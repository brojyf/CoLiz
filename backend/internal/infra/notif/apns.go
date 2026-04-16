package notif

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type apnsAlert struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type apnsAPS struct {
	Alert apnsAlert `json:"alert"`
	Sound string    `json:"sound,omitempty"`
}

// APNSClient sends push notifications via Apple's HTTP/2 APNs API (token-based auth).
// Uses only stdlib + the jwt library already in go.mod — no new dependencies.
type APNSClient struct {
	httpClient *http.Client
	teamID     string
	keyID      string
	key        *ecdsa.PrivateKey
	bundleID   string
	host       string

	mu       sync.Mutex
	token    string
	tokenExp time.Time
}

func NewAPNSClientFromPEM(keyPEM, keyID, teamID, bundleID string, sandbox bool) (*APNSClient, error) {
	return newAPNSClient(keyPEM, keyID, teamID, bundleID, sandbox)
}

func newAPNSClient(keyPEM, keyID, teamID, bundleID string, sandbox bool) (*APNSClient, error) {
	key, err := parseECKey(keyPEM)
	if err != nil {
		return nil, fmt.Errorf("apns: parse key: %w", err)
	}
	host := "https://api.push.apple.com"
	if sandbox {
		host = "https://api.sandbox.push.apple.com"
	}
	return &APNSClient{
		httpClient: &http.Client{Timeout: 10 * time.Second},
		teamID:     teamID,
		keyID:      keyID,
		key:        key,
		bundleID:   bundleID,
		host:       host,
	}, nil
}

func parseECKey(keyPEM string) (*ecdsa.PrivateKey, error) {
	block, _ := pem.Decode([]byte(keyPEM))
	if block == nil {
		return nil, fmt.Errorf("failed to decode PEM block")
	}
	// Apple p8 keys are PKCS8; fallback to SEC1 for older keys
	if pk8, err := x509.ParsePKCS8PrivateKey(block.Bytes); err == nil {
		if ec, ok := pk8.(*ecdsa.PrivateKey); ok {
			return ec, nil
		}
		return nil, fmt.Errorf("key is not EC")
	}
	return x509.ParseECPrivateKey(block.Bytes)
}

func (c *APNSClient) bearerToken() (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if time.Now().Before(c.tokenExp) {
		return c.token, nil
	}

	now := time.Now()
	t := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.MapClaims{
		"iss": c.teamID,
		"iat": now.Unix(),
	})
	t.Header["kid"] = c.keyID

	signed, err := t.SignedString(c.key)
	if err != nil {
		return "", err
	}
	c.token = signed
	c.tokenExp = now.Add(45 * time.Minute)
	return c.token, nil
}

// Send delivers a push notification to a single device token.
// extra is merged into the root of the JSON payload (e.g. "group_id").
func (c *APNSClient) Send(ctx context.Context, deviceToken, title, body, pushType string, extra map[string]string) error {
	token, err := c.bearerToken()
	if err != nil {
		return fmt.Errorf("apns: bearer token: %w", err)
	}

	payload := map[string]any{
		"aps":  apnsAPS{Alert: apnsAlert{Title: title, Body: body}, Sound: "default"},
		"type": pushType,
	}
	for k, v := range extra {
		payload[k] = v
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		fmt.Sprintf("%s/3/device/%s", c.host, deviceToken),
		bytes.NewReader(data),
	)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("apns-topic", c.bundleID)
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("apns: http: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		var body struct {
			Reason string `json:"reason"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&body)
		return fmt.Errorf("apns: status %d reason=%q device=%s", resp.StatusCode, body.Reason, deviceToken)
	}
	return nil
}
