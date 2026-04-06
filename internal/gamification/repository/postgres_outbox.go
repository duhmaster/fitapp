package repository

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type workoutFinishedPayload struct {
	UserID    string  `json:"user_id"`
	WorkoutID string  `json:"workout_id"`
	VolumeKg  float64 `json:"volume_kg"`
}

func (r *PG) EnqueueWorkoutFinished(ctx context.Context, tx pgx.Tx, userID, workoutID uuid.UUID, volumeKg float64) error {
	p := workoutFinishedPayload{
		UserID:    userID.String(),
		WorkoutID: workoutID.String(),
		VolumeKg:  volumeKg,
	}
	b, err := json.Marshal(p)
	if err != nil {
		return err
	}
	idem := fmt.Sprintf("xp:workout:outbox:%s", workoutID.String())
	_, err = tx.Exec(ctx, `
		INSERT INTO gamification_outbox (event_type, idempotency_key, payload)
		VALUES ('workout_xp', $1, $2::jsonb)
		ON CONFLICT (idempotency_key) DO NOTHING
	`, idem, b)
	return err
}

func (r *PG) ProcessOutbox(ctx context.Context, limit int) (int, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, payload FROM gamification_outbox
		WHERE processed_at IS NULL
		ORDER BY created_at ASC
		LIMIT $1
	`, limit)
	if err != nil {
		return 0, err
	}
	defer rows.Close()
	var processed int
	for rows.Next() {
		var id uuid.UUID
		var raw []byte
		if err := rows.Scan(&id, &raw); err != nil {
			return processed, err
		}
		var p workoutFinishedPayload
		if err := json.Unmarshal(raw, &p); err != nil {
			continue
		}
		uid, err := uuid.Parse(p.UserID)
		if err != nil {
			continue
		}
		wid, err := uuid.Parse(p.WorkoutID)
		if err != nil {
			continue
		}
		if err := r.ApplyWorkoutReward(ctx, uid, wid, p.VolumeKg); err != nil {
			continue
		}
		_, err = r.pool.Exec(ctx, `UPDATE gamification_outbox SET processed_at = NOW() WHERE id = $1`, id)
		if err != nil {
			return processed, err
		}
		processed++
	}
	return processed, rows.Err()
}
