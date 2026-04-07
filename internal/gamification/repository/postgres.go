package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	gamdomain "github.com/fitflow/fitflow/internal/gamification/domain"
	"github.com/fitflow/fitflow/internal/gamification/leaderboard"
	"github.com/fitflow/fitflow/internal/gamification/level"
	"github.com/fitflow/fitflow/internal/gamification/xp"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// PG is PostgreSQL implementation of gamdomain.Repository.
type PG struct {
	pool  *pgxpool.Pool
	redis *leaderboard.Redis
}

func NewPG(pool *pgxpool.Pool, redis *leaderboard.Redis) *PG {
	return &PG{pool: pool, redis: redis}
}

func (r *PG) GetProfile(ctx context.Context, userID uuid.UUID) (*gamdomain.Profile, error) {
	var totalXP, av int
	err := r.pool.QueryRow(ctx, `
		SELECT COALESCE(total_xp, 0), COALESCE(avatar_tier, 0)
		FROM gamification_profiles WHERE user_id = $1
	`, userID).Scan(&totalXP, &av)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			t := r.getLevelThresholds(ctx)
			into, span := level.ProgressWithThresholds(0, t)
			return &gamdomain.Profile{
				UserID: userID, TotalXP: 0, Level: 1,
				XPIntoCurrentLevel: into, XPForNextLevel: span, AvatarTier: 0,
			}, nil
		}
		return nil, err
	}
	t := r.getLevelThresholds(ctx)
	lv := level.FromTotalXPWithThresholds(totalXP, t)
	into, span := level.ProgressWithThresholds(totalXP, t)
	return &gamdomain.Profile{
		UserID: userID, TotalXP: totalXP, Level: lv,
		XPIntoCurrentLevel: into, XPForNextLevel: span, AvatarTier: av,
	}, nil
}

