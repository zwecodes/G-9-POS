package products

import (
	"log/slog"

	"github.com/gin-gonic/gin"

	"github.com/zwecodes/g9pos/backend/pkg/response"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler { return &Handler{service: service} }

func (h *Handler) List(c *gin.Context) {
	var active *bool
	if v := c.Query("is_active"); v != "" {
		b := v == "true"
		active = &b
	}
	rows, err := h.service.List(
		c.Request.Context(),
		c.Query("category_id"),
		c.Query("q"),
		active,
		c.Query("low_stock_only") == "true",
	)
	if err != nil {
		slog.Error("list products failed", "error", err)
		response.InternalError(c, "Could not load products")
		return
	}
	response.OK(c, rows)
}

func (h *Handler) Get(c *gin.Context) {
	p, err := h.service.Get(c.Request.Context(), c.Param("id"))
	if err != nil {
		slog.Error("get product failed", "error", err)
		response.InternalError(c, "Could not load product")
		return
	}
	if p == nil {
		response.NotFound(c, "Product not found")
		return
	}
	response.OK(c, p)
}
