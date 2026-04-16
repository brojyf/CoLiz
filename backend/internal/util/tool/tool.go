package tool

import (
	"mime/multipart"
	"reflect"
	"strings"
	"unicode"
)

const (
	nameMinLen = 1
	nameMaxLen = 32
	msgMinLen  = 1
	msgMaxLen  = 64
)

func Norm(v any, skipFields ...string) {
	skip := make(map[string]struct{}, len(skipFields))
	for _, f := range skipFields {
		skip[f] = struct{}{}
	}

	rv := reflect.ValueOf(v)
	if rv.Kind() != reflect.Pointer {
		return
	}
	rv = rv.Elem()
	if rv.Kind() != reflect.Struct {
		return
	}

	rt := rv.Type()
	for i := 0; i < rv.NumField(); i++ {
		if _, ok := skip[rt.Field(i).Name]; ok {
			continue
		}
		f := rv.Field(i)
		if f.CanSet() && f.Kind() == reflect.String {
			f.SetString(normString(f.String()))
		}
	}
}

func NormAndCheckName(n *string) (ok bool) {
	if n == nil {
		return false
	}
	*n = strings.TrimSpace(*n)
	l := len(*n)
	return l >= nameMinLen && l <= nameMaxLen
}

func NormAndChecMessage(s *string) (ok bool) {
	if s == nil {
		return false
	}
	*s = strings.TrimSpace(*s)
	l := len(*s)
	return l >= msgMinLen && l <= msgMaxLen
}

func NormAndCheckPwd(password *string) (ok bool) {
	if password == nil {
		return false
	}
	*password = strings.TrimSpace(*password)
	l := len(*password)
	var (
		hasMinLen  = l >= 8 && l <= 20
		hasUpper   bool
		hasLower   bool
		hasNumber  bool
		hasSpecial bool
	)
	for _, char := range *password {
		if unicode.IsSpace(char) {
			return false
		}

		switch {
		case unicode.IsLower(char):
			hasLower = true
		case unicode.IsUpper(char):
			hasUpper = true
		case unicode.IsDigit(char):
			hasNumber = true
		case unicode.IsPunct(char) || unicode.IsSymbol(char):
			hasSpecial = true
		}
	}
	return hasMinLen && hasUpper && hasLower && hasNumber && hasSpecial
}

func OpenMultipartFile(header *multipart.FileHeader) (multipart.File, error) {
	return header.Open()
}

func normString(s string) string {
	return strings.ToLower(strings.TrimSpace(s))
}
