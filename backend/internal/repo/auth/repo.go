package auth

import (
	"context"
	"database/sql"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/policy/ratelimit"
	"github.com/redis/go-redis/v9"
)

type Repo interface {
	SaveOTPThrottleAndEnqueue(context.Context, SaveOTPParam) error
	VerifyOTPAndSaveTicket(context.Context, *VerifyOTPParam) error
	ConsumeTicketAndThrottle(context.Context, ConsumeTicketParam) (string, error)
	CreateUser(ctx context.Context, user *domain.User) error
	ResetPassword(ctx context.Context, user *domain.User) (string, error)
	LoginThrottle(ctx context.Context, email string, rl ratelimit.RLWindow) error
	GetUserByEmail(ctx context.Context, email string) (*domain.User, error)
	UpdateLogin(ctx context.Context, user *domain.User) error
	RefreshThrottleByRTK(ctx context.Context, rtk string, rl ratelimit.RLWindow) error
	GetUserByRTKHash(ctx context.Context, version, hash string) (*domain.User, error)
	GetUserByUID(ctx context.Context, user *domain.User) (*domain.User, error)
	UpdatePassword(ctx context.Context, user *domain.User) error
	UpdateRTKHashByUID(ctx context.Context, user *domain.User) error
	RevokeRTKAndDID(ctx context.Context, uid string) error
	
	AuthVerifier
	MiddlewareThrottler
}

type repoStore struct {
	db  *mySQLStore
	rdb *redisStore
}

func NewRepo(db *sql.DB, rdb *redis.Client) Repo {
	return &repoStore{
		db:  newMySQLStore(db),
		rdb: newRedisStore(rdb),
	}
}

func (r *repoStore) SaveOTPThrottleAndEnqueue(ctx context.Context, p SaveOTPParam) error {
	return r.rdb.saveOTPThrottleAndEnqueue(ctx, p)
}

func (r *repoStore) VerifyOTPAndSaveTicket(ctx context.Context, p *VerifyOTPParam) error {
	return r.rdb.verifyOTPAndSaveTicket(ctx, p)
}

func (r *repoStore) ConsumeTicketAndThrottle(ctx context.Context, p ConsumeTicketParam) (string, error) {
	return r.rdb.consumeTicketAndThrottleByDID(ctx, p)
}

func (r *repoStore) CreateUser(ctx context.Context, user *domain.User) error {
	return r.db.createUser(ctx, user)
}

func (r *repoStore) ResetPassword(ctx context.Context, user *domain.User) (string, error) {
	return r.db.resetPassword(ctx, user)
}

func (r *repoStore) RefreshThrottleByRTK(ctx context.Context, rtk string, rl ratelimit.RLWindow) error {
	return r.rdb.refreshRTKThrottle(ctx, rtk, rl)
}

func (r *repoStore) GetUserByRTKHash(ctx context.Context, version, hash string) (*domain.User, error) {
	return r.db.getUserByRTKHash(ctx, version, hash)
}

func (r *repoStore) LoginThrottle(ctx context.Context, email string, rl ratelimit.RLWindow) error {
	return r.rdb.loginThrottle(ctx, email, rl)
}

func (r *repoStore) GetUserByEmail(ctx context.Context, email string) (*domain.User, error) {
	return r.db.getUserByEmail(ctx, email)
}

func (r *repoStore) UpdateLogin(ctx context.Context, user *domain.User) error {
	return r.db.updateLogin(ctx, user)
}

func (r *repoStore) UpdateRTKHashByUID(ctx context.Context, user *domain.User) error {
	return r.db.updateRTKHashByUID(ctx, user)
}

func (r *repoStore)RevokeRTKAndDID(ctx context.Context, uid string) error {
	return r.db.revokeRTKAndDID(ctx, uid)
}

func (r *repoStore) GetUserByUID(ctx context.Context, user *domain.User) (*domain.User, error) {
	return r.db.getUserByUID(ctx, user)
}

func (r *repoStore) UpdatePassword(ctx context.Context, user *domain.User) error {
	return r.db.updatePassword(ctx, user)
}
