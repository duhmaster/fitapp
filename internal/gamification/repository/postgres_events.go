package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/fitflow/fitflow/internal/gamification/level"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

const groupTrainingRegXP = 5

// ApplyGroupTrainingRegistrationReward grants small XP once per (user, training) and bumps weekly mission.
func (r *PG) ApplyGroupTrainingRegistrationReward(ctx context.Context, userID, trainingID uuid.UUID) error {
	idem := fmt.Sprintf("xp:group_reg:%s:%s", trainingID.String(), userID.String())
	delta := groupTrainingRegXP

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var lid uuid.UUID
	err = tx.QueryRow(ctx, `
		INSERT INTO xp_ledger (user_id, delta_xp, reason, source_type, source_id, idempotency_key)
		VALUES ($1, $2, 'group_training_register', 'group_training', $3, $4)
		ON CONFLICT (idempotency_key) DO NOTHING
		RETURNING id
	`, userID, delta, trainingID, idem).Scan(&lid)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return tx.Commit(ctx)
		}
		return err
	}

	var totalXP int
	err = tx.QueryRow(ctx, `SELECT COALESCE(total_xp, 0) FROM gamification_profiles WHERE user_id = $1 FOR UPDATE`, userID).Scan(&totalXP)
	if err != nil {
		if !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		totalXP = 0
	}
	newTotal := totalXP + delta
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

	now := time.Now().UTC()
	ws, we := weekBoundsUTC(now)
	var mid uuid.UUID
	var mtgt int
	err = tx.QueryRow(ctx, `SELECT id, target_value FROM mission_definitions WHERE code = 'group_training_register' LIMIT 1`).Scan(&mid, &mtgt)
	if err == nil {
		_, _ = tx.Exec(ctx, `
			INSERT INTO user_mission_state (user_id, mission_id, current_value, status, window_start, window_end, updated_at)
			VALUES ($1, $2, 1, CASE WHEN $5 <= 1 THEN 'completed' ELSE 'active' END, $3, $4, NOW())
			ON CONFLICT (user_id, mission_id, window_start) DO UPDATE SET
				current_value = LEAST($5, user_mission_state.current_value + 1),
				status = CASE WHEN LEAST($5, user_mission_state.current_value + 1) >= $5 THEN 'completed' ELSE 'active' END,
				updated_at = NOW()
		`, userID, mid, ws, we, mtgt)
	}

	if err := tx.Commit(ctx); err != nil {
		return err
	}
	r.incrRedisXP(ctx, userID, delta, nil)
	return nil
}

// ApplyGymCheckInMission updates daily gym_checkin mission (no XP until claim).
func (r *PG) ApplyGymCheckInMission(ctx context.Context, userID, gymID uuid.UUID) error {
	now := time.Now().UTC()
	dayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	dayEnd := dayStart.Add(24 * time.Hour)

	var mid uuid.UUID
	var mtgt int
	err := r.pool.QueryRow(ctx, `SELECT id, target_value FROM mission_definitions WHERE code = 'gym_checkin' LIMIT 1`).Scan(&mid, &mtgt)
	if err != nil {
		return err
	}

	_, err = r.pool.Exec(ctx, `
		INSERT INTO user_mission_state (user_id, mission_id, current_value, status, window_start, window_end, updated_at)
		VALUES ($1, $2, 1, CASE WHEN $5 <= 1 THEN 'completed' ELSE 'active' END, $3, $4, NOW())
		ON CONFLICT (user_id, mission_id, window_start) DO UPDATE SET
			current_value = LEAST($5, user_mission_state.current_value + 1),
			status = CASE WHEN LEAST($5, user_mission_state.current_value + 1) >= $5 THEN 'completed' ELSE 'active' END,
			updated_at = NOW()
	`, userID, mid, dayStart, dayEnd, mtgt)
	if err != nil {
		return err
	}
	_ = gymID
	return nil
}
