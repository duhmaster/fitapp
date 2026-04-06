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

type GroupTrainingTemplateRepository struct {
	pool *pgxpool.Pool
}

func NewGroupTrainingTemplateRepository(pool *pgxpool.Pool) *GroupTrainingTemplateRepository {
	return &GroupTrainingTemplateRepository{pool: pool}
}

// galleryURLsExpr references alias "t" for group_training_templates.
const galleryURLsExpr = `(SELECT COALESCE(array_agg(p2.url ORDER BY x.ord), ARRAY[]::text[])
	FROM unnest(t.gallery_photo_ids) WITH ORDINALITY AS x(pid, ord)
	LEFT JOIN photos p2 ON p2.id = x.pid)`

// galleryURLsReturning references RETURNING column gallery_photo_ids.
const galleryURLsReturning = `(SELECT COALESCE(array_agg(p2.url ORDER BY x.ord), ARRAY[]::text[])
	FROM unnest(gallery_photo_ids) WITH ORDINALITY AS x(pid, ord)
	LEFT JOIN photos p2 ON p2.id = x.pid)`

func primaryPhotoID(gallery []uuid.UUID) *uuid.UUID {
	if len(gallery) == 0 {
		return nil
	}
	id := gallery[0]
	return &id
}

func (r *GroupTrainingTemplateRepository) Create(
	ctx context.Context,
	trainerID uuid.UUID,
	name string,
	description string,
	durationMinutes int,
	equipment []string,
	levelOfPreparation string,
	photoPath *string,
	galleryPhotoIDs []uuid.UUID,
	maxPeopleCount int,
	groupTypeID uuid.UUID,
	isActive bool,
) (*domain.GroupTrainingTemplate, error) {
	gallery := galleryPhotoIDs
	if gallery == nil {
		gallery = []uuid.UUID{}
	}
	pid := primaryPhotoID(gallery)
	query := `
		INSERT INTO group_training_templates
			(name, description, duration_minutes, equipment, level_of_preparation, photo_path, photo_id, gallery_photo_ids, max_people_count, trainer_user_id, is_active, group_type_id)
		VALUES
			($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id, name, description, duration_minutes, equipment, level_of_preparation,
			COALESCE((SELECT ph.url FROM photos ph WHERE ph.id = photo_id), photo_path) as photo_path,
			photo_id, gallery_photo_ids, ` + galleryURLsReturning + ` as gallery_photo_urls,
			max_people_count, trainer_user_id, is_active, group_type_id, created_at, updated_at, deleted_at
	`

	var tpl domain.GroupTrainingTemplate
	var photo *string
	var photoUUID *uuid.UUID
	var gids []uuid.UUID
	var gurls []string
	err := r.pool.QueryRow(ctx, query,
		name,
		description,
		durationMinutes,
		equipment,
		levelOfPreparation,
		photoPath,
		pid,
		gallery,
		maxPeopleCount,
		trainerID,
		isActive,
		groupTypeID,
	).Scan(
		&tpl.ID,
		&tpl.Name,
		&tpl.Description,
		&tpl.DurationMinutes,
		&tpl.Equipment,
		&tpl.LevelOfPreparation,
		&photo,
		&photoUUID,
		&gids,
		&gurls,
		&tpl.MaxPeopleCount,
		&tpl.TrainerUserID,
		&tpl.IsActive,
		&tpl.GroupTypeID,
		&tpl.CreatedAt,
		&tpl.UpdatedAt,
		&tpl.DeletedAt,
	)
	if err != nil {
		return nil, err
	}
	tpl.PhotoPath = photo
	tpl.PhotoID = photoUUID
	tpl.GalleryPhotoIDs = gids
	tpl.GalleryPhotoURLs = gurls
	return &tpl, nil
}

func (r *GroupTrainingTemplateRepository) GetByID(ctx context.Context, trainerID, templateID uuid.UUID) (*domain.GroupTrainingTemplate, error) {
	query := `
		SELECT t.id, t.name, t.description, t.duration_minutes, t.equipment, t.level_of_preparation,
			COALESCE(p.url, t.photo_path) as photo_path, t.photo_id, t.gallery_photo_ids, ` + galleryURLsExpr + ` as gallery_photo_urls,
			t.max_people_count, t.trainer_user_id, t.is_active, t.group_type_id, t.created_at, t.updated_at, t.deleted_at
		FROM group_training_templates t
		LEFT JOIN photos p ON t.photo_id = p.id
		WHERE t.id = $1 AND t.trainer_user_id = $2 AND t.deleted_at IS NULL
	`
	var tpl domain.GroupTrainingTemplate
	var photo *string
	var photoUUID *uuid.UUID
	var gids []uuid.UUID
	var gurls []string
	err := r.pool.QueryRow(ctx, query, templateID, trainerID).Scan(
		&tpl.ID,
		&tpl.Name,
		&tpl.Description,
		&tpl.DurationMinutes,
		&tpl.Equipment,
		&tpl.LevelOfPreparation,
		&photo,
		&photoUUID,
		&gids,
		&gurls,
		&tpl.MaxPeopleCount,
		&tpl.TrainerUserID,
		&tpl.IsActive,
		&tpl.GroupTypeID,
		&tpl.CreatedAt,
		&tpl.UpdatedAt,
		&tpl.DeletedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrGroupTrainingTemplateNotFound
		}
		return nil, err
	}
	tpl.PhotoPath = photo
	tpl.PhotoID = photoUUID
	tpl.GalleryPhotoIDs = gids
	tpl.GalleryPhotoURLs = gurls
	return &tpl, nil
}

