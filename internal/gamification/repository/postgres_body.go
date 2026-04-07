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

const (
	xpBodyMeasurementLog = 5
)

// ApplyBodyMeasurementReward idempotent XP for logging body measurements + weekly mission + badges.
func (r *PG) ApplyBodyMeasurementReward(ctx context.Context, userID, measurementID uuid.UUID) error {
	idem := fmt.Sprintf("xp:body_measurement:%s", measurementID.String())

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var ledgerID uuid.UUID
	err = tx.QueryRow(ctx, `
		INSERT INTO xp_ledger (user_id, delta_xp, reason, source_type, source_id, idempotency_key)
		VALUES ($1, $2, 'body_measurement_log', 'body_measurement', $3, $4)
		ON CONFLICT (idempotency_key) DO NOTHING
		RETURNING id
	`, userID, xpBodyMeasurementLog, measurementID, idem).Scan(&ledgerID)
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
	newTotal := totalXP + xpBodyMeasurementLog
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

	var bmCount int
	_ = tx.QueryRow(ctx, `SELECT COUNT(*) FROM body_measurements WHERE user_id = $1`, userID).Scan(&bmCount)
	if bmCount >= 1 {
		_, _ = tx.Exec(ctx, `
			INSERT INTO user_badges (user_id, badge_id, unlocked_at)
			SELECT $1, id, NOW() FROM badge_definitions WHERE code = 'body_measurement_first'
			ON CONFLICT DO NOTHING
		`, userID)
	}
	if bmCount >= 10 {
		_, _ = tx.Exec(ctx, `
			INSERT INTO user_badges (user_id, badge_id, unlocked_at)
			SELECT $1, id, NOW() FROM badge_definitions WHERE code = 'body_measurement_10'
			ON CONFLICT DO NOTHING
		`, userID)
	}

	now := time.Now().UTC()
	ws, we := weekBoundsUTC(now)
	var mid uuid.UUID
	var mtgt int
	err = tx.QueryRow(ctx, `SELECT id, target_value FROM mission_definitions WHERE code = 'weekly_body_log' LIMIT 1`).Scan(&mid, &mtgt)
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
	r.incrRedisXP(ctx, userID, xpBodyMeasurementLog, nil)
	return nil
}
