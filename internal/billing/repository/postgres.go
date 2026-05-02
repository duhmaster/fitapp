package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	billingdomain "github.com/fitflow/fitflow/internal/billing/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PG struct {
	pool *pgxpool.Pool
}

func NewPG(pool *pgxpool.Pool) *PG {
	return &PG{pool: pool}
}

func (r *PG) ListActivePlans(ctx context.Context) ([]*billingdomain.Plan, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT code, title, billing_period, price_minor, currency, is_active
		FROM billing_plans
		WHERE is_active = TRUE
		ORDER BY price_minor ASC, code ASC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]*billingdomain.Plan, 0, 8)
	for rows.Next() {
		var p billingdomain.Plan
		if err := rows.Scan(&p.Code, &p.Title, &p.BillingPeriod, &p.PriceMinor, &p.Currency, &p.IsActive); err != nil {
			return nil, err
		}
		out = append(out, &p)
	}
	return out, rows.Err()
}

func (r *PG) GetPlanByCode(ctx context.Context, code string) (*billingdomain.Plan, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT code, title, billing_period, price_minor, currency, is_active
		FROM billing_plans
		WHERE code = $1 AND is_active = TRUE
	`, code)
	var p billingdomain.Plan
	if err := row.Scan(&p.Code, &p.Title, &p.BillingPeriod, &p.PriceMinor, &p.Currency, &p.IsActive); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("plan not found: %s", code)
		}
		return nil, err
	}
	return &p, nil
}

func (r *PG) GetLatestEntitlingSubscription(ctx context.Context, userID uuid.UUID, now time.Time) (*billingdomain.Subscription, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT plan_code, status, provider, auto_renew, current_period_end
		FROM user_subscriptions
		WHERE user_id = $1
		  AND status IN ('trial', 'active', 'grace')
		  AND (
		    status = 'grace'
		    OR current_period_end >= $2
		  )
		ORDER BY current_period_end DESC
		LIMIT 1
	`, userID, now.UTC())
	var s billingdomain.Subscription
	var status string
	if err := row.Scan(&s.PlanCode, &status, &s.Provider, &s.AutoRenew, &s.CurrentPeriodEnd); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	s.Status = billingdomain.SubscriptionStatus(status)
	return &s, nil
}

func (r *PG) GetUserRecord(ctx context.Context, userID uuid.UUID) (*authdomain.UserRecord, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, email, password_hash, role, theme, locale, paid_subscriber, subscription_expires_at, created_at, updated_at
		FROM users
		WHERE id = $1 AND deleted_at IS NULL
	`, userID)
	var u authdomain.UserRecord
	var role string
	var subExp *time.Time
	if err := row.Scan(
		&u.ID, &u.Email, &u.PasswordHash, &role, &u.Theme, &u.Locale,
		&u.PaidSubscriber, &subExp, &u.CreatedAt, &u.UpdatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, authdomain.ErrUserNotFound
		}
		return nil, err
	}
	u.Role = authdomain.Role(role)
	u.SubscriptionExpiresAt = subExp
	return &u, nil
}

func (r *PG) CountActiveTrainerClients(ctx context.Context, trainerID uuid.UUID) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `
		SELECT COUNT(1)
		FROM trainer_clients
		WHERE trainer_id = $1 AND status = 'active'
	`, trainerID).Scan(&n)
	return n, err
}

func (r *PG) CreatePayment(ctx context.Context, p *billingdomain.Payment) (*billingdomain.Payment, error) {
	row := r.pool.QueryRow(ctx, `
		INSERT INTO billing_payments (
			id, user_id, plan_code, provider, provider_payment_id, order_id, amount_minor, currency, status, checkout_url, created_at, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW(), NOW())
		RETURNING id, user_id, created_at, updated_at
	`, p.ID, p.UserID, p.PlanCode, p.Provider, p.ProviderPaymentID, p.OrderID, p.AmountMinor, p.Currency, string(p.Status), p.CheckoutURL)
	var id, userID string
	if err := row.Scan(&id, &userID, &p.CreatedAt, &p.UpdatedAt); err != nil {
		return nil, err
	}
	p.ID = id
	p.UserID = userID
	return p, nil
}

func (r *PG) GetPaymentByID(ctx context.Context, paymentID uuid.UUID) (*billingdomain.Payment, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, user_id, plan_code, provider, provider_payment_id, order_id, amount_minor, currency, status, checkout_url, created_at, updated_at
		FROM billing_payments
		WHERE id = $1
	`, paymentID)
	var p billingdomain.Payment
	var status string
	if err := row.Scan(&p.ID, &p.UserID, &p.PlanCode, &p.Provider, &p.ProviderPaymentID, &p.OrderID, &p.AmountMinor, &p.Currency, &status, &p.CheckoutURL, &p.CreatedAt, &p.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	p.Status = billingdomain.PaymentStatus(status)
	return &p, nil
}

