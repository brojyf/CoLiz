package expense

import (
	"fmt"
	"strings"

	"github.com/brojyf/CoLiz/internal/util/uuidx"
)

func validateUUIDv7(value string) error {
	if !uuidx.IsV7(strings.TrimSpace(value)) {
		return fmt.Errorf("uuid is not v7: %s", value)
	}
	return nil
}
