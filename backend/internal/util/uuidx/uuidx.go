package uuidx

import "github.com/google/uuid"

func NewV7() (string, error) {
	v, err := uuid.NewV7()
	if err != nil {
		return "", err
	}
	return v.String(), nil
}

func IsV7(s string) bool {
	id, err := uuid.Parse(s)
	if err != nil {
		return false
	}

	return id.Version() == 7
}

func IsV4(s string) bool {
	id, err := uuid.Parse(s)
	if err != nil {
		return false
	}

	return id.Version() == 4
}
