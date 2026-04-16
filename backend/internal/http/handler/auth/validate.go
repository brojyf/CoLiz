package auth

import (
	"net/mail"
	"strings"

	"github.com/brojyf/CoLiz/internal/util/uuidx"
)

func isValidEmail(email string) bool {
	if len(email) == 0 || len(email) > 255 {
		return false
	}

	addr, err := mail.ParseAddress(email)
	return err == nil && addr.Address == email
}

func isValidScene(scene string) bool {
	return scene == "signup" || scene == "reset"
}

func isValidOTP(otp string) bool {
	if len(otp) != 6 {
		return false
	}
	for _, ch := range otp {
		if ch < '0' || ch > '9' {
			return false
		}
	}
	return true
}

func isUUIDv4(value string) bool {
	return uuidx.IsV4(value)
}

func isValidRefreshToken(token string) bool {
	n := len(strings.TrimSpace(token))
	return n >= 46 && n <= 128
}
