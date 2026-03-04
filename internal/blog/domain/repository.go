package domain

import (
	"context"

	"github.com/google/uuid"
)

type BlogPostRepository interface {
	Create(ctx context.Context, userID uuid.UUID, title string, content *string) (*BlogPost, error)
	GetByID(ctx context.Context, id uuid.UUID) (*BlogPost, error)
	Update(ctx context.Context, id uuid.UUID, title string, content *string) (*BlogPost, error)
	SoftDelete(ctx context.Context, id uuid.UUID) error
	ListByUserID(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*BlogPost, error)
	List(ctx context.Context, tagID *uuid.UUID, limit, offset int) ([]*BlogPost, error)
}

type BlogPostPhotoRepository interface {
	Create(ctx context.Context, postID uuid.UUID, url string, sortOrder int) (*BlogPostPhoto, error)
	GetByID(ctx context.Context, id uuid.UUID) (*BlogPostPhoto, error)
	Delete(ctx context.Context, id uuid.UUID) error
	ListByPostID(ctx context.Context, postID uuid.UUID) ([]*BlogPostPhoto, error)
}

type TagRepository interface {
	Create(ctx context.Context, name string) (*Tag, error)
	GetByID(ctx context.Context, id uuid.UUID) (*Tag, error)
	GetByName(ctx context.Context, name string) (*Tag, error)
	List(ctx context.Context, limit, offset int) ([]*Tag, error)
}

type BlogPostTagRepository interface {
	Add(ctx context.Context, postID, tagID uuid.UUID) error
	Remove(ctx context.Context, postID, tagID uuid.UUID) error
	TagIDsByPostID(ctx context.Context, postID uuid.UUID) ([]uuid.UUID, error)
	PostIDsByTagID(ctx context.Context, tagID uuid.UUID, limit, offset int) ([]uuid.UUID, error)
}
