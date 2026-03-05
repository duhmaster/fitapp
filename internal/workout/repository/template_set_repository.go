package repository

import (
	"context"

	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TemplateExerciseSetRepository struct {
	pool *pgxpool.Pool
}

func NewTemplateExerciseSetRepository(pool *pgxpool.Pool) *TemplateExerciseSetRepository {
	return &TemplateExerciseSetRepository{pool: pool}
}

func (r *TemplateExerciseSetRepository) Create(ctx context.Context, templateExerciseID uuid.UUID, setOrder int, weightKg *float64, reps *int) (*workoutdomain.TemplateExerciseSet, error) {
	query := `
		INSERT INTO template_exercise_sets (template_exercise_id, set_order, weight_kg, reps)
		VALUES ($1, $2, $3, $4)
		RETURNING id, template_exercise_id, set_order, weight_kg, reps
	`
	var s workoutdomain.TemplateExerciseSet
	err := r.pool.QueryRow(ctx, query, templateExerciseID, setOrder, weightKg, reps).Scan(
		&s.ID, &s.TemplateExerciseID, &s.SetOrder, &s.WeightKg, &s.Reps,
	)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *TemplateExerciseSetRepository) ListByTemplateExerciseID(ctx context.Context, templateExerciseID uuid.UUID) ([]*workoutdomain.TemplateExerciseSet, error) {
	query := `
		SELECT id, template_exercise_id, set_order, weight_kg, reps
		FROM template_exercise_sets
		WHERE template_exercise_id = $1
		ORDER BY set_order ASC, id ASC
	`
	rows, err := r.pool.Query(ctx, query, templateExerciseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*workoutdomain.TemplateExerciseSet
	for rows.Next() {
		var s workoutdomain.TemplateExerciseSet
		if err := rows.Scan(&s.ID, &s.TemplateExerciseID, &s.SetOrder, &s.WeightKg, &s.Reps); err != nil {
			return nil, err
		}
		list = append(list, &s)
	}
	return list, rows.Err()
}

func (r *TemplateExerciseSetRepository) Delete(ctx context.Context, id uuid.UUID) error {
	res, err := r.pool.Exec(ctx, `DELETE FROM template_exercise_sets WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *TemplateExerciseSetRepository) DeleteByIDAndTemplateExerciseID(ctx context.Context, setID, templateExerciseID uuid.UUID) error {
	res, err := r.pool.Exec(ctx, `DELETE FROM template_exercise_sets WHERE id = $1 AND template_exercise_id = $2`, setID, templateExerciseID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *TemplateExerciseSetRepository) DeleteByTemplateExerciseID(ctx context.Context, templateExerciseID uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM template_exercise_sets WHERE template_exercise_id = $1`, templateExerciseID)
	return err
}
