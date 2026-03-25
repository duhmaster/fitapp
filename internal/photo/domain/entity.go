package domain

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

var ErrPhotoNotFound = errors.New("photo not found")
var ErrBucketNotFound = errors.New("bucket not found")

type Bucket struct {
	ID        uuid.UUID
	Name      string
	Endpoint  string
	Region    string
	PublicURL string
	CreatedAt time.Time
}

type Photo struct {
	ID               uuid.UUID
	BucketID         uuid.UUID
	ObjectKey        string
	URL              string
	UploadedByUserID *uuid.UUID
	CreatedAt        time.Time
}
