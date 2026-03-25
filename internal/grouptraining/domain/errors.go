package domain

import "errors"

var (
	ErrGroupTrainingTypeNotFound      = errors.New("group training type not found")
	ErrGroupTrainingTemplateNotFound = errors.New("group training template not found")
	ErrGroupTrainingTemplateForbidden = errors.New("group training template does not belong to trainer")

	ErrGroupTrainingNotFound = errors.New("group training not found")

	ErrRegistrationAlreadyExists = errors.New("already registered for this group training")
	ErrGroupTrainingFull         = errors.New("group training is full")

	ErrFreeUserWeeklyLimitReached = errors.New("free user weekly limit reached")
)

