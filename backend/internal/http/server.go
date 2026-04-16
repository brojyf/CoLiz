package http

import (
	"context"
	"net/http"

	"github.com/brojyf/CoLiz/internal/config"
	"github.com/brojyf/CoLiz/internal/http/handler"
	"github.com/brojyf/CoLiz/internal/http/middleware"
	"github.com/gin-gonic/gin"
)

type Server struct {
	srv *http.Server
}

func NewServer(cfg config.HTTP, m *middleware.Middlewares, h *handler.Handlers) *Server {
	engine := gin.Default()
	engine.Use(
		gin.Recovery(),
		middleware.RequestID(),
		m.Throttle.M(),
		m.Timeout.M(),
	)
	RegisterRouter(engine, m.ATK.M(), h)

	return &Server{
		srv: &http.Server{
			Addr:    cfg.Address,
			Handler: engine,
		},
	}
}

func (s *Server) Start() error {
	return s.srv.ListenAndServe()
}

func (s *Server) Shutdown(ctx context.Context) error {
	return s.srv.Shutdown(ctx)
}
