package repository

import (
	"context"
	"errors"
	"time"

	trainerdomain "github.com/fitflow/fitflow/internal/trainer/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TrainingProgramRepository struct {
	pool *pgxpool.Pool
}

func NewTrainingProgramRepository(pool *pgxpool.Pool) *TrainingProgramRepository {
	return &TrainingProgramRepository{pool: pool}
}

func (r *TrainingProgramRepository) Create(ctx context.Context, trainerID, clientID uuid.UUID, name string, assignedAt *time.Time) (*trainerdomain.TrainingProgram, error) {
	query := `
		INSERT INTO training_programs (trainer_id, client_id, name, assigned_at)
		VALUES ($1, $2, $3, $4)
		RETURNING id, trainer_id, client_id, name, assigned_at, created_at
	`
	var tp trainerdomain.TrainingProgram
	err := r.pool.QueryRow(ctx, query, trainerID, clientID, name, assignedAt).Scan(
		&tp.ID, &tp.TrainerID, &tp.ClientID, &tp.Name, &tp.AssignedAt, &tp.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &tp, nil
}

func (r *TrainingProgramRepository) GetByID(ctx context.Context, id uuid.UUID) (*trainerdomain.TrainingProgram, error) {
	query := `
		SELECT id, trainer_id, client_id, name, assigned_at, created_at
		FROM training_programs WHERE id = $1
	`
	var tp trainerdomain.TrainingProgram
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&tp.ID, &tp.TrainerID, &tp.ClientID, &tp.Name, &tp.AssignedAt, &tp.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, trainerdomain.ErrTrainingProgramNotFound
		}
		return nil, err
	}
	return &tp, nil
}

func (r *TrainingProgramRepository) Update(ctx context.Context, id uuid.UUID, name string, assignedAt *time.Time) (*trainerdomain.TrainingProgram, error) {
	query := `
		UPDATE training_programs
		SET name = $2, assigned_at = $3
		WHERE id = $1
		RETURNING id, trainer_id, client_id, name, assigned_at, created_at
	`
	var tp trainerdomain.TrainingProgram
	err := r.pool.QueryRow(ctx, query, id, name, assignedAt).Scan(
		&tp.ID, &tp.TrainerID, &tp.ClientID, &tp.Name, &tp.AssignedAt, &tp.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, trainerdomain.ErrTrainingProgramNotFound
		}
		return nil, err
	}
	return &tp, nil
}

func (r *TrainingProgramRepository) Delete(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM training_programs WHERE id = $1`
	ct, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return trainerdomain.ErrTrainingProgramNotFound
	}
	return nil
}

func (r *TrainingProgramRepository) ListByTrainer(ctx context.Context, trainerID uuid.UUID, clientID *uuid.UUID, limit, offset int) ([]*trainerdomain.TrainingProgram, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	var rows pgx.Rows
	var err error
	if clientID != nil {
		query := `
			SELECT id, trainer_id, client_id, name, assigned_at, created_at
			FROM training_programs
			WHERE trainer_id = $1 AND client_id = $2
			ORDER BY created_at DESC
			LIMIT $3 OFFSET $4
		`
		rows, err = r.pool.Query(ctx, query, trainerID, *clientID, limit, offset)
	} else {
		query := `
			SELECT id, trainer_id, client_id, name, assigned_at, created_at
			FROM training_programs
			WHERE trainer_id = $1
			ORDER BY created_at DESC
			LIMIT $2 OFFSET $3
		`
		rows, err = r.pool.Query(ctx, query, trainerID, limit, offset)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*trainerdomain.TrainingProgram
	for rows.Next() {
		var tp trainerdomain.TrainingProgram
		if err := rows.Scan(&tp.ID, &tp.TrainerID, &tp.ClientID, &tp.Name, &tp.AssignedAt, &tp.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &tp)
	}
	return list, rows.Err()
}

func (r *TrainingProgramRepository) ListByClient(ctx context.Context, clientID uuid.UUID, limit, offset int) ([]*trainerdomain.TrainingProgram, error) {
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
		SELECT id, trainer_id, client_id, name, assigned_at, created_at
		FROM training_programs
		WHERE client_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, clientID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*trainerdomain.TrainingProgram
	for rows.Next() {
		var tp trainerdomain.TrainingProgram
		if err := rows.Scan(&tp.ID, &tp.TrainerID, &tp.ClientID, &tp.Name, &tp.AssignedAt, &tp.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &tp)
	}
	return list, rows.Err()
}
