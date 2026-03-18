package usecase

import (
	"context"
	_ "embed"
	"encoding/json"

	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
)

//go:embed default_templates.json
var defaultTemplatesJSON []byte

type defaultTemplatesConfig struct {
	Templates []defaultTemplate `json:"templates"`
}

type defaultTemplate struct {
	Name      string                 `json:"name"`
	Exercises []defaultTemplateExercise `json:"exercises"`
}

type defaultTemplateExercise struct {
	Name string              `json:"name"`
	Sets []defaultTemplateSet `json:"sets"`
}

type defaultTemplateSet struct {
	WeightKg float64 `json:"weight_kg"`
	Reps     int     `json:"reps"`
}

type DefaultTemplatesDeps struct {
	Exercises        workoutdomain.ExerciseRepository
	Templates        workoutdomain.WorkoutTemplateRepository
	TemplateExercises workoutdomain.WorkoutTemplateExerciseRepository
	TemplateSets     workoutdomain.TemplateExerciseSetRepository
}

func parseDefaultTemplates() (*defaultTemplatesConfig, error) {
	var cfg defaultTemplatesConfig
	if err := json.Unmarshal(defaultTemplatesJSON, &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (uc *AuthUseCase) ensureDefaultTemplates(ctx context.Context, userID uuid.UUID) error {
	if uc.defaultTemplates == nil {
		return nil
	}
	cfg, err := parseDefaultTemplates()
	if err != nil {
		return err
	}

	// Create templates; if an exercise is missing, just skip that exercise.
	for _, t := range cfg.Templates {
		if t.Name == "" {
			continue
		}
		tpl, err := uc.defaultTemplates.Templates.Create(ctx, t.Name, userID, false, 0)
		if err != nil {
			return err
		}
		for exOrder, ex := range t.Exercises {
			if ex.Name == "" {
				continue
			}
			dbEx, err := uc.defaultTemplates.Exercises.GetByName(ctx, ex.Name)
			if err != nil {
				if err == workoutdomain.ErrExerciseNotFound {
					continue
				}
				return err
			}
			te, err := uc.defaultTemplates.TemplateExercises.Create(ctx, tpl.ID, dbEx.ID, exOrder)
			if err != nil {
				return err
			}
			for setOrder, s := range ex.Sets {
				w := s.WeightKg
				r := s.Reps
				_, err := uc.defaultTemplates.TemplateSets.Create(ctx, te.ID, setOrder, &w, &r)
				if err != nil {
					return err
				}
			}
		}
	}
	return nil
}