func (r *GroupTrainingTemplateRepository) ListByTrainerID(ctx context.Context, trainerID uuid.UUID, limit, offset int) ([]*domain.GroupTrainingTemplate, error) {
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
		SELECT t.id, t.name, t.description, t.duration_minutes, t.equipment, t.level_of_preparation,
			COALESCE(p.url, t.photo_path) as photo_path, t.photo_id, t.gallery_photo_ids, ` + galleryURLsExpr + ` as gallery_photo_urls,
			t.max_people_count, t.trainer_user_id, t.is_active, t.group_type_id, t.created_at, t.updated_at, t.deleted_at
		FROM group_training_templates t
		LEFT JOIN photos p ON t.photo_id = p.id
		WHERE t.trainer_user_id = $1 AND t.deleted_at IS NULL
		ORDER BY t.created_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.pool.Query(ctx, query, trainerID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]*domain.GroupTrainingTemplate, 0)
	for rows.Next() {
		var tpl domain.GroupTrainingTemplate
		var photo *string
		var photoUUID *uuid.UUID
		var gids []uuid.UUID
		var gurls []string
		if err := rows.Scan(
			&tpl.ID,
			&tpl.Name,
			&tpl.Description,
			&tpl.DurationMinutes,
			&tpl.Equipment,
			&tpl.LevelOfPreparation,
			&photo,
			&photoUUID,
			&gids,
			&gurls,
			&tpl.MaxPeopleCount,
			&tpl.TrainerUserID,
			&tpl.IsActive,
			&tpl.GroupTypeID,
			&tpl.CreatedAt,
			&tpl.UpdatedAt,
			&tpl.DeletedAt,
		); err != nil {
			return nil, err
		}
		tpl.PhotoPath = photo
		tpl.PhotoID = photoUUID
		tpl.GalleryPhotoIDs = gids
		tpl.GalleryPhotoURLs = gurls
		out = append(out, &tpl)
	}
	return out, rows.Err()
}

func (r *GroupTrainingTemplateRepository) Update(
	ctx context.Context,
	trainerID uuid.UUID,
	templateID uuid.UUID,
	name string,
	description string,
	durationMinutes int,
	equipment []string,
	levelOfPreparation string,
	photoPath *string,
	galleryPhotoIDs []uuid.UUID,
	maxPeopleCount int,
	groupTypeID uuid.UUID,
	isActive bool,
) (*domain.GroupTrainingTemplate, error) {
	gallery := galleryPhotoIDs
	if gallery == nil {
		gallery = []uuid.UUID{}
	}
	pid := primaryPhotoID(gallery)
	query := `
		UPDATE group_training_templates
		SET
			name = $2,
			description = $3,
			duration_minutes = $4,
			equipment = $5,
			level_of_preparation = $6,
			photo_path = $7,
			photo_id = $8,
			gallery_photo_ids = $9,
			max_people_count = $10,
			group_type_id = $11,
			is_active = $12,
			updated_at = NOW()
		WHERE id = $1 AND trainer_user_id = $13 AND deleted_at IS NULL
		RETURNING id, name, description, duration_minutes, equipment, level_of_preparation,
			COALESCE((SELECT ph.url FROM photos ph WHERE ph.id = photo_id), photo_path) as photo_path,
			photo_id, gallery_photo_ids, ` + galleryURLsReturning + ` as gallery_photo_urls,
			max_people_count, trainer_user_id, is_active, group_type_id, created_at, updated_at, deleted_at
	`

	var tpl domain.GroupTrainingTemplate
	var photo *string
	var photoUUID *uuid.UUID
	var gids []uuid.UUID
	var gurls []string
	err := r.pool.QueryRow(ctx, query,
		templateID,
		name,
		description,
		durationMinutes,
		equipment,
		levelOfPreparation,
		photoPath,
		pid,
		gallery,
		maxPeopleCount,
		groupTypeID,
		isActive,
		trainerID,
	).Scan(
		&tpl.ID,
		&tpl.Name,
		&tpl.Description,
		&tpl.DurationMinutes,
		&tpl.Equipment,
		&tpl.LevelOfPreparation,
		&photo,
		&photoUUID,
		&gids,
		&gurls,
		&tpl.MaxPeopleCount,
		&tpl.TrainerUserID,
		&tpl.IsActive,
		&tpl.GroupTypeID,
		&tpl.CreatedAt,
		&tpl.UpdatedAt,
		&tpl.DeletedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrGroupTrainingTemplateNotFound
		}
		return nil, err
	}
	tpl.PhotoPath = photo
	tpl.PhotoID = photoUUID
	tpl.GalleryPhotoIDs = gids
	tpl.GalleryPhotoURLs = gurls
	return &tpl, nil
}

func (r *GroupTrainingTemplateRepository) SoftDelete(ctx context.Context, trainerID, templateID uuid.UUID) error {
	res, err := r.pool.Exec(ctx, `UPDATE group_training_templates SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1 AND trainer_user_id = $2 AND deleted_at IS NULL`, templateID, trainerID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return domain.ErrGroupTrainingTemplateNotFound
	}
	return nil
}

// Ensure compile with unused imports in future edits.
var _ time.Time
