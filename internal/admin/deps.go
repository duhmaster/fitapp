package admin

import (
	"context"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	blogdomain "github.com/fitflow/fitflow/internal/blog/domain"
	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
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
}
