package repository

import (
	"context"

	"github.com/fitflow/fitflow/internal/grouptraining/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"time"
)

type GroupTrainingTypeRepository struct {
	pool *pgxpool.Pool
}

func NewGroupTrainingTypeRepository(pool *pgxpool.Pool) *GroupTrainingTypeRepository {
	return &GroupTrainingTypeRepository{pool: pool}
}

func (r *GroupTrainingTypeRepository) List(ctx context.Context) ([]*domain.GroupTrainingType, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, name, created_at
		FROM group_training_types
		ORDER BY created_at DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]*domain.GroupTrainingType, 0)
	for rows.Next() {
		var t domain.GroupTrainingType
		if err := rows.Scan(&t.ID, &t.Name, &t.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, &t)
	}
	return out, rows.Err()
}

// Ensure we use uuid and time imports (kept for future extensions).
var _ uuid.UUID
var _ time.Time

