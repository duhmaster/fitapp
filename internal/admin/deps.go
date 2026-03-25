package admin

import (
	"context"
	"io"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	blogdomain "github.com/fitflow/fitflow/internal/blog/domain"
	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
	photodomain "github.com/fitflow/fitflow/internal/photo/domain"
	systemmessagedomain "github.com/fitflow/fitflow/internal/systemmessage/domain"
	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
)

// Deps holds repositories and config needed for admin handlers.
// Repositories are interfaces to avoid importing all concrete types.
type Deps struct {
	// Config
	AdminUsername string
	AdminPassword string
	// Session secret for cookie signing (use AdminPassword or a dedicated secret)
	SessionSecret string

	// Repos (interfaces) — set concrete impls when wiring
	UsersList    func(ctx context.Context, limit, offset int, search string) ([]*authdomain.UserRecord, error)
	UsersGet     func(ctx context.Context, id uuid.UUID) (*authdomain.UserRecord, error)
	UsersUpdateRole func(ctx context.Context, id uuid.UUID, role authdomain.Role) error

	GymsSearch   func(ctx context.Context, q, city string, lat, lng *float64, limit, offset int) ([]*gymdomain.Gym, error)
	GymsCreate   func(ctx context.Context, name string, lat, lng *float64, address string) (*gymdomain.Gym, error)
	GymsGet      func(ctx context.Context, id uuid.UUID) (*gymdomain.Gym, error)
	GymsUpdate   func(ctx context.Context, id uuid.UUID, name string, lat, lng *float64, address string) (*gymdomain.Gym, error)
	GymsDelete   func(ctx context.Context, id uuid.UUID) error

	ExercisesList   func(ctx context.Context, limit, offset int, filters *workoutdomain.ExerciseFilters) ([]*workoutdomain.Exercise, error)
	ExercisesGet    func(ctx context.Context, id uuid.UUID) (*workoutdomain.Exercise, error)
	ExercisesCreate func(ctx context.Context, e *workoutdomain.Exercise) (*workoutdomain.Exercise, error)
	ExercisesUpdate func(ctx context.Context, e *workoutdomain.Exercise) (*workoutdomain.Exercise, error)
	ExercisesDelete func(ctx context.Context, id uuid.UUID) error

	ProgramsList   func(ctx context.Context, userID *uuid.UUID, limit, offset int) ([]*workoutdomain.Program, error)
	ProgramsGet    func(ctx context.Context, id uuid.UUID) (*workoutdomain.Program, error)
	ProgramsCreate func(ctx context.Context, name, description string, createdBy *uuid.UUID) (*workoutdomain.Program, error)
	ProgramsUpdate func(ctx context.Context, id uuid.UUID, name, description string, createdBy *uuid.UUID) (*workoutdomain.Program, error)
	ProgramsDelete func(ctx context.Context, id uuid.UUID) error

	TagsList    func(ctx context.Context, limit, offset int) ([]*blogdomain.Tag, error)
	TagsGet     func(ctx context.Context, id uuid.UUID) (*blogdomain.Tag, error)
	TagsCreate  func(ctx context.Context, name string) (*blogdomain.Tag, error)
	TagsDelete  func(ctx context.Context, id uuid.UUID) error

	BlogPostsList   func(ctx context.Context, tagID *uuid.UUID, limit, offset int) ([]*blogdomain.BlogPost, error)
	BlogPostsGet    func(ctx context.Context, id uuid.UUID) (*blogdomain.BlogPost, error)
	BlogPostsCreate func(ctx context.Context, userID uuid.UUID, title string, content *string) (*blogdomain.BlogPost, error)
	BlogPostsUpdate func(ctx context.Context, id uuid.UUID, title string, content *string) (*blogdomain.BlogPost, error)
	BlogPostsDelete func(ctx context.Context, id uuid.UUID) error

	SystemMessagesList   func(ctx context.Context, limit, offset int) ([]*systemmessagedomain.SystemMessage, error)
	SystemMessagesGet    func(ctx context.Context, id uuid.UUID) (*systemmessagedomain.SystemMessage, error)
	SystemMessagesCreate func(ctx context.Context, title, body string, isActive bool) (*systemmessagedomain.SystemMessage, error)
	SystemMessagesUpdate func(ctx context.Context, id uuid.UUID, title, body string, isActive bool) (*systemmessagedomain.SystemMessage, error)
	SystemMessagesDelete func(ctx context.Context, id uuid.UUID) error

	BucketsList   func(ctx context.Context) ([]*photodomain.Bucket, error)
	BucketsGet    func(ctx context.Context, id uuid.UUID) (*photodomain.Bucket, error)
	BucketsCreate func(ctx context.Context, name, endpoint, region, publicURL string) (*photodomain.Bucket, error)
	BucketsUpdate func(ctx context.Context, id uuid.UUID, name, endpoint, region, publicURL string) (*photodomain.Bucket, error)
	BucketsDelete func(ctx context.Context, id uuid.UUID) error

	PhotosList   func(ctx context.Context, limit, offset int) ([]*photodomain.Photo, error)
	PhotosGet    func(ctx context.Context, id uuid.UUID) (*photodomain.Photo, error)
	PhotosUpload func(ctx context.Context, bucketName string, r io.Reader, contentType string) (photoID uuid.UUID, url string, err error)
	PhotosDelete func(ctx context.Context, id uuid.UUID) error
}
