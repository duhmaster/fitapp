package repository

import (
	"context"
	"errors"

	trainerdomain "github.com/fitflow/fitflow/internal/trainer/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TrainerPhotoRepository struct {
	pool *pgxpool.Pool
}

func NewTrainerPhotoRepository(pool *pgxpool.Pool) *TrainerPhotoRepository {
	return &TrainerPhotoRepository{pool: pool}
}

func (r *TrainerPhotoRepository) ListByTrainerUserID(ctx context.Context, trainerUserID uuid.UUID) ([]*trainerdomain.TrainerPhoto, error) {
	query := `
		SELECT id, trainer_user_id, path, position, created_at
		FROM trainer_photos
		WHERE trainer_user_id = $1
		ORDER BY position ASC, created_at ASC
	`
	rows, err := r.pool.Query(ctx, query, trainerUserID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*trainerdomain.TrainerPhoto
	for rows.Next() {
		var p trainerdomain.TrainerPhoto
		if err := rows.Scan(&p.ID, &p.TrainerUserID, &p.Path, &p.Position, &p.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &p)
	}
	return list, rows.Err()
}

func (r *TrainerPhotoRepository) CountByTrainerUserID(ctx context.Context, trainerUserID uuid.UUID) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM trainer_photos WHERE trainer_user_id = $1`, trainerUserID).Scan(&n)
	return n, err
}

func (r *TrainerPhotoRepository) Create(ctx context.Context, trainerUserID uuid.UUID, path string, position int) (*trainerdomain.TrainerPhoto, error) {
	query := `
		INSERT INTO trainer_photos (trainer_user_id, path, position)
		VALUES ($1, $2, $3)
		RETURNING id, trainer_user_id, path, position, created_at
	`
	var p trainerdomain.TrainerPhoto
	err := r.pool.QueryRow(ctx, query, trainerUserID, path, position).Scan(
		&p.ID, &p.TrainerUserID, &p.Path, &p.Position, &p.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *TrainerPhotoRepository) GetByID(ctx context.Context, id uuid.UUID) (*trainerdomain.TrainerPhoto, error) {
	query := `
		SELECT id, trainer_user_id, path, position, created_at
		FROM trainer_photos
		WHERE id = $1
	`
	var p trainerdomain.TrainerPhoto
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&p.ID, &p.TrainerUserID, &p.Path, &p.Position, &p.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, trainerdomain.ErrTrainerPhotoNotFound
		}
		return nil, err
	}
	return &p, nil
}

func (r *TrainerPhotoRepository) Delete(ctx context.Context, id uuid.UUID) error {
	ct, err := r.pool.Exec(ctx, `DELETE FROM trainer_photos WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return trainerdomain.ErrTrainerPhotoNotFound
	}
	return nil
}
