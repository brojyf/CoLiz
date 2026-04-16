package app

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"path/filepath"
	"time"

	"github.com/brojyf/CoLiz/internal/config"
	"github.com/brojyf/CoLiz/internal/http"
	"github.com/brojyf/CoLiz/internal/http/handler"
	authh "github.com/brojyf/CoLiz/internal/http/handler/auth"
	expenseh "github.com/brojyf/CoLiz/internal/http/handler/expense"
	friendh "github.com/brojyf/CoLiz/internal/http/handler/friend"
	grouph "github.com/brojyf/CoLiz/internal/http/handler/group"
	todoh "github.com/brojyf/CoLiz/internal/http/handler/todo"
	userh "github.com/brojyf/CoLiz/internal/http/handler/user"
	"github.com/brojyf/CoLiz/internal/http/middleware"
	"github.com/brojyf/CoLiz/internal/infra/infradb"
	"github.com/brojyf/CoLiz/internal/infra/infrardb"
	"github.com/brojyf/CoLiz/internal/infra/notif"
	txinfra "github.com/brojyf/CoLiz/internal/infra/tx"
	"github.com/brojyf/CoLiz/internal/policy/ratelimit"
	authrepo "github.com/brojyf/CoLiz/internal/repo/auth"
	avatarrepo "github.com/brojyf/CoLiz/internal/repo/avatar"
	devicerepo "github.com/brojyf/CoLiz/internal/repo/device"
	expenserepo "github.com/brojyf/CoLiz/internal/repo/expense"
	friendrepo "github.com/brojyf/CoLiz/internal/repo/friend"
	grouprepo "github.com/brojyf/CoLiz/internal/repo/group"
	todorepo "github.com/brojyf/CoLiz/internal/repo/todo"
	userrepo "github.com/brojyf/CoLiz/internal/repo/user"
	authsvc "github.com/brojyf/CoLiz/internal/service/auth"
	expensesvc "github.com/brojyf/CoLiz/internal/service/expense"
	friendsvc "github.com/brojyf/CoLiz/internal/service/friend"
	groupsvc "github.com/brojyf/CoLiz/internal/service/group"
	todosvc "github.com/brojyf/CoLiz/internal/service/todo"
	usersvc "github.com/brojyf/CoLiz/internal/service/user"
	"github.com/brojyf/CoLiz/internal/util/jwtx"
	"github.com/redis/go-redis/v9"
)

type App struct {
	cfg     config.Config
	jwtUtil jwtx.JWTX
	authSvc authsvc.Service
	db      *sql.DB
	tx      *txinfra.Transactor
	rdb     *redis.Client
	server  *http.Server
}

func NewApp(cfg config.Config) (*App, error) {
	a := &App{cfg: cfg}

	err := a.initStores()
	if err != nil {
		return nil, err
	}

	a.initUtils()

	// init handlers
	authR, authH := a.initAuth()
	n := a.initNotifier()
	expenseH := a.initExpense(n)
	friendH := a.initFriend(n)
	userH := a.initUser()
	groupH := a.initGroup(n)
	todoH := a.initTodo(n)

	h := &handler.Handlers{
		Auth:    authH,
		Expense: expenseH,
		User:    userH,
		Friend:  friendH,
		Group:   groupH,
		Todo:    todoH,
	}

	// init middlewares
	middlewares := middleware.Middlewares{
		Timeout:  middleware.NewTimeout(a.cfg.HTTP.Timeout),
		ATK:      middleware.NewAccessToken(authR, a.jwtUtil),
		Throttle: middleware.NewThrottle(authR, ratelimit.New(a.cfg.HTTP.ThrottleRL, a.cfg.HTTP.ThrottleTTL), a.cfg.HTTP.ThrottleTimeout),
	}

	// init server
	a.server = http.NewServer(a.cfg.HTTP, &middlewares, h)

	return a, nil
}

// Exported methods
func (a *App) Start() error {
	return a.server.Start()
}
func (a *App) Close(ctx context.Context) error {
	var errs []error

	if a.server != nil {
		errs = append(errs, a.server.Shutdown(ctx))
	}
	if a.rdb != nil {
		errs = append(errs, a.rdb.Close())
	}
	if a.db != nil {
		errs = append(errs, a.db.Close())
	}

	return errors.Join(errs...)
}

// private helpers
func (a *App) initStores() error {
	db, err := infradb.NewDB(a.cfg.MySQL)
	if err != nil {
		return err
	}

	rdb, err := infrardb.NewRedis(a.cfg.Redis)
	if err != nil {
		return err
	}

	a.db = db
	a.rdb = rdb
	return nil
}
func (a *App) initUtils() {
	a.tx = txinfra.NewTransactor(a.db)
	a.jwtUtil = jwtx.NewJWTX(&jwtx.Config{
		ISS:           a.cfg.JWT.ISS,
		ATKExpiresIn:  a.cfg.JWT.ATKExpiresIn,
		CurKeyVersion: a.cfg.JWT.CurKeyVersion,
		Keys:          a.cfg.JWT.Keys,
	})
}
func (a *App) WatchRotation(ctx context.Context, path string, interval time.Duration) {
	config.NewRotationWatcher(path, interval, a.jwtUtil, a.authSvc).Start(ctx)
}

