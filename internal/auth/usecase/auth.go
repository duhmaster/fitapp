package usecase

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"time"

	"github.com/fitflow/fitflow/internal/auth/domain"
	"golang.org/x/crypto/bcrypt"
)

// AuthUseCase handles authentication operations.
type AuthUseCase struct {
	userRepo         domain.UserRepository
	refreshTokenRepo domain.RefreshTokenRepository
	jwtSecret        []byte
	accessExpiry     time.Duration
	refreshExpiry    time.Duration
}

// NewAuthUseCase creates a new AuthUseCase.
func NewAuthUseCase(
	userRepo domain.UserRepository,
	refreshTokenRepo domain.RefreshTokenRepository,
	jwtSecret []byte,
	accessExpiry, refreshExpiry time.Duration,
) *AuthUseCase {
	return &AuthUseCase{
		userRepo:         userRepo,
		refreshTokenRepo: refreshTokenRepo,
		jwtSecret:        jwtSecret,
		accessExpiry:     accessExpiry,
		refreshExpiry:    refreshExpiry,
	}
}

// RegisterInput for user registration.
type RegisterInput struct {
	Email    string
	Password string
	Role     domain.Role
}

// RegisterOutput contains tokens after successful registration.
type RegisterOutput struct {
	User         *domain.User
	AccessToken  string
	RefreshToken string
	ExpiresIn    int64
}

// Register creates a new user and returns tokens.
func (uc *AuthUseCase) Register(ctx context.Context, in RegisterInput) (*RegisterOutput, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	role := in.Role
	if role == "" {
		role = domain.RoleUser
	}

	rec, err := uc.userRepo.Create(ctx, in.Email, string(hash), role)
	if err != nil {
		return nil, err
	}

	user := &domain.User{
		ID:        rec.ID,
		Email:     rec.Email,
		Role:      rec.Role,
		CreatedAt: rec.CreatedAt,
	}

	return uc.issueTokens(ctx, user)
}

// LoginInput for user login.
type LoginInput struct {
	Email    string
	Password string
}

// LoginOutput contains tokens after successful login.
type LoginOutput struct {
	User         *domain.User
	AccessToken  string
	RefreshToken string
	ExpiresIn    int64
}

// Login authenticates a user and returns tokens.
func (uc *AuthUseCase) Login(ctx context.Context, in LoginInput) (*LoginOutput, error) {
	rec, err := uc.userRepo.GetByEmail(ctx, in.Email)
	if err != nil {
		return nil, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(rec.PasswordHash), []byte(in.Password)); err != nil {
		return nil, domain.ErrInvalidPassword
	}

	user := &domain.User{
		ID:        rec.ID,
		Email:     rec.Email,
		Role:      rec.Role,
		CreatedAt: rec.CreatedAt,
	}

	return uc.issueTokens(ctx, user)
}

// RefreshInput for token refresh.
type RefreshInput struct {
	RefreshToken string
}

// RefreshOutput contains new tokens.
type RefreshOutput struct {
	AccessToken  string
	RefreshToken string
	ExpiresIn    int64
}

// Refresh exchanges a refresh token for new access and refresh tokens (rotation).
func (uc *AuthUseCase) Refresh(ctx context.Context, in RefreshInput) (*RefreshOutput, error) {
	rt, err := uc.refreshTokenRepo.GetByToken(ctx, in.RefreshToken)
	if err != nil {
		return nil, err
	}

	if time.Now().After(rt.ExpiresAt) {
		_ = uc.refreshTokenRepo.DeleteByToken(ctx, in.RefreshToken)
		return nil, domain.ErrInvalidToken
	}

	rec, err := uc.userRepo.GetByID(ctx, rt.UserID)
	if err != nil {
		return nil, err
	}

	user := &domain.User{
		ID:        rec.ID,
		Email:     rec.Email,
		Role:      rec.Role,
		CreatedAt: rec.CreatedAt,
	}

	// Rotation: delete old refresh token
	_ = uc.refreshTokenRepo.DeleteByToken(ctx, in.RefreshToken)

	out, err := uc.issueTokens(ctx, user)
	if err != nil {
		return nil, err
	}

	return &RefreshOutput{
		AccessToken:  out.AccessToken,
		RefreshToken: out.RefreshToken,
		ExpiresIn:    out.ExpiresIn,
	}, nil
}

func (uc *AuthUseCase) issueTokens(ctx context.Context, user *domain.User) (*RegisterOutput, error) {
	accessToken, expiresAt, err := GenerateAccessToken(user, uc.jwtSecret, uc.accessExpiry)
	if err != nil {
		return nil, err
	}

	refreshToken, err := generateSecureToken()
	if err != nil {
		return nil, err
	}

	expiresAtRefresh := time.Now().Add(uc.refreshExpiry)
	if err := uc.refreshTokenRepo.Create(ctx, user.ID, refreshToken, expiresAtRefresh); err != nil {
		return nil, err
	}

	return &RegisterOutput{
		User:         user,
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int64(time.Until(expiresAt).Seconds()),
	}, nil
}

func generateSecureToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}
