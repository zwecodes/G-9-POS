package inventory

import (
	"log/slog"

	"github.com/gin-gonic/gin"

	"github.com/zwecodes/g9pos/backend/pkg/response"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler { return &Handler{service: service} }

func (h *Handler) ListForProduct(c *gin.Context) {
	rows, err := h.service.ListForProduct(c.Request.Context(), c.Param("id"))
	if err != nil {
		slog.Error("list inventory events failed", "error", err)
		response.InternalError(c, "Could not load stock history")
		return
	}
	response.OK(c, rows)
}