func (r *PG) ListXPHistory(ctx context.Context, userID uuid.UUID, limit, offset int) ([]gamdomain.XPLedgerRow, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, user_id, delta_xp, reason, source_type, source_id, idempotency_key, created_at
		FROM xp_ledger WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3
	`, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []gamdomain.XPLedgerRow
	for rows.Next() {
		var x gamdomain.XPLedgerRow
		var st *string
		var sid *uuid.UUID
		if err := rows.Scan(&x.ID, &x.UserID, &x.DeltaXP, &x.Reason, &st, &sid, &x.IdempotencyKey, &x.CreatedAt); err != nil {
			return nil, err
		}
		x.SourceType = st
		if sid != nil {
			x.SourceID = sid
		}
		out = append(out, x)
	}
	return out, rows.Err()
}

func (r *PG) ListBadgeDefinitions(ctx context.Context) ([]gamdomain.BadgeDefinition, error) {
	rows, err := r.pool.Query(ctx, `SELECT id, code, title, description, rarity, icon_key FROM badge_definitions ORDER BY code`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []gamdomain.BadgeDefinition
	for rows.Next() {
		var b gamdomain.BadgeDefinition
		if err := rows.Scan(&b.ID, &b.Code, &b.Title, &b.Description, &b.Rarity, &b.IconKey); err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

func (r *PG) ListUserBadges(ctx context.Context, userID uuid.UUID) ([]gamdomain.UserBadge, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT badge_id, unlocked_at FROM user_badges WHERE user_id = $1 ORDER BY unlocked_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []gamdomain.UserBadge
	for rows.Next() {
		var ub gamdomain.UserBadge
		if err := rows.Scan(&ub.BadgeID, &ub.UnlockedAt); err != nil {
			return nil, err
		}
		out = append(out, ub)
	}
	return out, rows.Err()
}

func (r *PG) ListMissionDefinitions(ctx context.Context) ([]gamdomain.MissionDefinition, error) {
	rows, err := r.pool.Query(ctx, `SELECT id, code, title, description, period, target_value, reward_xp FROM mission_definitions ORDER BY period, code`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []gamdomain.MissionDefinition
	for rows.Next() {
		var m gamdomain.MissionDefinition
		if err := rows.Scan(&m.ID, &m.Code, &m.Title, &m.Description, &m.Period, &m.TargetValue, &m.RewardXP); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (r *PG) ListUserMissionProgress(ctx context.Context, userID uuid.UUID) ([]gamdomain.UserMissionProgress, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT mission_id, current_value, status, window_start, window_end
		FROM user_mission_state WHERE user_id = $1 ORDER BY window_start DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []gamdomain.UserMissionProgress
	for rows.Next() {
		var p gamdomain.UserMissionProgress
		var st string
		var ws, we *time.Time
		if err := rows.Scan(&p.MissionID, &p.CurrentValue, &st, &ws, &we); err != nil {
			return nil, err
		}
		p.Status = gamdomain.MissionStatus(st)
		p.WindowStart = ws
		p.WindowEnd = we
		out = append(out, p)
	}
	return out, rows.Err()
}

func (r *PG) ClaimMission(ctx context.Context, userID, missionID uuid.UUID) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var rowID uuid.UUID
	var reward int
	err = tx.QueryRow(ctx, `
		SELECT ums.id, md.reward_xp
		FROM user_mission_state ums
		JOIN mission_definitions md ON md.id = ums.mission_id
		WHERE ums.user_id = $1 AND ums.mission_id = $2 AND ums.status = 'completed'
		ORDER BY ums.window_start DESC
		LIMIT 1
		FOR UPDATE OF ums
	`, userID, missionID).Scan(&rowID, &reward)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("mission not ready to claim")
		}
		return err
	}
	_, err = tx.Exec(ctx, `UPDATE user_mission_state SET status = 'claimed', updated_at = NOW() WHERE id = $1`, rowID)
	if err != nil {
		return err
	}
	idem := fmt.Sprintf("xp:mission_claim:%s:%s", userID.String(), missionID.String())
	tag, err := tx.Exec(ctx, `
		INSERT INTO xp_ledger (user_id, delta_xp, reason, source_type, source_id, idempotency_key)
		VALUES ($1, $2, 'mission_claim', 'mission', $3, $4)
		ON CONFLICT (idempotency_key) DO NOTHING
	`, userID, reward, missionID, idem)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return tx.Commit(ctx)
	}
	var total int
	_ = tx.QueryRow(ctx, `SELECT COALESCE(total_xp,0) FROM gamification_profiles WHERE user_id = $1 FOR UPDATE`, userID).Scan(&total)
	newTotal := total + reward
	lv := level.FromTotalXPWithThresholds(newTotal, r.getLevelThresholds(ctx))
	_, err = tx.Exec(ctx, `
		INSERT INTO gamification_profiles (user_id, total_xp, current_level, updated_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (user_id) DO UPDATE SET total_xp = $2, current_level = $3, updated_at = NOW()
	`, userID, newTotal, lv)
	if err != nil {
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return err
	}
	r.incrRedisXP(ctx, userID, reward, nil)
	return nil
}

const xpWorkoutPRBonus = 15

// workoutHasPersonalRecord is true if any exercise in this workout has max set weight above all prior finished workouts for that exercise.
func (r *PG) workoutHasPersonalRecord(ctx context.Context, tx pgx.Tx, userID, workoutID uuid.UUID) (bool, error) {
	var ok bool
	err := tx.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1
			FROM (
				SELECT el.exercise_id, MAX(el.weight_kg) AS cur_w
				FROM exercise_logs el
				WHERE el.workout_id = $1
				  AND el.reps IS NOT NULL AND el.reps > 0
				  AND el.weight_kg IS NOT NULL
				GROUP BY el.exercise_id
			) cur
			LEFT JOIN (
				SELECT el.exercise_id, MAX(el.weight_kg) AS prev_w
				FROM exercise_logs el
				INNER JOIN workouts w ON w.id = el.workout_id
				WHERE w.user_id = $2 AND w.finished_at IS NOT NULL AND w.id <> $1
				  AND el.reps IS NOT NULL AND el.reps > 0
				  AND el.weight_kg IS NOT NULL
				GROUP BY el.exercise_id
			) prev ON prev.exercise_id = cur.exercise_id
			WHERE cur.cur_w > COALESCE(prev.prev_w, 0)
		)
	`, workoutID, userID).Scan(&ok)
	return ok, err
}