func (r *PG) MarkPaymentStatus(ctx context.Context, paymentID uuid.UUID, status billingdomain.PaymentStatus) error {
	_, err := r.pool.Exec(ctx, `
		UPDATE billing_payments
		SET status = $2::varchar,
		    paid_at = CASE WHEN $2::varchar = 'paid' THEN NOW() ELSE paid_at END,
		    updated_at = NOW()
		WHERE id = $1
	`, paymentID, string(status))
	return err
}

func (r *PG) GetPaymentByProviderPaymentID(ctx context.Context, provider, providerPaymentID string) (*billingdomain.Payment, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, user_id, plan_code, provider, provider_payment_id, order_id, amount_minor, currency, status, checkout_url, created_at, updated_at
		FROM billing_payments
		WHERE provider = $1 AND provider_payment_id = $2
	`, provider, providerPaymentID)
	var p billingdomain.Payment
	var status string
	if err := row.Scan(&p.ID, &p.UserID, &p.PlanCode, &p.Provider, &p.ProviderPaymentID, &p.OrderID, &p.AmountMinor, &p.Currency, &status, &p.CheckoutURL, &p.CreatedAt, &p.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	p.Status = billingdomain.PaymentStatus(status)
	return &p, nil
}

func (r *PG) ActivateSubscriptionForPayment(ctx context.Context, paymentID uuid.UUID) error {
	tx, err := r.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var userID uuid.UUID
	var planCode, provider, status, billingPeriod string
	err = tx.QueryRow(ctx, `
		SELECT p.user_id, p.plan_code, p.provider, p.status, bp.billing_period
		FROM billing_payments p
		JOIN billing_plans bp ON bp.code = p.plan_code
		WHERE p.id = $1
		FOR UPDATE
	`, paymentID).Scan(&userID, &planCode, &provider, &status, &billingPeriod)
	if err != nil {
		return err
	}
	if status != string(billingdomain.PaymentStatusPaid) {
		return fmt.Errorf("payment is not paid")
	}

	now := time.Now().UTC()
	periodEnd := now.AddDate(0, 1, 0)
	if billingPeriod == "year" {
		periodEnd = now.AddDate(1, 0, 0)
	}

	var subscriptionID uuid.UUID
	err = tx.QueryRow(ctx, `
		INSERT INTO user_subscriptions (
			id, user_id, plan_code, provider, provider_subscription_id, status, auto_renew, current_period_start, current_period_end, created_at, updated_at
		)
		VALUES (gen_random_uuid(), $1, $2, $3, $4, 'active', TRUE, $5, $6, NOW(), NOW())
		RETURNING id
	`, userID, planCode, provider, paymentID.String(), now, periodEnd).Scan(&subscriptionID)
	if err != nil {
		return err
	}

	_, err = tx.Exec(ctx, `
		UPDATE billing_payments
		SET subscription_id = $1,
		updated_at = NOW()
		WHERE id = $2
	`, subscriptionID, paymentID)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func (r *PG) InsertProviderEvent(ctx context.Context, ev *billingdomain.ProviderEvent) (bool, error) {
	var payload any
	if len(ev.Payload) > 0 {
		if err := json.Unmarshal(ev.Payload, &payload); err != nil {
			return false, err
		}
	}
	tag, err := r.pool.Exec(ctx, `
		INSERT INTO billing_provider_events (
			id, provider, provider_event_id, event_type, payload, signature_valid, created_at
		)
		VALUES (gen_random_uuid(), $1, $2, $3, $4::jsonb, $5, NOW())
		ON CONFLICT (provider, provider_event_id) DO NOTHING
	`, ev.Provider, ev.ProviderEventID, ev.EventType, payload, ev.SignatureValid)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

func (r *PG) MarkProviderEventProcessed(ctx context.Context, provider, providerEventID string) error {
	_, err := r.pool.Exec(ctx, `
		UPDATE billing_provider_events
		SET processed_at = NOW()
		WHERE provider = $1 AND provider_event_id = $2
	`, provider, providerEventID)
	return err
}

// GetCoachSubscriptionForAdmin returns the active coach-tier subscription row, if any.
func (r *PG) GetCoachSubscriptionForAdmin(ctx context.Context, userID uuid.UUID) (*billingdomain.CoachSubscriptionInfo, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT plan_code, status, current_period_end
		FROM user_subscriptions
		WHERE user_id = $1
		  AND plan_code IN ('free_coach', 'coach_pro', 'coach_pro_yearly')
		  AND status IN ('trial', 'active', 'grace')
		ORDER BY current_period_end DESC
		LIMIT 1
	`, userID)
	var info billingdomain.CoachSubscriptionInfo
	if err := row.Scan(&info.PlanCode, &info.Status, &info.CurrentPeriodEnd); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &info, nil
}

