package auth

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"sync"
	"time"
	"unicode"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"github.com/zwecodes/g9pos/backend/pkg/middleware"
)

const (
	accessTTL  = 15 * time.Minute
	refreshTTL = 30 * 24 * time.Hour
	lockAfter  = 5
	lockFor    = 15 * time.Minute
	bcryptCost = 10
)

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrAccountLocked      = errors.New("account locked")
	ErrSetupComplete      = errors.New("setup already complete")
	ErrStaffLimit         = errors.New("staff limit reached")
	ErrValidation         = errors.New("validation")
	ErrUnauthorized       = errors.New("unauthorized")
)

type Service struct {
	repo      *Repository
	jwtSecret []byte

	lockMu sync.Mutex
	fails  map[string]failState
	denied map[string]time.Time
}

type failState struct {
	count    int
	lockedAt time.Time
}

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresAt    int64  `json:"expires_at"`
	User         PublicUser `json:"user"`
}

type PublicUser struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Username  string `json:"username,omitempty"`
	Role      string `json:"role"`
	CreatedAt int64  `json:"created_at,omitempty"`
}

type SetupInput struct {
	Username string
	Password string
	Name     string
	PIN      string
}

type LoginInput struct {
	Username     string
	Password     string
	DeviceID     string
	DeviceName   string
	DeviceType   string
	LoginContext string
}

func NewService(repo *Repository, jwtSecret string) *Service {
	return &Service{
		repo:      repo,
		jwtSecret: []byte(jwtSecret),
		fails:     map[string]failState{},
		denied:    map[string]time.Time{},
	}
}

func (s *Service) Setup(ctx context.Context, in SetupInput) (PublicUser, error) {
	if err := validateSetup(in); err != nil {
		return PublicUser{}, err
	}
	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return PublicUser{}, err
	}
	defer tx.Rollback()

	n, err := s.repo.CountUsers(ctx, tx)
	if err != nil {
		return PublicUser{}, err
	}
	if n > 0 {
		return PublicUser{}, ErrSetupComplete
	}

	now := time.Now().UTC()
	id := uuid.NewString()
	passHash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcryptCost)
	if err != nil {
		return PublicUser{}, fmt.Errorf("auth.Setup hash password: %w", err)
	}
	pinHash, err := bcrypt.GenerateFromPassword([]byte(in.PIN), bcryptCost)
	if err != nil {
		return PublicUser{}, fmt.Errorf("auth.Setup hash pin: %w", err)
	}
	u := User{
		ID:           id,
		Name:         in.Name,
		Username:     sql.NullString{String: in.Username, Valid: true},
		PasswordHash: sql.NullString{String: string(passHash), Valid: true},
		PIN:          string(pinHash),
		Role:         "owner",
		CreatedAt:    now,
	}
	if err := s.repo.InsertOwner(ctx, tx, u); err != nil {
		return PublicUser{}, err
	}
	if err := tx.Commit(); err != nil {
		return PublicUser{}, fmt.Errorf("auth.Setup commit: %w", err)
	}
	return PublicUser{ID: id, Name: in.Name, Username: in.Username, Role: "owner"}, nil
}