// ApplyWorkoutReward idempotent XP grant for a finished workout (volume matches Flutter preview curve).
func (r *PG) ApplyWorkoutReward(ctx context.Context, userID, workoutID uuid.UUID, performedVolumeKg float64) error {
	deltaXP := xp.DeltaFromVolume(performedVolumeKg, r.getXPCurve(ctx))
	idem := fmt.Sprintf("xp:workout:%s", workoutID.String())

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var ledgerID uuid.UUID
	err = tx.QueryRow(ctx, `
		INSERT INTO xp_ledger (user_id, delta_xp, reason, source_type, source_id, idempotency_key)
		VALUES ($1, $2, 'workout_finished', 'workout', $3, $4)
		ON CONFLICT (idempotency_key) DO NOTHING
		RETURNING id
	`, userID, deltaXP, workoutID, idem).Scan(&ledgerID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return tx.Commit(ctx)
		}
		return err
	}

	prBonus := 0
	hasPR, err := r.workoutHasPersonalRecord(ctx, tx, userID, workoutID)
	if err != nil {
		return err
	}
	if hasPR {
		prIDem := fmt.Sprintf("xp:pr_bonus:%s", workoutID.String())
		var prRow uuid.UUID
		err = tx.QueryRow(ctx, `
			INSERT INTO xp_ledger (user_id, delta_xp, reason, source_type, source_id, idempotency_key)
			VALUES ($1, $2, 'workout_pr_bonus', 'workout', $3, $4)
			ON CONFLICT (idempotency_key) DO NOTHING
			RETURNING id
		`, userID, xpWorkoutPRBonus, workoutID, prIDem).Scan(&prRow)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		if err == nil {
			prBonus = xpWorkoutPRBonus
		}
		var prCnt int
		_ = tx.QueryRow(ctx, `SELECT COUNT(*) FROM xp_ledger WHERE user_id = $1 AND reason = 'workout_pr_bonus'`, userID).Scan(&prCnt)
		if prCnt >= 1 {
			_, _ = tx.Exec(ctx, `
				INSERT INTO user_badges (user_id, badge_id, unlocked_at)
				SELECT $1, id, NOW() FROM badge_definitions WHERE code = 'pr_first'
				ON CONFLICT DO NOTHING
			`, userID)
		}
		if prCnt >= 10 {
			_, _ = tx.Exec(ctx, `
				INSERT INTO user_badges (user_id, badge_id, unlocked_at)
				SELECT $1, id, NOW() FROM badge_definitions WHERE code = 'pr_veteran'
				ON CONFLICT DO NOTHING
			`, userID)
		}
	}

	var totalXP int
	err = tx.QueryRow(ctx, `SELECT COALESCE(total_xp, 0) FROM gamification_profiles WHERE user_id = $1 FOR UPDATE`, userID).Scan(&totalXP)
	if err != nil {
		if !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		totalXP = 0
	}
	newTotal := totalXP + deltaXP + prBonus
	lv := level.FromTotalXPWithThresholds(newTotal, r.getLevelThresholds(ctx))
	_, err = tx.Exec(ctx, `
		INSERT INTO gamification_profiles (user_id, total_xp, current_level, avatar_tier, updated_at)
		VALUES ($1, $2, $3, 0, NOW())
		ON CONFLICT (user_id) DO UPDATE SET
			total_xp = EXCLUDED.total_xp,
			current_level = EXCLUDED.current_level,
			updated_at = NOW()
	`, userID, newTotal, lv)
	if err != nil {
		return err
	}

	var cnt int
	_ = tx.QueryRow(ctx, `SELECT COUNT(*) FROM xp_ledger WHERE user_id = $1 AND reason = 'workout_finished'`, userID).Scan(&cnt)
	if cnt == 1 {
		_, _ = tx.Exec(ctx, `
			INSERT INTO user_badges (user_id, badge_id, unlocked_at)
			SELECT $1, id, NOW() FROM badge_definitions WHERE code = 'first_workout'
			ON CONFLICT DO NOTHING
		`, userID)
	}

	now := time.Now().UTC()
	dayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	dayEnd := dayStart.Add(24 * time.Hour)
	var dailyID uuid.UUID
	var dailyTarget int
	err = tx.QueryRow(ctx, `SELECT id, target_value FROM mission_definitions WHERE code = 'daily_workout' LIMIT 1`).Scan(&dailyID, &dailyTarget)
	if err == nil {
		_, _ = tx.Exec(ctx, `
			INSERT INTO user_mission_state (user_id, mission_id, current_value, status, window_start, window_end, updated_at)
			VALUES ($1, $2, 1, CASE WHEN $5 <= 1 THEN 'completed' ELSE 'active' END, $3, $4, NOW())
			ON CONFLICT (user_id, mission_id, window_start) DO UPDATE SET
				current_value = LEAST($5, user_mission_state.current_value + 1),
				status = CASE WHEN LEAST($5, user_mission_state.current_value + 1) >= $5 THEN 'completed' ELSE 'active' END,
				updated_at = NOW()
		`, userID, dailyID, dayStart, dayEnd, dailyTarget)
	}

	ws, we := weekBoundsUTC(now)
	var weekID uuid.UUID
	var weekTarget int
	err = tx.QueryRow(ctx, `SELECT id, target_value FROM mission_definitions WHERE code = 'weekly_volume' LIMIT 1`).Scan(&weekID, &weekTarget)
	if err == nil {
		_, _ = tx.Exec(ctx, `
			INSERT INTO user_mission_state (user_id, mission_id, current_value, status, window_start, window_end, updated_at)
			VALUES ($1, $2, 1, CASE WHEN $5 <= 1 THEN 'completed' ELSE 'active' END, $3, $4, NOW())
			ON CONFLICT (user_id, mission_id, window_start) DO UPDATE SET
				current_value = LEAST($5, user_mission_state.current_value + 1),
				status = CASE WHEN LEAST($5, user_mission_state.current_value + 1) >= $5 THEN 'completed' ELSE 'active' END,
				updated_at = NOW()
		`, userID, weekID, ws, we, weekTarget)
	}

	if err := tx.Commit(ctx); err != nil {
		return err
	}
	r.postXPLeaderboards(ctx, userID, deltaXP+prBonus, workoutID)
	return nil
}

