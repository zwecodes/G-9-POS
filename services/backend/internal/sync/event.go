package sync

import "github.com/zwecodes/g9pos/backend/internal/event"

type Event = event.Event
type PermanentError = event.PermanentError
type ConflictError = event.ConflictError

var (
	Reject       = event.Reject
	Unmarshal    = event.Unmarshal
	IncomingWins = event.IncomingWins
)
