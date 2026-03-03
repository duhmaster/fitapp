package storage

import (
	"context"
	"io"
)

// Store defines file storage operations (S3-compatible or filesystem).
type Store interface {
	// Save stores the file and returns the public URL.
	Save(ctx context.Context, path string, r io.Reader, contentType string) (string, error)
	// Delete removes a file by path.
	Delete(ctx context.Context, path string) error
	// Exists checks if a file exists.
	Exists(ctx context.Context, path string) (bool, error)
}
