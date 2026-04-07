package repository

import (
	"context"
	"encoding/json"

	"github.com/fitflow/fitflow/internal/gamification/level"
	"github.com/fitflow/fitflow/internal/gamification/xp"
)

func (r *PG) GetGamificationSetting(ctx context.Context, key string) ([]byte, error) {
	var raw []byte
	err := r.pool.QueryRow(ctx, `SELECT value FROM gamification_settings WHERE key = $1`, key).Scan(&raw)
	if err != nil {
		return nil, err
	}
	return raw, nil
}

func (r *PG) SetGamificationSetting(ctx context.Context, key string, value []byte) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO gamification_settings (key, value, updated_at)
		VALUES ($1, $2::jsonb, NOW())
		ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
	`, key, value)
	return err
}

func (r *PG) getXPCurve(ctx context.Context) xp.Curve {
	raw, err := r.GetGamificationSetting(ctx, "xp_curve")
	if err != nil || len(raw) == 0 {
		return xp.DefaultCurve()
	}
	return xp.CurveFromJSON(raw)
}

func (r *PG) GetLevelThresholds(ctx context.Context) ([]int, error) {
	raw, err := r.GetGamificationSetting(ctx, "level_thresholds")
	if err != nil || len(raw) == 0 {
		return level.CumulativeXPThresholds, nil
	}
	var thresholds []int
	if err := json.Unmarshal(raw, &thresholds); err != nil {
		return level.CumulativeXPThresholds, nil
	}
	return level.NormalizeThresholds(thresholds), nil
}

func (r *PG) SetLevelThresholds(ctx context.Context, thresholds []int) error {
	normalized := level.NormalizeThresholds(thresholds)
	raw, err := json.Marshal(normalized)
	if err != nil {
		return err
	}
	return r.SetGamificationSetting(ctx, "level_thresholds", raw)
}

func (r *PG) getLevelThresholds(ctx context.Context) []int {
	v, err := r.GetLevelThresholds(ctx)
	if err != nil {
		return level.CumulativeXPThresholds
	}
	return v
}
