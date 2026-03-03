package usecase

import (
	"errors"
	"fmt"
	"time"

	"github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/google/uuid"
	"github.com/golang-jwt/jwt/v5"
)

// jwtClaims holds JWT payload.
type jwtClaims struct {
	jwt.RegisteredClaims
	UserID string `json:"sub"`
	Email  string `json:"email"`
	Role   string `json:"role"`
}

// GenerateAccessToken creates a signed JWT access token.
func GenerateAccessToken(user *domain.User, secret []byte, expiry time.Duration) (string, time.Time, error) {
	expiresAt := time.Now().Add(expiry)
	claims := jwtClaims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   user.ID.String(),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
		UserID: user.ID.String(),
		Email:  user.Email,
		Role:   string(user.Role),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString(secret)
	if err != nil {
		return "", time.Time{}, err
	}

	return signed, expiresAt, nil
}

// ValidateAccessToken parses and validates a JWT, returning the user context.
func ValidateAccessToken(tokenString string, secret []byte) (*domain.User, error) {
	token, err := jwt.ParseWithClaims(tokenString, &jwtClaims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return secret, nil
	})
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*jwtClaims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid token")
	}

	userID, err := parseUUID(claims.UserID)
	if err != nil {
		return nil, err
	}

	return &domain.User{
		ID:    userID,
		Email: claims.Email,
		Role:  domain.Role(claims.Role),
	}, nil
}

func parseUUID(s string) (uuid.UUID, error) {
	return uuid.Parse(s)
}
