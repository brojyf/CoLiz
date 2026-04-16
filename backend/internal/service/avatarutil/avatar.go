package avatarutil

import (
	"bytes"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	"image/png"
	"io"

	"github.com/brojyf/CoLiz/internal/policy/avpol"
	svc "github.com/brojyf/CoLiz/internal/service"
)

func NormalizePNG(src io.Reader, sidePixels int) ([]byte, error) {
	if !withinTargetBounds(sidePixels) {
		return nil, svc.ErrInvalidInput
	}

	data, err := io.ReadAll(src)
	if err != nil {
		return nil, svc.ErrInvalidInput
	}

	cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return nil, svc.ErrInvalidInput
	}
	if !withinSourceBounds(cfg.Width, cfg.Height) {
		return nil, svc.ErrInvalidInput
	}

	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, svc.ErrInvalidInput
	}

	cropped := centerCropSquare(img)
	resized := resizeNearest(cropped, sidePixels, sidePixels)

	var buf bytes.Buffer
	if err := png.Encode(&buf, resized); err != nil {
		return nil, svc.ErrInternal
	}

	return buf.Bytes(), nil
}

// Helper function
func withinSourceBounds(width, height int) bool {
	if width <= 0 || height <= 0 {
		return false
	}
	if width > avpol.MaxSize || height > avpol.MaxSize {
		return false
	}

	return int64(width)*int64(height) <= avpol.MaxPixels
}

func withinTargetBounds(sidePixels int) bool {
	if sidePixels <= 0 || sidePixels > avpol.MaxSize {
		return false
	}

	return int64(sidePixels)*int64(sidePixels) <= avpol.MaxPixels
}

func centerCropSquare(src image.Image) image.Image {
	b := src.Bounds()
	width := b.Dx()
	height := b.Dy()
	side := width
	if height < side {
		side = height
	}

	startX := b.Min.X + (width-side)/2
	startY := b.Min.Y + (height-side)/2
	dst := image.NewNRGBA(image.Rect(0, 0, side, side))

	for y := 0; y < side; y++ {
		for x := 0; x < side; x++ {
			dst.Set(x, y, src.At(startX+x, startY+y))
		}
	}

	return dst
}

func resizeNearest(src image.Image, width, height int) *image.NRGBA {
	dst := image.NewNRGBA(image.Rect(0, 0, width, height))
	sb := src.Bounds()
	srcWidth := sb.Dx()
	srcHeight := sb.Dy()

	if srcWidth == 0 || srcHeight == 0 {
		return dst
	}

	for y := 0; y < height; y++ {
		srcY := sb.Min.Y + y*srcHeight/height
		for x := 0; x < width; x++ {
			srcX := sb.Min.X + x*srcWidth/width
			dst.Set(x, y, src.At(srcX, srcY))
		}
	}

	return dst
}
