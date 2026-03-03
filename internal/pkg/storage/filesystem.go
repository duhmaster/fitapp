package storage

import (
	"context"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// FilesystemStore implements Store using the local filesystem.
type FilesystemStore struct {
	basePath string
	baseURL  string
}

// NewFilesystemStore creates a local filesystem store.
// basePath: directory for uploads (e.g. ./uploads)
// baseURL: base URL for served files (e.g. http://localhost:8080/uploads)
func NewFilesystemStore(basePath, baseURL string) *FilesystemStore {
	return &FilesystemStore{basePath: basePath, baseURL: strings.TrimSuffix(baseURL, "/")}
}

// Save stores the file and returns the URL.
func (s *FilesystemStore) Save(ctx context.Context, path string, r io.Reader, _ string) (string, error) {
	fullPath := filepath.Join(s.basePath, path)
	dir := filepath.Dir(fullPath)

	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", err
	}

	f, err := os.Create(fullPath)
	if err != nil {
		return "", err
	}
	defer f.Close()

	if _, err := io.Copy(f, r); err != nil {
		os.Remove(fullPath)
		return "", err
	}

	return s.baseURL + "/" + path, nil
}

// Delete removes a file.
func (s *FilesystemStore) Delete(ctx context.Context, path string) error {
	fullPath := filepath.Join(s.basePath, path)
	return os.Remove(fullPath)
}

// Exists checks if a file exists.
func (s *FilesystemStore) Exists(ctx context.Context, path string) (bool, error) {
	fullPath := filepath.Join(s.basePath, path)
	_, err := os.Stat(fullPath)
	if os.IsNotExist(err) {
		return false, nil
	}
	return err == nil, err
}
