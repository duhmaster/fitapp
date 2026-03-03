package redis

import (
	"context"

	"github.com/redis/go-redis/v9"
)

// NewClient creates a Redis client.
func NewClient(addr, password string, db int) *redis.Client {
	return redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: password,
		DB:       db,
	})
}

// Ping verifies the Redis connection is alive.
func Ping(ctx context.Context, client *redis.Client) error {
	return client.Ping(ctx).Err()
}
