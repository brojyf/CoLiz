package mailer

import (
	"context"
	"fmt"

	"github.com/brojyf/CoLiz/internal/config"
	"github.com/resend/resend-go/v2"
)

type Resend struct {
	client *resend.Client
	from   string
}

func NewResend(cfg config.Mail) (*Resend, error) {
	if cfg.ResendAPIKey == "" {
		return nil, fmt.Errorf("resend api key is empty")
	}

	return &Resend{
		client: resend.NewClient(cfg.ResendAPIKey),
		from:   cfg.From,
	}, nil
}

func (r *Resend) SendOTPEmail(ctx context.Context, to, scene, otp string) error {
	subject, purpose := emailSubjectAndPurpose(scene)
	html := fmt.Sprintf(
		`
		    <p>Your CoLiz %s verification code is: <strong>%s</strong></p>
			<p>This code is valid for 3 minutes.</p>
			<p>If you did not request this, ignore this email.</p>
		`,
		purpose,
		otp,
	)

	params := &resend.SendEmailRequest{
		From:    r.from,
		To:      []string{to},
		Subject: subject,
		Html:    html,
	}

	_, err := r.client.Emails.SendWithContext(ctx, params)
	if err != nil {
		return err
	}

	return nil
}

func emailSubjectAndPurpose(scene string) (string, string) {
	if scene == "reset" {
		return "[CoLiz] Password reset verification code", "password reset"
	}
	return "[CoLiz] Account verification code", "account signup"
}
