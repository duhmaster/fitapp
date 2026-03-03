package repository

import (
	"context"
	"errors"
	"time"

	"github.com/fitflow/fitflow/internal/user/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// MetricRepository implements domain.MetricRepository.
type MetricRepository struct {
	pool *pgxpool.Pool
}

// NewMetricRepository creates a new MetricRepository.
func NewMetricRepository(pool *pgxpool.Pool) *MetricRepository {
	return &MetricRepository{pool: pool}
}

// Create inserts a new metric record.
func (r *MetricRepository) Create(ctx context.Context, userID uuid.UUID, heightCm, weightKg *float64, recordedAt time.Time) (*domain.Metric, error) {
	query := `
		INSERT INTO user_metrics (user_id, height_cm, weight_kg, recorded_at)
		VALUES ($1, $2, $3, $4)
		RETURNING id, user_id, height_cm, weight_kg, recorded_at
	`
	var m domain.Metric
	err := r.pool.QueryRow(ctx, query, userID, heightCm, weightKg, recordedAt).Scan(
		&m.ID, &m.UserID, &m.HeightCm, &m.WeightKg, &m.RecordedAt,
	)
	if err != nil {
		return nil, err
	}
	return &m, nil
}

// GetLatestByUserID returns the most recent metric for a user.
func (r *MetricRepository) GetLatestByUserID(ctx context.Context, userID uuid.UUID) (*domain.Metric, error) {
	query := `
		SELECT id, user_id, height_cm, weight_kg, recorded_at
		FROM user_metrics
		WHERE user_id = $1
		ORDER BY recorded_at DESC
		LIMIT 1
	`
	var m domain.Metric
	err := r.pool.QueryRow(ctx, query, userID).Scan(
		&m.ID, &m.UserID, &m.HeightCm, &m.WeightKg, &m.RecordedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &m, nil
}

// ListByUserID returns metric history for a user.
func (r *MetricRepository) ListByUserID(ctx context.Context, userID uuid.UUID, limit int) ([]*domain.Metric, error) {
	if limit <= 0 {
		limit = 50
	}
	query := `
		SELECT id, user_id, height_cm, weight_kg, recorded_at
		FROM user_metrics
		WHERE user_id = $1
		ORDER BY recorded_at DESC
		LIMIT $2
	`
	rows, err := r.pool.Query(ctx, query, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var metrics []*domain.Metric
	for rows.Next() {
		var m domain.Metric
		if err := rows.Scan(&m.ID, &m.UserID, &m.HeightCm, &m.WeightKg, &m.RecordedAt); err != nil {
			return nil, err
		}
		metrics = append(metrics, &m)
	}
	return metrics, rows.Err()
}
