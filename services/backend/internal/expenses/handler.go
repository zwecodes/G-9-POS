package expenses

import (
	"log/slog"

	"github.com/gin-gonic/gin"

	"github.com/zwecodes/g9pos/backend/pkg/response"
)

type Handler struct{ service *Service }

func NewHandler(service *Service) *Handler { return &Handler{service: service} }

func (h *Handler) List(c *gin.Context) {
	rows, err := h.service.List(c.Request.Context(), c.Query("date_from"), c.Query("date_to"), c.Query("category"))
	if err != nil {
		slog.Error("list expenses failed", "error", err)
		response.InternalError(c, "Could not load expenses")
		return
	}
	response.OK(c, rows)
}
