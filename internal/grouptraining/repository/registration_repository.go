package repository

import (
	"context"
	"errors"
	"time"

	"github.com/fitflow/fitflow/internal/grouptraining/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type GroupTrainingRegistrationRepository struct {
	pool *pgxpool.Pool
}

func NewGroupTrainingRegistrationRepository(pool *pgxpool.Pool) *GroupTrainingRegistrationRepository {
	return &GroupTrainingRegistrationRepository{pool: pool}
}

func (r *GroupTrainingRegistrationRepository) CountByTrainingID(ctx context.Context, trainingID uuid.UUID) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM group_training_registrations WHERE group_training_id = $1`, trainingID).Scan(&n)
	return n, err
}

func (r *GroupTrainingRegistrationRepository) IsRegistered(ctx context.Context, userID, trainingID uuid.UUID) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1
			FROM group_training_registrations
			WHERE user_id = $1 AND group_training_id = $2
		)
	`, userID, trainingID).Scan(&exists)
	return exists, err
}

func (r *GroupTrainingRegistrationRepository) Add(ctx context.Context, userID, trainingID uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO group_training_registrations (group_training_id, user_id)
		VALUES ($1, $2)
	`, trainingID, userID)
	if err != nil {
		// Unique violation indicates already registered.
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return domain.ErrRegistrationAlreadyExists
		}
		return err
	}
	return nil
}

func (r *GroupTrainingRegistrationRepository) Delete(ctx context.Context, userID, trainingID uuid.UUID) error {
	res, err := r.pool.Exec(ctx, `
		DELETE FROM group_training_registrations
		WHERE group_training_id = $1 AND user_id = $2
	`, trainingID, userID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return nil
	}
	return nil
}

func (r *GroupTrainingRegistrationRepository) ListParticipantsByTrainingID(ctx context.Context, trainingID uuid.UUID) ([]*domain.ParticipantProfile, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT
			u.id,
			p.display_name,
			p.city,
			p.avatar_url
		FROM group_training_registrations r
		INNER JOIN users u ON u.id = r.user_id
		LEFT JOIN user_profiles p ON p.user_id = u.id
		WHERE r.group_training_id = $1
		ORDER BY p.display_name ASC
	`, trainingID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]*domain.ParticipantProfile, 0)
	for rows.Next() {
		var p domain.ParticipantProfile
		if err := rows.Scan(&p.UserID, &p.DisplayName, &p.City, &p.AvatarURL); err != nil {
			return nil, err
		}
		out = append(out, &p)
	}
	return out, rows.Err()
}

func (r *GroupTrainingRegistrationRepository) CountUserRegistrationsInWeek(ctx context.Context, userID uuid.UUID, weekStart time.Time, weekEnd time.Time) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM group_training_registrations r
		INNER JOIN group_trainings t ON t.id = r.group_training_id
		WHERE r.user_id = $1
			AND t.scheduled_at >= $2
			AND t.scheduled_at < $3
	`, userID, weekStart, weekEnd).Scan(&n)
	return n, err
}

var _ uuid.UUID
var _ time.Time

