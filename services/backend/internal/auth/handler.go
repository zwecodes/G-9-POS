package auth

import (
	"errors"
	"log/slog"

	"github.com/gin-gonic/gin"

	"github.com/zwecodes/g9pos/backend/pkg/middleware"
	"github.com/zwecodes/g9pos/backend/pkg/response"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

type setupBody struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Name     string `json:"name"`
	PIN      string `json:"pin"`
	Role     string `json:"role"`
}

type loginBody struct {
	Username     string `json:"username"`
	Password     string `json:"password"`
	DeviceID     string `json:"device_id"`
	DeviceName   string `json:"device_name"`
	DeviceType   string `json:"device_type"`
	LoginContext string `json:"login_context"`
}

type refreshBody struct {
	RefreshToken string `json:"refresh_token"`
}

type staffBody struct {
	Name string `json:"name"`
	PIN  string `json:"pin"`
	Role string `json:"role"`
}

func (h *Handler) Setup(c *gin.Context) {
	var body setupBody
	if err := c.ShouldBindJSON(&body); err != nil {
		response.BadRequest(c, "Please check the form and try again.")
		return
	}
	if body.Role != "" {
		response.BadRequest(c, "Please check the form and try again.")
		return
	}
	user, err := h.service.Setup(c.Request.Context(), SetupInput{
		Username: body.Username,
		Password: body.Password,
		Name:     body.Name,
		PIN:      body.PIN,
	})
	if errors.Is(err, ErrValidation) {
		response.BadRequest(c, "Please check the form and try again.")
		return
	}
	if errors.Is(err, ErrSetupComplete) {
		response.Conflict(c, "SETUP_ALREADY_COMPLETE", "Setup is already complete.")
		return
	}
	if err != nil {
		slog.Error("setup failed", "error", err)
		response.InternalError(c, "Could not finish setup")
		return
	}
	response.OK(c, user)
}

func (h *Handler) Login(c *gin.Context) {
	var body loginBody
	if err := c.ShouldBindJSON(&body); err != nil {
		response.BadRequest(c, "Please check the form and try again.")
		return
	}
	pair, retry, err := h.service.Login(c.Request.Context(), LoginInput{
		Username:     body.Username,
		Password:     body.Password,
		DeviceID:     body.DeviceID,
		DeviceName:   body.DeviceName,
		DeviceType:   body.DeviceType,
		LoginContext: body.LoginContext,
	})
	if errors.Is(err, ErrAccountLocked) {
		response.AccountLocked(c, retry)
		return
	}
	if errors.Is(err, ErrInvalidCredentials) || errors.Is(err, ErrUnauthorized) {
		response.Unauthorized(c)
		return
	}
	if errors.Is(err, ErrValidation) {
		response.BadRequest(c, "Please check the form and try again.")
		return
	}
	if err != nil {
		slog.Error("login failed", "error", err)
		response.InternalError(c, "Could not sign in")
		return
	}
	response.OK(c, pair)
}

func (h *Handler) Refresh(c *gin.Context) {
	var body refreshBody
	if err := c.ShouldBindJSON(&body); err != nil || body.RefreshToken == "" {
		response.Unauthorized(c)
		return
	}
	pair, err := h.service.Refresh(c.Request.Context(), body.RefreshToken)
	if errors.Is(err, ErrUnauthorized) {
		response.Unauthorized(c)
		return
	}
	if err != nil {
		slog.Error("refresh failed", "error", err)
		response.InternalError(c, "Could not refresh the session")
		return
	}
	response.OK(c, pair)
}

func (h *Handler) Logout(c *gin.Context) {
	h.service.Logout(c.GetString(middleware.CtxTokenJTI))
	var body refreshBody
	_ = c.ShouldBindJSON(&body)
	if body.RefreshToken != "" {
		if claims, err := h.service.parseToken(body.RefreshToken, "refresh"); err == nil {
			h.service.DenyToken(claims.ID)
		}
	}
	response.OK(c, gin.H{})
}

func (h *Handler) CreateStaff(c *gin.Context) {
	var body staffBody
	if err := c.ShouldBindJSON(&body); err != nil {
		response.BadRequest(c, "Please check the form and try again.")
		return
	}
	if body.Role != "" {
		response.BadRequest(c, "Please check the form and try again.")
		return
	}
	user, err := h.service.CreateStaff(c.Request.Context(), body.Name, body.PIN)
	if errors.Is(err, ErrValidation) {
		response.BadRequest(c, "Please check the form and try again.")
		return
	}
	if errors.Is(err, ErrStaffLimit) {
		response.Conflict(c, "STAFF_LIMIT_REACHED", "A staff account already exists.")
		return
	}
	if err != nil {
		slog.Error("create staff failed", "error", err)
		response.InternalError(c, "Could not create staff")
		return
	}
	response.OK(c, user)
}

func (h *Handler) ListUsers(c *gin.Context) {
	users, err := h.service.ListUsers(c.Request.Context())
	if err != nil {
		slog.Error("list users failed", "error", err)
		response.InternalError(c, "Could not load users")
		return
	}
	response.OK(c, users)
}
