package devices

import (
	"database/sql"
	"log/slog"

	"github.com/gin-gonic/gin"

	"github.com/zwecodes/g9pos/backend/pkg/response"
)

type Handler struct{ service *Service }

func NewHandler(service *Service) *Handler { return &Handler{service: service} }

func (h *Handler) List(c *gin.Context) {
	rows, err := h.service.List(c.Request.Context())
	if err != nil {
		slog.Error("list devices failed", "error", err)
		response.InternalError(c, "Could not load devices")
		return
	}
	response.OK(c, rows)
}

func (h *Handler) Rename(c *gin.Context) {
	var body struct {
		Name string `json:"name"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || body.Name == "" {
		response.BadRequest(c, "Please enter a device name.")
		return
	}
	err := h.service.Rename(c.Request.Context(), c.Param("id"), body.Name)
	if err == sql.ErrNoRows {
		response.NotFound(c, "Device not found")
		return
	}
	if err != nil {
		slog.Error("rename device failed", "error", err)
		response.InternalError(c, "Could not rename device")
		return
	}
	response.OK(c, gin.H{"id": c.Param("id"), "name": body.Name})
}

func (h *Handler) Revoke(c *gin.Context) {
	err := h.service.Revoke(c.Request.Context(), c.Param("id"))
	if err == sql.ErrNoRows {
		response.NotFound(c, "Device not found")
		return
	}
	if err != nil {
		slog.Error("revoke device failed", "error", err)
		response.InternalError(c, "Could not revoke device")
		return
	}
	response.OK(c, gin.H{"id": c.Param("id"), "revoked": true})
}
