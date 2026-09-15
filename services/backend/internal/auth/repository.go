package auth

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
)

type User struct {
	ID           string         `db:"id"`
	Name         string         `db:"name"`
	Username     sql.NullString `db:"username"`
	PasswordHash sql.NullString `db:"password_hash"`
	PIN          string         `db:"pin"`
	Role         string         `db:"role"`
	CreatedAt    time.Time      `db:"created_at"`
	UpdatedAt    time.Time      `db:"updated_at"`
	DeletedAt    sql.NullTime   `db:"deleted_at"`
}

type Device struct {
	ID          string       `db:"id"`
	UserID      string       `db:"user_id"`
	Name        string       `db:"name"`
	Type        string       `db:"type"`
	IsActivePOS bool         `db:"is_active_pos"`
	LastSeenAt  sql.NullTime `db:"last_seen_at"`
	LastSyncAt  sql.NullTime `db:"last_sync_at"`
	AppVersion  sql.NullString `db:"app_version"`
	CreatedAt   time.Time    `db:"created_at"`
	RevokedAt   sql.NullTime `db:"revoked_at"`
}

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) CountUsers(ctx context.Context, tx *sqlx.Tx) (int, error) {
	var n int
	err := tx.GetContext(ctx, &n, `SELECT COUNT(*) FROM users`)
	if err != nil {
		return 0, fmt.Errorf("auth.CountUsers: %w", err)
	}
	return n, nil
}

func (r *Repository) InsertOwner(ctx context.Context, tx *sqlx.Tx, u User) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO users (id, name, username, password_hash, pin, role, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, 'owner', $6, $6)`,
		u.ID, u.Name, u.Username, u.PasswordHash, u.PIN, u.CreatedAt)
	if err != nil {
		return fmt.Errorf("auth.InsertOwner: %w", err)
	}
	return nil
}

func (r *Repository) FindByUsername(ctx context.Context, username string) (*User, error) {
	var u User
	err := r.db.GetContext(ctx, &u, `
		SELECT id, name, username, password_hash, pin, role, created_at, updated_at, deleted_at
		FROM users
		WHERE username = $1 AND deleted_at IS NULL`, username)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("auth.FindByUsername: %w", err)
	}
	return &u, nil
}

func (r *Repository) FindByID(ctx context.Context, id string) (*User, error) {
	var u User
	err := r.db.GetContext(ctx, &u, `
		SELECT id, name, username, password_hash, pin, role, created_at, updated_at, deleted_at
		FROM users WHERE id = $1 AND deleted_at IS NULL`, id)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("auth.FindByID: %w", err)
	}
	return &u, nil
}

func (r *Repository) ListUsers(ctx context.Context) ([]User, error) {
	var users []User
	err := r.db.SelectContext(ctx, &users, `
		SELECT id, name, username, password_hash, pin, role, created_at, updated_at, deleted_at
		FROM users WHERE deleted_at IS NULL ORDER BY created_at ASC`)
	if err != nil {
		return nil, fmt.Errorf("auth.ListUsers: %w", err)
	}
	return users, nil
}

func (r *Repository) CountStaff(ctx context.Context) (int, error) {
	var n int
	err := r.db.GetContext(ctx, &n, `
		SELECT COUNT(*) FROM users WHERE role = 'staff' AND deleted_at IS NULL`)
	if err != nil {
		return 0, fmt.Errorf("auth.CountStaff: %w", err)
	}
	return n, nil
}

func (r *Repository) InsertStaff(ctx context.Context, u User) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO users (id, name, pin, role, created_at, updated_at)
		VALUES ($1, $2, $3, 'staff', $4, $4)`,
		u.ID, u.Name, u.PIN, u.CreatedAt)
	if err != nil {
		return fmt.Errorf("auth.InsertStaff: %w", err)
	}
	return nil
}

func (r *Repository) UpsertDevice(ctx context.Context, d Device) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO devices (id, user_id, name, type, is_active_pos, last_seen_at, created_at)
		VALUES ($1, $2, $3, $4, false, $5, $5)
		ON CONFLICT (id) DO UPDATE SET
			user_id = EXCLUDED.user_id,
			name = EXCLUDED.name,
			type = EXCLUDED.type,
			last_seen_at = EXCLUDED.last_seen_at`,
		d.ID, d.UserID, d.Name, d.Type, d.CreatedAt)
	if err != nil {
		return fmt.Errorf("auth.UpsertDevice: %w", err)
	}
	return nil
}

func (r *Repository) FindDevice(ctx context.Context, id string) (*Device, error) {
	var d Device
	err := r.db.GetContext(ctx, &d, `
		SELECT id, user_id, name, type, is_active_pos, last_seen_at, last_sync_at,
		       app_version, created_at, revoked_at
		FROM devices WHERE id = $1`, id)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("auth.FindDevice: %w", err)
	}
	return &d, nil
}

func (r *Repository) TouchDevice(ctx context.Context, id string, seenAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `UPDATE devices SET last_seen_at = $2 WHERE id = $1`, id, seenAt)
	if err != nil {
		return fmt.Errorf("auth.TouchDevice: %w", err)
	}
	return nil
}

func (r *Repository) BeginTx(ctx context.Context) (*sqlx.Tx, error) {
	return r.db.BeginTxx(ctx, nil)
}
