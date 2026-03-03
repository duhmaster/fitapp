package usecase

import (
	"context"
	"testing"
	"time"

	"github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

func TestAuthUseCase_Login_UserNotFound(t *testing.T) {
	uc := NewAuthUseCase(
		&mockUserRepo{getByEmail: func(ctx context.Context, email string) (*domain.UserRecord, error) {
			return nil, domain.ErrUserNotFound
		}},
		&mockRefreshTokenRepo{},
		[]byte("test-secret"),
		15*time.Minute,
		24*time.Hour,
	)

	_, err := uc.Login(context.Background(), LoginInput{
		Email:    "test@example.com",
		Password: "password123",
	})
	if err != domain.ErrUserNotFound {
		t.Errorf("Login() error = %v, want ErrUserNotFound", err)
	}
}

func TestAuthUseCase_Login_InvalidPassword(t *testing.T) {
	uid := uuid.New()
	uc := NewAuthUseCase(
		&mockUserRepo{getByEmail: func(ctx context.Context, email string) (*domain.UserRecord, error) {
			hash, _ := hashPassword("correct")
			return &domain.UserRecord{
				ID:           uid,
				Email:        "test@example.com",
				PasswordHash: hash,
				Role:         domain.RoleUser,
			}, nil
		}},
		&mockRefreshTokenRepo{},
		[]byte("test-secret"),
		15*time.Minute,
		24*time.Hour,
	)

	_, err := uc.Login(context.Background(), LoginInput{
		Email:    "test@example.com",
		Password: "wrong-password",
	})
	if err != domain.ErrInvalidPassword {
		t.Errorf("Login() error = %v, want ErrInvalidPassword", err)
	}
}

type mockUserRepo struct {
	create     func(ctx context.Context, email, passwordHash string, role domain.Role) (*domain.UserRecord, error)
	getByEmail func(ctx context.Context, email string) (*domain.UserRecord, error)
	getByID    func(ctx context.Context, id uuid.UUID) (*domain.UserRecord, error)
}

func (m *mockUserRepo) Create(ctx context.Context, email, passwordHash string, role domain.Role) (*domain.UserRecord, error) {
	if m.create != nil {
		return m.create(ctx, email, passwordHash, role)
	}
	return nil, nil
}

func (m *mockUserRepo) GetByEmail(ctx context.Context, email string) (*domain.UserRecord, error) {
	if m.getByEmail != nil {
		return m.getByEmail(ctx, email)
	}
	return nil, domain.ErrUserNotFound
}

func (m *mockUserRepo) GetByID(ctx context.Context, id uuid.UUID) (*domain.UserRecord, error) {
	if m.getByID != nil {
		return m.getByID(ctx, id)
	}
	return nil, domain.ErrUserNotFound
}

type mockRefreshTokenRepo struct {
	create        func(ctx context.Context, userID uuid.UUID, token string, expiresAt time.Time) error
	getByToken    func(ctx context.Context, token string) (*domain.RefreshToken, error)
	deleteByToken func(ctx context.Context, token string) error
	deleteByUserID func(ctx context.Context, userID uuid.UUID) error
}

func (m *mockRefreshTokenRepo) Create(ctx context.Context, userID uuid.UUID, token string, expiresAt time.Time) error {
	if m.create != nil {
		return m.create(ctx, userID, token, expiresAt)
	}
	return nil
}

func (m *mockRefreshTokenRepo) GetByToken(ctx context.Context, token string) (*domain.RefreshToken, error) {
	if m.getByToken != nil {
		return m.getByToken(ctx, token)
	}
	return nil, domain.ErrInvalidToken
}

func (m *mockRefreshTokenRepo) DeleteByToken(ctx context.Context, token string) error {
	if m.deleteByToken != nil {
		return m.deleteByToken(ctx, token)
	}
	return nil
}

func (m *mockRefreshTokenRepo) DeleteByUserID(ctx context.Context, userID uuid.UUID) error {
	if m.deleteByUserID != nil {
		return m.deleteByUserID(ctx, userID)
	}
	return nil
}

func hashPassword(pw string) (string, error) {
	h, err := bcrypt.GenerateFromPassword([]byte(pw), bcrypt.DefaultCost)
	return string(h), err
}
