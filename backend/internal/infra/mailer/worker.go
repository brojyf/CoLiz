package mailer

import (
	"context"
	"fmt"
	"time"

	"github.com/brojyf/CoLiz/internal/util/logx"
)

type Queue interface {
	Dequeue(ctx context.Context, timeout time.Duration) (*OTPEmailJob, error)
	Requeue(ctx context.Context, job *OTPEmailJob) error
}

type Sender interface {
	SendOTPEmail(ctx context.Context, to, scene, otp string) error
}
type DLQStore interface {
	SaveFailedOTPEmail(ctx context.Context, codeID, email, scene string, attempts int, lastErr string) error
}

type Config struct {
	PollTimeout time.Duration
	RetryDelay  time.Duration
	MaxRetry    int
}

type Worker struct {
	q      Queue
	sender Sender
	dlq    DLQStore
	cfg    Config
}

const (
	persistRetryMax      = 5
	persistRetryInterval = 500 * time.Millisecond
)

func NewWorker(q Queue, sender Sender, dlq DLQStore, cfg Config) *Worker {
	if cfg.PollTimeout <= 0 {
		cfg.PollTimeout = 1 * time.Second
	}
	if cfg.MaxRetry <= 0 {
		cfg.MaxRetry = 3
	}

	return &Worker{
		q:      q,
		sender: sender,
		dlq:    dlq,
		cfg:    cfg,
	}
}

func (w *Worker) Run(ctx context.Context) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		default:
		}

		job, err := w.q.Dequeue(ctx, w.cfg.PollTimeout)
		if err != nil {
			logx.Error(ctx, "worker.otp_email.dequeue", err)
			continue
		}
		if job == nil {
			continue
		}

		err = w.sender.SendOTPEmail(ctx, job.Email, job.Scene, job.OTP)
		if err == nil {
			logx.Info(ctx, "worker.otp_email.sent", fmt.Sprintf("email=%s code_id=%s scene=%s", job.Email, job.CodeID, job.Scene))
			continue
		}

		err = w.handleDeliveryFailure(ctx, job, err)
		if err != nil {
			return fmt.Errorf("worker.otp_email.handle_failure: %w", err)
		}
	}
}

func (w *Worker) handleDeliveryFailure(ctx context.Context, job *OTPEmailJob, deliveryErr error) error {
	if deliveryErr == nil {
		return nil
	}

	job.Attempts++
	job.LastError = deliveryErr.Error()

	if job.Attempts > w.cfg.MaxRetry {
		err := w.saveDLQWithRetry(ctx, job)
		if err != nil {
			requeueErr := w.requeueWithRetry(ctx, job)
			if requeueErr != nil {
				return fmt.Errorf("save dlq failed: %v; fallback requeue failed: %w", err, requeueErr)
			}
			logx.Error(ctx, "worker.otp_email.dlq_fallback_requeue", fmt.Errorf("email=%s code_id=%s err=%v", job.Email, job.CodeID, err))
			return nil
		}

		logx.Error(ctx, "worker.otp_email.dlq", fmt.Errorf("email=%s code_id=%s err=%v", job.Email, job.CodeID, deliveryErr))
		return nil
	}

	if w.cfg.RetryDelay > 0 {
		timer := time.NewTimer(w.cfg.RetryDelay)
		select {
		case <-ctx.Done():
			timer.Stop()
			return nil
		case <-timer.C:
		}
	}

	err := w.requeueWithRetry(ctx, job)
	if err != nil {
		return fmt.Errorf("requeue job: %w", err)
	}

	logx.Error(
		ctx,
		"worker.otp_email.retry",
		fmt.Errorf("email=%s code_id=%s attempts=%d err=%v", job.Email, job.CodeID, job.Attempts, deliveryErr),
	)
	return nil
}

func (w *Worker) saveDLQWithRetry(ctx context.Context, job *OTPEmailJob) error {
	var err error
	for i := 0; i < persistRetryMax; i++ {
		err = w.dlq.SaveFailedOTPEmail(ctx, job.CodeID, job.Email, job.Scene, job.Attempts, job.LastError)
		if err == nil {
			return nil
		}
		if !waitRetry(ctx) {
			break
		}
	}
	return err
}

func (w *Worker) requeueWithRetry(ctx context.Context, job *OTPEmailJob) error {
	var err error
	for i := 0; i < persistRetryMax; i++ {
		err = w.q.Requeue(ctx, job)
		if err == nil {
			return nil
		}
		if !waitRetry(ctx) {
			break
		}
	}
	return err
}

func waitRetry(ctx context.Context) bool {
	timer := time.NewTimer(persistRetryInterval)
	defer timer.Stop()

	select {
	case <-ctx.Done():
		return false
	case <-timer.C:
		return true
	}
}
