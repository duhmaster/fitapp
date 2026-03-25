package repository

import (
	"context"
	"errors"
	"time"

	"github.com/fitflow/fitflow/internal/grouptraining/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type GroupTrainingRepository struct {
	pool *pgxpool.Pool
}

func NewGroupTrainingRepository(pool *pgxpool.Pool) *GroupTrainingRepository {
	return &GroupTrainingRepository{pool: pool}
}

func (r *GroupTrainingRepository) Create(ctx context.Context, trainerID uuid.UUID, templateID uuid.UUID, scheduledAt time.Time, gymID uuid.UUID) (*domain.GroupTraining, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var tplTrainerID uuid.UUID
	queryTpl := `
		SELECT trainer_user_id
		FROM group_training_templates
		WHERE id = $1 AND deleted_at IS NULL
	`
	if err := tx.QueryRow(ctx, queryTpl, templateID).Scan(&tplTrainerID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrGroupTrainingTemplateNotFound
		}
		return nil, err
	}
	if tplTrainerID != trainerID {
		return nil, domain.ErrGroupTrainingTemplateForbidden
	}

	var city string
	if err := tx.QueryRow(ctx, `SELECT city FROM gyms WHERE id = $1`, gymID).Scan(&city); err != nil {
		return nil, err
	}

	var training domain.GroupTraining
	err = tx.QueryRow(ctx, `
		INSERT INTO group_trainings (template_id, scheduled_at, trainer_user_id, gym_id, city)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, template_id, scheduled_at, trainer_user_id, gym_id, city, created_at, updated_at
	`, templateID, scheduledAt, trainerID, gymID, city).Scan(
		&training.ID,
		&training.TemplateID,
		&training.ScheduledAt,
		&training.TrainerUserID,
		&training.GymID,
		&training.City,
		&training.CreatedAt,
		&training.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &training, nil
}

func (r *GroupTrainingRepository) Update(
	ctx context.Context,
	trainerID uuid.UUID,
	trainingID uuid.UUID,
	templateID uuid.UUID,
	scheduledAt time.Time,
	gymID uuid.UUID,
) (*domain.GroupTraining, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	// Ensure template exists and belongs to this trainer (and isn't soft-deleted).
	var tplTrainerID uuid.UUID
	queryTpl := `
		SELECT trainer_user_id
		FROM group_training_templates
		WHERE id = $1 AND deleted_at IS NULL
	`
	if err := tx.QueryRow(ctx, queryTpl, templateID).Scan(&tplTrainerID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrGroupTrainingTemplateNotFound
		}
		return nil, err
	}
	if tplTrainerID != trainerID {
		return nil, domain.ErrGroupTrainingTemplateForbidden
	}

	// Resolve city by gym_id.
	var city string
	if err := tx.QueryRow(ctx, `SELECT city FROM gyms WHERE id = $1`, gymID).Scan(&city); err != nil {
		return nil, err
	}

	var training domain.GroupTraining
	err = tx.QueryRow(ctx, `
		UPDATE group_trainings
		SET template_id = $1,
		    scheduled_at = $2,
		    gym_id = $3,
		    city = $4,
		    updated_at = NOW()
		WHERE id = $5 AND trainer_user_id = $6
		RETURNING id, template_id, scheduled_at, trainer_user_id, gym_id, city, created_at, updated_at
	`, templateID, scheduledAt, gymID, city, trainingID, trainerID).Scan(
		&training.ID,
		&training.TemplateID,
		&training.ScheduledAt,
		&training.TrainerUserID,
		&training.GymID,
		&training.City,
		&training.CreatedAt,
		&training.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrGroupTrainingNotFound
		}
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &training, nil
}

func (r *GroupTrainingRepository) GetByIDForTrainer(ctx context.Context, trainerID, trainingID uuid.UUID) (*domain.GroupTraining, error) {
	query := `
		SELECT t.id, t.template_id, COALESCE(tpl.name, ''), t.scheduled_at, t.trainer_user_id, t.gym_id, t.city, t.created_at, t.updated_at
		FROM group_trainings t
		LEFT JOIN group_training_templates tpl ON tpl.id = t.template_id
		WHERE t.id = $1 AND t.trainer_user_id = $2
	`
	var training domain.GroupTraining
	err := r.pool.QueryRow(ctx, query, trainingID, trainerID).Scan(
		&training.ID,
		&training.TemplateID,
		&training.TemplateName,
		&training.ScheduledAt,
		&training.TrainerUserID,
		&training.GymID,
		&training.City,
		&training.CreatedAt,
		&training.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrGroupTrainingNotFound
		}
		return nil, err
	}
	return &training, nil
}

