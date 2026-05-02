package domain

import "time"

type Plan struct {
	Code          string
	Title         string
	BillingPeriod string
	PriceMinor    int64
	Currency      string
	IsActive      bool
}

type SubscriptionStatus string

const (
	SubscriptionStatusTrial    SubscriptionStatus = "trial"
	SubscriptionStatusActive   SubscriptionStatus = "active"
	SubscriptionStatusGrace    SubscriptionStatus = "grace"
	SubscriptionStatusPastDue  SubscriptionStatus = "past_due"
	SubscriptionStatusCanceled SubscriptionStatus = "canceled"
	SubscriptionStatusExpired  SubscriptionStatus = "expired"
)

type Subscription struct {
	PlanCode         string
	Status           SubscriptionStatus
	Provider         string
	AutoRenew        bool
	CurrentPeriodEnd time.Time
}

type PaymentStatus string

const (
	PaymentStatusCreated  PaymentStatus = "created"
	PaymentStatusPending  PaymentStatus = "pending"
	PaymentStatusPaid     PaymentStatus = "paid"
	PaymentStatusFailed   PaymentStatus = "failed"
	PaymentStatusCanceled PaymentStatus = "canceled"
)

type Payment struct {
	ID                string
	UserID            string
	PlanCode          string
	Provider          string
	ProviderPaymentID string
	OrderID           string
	AmountMinor       int64
	Currency          string
	Status            PaymentStatus
	CheckoutURL       string
	CreatedAt         time.Time
	UpdatedAt         time.Time
}

type ProviderEvent struct {
	Provider        string
	ProviderEventID string
	EventType       string
	Payload         []byte
	SignatureValid  bool
}

type Entitlements struct {
	PremiumUser           bool
	CoachPro              bool
	AdsDisabled           bool
	PremiumAnalytics      bool
	PremiumGoalsExtended  bool
	CoachClientsUnlimited bool
	CoachAdvancedReports  bool
	CanAddClient          bool
}
