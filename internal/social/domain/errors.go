package domain

import "errors"

var (
	ErrFollowSelf         = errors.New("cannot follow yourself")
	ErrAlreadyFollowing   = errors.New("already following")
	ErrNotFollowing       = errors.New("not following")
	ErrFriendRequestNotFound = errors.New("friend request not found")
	ErrPostNotFound       = errors.New("post not found")
	ErrAlreadyLiked       = errors.New("already liked")
	ErrNotLiked           = errors.New("not liked")
)
