package domain

import "errors"

var (
	ErrExerciseNotFound  = errors.New("exercise not found")
	ErrWorkoutNotFound   = errors.New("workout not found")
	ErrWorkoutForbidden  = errors.New("workout does not belong to user")
	ErrProgramNotFound   = errors.New("program not found")
)
