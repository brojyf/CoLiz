package auth

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"
	math "math/rand/v2"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/policy/authpol"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/repo/auth"
	svc "github.com/brojyf/CoLiz/internal/service"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/brojyf/CoLiz/internal/util/logx"
	"golang.org/x/crypto/bcrypt"
)

type TokenConfig struct {
	TokenType string
	ExpiresIn int64

	RTKPepperVersion string
	RTKPepperMap     map[string][]byte
	RTKTTL           time.Duration
}

type SetPwdParam struct {
	DeviceID string
	Password string
	TicketID string
}

type LoginParam struct {
	Email    string
	DeviceID string
	Password string
}

func (s *service) Register(ctx context.Context, p SetPwdParam) (domain.AuthTokens, error) {
	repoParam := auth.ConsumeTicketParam{
		TicketID:    p.TicketID,
		DeviceID:    p.DeviceID,
		TargetScene: authpol.SignupString,
		RL:          s.cfg.Register,
	}
	email, err := s.repo.ConsumeTicketAndThrottle(ctx, repoParam)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return domain.AuthTokens{}, err
		case errors.Is(err, repo.ErrUnauthorized):
			return domain.AuthTokens{}, svc.ErrUnauthorized
		case errors.Is(err, repo.ErrRateLimit):
			return domain.AuthTokens{}, svc.ErrRateLimit
		default:
			logx.Error(ctx, "auth.register", err)
			return domain.AuthTokens{}, svc.ErrInternal
		}
	}

	pwdHash, err := hashPassword(p.Password)
	if err != nil {
		logx.Error(ctx, "auth.register", err)
		return domain.AuthTokens{}, svc.ErrInternal
	}

	user := domain.NewUser(
		domain.WithNewUserID(),
		domain.WithEmail(email),
		domain.WithDeviceID(p.DeviceID),
		domain.WithPasswordHash(pwdHash),
		domain.WithUsername(authpol.RandNames[math.IntN(len(authpol.RandNames))]),
	)

	atk, rtk, rtkVersion, err := s.signTokens(user)
	if err != nil {
		logx.Error(ctx, "auth.register", err)
		return domain.AuthTokens{}, svc.ErrInternal
	}

	err = s.repo.CreateUser(ctx, user)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return domain.AuthTokens{}, err
		case errors.Is(err, repo.ErrConflict):
			return domain.AuthTokens{}, svc.ErrConflict
		default:
			logx.Error(ctx, "auth.register", err)
			return domain.AuthTokens{}, svc.ErrInternal
		}
	}

	tk := domain.NewAuthTokens(
		domain.WithAccessToken(atk),
		domain.WithTokenType(s.cfg.Token.TokenType),
		domain.WithExpiresIn(s.cfg.Token.ExpiresIn),
		domain.WithRefreshToken(concatRTK(rtkVersion, rtk)),
	)

	return *tk, nil
}

func (s *service) ResetPwd(ctx context.Context, p SetPwdParam) (domain.AuthTokens, error) {
	repoParam := auth.ConsumeTicketParam{
		TicketID:    p.TicketID,
		DeviceID:    p.DeviceID,
		TargetScene: authpol.ResetString,
		RL:          s.cfg.Register,
	}
	email, err := s.repo.ConsumeTicketAndThrottle(ctx, repoParam)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return domain.AuthTokens{}, err
		case errors.Is(err, repo.ErrUnauthorized):
			return domain.AuthTokens{}, svc.ErrUnauthorized
		case errors.Is(err, repo.ErrRateLimit):
			return domain.AuthTokens{}, svc.ErrRateLimit
		default:
			logx.Error(ctx, "auth.createAccount", err)
			return domain.AuthTokens{}, svc.ErrInternal
		}
	}

	pwdHash, err := hashPassword(p.Password)
	if err != nil {
		logx.Error(ctx, "auth.resetPwd", err)
		return domain.AuthTokens{}, svc.ErrInternal
	}

	user := domain.NewUser (
	    domain.WithEmail(email),
		domain.WithDeviceID(p.DeviceID),
		domain.WithPasswordHash(pwdHash),	
	)

	rtk, rtkVersion, err := s.generateRTK(user)
	if err != nil {
		logx.Error(ctx, "auth.resetPwd", err)
		return domain.AuthTokens{}, svc.ErrInternal
	}

	uid, err := s.repo.ResetPassword(ctx, user)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return domain.AuthTokens{}, err
		case errors.Is(err, repo.ErrNotFound):
			return domain.AuthTokens{}, svc.ErrNotFound
		default:
			logx.Error(ctx, "auth.resetPwd", err)
			return domain.AuthTokens{}, svc.ErrInternal
		}
	}

	atk, err := s.jwtUtil.SignATK(uid, p.DeviceID)
	if err != nil {
		logx.Error(ctx, "auth.resetPwd", err)
		return domain.AuthTokens{}, svc.ErrInternal
	}

	tk := domain.NewAuthTokens(
		domain.WithAccessToken(atk),
		domain.WithTokenType(s.cfg.Token.TokenType),
		domain.WithExpiresIn(s.cfg.Token.ExpiresIn),
		domain.WithRefreshToken(concatRTK(rtkVersion, rtk)),
	)

	return *tk, nil
}

