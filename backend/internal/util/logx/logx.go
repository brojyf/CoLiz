package logx

import (
	"context"
	"log"

	"github.com/brojyf/CoLiz/internal/util/requestid"
)

type key struct{}

func Error(c context.Context, op string, err error) {
	rid, _ := requestid.From(c)
	log.Printf("\033[31m[ERROR]\033[0m request_id=%s op=%s err=%v", rid, op, err)
}
func Info(c context.Context, op, msg string) {
	rid, _ := requestid.From(c)
	log.Printf("[INFO] request_id=%s op=%s msg=%s", rid, op, msg)
}
