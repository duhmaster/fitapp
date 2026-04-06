package repository

import (
	"context"

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
