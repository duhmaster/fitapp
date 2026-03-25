package usecase

import (
	"context"
	"fmt"
	"io"
	"path"
	"strings"

	photodomain "github.com/fitflow/fitflow/internal/photo/domain"
	"github.com/fitflow/fitflow/internal/photo/repository"
	"github.com/fitflow/fitflow/internal/pkg/storage"
	"github.com/google/uuid"
)

// UploadResult is returned after a successful upload.
type UploadResult struct {
	PhotoID uuid.UUID
	URL     string
}

// PhotoUseCase handles photo uploads and CRUD.
type PhotoUseCase struct {
	photoRepo  *repository.PhotoRepository
	bucketRepo *repository.BucketRepository
	s3Store    *storage.S3Store
	fsStore    storage.Store
}

// NewPhotoUseCase creates a new photo use case.
func NewPhotoUseCase(
	photoRepo *repository.PhotoRepository,
	bucketRepo *repository.BucketRepository,
	s3Store *storage.S3Store,
	fsStore storage.Store,
) *PhotoUseCase {
	return &PhotoUseCase{
		photoRepo:  photoRepo,
		bucketRepo: bucketRepo,
		s3Store:    s3Store,
		fsStore:    fsStore,
	}
}

// Upload saves a file and creates a photo record.
func (uc *PhotoUseCase) Upload(ctx context.Context, bucketName string, prefix string, r io.Reader, contentType string, uploadedBy *uuid.UUID) (*UploadResult, error) {
	bucket, err := uc.bucketRepo.GetByName(ctx, bucketName)
	if err != nil {
		return nil, err
	}

	ext := ""
	if contentType != "" {
		if ct := strings.ToLower(contentType); strings.HasPrefix(ct, "image/") {
			switch ct {
			case "image/jpeg", "image/jpg":
				ext = ".jpg"
			case "image/png":
				ext = ".png"
			case "image/gif":
				ext = ".gif"
			case "image/webp":
				ext = ".webp"
			default:
				ext = ".bin"
			}
		}
	}
	if ext == "" {
		ext = ".bin"
	}
	objectPath := path.Join(strings.Trim(prefix, "/"), uuid.New().String()+ext)

	var url string
	if uc.s3Store != nil && bucket.Name != "local" {
		url, err = uc.s3Store.Save(ctx, objectPath, r, contentType)
	} else if uc.fsStore != nil {
		url, err = uc.fsStore.Save(ctx, "photos/"+objectPath, r, contentType)
		if err == nil {
			objectPath = "photos/" + objectPath
		}
	} else {
		return nil, fmt.Errorf("no storage configured for uploads")
	}
	if err != nil {
		return nil, fmt.Errorf("upload: %w", err)
	}

	photo, err := uc.photoRepo.Create(ctx, bucket.ID, objectPath, url, uploadedBy)
	if err != nil {
		return nil, err
	}
	return &UploadResult{PhotoID: photo.ID, URL: photo.URL}, nil
}

// GetByID returns a photo by ID.
func (uc *PhotoUseCase) GetByID(ctx context.Context, id uuid.UUID) (*photodomain.Photo, error) {
	return uc.photoRepo.GetByID(ctx, id)
}

// List returns photos with pagination.
func (uc *PhotoUseCase) List(ctx context.Context, limit, offset int) ([]*photodomain.Photo, error) {
	return uc.photoRepo.List(ctx, limit, offset)
}

// Delete removes a photo record. Does not delete from storage.
func (uc *PhotoUseCase) Delete(ctx context.Context, id uuid.UUID) error {
	return uc.photoRepo.Delete(ctx, id)
}
