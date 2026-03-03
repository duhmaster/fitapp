package repository

import (
	"context"
	"time"

	progressdomain "github.com/fitflow/fitflow/internal/progress/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type BodyFatTrackingRepository struct {
	pool *pgxpool.Pool
}

func NewBodyFatTrackingRepository(pool *pgxpool.Pool) *BodyFatTrackingRepository {
	return &BodyFatTrackingRepository{pool: pool}
}

func (r *BodyFatTrackingRepository) Create(ctx context.Context, userID uuid.UUID, bodyFatPct float64, recordedAt time.Time) (*progressdomain.BodyFatTracking, error) {
	query := `
		INSERT INTO body_fat_tracking (user_id, body_fat_pct, recorded_at)
		VALUES ($1, $2, $3)
		RETURNING id, user_id, body_fat_pct, recorded_at
	`
	var b progressdomain.BodyFatTracking
	err := r.pool.QueryRow(ctx, query, userID, bodyFatPct, recordedAt).Scan(
		&b.ID, &b.UserID, &b.BodyFatPct, &b.RecordedAt,
	)
	if err != nil {
		return nil, err
	}
	return &b, nil
}

func (r *BodyFatTrackingRepository) ListByUserID(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*progressdomain.BodyFatTracking, error) {
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
		SELECT id, user_id, body_fat_pct, recorded_at
		FROM body_fat_tracking
		WHERE user_id = $1
		ORDER BY recorded_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*progressdomain.BodyFatTracking
	for rows.Next() {
		var b progressdomain.BodyFatTracking
		if err := rows.Scan(&b.ID, &b.UserID, &b.BodyFatPct, &b.RecordedAt); err != nil {
			return nil, err
		}
		list = append(list, &b)
	}
	return list, rows.Err()
}
