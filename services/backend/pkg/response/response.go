package response

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const RequestIDKey = "request_id"

type Page struct {
	Cursor     string `json:"cursor,omitempty"`
	NextCursor string `json:"next_cursor,omitempty"`
	HasMore    bool   `json:"has_more"`
	Limit      int    `json:"limit"`
}

type Meta struct {
	RequestID string `json:"request_id"`
	Page      *Page  `json:"page,omitempty"`
}

type APIError struct {
	Code       string `json:"code"`
	Message    string `json:"message"`
	Field      string `json:"field,omitempty"`
	RetryAfter *int   `json:"retry_after,omitempty"`
	Details    any    `json:"details,omitempty"`
}

type APIResponse struct {
	Data  any       `json:"data,omitempty"`
	Error *APIError `json:"error,omitempty"`
	Meta  Meta      `json:"meta"`
}

func RequestID(c *gin.Context) string {
	if id := c.GetString(RequestIDKey); id != "" {
		return id
	}
	id := c.GetHeader("X-Request-ID")
	if id == "" {
		id = "req_" + uuid.NewString()
	}
	c.Set(RequestIDKey, id)
	return id
}

func meta(c *gin.Context) Meta {
	return Meta{RequestID: RequestID(c)}
}

func OK(c *gin.Context, data any) {
	c.JSON(200, APIResponse{Data: data, Meta: meta(c)})
}

func OKPage(c *gin.Context, data any, page Page) {
	m := meta(c)
	m.Page = &page
	c.JSON(200, APIResponse{Data: data, Meta: m})
}

func BadRequest(c *gin.Context, message string) {
	errorJSON(c, 400, &APIError{Code: "VALIDATION_ERROR", Message: message})
}

func BadRequestField(c *gin.Context, message, field string) {
	errorJSON(c, 400, &APIError{Code: "VALIDATION_ERROR", Message: message, Field: field})
}

func Unauthorized(c *gin.Context) {
	errorJSON(c, 401, &APIError{Code: "UNAUTHORIZED", Message: "Authentication required"})
}

func AccountLocked(c *gin.Context, retryAfterSec int) {
	errorJSON(c, 401, &APIError{
		Code:       "ACCOUNT_LOCKED",
		Message:    "This account is locked. Try again in a few minutes.",
		RetryAfter: &retryAfterSec,
	})
}

func Forbidden(c *gin.Context) {
	errorJSON(c, 403, &APIError{Code: "FORBIDDEN", Message: "You do not have permission to do that."})
}

func NotFound(c *gin.Context, message string) {
	errorJSON(c, 404, &APIError{Code: "NOT_FOUND", Message: message})
}

func Conflict(c *gin.Context, code, message string) {
	errorJSON(c, 409, &APIError{Code: code, Message: message})
}

func PayloadTooLarge(c *gin.Context) {
	errorJSON(c, 413, &APIError{Code: "PAYLOAD_TOO_LARGE", Message: "This request is too large."})
}

func RateLimited(c *gin.Context) {
	errorJSON(c, 429, &APIError{Code: "RATE_LIMITED", Message: "Too many attempts. Please wait and try again."})
}

func InternalError(c *gin.Context, message string) {
	errorJSON(c, 500, &APIError{Code: "INTERNAL_ERROR", Message: message})
}

func Error(c *gin.Context, status int, err *APIError) {
	errorJSON(c, status, err)
}

func errorJSON(c *gin.Context, status int, err *APIError) {
	c.JSON(status, APIResponse{Error: err, Meta: meta(c)})
}
