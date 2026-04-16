package middleware

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type Timeout struct {
	timeout time.Duration
}

func NewTimeout(t time.Duration) *Timeout {
	return &Timeout{timeout: t}
}

func (m *Timeout) M() gin.HandlerFunc {
	if m.timeout <= 0 {
		return func(c *gin.Context) { c.Next() }
	}

	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), m.timeout)
		defer cancel()

		c.Request = c.Request.WithContext(ctx)
		c.Next()

		if errors.Is(ctx.Err(), context.DeadlineExceeded) && !c.Writer.Written() {
			c.AbortWithStatusJSON(http.StatusGatewayTimeout, gin.H{
				"error": "request timed out",
			})
		}
	}
}
