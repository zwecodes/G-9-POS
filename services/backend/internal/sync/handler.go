package sync

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/zwecodes/g9pos/backend/pkg/middleware"
	"github.com/zwecodes/g9pos/backend/pkg/response"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler { return &Handler{service: service} }

func (h *Handler) SubmitEvents(c *gin.Context) {
	if c.GetString(middleware.CtxRole) == "dashboard_viewer" {
		response.Forbidden(c)
		return
	}
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBatchBytes+1)
	raw, err := io.ReadAll(c.Request.Body)
	if err != nil {
		var maxErr *http.MaxBytesError
		if errors.As(err, &maxErr) {
			response.PayloadTooLarge(c)
			return
		}
		response.BadRequest(c, "This request could not be read.")
		return
	}
	if len(raw) > maxBatchBytes {
		response.PayloadTooLarge(c)
		return
	}

	var req BatchRequest
	if err := json.Unmarshal(raw, &req); err != nil {
		response.BadRequest(c, "This request could not be read.")
		return
	}

	result, err := h.service.SubmitBatch(
		c.Request.Context(),
		c.GetString(middleware.CtxRole),
		c.GetString(middleware.CtxDeviceID),
		raw,
		req,
	)
	if IsPayloadTooLarge(err) {
		response.PayloadTooLarge(c)
		return
	}
	if IsInvalidBatch(err) || IsDeviceMismatch(err) {
		response.BadRequest(c, "This sync batch could not be saved.")
		return
	}
	if err != nil {
		slog.Error("sync batch failed", "error", err)
		response.InternalError(c, "Could not save these changes")
		return
	}
	response.OK(c, result)
}

func (h *Handler) Pull(c *gin.Context) {
	deviceID := c.Query("device_id")
	if deviceID == "" {
		deviceID = c.GetString(middleware.CtxDeviceID)
	}
	payload, err := h.service.Pull(c.Request.Context(), deviceID, c.Query("last_sync_at"))
	if err != nil {
		slog.Error("sync pull failed", "error", err)
		response.InternalError(c, "Could not load updates")
		return
	}
	response.OK(c, payload)
}

func (h *Handler) ImportCatalog(c *gin.Context) {
	file, err := c.FormFile("file")
	if err != nil {
		response.BadRequestField(c, "Please choose a CSV file.", "file")
		return
	}
	if file.Size > maxBatchBytes {
		response.PayloadTooLarge(c)
		return
	}
	f, err := file.Open()
	if err != nil {
		response.BadRequestField(c, "This file could not be read.", "file")
		return
	}
	defer f.Close()

	result, err := h.service.ImportCatalog(
		c.Request.Context(),
		f,
		c.GetString(middleware.CtxDeviceID),
		c.GetString(middleware.CtxUserID),
	)
	var importErr *ImportError
	if errors.As(err, &importErr) {
		response.Error(c, 400, &response.APIError{
			Code:    "VALIDATION_ERROR",
			Message: "CSV import failed. No products were created.",
			Field:   "file",
			Details: importErr.Details,
		})
		return
	}
	if err != nil {
		slog.Error("catalog import failed", "error", err)
		response.InternalError(c, "Could not import the catalog")
		return
	}
	response.OK(c, result)
}
