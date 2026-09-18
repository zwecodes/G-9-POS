package main

import (
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	embeddedpostgres "github.com/fergusstrange/embedded-postgres"
)

func main() {
	root, err := os.UserConfigDir()
	if err != nil {
		panic(err)
	}
	dir := filepath.Join(root, "g9pos", "devpg")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		panic(err)
	}
	pg := embeddedpostgres.NewDatabase(embeddedpostgres.DefaultConfig().
		Username("g9pos").
		Password("g9pos").
		Database("g9pos").
		Port(5432).
		RuntimePath(filepath.Join(dir, "runtime")).
		DataPath(filepath.Join(dir, "data")))
	if err := pg.Start(); err != nil {
		panic(err)
	}
	fmt.Println("g9pos postgres listening on 5432")
	fmt.Println("data", filepath.Join(dir, "data"))
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, os.Interrupt, syscall.SIGTERM)
	<-ch
	_ = pg.Stop()
}
