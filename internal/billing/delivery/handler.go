package delivery

import (
	"crypto/subtle"
	"net/http"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	billingdomain "github.com/fitflow/fitflow/internal/billing/domain"
	"github.com/fitflow/fitflow/internal/billing/usecase"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	uc            *usecase.UseCase
	webhookSecret string
}

func NewHandler(uc *usecase.UseCase, webhookSecret string) *Handler {
	return &Handler{uc: uc, webhookSecret: webhookSecret}
}

type PlanResponse struct {
	Code          string `json:"code"`
	Title         string `json:"title"`
	BillingPeriod string `json:"billing_period"`
	PriceMinor    int64  `json:"price_minor"`
	Currency      string `json:"currency"`
}

func (h *Handler) ListPlans(c *gin.Context) {
	plans, err := h.uc.ListPlans(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]PlanResponse, 0, len(plans))
	for _, p := range plans {
		out = append(out, PlanResponse{
			Code:          p.Code,
			Title:         p.Title,
			BillingPeriod: p.BillingPeriod,
			PriceMinor:    p.PriceMinor,
			Currency:      p.Currency,
		})
	}
	c.JSON(http.StatusOK, gin.H{"plans": out})
}

type SubscriptionResponse struct {
	PlanCode         string `json:"plan_code"`
	Status           string `json:"status"`
	Provider         string `json:"provider"`
	AutoRenew        bool   `json:"auto_renew"`
	CurrentPeriodEnd string `json:"current_period_end"`
}

func (h *Handler) GetMySubscription(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	sub, err := h.uc.GetMySubscription(c.Request.Context(), user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if sub == nil {
		c.JSON(http.StatusOK, gin.H{"subscription": nil})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"subscription": SubscriptionResponse{
			PlanCode:         sub.PlanCode,
			Status:           string(sub.Status),
			Provider:         sub.Provider,
			AutoRenew:        sub.AutoRenew,
			CurrentPeriodEnd: sub.CurrentPeriodEnd.UTC().Format(time.RFC3339),
		},
	})
}

func (h *Handler) GetMyEntitlements(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	ent, err := h.uc.GetEntitlements(c.Request.Context(), user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"entitlements": toEntitlementsResponse(ent)})
}

type CheckoutRequest struct {
	PlanCode  string `json:"plan_code" binding:"required"`
	Platform  string `json:"platform"`
	ReturnURL string `json:"return_url"`
	CancelURL string `json:"cancel_url"`
}

type CheckoutResponse struct {
	PaymentID   string `json:"payment_id"`
	Status      string `json:"status"`
	Provider    string `json:"provider"`
	CheckoutURL string `json:"checkout_url"`
	AmountMinor int64  `json:"amount_minor"`
	Currency    string `json:"currency"`
}

func (h *Handler) CreateCheckout(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	var req CheckoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	p, err := h.uc.CreateCheckout(c.Request.Context(), user, usecase.CheckoutInput{
		PlanCode:  req.PlanCode,
		Platform:  req.Platform,
		ReturnURL: req.ReturnURL,
		CancelURL: req.CancelURL,
	})
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, CheckoutResponse{
		PaymentID:   p.ID,
		Status:      string(p.Status),
		Provider:    p.Provider,
		CheckoutURL: p.CheckoutURL,
		AmountMinor: p.AmountMinor,
		Currency:    p.Currency,
	})
}

func (h *Handler) GetMyPayment(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	paymentID, err := uuid.Parse(c.Param("payment_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid payment_id"})
		return
	}
	p, err := h.uc.GetMyPayment(c.Request.Context(), user, paymentID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if p == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "payment not found"})
		return
	}
	c.JSON(http.StatusOK, CheckoutResponse{
		PaymentID:   p.ID,
		Status:      string(p.Status),
		Provider:    p.Provider,
		CheckoutURL: p.CheckoutURL,
		AmountMinor: p.AmountMinor,
		Currency:    p.Currency,
	})
}

func (h *Handler) MockConfirmMyPayment(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	paymentID, err := uuid.Parse(c.Param("payment_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid payment_id"})
		return
	}
	p, err := h.uc.GetMyPayment(c.Request.Context(), user, paymentID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if p == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "payment not found"})
		return
	}
	if err := h.uc.ConfirmPayment(c.Request.Context(), paymentID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

type ProviderWebhookRequest struct {
	EventID           string `json:"event_id"`
	EventType         string `json:"event_type"`
	Provider          string `json:"provider"`
	ProviderPaymentID string `json:"provider_payment_id" binding:"required"`
	Status            string `json:"status" binding:"required"`
}

func (h *Handler) ProviderWebhook(c *gin.Context) {
	signatureValid := true
	if h.webhookSecret != "" {
		received := c.GetHeader("X-Billing-Signature")
		signatureValid = subtle.ConstantTimeCompare([]byte(received), []byte(h.webhookSecret)) == 1
		if !signatureValid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid signature"})
			return
		}
	}
	var req ProviderWebhookRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	provider := req.Provider
	if provider == "" {
		provider = "tinkoff"
	}
	eventID := req.EventID
	if eventID == "" {
		eventID = provider + ":" + req.ProviderPaymentID + ":" + req.Status
	}
	eventType := req.EventType
	if eventType == "" {
		eventType = req.Status
	}
	if err := h.uc.ProcessProviderWebhookEvent(c.Request.Context(), billingdomain.ProviderEvent{
		Provider:        provider,
		ProviderEventID: eventID,
		EventType:       eventType,
		SignatureValid:  signatureValid,
	}, usecase.ProviderWebhookInput{
		Provider:          provider,
		ProviderPaymentID: req.ProviderPaymentID,
		Status:            req.Status,
	}); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

type EntitlementsResponse struct {
	PremiumUser           bool `json:"premium_user"`
	CoachPro              bool `json:"coach_pro"`
	AdsDisabled           bool `json:"ads_disabled"`
	PremiumAnalytics      bool `json:"premium_analytics_full_history"`
	PremiumGoalsExtended  bool `json:"premium_goals_extended"`
	CoachClientsUnlimited bool `json:"coach_clients_unlimited"`
	CoachAdvancedReports  bool `json:"coach_advanced_reports"`
	CanAddClient          bool `json:"can_add_client"`
}

func toEntitlementsResponse(ent billingdomain.Entitlements) EntitlementsResponse {
	return EntitlementsResponse{
		PremiumUser:           ent.PremiumUser,
		CoachPro:              ent.CoachPro,
		AdsDisabled:           ent.AdsDisabled,
		PremiumAnalytics:      ent.PremiumAnalytics,
		PremiumGoalsExtended:  ent.PremiumGoalsExtended,
		CoachClientsUnlimited: ent.CoachClientsUnlimited,
		CoachAdvancedReports:  ent.CoachAdvancedReports,
		CanAddClient:          ent.CanAddClient,
	}
}

func getUser(c *gin.Context) *authdomain.User {
	val, exists := c.Get(string(middleware.UserContextKey))
	if !exists {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return nil
	}
	user, ok := val.(*authdomain.User)
	if !ok {
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "forbidden"})
		return nil
	}
	return user
}
