package middleware

import (
	"context"
	"errors"
	"time"

	"github.com/brojyf/CoLiz/internal/policy/ratelimit"
	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/repo/auth"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/logx"
	"github.com/gin-gonic/gin"
)

type Throttle struct {
	repo    auth.MiddlewareThrottler
	rl      ratelimit.RLWindow
	timeout time.Duration
}

func NewThrottle(r auth.MiddlewareThrottler, rl ratelimit.RLWindow, timeout time.Duration) *Throttle {
	return &Throttle{repo: r, rl: rl, timeout: timeout}
}

func (t *Throttle) M() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), t.timeout)
		defer cancel()

		ip := c.GetHeader("CF-Connecting-IP")
		if ip == "" {
			ip = c.ClientIP()
		}

		err := t.repo.MiddlewareThrottle(ctx, ip, t.rl)
		if err != nil {
			switch {
			case ctxx.IsCtxError(err):
				httpx.WriteErrorAbort(c, 504, "GATEWAY_TIMEOUT", "Gateway timeout.")
			case errors.Is(err, repo.ErrRateLimit):
				httpx.WriteErrorAbort(c, 429, "TOO_MANY_REQUESTS", "Too many requests.")
			default:
				logx.Error(ctx, "middleware.throttle", err)
				httpx.WriteErrorAbort(c, 500, "INTERNAL_SERVER_ERROR", "Internal server error.")
			}
			return
		}

		c.Next()
	}
}