func (r *GroupTrainingRepository) ListByTrainerID(ctx context.Context, trainerID uuid.UUID, includePast bool, limit, offset int) ([]*domain.GroupTraining, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 200 {
		limit = 200
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT t.id, t.template_id, COALESCE(tpl.name, ''), t.scheduled_at, t.trainer_user_id, t.gym_id, t.city, t.created_at, t.updated_at
		FROM group_trainings t
		LEFT JOIN group_training_templates tpl ON tpl.id = t.template_id
		WHERE t.trainer_user_id = $1
		` + func() string {
		if includePast {
			return ""
		}
		return ` AND t.scheduled_at >= NOW() `
	}() + `
		ORDER BY t.scheduled_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.pool.Query(ctx, query, trainerID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]*domain.GroupTraining, 0)
	for rows.Next() {
		var t domain.GroupTraining
		if err := rows.Scan(&t.ID, &t.TemplateID, &t.TemplateName, &t.ScheduledAt, &t.TrainerUserID, &t.GymID, &t.City, &t.CreatedAt, &t.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, &t)
	}
	return out, rows.Err()
}

func (r *GroupTrainingRepository) GetByIDForUser(ctx context.Context, userID, trainingID uuid.UUID) (*domain.GroupTraining, error) {
	query := `
		SELECT t.id, t.template_id, COALESCE(tpl.name, ''), t.scheduled_at, t.trainer_user_id, t.gym_id, t.city, t.created_at, t.updated_at
		FROM group_trainings t
		INNER JOIN group_training_registrations r ON r.group_training_id = t.id
		LEFT JOIN group_training_templates tpl ON tpl.id = t.template_id
		WHERE r.user_id = $1 AND t.id = $2
	`
	var training domain.GroupTraining
	err := r.pool.QueryRow(ctx, query, userID, trainingID).Scan(
		&training.ID,
		&training.TemplateID,
		&training.TemplateName,
		&training.ScheduledAt,
		&training.TrainerUserID,
		&training.GymID,
		&training.City,
		&training.CreatedAt,
		&training.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrGroupTrainingNotFound
		}
		return nil, err
	}
	return &training, nil
}

