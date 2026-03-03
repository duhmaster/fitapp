package domain

import "errors"

var (
	ErrUserNotFound      = errors.New("user not found")
	ErrUserAlreadyExists = errors.New("user with this email already exists")
	ErrInvalidPassword   = errors.New("invalid password")
	ErrInvalidToken      = errors.New("invalid or expired token")
)
