package middleware

import (
	"sync"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/zwecodes/g9pos/backend/pkg/response"
)

type limiter struct {
	mu      sync.Mutex
	window  time.Duration
	max     int
	buckets map[string][]time.Time
}

func newLimiter(max int, window time.Duration) *limiter {
	return &limiter{window: window, max: max, buckets: map[string][]time.Time{}}
}

func (l *limiter) allow(key string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := time.Now()
	cutoff := now.Add(-l.window)
	hits := l.buckets[key]
	kept := hits[:0]
	for _, t := range hits {
		if t.After(cutoff) {
			kept = append(kept, t)
		}
	}
	if len(kept) >= l.max {
		l.buckets[key] = kept
		return false
	}
	l.buckets[key] = append(kept, now)
	return true
}

func RateLimitIP(max int, window time.Duration) gin.HandlerFunc {
	return RateLimit(max, window, func(c *gin.Context) string { return c.ClientIP() })
}

func RateLimit(max int, window time.Duration, keyFn func(*gin.Context) string) gin.HandlerFunc {
	lim := newLimiter(max, window)
	return func(c *gin.Context) {
		if !lim.allow(keyFn(c)) {
			response.RateLimited(c)
			c.Abort()
			return
		}
		c.Next()
	}
}
