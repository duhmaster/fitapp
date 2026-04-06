package repository

import (
	"context"
	"errors"

	"github.com/google/uuid"
)

func (r *PG) CreateBadgeDefinition(ctx context.Context, code, title string, description *string, rarity string, iconKey *string) (uuid.UUID, error) {
	if rarity == "" {
		rarity = "common"
	}
	var id uuid.UUID
	err := r.pool.QueryRow(ctx, `
		INSERT INTO badge_definitions (code, title, description, rarity, icon_key)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id
	`, code, title, description, rarity, iconKey).Scan(&id)
	return id, err
}

func (r *PG) UpdateBadgeDefinition(ctx context.Context, id uuid.UUID, code, title string, description *string, rarity string, iconKey *string) error {
	if rarity == "" {
		rarity = "common"
	}
	tag, err := r.pool.Exec(ctx, `
		UPDATE badge_definitions SET code = $2, title = $3, description = $4, rarity = $5, icon_key = $6
		WHERE id = $1
	`, id, code, title, description, rarity, iconKey)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("badge not found")
	}
	return nil
}

func (r *PG) DeleteBadgeDefinition(ctx context.Context, id uuid.UUID) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM badge_definitions WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("badge not found")
	}
	return nil
}

func (r *PG) CreateMissionDefinition(ctx context.Context, code, title string, description *string, period string, targetValue, rewardXP int) (uuid.UUID, error) {
	var id uuid.UUID
	err := r.pool.QueryRow(ctx, `
		INSERT INTO mission_definitions (code, title, description, period, target_value, reward_xp)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id
	`, code, title, description, period, targetValue, rewardXP).Scan(&id)
	return id, err
}

func (r *PG) UpdateMissionDefinition(ctx context.Context, id uuid.UUID, code, title string, description *string, period string, targetValue, rewardXP int) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE mission_definitions SET code = $2, title = $3, description = $4, period = $5, target_value = $6, reward_xp = $7
		WHERE id = $1
	`, id, code, title, description, period, targetValue, rewardXP)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("mission not found")
	}
	return nil
}

func (r *PG) DeleteMissionDefinition(ctx context.Context, id uuid.UUID) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM mission_definitions WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("mission not found")
	}
	return nil
}
