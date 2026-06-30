package main

import (
    "context"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "time"
)

type ServerConfig struct {
    Address string        `json:"address"`
    Timeout time.Duration `json:"timeout"`
    Debug   bool          `json:"debug"`
}

type HealthResponse struct {
    Status    string    `json:"status"`
    Version   string    `json:"version"`
    Timestamp time.Time `json:"timestamp"`
}

func main() {
    cfg := ServerConfig{
        Address: ":8080",
        Timeout: 5 * time.Second,
        Debug:   true,
    }

    mux := http.NewServeMux()
    mux.HandleFunc("/health", healthHandler("1.4.2"))
    mux.HandleFunc("/config", configHandler(cfg))

    srv := &http.Server{
        Addr:              cfg.Address,
        Handler:           logging(mux),
        ReadHeaderTimeout: cfg.Timeout,
    }

    log.Printf("starting sample server on %s", cfg.Address)
    if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
        log.Fatal(err)
    }
}

func healthHandler(version string) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        respondJSON(w, HealthResponse{
            Status:    "ok",
            Version:   version,
            Timestamp: time.Now().UTC(),
        })
    }
}

func configHandler(cfg ServerConfig) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        ctx, cancel := context.WithTimeout(r.Context(), cfg.Timeout)
        defer cancel()
        select {
        case <-ctx.Done():
            http.Error(w, ctx.Err().Error(), http.StatusGatewayTimeout)
        default:
            respondJSON(w, cfg)
        }
    }
}

func logging(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        started := time.Now()
        next.ServeHTTP(w, r)
        fmt.Printf("%s %s took=%s\n", r.Method, r.URL.Path, time.Since(started))
    })
}

func respondJSON(w http.ResponseWriter, value any) {
    w.Header().Set("Content-Type", "application/json")
    _ = json.NewEncoder(w).Encode(value)
}
