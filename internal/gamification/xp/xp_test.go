package xp

import "testing"

func TestDeltaXPFromVolume(t *testing.T) {
	if n := DeltaXPFromVolume(0); n != 10 {
		t.Fatalf("zero volume: got %d want 10", n)
	}
	if n := DeltaXPFromVolume(100); n != 12 {
		t.Fatalf("100kg: got %d want 12", n)
	}
	if n := DeltaXPFromVolume(25); n != 1+10 {
		t.Fatalf("25kg: got %d want 11", n)
	}
}
