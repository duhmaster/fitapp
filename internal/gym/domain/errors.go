package domain

import "errors"

var (
	ErrGymNotFound = errors.New("gym not found")
	// ErrCoachingPurposeTrainerOnly is returned when a non-trainer links a gym with purpose "coaching".
	ErrCoachingPurposeTrainerOnly = errors.New("coaching gyms are only for trainer accounts")
)
