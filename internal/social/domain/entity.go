package domain

import (
	"time"

	"github.com/google/uuid"
)

type Follow struct {
	FollowerID  uuid.UUID
	FollowingID uuid.UUID
	CreatedAt   time.Time
}

type FriendRequest struct {
	ID         uuid.UUID
	FromUserID uuid.UUID
	ToUserID   uuid.UUID
	Status     string // pending, accepted, rejected
	CreatedAt  time.Time
}

type Post struct {
	ID        uuid.UUID
	UserID    uuid.UUID
	Content   *string
	CreatedAt time.Time
}

type Like struct {
	ID         uuid.UUID
	UserID     uuid.UUID
	TargetType string
	TargetID   uuid.UUID
	CreatedAt  time.Time
}

type Comment struct {
	ID         uuid.UUID
	UserID     uuid.UUID
	TargetType string
	TargetID   uuid.UUID
	Content    string
	CreatedAt  time.Time
}
