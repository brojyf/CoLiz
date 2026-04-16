package auth

import (
	"context"
	"sync"

	"github.com/brojyf/CoLiz/internal/domain"
	txinfra "github.com/brojyf/CoLiz/internal/infra/tx"
	"github.com/brojyf/CoLiz/internal/policy/ratelimit"
	"github.com/brojyf/CoLiz/internal/repo/auth"
	"github.com/brojyf/CoLiz/internal/util/jwtx"
)

type Service interface {
	RequestOTP(ctx context.Context, email, scene string) (string, error)
	VerifyOTP(ctx context.Context, p VerifyOTPParam) (string, error)
	Register(ctx context.Context, p SetPwdParam) (domain.AuthTokens, error)
	ResetPwd(ctx context.Context, p SetPwdParam) (domain.AuthTokens, error)
	Login(ctx context.Context, p LoginParam) (domain.AuthTokens, error)
	Logout(ctx context.Context, uid string) error
	Refresh(ctx context.Context, rtk, did string) (domain.AuthTokens, error)
	ChangePassword(ctx context.Context, uid, old, new string) (domain.AuthTokens, error)
	UpdateTokenConfig(curVersion string, pepperMap map[string][]byte)
}

type Config struct {
	Token      TokenConfig
	RequestOTP RequestOTPConfig
	VerifyOTP  VerifyOTPConfig
	Register   ratelimit.RLWindow
	Refresh    ratelimit.RLWindow
	Login      ratelimit.RLWindow
}

type service struct {
	repo    auth.Repo
	jwtUtil jwtx.JWTX
	tx      *txinfra.Transactor
	cfg     Config
	tokenMu sync.RWMutex // protects cfg.Token.{RTKPepperVersion, RTKPepperMap}
}

func NewService(r auth.Repo, c Config, t *txinfra.Transactor, j jwtx.JWTX) Service {
	return &service{repo: r, cfg: c, tx: t, jwtUtil: j}
}

// UpdateTokenConfig hot-swaps the RTK pepper set. Safe to call concurrently.
// The new pepperMap must not be modified by the caller after this call.
func (s *service) UpdateTokenConfig(curVersion string, pepperMap map[string][]byte) {
	s.tokenMu.Lock()
	defer s.tokenMu.Unlock()
	s.cfg.Token.RTKPepperVersion = curVersion
	s.cfg.Token.RTKPepperMap = pepperMap
}

// curPepper atomically returns the current pepper version and its secret.
func (s *service) curPepper() (version string, pepper []byte, ok bool) {
	s.tokenMu.RLock()
	defer s.tokenMu.RUnlock()
	v := s.cfg.Token.RTKPepperVersion
	p, found := s.cfg.Token.RTKPepperMap[v]
	return v, p, found
}

// pepper looks up a pepper by an arbitrary version (used when verifying
// a client's existing refresh token, which may carry an older version).
func (s *service) pepper(version string) ([]byte, bool) {
	s.tokenMu.RLock()
	defer s.tokenMu.RUnlock()
	p, ok := s.cfg.Token.RTKPepperMap[version]
	return p, ok
}
