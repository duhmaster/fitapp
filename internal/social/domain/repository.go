package domain

import (
	"context"

	"github.com/google/uuid"
)

type FollowRepository interface {
	Create(ctx context.Context, followerID, followingID uuid.UUID) (*Follow, error)
	Delete(ctx context.Context, followerID, followingID uuid.UUID) error
	IsFollowing(ctx context.Context, followerID, followingID uuid.UUID) (bool, error)
	ListFollowingIDs(ctx context.Context, followerID uuid.UUID, limit, offset int) ([]uuid.UUID, error)
	ListFollowerIDs(ctx context.Context, followingID uuid.UUID, limit, offset int) ([]uuid.UUID, error)
}

type FriendRequestRepository interface {
	Create(ctx context.Context, fromUserID, toUserID uuid.UUID) (*FriendRequest, error)
	GetByID(ctx context.Context, id uuid.UUID) (*FriendRequest, error)
	UpdateStatus(ctx context.Context, id uuid.UUID, status string) (*FriendRequest, error)
	ListIncoming(ctx context.Context, toUserID uuid.UUID, status string, limit, offset int) ([]*FriendRequest, error)
	ListOutgoing(ctx context.Context, fromUserID uuid.UUID, status string, limit, offset int) ([]*FriendRequest, error)
}

type PostRepository interface {
	Create(ctx context.Context, userID uuid.UUID, content *string) (*Post, error)
	GetByID(ctx context.Context, id uuid.UUID) (*Post, error)
	ListByUserIDs(ctx context.Context, userIDs []uuid.UUID, limit, offset int) ([]*Post, error)
	ListByUserID(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*Post, error)
}

type LikeRepository interface {
	Create(ctx context.Context, userID uuid.UUID, targetType string, targetID uuid.UUID) (*Like, error)
	Delete(ctx context.Context, userID uuid.UUID, targetType string, targetID uuid.UUID) error
	CountByTarget(ctx context.Context, targetType string, targetID uuid.UUID) (int, error)
	IsLiked(ctx context.Context, userID uuid.UUID, targetType string, targetID uuid.UUID) (bool, error)
}

type CommentRepository interface {
	Create(ctx context.Context, userID uuid.UUID, targetType string, targetID uuid.UUID, content string) (*Comment, error)
	ListByTarget(ctx context.Context, targetType string, targetID uuid.UUID, limit, offset int) ([]*Comment, error)
}
