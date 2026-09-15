package suppliers

import (
	"log/slog"

	"github.com/gin-gonic/gin"

	"github.com/zwecodes/g9pos/backend/pkg/response"
)

type Handler struct{ service *Service }

func NewHandler(service *Service) *Handler { return &Handler{service: service} }

func (h *Handler) List(c *gin.Context) {
	rows, err := h.service.ListSuppliers(c.Request.Context())
	if err != nil {
		slog.Error("list suppliers failed", "error", err)
		response.InternalError(c, "Could not load suppliers")
		return
	}
	response.OK(c, rows)
}

func (h *Handler) ListOrders(c *gin.Context) {
	rows, err := h.service.ListOrders(c.Request.Context())
	if err != nil {
		slog.Error("list supplier orders failed", "error", err)
		response.InternalError(c, "Could not load orders")
		return
	}
	response.OK(c, rows)
}
