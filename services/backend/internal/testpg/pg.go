package testpg

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"sync"
	"testing"

	embeddedpostgres "github.com/fergusstrange/embedded-postgres"
	"github.com/jmoiron/sqlx"

	"github.com/zwecodes/g9pos/backend/pkg/db"
)

var (
	startOnce sync.Once
	startErr  error
	testDB    *sqlx.DB
	postgres  *embeddedpostgres.EmbeddedPostgres
)

func Open(t *testing.T) *sqlx.DB {
	t.Helper()
	startOnce.Do(func() {
		if u := os.Getenv("TEST_DATABASE_URL"); u != "" {
			testDB, startErr = db.Connect(u)
			if startErr != nil {
				return
			}
			startErr = db.Migrate(u)
			return
		}

		port, err := freePort()
		if err != nil {
			startErr = err
			return
		}
		runtimeDir, err := os.MkdirTemp("", "g9pos-pg-")
		if err != nil {
			startErr = err
			return
		}
		postgres = embeddedpostgres.NewDatabase(embeddedpostgres.DefaultConfig().
			Username("g9pos").
			Password("g9pos").
			Database("g9pos").
			Port(uint32(port)).
			RuntimePath(filepath.Join(runtimeDir, "runtime")).
			DataPath(filepath.Join(runtimeDir, "data")))
		if err := postgres.Start(); err != nil {
			startErr = fmt.Errorf("embedded postgres: %w", err)
			return
		}
		url := fmt.Sprintf("postgres://g9pos:g9pos@127.0.0.1:%d/g9pos?sslmode=disable", port)
		testDB, startErr = db.Connect(url)
		if startErr != nil {
			_ = postgres.Stop()
			return
		}
		if err := db.Migrate(url); err != nil {
			startErr = err
			_ = testDB.Close()
			_ = postgres.Stop()
			return
		}
	})
	if startErr != nil {
		t.Fatalf("postgres test db: %v", startErr)
	}
	Reset(t)
	return testDB
}

func Reset(t *testing.T) {
	t.Helper()
	_, err := testDB.Exec(`
		TRUNCATE TABLE
			supplier_order_items,
			supplier_orders,
			sale_items,
			sales,
			inventory_events,
			products,
			categories,
			expenses,
			suppliers,
			devices,
			users
		RESTART IDENTITY CASCADE`)
	if err != nil {
		t.Fatalf("truncate: %v", err)
	}
}

func freePort() (int, error) {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port, nil
}