// AdminReplaceCoachSubscription cancels active coach-tier rows and optionally inserts a new one from the admin panel.
// planCode empty: only cancel. Otherwise one of free_coach, coach_pro, coach_pro_yearly.
// If periodEnd is nil, a default end date is chosen from the plan’s billing period.
func (r *PG) AdminReplaceCoachSubscription(ctx context.Context, userID uuid.UUID, planCode string, periodEnd *time.Time) error {
	planCode = strings.TrimSpace(planCode)
	if planCode == "" {
		_, err := r.pool.Exec(ctx, `
			UPDATE user_subscriptions
			SET status = 'canceled', updated_at = NOW()
			WHERE user_id = $1
			  AND plan_code IN ('free_coach', 'coach_pro', 'coach_pro_yearly')
			  AND status IN ('trial', 'active', 'grace')
		`, userID)
		return err
	}
	if planCode != "free_coach" && planCode != "coach_pro" && planCode != "coach_pro_yearly" {
		return fmt.Errorf("invalid coach plan: %q", planCode)
	}
	now := time.Now().UTC()
	end := periodEnd
	if end == nil {
		switch planCode {
		case "free_coach":
			t := now.AddDate(50, 0, 0)
			end = &t
		case "coach_pro":
			t := now.AddDate(0, 1, 0)
			end = &t
		case "coach_pro_yearly":
			t := now.AddDate(1, 0, 0)
			end = &t
		}
	}
	tx, err := r.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err := tx.Exec(ctx, `
		UPDATE user_subscriptions
		SET status = 'canceled', updated_at = NOW()
		WHERE user_id = $1
		  AND plan_code IN ('free_coach', 'coach_pro', 'coach_pro_yearly')
		  AND status IN ('trial', 'active', 'grace')
	`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO user_subscriptions (
			user_id, plan_code, provider, provider_subscription_id,
			status, auto_renew, current_period_start, current_period_end,
			created_at, updated_at
		)
		VALUES ($1, $2, 'admin', 'admin_panel', 'active', FALSE, $3, $4, NOW(), NOW())
	`, userID, planCode, now, *end); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
