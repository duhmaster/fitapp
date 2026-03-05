package usecase

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"time"

	"github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/google/uuid"
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

type issuedTokens struct {
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

	toks, err := uc.issueTokens(ctx, user)
	if err != nil {
		return nil, err
	}

	return &RegisterOutput{
		User:         user,
		AccessToken:  toks.AccessToken,
		RefreshToken: toks.RefreshToken,
		ExpiresIn:    toks.ExpiresIn,
	}, nil
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

	toks, err := uc.issueTokens(ctx, user)
	if err != nil {
		return nil, err
	}

	return &LoginOutput{
		User:         user,
		AccessToken:  toks.AccessToken,
		RefreshToken: toks.RefreshToken,
		ExpiresIn:    toks.ExpiresIn,
	}, nil
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

	toks, err := uc.issueTokens(ctx, user)
	if err != nil {
		return nil, err
	}

	return &RefreshOutput{
		AccessToken:  toks.AccessToken,
		RefreshToken: toks.RefreshToken,
		ExpiresIn:    toks.ExpiresIn,
	}, nil
}

func (uc *AuthUseCase) issueTokens(ctx context.Context, user *domain.User) (*issuedTokens, error) {
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

	return &issuedTokens{
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

// MeDetails holds current user preferences and subscription for GET /me.
type MeDetails struct {
	Theme                 string
	Locale                string
	PaidSubscriber        bool
	SubscriptionExpiresAt *string // RFC3339
}

// GetMeDetails returns theme, locale and subscription for the current user.
func (uc *AuthUseCase) GetMeDetails(ctx context.Context, userID uuid.UUID) (*MeDetails, error) {
	rec, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	t, l := rec.Theme, rec.Locale
	if t == "" {
		t = "system"
	}
	if l == "" {
		l = "en"
	}
	var subExp *string
	if rec.SubscriptionExpiresAt != nil {
		s := rec.SubscriptionExpiresAt.Format(time.RFC3339)
		subExp = &s
	}
	return &MeDetails{
		Theme:                 t,
		Locale:                l,
		PaidSubscriber:        rec.PaidSubscriber,
		SubscriptionExpiresAt: subExp,
	}, nil
}

// GetPreferences returns theme and locale for the user.
func (uc *AuthUseCase) GetPreferences(ctx context.Context, userID uuid.UUID) (theme, locale string, err error) {
	rec, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return "", "", err
	}
	t, l := rec.Theme, rec.Locale
	if t == "" {
		t = "system"
	}
	if l == "" {
		l = "en"
	}
	return t, l, nil
}

// UpdatePreferencesInput for updating user preferences.
type UpdatePreferencesInput struct {
	Theme  string
	Locale string
}

// UpdatePreferences updates theme and locale for the user.
func (uc *AuthUseCase) UpdatePreferences(ctx context.Context, userID uuid.UUID, in UpdatePreferencesInput) error {
	theme, locale := in.Theme, in.Locale
	if theme == "" {
		theme = "system"
	}
	if locale == "" {
		locale = "en"
	}
	return uc.userRepo.UpdatePreferences(ctx, userID, theme, locale)
}
