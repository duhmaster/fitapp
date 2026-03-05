package domain

import "errors"

var (
	ErrExerciseNotFound        = errors.New("exercise not found")
	ErrWorkoutNotFound         = errors.New("workout not found")
	ErrWorkoutForbidden        = errors.New("workout does not belong to user")
	ErrProgramNotFound         = errors.New("program not found")
	ErrTemplateNotFound        = errors.New("template not found")
	ErrTemplateForbidden       = errors.New("template does not belong to user")
	ErrTemplateExerciseNotFound = errors.New("template exercise not found")
)
