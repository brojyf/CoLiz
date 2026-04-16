package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/brojyf/CoLiz/internal/policy/ratelimit"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/repo/auth/scripts"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/redis/go-redis/v9"
)

type SaveOTPParam struct {
	CodeID   string
	Email    string
	Scene    string
	OTP      string
	QueueKey string
	TTL      time.Duration
	RL       ratelimit.RLWindow
}
type VerifyOTPParam struct {
	CodeID    string
	Email     string
	Scene     string
	OTP       string
	TicketID  string
	DeviceID  string
	TicketTTL time.Duration
	ShortRL   ratelimit.RLWindow
	DailyRL   ratelimit.RLWindow
}
type ConsumeTicketParam struct {
	DeviceID    string
	TicketID    string
	TargetScene string
	RL          ratelimit.RLWindow
}

type OTPVal struct {
	Email string `json:"email"`
	Scene string `json:"scene"`
	OTP   string `json:"otp"`
}
type OTPEmailJobVal struct {
	CodeID     string `json:"code_id"`
	Email      string `json:"email"`
	Scene      string `json:"scene"`
	OTP        string `json:"otp"`
	Attempts   int    `json:"attempts"`
	EnqueuedAt int64  `json:"enqueued_at"`
}
type TicketVal struct {
	Email    string `json:"email"`
	Scene    string `json:"scene"`
	DeviceID string `json:"device_id"`
}

type redisStore struct {
	rdb     *redis.Client
	scripts *scripts.Registry
}

func newRedisStore(rdb *redis.Client) *redisStore {
	return &redisStore{
		rdb:     rdb,
		scripts: scripts.NewRegistry(),
	}
}

func (r *redisStore) saveOTPThrottleAndEnqueue(ctx context.Context, p SaveOTPParam) error {
	k := []string{
		otpKey(p.CodeID),
		otpThKey(p.Email, p.Scene),
		p.QueueKey,
	}
	v, err := json.Marshal(OTPVal{p.Email, p.Scene, p.OTP})
	if err != nil {
		return repo.NewError(repo.ErrInternal, err)
	}
	queuePayload, err := json.Marshal(OTPEmailJobVal{
		CodeID:     p.CodeID,
		Email:      p.Email,
		Scene:      p.Scene,
		OTP:        p.OTP,
		Attempts:   0,
		EnqueuedAt: time.Now().Unix(),
	})
	if err != nil {
		return repo.NewError(repo.ErrInternal, err)
	}

	args := []interface{}{
		string(v),
		int(p.TTL.Seconds()),
		p.RL.RL,
		int(p.RL.TTL.Seconds()),
		string(queuePayload),
	}

	res, err := r.scripts.SaveOTPThrottleAndEnqueue.Run(ctx, r.rdb, k, args...).Int64()
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		return repo.NewError(repo.ErrInternal, err)
	}

	switch res {
	case 1:
		return nil
	case 0:
		return repo.NewError(repo.ErrRateLimit, nil)
	default:
		return repo.NewError(repo.ErrInternal, nil)
	}
}
func (r *redisStore) verifyOTPAndSaveTicket(ctx context.Context, p *VerifyOTPParam) error {
	k := []string{
		otpKey(p.CodeID),
		verifyShortKey(p.Email, p.Scene),
		verifyDailyKey(p.Email, p.Scene),
		ticketKey(p.TicketID),
	}

	ticketVal, err := json.Marshal(&TicketVal{p.Email, p.Scene, p.DeviceID})
	if err != nil {
		return repo.NewError(repo.ErrInternal, err)
	}
	otpVal, err := json.Marshal(OTPVal{p.Email, p.Scene, p.OTP})
	if err != nil {
		return repo.NewError(repo.ErrInternal, err)
	}

	args := []any{
		string(otpVal),
		p.ShortRL.RL,
		int(p.ShortRL.TTL.Seconds()),
		p.DailyRL.RL,
		int(p.DailyRL.TTL.Seconds()),
		string(ticketVal),
		int(p.TicketTTL.Seconds()),
	}

	res, err := r.scripts.ThrottleAndVerifyOTPAndSaveTicket.Run(ctx, r.rdb, k, args...).Int64()
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		return repo.NewError(repo.ErrInternal, err)
	}

	switch res {
	case 1:
		return nil
	case 0:
		return repo.ErrRateLimit
	case -1:
		return repo.ErrUnauthorized
	default:
		return repo.ErrInternal
	}
}
func (r *redisStore) consumeTicketAndThrottleByDID(ctx context.Context, p ConsumeTicketParam) (string, error) {
	k := []string{
		ticketThrottleKey(p.DeviceID),
		ticketKey(p.TicketID),
	}
	args := []interface{}{
		p.DeviceID,
		p.TargetScene,
		p.RL.RL,
		int(p.RL.TTL.Seconds()),
	}

	res, err := r.scripts.ThrottleAndConsumeTicket.Run(ctx, r.rdb, k, args...).Text()
	if err != nil {
		if ctxx.IsCtxError(err) {
			return "", err
		}
		return "", repo.NewError(repo.ErrInternal, err)
	}

	switch res {
	case "throttled":
		return "", repo.NewError(repo.ErrRateLimit, nil)
	case "unauthorized":
		return "", repo.NewError(repo.ErrUnauthorized, nil)
	}

	return res, nil
}
func (r *redisStore) loginThrottle(ctx context.Context, email string, rl ratelimit.RLWindow) error {
	return r.baseThrottle(ctx, loginThrottleKey(email), rl)
}
func (r *redisStore) refreshRTKThrottle(ctx context.Context, rtk string, rl ratelimit.RLWindow) error {
	return r.baseThrottle(ctx, refreshRTKThrottleKey(rtk), rl)
}

// MiddlewareThrottler
func (r *redisStore) middlewareThrottle(ctx context.Context, ip string, rl ratelimit.RLWindow) error {
	return r.baseThrottle(ctx, ipThrottleKey(ip), rl)
}

// Helper Methods
func (r *redisStore) baseThrottle(ctx context.Context, key string, rl ratelimit.RLWindow) error {
	k := []string{key}
	args := []interface{}{
		rl.RL,
		int(rl.TTL.Seconds()),
	}

	res, err := r.scripts.Throttle.Run(ctx, r.rdb, k, args...).Int64()
	if err != nil {
		if ctxx.IsCtxError(err) {
			return err
		}
		return repo.NewError(repo.ErrInternal, err)
	}

	if res != 1 {
		return repo.NewError(repo.ErrRateLimit, nil)
	}

	return nil
}

func otpKey(codeID string) string {
	return fmt.Sprintf("auth:otp:%s", codeID)
}
func otpThKey(email, scene string) string {
	return fmt.Sprintf("auth:otp:th:%s:%s", email, scene)
}
func verifyShortKey(email, scene string) string {
	return fmt.Sprintf("auth:otp:verify:short:th:%s:%s", email, scene)
}
func verifyDailyKey(email, scene string) string {
	return fmt.Sprintf("auth:otp:verify:daily:th:%s:%s", email, scene)
}
func ticketKey(ticketID string) string {
	return fmt.Sprintf("auth:ticket:%s", ticketID)
}
func ticketThrottleKey(did string) string {
	return fmt.Sprintf("auth:ticket:th:%s", did)
}
func loginThrottleKey(email string) string {
	return fmt.Sprintf("auth:login:th:%s", email)
}
func refreshRTKThrottleKey(rtk string) string {
	return fmt.Sprintf("auth:refresh:rtk:th:%s", rtk)
}
func ipThrottleKey(ip string) string {
	return fmt.Sprintf("auth:ip:th:%s", ip)
}
