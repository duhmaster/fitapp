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

// BodyMeasurementRepository implements domain.BodyMeasurementRepository.
type BodyMeasurementRepository struct {
	pool *pgxpool.Pool
}

// NewBodyMeasurementRepository creates a new BodyMeasurementRepository.
func NewBodyMeasurementRepository(pool *pgxpool.Pool) *BodyMeasurementRepository {
	return &BodyMeasurementRepository{pool: pool}
}

// Create inserts a new body measurement.
func (r *BodyMeasurementRepository) Create(ctx context.Context, userID uuid.UUID, recordedAt time.Time, weightKg float64, bodyFatPct, heightCm *float64) (*domain.BodyMeasurement, error) {
	query := `
		INSERT INTO body_measurements (user_id, recorded_at, weight_kg, body_fat_pct, height_cm)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, user_id, recorded_at, weight_kg, body_fat_pct, height_cm
	`
	var m domain.BodyMeasurement
	err := r.pool.QueryRow(ctx, query, userID, recordedAt, weightKg, bodyFatPct, heightCm).Scan(
		&m.ID, &m.UserID, &m.RecordedAt, &m.WeightKg, &m.BodyFatPct, &m.HeightCm,
	)
	if err != nil {
		return nil, err
	}
	return &m, nil
}

// GetByID returns a body measurement by ID.
func (r *BodyMeasurementRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.BodyMeasurement, error) {
	query := `
		SELECT id, user_id, recorded_at, weight_kg, body_fat_pct, height_cm
		FROM body_measurements
		WHERE id = $1
	`
	var m domain.BodyMeasurement
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&m.ID, &m.UserID, &m.RecordedAt, &m.WeightKg, &m.BodyFatPct, &m.HeightCm,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &m, nil
}

// ListByUserID returns body measurements for a user, newest first.
func (r *BodyMeasurementRepository) ListByUserID(ctx context.Context, userID uuid.UUID, limit int) ([]*domain.BodyMeasurement, error) {
	if limit <= 0 {
		limit = 100
	}
	query := `
		SELECT id, user_id, recorded_at, weight_kg, body_fat_pct, height_cm
		FROM body_measurements
		WHERE user_id = $1
		ORDER BY recorded_at DESC
		LIMIT $2
	`
	rows, err := r.pool.Query(ctx, query, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*domain.BodyMeasurement
	for rows.Next() {
		var m domain.BodyMeasurement
		if err := rows.Scan(&m.ID, &m.UserID, &m.RecordedAt, &m.WeightKg, &m.BodyFatPct, &m.HeightCm); err != nil {
			return nil, err
		}
		list = append(list, &m)
	}
	return list, rows.Err()
}

// Update updates a body measurement.
func (r *BodyMeasurementRepository) Update(ctx context.Context, id uuid.UUID, recordedAt time.Time, weightKg float64, bodyFatPct, heightCm *float64) (*domain.BodyMeasurement, error) {
	query := `
		UPDATE body_measurements
		SET recorded_at = $2, weight_kg = $3, body_fat_pct = $4, height_cm = $5
		WHERE id = $1
		RETURNING id, user_id, recorded_at, weight_kg, body_fat_pct, height_cm
	`
	var m domain.BodyMeasurement
	err := r.pool.QueryRow(ctx, query, id, recordedAt, weightKg, bodyFatPct, heightCm).Scan(
		&m.ID, &m.UserID, &m.RecordedAt, &m.WeightKg, &m.BodyFatPct, &m.HeightCm,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &m, nil
}

// Delete deletes a body measurement.
func (r *BodyMeasurementRepository) Delete(ctx context.Context, id uuid.UUID) error {
	res, err := r.pool.Exec(ctx, `DELETE FROM body_measurements WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}
