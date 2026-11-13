// demo-app is a tiny HTTP service used throughout the KCNA labs.
package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

// version is set at build time with -ldflags "-X main.version=...".
var version = "dev"

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	port := getenv("PORT", "8080")
	message := getenv("MESSAGE", "Hello from demo-app")
	hostname, _ := os.Hostname()

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"message":  message,
			"version":  version,
			"hostname": hostname,
			"uid":      os.Getuid(),
			"time":     time.Now().UTC().Format(time.RFC3339),
		})
	})
	ok := func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte("ok\n")) }
	mux.HandleFunc("/healthz", ok)
	mux.HandleFunc("/readyz", ok)

	srv := &http.Server{Addr: ":" + port, Handler: mux, ReadHeaderTimeout: 5 * time.Second}

	// Kubernetes sends SIGTERM when it stops a container, then SIGKILL after the grace period.
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
	defer stop()

	go func() {
		log.Printf("demo-app %s listening on :%s as uid %d", version, port, os.Getuid())
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()

	<-ctx.Done()
	log.Print("SIGTERM received, shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
}
