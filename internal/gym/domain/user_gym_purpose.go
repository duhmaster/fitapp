package domain

import "fmt"

// UserGymPurpose classifies why a user is linked to a gym.
type UserGymPurpose string

const (
	UserGymPurposePersonal UserGymPurpose = "personal"
	UserGymPurposeCoaching UserGymPurpose = "coaching"
)

// ParseUserGymPurpose returns a purpose from API strings; empty defaults to personal.
func ParseUserGymPurpose(s string) (UserGymPurpose, error) {
	if s == "" {
		return UserGymPurposePersonal, nil
	}
	switch UserGymPurpose(s) {
	case UserGymPurposePersonal, UserGymPurposeCoaching:
		return UserGymPurpose(s), nil
	default:
		return "", fmt.Errorf("invalid purpose: %q", s)
	}
}