func (r *GroupTrainingRepository) ListByUserID(ctx context.Context, userID uuid.UUID, includePast bool, limit, offset int) ([]*domain.GroupTraining, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 200 {
		limit = 200
	}
	if offset < 0 {
		offset = 0
	}

	// For the user list we filter by "registered trainings".
	query := `
		SELECT t.id, t.template_id, COALESCE(tpl.name, ''), t.scheduled_at, t.trainer_user_id, t.gym_id, t.city, t.created_at, t.updated_at
		FROM group_trainings t
		INNER JOIN group_training_registrations r ON r.group_training_id = t.id
		LEFT JOIN group_training_templates tpl ON tpl.id = t.template_id
		WHERE r.user_id = $1
		` + func() string {
		if includePast {
			return ""
		}
		return ` AND t.scheduled_at >= NOW() `
	}() + `
		ORDER BY t.scheduled_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.pool.Query(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]*domain.GroupTraining, 0)
	for rows.Next() {
		var t domain.GroupTraining
		if err := rows.Scan(&t.ID, &t.TemplateID, &t.TemplateName, &t.ScheduledAt, &t.TrainerUserID, &t.GymID, &t.City, &t.CreatedAt, &t.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, &t)
	}
	return out, rows.Err()
}

func (r *GroupTrainingRepository) Delete(ctx context.Context, trainerID uuid.UUID, trainingID uuid.UUID) error {
	res, err := r.pool.Exec(ctx, `DELETE FROM group_trainings WHERE id = $1 AND trainer_user_id = $2`, trainingID, trainerID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return domain.ErrGroupTrainingNotFound
	}
	return nil
}

func (r *GroupTrainingRepository) GetMaxPeopleForTraining(ctx context.Context, trainingID uuid.UUID) (int, error) {
	// Only active, non-soft-deleted templates are bookable.
	var maxPeople int
	err := r.pool.QueryRow(ctx, `
		SELECT tpl.max_people_count
		FROM group_trainings t
		INNER JOIN group_training_templates tpl ON tpl.id = t.template_id
		WHERE t.id = $1
		  AND tpl.deleted_at IS NULL
		  AND tpl.is_active = TRUE
	`, trainingID).Scan(&maxPeople)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return 0, domain.ErrGroupTrainingNotFound
		}
		return 0, err
	}
	return maxPeople, nil
}

func (r *GroupTrainingRepository) GetBookingDisplayByID(ctx context.Context, trainingID uuid.UUID) (*domain.GroupTrainingBookingItem, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT
			t.id,
			t.template_id,
			tpl.name,
			tpl.description,
			tpl.duration_minutes,
			tpl.equipment,
			tpl.level_of_preparation,
			COALESCE(p.url, tpl.photo_path) AS photo_path,
			tpl.max_people_count,
			typ.id,
			typ.name,
			t.scheduled_at,
			t.trainer_user_id,
			t.gym_id,
			t.city,
			COUNT(reg.user_id) AS participants_count
		FROM group_trainings t
		INNER JOIN group_training_templates tpl ON tpl.id = t.template_id
		LEFT JOIN photos p ON tpl.photo_id = p.id
		INNER JOIN group_training_types typ ON typ.id = tpl.group_type_id
		LEFT JOIN group_training_registrations reg ON reg.group_training_id = t.id
		WHERE t.id = $1
		  AND tpl.deleted_at IS NULL
		  AND tpl.is_active = TRUE
		GROUP BY
			t.id, t.template_id,
			tpl.name, tpl.description, tpl.duration_minutes, tpl.equipment, tpl.level_of_preparation, COALESCE(p.url, tpl.photo_path), tpl.max_people_count,
			typ.id, typ.name,
			t.scheduled_at, t.trainer_user_id, t.gym_id, t.city
	`, trainingID)

	var item domain.GroupTrainingBookingItem
	var photo *string
	if err := row.Scan(
		&item.TrainingID,
		&item.TemplateID,
		&item.TemplateName,
		&item.Description,
		&item.DurationMinutes,
		&item.Equipment,
		&item.LevelOfPreparation,
		&photo,
		&item.MaxPeopleCount,
		&item.GroupTypeID,
		&item.GroupTypeName,
		&item.ScheduledAt,
		&item.TrainerUserID,
		&item.GymID,
		&item.City,
		&item.ParticipantsCount,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrGroupTrainingNotFound
		}
		return nil, err
	}
	item.PhotoPath = photo
	return &item, nil
}

func (r *GroupTrainingRepository) ListAvailableForUser(
	ctx context.Context,
	userID uuid.UUID,
	city *string,
	gymID *uuid.UUID,
	trainerUserID *uuid.UUID,
	dateFrom *time.Time,
	dateTo *time.Time,
	groupTypeID *uuid.UUID,
	limit, offset int,
) ([]*domain.GroupTrainingBookingItem, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 200 {
		limit = 200
	}
	if offset < 0 {
		offset = 0
	}

	rows, err := r.pool.Query(ctx, `
		SELECT
			t.id,
			t.template_id,
			tpl.name,
			tpl.description,
			tpl.duration_minutes,
			tpl.equipment,
			tpl.level_of_preparation,
			COALESCE(p.url, tpl.photo_path) AS photo_path,
			tpl.max_people_count,
			typ.id,
			typ.name,
			t.scheduled_at,
			t.trainer_user_id,
			t.gym_id,
			t.city,
			COUNT(reg.user_id) AS participants_count
		FROM group_trainings t
		INNER JOIN group_training_templates tpl ON tpl.id = t.template_id
		LEFT JOIN photos p ON tpl.photo_id = p.id
		INNER JOIN group_training_types typ ON typ.id = tpl.group_type_id
		LEFT JOIN group_training_registrations reg ON reg.group_training_id = t.id
		WHERE tpl.deleted_at IS NULL
		  AND tpl.is_active = TRUE
		  AND t.scheduled_at >= NOW()
		  AND NOT EXISTS (
		    SELECT 1 FROM group_training_registrations r2
		    WHERE r2.group_training_id = t.id AND r2.user_id = $1
		  )
		  AND ($2::text IS NULL OR t.city = $2)
		  AND ($3::uuid IS NULL OR t.gym_id = $3)
		  AND ($4::uuid IS NULL OR t.trainer_user_id = $4)
		  AND ($5::timestamptz IS NULL OR t.scheduled_at >= $5)
		  AND ($6::timestamptz IS NULL OR t.scheduled_at <= $6)
		  AND ($7::uuid IS NULL OR tpl.group_type_id = $7)
		GROUP BY
			t.id, t.template_id,
			tpl.name, tpl.description, tpl.duration_minutes, tpl.equipment, tpl.level_of_preparation, COALESCE(p.url, tpl.photo_path), tpl.max_people_count,
			typ.id, typ.name,
			t.scheduled_at, t.trainer_user_id, t.gym_id, t.city
		HAVING COUNT(reg.user_id) < tpl.max_people_count
		ORDER BY t.scheduled_at ASC
		LIMIT $8 OFFSET $9
	`, userID, city, gymID, trainerUserID, dateFrom, dateTo, groupTypeID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]*domain.GroupTrainingBookingItem, 0)
	for rows.Next() {
		var item domain.GroupTrainingBookingItem
		var photo *string
		if err := rows.Scan(
			&item.TrainingID,
			&item.TemplateID,
			&item.TemplateName,
			&item.Description,
			&item.DurationMinutes,
			&item.Equipment,
			&item.LevelOfPreparation,
			&photo,
			&item.MaxPeopleCount,
			&item.GroupTypeID,
			&item.GroupTypeName,
			&item.ScheduledAt,
			&item.TrainerUserID,
			&item.GymID,
			&item.City,
			&item.ParticipantsCount,
		); err != nil {
			return nil, err
		}
		item.PhotoPath = photo
		out = append(out, &item)
	}
	return out, rows.Err()
}

