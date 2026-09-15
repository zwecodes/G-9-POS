package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"

	"github.com/zwecodes/g9pos/backend/pkg/response"
)

const (
	CtxUserID   = "user_id"
	CtxRole     = "role"
	CtxDeviceID = "device_id"
	CtxTokenJTI = "token_jti"
)

type Claims struct {
	Role     string `json:"role"`
	DeviceID string `json:"device_id"`
	TokenUse string `json:"token_use"`
	jwt.RegisteredClaims
}

type TokenValidator interface {
	ParseAccess(token string) (*Claims, error)
	IsDeviceRevoked(deviceID string) (bool, error)
	IsTokenDenied(jti string) bool
}

func JWT(v TokenValidator) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			response.Unauthorized(c)
			c.Abort()
			return
		}
		raw := strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
		claims, err := v.ParseAccess(raw)
		if err != nil {
			response.Unauthorized(c)
			c.Abort()
			return
		}
		if v.IsTokenDenied(claims.ID) {
			response.Unauthorized(c)
			c.Abort()
			return
		}
		revoked, err := v.IsDeviceRevoked(claims.DeviceID)
		if err != nil {
			response.InternalError(c, "Could not check this device")
			c.Abort()
			return
		}
		if revoked {
			response.Unauthorized(c)
			c.Abort()
			return
		}
		c.Set(CtxUserID, claims.Subject)
		c.Set(CtxRole, claims.Role)
		c.Set(CtxDeviceID, claims.DeviceID)
		c.Set(CtxTokenJTI, claims.ID)
		c.Next()
	}
}

func RequireRoles(roles ...string) gin.HandlerFunc {
	allowed := map[string]struct{}{}
	for _, r := range roles {
		allowed[r] = struct{}{}
	}
	return func(c *gin.Context) {
		role := c.GetString(CtxRole)
		if _, ok := allowed[role]; !ok {
			response.Forbidden(c)
			c.Abort()
			return
		}
		c.Next()
	}
}
