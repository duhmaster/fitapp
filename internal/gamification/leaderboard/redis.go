package leaderboard

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

// Redis maintains sorted sets for fast leaderboard reads (ZINCRBY on XP events).
type Redis struct {
	rdb *redis.Client
}

// New returns a leaderboard helper; nil rdb yields no-op receiver.
func New(rdb *redis.Client) *Redis {
	if rdb == nil {
		return nil
	}
	return &Redis{rdb: rdb}
}

func (r *Redis) OK() bool {
	return r != nil && r.rdb != nil
}

// WeekKey is ISO year-week for key suffix (aligned with weekly SQL windows).
func WeekKey(t time.Time) string {
	y, w := t.UTC().ISOWeek()
	return fmt.Sprintf("%04d-W%02d", y, w)
}

// IncrUserXP increments all relevant leaderboard ZSETs for one XP grant.
func (r *Redis) IncrUserXP(ctx context.Context, userID uuid.UUID, delta int, weekKey string, gymID *uuid.UUID, trainerIDs []uuid.UUID) error {
	if !r.OK() || delta == 0 {
		return nil
	}
	uid := userID.String()
	d := float64(delta)
	pipe := r.rdb.Pipeline()
	pipe.ZIncrBy(ctx, "gam:lb:g:wk:"+weekKey, d, uid)
	pipe.ZIncrBy(ctx, "gam:lb:g:at", d, uid)
	if gymID != nil {
		g := gymID.String()
		pipe.ZIncrBy(ctx, "gam:lb:gym:"+g+":wk:"+weekKey, d, uid)
		pipe.ZIncrBy(ctx, "gam:lb:gym:"+g+":at", d, uid)
	}
	for _, tid := range trainerIDs {
		ts := tid.String()
		pipe.ZIncrBy(ctx, "gam:lb:tr:"+ts+":wk:"+weekKey, d, uid)
		pipe.ZIncrBy(ctx, "gam:lb:tr:"+ts+":at", d, uid)
	}
	_, err := pipe.Exec(ctx)
	return err
}

// TopGlobalWeekly returns Redis ZSET members with scores (member = user_id string).
func (r *Redis) TopGlobalWeekly(ctx context.Context, weekKey string, limit int) ([]redis.Z, error) {
	if !r.OK() || limit <= 0 {
		return nil, nil
	}
	return r.rdb.ZRevRangeWithScores(ctx, "gam:lb:g:wk:"+weekKey, 0, int64(limit-1)).Result()
}

// TopGlobalAllTime returns global all-time top.
func (r *Redis) TopGlobalAllTime(ctx context.Context, limit int) ([]redis.Z, error) {
	if !r.OK() || limit <= 0 {
		return nil, nil
	}
	return r.rdb.ZRevRangeWithScores(ctx, "gam:lb:g:at", 0, int64(limit-1)).Result()
}

// TopGymWeekly scores for a gym/week.
func (r *Redis) TopGymWeekly(ctx context.Context, gymID uuid.UUID, weekKey string, limit int) ([]redis.Z, error) {
	if !r.OK() || limit <= 0 {
		return nil, nil
	}
	return r.rdb.ZRevRangeWithScores(ctx, "gam:lb:gym:"+gymID.String()+":wk:"+weekKey, 0, int64(limit-1)).Result()
}

// TopGymAllTime scores for a gym.
func (r *Redis) TopGymAllTime(ctx context.Context, gymID uuid.UUID, limit int) ([]redis.Z, error) {
	if !r.OK() || limit <= 0 {
		return nil, nil
	}
	return r.rdb.ZRevRangeWithScores(ctx, "gam:lb:gym:"+gymID.String()+":at", 0, int64(limit-1)).Result()
}

// TopTrainerClientsWeekly for trainer's clients.
func (r *Redis) TopTrainerClientsWeekly(ctx context.Context, trainerID uuid.UUID, weekKey string, limit int) ([]redis.Z, error) {
	if !r.OK() || limit <= 0 {
		return nil, nil
	}
	return r.rdb.ZRevRangeWithScores(ctx, "gam:lb:tr:"+trainerID.String()+":wk:"+weekKey, 0, int64(limit-1)).Result()
}

// TopTrainerClientsAllTime for trainer's clients.
func (r *Redis) TopTrainerClientsAllTime(ctx context.Context, trainerID uuid.UUID, limit int) ([]redis.Z, error) {
	if !r.OK() || limit <= 0 {
		return nil, nil
	}
	return r.rdb.ZRevRangeWithScores(ctx, "gam:lb:tr:"+trainerID.String()+":at", 0, int64(limit-1)).Result()
}

// TopScoresOnlyWeekly returns ordered scores (no member ids) for public leaderboard.
func (r *Redis) TopScoresOnlyWeekly(ctx context.Context, weekKey string, limit int) ([]float64, error) {
	if !r.OK() || limit <= 0 {
		return nil, nil
	}
	zs, err := r.rdb.ZRevRangeWithScores(ctx, "gam:lb:g:wk:"+weekKey, 0, int64(limit-1)).Result()
	if err != nil {
		return nil, err
	}
	out := make([]float64, 0, len(zs))
	for _, z := range zs {
		out = append(out, z.Score)
	}
	return out, nil
}