func weekBoundsUTC(now time.Time) (start, end time.Time) {
	u := now.UTC()
	wd := int(u.Weekday())
	daysFromMonday := (wd + 6) % 7
	start = time.Date(u.Year(), u.Month(), u.Day(), 0, 0, 0, 0, time.UTC).AddDate(0, 0, -daysFromMonday)
	end = start.AddDate(0, 0, 7)
	return start, end
}

func (r *PG) LeaderboardGlobalWeekly(ctx context.Context, weekStart, weekEnd time.Time, limit int, currentUserID uuid.UUID) ([]gamdomain.LeaderboardEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	rows, err := r.pool.Query(ctx, `
		WITH scores AS (
			SELECT user_id, SUM(delta_xp)::bigint AS score
			FROM xp_ledger
			WHERE created_at >= $1 AND created_at < $2
			GROUP BY user_id
		)
		SELECT s.user_id, s.score, COALESCE(p.display_name, ''), p.avatar_url
		FROM scores s
		LEFT JOIN user_profiles p ON p.user_id = s.user_id
		ORDER BY s.score DESC
		LIMIT $3
	`, weekStart, weekEnd, limit)
	if err != nil {
		return nil, err
	}
	return scanLeaderboardRows(rows, currentUserID)
}

func (r *PG) LeaderboardGlobalAllTime(ctx context.Context, limit int, currentUserID uuid.UUID) ([]gamdomain.LeaderboardEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	rows, err := r.pool.Query(ctx, `
		WITH scores AS (
			SELECT user_id, SUM(delta_xp)::bigint AS score
			FROM xp_ledger
			GROUP BY user_id
		)
		SELECT s.user_id, s.score, COALESCE(p.display_name, ''), p.avatar_url
		FROM scores s
		LEFT JOIN user_profiles p ON p.user_id = s.user_id
		ORDER BY s.score DESC
		LIMIT $1
	`, limit)
	if err != nil {
		return nil, err
	}
	return scanLeaderboardRows(rows, currentUserID)
}

func (r *PG) LeaderboardGymWeekly(ctx context.Context, gymID uuid.UUID, weekStart, weekEnd time.Time, limit int, currentUserID uuid.UUID) ([]gamdomain.LeaderboardEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	rows, err := r.pool.Query(ctx, `
		WITH scores AS (
			SELECT l.user_id, SUM(l.delta_xp)::bigint AS score
			FROM xp_ledger l
			INNER JOIN workouts w ON w.id = l.source_id AND l.source_type = 'workout'
			WHERE l.created_at >= $1 AND l.created_at < $2 AND w.gym_id = $4
			GROUP BY l.user_id
		)
		SELECT s.user_id, s.score, COALESCE(p.display_name, ''), p.avatar_url
		FROM scores s
		LEFT JOIN user_profiles p ON p.user_id = s.user_id
		ORDER BY s.score DESC
		LIMIT $3
	`, weekStart, weekEnd, limit, gymID)
	if err != nil {
		return nil, err
	}
	return scanLeaderboardRows(rows, currentUserID)
}

func (r *PG) LeaderboardGymAllTime(ctx context.Context, gymID uuid.UUID, limit int, currentUserID uuid.UUID) ([]gamdomain.LeaderboardEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	rows, err := r.pool.Query(ctx, `
		WITH scores AS (
			SELECT l.user_id, SUM(l.delta_xp)::bigint AS score
			FROM xp_ledger l
			INNER JOIN workouts w ON w.id = l.source_id AND l.source_type = 'workout'
			WHERE w.gym_id = $2
			GROUP BY l.user_id
		)
		SELECT s.user_id, s.score, COALESCE(p.display_name, ''), p.avatar_url
		FROM scores s
		LEFT JOIN user_profiles p ON p.user_id = s.user_id
		ORDER BY s.score DESC
		LIMIT $1
	`, limit, gymID)
	if err != nil {
		return nil, err
	}
	return scanLeaderboardRows(rows, currentUserID)
}

