package tool

import "testing"

func TestNormLowercasesStringFields(t *testing.T) {
	t.Parallel()

	req := struct {
		Email    string
		Scene    string
		Password string
	}{
		Email:    "  User@Example.COM  ",
		Scene:    " SignUp ",
		Password: " KeepMeMixed ",
	}

	Norm(&req, "Password")

	if req.Email != "user@example.com" {
		t.Fatalf("expected normalized email, got %q", req.Email)
	}
	if req.Scene != "signup" {
		t.Fatalf("expected normalized scene, got %q", req.Scene)
	}
	if req.Password != " KeepMeMixed " {
		t.Fatalf("expected skipped field to stay unchanged, got %q", req.Password)
	}
}
