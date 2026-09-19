// Command setupowner calls POST /v1/setup once before public exposure
// (API-SPEC.md §2.5 / REQUIREMENTS.md §5.1).
//
// Usage:
//
//	API_URL=http://localhost:8080 \
//	OWNER_USERNAME=owner \
//	OWNER_PASSWORD='...' \
//	OWNER_NAME='Shop Owner' \
//	OWNER_PIN=1234 \
//	go run ./cmd/setupowner
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

func main() {
	apiURL := strings.TrimRight(envOr("API_URL", "http://localhost:8080"), "/")
	username := requireEnv("OWNER_USERNAME")
	password := requireEnv("OWNER_PASSWORD")
	name := requireEnv("OWNER_NAME")
	pin := requireEnv("OWNER_PIN")

	body, err := json.Marshal(map[string]string{
		"username": username,
		"password": password,
		"name":     name,
		"pin":      pin,
	})
	if err != nil {
		fail("encode request: %v", err)
	}

	req, err := http.NewRequest(http.MethodPost, apiURL+"/v1/setup", bytes.NewReader(body))
	if err != nil {
		fail("build request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		fail("request failed: %v", err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)

	switch resp.StatusCode {
	case http.StatusOK:
		fmt.Println("Owner account created. Sign in with that username and password — no JWT was issued by setup.")
		fmt.Println(string(raw))
	case http.StatusConflict:
		fail("setup already complete (HTTP 409). Do not re-run this against a live shop DB.")
	default:
		fail("setup failed HTTP %d: %s", resp.StatusCode, string(raw))
	}
}

func requireEnv(key string) string {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		fail("%s is required", key)
	}
	return v
}

func envOr(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}