func (s *Service) Login(ctx context.Context, in LoginInput) (TokenPair, int, error) {
	if in.Username == "" || in.Password == "" || in.DeviceID == "" {
		return TokenPair{}, 0, ErrValidation
	}
	if retry, locked := s.lockRetry(in.Username); locked {
		return TokenPair{}, retry, ErrAccountLocked
	}

	u, err := s.repo.FindByUsername(ctx, in.Username)
	if err != nil {
		return TokenPair{}, 0, err
	}
	if u == nil || !u.PasswordHash.Valid {
		s.recordFail(in.Username)
		return TokenPair{}, 0, ErrInvalidCredentials
	}
	if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash.String), []byte(in.Password)) != nil {
		s.recordFail(in.Username)
		return TokenPair{}, 0, ErrInvalidCredentials
	}
	s.clearFails(in.Username)

	role := u.Role
	if in.LoginContext == "dashboard" {
		role = "dashboard_viewer"
	}

	now := time.Now().UTC()
	name := in.DeviceName
	if name == "" {
		name = "POS device"
	}
	typ := in.DeviceType
	if typ == "" {
		typ = "tablet"
	}
	if err := s.repo.UpsertDevice(ctx, Device{
		ID:        in.DeviceID,
		UserID:    u.ID,
		Name:      name,
		Type:      typ,
		CreatedAt: now,
	}); err != nil {
		return TokenPair{}, 0, err
	}
	dev, err := s.repo.FindDevice(ctx, in.DeviceID)
	if err != nil {
		return TokenPair{}, 0, err
	}
	if dev != nil && dev.RevokedAt.Valid {
		return TokenPair{}, 0, ErrUnauthorized
	}

	pair, err := s.issueTokens(u, in.DeviceID, role)
	if err != nil {
		return TokenPair{}, 0, err
	}
	return pair, 0, nil
}

func (s *Service) Refresh(ctx context.Context, refreshToken string) (TokenPair, error) {
	claims, err := s.parseToken(refreshToken, "refresh")
	if err != nil {
		return TokenPair{}, ErrUnauthorized
	}
	if s.IsTokenDenied(claims.ID) {
		return TokenPair{}, ErrUnauthorized
	}
	revoked, err := s.IsDeviceRevoked(claims.DeviceID)
	if err != nil {
		return TokenPair{}, err
	}
	if revoked {
		return TokenPair{}, ErrUnauthorized
	}
	s.DenyToken(claims.ID)

	u, err := s.repo.FindByID(ctx, claims.Subject)
	if err != nil {
		return TokenPair{}, err
	}
	if u == nil {
		return TokenPair{}, ErrUnauthorized
	}
	_ = s.repo.TouchDevice(ctx, claims.DeviceID, time.Now().UTC())
	return s.issueTokens(u, claims.DeviceID, claims.Role)
}

func (s *Service) Logout(jti string) {
	if jti != "" {
		s.DenyToken(jti)
	}
}

func (s *Service) CreateStaff(ctx context.Context, name, pin string) (PublicUser, error) {
	if name == "" || !isFourDigitPIN(pin) {
		return PublicUser{}, ErrValidation
	}
	n, err := s.repo.CountStaff(ctx)
	if err != nil {
		return PublicUser{}, err
	}
	if n >= 1 {
		return PublicUser{}, ErrStaffLimit
	}
	pinHash, err := bcrypt.GenerateFromPassword([]byte(pin), bcryptCost)
	if err != nil {
		return PublicUser{}, fmt.Errorf("auth.CreateStaff hash pin: %w", err)
	}
	now := time.Now().UTC()
	id := uuid.NewString()
	if err := s.repo.InsertStaff(ctx, User{
		ID:        id,
		Name:      name,
		PIN:       string(pinHash),
		CreatedAt: now,
	}); err != nil {
		return PublicUser{}, err
	}
	return PublicUser{ID: id, Name: name, Role: "staff", CreatedAt: now.UnixMilli()}, nil
}

func (s *Service) ListUsers(ctx context.Context) ([]PublicUser, error) {
	users, err := s.repo.ListUsers(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]PublicUser, 0, len(users))
	for _, u := range users {
		out = append(out, PublicUser{
			ID:        u.ID,
			Name:      u.Name,
			Role:      u.Role,
			CreatedAt: u.CreatedAt.UnixMilli(),
		})
	}
	return out, nil
}

func (s *Service) ParseAccess(token string) (*middleware.Claims, error) {
	return s.parseToken(token, "access")
}

func (s *Service) UserByID(ctx context.Context, id string) (*User, error) {
	return s.repo.FindByID(ctx, id)
}

