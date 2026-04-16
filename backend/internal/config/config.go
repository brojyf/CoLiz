package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type MySQL struct {
	DSN                   string
	MaxOpenConnections    int
	MaxIdleConnections    int
	ConnectionMaxLifetime time.Duration
	ConnectionMaxIdleTime time.Duration
	PingTimeout           time.Duration
}

type Redis struct {
	Address      string
	Password     string
	DB           int
	DialTimeout  time.Duration
	ReadTimeout  time.Duration
	WriteTimeout time.Duration
	PingTimeout  time.Duration
}

type HTTP struct {
	Address         string
	Timeout         time.Duration
	ThrottleTimeout time.Duration
	ThrottleRL      int
	ThrottleTTL     time.Duration
}
type JWT struct {
	ISS           string
	ATKExpiresIn  int64
	CurKeyVersion string
	Keys          map[string][]byte
}

type Auth struct {
	// Request code
	OTPRL    int
	OTPTTL   time.Duration
	OTPThTTL time.Duration
	// Verify code
	VerifyShortRL  int
	VerifyDailyRL  int
	VerifyShortTTL time.Duration
	TicketTTL      time.Duration
	// Session tokens
	TokenType        string
	RTKPepperVersion string
	RTKPepperMap     map[string][]byte
	RTKTTL           time.Duration
	// Create account
	DIDRL    int
	DIDThTTL time.Duration
	// Login
	LoginEmailRL    int
	LoginEmailThTTL time.Duration
	// Refresh
	RTKRL    int
	RTKThTTL time.Duration
}

type Friend struct {
	RequestTTL time.Duration
}

type Avatar struct {
	Root        string
	DefaultPath string
	CacheMaxAge time.Duration
}

type Queue struct {
	OTPEmailKey       string
	WorkerPollTimeout time.Duration
	WorkerRetryDelay  time.Duration
	WorkerMaxRetry    int
}

type Mail struct {
	From         string
	ResendAPIKey string
}

type APNS struct {
	KeyPEM   string
	KeyID    string
	TeamID   string
	BundleID string
	Sandbox  bool
}

type Config struct {
	MySQL  MySQL
	Redis  Redis
	HTTP   HTTP
	JWT    JWT
	Queue  Queue
	Mail   Mail
	Auth   Auth
	Friend Friend
	Avatar Avatar
	APNS   APNS
}

func InitConfig() (Config, error) {
	var err error

	envString := func(key string) string {
		if err != nil {
			return ""
		}

		var v string
		v, err = readEnvString(key)
		return v
	}
	envInt := func(key string) int {
		if err != nil {
			return 0
		}

		var v int
		v, err = readEnvInt(key)
		return v
	}
	envInt64 := func(key string) int64 {
		if err != nil {
			return 0
		}

		var v int64
		v, err = readEnvInt64(key)
		return v
	}
	envDuration := func(key string) time.Duration {
		if err != nil {
			return 0
		}

		var v time.Duration
		v, err = readEnvDuration(key)
		return v
	}
	envStringDefault := func(key, fallback string) string {
		if err != nil {
			return ""
		}

		var v string
		v, err = readEnvStringDefault(key, fallback)
		return v
	}
	envDurationDefault := func(key string, fallback time.Duration) time.Duration {
		if err != nil {
			return 0
		}

		var v time.Duration
		v, err = readEnvDurationDefault(key, fallback)
		return v
	}

	jwtCurKeyVersion := envString("JWT_CUR_KEY_VERSION")
	jwtKey := envString("JWT_KEY")
	authRTKPepperVersion := envString("AUTH_RTK_PEPPER_VERSION")
	authRTKPepper := envString("AUTH_RTK_PEPPER")

	jwtKeys := parseVersionedSecrets(
		jwtCurKeyVersion,
		jwtKey,
		envStringDefault("JWT_KEYS", ""),
	)
	authRTKPepperMap := parseVersionedSecrets(
		authRTKPepperVersion,
		authRTKPepper,
		envStringDefault("AUTH_RTK_PEPPERS", ""),
	)

	cfg := Config{
		MySQL: MySQL{
			DSN:                   envString("MYSQL_DSN"),
			MaxOpenConnections:    envInt("MYSQL_MAX_OPEN_CONNECTIONS"),
			MaxIdleConnections:    envInt("MYSQL_MAX_IDLE_CONNECTIONS"),
			ConnectionMaxLifetime: envDuration("MYSQL_CONNECTION_MAX_LIFETIME"),
			ConnectionMaxIdleTime: envDuration("MYSQL_CONNECTION_MAX_IDLE_TIME"),
			PingTimeout:           envDuration("MYSQL_PING_TIMEOUT"),
		},
		Redis: Redis{
			Address:      envString("REDIS_ADDRESS"),
			Password:     envStringDefault("REDIS_PASSWORD", ""),
			DB:           envInt("REDIS_DB"),
			DialTimeout:  envDuration("REDIS_DIAL_TIMEOUT"),
			ReadTimeout:  envDuration("REDIS_READ_TIMEOUT"),
			WriteTimeout: envDuration("REDIS_WRITE_TIMEOUT"),
			PingTimeout:  envDuration("REDIS_PING_TIMEOUT"),
		},
		HTTP: HTTP{
			Address:         envString("HTTP_ADDRESS"),
			Timeout:         envDuration("HTTP_TIMEOUT"),
			ThrottleTimeout: envDuration("HTTP_THROTTLE_TIMEOUT"),
			ThrottleRL:      envInt("HTTP_THROTTLE_RL"),
			ThrottleTTL:     envDuration("HTTP_THROTTLE_TTL"),
		},
		JWT: JWT{
			ISS:           envString("JWT_ISS"),
			ATKExpiresIn:  envInt64("JWT_ATK_EXPIRES_IN"),
			CurKeyVersion: jwtCurKeyVersion,
			Keys:          jwtKeys,
		},
		Auth: Auth{
			// Request code
			OTPRL:    envInt("AUTH_OTP_RL"),
			OTPTTL:   envDuration("AUTH_OTP_TTL"),
			OTPThTTL: envDuration("AUTH_OTP_TH_TTL"),
			// Verify code
			VerifyShortRL:  envInt("AUTH_VERIFY_SHORT_RL"),
			VerifyDailyRL:  envInt("AUTH_VERIFY_DAILY_RL"),
			VerifyShortTTL: envDuration("AUTH_VERIFY_SHORT_TTL"),
			TicketTTL:      envDuration("AUTH_TICKET_TTL"),
			// Auth tokens
			TokenType:        envString("AUTH_TOKEN_TYPE"),
			RTKPepperVersion: authRTKPepperVersion,
			RTKPepperMap:     authRTKPepperMap,
			RTKTTL:           envDuration("AUTH_RTK_TTL"),
			// Create account
			DIDRL:    envInt("AUTH_DID_RL"),
			DIDThTTL: envDuration("AUTH_DID_TH_TTL"),
			// Login
			LoginEmailRL:    envInt("AUTH_LOGIN_EMAIL_RL"),
			LoginEmailThTTL: envDuration("AUTH_LOGIN_EMAIL_TH_TTL"),
			// Refresh
			RTKRL:    envInt("AUTH_RTK_RL"),
			RTKThTTL: envDuration("AUTH_RTK_TH_TTL"),
		},
		Friend: Friend{
			RequestTTL: envDuration("FRIEND_REQUEST_TTL"),
		},
		Avatar: Avatar{
			Root:        envStringDefault("AVATAR_ROOT", "./storage/avatars"),
			DefaultPath: envStringDefault("AVATAR_DEFAULT_PATH", "./storage/avatars/default.svg"),
			CacheMaxAge: envDurationDefault("AVATAR_CACHE_MAX_AGE", 24*time.Hour),
		},
		Queue: Queue{
			OTPEmailKey:       envString("QUEUE_OTP_EMAIL_KEY"),
			WorkerPollTimeout: envDuration("QUEUE_WORKER_POLL_TIMEOUT"),
			WorkerRetryDelay:  envDuration("QUEUE_WORKER_RETRY_DELAY"),
			WorkerMaxRetry:    envInt("QUEUE_WORKER_MAX_RETRY"),
		},
		Mail: Mail{
			From:         envString("RESEND_FROM"),
			ResendAPIKey: envString("RESEND_API_KEY"),
		},
		APNS: APNS{
			KeyPEM:   normalizePEMEnv(envStringDefault("APNS_KEY_PEM", "")),
			KeyID:    envStringDefault("APNS_KEY_ID", ""),
			TeamID:   envStringDefault("APNS_TEAM_ID", ""),
			BundleID: envStringDefault("APNS_BUNDLE_ID", ""),
			Sandbox:  envStringDefault("APNS_SANDBOX", "true") == "true",
		},
	}

	if err != nil {
		return Config{}, err
	}

	return cfg, nil
}

