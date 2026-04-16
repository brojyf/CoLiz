package mailer

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/redis/go-redis/v9"
)

const (
	defaultOTPEmailQueueKey = "queue:auth:otp_email"
)

type OTPEmailJob struct {
	CodeID     string `json:"code_id"`
	Email      string `json:"email"`
	Scene      string `json:"scene"`
	OTP        string `json:"otp"`
	Attempts   int    `json:"attempts"`
	EnqueuedAt int64  `json:"enqueued_at"`
	LastError  string `json:"last_error,omitempty"`
}

type OTPEmailQueue struct {
	rdb *redis.Client
	key string
}

func NewOTPEmailQueue(rdb *redis.Client, key string) *OTPEmailQueue {
	if key == "" {
		key = defaultOTPEmailQueueKey
	}

	return &OTPEmailQueue{
		rdb: rdb,
		key: key,
	}
}

func (q *OTPEmailQueue) EnqueueCodeEmail(ctx context.Context, codeID, email, scene, otp string) error {
	job := OTPEmailJob{
		CodeID:     codeID,
		Email:      email,
		Scene:      scene,
		OTP:        otp,
		Attempts:   0,
		EnqueuedAt: time.Now().Unix(),
	}
	return q.enqueue(ctx, &job)
}

func (q *OTPEmailQueue) Dequeue(ctx context.Context, timeout time.Duration) (*OTPEmailJob, error) {
	res, err := q.rdb.BRPop(ctx, timeout, q.key).Result()
	if err != nil {
		if errors.Is(err, redis.Nil) {
			return nil, nil
		}
		return nil, err
	}

	if len(res) != 2 {
		return nil, errors.New("invalid brpop response")
	}

	var job OTPEmailJob
	err = json.Unmarshal([]byte(res[1]), &job)
	if err != nil {
		return nil, err
	}
	return &job, nil
}

func (q *OTPEmailQueue) Requeue(ctx context.Context, job *OTPEmailJob) error {
	return q.enqueue(ctx, job)
}

func (q *OTPEmailQueue) enqueue(ctx context.Context, job *OTPEmailJob) error {
	payload, err := json.Marshal(job)
	if err != nil {
		return err
	}
	return q.rdb.LPush(ctx, q.key, payload).Err()
}
