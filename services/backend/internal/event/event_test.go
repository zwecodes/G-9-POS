package event

import "testing"

func TestIncomingWins(t *testing.T) {
	if IncomingWins(1_000, 1_002) {
		t.Fatal("within 5s the existing version must win")
	}
	if !IncomingWins(1_000, 10_000) {
		t.Fatal("later created_at outside the 5s window must win")
	}
	if IncomingWins(10_000, 1_000) {
		t.Fatal("earlier incoming must lose")
	}
}
