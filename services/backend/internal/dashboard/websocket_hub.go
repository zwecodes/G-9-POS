package dashboard

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"github.com/zwecodes/g9pos/backend/pkg/middleware"
	"github.com/zwecodes/g9pos/backend/pkg/response"
)

const maxConnsPerUser = 3

type TokenParser interface {
	ParseAccess(token string) (*middleware.Claims, error)
	IsDeviceRevoked(deviceID string) (bool, error)
	IsTokenDenied(jti string) bool
}

type Hub struct {
	mu      sync.Mutex
	clients map[*client]struct{}
	byUser  map[string]int
	parser  TokenParser
}

type client struct {
	userID string
	conn   *websocket.Conn
	send   chan []byte
}

func NewHub(parser TokenParser) *Hub {
	return &Hub{
		clients: map[*client]struct{}{},
		byUser:  map[string]int{},
		parser:  parser,
	}
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

func (h *Hub) HandleWS(c *gin.Context) {
	token := c.Query("token")
	claims, err := h.parser.ParseAccess(token)
	if err != nil || claims.Role != "dashboard_viewer" {
		response.Unauthorized(c)
		return
	}
	if h.parser.IsTokenDenied(claims.ID) {
		response.Unauthorized(c)
		return
	}
	revoked, err := h.parser.IsDeviceRevoked(claims.DeviceID)
	if err != nil || revoked {
		response.Unauthorized(c)
		return
	}

	h.mu.Lock()
	if h.byUser[claims.Subject] >= maxConnsPerUser {
		h.mu.Unlock()
		response.RateLimited(c)
		return
	}
	h.mu.Unlock()

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		slog.Error("websocket upgrade failed", "error", err)
		return
	}

	cl := &client{userID: claims.Subject, conn: conn, send: make(chan []byte, 16)}
	h.add(cl)
	go cl.write()
	h.read(cl)
}

func (h *Hub) Broadcast(event string, payload any) {
	body, err := json.Marshal(map[string]any{"event": event, "payload": payload})
	if err != nil {
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	for cl := range h.clients {
		select {
		case cl.send <- body:
		default:
		}
	}
}

func (h *Hub) add(cl *client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.clients[cl] = struct{}{}
	h.byUser[cl.userID]++
}

func (h *Hub) remove(cl *client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if _, ok := h.clients[cl]; !ok {
		return
	}
	delete(h.clients, cl)
	h.byUser[cl.userID]--
	if h.byUser[cl.userID] <= 0 {
		delete(h.byUser, cl.userID)
	}
	close(cl.send)
	_ = cl.conn.Close()
}

func (h *Hub) read(cl *client) {
	defer h.remove(cl)
	for {
		if _, _, err := cl.conn.ReadMessage(); err != nil {
			return
		}
	}
}

func (c *client) write() {
	for msg := range c.send {
		if err := c.conn.WriteMessage(websocket.TextMessage, msg); err != nil {
			return
		}
	}
}
