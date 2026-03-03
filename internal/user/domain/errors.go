package domain

import "errors"

var (
	ErrProfileNotFound = errors.New("profile not found")
	ErrForbidden       = errors.New("forbidden: cannot access this resource")
)
