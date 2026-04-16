package config

import "testing"

func TestNormalizePEMEnv(t *testing.T) {
	input := "-----BEGIN PRIVATE KEY-----\\nline1\\nline2\\n-----END PRIVATE KEY-----"

	got := normalizePEMEnv(input)

	want := "-----BEGIN PRIVATE KEY-----\nline1\nline2\n-----END PRIVATE KEY-----"
	if got != want {
		t.Fatalf("normalizePEMEnv() mismatch:\nwant: %q\ngot:  %q", want, got)
	}
}
