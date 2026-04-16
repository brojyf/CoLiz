package httpx

import (
	"errors"
	"fmt"
	"net/http"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/policy/errormap"
	"github.com/brojyf/CoLiz/internal/util/ctxx"
	"github.com/gin-gonic/gin"
)

var errorMap = map[int]func(*gin.Context){
	400: WriteBadRequest,
	401: WriteUnauthorized,
	409: writeConflict,
	429: writeTooManyRequests,
	500: WriteInternal,
	504: writeTimeout,
}

type err struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

func WriteJSON(c *gin.Context, code int, d any) {
	c.JSON(code, d)
}

func WriteError(c *gin.Context, code int, e, m string) {
	WriteJSON(c, code, err{
		Error:   e,
		Message: m,
	})
}

func WriteErrorAbort(c *gin.Context, code int, e, m string) {
	WriteError(c, code, e, m)
	c.Abort()
}

func SmartError(c *gin.Context, e error) {
	if e == nil {
		return
	}
	if c.Writer.Written() {
		return
	}

	if ctxx.IsCtxError(e) {
		writeTimeout(c)
		return
	}

	for target, code := range errormap.ErrorMap {
		if errors.Is(e, target) {
			fn, ok := errorMap[code]
			if ok {
				fn(c)
				return
			}
			WriteError(c, code, http.StatusText(code), e.Error())
			return
		}
	}

	WriteInternal(c)
}

func WriteBadRequest(c *gin.Context) {
	WriteJSON(c, 400, err{
		Error:   "BAD_REQUEST",
		Message: "Invalid request body.",
	})
}

func WriteUnauthorized(c *gin.Context) {
	WriteJSON(c, 401, err{
		Error:   "UNAUTHORIZED",
		Message: "Unauthorized.",
	})
}

func WriteInternal(c *gin.Context) {
	WriteJSON(c, 500, err{
		Error:   "INTERNAL_SERVER_ERROR",
		Message: "Internal server error. Please try again later.",
	})
}
func ServeAsset(c *gin.Context, asset *domain.FileAsset) {
    content := asset.Content
    if content == nil {
        c.AbortWithStatus(http.StatusNotFound)
        return
    }

    if maxAge := asset.CacheAge; maxAge > 0 {
        c.Header("Cache-Control", fmt.Sprintf("private, max-age=%d", maxAge))
    }

    if ct := asset.ContentType; ct != "" {
        c.Header("Content-Type", ct)
    }

    c.Header("X-Content-Type-Options", "nosniff")

    http.ServeContent(c.Writer, c.Request, asset.Name, asset.ModTime, content)
}

// Helper functions
func writeConflict(c *gin.Context) {
	WriteJSON(c, 409, err{
		Error:   "CONFLICT",
		Message: "Conflict.",
	})
}

func writeTooManyRequests(c *gin.Context) {
	WriteJSON(c, 429, err{
		Error:   "TOO_MANY_REQUESTS",
		Message: "Too many requests.",
	})
}

func writeTimeout(c *gin.Context) {
	WriteJSON(c, 504, err{
		Error:   "GATEWAY_TIMEOUT",
		Message: "Gateway timeout.",
	})
}