func (r *PG) LeaderboardTrainerClientsWeekly(ctx context.Context, trainerID uuid.UUID, weekStart, weekEnd time.Time, limit int, currentUserID uuid.UUID) ([]gamdomain.LeaderboardEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	rows, err := r.pool.Query(ctx, `
		WITH scores AS (
			SELECT l.user_id, SUM(l.delta_xp)::bigint AS score
			FROM xp_ledger l
			INNER JOIN trainer_clients tc ON tc.client_id = l.user_id AND tc.trainer_id = $4 AND tc.status = 'active'
			WHERE l.created_at >= $1 AND l.created_at < $2
			GROUP BY l.user_id
		)
		SELECT s.user_id, s.score, COALESCE(p.display_name, ''), p.avatar_url
		FROM scores s
		LEFT JOIN user_profiles p ON p.user_id = s.user_id
		ORDER BY s.score DESC
		LIMIT $3
	`, weekStart, weekEnd, limit, trainerID)
	if err != nil {
		return nil, err
	}
	return scanLeaderboardRows(rows, currentUserID)
}

func (r *PG) LeaderboardTrainerClientsAllTime(ctx context.Context, trainerID uuid.UUID, limit int, currentUserID uuid.UUID) ([]gamdomain.LeaderboardEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	rows, err := r.pool.Query(ctx, `
		WITH scores AS (
			SELECT l.user_id, SUM(l.delta_xp)::bigint AS score
			FROM xp_ledger l
			INNER JOIN trainer_clients tc ON tc.client_id = l.user_id AND tc.trainer_id = $2 AND tc.status = 'active'
			GROUP BY l.user_id
		)
		SELECT s.user_id, s.score, COALESCE(p.display_name, ''), p.avatar_url
		FROM scores s
		LEFT JOIN user_profiles p ON p.user_id = s.user_id
		ORDER BY s.score DESC
		LIMIT $1
	`, limit, trainerID)
	if err != nil {
		return nil, err
	}
	return scanLeaderboardRows(rows, currentUserID)
}

func scanLeaderboardRows(rows pgx.Rows, currentUserID uuid.UUID) ([]gamdomain.LeaderboardEntry, error) {
	defer rows.Close()
	var out []gamdomain.LeaderboardEntry
	rank := 1
	for rows.Next() {
		var uid uuid.UUID
		var score int64
		var dn string
		var av *string
		if err := rows.Scan(&uid, &score, &dn, &av); err != nil {
			return nil, err
		}
		out = append(out, gamdomain.LeaderboardEntry{
			Rank:          rank,
			UserID:        uid,
			DisplayName:   dn,
			Score:         int(score),
			AvatarURL:     av,
			IsCurrentUser: uid == currentUserID,
		})
		rank++
	}
	return out, rows.Err()
}

func (r *PG) GetUserFeaturePreferences(ctx context.Context, userID uuid.UUID) (gamdomain.UserFeaturePreferences, error) {
	var p gamdomain.UserFeaturePreferences
	err := r.pool.QueryRow(ctx, `
		SELECT xp_enabled, badges_enabled, leaderboard_enabled, trainer_ranking_enabled
		FROM user_gamification_prefs WHERE user_id = $1
	`, userID).Scan(&p.XPEnabled, &p.BadgesEnabled, &p.LeaderboardEnabled, &p.TrainerRankingEnabled)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return gamdomain.DefaultUserFeaturePreferences(), nil
		}
		return gamdomain.UserFeaturePreferences{}, err
	}
	return p, nil
}

func (r *PG) UpsertUserFeaturePreferences(ctx context.Context, userID uuid.UUID, p gamdomain.UserFeaturePreferences) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO user_gamification_prefs (user_id, xp_enabled, badges_enabled, leaderboard_enabled, trainer_ranking_enabled, updated_at)
		VALUES ($1, $2, $3, $4, $5, NOW())
		ON CONFLICT (user_id) DO UPDATE SET
			xp_enabled = EXCLUDED.xp_enabled,
			badges_enabled = EXCLUDED.badges_enabled,
			leaderboard_enabled = EXCLUDED.leaderboard_enabled,
			trainer_ranking_enabled = EXCLUDED.trainer_ranking_enabled,
			updated_at = NOW()
	`, userID, p.XPEnabled, p.BadgesEnabled, p.LeaderboardEnabled, p.TrainerRankingEnabled)
	return err
}