func (s *Service) IsDeviceRevoked(deviceID string) (bool, error) {
	if deviceID == "" {
		return false, nil
	}
	d, err := s.repo.FindDevice(context.Background(), deviceID)
	if err != nil {
		return false, err
	}
	if d == nil {
		return false, nil
	}
	return d.RevokedAt.Valid, nil
}

func (s *Service) IsTokenDenied(jti string) bool {
	s.lockMu.Lock()
	defer s.lockMu.Unlock()
	exp, ok := s.denied[jti]
	if !ok {
		return false
	}
	if time.Now().After(exp) {
		delete(s.denied, jti)
		return false
	}
	return true
}

func (s *Service) DenyToken(jti string) {
	s.lockMu.Lock()
	defer s.lockMu.Unlock()
	s.denied[jti] = time.Now().Add(refreshTTL)
}

func (s *Service) issueTokens(u *User, deviceID, role string) (TokenPair, error) {
	now := time.Now()
	accessExp := now.Add(accessTTL)
	access, err := s.sign(u.ID, role, deviceID, "access", accessExp)
	if err != nil {
		return TokenPair{}, err
	}
	refresh, err := s.sign(u.ID, role, deviceID, "refresh", now.Add(refreshTTL))
	if err != nil {
		return TokenPair{}, err
	}
	username := ""
	if u.Username.Valid {
		username = u.Username.String
	}
	return TokenPair{
		AccessToken:  access,
		RefreshToken: refresh,
		ExpiresAt:    accessExp.UnixMilli(),
		User: PublicUser{
			ID:       u.ID,
			Name:     u.Name,
			Username: username,
			Role:     role,
		},
	}, nil
}

func (s *Service) sign(userID, role, deviceID, use string, exp time.Time) (string, error) {
	claims := middleware.Claims{
		Role:     role,
		DeviceID: deviceID,
		TokenUse: use,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			ID:        uuid.NewString(),
			ExpiresAt: jwt.NewNumericDate(exp),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return t.SignedString(s.jwtSecret)
}

func (s *Service) parseToken(raw, wantUse string) (*middleware.Claims, error) {
	parsed, err := jwt.ParseWithClaims(raw, &middleware.Claims{}, func(t *jwt.Token) (any, error) {
		if t.Method != jwt.SigningMethodHS256 {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return s.jwtSecret, nil
	})
	if err != nil || !parsed.Valid {
		return nil, ErrUnauthorized
	}
	claims, ok := parsed.Claims.(*middleware.Claims)
	if !ok || claims.TokenUse != wantUse {
		return nil, ErrUnauthorized
	}
	return claims, nil
}

func (s *Service) lockRetry(username string) (int, bool) {
	s.lockMu.Lock()
	defer s.lockMu.Unlock()
	st, ok := s.fails[username]
	if !ok || st.count < lockAfter {
		return 0, false
	}
	until := st.lockedAt.Add(lockFor)
	if time.Now().After(until) {
		delete(s.fails, username)
		return 0, false
	}
	return int(time.Until(until).Seconds()) + 1, true
}

func (s *Service) recordFail(username string) {
	s.lockMu.Lock()
	defer s.lockMu.Unlock()
	st := s.fails[username]
	st.count++
	if st.count >= lockAfter {
		st.lockedAt = time.Now()
	}
	s.fails[username] = st
}

func (s *Service) clearFails(username string) {
	s.lockMu.Lock()
	defer s.lockMu.Unlock()
	delete(s.fails, username)
}

func validateSetup(in SetupInput) error {
	if in.Username == "" || in.Password == "" || in.Name == "" {
		return ErrValidation
	}
	if !isFourDigitPIN(in.PIN) {
		return ErrValidation
	}
	return nil
}

func isFourDigitPIN(pin string) bool {
	if len(pin) != 4 {
		return false
	}
	for _, r := range pin {
		if !unicode.IsDigit(r) {
			return false
		}
	}
	return true
}