func (s *service) Login(ctx context.Context, p LoginParam) (domain.AuthTokens, error) {
	err := s.repo.LoginThrottle(ctx, p.Email, s.cfg.Login)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return domain.AuthTokens{}, err
		case errors.Is(err, repo.ErrRateLimit):
			return domain.AuthTokens{}, svc.ErrRateLimit
		default:
			logx.Error(ctx, "auth.login", err)
			return domain.AuthTokens{}, svc.ErrInternal
		}
	}

	user, err := s.repo.GetUserByEmail(ctx, p.Email)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return domain.AuthTokens{}, err
		case errors.Is(err, repo.ErrNotFound):
			return domain.AuthTokens{}, svc.ErrUnauthorized
		default:
			logx.Error(ctx, "auth.login", err)
			return domain.AuthTokens{}, svc.ErrInternal
		}
	}

	ok := comparePasswordHash(p.Password, user.PasswordHash)
	if !ok { return domain.AuthTokens{}, svc.ErrUnauthorized }

	user.BindDevice(p.DeviceID)
	atk, rtk, rtkVersion, err := s.signTokens(user)
	if err != nil {
		logx.Error(ctx, "auth.login", err)
		return domain.AuthTokens{}, svc.ErrInternal
	}

	err = s.repo.UpdateLogin(ctx, user)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return domain.AuthTokens{}, err
		default:
			logx.Error(ctx, "auth.login", err)
			return domain.AuthTokens{}, svc.ErrInternal
		}
	}

	tk := domain.NewAuthTokens(
		domain.WithAccessToken(atk),
		domain.WithTokenType(s.cfg.Token.TokenType),
		domain.WithExpiresIn(s.cfg.Token.ExpiresIn),
		domain.WithRefreshToken(concatRTK(rtkVersion, rtk)),
	)
	
	return *tk, nil
}

func (s *service) Logout(ctx context.Context, uid string) error {
	err := s.repo.RevokeRTKAndDID(ctx, uid)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return err
		case errors.Is(err, repo.ErrUnauthorized):
			return svc.ErrUnauthorized
		default:
			logx.Error(ctx, "auth.logout", err)
			return svc.ErrInternal
		}
	}

	return nil
}

func (s *service) Refresh(ctx context.Context, rtk, did string) (domain.AuthTokens, error) {
	err := s.repo.RefreshThrottleByRTK(
		ctx,
		rtk,
		s.cfg.Refresh,
	)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return domain.AuthTokens{}, err
		case errors.Is(err, repo.ErrRateLimit):
			return domain.AuthTokens{}, svc.ErrRateLimit
		default:
			logx.Error(ctx, "auth.refresh", err)
			return domain.AuthTokens{}, svc.ErrInternal
		}
	}

	incomingVersion, rtk, ok := parseRTK(rtk)
	if !ok {
		return domain.AuthTokens{}, svc.ErrUnauthorized
	}
	pepper, ok := s.pepper(incomingVersion)
	if !ok {
		return domain.AuthTokens{}, svc.ErrUnauthorized
	}
	hash := hashRTK(rtk, pepper)

	user, err := s.repo.GetUserByRTKHash(ctx, incomingVersion, hash)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return domain.AuthTokens{}, err
		case errors.Is(err, repo.ErrNotFound):
			return domain.AuthTokens{}, svc.ErrUnauthorized
		default:
			logx.Error(ctx, "auth.refresh", err)
			return domain.AuthTokens{}, svc.ErrInternal
		}
	}

	invalid := user.IsRTKValid(did, time.Now())
	if !invalid {
		return domain.AuthTokens{}, svc.ErrUnauthorized
	}

	curV, _, _ := s.curPepper()
	if incomingVersion != curV {
		rtk, curV, err = s.generateRTK(user)
		if err != nil {
			logx.Error(ctx, "auth.refresh", err)
			return domain.AuthTokens{}, svc.ErrInternal
		}

		err = s.repo.UpdateRTKHashByUID(ctx, user)
		if err != nil {
			logx.Error(ctx, "auth.refresh", err)
			return domain.AuthTokens{}, svc.ErrInternal
		}
	}

	atk, err := s.jwtUtil.SignATK(user.ID, did)
	if err != nil {
		logx.Error(ctx, "auth.refresh", err)
		return domain.AuthTokens{}, svc.ErrInternal
	}

	tk := domain.NewAuthTokens(
		domain.WithRefreshToken(concatRTK(curV, rtk)),
		domain.WithAccessToken(atk),
		domain.WithTokenType(s.cfg.Token.TokenType),
		domain.WithExpiresIn(s.cfg.Token.ExpiresIn),
	)

	return *tk, nil
}

