package domain

import (
	"time"

	"github.com/google/uuid"
)

type BlogPost struct {
	ID        uuid.UUID
	UserID    uuid.UUID
	Title     string
	Content   *string
	CreatedAt time.Time
	UpdatedAt time.Time
	DeletedAt *time.Time
}

type BlogPostPhoto struct {
	ID        uuid.UUID
	PostID    uuid.UUID
	URL       string
	SortOrder int
}

type Tag struct {
	ID   uuid.UUID
	Name string
}

type BlogPostTag struct {
	PostID uuid.UUID
	TagID  uuid.UUID
}
