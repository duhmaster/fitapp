package domain

import (
	"time"

	"github.com/google/uuid"
)

type SystemMessage struct {
	ID        uuid.UUID
	CreatedAt time.Time
	Title     string
	Body      string
	IsActive  bool
}

