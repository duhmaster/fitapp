package domain

import (
	"time"

	"github.com/google/uuid"
)

// Profile matches Flutter GamificationProfile JSON.
type Profile struct {
	UserID             uuid.UUID
	TotalXP            int
	Level              int
	XPIntoCurrentLevel int
	XPForNextLevel     int
	AvatarTier         int
	DisplayTitle       *string
}

// XPLedgerRow is one xp_ledger row.
type XPLedgerRow struct {
	ID              uuid.UUID
	UserID          uuid.UUID
	DeltaXP         int
	Reason          string
	SourceType      *string
	SourceID        *uuid.UUID
	IdempotencyKey  string
	CreatedAt       time.Time
}

// BadgeDefinition is a catalog row.
type BadgeDefinition struct {
	ID          uuid.UUID
	Code        string
	Title       string
	Description *string
	Rarity      string
	IconKey     *string
}

// UserBadge is an unlocked badge.
type UserBadge struct {
	BadgeID     uuid.UUID
	UnlockedAt  time.Time
}

// MissionDefinition is a mission template.
type MissionDefinition struct {
	ID          uuid.UUID
	Code        string
	Title       string
	Description *string
	Period      string // daily | weekly
	TargetValue int
	RewardXP    int
}

// MissionStatus mirrors Flutter.
type MissionStatus string

const (
	MissionActive    MissionStatus = "active"
	MissionCompleted MissionStatus = "completed"
	MissionClaimed   MissionStatus = "claimed"
	MissionExpired   MissionStatus = "expired"
)

// UserMissionProgress is progress for one mission window.
type UserMissionProgress struct {
	MissionID    uuid.UUID
	CurrentValue int
	Status       MissionStatus
	WindowStart  *time.Time
	WindowEnd    *time.Time
}

// LeaderboardEntry is one ranked row.
type LeaderboardEntry struct {
	Rank           int
	UserID         uuid.UUID
	DisplayName    string
	Score          int
	AvatarURL      *string
	IsCurrentUser  bool
}

// LeaderboardProfileRow is display data for a user on a leaderboard.
type LeaderboardProfileRow struct {
	DisplayName string
	AvatarURL   *string
}
