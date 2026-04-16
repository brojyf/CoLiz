package middleware

import (
	"errors"
	"strings"

	"github.com/brojyf/CoLiz/internal/repo"
	"github.com/brojyf/CoLiz/internal/repo/auth"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/brojyf/CoLiz/internal/util/httpx"
	"github.com/brojyf/CoLiz/internal/util/jwtx"
	"github.com/brojyf/CoLiz/internal/util/logx"
	"github.com/brojyf/CoLiz/internal/util/uuidx"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

type AccessToken struct {
	repo auth.AuthVerifier
	jwtx jwtx.JWTX
}

func NewAccessToken(repo auth.AuthVerifier, jwtx jwtx.JWTX) *AccessToken {
	return &AccessToken{
		repo: repo,
		jwtx: jwtx,
	}
}

func (m *AccessToken) M() gin.HandlerFunc {
	return func(c *gin.Context) {   
		token, err := extractBearer(c)
		if err != nil {
			httpx.WriteErrorAbort(c, 401, "UNAUTHORIZED", "Unauthorized.")
			return
		}

		claims, err := m.jwtx.ParseATK(token)
		if err != nil {
			if errors.Is(err, jwt.ErrTokenExpired) {
				httpx.WriteErrorAbort(c, 401, "ACCESS_TOKEN_EXPIRED", "Access token expired.")
				return
			}
			httpx.WriteErrorAbort(c, 401, "UNAUTHORIZED", "Unauthorized.")
			return
		}

		ctx := c.Request.Context()
        if !uuidx.IsV7(claims.UserID) || !uuidx.IsV4(claims.DeviceID) {
            httpx.WriteErrorAbort(c, 401, "UNAUTHORIZED", "Unauthorized.")
            return
        }

		err = m.repo.DidMatchUID(ctx, claims.DeviceID, claims.UserID)
		if err != nil {
			switch {
			case ctxx.IsCtxError(err):
				httpx.WriteErrorAbort(c, 504, "GATEWAY_TIMEOUT", "Gateway timeout.")
			case errors.Is(err, repo.ErrUnauthorized):
				httpx.WriteErrorAbort(c, 401, "UNAUTHORIZED", "Unauthorized.")
			case errors.Is(err, repo.ErrInternal):
				logx.Error(ctx, "middleware.accessToken", err)
				httpx.WriteErrorAbort(c, 500, "INTERNAL_SERVER_ERROR", "Internal server error.")
			}
			return
		}

		c.Set("uid", claims.UserID)
		c.Next()
	}
}

func extractBearer(c *gin.Context) (string, error) {
	auth := c.GetHeader("Authorization")

	if auth == "" {
		return "", errors.New("authorization header is empty")
	}
	if !strings.HasPrefix(auth, "Bearer ") {
		return "", errors.New("invalid Authorization format: " + auth)
	}
	token := strings.TrimPrefix(auth, "Bearer ")
	if token == "" {
		return "", errors.New("empty token")
	}
	
	return token, nil
}
