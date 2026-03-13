package repository

import (
	"context"
	"errors"

	trainerdomain "github.com/fitflow/fitflow/internal/trainer/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TrainerProfileRepository struct {
	pool *pgxpool.Pool
}

func NewTrainerProfileRepository(pool *pgxpool.Pool) *TrainerProfileRepository {
	return &TrainerProfileRepository{pool: pool}
}

func (r *TrainerProfileRepository) GetByUserID(ctx context.Context, userID uuid.UUID) (*trainerdomain.TrainerProfile, error) {
	query := `
		SELECT user_id, COALESCE(about_me,''), COALESCE(contacts,''), created_at, updated_at
		FROM trainer_profiles
		WHERE user_id = $1
	`
	var p trainerdomain.TrainerProfile
	err := r.pool.QueryRow(ctx, query, userID).Scan(
		&p.UserID, &p.AboutMe, &p.Contacts, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, trainerdomain.ErrTrainerProfileNotFound
		}
		return nil, err
	}
	return &p, nil
}

func (r *TrainerProfileRepository) Upsert(ctx context.Context, p *trainerdomain.TrainerProfile) error {
	query := `
		INSERT INTO trainer_profiles (user_id, about_me, contacts, updated_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (user_id) DO UPDATE SET
			about_me = EXCLUDED.about_me,
			contacts = EXCLUDED.contacts,
			updated_at = NOW()
	`
	_, err := r.pool.Exec(ctx, query, p.UserID, p.AboutMe, p.Contacts)
	return err
}

// SearchTrainerUserIDs returns user IDs of users who have a trainer profile and match query (display_name or city ILIKE).
func (r *TrainerProfileRepository) SearchTrainerUserIDs(ctx context.Context, q string, limit int) ([]uuid.UUID, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 50 {
		limit = 50
	}
	pattern := "%" + q + "%"
	sql := `
		SELECT tp.user_id
		FROM trainer_profiles tp
		JOIN user_profiles up ON up.user_id = tp.user_id
		WHERE $1 = '' OR up.display_name ILIKE $2 OR COALESCE(up.city,'') ILIKE $2
		ORDER BY up.display_name
		LIMIT $3
	`
	rows, err := r.pool.Query(ctx, sql, q, pattern, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}
