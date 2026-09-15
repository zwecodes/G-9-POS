package reports

import (
	"log/slog"

	"github.com/gin-gonic/gin"

	"github.com/zwecodes/g9pos/backend/internal/auth"
	"github.com/zwecodes/g9pos/backend/pkg/middleware"
	"github.com/zwecodes/g9pos/backend/pkg/response"
)

type Handler struct {
	service *Service
	auth    *auth.Service
}

func NewHandler(service *Service, authService *auth.Service) *Handler {
	return &Handler{service: service, auth: authService}
}

func (h *Handler) requireOwnerPIN(c *gin.Context) bool {
	operatorID := c.Query("operator_id")
	if operatorID == "" {
		operatorID = c.GetString(middleware.CtxUserID)
	}
	u, err := h.auth.UserByID(c.Request.Context(), operatorID)
	if err != nil {
		slog.Error("reports operator lookup failed", "error", err)
		response.InternalError(c, "Could not load report")
		return false
	}
	if u == nil || u.Role != "owner" {
		response.Forbidden(c)
		return false
	}
	return true
}

func (h *Handler) DailySummary(c *gin.Context) {
	if !h.requireOwnerPIN(c) {
		return
	}
	row, err := h.service.DailySummary(c.Request.Context(), c.Query("date"))
	if err != nil {
		slog.Error("daily summary failed", "error", err)
		response.InternalError(c, "Could not load the daily summary")
		return
	}
	response.OK(c, row)
}

func (h *Handler) Range(c *gin.Context) {
	if !h.requireOwnerPIN(c) {
		return
	}
	rows, err := h.service.Range(c.Request.Context(), c.Query("date_from"), c.Query("date_to"), c.Query("group_by"))
	if err != nil {
		slog.Error("range report failed", "error", err)
		response.InternalError(c, "Could not load the report")
		return
	}
	response.OK(c, rows)
}

func (h *Handler) LowStock(c *gin.Context) {
	if !h.requireOwnerPIN(c) {
		return
	}
	rows, err := h.service.LowStock(c.Request.Context())
	if err != nil {
		slog.Error("low stock report failed", "error", err)
		response.InternalError(c, "Could not load low-stock products")
		return
	}
	response.OK(c, rows)
}

func (h *Handler) StaffActivity(c *gin.Context) {
	if !h.requireOwnerPIN(c) {
		return
	}
	rows, err := h.service.StaffActivity(c.Request.Context(), c.Query("date_from"), c.Query("date_to"))
	if err != nil {
		slog.Error("staff activity failed", "error", err)
		response.InternalError(c, "Could not load staff activity")
		return
	}
	response.OK(c, rows)
}

func (h *Handler) Overview(c *gin.Context) {
	if !h.requireOwnerPIN(c) {
		return
	}
	row, err := h.service.Overview(c.Request.Context())
	if err != nil {
		slog.Error("dashboard overview failed", "error", err)
		response.InternalError(c, "Could not load the dashboard")
		return
	}
	response.OK(c, row)
}
