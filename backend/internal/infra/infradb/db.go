package infradb

import (
	"context"
	"database/sql"

	"github.com/brojyf/CoLiz/internal/config"
	_ "github.com/go-sql-driver/mysql"
)

func NewDB(cfg config.MySQL) (*sql.DB, error) {
	db, err := sql.Open("mysql", cfg.DSN)
	if err != nil {
		return nil, err
	}

	db.SetMaxOpenConns(cfg.MaxOpenConnections)
	db.SetMaxIdleConns(cfg.MaxIdleConnections)
	db.SetConnMaxLifetime(cfg.ConnectionMaxLifetime)
	db.SetConnMaxIdleTime(cfg.ConnectionMaxIdleTime)

	ctx, cancel := context.WithTimeout(context.Background(), cfg.PingTimeout)
	defer cancel()

	if err = db.PingContext(ctx); err != nil {
		return nil, err
	}

	return db, nil
}
