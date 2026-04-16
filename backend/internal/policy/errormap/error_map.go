package errormap

import "github.com/brojyf/CoLiz/internal/service"

var ErrorMap = map[error]int{
	service.ErrInvalidInput: 400,
	service.ErrUnauthorized: 401,
	service.ErrNotFound:     404,
	service.ErrConflict:     409,
	service.ErrGroupNotSettled: 409,
	service.ErrMemberNotSettled: 409,
	service.ErrOwnerCannotLeave: 409,
	service.ErrRateLimit:    429,


}
