package avatarutil

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"testing"

	"github.com/brojyf/CoLiz/internal/policy/avpol"
)

func TestNormalizePNGRejectsOversizedDimensions(t *testing.T) {
	t.Parallel()

	src := image.NewNRGBA(image.Rect(0, 0, avpol.MaxSize+1, 1))
	var buf bytes.Buffer
	if err := png.Encode(&buf, src); err != nil {
		t.Fatalf("encode source png: %v", err)
	}

	if _, err := NormalizePNG(bytes.NewReader(buf.Bytes()), 512); err == nil {
		t.Fatal("expected oversized image to be rejected")
	}
}

func TestNormalizePNGRejectsOversizedTarget(t *testing.T) {
	t.Parallel()

	src := image.NewNRGBA(image.Rect(0, 0, 64, 64))
	var buf bytes.Buffer
	if err := png.Encode(&buf, src); err != nil {
		t.Fatalf("encode source png: %v", err)
	}

	if _, err := NormalizePNG(bytes.NewReader(buf.Bytes()), avpol.MaxPixels); err == nil {
		t.Fatal("expected oversized target to be rejected")
	}
}

func TestNormalizePNGProducesSquarePNG(t *testing.T) {
	t.Parallel()

	src := image.NewNRGBA(image.Rect(0, 0, 640, 320))
	src.Set(0, 0, color.NRGBA{R: 255, A: 255})

	var buf bytes.Buffer
	if err := png.Encode(&buf, src); err != nil {
		t.Fatalf("encode source png: %v", err)
	}

	data, err := NormalizePNG(bytes.NewReader(buf.Bytes()), 512)
	if err != nil {
		t.Fatalf("normalize png: %v", err)
	}

	out, err := png.Decode(bytes.NewReader(data))
	if err != nil {
		t.Fatalf("decode normalized png: %v", err)
	}
	if out.Bounds().Dx() != 512 || out.Bounds().Dy() != 512 {
		t.Fatalf("expected 512x512 output, got %dx%d", out.Bounds().Dx(), out.Bounds().Dy())
	}
}
