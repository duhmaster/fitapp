package storage

import (
	"context"
	"fmt"
	"io"
	"path"
	"strings"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// S3Store implements Store using S3-compatible storage (Selectel, AWS, etc).
type S3Store struct {
	client    *minio.Client
	bucket    string
	publicURL string // base URL for public access, e.g. http://s3.gymmore.ru
}

// S3Config holds S3 connection parameters.
type S3Config struct {
	Endpoint   string // e.g. s3.ru-7.storage.selcloud.ru
	AccessKey  string
	SecretKey  string
	Bucket     string
	Region     string
	PublicURL  string // e.g. http://s3.gymmore.ru
	UseSSL     bool
}

// NewS3Store creates an S3-compatible store. Returns nil if config is incomplete.
func NewS3Store(cfg S3Config) (*S3Store, error) {
	if cfg.Endpoint == "" || cfg.AccessKey == "" || cfg.SecretKey == "" {
		return nil, nil
	}
	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
		Region: cfg.Region,
	})
	if err != nil {
		return nil, fmt.Errorf("s3 client: %w", err)
	}
	return &S3Store{
		client:    client,
		bucket:    cfg.Bucket,
		publicURL: strings.TrimSuffix(cfg.PublicURL, "/"),
	}, nil
}

// Save stores the file and returns the public URL.
func (s *S3Store) Save(ctx context.Context, objectPath string, r io.Reader, contentType string) (string, error) {
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	_, err := s.client.PutObject(ctx, s.bucket, objectPath, r, -1, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", fmt.Errorf("s3 put object: %w", err)
	}
	return s.publicURL + "/" + path.Join(s.bucket, objectPath), nil
}

// Delete removes a file by path.
func (s *S3Store) Delete(ctx context.Context, objectPath string) error {
	return s.client.RemoveObject(ctx, s.bucket, objectPath, minio.RemoveObjectOptions{})
}

// Exists checks if a file exists.
func (s *S3Store) Exists(ctx context.Context, objectPath string) (bool, error) {
	_, err := s.client.StatObject(ctx, s.bucket, objectPath, minio.StatObjectOptions{})
	if err != nil {
		errResp := minio.ToErrorResponse(err)
		if errResp.Code == "NoSuchKey" {
			return false, nil
		}
		return false, err
	}
	return true, nil
}
