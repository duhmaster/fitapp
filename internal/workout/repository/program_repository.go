package repository

import (
	"context"
	"errors"

	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ProgramRepository struct {
	pool *pgxpool.Pool
}

func NewProgramRepository(pool *pgxpool.Pool) *ProgramRepository {
	return &ProgramRepository{pool: pool}
}

func (r *ProgramRepository) List(ctx context.Context, userID *uuid.UUID, limit, offset int) ([]*workoutdomain.Program, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	var rows pgx.Rows
	if userID != nil {
		query := `
			SELECT id, name, description, created_by, created_at
			FROM programs
			WHERE created_by IS NULL OR created_by = $1
			ORDER BY name ASC
			LIMIT $2 OFFSET $3
		`
		var err error
		rows, err = r.pool.Query(ctx, query, *userID, limit, offset)
		if err != nil {
			return nil, err
		}
	} else {
		query := `
			SELECT id, name, description, created_by, created_at
			FROM programs
			WHERE created_by IS NULL
			ORDER BY name ASC
			LIMIT $1 OFFSET $2
		`
		var err error
		rows, err = r.pool.Query(ctx, query, limit, offset)
		if err != nil {
			return nil, err
		}
	}
	defer rows.Close()

	var list []*workoutdomain.Program
	for rows.Next() {
		var p workoutdomain.Program
		if err := rows.Scan(&p.ID, &p.Name, &p.Description, &p.CreatedBy, &p.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &p)
	}
	return list, rows.Err()
}

func (r *ProgramRepository) GetByID(ctx context.Context, id uuid.UUID) (*workoutdomain.Program, error) {
	query := `
		SELECT id, name, description, created_by, created_at
		FROM programs
		WHERE id = $1
	`
	var p workoutdomain.Program
	err := r.pool.QueryRow(ctx, query, id).Scan(&p.ID, &p.Name, &p.Description, &p.CreatedBy, &p.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, workoutdomain.ErrProgramNotFound
		}
		return nil, err
	}
	return &p, nil
}

func (r *ProgramRepository) Create(ctx context.Context, name, description string, createdBy *uuid.UUID) (*workoutdomain.Program, error) {
	query := `
		INSERT INTO programs (name, description, created_by)
		VALUES ($1, $2, $3)
		RETURNING id, name, description, created_by, created_at
	`
	var p workoutdomain.Program
	err := r.pool.QueryRow(ctx, query, name, description, createdBy).Scan(
		&p.ID, &p.Name, &p.Description, &p.CreatedBy, &p.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *ProgramRepository) Update(ctx context.Context, id uuid.UUID, name, description string, createdBy *uuid.UUID) (*workoutdomain.Program, error) {
	query := `
		UPDATE programs SET name = $2, description = $3, created_by = $4
		WHERE id = $1
		RETURNING id, name, description, created_by, created_at
	`
	var p workoutdomain.Program
	err := r.pool.QueryRow(ctx, query, id, name, description, createdBy).Scan(
		&p.ID, &p.Name, &p.Description, &p.CreatedBy, &p.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, workoutdomain.ErrProgramNotFound
		}
		return nil, err
	}
	return &p, nil
}

func (r *ProgramRepository) Delete(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM programs WHERE id = $1`
	ct, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return workoutdomain.ErrProgramNotFound
	}
	return nil
}
