package usecase

import (
	"context"
	"fmt"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	billingdomain "github.com/fitflow/fitflow/internal/billing/domain"
	"github.com/google/uuid"
)

const freeCoachClientLimit = 5

type UseCase struct {
	repo billingdomain.Repository
}

func New(repo billingdomain.Repository) *UseCase {
	return &UseCase{repo: repo}
}

func (uc *UseCase) ListPlans(ctx context.Context) ([]*billingdomain.Plan, error) {
	return uc.repo.ListActivePlans(ctx)
}

func (uc *UseCase) GetMySubscription(ctx context.Context, user *authdomain.User) (*billingdomain.Subscription, error) {
	return uc.repo.GetLatestEntitlingSubscription(ctx, user.ID, time.Now().UTC())
}

func (uc *UseCase) GetEntitlements(ctx context.Context, user *authdomain.User) (billingdomain.Entitlements, error) {
	sub, err := uc.repo.GetLatestEntitlingSubscription(ctx, user.ID, time.Now().UTC())
	if err != nil {
		return billingdomain.Entitlements{}, err
	}
	rec, err := uc.repo.GetUserRecord(ctx, user.ID)
	if err != nil {
		return billingdomain.Entitlements{}, err
	}
	ent := billingdomain.Entitlements{}

	// Legacy compatibility for already migrated users.
	legacyPremium := rec.PaidSubscriber && (rec.SubscriptionExpiresAt == nil || rec.SubscriptionExpiresAt.After(time.Now().UTC()))

	if sub != nil {
		switch sub.PlanCode {
		case "premium_user", "premium_user_yearly":
			ent.PremiumUser = true
		case "coach_pro", "coach_pro_yearly":
			ent.CoachPro = true
		}
	}
	if legacyPremium {
		ent.PremiumUser = true
	}

	ent.AdsDisabled = ent.PremiumUser || ent.CoachPro
	ent.PremiumAnalytics = ent.PremiumUser
	ent.PremiumGoalsExtended = ent.PremiumUser
	ent.CoachClientsUnlimited = ent.CoachPro
	ent.CoachAdvancedReports = ent.CoachPro

	if rec.Role == authdomain.RoleTrainer {
		if ent.CoachPro {
			ent.CanAddClient = true
		} else {
			n, err := uc.repo.CountActiveTrainerClients(ctx, user.ID)
			if err != nil {
				return billingdomain.Entitlements{}, err
			}
			ent.CanAddClient = n < freeCoachClientLimit
		}
	}

	return ent, nil
}

func (uc *UseCase) IsPremiumUser(ctx context.Context, user *authdomain.User) (bool, error) {
	ent, err := uc.GetEntitlements(ctx, user)
	if err != nil {
		return false, err
	}
	return ent.PremiumUser, nil
}

func (uc *UseCase) IsCoachPro(ctx context.Context, user *authdomain.User) (bool, error) {
	ent, err := uc.GetEntitlements(ctx, user)
	if err != nil {
		return false, err
	}
	return ent.CoachPro, nil
}

type CheckoutInput struct {
	PlanCode  string
	Platform  string
	ReturnURL string
	CancelURL string
}

func (uc *UseCase) CreateCheckout(ctx context.Context, user *authdomain.User, in CheckoutInput) (*billingdomain.Payment, error) {
	plan, err := uc.repo.GetPlanByCode(ctx, in.PlanCode)
	if err != nil {
		return nil, err
	}
	paymentID := uuid.New()
	orderID := fmt.Sprintf("ord_%d_%s", time.Now().Unix(), paymentID.String())
	// MVP stub: payment provider URL placeholder; real provider integration is next sprint.
	checkoutURL := fmt.Sprintf("/pay/mock/%s", paymentID.String())
	p := &billingdomain.Payment{
		ID:                paymentID.String(),
		UserID:            user.ID.String(),
		PlanCode:          plan.Code,
		Provider:          "tinkoff",
		ProviderPaymentID: paymentID.String(),
		OrderID:           orderID,
		AmountMinor:       plan.PriceMinor,
		Currency:          plan.Currency,
		Status:            billingdomain.PaymentStatusPending,
		CheckoutURL:       checkoutURL,
	}
	return uc.repo.CreatePayment(ctx, p)
}

func (uc *UseCase) GetMyPayment(ctx context.Context, user *authdomain.User, paymentID uuid.UUID) (*billingdomain.Payment, error) {
	p, err := uc.repo.GetPaymentByID(ctx, paymentID)
	if err != nil {
		return nil, err
	}
	if p == nil {
		return nil, nil
	}
	if p.UserID != user.ID.String() {
		return nil, fmt.Errorf("payment not found")
	}
	// Preserve consistent URL on read in MVP stub.
	if p.CheckoutURL == "" {
		p.CheckoutURL = fmt.Sprintf("/pay/mock/%s", p.ID)
	}
	return p, nil
}

func (uc *UseCase) ConfirmPayment(ctx context.Context, paymentID uuid.UUID) error {
	if err := uc.repo.MarkPaymentStatus(ctx, paymentID, billingdomain.PaymentStatusPaid); err != nil {
		return err
	}
	return uc.repo.ActivateSubscriptionForPayment(ctx, paymentID)
}

func (uc *UseCase) FailPayment(ctx context.Context, paymentID uuid.UUID) error {
	return uc.repo.MarkPaymentStatus(ctx, paymentID, billingdomain.PaymentStatusFailed)
}

type ProviderWebhookInput struct {
	Provider          string
	ProviderPaymentID string
	Status            string
}

func (uc *UseCase) ProcessProviderWebhook(ctx context.Context, in ProviderWebhookInput) error {
	return uc.ProcessProviderWebhookEvent(ctx, billingdomain.ProviderEvent{
		Provider:        in.Provider,
		ProviderEventID: fmt.Sprintf("%s:%s:%s", in.Provider, in.ProviderPaymentID, in.Status),
		EventType:       in.Status,
		SignatureValid:  true,
	}, in)
}

func (uc *UseCase) ProcessProviderWebhookEvent(ctx context.Context, ev billingdomain.ProviderEvent, in ProviderWebhookInput) error {
	inserted, err := uc.repo.InsertProviderEvent(ctx, &ev)
	if err != nil {
		return err
	}
	if !inserted {
		// idempotent duplicate: already processed/received.
		return nil
	}

	p, err := uc.repo.GetPaymentByProviderPaymentID(ctx, in.Provider, in.ProviderPaymentID)
	if err != nil {
		return err
	}
	if p == nil {
		return fmt.Errorf("payment not found")
	}

	switch in.Status {
	case "paid", "confirmed", "success":
		paymentID, parseErr := uuid.Parse(p.ID)
		if parseErr != nil {
			return parseErr
		}
		if err := uc.ConfirmPayment(ctx, paymentID); err != nil {
			return err
		}
	case "failed", "canceled":
		paymentID, parseErr := uuid.Parse(p.ID)
		if parseErr != nil {
			return parseErr
		}
		if err := uc.FailPayment(ctx, paymentID); err != nil {
			return err
		}
	default:
		// Unknown/ignored status is accepted and marked as processed.
	}
	return uc.repo.MarkProviderEventProcessed(ctx, ev.Provider, ev.ProviderEventID)
}
