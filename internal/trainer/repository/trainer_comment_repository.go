package repository

import (
	"context"

	trainerdomain "github.com/fitflow/fitflow/internal/trainer/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TrainerCommentRepository struct {
	pool *pgxpool.Pool
}

func NewTrainerCommentRepository(pool *pgxpool.Pool) *TrainerCommentRepository {
	return &TrainerCommentRepository{pool: pool}
}

func (r *TrainerCommentRepository) Create(ctx context.Context, trainerID, clientID uuid.UUID, content string) (*trainerdomain.TrainerComment, error) {
	query := `
		INSERT INTO trainer_comments (trainer_id, client_id, content)
		VALUES ($1, $2, $3)
		RETURNING id, trainer_id, client_id, content, created_at
	`
	var tc trainerdomain.TrainerComment
	err := r.pool.QueryRow(ctx, query, trainerID, clientID, content).Scan(
		&tc.ID, &tc.TrainerID, &tc.ClientID, &tc.Content, &tc.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &tc, nil
}

func (r *TrainerCommentRepository) ListByTrainerAndClient(ctx context.Context, trainerID, clientID uuid.UUID, limit, offset int) ([]*trainerdomain.TrainerComment, error) {
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
		SELECT id, trainer_id, client_id, content, created_at
		FROM trainer_comments
		WHERE trainer_id = $1 AND client_id = $2
		ORDER BY created_at ASC
		LIMIT $3 OFFSET $4
	`
	rows, err := r.pool.Query(ctx, query, trainerID, clientID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*trainerdomain.TrainerComment
	for rows.Next() {
		var tc trainerdomain.TrainerComment
		if err := rows.Scan(&tc.ID, &tc.TrainerID, &tc.ClientID, &tc.Content, &tc.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &tc)
	}
	return list, rows.Err()
}
