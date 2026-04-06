package usecase

import (
	"context"
	"errors"
	"time"

	gamdomain "github.com/fitflow/fitflow/internal/gamification/domain"
	"github.com/fitflow/fitflow/internal/gamification/leaderboard"
	goredis "github.com/redis/go-redis/v9"
	"github.com/google/uuid"
)

// ErrGymIDRequired is returned when scope=gym without gym_id.
var ErrGymIDRequired = errors.New("gym_id is required for gym scope")

// UseCase orchestrates gamification reads and workout rewards.
type UseCase struct {
	repo  gamdomain.Repository
	redis *leaderboard.Redis
}

func New(repo gamdomain.Repository, redis *leaderboard.Redis) *UseCase {
	return &UseCase{repo: repo, redis: redis}
}

func (u *UseCase) GetProfile(ctx context.Context, userID uuid.UUID) (*gamdomain.Profile, error) {
	return u.repo.GetProfile(ctx, userID)
}

func (u *UseCase) ListXPHistory(ctx context.Context, userID uuid.UUID, limit, offset int) ([]gamdomain.XPLedgerRow, error) {
	return u.repo.ListXPHistory(ctx, userID, limit, offset)
}

func (u *UseCase) ListBadgeCatalog(ctx context.Context) ([]gamdomain.BadgeDefinition, error) {
	return u.repo.ListBadgeDefinitions(ctx)
}

func (u *UseCase) ListUserBadges(ctx context.Context, userID uuid.UUID) ([]gamdomain.UserBadge, error) {
	return u.repo.ListUserBadges(ctx, userID)
}

func (u *UseCase) ListMissionDefinitions(ctx context.Context) ([]gamdomain.MissionDefinition, error) {
	return u.repo.ListMissionDefinitions(ctx)
}

func (u *UseCase) ListMissionProgress(ctx context.Context, userID uuid.UUID) ([]gamdomain.UserMissionProgress, error) {
	return u.repo.ListUserMissionProgress(ctx, userID)
}

func (u *UseCase) ClaimMission(ctx context.Context, userID, missionID uuid.UUID) error {
	return u.repo.ClaimMission(ctx, userID, missionID)
}

// OnWorkoutFinished applies idempotent XP for a completed workout (e.g. manual replay).
func (u *UseCase) OnWorkoutFinished(ctx context.Context, userID, workoutID uuid.UUID, performedVolumeKg float64) error {
	return u.repo.ApplyWorkoutReward(ctx, userID, workoutID, performedVolumeKg)
}

// ProcessOutbox drains pending workout_xp rows (also run after enqueue in FinishWorkout).
func (u *UseCase) ProcessOutbox(ctx context.Context, limit int) (int, error) {
	return u.repo.ProcessOutbox(ctx, limit)
}

// ApplyGroupTrainingRegistrationReward is called after successful group training registration.
func (u *UseCase) ApplyGroupTrainingRegistrationReward(ctx context.Context, userID, trainingID uuid.UUID) error {
	return u.repo.ApplyGroupTrainingRegistrationReward(ctx, userID, trainingID)
}

// ApplyGymCheckInMission is called after a successful gym check-in.
func (u *UseCase) ApplyGymCheckInMission(ctx context.Context, userID, gymID uuid.UUID) error {
	return u.repo.ApplyGymCheckInMission(ctx, userID, gymID)
}

// PublicLeaderboardScores returns top weekly global scores without PII (Redis); falls back to SQL aggregates.
func (u *UseCase) PublicLeaderboardScores(ctx context.Context, limit int) ([]PublicScoreRow, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	if u.redis != nil && u.redis.OK() {
		wk := leaderboard.WeekKey(time.Now().UTC())
		scores, err := u.redis.TopScoresOnlyWeekly(ctx, wk, limit)
		if err == nil && len(scores) > 0 {
			out := make([]PublicScoreRow, len(scores))
			for i, s := range scores {
				out[i] = PublicScoreRow{Rank: i + 1, Score: int(s)}
			}
			return out, nil
		}
	}
	ws, we := WeekBoundsUTC(time.Now().UTC())
	entries, err := u.repo.LeaderboardGlobalWeekly(ctx, ws, we, limit, uuid.Nil)
	if err != nil {
		return nil, err
	}
	out := make([]PublicScoreRow, len(entries))
	for i, e := range entries {
		out[i] = PublicScoreRow{Rank: e.Rank, Score: e.Score}
	}
	return out, nil
}

// PublicScoreRow is a leaderboard row without user identifiers.
type PublicScoreRow struct {
	Rank  int `json:"rank"`
	Score int `json:"score"`
}