func (s *service) ChangePassword(ctx context.Context, uid, old, new string) (domain.AuthTokens, error) {
	user, err := s.repo.GetUserByUID(ctx, &domain.User{ID: uid})
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return domain.AuthTokens{}, err
		case errors.Is(err, repo.ErrNotFound):
			return domain.AuthTokens{}, svc.ErrUnauthorized
		default:
			logx.Error(ctx, "auth.changePassword", err)
			return domain.AuthTokens{}, svc.ErrInternal
		}
	}

	ok := comparePasswordHash(old, user.PasswordHash)
	if !ok {
		return domain.AuthTokens{}, svc.ErrUnauthorized
	}

	atk, rtk, rtkVersion, err := s.signTokens(user)
	if err != nil {
		logx.Error(ctx, "auth.changePassword", err)
		return domain.AuthTokens{}, svc.ErrInternal
	}

	newHash, err := hashPassword(new)
	if err != nil {
		logx.Error(ctx, "auth.changePassword", err)
		return domain.AuthTokens{}, svc.ErrInternal
	}
	user.PasswordHash = newHash

	err = s.repo.UpdatePassword(ctx, user)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return domain.AuthTokens{}, err
		default:
			logx.Error(ctx, "auth.changePassword", err)
			return domain.AuthTokens{}, svc.ErrInternal
		}
	}

	return *domain.NewAuthTokens(
		domain.WithAccessToken(atk),
		domain.WithRefreshToken(concatRTK(rtkVersion, rtk)),
		domain.WithTokenType(s.cfg.Token.TokenType),
		domain.WithExpiresIn(s.cfg.Token.ExpiresIn),
	), nil
}

// Helper functions

// signTokens generates an ATK and RTK for the given user.
// Returns (atk, rtk, rtkVersion) so callers can embed the correct version
// in the refresh token without a second lock acquisition.
func (s *service) signTokens(user *domain.User) (atk, rtk, rtkVersion string, e error) {
	rtk, rtkVersion, err := s.generateRTK(user)
	if err != nil {
		return "", "", "", err
	}

	atk, err = s.jwtUtil.SignATK(user.ID, user.DeviceID)
	if err != nil {
		return "", "", "", err
	}

	return atk, rtk, rtkVersion, nil
}

// generateRTK generates a fresh refresh token using the current pepper.
// Returns (rtk, version) so the caller can build the versioned RTK string
// with the exact version that was used for hashing, avoiding a TOCTOU race.
func (s *service) generateRTK(user *domain.User) (rtk, version string, e error) {
	version, pepper, ok := s.curPepper()
	if !ok || len(pepper) == 0 {
		return "", "", errors.New("invalid pepper")
	}

	b := make([]byte, authpol.RTKBytes)
	if _, err := io.ReadFull(rand.Reader, b); err != nil {
		return "", "", err
	}

	rtk = base64.RawURLEncoding.EncodeToString(b)
	user.UpdateRTK(hashRTK(rtk, pepper), version, time.Now().Add(s.cfg.Token.RTKTTL))

	return rtk, version, nil
}

func concatRTK(v, rtk string) string {
	if len(v) == 0 || len(rtk) == 0 {
		return ""
	}
	return fmt.Sprintf("%s.%s", v, rtk)
}

func parseRTK(rtk string) (string, string, bool) {
	if rtk == "" {
		return "", "", false
	}
	parts := strings.SplitN(rtk, ".", 2)
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return "", "", false
	}
	return parts[0], parts[1], true
}

func hashRTK(rtk string, pepper []byte) string {
	h := hmac.New(sha256.New, pepper)
	h.Write([]byte(rtk))
	return hex.EncodeToString(h.Sum(nil))
}

func comparePasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

func hashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(bytes), err
}
