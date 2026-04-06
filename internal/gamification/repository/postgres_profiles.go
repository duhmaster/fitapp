package repository

import (
	"context"

	gamdomain "github.com/fitflow/fitflow/internal/gamification/domain"
	"github.com/google/uuid"
)

func (r *PG) FetchUserProfilesForLeaderboard(ctx context.Context, userIDs []uuid.UUID) (map[uuid.UUID]gamdomain.LeaderboardProfileRow, error) {
	if len(userIDs) == 0 {
		return map[uuid.UUID]gamdomain.LeaderboardProfileRow{}, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT user_id, COALESCE(display_name, ''), avatar_url
		FROM user_profiles WHERE user_id = ANY($1::uuid[])
	`, userIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make(map[uuid.UUID]gamdomain.LeaderboardProfileRow, len(userIDs))
	for rows.Next() {
		var uid uuid.UUID
		var dn string
		var av *string
		if err := rows.Scan(&uid, &dn, &av); err != nil {
			return nil, err
		}
		out[uid] = gamdomain.LeaderboardProfileRow{DisplayName: dn, AvatarURL: av}
	}
	return out, rows.Err()
}
