package middleware

import (
	"github.com/brojyf/CoLiz/internal/util/requestid"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		rid := c.GetHeader("X-Request-ID")
		if rid == "" {
			rid = uuid.NewString()
		}

		ctx := requestid.With(c.Request.Context(), rid)
		c.Request = c.Request.WithContext(ctx)
		c.Header("X-Request-ID", rid)

		c.Next()
	}
}
