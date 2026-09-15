package categories

import (
	"log/slog"

	"github.com/gin-gonic/gin"

	"github.com/zwecodes/g9pos/backend/pkg/middleware"
	"github.com/zwecodes/g9pos/backend/pkg/response"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler { return &Handler{service: service} }

func (h *Handler) List(c *gin.Context) {
	includeDeleted := c.Query("include_deleted") == "true"
	role := c.GetString(middleware.CtxRole)
	if includeDeleted && role == "staff" {
		includeDeleted = false
	}
	rows, err := h.service.List(c.Request.Context(), includeDeleted)
	if err != nil {
		slog.Error("list categories failed", "error", err)
		response.InternalError(c, "Could not load categories")
		return
	}
	response.OK(c, rows)
}
