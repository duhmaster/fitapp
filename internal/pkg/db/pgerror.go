package db

import (
	"errors"

	"github.com/jackc/pgx/v5/pgconn"
)

// PostgreSQL error codes used for classification.
const (
	// UniqueViolation is Postgres error code 23505.
	UniqueViolation = "23505"
)

// IsUniqueViolation returns true if err is a PostgreSQL unique constraint violation.
func IsUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == UniqueViolation
}

