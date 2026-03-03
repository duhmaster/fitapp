package repository

import (
	"context"
	"time"

	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type CheckInRepository struct {
	pool *pgxpool.Pool
}

func NewCheckInRepository(pool *pgxpool.Pool) *CheckInRepository {
	return &CheckInRepository{pool: pool}
}

func (r *CheckInRepository) Create(ctx context.Context, userID, gymID uuid.UUID, checkedInAt time.Time) (*gymdomain.CheckIn, error) {
	query := `
		INSERT INTO gym_check_ins (user_id, gym_id, checked_in_at)
		VALUES ($1, $2, $3)
		RETURNING id, user_id, gym_id, checked_in_at
	`
	var c gymdomain.CheckIn
	err := r.pool.QueryRow(ctx, query, userID, gymID, checkedInAt).Scan(&c.ID, &c.UserID, &c.GymID, &c.CheckedInAt)
	if err != nil {
		return nil, err
	}
	return &c, nil
}

