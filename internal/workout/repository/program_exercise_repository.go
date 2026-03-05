package repository

import (
	"context"
	"encoding/json"

	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ProgramExerciseRepository struct {
	pool *pgxpool.Pool
}

func NewProgramExerciseRepository(pool *pgxpool.Pool) *ProgramExerciseRepository {
	return &ProgramExerciseRepository{pool: pool}
}

func (r *ProgramExerciseRepository) ListByProgramID(ctx context.Context, programID uuid.UUID) ([]*workoutdomain.ProgramExercise, error) {
	query := `
		SELECT pe.id, pe.program_id, pe.exercise_id, pe.order_index,
		       e.id, e.name, e.muscle_group, COALESCE(e.equipment, '{}'), COALESCE(e.tags, '{}'), e.description, COALESCE(e.instruction, '{}'),
		       COALESCE(e.muscle_loads, '{}'::jsonb), e.formula, e.difficulty_level, COALESCE(e.is_base, false), COALESCE(e.is_popular, false), COALESCE(e.is_free, true), e.created_at
		FROM program_exercises pe
		JOIN exercises e ON e.id = pe.exercise_id
		WHERE pe.program_id = $1
		ORDER BY pe.order_index ASC, pe.id ASC
	`
	rows, err := r.pool.Query(ctx, query, programID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*workoutdomain.ProgramExercise
	for rows.Next() {
		var pe workoutdomain.ProgramExercise
		var e workoutdomain.Exercise
		var muscleGroup, description, formula, difficultyLevel *string
		var equipment, tags, instruction []string
		var muscleLoads []byte
		err := rows.Scan(&pe.ID, &pe.ProgramID, &pe.ExerciseID, &pe.OrderIndex,
			&e.ID, &e.Name, &muscleGroup, &equipment, &tags, &description, &instruction,
			&muscleLoads, &formula, &difficultyLevel, &e.IsBase, &e.IsPopular, &e.IsFree, &e.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		e.MuscleGroup = muscleGroup
		e.Equipment = equipment
		e.Tags = tags
		e.Description = description
		e.Instruction = instruction
		e.Formula = formula
		e.DifficultyLevel = difficultyLevel
		if len(muscleLoads) > 0 {
			_ = json.Unmarshal(muscleLoads, &e.MuscleLoads)
		}
		if e.MuscleLoads == nil {
			e.MuscleLoads = make(map[string]float64)
		}
		pe.Exercise = &e
		list = append(list, &pe)
	}
	return list, rows.Err()
}

func (r *ProgramExerciseRepository) Create(ctx context.Context, programID, exerciseID uuid.UUID, orderIndex int) (*workoutdomain.ProgramExercise, error) {
	query := `
		INSERT INTO program_exercises (program_id, exercise_id, order_index)
		VALUES ($1, $2, $3)
		RETURNING id, program_id, exercise_id, order_index
	`
	var pe workoutdomain.ProgramExercise
	err := r.pool.QueryRow(ctx, query, programID, exerciseID, orderIndex).Scan(
		&pe.ID, &pe.ProgramID, &pe.ExerciseID, &pe.OrderIndex,
	)
	if err != nil {
		return nil, err
	}
	return &pe, nil
}

func (r *ProgramExerciseRepository) CreateBatch(ctx context.Context, programID uuid.UUID, exerciseIDs []uuid.UUID, orderIndexes []int) error {
	if len(exerciseIDs) != len(orderIndexes) || len(exerciseIDs) == 0 {
		return nil
	}
	for i := range exerciseIDs {
		_, err := r.Create(ctx, programID, exerciseIDs[i], orderIndexes[i])
		if err != nil {
			return err
		}
	}
	return nil
}
