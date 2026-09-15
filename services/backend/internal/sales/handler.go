package sales

import (
	"log/slog"

	"github.com/gin-gonic/gin"

	"github.com/zwecodes/g9pos/backend/pkg/middleware"
	"github.com/zwecodes/g9pos/backend/pkg/response"
)

type Handler struct{ service *Service }

func NewHandler(service *Service) *Handler { return &Handler{service: service} }

func (h *Handler) List(c *gin.Context) {
	operatorID := c.Query("operator_id")
	if c.GetString(middleware.CtxRole) == "staff" {
		operatorID = c.GetString(middleware.CtxUserID)
	}
	rows, err := h.service.List(c.Request.Context(), operatorID, c.Query("status"),
		c.Query("date_from"), c.Query("date_to"), c.Query("product_id"))
	if err != nil {
		slog.Error("list sales failed", "error", err)
		response.InternalError(c, "Could not load sales")
		return
	}
	response.OK(c, rows)
}

func (h *Handler) Get(c *gin.Context) {
	row, err := h.service.Get(c.Request.Context(), c.Param("id"))
	if err != nil {
		slog.Error("get sale failed", "error", err)
		response.InternalError(c, "Could not load sale")
		return
	}
	if row == nil {
		response.NotFound(c, "Sale not found")
		return
	}
	if c.GetString(middleware.CtxRole) == "staff" && row.OperatorID != c.GetString(middleware.CtxUserID) {
		response.Forbidden(c)
		return
	}
	response.OK(c, row)
}