func (r *GroupTrainingRepository) ListUpcomingForTrainer(
	ctx context.Context,
	trainerID uuid.UUID,
	limit, offset int,
) ([]*domain.GroupTrainingBookingItem, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 200 {
		limit = 200
	}
	if offset < 0 {
		offset = 0
	}

	rows, err := r.pool.Query(ctx, `
		SELECT
			t.id,
			t.template_id,
			tpl.name,
			tpl.description,
			tpl.duration_minutes,
			tpl.equipment,
			tpl.level_of_preparation,
			COALESCE(p.url, tpl.photo_path) AS photo_path,
			tpl.max_people_count,
			typ.id,
			typ.name,
			t.scheduled_at,
			t.trainer_user_id,
			t.gym_id,
			t.city,
			COUNT(reg.user_id) AS participants_count
		FROM group_trainings t
		INNER JOIN group_training_templates tpl ON tpl.id = t.template_id
		INNER JOIN group_training_types typ ON typ.id = tpl.group_type_id
		LEFT JOIN photos p ON tpl.photo_id = p.id
		LEFT JOIN group_training_registrations reg ON reg.group_training_id = t.id
		WHERE tpl.deleted_at IS NULL
		  AND tpl.is_active = TRUE
		  AND t.trainer_user_id = $1
		  AND t.scheduled_at >= NOW()
		GROUP BY
			t.id, t.template_id,
			tpl.name, tpl.description, tpl.duration_minutes, tpl.equipment, tpl.level_of_preparation,
			COALESCE(p.url, tpl.photo_path), tpl.max_people_count,
			typ.id, typ.name,
			t.scheduled_at, t.trainer_user_id, t.gym_id, t.city
		ORDER BY t.scheduled_at ASC
		LIMIT $2 OFFSET $3
	`, trainerID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]*domain.GroupTrainingBookingItem, 0)
	for rows.Next() {
		var item domain.GroupTrainingBookingItem
		var photo *string
		if err := rows.Scan(
			&item.TrainingID,
			&item.TemplateID,
			&item.TemplateName,
			&item.Description,
			&item.DurationMinutes,
			&item.Equipment,
			&item.LevelOfPreparation,
			&photo,
			&item.MaxPeopleCount,
			&item.GroupTypeID,
			&item.GroupTypeName,
			&item.ScheduledAt,
			&item.TrainerUserID,
			&item.GymID,
			&item.City,
			&item.ParticipantsCount,
		); err != nil {
			return nil, err
		}
		item.PhotoPath = photo
		out = append(out, &item)
	}
	return out, rows.Err()
}

func (r *GroupTrainingRepository) CountTrainerCreationsInWeek(ctx context.Context, trainerID uuid.UUID, weekStart time.Time, weekEnd time.Time) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM group_trainings
		WHERE trainer_user_id = $1
		  AND scheduled_at >= $2
		  AND scheduled_at < $3
	`, trainerID, weekStart, weekEnd).Scan(&n)
	return n, err
}

var _ uuid.UUID

