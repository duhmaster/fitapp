package repository

import (
	"context"
	"errors"

	trainerdomain "github.com/fitflow/fitflow/internal/trainer/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TrainerClientRepository struct {
	pool *pgxpool.Pool
}

func NewTrainerClientRepository(pool *pgxpool.Pool) *TrainerClientRepository {
	return &TrainerClientRepository{pool: pool}
}

func (r *TrainerClientRepository) Create(ctx context.Context, trainerID, clientID uuid.UUID, status string) (*trainerdomain.TrainerClient, error) {
	if status == "" {
		status = "active"
	}

	query := `
		INSERT INTO trainer_clients (trainer_id, client_id, status)
		VALUES ($1, $2, $3)
		RETURNING id, trainer_id, client_id, status, created_at
	`
	var tc trainerdomain.TrainerClient
	err := r.pool.QueryRow(ctx, query, trainerID, clientID, status).Scan(
		&tc.ID, &tc.TrainerID, &tc.ClientID, &tc.Status, &tc.CreatedAt,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, trainerdomain.ErrAlreadyClient
		}
		return nil, err
	}
	return &tc, nil
}

func (r *TrainerClientRepository) GetByTrainerAndClient(ctx context.Context, trainerID, clientID uuid.UUID) (*trainerdomain.TrainerClient, error) {
	query := `
		SELECT id, trainer_id, client_id, status, created_at
		FROM trainer_clients
		WHERE trainer_id = $1 AND client_id = $2
	`
	var tc trainerdomain.TrainerClient
	err := r.pool.QueryRow(ctx, query, trainerID, clientID).Scan(
		&tc.ID, &tc.TrainerID, &tc.ClientID, &tc.Status, &tc.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, trainerdomain.ErrTrainerClientNotFound
		}
		return nil, err
	}
	return &tc, nil
}

func (r *TrainerClientRepository) UpdateStatus(ctx context.Context, trainerID, clientID uuid.UUID, status string) (*trainerdomain.TrainerClient, error) {
	query := `
		UPDATE trainer_clients SET status = $3
		WHERE trainer_id = $1 AND client_id = $2
		RETURNING id, trainer_id, client_id, status, created_at
	`
	var tc trainerdomain.TrainerClient
	err := r.pool.QueryRow(ctx, query, trainerID, clientID, status).Scan(
		&tc.ID, &tc.TrainerID, &tc.ClientID, &tc.Status, &tc.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, trainerdomain.ErrTrainerClientNotFound
		}
		return nil, err
	}
	return &tc, nil
}

func (r *TrainerClientRepository) ListClientsByTrainer(ctx context.Context, trainerID uuid.UUID, status string, limit, offset int) ([]*trainerdomain.TrainerClient, error) {
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
		SELECT id, trainer_id, client_id, status, created_at
		FROM trainer_clients
		WHERE trainer_id = $1 AND ($2 = '' OR status = $2)
		ORDER BY created_at DESC
		LIMIT $3 OFFSET $4
	`
	rows, err := r.pool.Query(ctx, query, trainerID, status, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*trainerdomain.TrainerClient
	for rows.Next() {
		var tc trainerdomain.TrainerClient
		if err := rows.Scan(&tc.ID, &tc.TrainerID, &tc.ClientID, &tc.Status, &tc.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &tc)
	}
	return list, rows.Err()
}

func (r *TrainerClientRepository) CountByTrainerID(ctx context.Context, trainerID uuid.UUID) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM trainer_clients WHERE trainer_id = $1`, trainerID).Scan(&n)
	return n, err
}

func (r *TrainerClientRepository) ListTrainersByClient(ctx context.Context, clientID uuid.UUID, status string, limit, offset int) ([]*trainerdomain.TrainerClient, error) {
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
		SELECT id, trainer_id, client_id, status, created_at
		FROM trainer_clients
		WHERE client_id = $1 AND ($2 = '' OR status = $2)
		ORDER BY created_at DESC
		LIMIT $3 OFFSET $4
	`
	rows, err := r.pool.Query(ctx, query, clientID, status, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*trainerdomain.TrainerClient
	for rows.Next() {
		var tc trainerdomain.TrainerClient
		if err := rows.Scan(&tc.ID, &tc.TrainerID, &tc.ClientID, &tc.Status, &tc.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &tc)
	}
	return list, rows.Err()
}

func (r *TrainerClientRepository) Remove(ctx context.Context, trainerID, clientID uuid.UUID) error {
	ct, err := r.pool.Exec(ctx, `DELETE FROM trainer_clients WHERE trainer_id = $1 AND client_id = $2`, trainerID, clientID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return trainerdomain.ErrTrainerClientNotFound
	}
	return nil
}
