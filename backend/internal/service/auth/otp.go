package auth

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/brojyf/CoLiz/internal/policy/ratelimit"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/repo/auth"
	svc "github.com/brojyf/CoLiz/internal/service"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/brojyf/CoLiz/internal/util/logx"
	"github.com/google/uuid"
)

type RequestOTPConfig struct {
	OTPTTL   time.Duration
	RL       ratelimit.RLWindow
	QueueKey string
}

type VerifyOTPConfig struct {
	TicketTTL time.Duration
	ShortRL   ratelimit.RLWindow
	DailyRL   int
}

type VerifyOTPParam struct {
	CodeID   string
	Email    string
	Scene    string
	OTP      string
	DeviceID string
}

func (s *service) RequestOTP(ctx context.Context, email, scene string) (string, error) {
	if s.cfg.RequestOTP.QueueKey == "" {
		logx.Error(ctx, "auth.requestOTP", errors.New("otp email queue key not configured"))
		return "", svc.ErrInternal
	}

	codeID := uuid.NewString()
	otp, err := generateOTP()
	if err != nil {
		logx.Error(ctx, "auth.requestOTP", err)
		return "", svc.ErrInternal
	}

	p := auth.SaveOTPParam{
		CodeID:   codeID,
		Email:    email,
		Scene:    scene,
		OTP:      otp,
		QueueKey: s.cfg.RequestOTP.QueueKey,
		TTL:      s.cfg.RequestOTP.OTPTTL,
		RL:       s.cfg.RequestOTP.RL,
	}
	err = s.repo.SaveOTPThrottleAndEnqueue(ctx, p)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return "", err
		case errors.Is(err, repo.ErrRateLimit):
			return "", svc.ErrRateLimit
		default:
			logx.Error(ctx, "auth.requestOTP", err)
			return "", svc.ErrInternal
		}
	}

	return codeID, nil
}

func (s *service) VerifyOTP(ctx context.Context, p VerifyOTPParam) (string, error) {
	ticketID := uuid.NewString()

	param := auth.VerifyOTPParam{
		CodeID:    p.CodeID,
		Email:     p.Email,
		Scene:     p.Scene,
		OTP:       p.OTP,
		TicketID:  ticketID,
		DeviceID:  p.DeviceID,
		TicketTTL: s.cfg.VerifyOTP.TicketTTL,
		ShortRL:   s.cfg.VerifyOTP.ShortRL,
		DailyRL:   ratelimit.New(s.cfg.VerifyOTP.DailyRL, getDailyTTL()),
	}
	err := s.repo.VerifyOTPAndSaveTicket(ctx, &param)
	if err != nil {
		switch {
		case ctxx.IsCtxError(err):
			return "", err
		case errors.Is(err, repo.ErrUnauthorized):
			return "", svc.ErrUnauthorized
		case errors.Is(err, repo.ErrRateLimit):
			return "", svc.ErrRateLimit
		default:
			logx.Error(ctx, "auth.verifyOTP", err)
			return "", svc.ErrInternal
		}
	}

	return ticketID, nil
}

// Helper methods
func generateOTP() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("%06d", n.Int64()), nil
}

func getDailyTTL() time.Duration {
	now := time.Now()
	tomorrow := now.AddDate(0, 0, 1)
	midnight := time.Date(tomorrow.Year(), tomorrow.Month(), tomorrow.Day(), 0, 0, 0, 0, now.Location())
	ttl := midnight.Sub(now)
	if ttl < time.Second {
		ttl = time.Second
	}
	return ttl
}
