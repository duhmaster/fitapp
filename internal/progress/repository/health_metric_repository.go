package repository

import (
	"context"
	"time"

	progressdomain "github.com/fitflow/fitflow/internal/progress/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type HealthMetricRepository struct {
	pool *pgxpool.Pool
}

func NewHealthMetricRepository(pool *pgxpool.Pool) *HealthMetricRepository {
	return &HealthMetricRepository{pool: pool}
}

func (r *HealthMetricRepository) Create(ctx context.Context, userID uuid.UUID, metricType string, value *float64, recordedAt time.Time, source *string) (*progressdomain.HealthMetric, error) {
	query := `
		INSERT INTO health_metrics (user_id, metric_type, value, recorded_at, source)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, user_id, metric_type, value, recorded_at, source
	`
	var h progressdomain.HealthMetric
	err := r.pool.QueryRow(ctx, query, userID, metricType, value, recordedAt, source).Scan(
		&h.ID, &h.UserID, &h.MetricType, &h.Value, &h.RecordedAt, &h.Source,
	)
	if err != nil {
		return nil, err
	}
	return &h, nil
}

func (r *HealthMetricRepository) ListByUserID(ctx context.Context, userID uuid.UUID, metricType string, limit, offset int) ([]*progressdomain.HealthMetric, error) {
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
		SELECT id, user_id, metric_type, value, recorded_at, source
		FROM health_metrics
		WHERE user_id = $1 AND ($2 = '' OR metric_type = $2)
		ORDER BY recorded_at DESC
		LIMIT $3 OFFSET $4
	`
	rows, err := r.pool.Query(ctx, query, userID, metricType, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*progressdomain.HealthMetric
	for rows.Next() {
		var h progressdomain.HealthMetric
		if err := rows.Scan(&h.ID, &h.UserID, &h.MetricType, &h.Value, &h.RecordedAt, &h.Source); err != nil {
			return nil, err
		}
		list = append(list, &h)
	}
	return list, rows.Err()
}
