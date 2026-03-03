package repository

import (
	"context"
	"time"

	progressdomain "github.com/fitflow/fitflow/internal/progress/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type WeightTrackingRepository struct {
	pool *pgxpool.Pool
}

func NewWeightTrackingRepository(pool *pgxpool.Pool) *WeightTrackingRepository {
	return &WeightTrackingRepository{pool: pool}
}

func (r *WeightTrackingRepository) Create(ctx context.Context, userID uuid.UUID, weightKg float64, recordedAt time.Time) (*progressdomain.WeightTracking, error) {
	query := `
		INSERT INTO weight_tracking (user_id, weight_kg, recorded_at)
		VALUES ($1, $2, $3)
		RETURNING id, user_id, weight_kg, recorded_at
	`
	var w progressdomain.WeightTracking
	err := r.pool.QueryRow(ctx, query, userID, weightKg, recordedAt).Scan(
		&w.ID, &w.UserID, &w.WeightKg, &w.RecordedAt,
	)
	if err != nil {
		return nil, err
	}
	return &w, nil
}

func (r *WeightTrackingRepository) ListByUserID(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*progressdomain.WeightTracking, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT id, user_id, weight_kg, recorded_at
		FROM weight_tracking
		WHERE user_id = $1
		ORDER BY recorded_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*progressdomain.WeightTracking
	for rows.Next() {
		var w progressdomain.WeightTracking
		if err := rows.Scan(&w.ID, &w.UserID, &w.WeightKg, &w.RecordedAt); err != nil {
			return nil, err
		}
		list = append(list, &w)
	}
	return list, rows.Err()
}
