package service

import "errors"

var (
	ErrInvalidInput = errors.New("invalid input")
	ErrUnauthorized = errors.New("unauthorized")
	ErrNotFound     = errors.New("not found")
	ErrConflict     = errors.New("conflict")
	ErrRateLimit    = errors.New("rate limit exceeded")
	ErrInternal     = errors.New("internal server error")

	// Group
	ErrGroupNotSettled  = errors.New("group not settled")
	ErrMemberNotSettled = errors.New("member not settled")
	ErrOwnerCannotLeave = errors.New("group owner cannot leave")
)
