package usecase

import (
	"context"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	blogdomain "github.com/fitflow/fitflow/internal/blog/domain"
	"github.com/google/uuid"
)

type BlogUseCase struct {
	posts blogdomain.BlogPostRepository
	photos blogdomain.BlogPostPhotoRepository
	tags  blogdomain.TagRepository
	postTags blogdomain.BlogPostTagRepository
}

func NewBlogUseCase(
	posts blogdomain.BlogPostRepository,
	photos blogdomain.BlogPostPhotoRepository,
	tags blogdomain.TagRepository,
	postTags blogdomain.BlogPostTagRepository,
) *BlogUseCase {
	return &BlogUseCase{
		posts:    posts,
		photos:   photos,
		tags:     tags,
		postTags: postTags,
	}
}

func (uc *BlogUseCase) CreatePost(ctx context.Context, user *authdomain.User, title string, content *string) (*blogdomain.BlogPost, error) {
	return uc.posts.Create(ctx, user.ID, title, content)
}

func (uc *BlogUseCase) GetPost(ctx context.Context, postID uuid.UUID) (*blogdomain.BlogPost, error) {
	return uc.posts.GetByID(ctx, postID)
}

func (uc *BlogUseCase) UpdatePost(ctx context.Context, user *authdomain.User, postID uuid.UUID, title string, content *string) (*blogdomain.BlogPost, error) {
	p, err := uc.posts.GetByID(ctx, postID)
	if err != nil {
		return nil, err
	}
	if p.UserID != user.ID {
		return nil, blogdomain.ErrBlogPostNotFound
	}
	return uc.posts.Update(ctx, postID, title, content)
}

func (uc *BlogUseCase) DeletePost(ctx context.Context, user *authdomain.User, postID uuid.UUID) error {
	p, err := uc.posts.GetByID(ctx, postID)
	if err != nil {
		return err
	}
	if p.UserID != user.ID {
		return blogdomain.ErrBlogPostNotFound
	}
	return uc.posts.SoftDelete(ctx, postID)
}

func (uc *BlogUseCase) ListMyPosts(ctx context.Context, user *authdomain.User, limit, offset int) ([]*blogdomain.BlogPost, error) {
	return uc.posts.ListByUserID(ctx, user.ID, limit, offset)
}

func (uc *BlogUseCase) ListPosts(ctx context.Context, tagID *uuid.UUID, limit, offset int) ([]*blogdomain.BlogPost, error) {
	return uc.posts.List(ctx, tagID, limit, offset)
}

func (uc *BlogUseCase) AddPhoto(ctx context.Context, user *authdomain.User, postID uuid.UUID, url string, sortOrder int) (*blogdomain.BlogPostPhoto, error) {
	p, err := uc.posts.GetByID(ctx, postID)
	if err != nil {
		return nil, err
	}
	if p.UserID != user.ID {
		return nil, blogdomain.ErrBlogPostNotFound
	}
	return uc.photos.Create(ctx, postID, url, sortOrder)
}

func (uc *BlogUseCase) DeletePhoto(ctx context.Context, user *authdomain.User, photoID uuid.UUID) error {
	ph, err := uc.photos.GetByID(ctx, photoID)
	if err != nil {
		return err
	}
	p, err := uc.posts.GetByID(ctx, ph.PostID)
	if err != nil {
		return err
	}
	if p.UserID != user.ID {
		return blogdomain.ErrBlogPostNotFound
	}
	return uc.photos.Delete(ctx, photoID)
}

func (uc *BlogUseCase) ListPhotos(ctx context.Context, postID uuid.UUID) ([]*blogdomain.BlogPostPhoto, error) {
	return uc.photos.ListByPostID(ctx, postID)
}

func (uc *BlogUseCase) CreateTag(ctx context.Context, name string) (*blogdomain.Tag, error) {
	return uc.tags.Create(ctx, name)
}

func (uc *BlogUseCase) GetTag(ctx context.Context, tagID uuid.UUID) (*blogdomain.Tag, error) {
	return uc.tags.GetByID(ctx, tagID)
}

func (uc *BlogUseCase) ListTags(ctx context.Context, limit, offset int) ([]*blogdomain.Tag, error) {
	return uc.tags.List(ctx, limit, offset)
}

func (uc *BlogUseCase) AddTagToPost(ctx context.Context, user *authdomain.User, postID, tagID uuid.UUID) error {
	p, err := uc.posts.GetByID(ctx, postID)
	if err != nil {
		return err
	}
	if p.UserID != user.ID {
		return blogdomain.ErrBlogPostNotFound
	}
	if _, err := uc.tags.GetByID(ctx, tagID); err != nil {
		return err
	}
	return uc.postTags.Add(ctx, postID, tagID)
}

func (uc *BlogUseCase) RemoveTagFromPost(ctx context.Context, user *authdomain.User, postID, tagID uuid.UUID) error {
	p, err := uc.posts.GetByID(ctx, postID)
	if err != nil {
		return err
	}
	if p.UserID != user.ID {
		return blogdomain.ErrBlogPostNotFound
	}
	return uc.postTags.Remove(ctx, postID, tagID)
}

func (uc *BlogUseCase) GetPostTags(ctx context.Context, postID uuid.UUID) ([]uuid.UUID, error) {
	return uc.postTags.TagIDsByPostID(ctx, postID)
}
