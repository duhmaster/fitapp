package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// Repository persists gamification data.
type Repository interface {
	GetProfile(ctx context.Context, userID uuid.UUID) (*Profile, error)
	ListXPHistory(ctx context.Context, userID uuid.UUID, limit, offset int) ([]XPLedgerRow, error)
	ListBadgeDefinitions(ctx context.Context) ([]BadgeDefinition, error)
	ListUserBadges(ctx context.Context, userID uuid.UUID) ([]UserBadge, error)
	ListMissionDefinitions(ctx context.Context) ([]MissionDefinition, error)
	ListUserMissionProgress(ctx context.Context, userID uuid.UUID) ([]UserMissionProgress, error)
	ClaimMission(ctx context.Context, userID, missionID uuid.UUID) error

	// ApplyWorkoutReward is idempotent per workout_id (xp:workout:{id}).
	ApplyWorkoutReward(ctx context.Context, userID, workoutID uuid.UUID, performedVolumeKg float64) error

	LeaderboardGlobalWeekly(ctx context.Context, weekStart, weekEnd time.Time, limit int, currentUserID uuid.UUID) ([]LeaderboardEntry, error)
	LeaderboardGlobalAllTime(ctx context.Context, limit int, currentUserID uuid.UUID) ([]LeaderboardEntry, error)
	LeaderboardGymWeekly(ctx context.Context, gymID uuid.UUID, weekStart, weekEnd time.Time, limit int, currentUserID uuid.UUID) ([]LeaderboardEntry, error)
	LeaderboardGymAllTime(ctx context.Context, gymID uuid.UUID, limit int, currentUserID uuid.UUID) ([]LeaderboardEntry, error)
	LeaderboardTrainerClientsWeekly(ctx context.Context, trainerID uuid.UUID, weekStart, weekEnd time.Time, limit int, currentUserID uuid.UUID) ([]LeaderboardEntry, error)
	LeaderboardTrainerClientsAllTime(ctx context.Context, trainerID uuid.UUID, limit int, currentUserID uuid.UUID) ([]LeaderboardEntry, error)

	// EnqueueWorkoutFinished inserts outbox row in the same transaction as workout finish.
	EnqueueWorkoutFinished(ctx context.Context, tx pgx.Tx, userID, workoutID uuid.UUID, volumeKg float64) error
	// ProcessOutbox applies pending workout_xp events (idempotent via xp_ledger).
	ProcessOutbox(ctx context.Context, limit int) (int, error)

	GetGamificationSetting(ctx context.Context, key string) ([]byte, error)
	SetGamificationSetting(ctx context.Context, key string, value []byte) error
	GetLevelThresholds(ctx context.Context) ([]int, error)
	SetLevelThresholds(ctx context.Context, thresholds []int) error

	CreateBadgeDefinition(ctx context.Context, code, title string, description *string, rarity string, iconKey *string) (uuid.UUID, error)
	UpdateBadgeDefinition(ctx context.Context, id uuid.UUID, code, title string, description *string, rarity string, iconKey *string) error
	DeleteBadgeDefinition(ctx context.Context, id uuid.UUID) error

	CreateMissionDefinition(ctx context.Context, code, title string, description *string, period string, targetValue, rewardXP int) (uuid.UUID, error)
	UpdateMissionDefinition(ctx context.Context, id uuid.UUID, code, title string, description *string, period string, targetValue, rewardXP int) error
	DeleteMissionDefinition(ctx context.Context, id uuid.UUID) error

	ApplyGroupTrainingRegistrationReward(ctx context.Context, userID, trainingID uuid.UUID) error
	ApplyGymCheckInMission(ctx context.Context, userID, gymID uuid.UUID) error

	// ApplyBodyMeasurementReward grants small XP and updates weekly_body_log mission (idempotent per measurement id).
	ApplyBodyMeasurementReward(ctx context.Context, userID, measurementID uuid.UUID) error

	FetchUserProfilesForLeaderboard(ctx context.Context, userIDs []uuid.UUID) (map[uuid.UUID]LeaderboardProfileRow, error)

	GetUserFeaturePreferences(ctx context.Context, userID uuid.UUID) (UserFeaturePreferences, error)
	UpsertUserFeaturePreferences(ctx context.Context, userID uuid.UUID, p UserFeaturePreferences) error
}
