package usecase

import (
	"context"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	socialdomain "github.com/fitflow/fitflow/internal/social/domain"
	"github.com/google/uuid"
)

const TargetTypePost = "post"

type SocialUseCase struct {
	follows   socialdomain.FollowRepository
	requests  socialdomain.FriendRequestRepository
	posts     socialdomain.PostRepository
	likes     socialdomain.LikeRepository
	comments  socialdomain.CommentRepository
}

func NewSocialUseCase(
	follows socialdomain.FollowRepository,
	requests socialdomain.FriendRequestRepository,
	posts socialdomain.PostRepository,
	likes socialdomain.LikeRepository,
	comments socialdomain.CommentRepository,
) *SocialUseCase {
	return &SocialUseCase{
		follows:  follows,
		requests: requests,
		posts:    posts,
		likes:    likes,
		comments: comments,
	}
}

func (uc *SocialUseCase) Follow(ctx context.Context, user *authdomain.User, targetUserID uuid.UUID) (*socialdomain.Follow, error) {
	return uc.follows.Create(ctx, user.ID, targetUserID)
}

func (uc *SocialUseCase) Unfollow(ctx context.Context, user *authdomain.User, targetUserID uuid.UUID) error {
	return uc.follows.Delete(ctx, user.ID, targetUserID)
}

func (uc *SocialUseCase) ListFollowing(ctx context.Context, user *authdomain.User, limit, offset int) ([]uuid.UUID, error) {
	return uc.follows.ListFollowingIDs(ctx, user.ID, limit, offset)
}

func (uc *SocialUseCase) ListFollowers(ctx context.Context, user *authdomain.User, limit, offset int) ([]uuid.UUID, error) {
	return uc.follows.ListFollowerIDs(ctx, user.ID, limit, offset)
}

func (uc *SocialUseCase) CreateFriendRequest(ctx context.Context, user *authdomain.User, toUserID uuid.UUID) (*socialdomain.FriendRequest, error) {
	return uc.requests.Create(ctx, user.ID, toUserID)
}

func (uc *SocialUseCase) AcceptFriendRequest(ctx context.Context, user *authdomain.User, requestID uuid.UUID) (*socialdomain.FriendRequest, error) {
	fr, err := uc.requests.GetByID(ctx, requestID)
	if err != nil {
		return nil, err
	}
	if fr.ToUserID != user.ID {
		return nil, socialdomain.ErrFriendRequestNotFound
	}
	return uc.requests.UpdateStatus(ctx, requestID, "accepted")
}

func (uc *SocialUseCase) RejectFriendRequest(ctx context.Context, user *authdomain.User, requestID uuid.UUID) (*socialdomain.FriendRequest, error) {
	fr, err := uc.requests.GetByID(ctx, requestID)
	if err != nil {
		return nil, err
	}
	if fr.ToUserID != user.ID {
		return nil, socialdomain.ErrFriendRequestNotFound
	}
	return uc.requests.UpdateStatus(ctx, requestID, "rejected")
}

func (uc *SocialUseCase) ListIncomingFriendRequests(ctx context.Context, user *authdomain.User, status string, limit, offset int) ([]*socialdomain.FriendRequest, error) {
	return uc.requests.ListIncoming(ctx, user.ID, status, limit, offset)
}

func (uc *SocialUseCase) ListOutgoingFriendRequests(ctx context.Context, user *authdomain.User, status string, limit, offset int) ([]*socialdomain.FriendRequest, error) {
	return uc.requests.ListOutgoing(ctx, user.ID, status, limit, offset)
}

func (uc *SocialUseCase) CreatePost(ctx context.Context, user *authdomain.User, content *string) (*socialdomain.Post, error) {
	return uc.posts.Create(ctx, user.ID, content)
}

func (uc *SocialUseCase) GetPost(ctx context.Context, postID uuid.UUID) (*socialdomain.Post, error) {
	return uc.posts.GetByID(ctx, postID)
}

func (uc *SocialUseCase) GetFeed(ctx context.Context, user *authdomain.User, limit, offset int) ([]*socialdomain.Post, error) {
	followingIDs, err := uc.follows.ListFollowingIDs(ctx, user.ID, 1000, 0)
	if err != nil {
		return nil, err
	}
	// Include own posts in feed
	followingIDs = append(followingIDs, user.ID)
	return uc.posts.ListByUserIDs(ctx, followingIDs, limit, offset)
}

func (uc *SocialUseCase) ListUserPosts(ctx context.Context, targetUserID uuid.UUID, limit, offset int) ([]*socialdomain.Post, error) {
	return uc.posts.ListByUserID(ctx, targetUserID, limit, offset)
}

func (uc *SocialUseCase) Like(ctx context.Context, user *authdomain.User, targetType string, targetID uuid.UUID) (*socialdomain.Like, error) {
	return uc.likes.Create(ctx, user.ID, targetType, targetID)
}

func (uc *SocialUseCase) Unlike(ctx context.Context, user *authdomain.User, targetType string, targetID uuid.UUID) error {
	return uc.likes.Delete(ctx, user.ID, targetType, targetID)
}

func (uc *SocialUseCase) GetLikeCount(ctx context.Context, targetType string, targetID uuid.UUID) (int, error) {
	return uc.likes.CountByTarget(ctx, targetType, targetID)
}

func (uc *SocialUseCase) IsLiked(ctx context.Context, user *authdomain.User, targetType string, targetID uuid.UUID) (bool, error) {
	return uc.likes.IsLiked(ctx, user.ID, targetType, targetID)
}

func (uc *SocialUseCase) AddComment(ctx context.Context, user *authdomain.User, targetType string, targetID uuid.UUID, content string) (*socialdomain.Comment, error) {
	return uc.comments.Create(ctx, user.ID, targetType, targetID, content)
}

func (uc *SocialUseCase) ListComments(ctx context.Context, targetType string, targetID uuid.UUID, limit, offset int) ([]*socialdomain.Comment, error) {
	return uc.comments.ListByTarget(ctx, targetType, targetID, limit, offset)
}
