package domain

import (
	"time"

	"github.com/google/uuid"
)

type Severity string

const (
	SeverityInfo     Severity = "info"
	SeverityWarning  Severity = "warning"
	SeverityCritical Severity = "critical"
)

type RecommendationType string

const (
	RecommendationTypeLoadAdjust    RecommendationType = "load_adjust"
	RecommendationTypeSleepRecovery RecommendationType = "sleep_recovery"
	RecommendationTypeWellbeing     RecommendationType = "wellbeing_alert"
	RecommendationTypeNextSession   RecommendationType = "next_session"
	RecommendationTypeGeneralTip    RecommendationType = "general_tip"
)

type Recommendation struct {
	ID          uuid.UUID
	UserID      uuid.UUID
	WorkoutID   uuid.UUID
	Type        RecommendationType
	Severity    Severity
	Title       string
	Message     string
	Payload     map[string]any
	RuleVersion string
	CreatedAt   time.Time
	ExpiresAt   *time.Time
	ReadAt      *time.Time
}
