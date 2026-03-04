package repository

import (
	"context"
	"errors"

	socialdomain "github.com/fitflow/fitflow/internal/social/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type FriendRequestRepository struct {
	pool *pgxpool.Pool
}

func NewFriendRequestRepository(pool *pgxpool.Pool) *FriendRequestRepository {
	return &FriendRequestRepository{pool: pool}
}

func (r *FriendRequestRepository) Create(ctx context.Context, fromUserID, toUserID uuid.UUID) (*socialdomain.FriendRequest, error) {
	if fromUserID == toUserID {
		return nil, errors.New("cannot send friend request to yourself")
	}

	query := `
		INSERT INTO friend_requests (from_user_id, to_user_id, status)
		VALUES ($1, $2, 'pending')
		RETURNING id, from_user_id, to_user_id, status, created_at
	`
	var fr socialdomain.FriendRequest
	err := r.pool.QueryRow(ctx, query, fromUserID, toUserID).Scan(
		&fr.ID, &fr.FromUserID, &fr.ToUserID, &fr.Status, &fr.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &fr, nil
}

func (r *FriendRequestRepository) GetByID(ctx context.Context, id uuid.UUID) (*socialdomain.FriendRequest, error) {
	query := `
		SELECT id, from_user_id, to_user_id, status, created_at
		FROM friend_requests WHERE id = $1
	`
	var fr socialdomain.FriendRequest
	err := r.pool.QueryRow(ctx, query, id).Scan(&fr.ID, &fr.FromUserID, &fr.ToUserID, &fr.Status, &fr.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, socialdomain.ErrFriendRequestNotFound
		}
		return nil, err
	}
	return &fr, nil
}

func (r *FriendRequestRepository) UpdateStatus(ctx context.Context, id uuid.UUID, status string) (*socialdomain.FriendRequest, error) {
	query := `
		UPDATE friend_requests SET status = $2 WHERE id = $1
		RETURNING id, from_user_id, to_user_id, status, created_at
	`
	var fr socialdomain.FriendRequest
	err := r.pool.QueryRow(ctx, query, id, status).Scan(&fr.ID, &fr.FromUserID, &fr.ToUserID, &fr.Status, &fr.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, socialdomain.ErrFriendRequestNotFound
		}
		return nil, err
	}
	return &fr, nil
}

func (r *FriendRequestRepository) ListIncoming(ctx context.Context, toUserID uuid.UUID, status string, limit, offset int) ([]*socialdomain.FriendRequest, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT id, from_user_id, to_user_id, status, created_at
		FROM friend_requests
		WHERE to_user_id = $1 AND ($2 = '' OR status = $2)
		ORDER BY created_at DESC
		LIMIT $3 OFFSET $4
	`
	rows, err := r.pool.Query(ctx, query, toUserID, status, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*socialdomain.FriendRequest
	for rows.Next() {
		var fr socialdomain.FriendRequest
		if err := rows.Scan(&fr.ID, &fr.FromUserID, &fr.ToUserID, &fr.Status, &fr.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &fr)
	}
	return list, rows.Err()
}

func (r *FriendRequestRepository) ListOutgoing(ctx context.Context, fromUserID uuid.UUID, status string, limit, offset int) ([]*socialdomain.FriendRequest, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT id, from_user_id, to_user_id, status, created_at
		FROM friend_requests
		WHERE from_user_id = $1 AND ($2 = '' OR status = $2)
		ORDER BY created_at DESC
		LIMIT $3 OFFSET $4
	`
	rows, err := r.pool.Query(ctx, query, fromUserID, status, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*socialdomain.FriendRequest
	for rows.Next() {
		var fr socialdomain.FriendRequest
		if err := rows.Scan(&fr.ID, &fr.FromUserID, &fr.ToUserID, &fr.Status, &fr.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &fr)
	}
	return list, rows.Err()
}
