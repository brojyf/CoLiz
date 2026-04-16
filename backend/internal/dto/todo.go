package dto

import "time"

type Todo struct {
	ID            string    `json:"id"`
	GroupID       string    `json:"group_id"`
	Message       string    `json:"message"`
	Done          bool      `json:"done"`
	CreatedBy     string    `json:"created_by"`
	CreatedByName string    `json:"created_by_name"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}