func readEnvString(key string) (string, error) {
	v, ok := os.LookupEnv(key)
	if !ok {
		return "", fmt.Errorf("missing env %s", key)
	}
	return v, nil
}

func normalizePEMEnv(v string) string {
	v = strings.TrimSpace(v)
	if v == "" {
		return ""
	}
	return strings.ReplaceAll(v, `\n`, "\n")
}

func readEnvStringDefault(key, fallback string) (string, error) {
	v, ok := os.LookupEnv(key)
	if !ok || v == "" {
		return fallback, nil
	}
	return v, nil
}

func readEnvInt(key string) (int, error) {
	raw, err := readEnvString(key)
	if err != nil {
		return 0, err
	}
	v, err := strconv.Atoi(raw)
	if err != nil {
		return 0, fmt.Errorf("parse env %s as int: %w", key, err)
	}
	return v, nil
}

func readEnvInt64(key string) (int64, error) {
	raw, err := readEnvString(key)
	if err != nil {
		return 0, err
	}
	v, err := strconv.ParseInt(raw, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("parse env %s as int64: %w", key, err)
	}
	return v, nil
}

func readEnvDuration(key string) (time.Duration, error) {
	raw, err := readEnvString(key)
	if err != nil {
		return 0, err
	}
	v, err := time.ParseDuration(raw)
	if err != nil {
		return 0, fmt.Errorf("parse env %s as duration: %w", key, err)
	}
	return v, nil
}

func readEnvDurationDefault(key string, fallback time.Duration) (time.Duration, error) {
	raw, ok := os.LookupEnv(key)
	if !ok || raw == "" {
		return fallback, nil
	}
	v, err := time.ParseDuration(raw)
	if err != nil {
		return 0, fmt.Errorf("parse env %s as duration: %w", key, err)
	}
	return v, nil
}

func parseVersionedSecrets(currentVersion, currentValue, raw string) map[string][]byte {
	m := make(map[string][]byte)

	for _, pair := range strings.Split(raw, ",") {
		pair = strings.TrimSpace(pair)
		if pair == "" {
			continue
		}

		parts := strings.SplitN(pair, ":", 2)
		if len(parts) != 2 {
			continue
		}

		version := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		if version == "" || value == "" {
			continue
		}

		m[version] = []byte(value)
	}

	if currentVersion != "" && currentValue != "" {
		m[currentVersion] = []byte(currentValue)
	}

	return m
}