// Leaderboard resolves scope/period; prefers Redis when populated, else PostgreSQL.
func (u *UseCase) Leaderboard(ctx context.Context, userID uuid.UUID, scope, period string, gymID *uuid.UUID, limit int) ([]gamdomain.LeaderboardEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	wk := leaderboard.WeekKey(time.Now().UTC())

	if u.redis != nil && u.redis.OK() {
		var zs []goredis.Z
		var err error
		switch period {
		case "all_time":
			switch scope {
			case "gym":
				if gymID == nil {
					return nil, ErrGymIDRequired
				}
				zs, err = u.redis.TopGymAllTime(ctx, *gymID, limit)
			case "trainer", "trainer_clients":
				zs, err = u.redis.TopTrainerClientsAllTime(ctx, userID, limit)
			default:
				zs, err = u.redis.TopGlobalAllTime(ctx, limit)
			}
		default:
			switch scope {
			case "gym":
				if gymID == nil {
					return nil, ErrGymIDRequired
				}
				zs, err = u.redis.TopGymWeekly(ctx, *gymID, wk, limit)
			case "trainer", "trainer_clients":
				zs, err = u.redis.TopTrainerClientsWeekly(ctx, userID, wk, limit)
			default:
				zs, err = u.redis.TopGlobalWeekly(ctx, wk, limit)
			}
		}
		if err == nil && len(zs) > 0 {
			return u.entriesFromRedisZ(ctx, zs, userID)
		}
	}

	switch period {
	case "all_time":
		switch scope {
		case "gym":
			if gymID == nil {
				return nil, ErrGymIDRequired
			}
			return u.repo.LeaderboardGymAllTime(ctx, *gymID, limit, userID)
		case "trainer", "trainer_clients":
			return u.repo.LeaderboardTrainerClientsAllTime(ctx, userID, limit, userID)
		case "global":
			return u.repo.LeaderboardGlobalAllTime(ctx, limit, userID)
		default:
			return u.repo.LeaderboardGlobalAllTime(ctx, limit, userID)
		}
	default:
		ws, we := WeekBoundsUTC(time.Now().UTC())
		switch scope {
		case "gym":
			if gymID == nil {
				return nil, ErrGymIDRequired
			}
			return u.repo.LeaderboardGymWeekly(ctx, *gymID, ws, we, limit, userID)
		case "trainer", "trainer_clients":
			return u.repo.LeaderboardTrainerClientsWeekly(ctx, userID, ws, we, limit, userID)
		default:
			return u.repo.LeaderboardGlobalWeekly(ctx, ws, we, limit, userID)
		}
	}
}

func (u *UseCase) entriesFromRedisZ(ctx context.Context, zs []goredis.Z, currentUserID uuid.UUID) ([]gamdomain.LeaderboardEntry, error) {
	ids := make([]uuid.UUID, 0, len(zs))
	for _, z := range zs {
		member, _ := z.Member.(string)
		id, err := uuid.Parse(member)
		if err != nil {
			continue
		}
		ids = append(ids, id)
	}
	profs, err := u.repo.FetchUserProfilesForLeaderboard(ctx, ids)
	if err != nil {
		return nil, err
	}
	out := make([]gamdomain.LeaderboardEntry, 0, len(zs))
	rank := 1
	for _, z := range zs {
		member, _ := z.Member.(string)
		id, err := uuid.Parse(member)
		if err != nil {
			continue
		}
		p := profs[id]
		out = append(out, gamdomain.LeaderboardEntry{
			Rank:          rank,
			UserID:        id,
			DisplayName:   p.DisplayName,
			Score:         int(z.Score),
			AvatarURL:     p.AvatarURL,
			IsCurrentUser: id == currentUserID,
		})
		rank++
	}
	return out, nil
}

// WeekBoundsUTC returns [start, end) for the ISO week containing now (UTC, Monday start).
func WeekBoundsUTC(now time.Time) (start, end time.Time) {
	u := now.UTC()
	wd := int(u.Weekday())
	daysFromMonday := (wd + 6) % 7
	start = time.Date(u.Year(), u.Month(), u.Day(), 0, 0, 0, 0, time.UTC).AddDate(0, 0, -daysFromMonday)
	end = start.AddDate(0, 0, 7)
	return start, end
}

// GetUserFeaturePreferences returns toggles for the current user (defaults all true if missing).
func (u *UseCase) GetUserFeaturePreferences(ctx context.Context, userID uuid.UUID) (gamdomain.UserFeaturePreferences, error) {
	return u.repo.GetUserFeaturePreferences(ctx, userID)
}

// UpsertUserFeaturePreferences saves per-user gamification toggles.
func (u *UseCase) UpsertUserFeaturePreferences(ctx context.Context, userID uuid.UUID, p gamdomain.UserFeaturePreferences) error {
	return u.repo.UpsertUserFeaturePreferences(ctx, userID, p)
}
