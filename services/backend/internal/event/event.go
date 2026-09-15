package event

import (
	"encoding/json"
	"fmt"
)

type Event struct {
	ID          string          `json:"id"`
	EventType   string          `json:"event_type"`
	DeviceID    string          `json:"device_id"`
	ReferenceID *string         `json:"reference_id"`
	CreatedAt   int64           `json:"created_at"`
	OperatorID  string          `json:"operator_id"`
	Raw         json.RawMessage `json:"-"`
}

type PermanentError struct {
	Reason  string
	Message string
	Detail  map[string]any
}

func (e *PermanentError) Error() string { return e.Reason }

func Reject(reason, message string, detail map[string]any) *PermanentError {
	if detail == nil {
		detail = map[string]any{}
	}
	return &PermanentError{Reason: reason, Message: message, Detail: detail}
}

type ConflictError struct {
	WinningPayload any
}

func (e *ConflictError) Error() string { return "conflict" }

func Unmarshal(raw json.RawMessage) (Event, error) {
	var ev Event
	if err := json.Unmarshal(raw, &ev); err != nil {
		return Event{}, fmt.Errorf("sync event: %w", err)
	}
	ev.Raw = raw
	return ev, nil
}

func IncomingWins(existingMs, incomingMs int64) bool {
	d := existingMs - incomingMs
	if d < 0 {
		d = -d
	}
	if d < 5000 {
		return false
	}
	return incomingMs > existingMs
}
