package domain

// UserFeaturePreferences are per-user toggles for XP, badges, leaderboards (client + server).
type UserFeaturePreferences struct {
	XPEnabled             bool `json:"xp_enabled"`
	BadgesEnabled         bool `json:"badges_enabled"`
	LeaderboardEnabled    bool `json:"leaderboard_enabled"`
	TrainerRankingEnabled bool `json:"trainer_ranking_enabled"`
}

// DefaultUserFeaturePreferences is used when no row exists (should be rare after migration).
func DefaultUserFeaturePreferences() UserFeaturePreferences {
	return UserFeaturePreferences{
		XPEnabled:             true,
		BadgesEnabled:         true,
		LeaderboardEnabled:    true,
		TrainerRankingEnabled: true,
	}
}
