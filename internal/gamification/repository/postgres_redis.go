package repository

import (
	"context"
	"time"

	"github.com/fitflow/fitflow/internal/gamification/leaderboard"
	"github.com/google/uuid"
)

func (r *PG) listTrainerIDsForClient(ctx context.Context, clientID uuid.UUID) []uuid.UUID {
	rows, err := r.pool.Query(ctx, `
		SELECT trainer_id FROM trainer_clients WHERE client_id = $1 AND status = 'active'
	`, clientID)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return out
		}
		out = append(out, id)
	}
	return out
}

func (r *PG) incrRedisXP(ctx context.Context, userID uuid.UUID, delta int, gymID *uuid.UUID) {
	if r.redis == nil || !r.redis.OK() || delta == 0 {
		return
	}
	ids := r.listTrainerIDsForClient(ctx, userID)
	wk := leaderboard.WeekKey(time.Now().UTC())
	_ = r.redis.IncrUserXP(ctx, userID, delta, wk, gymID, ids)
}

func (r *PG) postXPLeaderboards(ctx context.Context, userID uuid.UUID, deltaXP int, workoutID uuid.UUID) {
	var gymID *uuid.UUID
	_ = r.pool.QueryRow(ctx, `SELECT gym_id FROM workouts WHERE id = $1`, workoutID).Scan(&gymID)
	r.incrRedisXP(ctx, userID, deltaXP, gymID)
}
