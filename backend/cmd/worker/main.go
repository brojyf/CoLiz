package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/brojyf/CoLiz/internal/config"
	"github.com/brojyf/CoLiz/internal/infra/infradb"
	"github.com/brojyf/CoLiz/internal/infra/infrardb"
	"github.com/brojyf/CoLiz/internal/infra/mailer"
	emaildlqrepo "github.com/brojyf/CoLiz/internal/repo/emaildlq"
)

func main() {
	ctx, stop := signal.NotifyContext(
		context.Background(),
		os.Interrupt,
		syscall.SIGTERM,
	)
	defer stop()

	cfg, err := config.InitConfig()
	if err != nil {
		log.Fatalf("[worker] init config: %v", err)
	}

	db, err := infradb.NewDB(cfg.MySQL)
	if err != nil {
		log.Fatalf("[worker] init mysql: %v", err)
	}
	defer func() {
		_ = db.Close()
	}()

	rdb, err := infrardb.NewRedis(cfg.Redis)
	if err != nil {
		log.Fatalf("[worker] init redis: %v", err)
	}
	defer func() {
		_ = rdb.Close()
	}()

	otpQueue := mailer.NewOTPEmailQueue(
		rdb,
		cfg.Queue.OTPEmailKey,
	)
	dlqStore := emaildlqrepo.NewRepo(db)
	sender, err := mailer.NewResend(cfg.Mail)
	if err != nil {
		log.Fatalf("[worker] init resend mailer: %v", err)
	}

	worker := mailer.NewWorker(
		otpQueue,
		sender,
		dlqStore,
		mailer.Config{
			PollTimeout: cfg.Queue.WorkerPollTimeout,
			RetryDelay:  cfg.Queue.WorkerRetryDelay,
			MaxRetry:    cfg.Queue.WorkerMaxRetry,
		},
	)

	log.Println("[worker] otp email worker starting...")
	err = worker.Run(ctx)
	if err != nil {
		log.Fatalf("[worker] runtime error: %v", err)
	}
	log.Println("[worker] stopped")
}
