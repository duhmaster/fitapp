package repository

import (
	"context"
	"time"

	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type LoadSnapshotRepository struct {
	pool *pgxpool.Pool
}

func NewLoadSnapshotRepository(pool *pgxpool.Pool) *LoadSnapshotRepository {
	return &LoadSnapshotRepository{pool: pool}
}

func (r *LoadSnapshotRepository) UpsertHour(ctx context.Context, gymID uuid.UUID, hourBucket time.Time, loadCount int) error {
	query := `
		INSERT INTO gym_load_snapshots (gym_id, load_count, hour_bucket)
		VALUES ($1, $2, $3)
		ON CONFLICT (gym_id, hour_bucket) DO UPDATE SET
			load_count = EXCLUDED.load_count
	`
	_, err := r.pool.Exec(ctx, query, gymID, loadCount, hourBucket)
	return err
}

func (r *LoadSnapshotRepository) ListByGymID(ctx context.Context, gymID uuid.UUID, limit int) ([]*gymdomain.LoadSnapshot, error) {
	if limit <= 0 {
		limit = 24
	}
	if limit > 168 {
		limit = 168
	}

	query := `
		SELECT id, gym_id, load_count, hour_bucket
		FROM gym_load_snapshots
		WHERE gym_id = $1
		ORDER BY hour_bucket DESC
		LIMIT $2
	`
	rows, err := r.pool.Query(ctx, query, gymID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []*gymdomain.LoadSnapshot
	for rows.Next() {
		var s gymdomain.LoadSnapshot
		if err := rows.Scan(&s.ID, &s.GymID, &s.LoadCount, &s.HourBucket); err != nil {
			return nil, err
		}
		out = append(out, &s)
	}
	return out, rows.Err()
}