func (a *App) initAuth() (authrepo.Repo, *authh.Handler) {
	authRepo := authrepo.NewRepo(a.db, a.rdb)
	c := authsvc.Config{
		Token: authsvc.TokenConfig{
			TokenType:        a.cfg.Auth.TokenType,
			ExpiresIn:        a.cfg.JWT.ATKExpiresIn,
			RTKPepperVersion: a.cfg.Auth.RTKPepperVersion,
			RTKPepperMap:     a.cfg.Auth.RTKPepperMap,
			RTKTTL:           a.cfg.Auth.RTKTTL,
		},
		RequestOTP: authsvc.RequestOTPConfig{
			OTPTTL:   a.cfg.Auth.OTPTTL,
			RL:       ratelimit.New(a.cfg.Auth.OTPRL, a.cfg.Auth.OTPThTTL),
			QueueKey: a.cfg.Queue.OTPEmailKey,
		},
		VerifyOTP: authsvc.VerifyOTPConfig{
			ShortRL:   ratelimit.New(a.cfg.Auth.VerifyShortRL, a.cfg.Auth.VerifyShortTTL),
			DailyRL:   a.cfg.Auth.VerifyDailyRL,
			TicketTTL: a.cfg.Auth.TicketTTL,
		},
		Register: ratelimit.New(a.cfg.Auth.DIDRL, a.cfg.Auth.DIDThTTL),
		Refresh:  ratelimit.New(a.cfg.Auth.RTKRL, a.cfg.Auth.RTKThTTL),
		Login:    ratelimit.New(a.cfg.Auth.LoginEmailRL, a.cfg.Auth.LoginEmailThTTL),
	}
	authSvc := authsvc.NewService(authRepo, c, a.tx, a.jwtUtil)
	a.authSvc = authSvc
	return authRepo, authh.NewHandler(authSvc)
}

func (a *App) initNotifier() *notif.Notifier {
	cfg := a.cfg.APNS
	if cfg.KeyPEM == "" || cfg.KeyID == "" || cfg.TeamID == "" || cfg.BundleID == "" {
		return notif.NewNoopNotifier()
	}
	apnsClient, err := notif.NewAPNSClientFromPEM(cfg.KeyPEM, cfg.KeyID, cfg.TeamID, cfg.BundleID, cfg.Sandbox)
	if err != nil {
		// Log but don't fail startup — push notifications are non-critical
		fmt.Printf("apns: init failed (notifications disabled): %v\n", err)
		return notif.NewNoopNotifier()
	}
	deviceRepo := devicerepo.NewRepo(a.db)
	return notif.NewNotifier(apnsClient, deviceRepo, a.db)
}
func (a *App) initUser() *userh.Handler {
	userRepo := userrepo.NewRepo(a.db)
	avatarRepo := avatarrepo.NewLocalRepo(a.cfg.Avatar.Root)
	userCfg := usersvc.Config{
		AvatarCacheMaxAge: a.cfg.Avatar.CacheMaxAge,
		DefaultAvatarPath: a.cfg.Avatar.DefaultPath,
	}
	deviceRepo := devicerepo.NewRepo(a.db)
	return userh.NewHandler(usersvc.NewService(userCfg, userRepo, avatarRepo), deviceRepo)
}
func (a *App) initFriend(n *notif.Notifier) *friendh.Handler {
	friendRepo := friendrepo.NewRepo(a.db)
	friendSvc := friendsvc.NewService(friendsvc.Config{
		RequestTTL: a.cfg.Friend.RequestTTL,
	}, friendRepo, a.tx)

	return friendh.NewHandler(friendSvc, n)
}
func (a *App) initExpense(n *notif.Notifier) *expenseh.Handler {
	expenseRepo := expenserepo.NewRepo(a.db)
	return expenseh.NewHandler(expensesvc.NewService(expenseRepo, a.tx), n)
}
func (a *App) initGroup(n *notif.Notifier) *grouph.Handler {
	groupRepo := grouprepo.NewRepo(a.db)
	groupAvatarRepo := avatarrepo.NewLocalRepo(filepath.Join(a.cfg.Avatar.Root, "groups"))
	groupCfg := groupsvc.Config{
		AvatarCacheMaxAge: a.cfg.Avatar.CacheMaxAge,
		DefaultAvatarPath: a.cfg.Avatar.DefaultPath,
	}
	return grouph.NewHandler(groupsvc.NewService(groupCfg, groupRepo, a.tx, groupAvatarRepo), n)
}
func (a *App) initTodo(n *notif.Notifier) *todoh.Handler {
	todoRepo := todorepo.NewRepo(a.db)
	return todoh.NewHandler(todosvc.NewService(todoRepo, a.tx), n)
}
