package auth

import (
	"context"

	"github.com/brojyf/CoLiz/internal/policy/ratelimit"
)

type MiddlewareThrottler interface {
	MiddlewareThrottle(ctx context.Context, ip string, rl ratelimit.RLWindow) error
}

func (r *repoStore) MiddlewareThrottle(ctx context.Context, ip string, rl ratelimit.RLWindow) error {
	return r.rdb.middlewareThrottle(ctx, ip, rl)
}
