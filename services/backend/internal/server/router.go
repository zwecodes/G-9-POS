package server

import (
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"

	"github.com/zwecodes/g9pos/backend/internal/auth"
	"github.com/zwecodes/g9pos/backend/internal/categories"
	"github.com/zwecodes/g9pos/backend/internal/dashboard"
	"github.com/zwecodes/g9pos/backend/internal/devices"
	"github.com/zwecodes/g9pos/backend/internal/expenses"
	"github.com/zwecodes/g9pos/backend/internal/inventory"
	"github.com/zwecodes/g9pos/backend/internal/products"
	"github.com/zwecodes/g9pos/backend/internal/reports"
	"github.com/zwecodes/g9pos/backend/internal/sales"
	"github.com/zwecodes/g9pos/backend/internal/suppliers"
	syn "github.com/zwecodes/g9pos/backend/internal/sync"
	"github.com/zwecodes/g9pos/backend/pkg/middleware"
)

type Options struct {
	RelaxLimits bool
}

func New(database *sqlx.DB, jwtSecret string, opts Options) *gin.Engine {
	authRepo := auth.NewRepository(database)
	authService := auth.NewService(authRepo, jwtSecret)
	authHandler := auth.NewHandler(authService)

	catService := categories.NewService(categories.NewRepository(database))
	prodService := products.NewService(products.NewRepository(database))
	invService := inventory.NewService(inventory.NewRepository(database))
	saleService := sales.NewService(sales.NewRepository(database))
	expService := expenses.NewService(expenses.NewRepository(database))
	supService := suppliers.NewService(suppliers.NewRepository(database))
	devService := devices.NewService(devices.NewRepository(database))

	hub := dashboard.NewHub(authService)
	processor := syn.NewProcessor(catService, prodService, invService, saleService, expService, supService, devService)
	syncService := syn.NewService(syn.NewRepository(database), processor, catService, prodService, invService, saleService, devService, hub)
	syncHandler := syn.NewHandler(syncService)

	reportService := reports.NewService(reports.NewRepository(database), prodService, devService)
	reportHandler := reports.NewHandler(reportService, authService)

	catHandler := categories.NewHandler(catService)
	prodHandler := products.NewHandler(prodService)
	invHandler := inventory.NewHandler(invService)
	saleHandler := sales.NewHandler(saleService)
	expHandler := expenses.NewHandler(expService)
	supHandler := suppliers.NewHandler(supService)
	devHandler := devices.NewHandler(devService)

	loginLimit := 5
	syncLimit := 60
	importLimit := 5
	if opts.RelaxLimits {
		loginLimit, syncLimit, importLimit = 10_000, 10_000, 10_000
	}

	r := gin.New()
	r.Use(gin.Recovery(), middleware.RequestID(), middleware.Logger())
	r.Use(cors.New(cors.Config{
		AllowOriginFunc:  func(origin string) bool { return true },
		AllowMethods:     []string{"GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Authorization", "Content-Type", "X-Request-ID"},
		ExposeHeaders:    []string{"X-Request-ID"},
		AllowCredentials: true,
	}))

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
	r.GET("/ws", hub.HandleWS)

	v1 := r.Group("/v1")
	{
		v1.POST("/setup", middleware.RateLimitIP(loginLimit, time.Minute), authHandler.Setup)
		v1.POST("/auth/login", middleware.RateLimitIP(loginLimit, time.Minute), authHandler.Login)
		v1.POST("/auth/refresh", authHandler.Refresh)

		authed := v1.Group("")
		authed.Use(middleware.JWT(authService))
		{
			authed.POST("/auth/logout", authHandler.Logout)

			ownerDash := authed.Group("")
			ownerDash.Use(middleware.RequireRoles("owner", "dashboard_viewer"))
			{
				ownerDash.GET("/users", authHandler.ListUsers)
				ownerDash.POST("/users", middleware.RateLimit(importLimit, time.Minute, func(c *gin.Context) string {
					return c.GetString(middleware.CtxUserID)
				}), authHandler.CreateStaff)
				ownerDash.GET("/devices", devHandler.List)
				ownerDash.POST("/devices/:id/revoke", devHandler.Revoke)
				ownerDash.GET("/suppliers", supHandler.List)
				ownerDash.GET("/supplier-orders", supHandler.ListOrders)
				ownerDash.GET("/products/:id/inventory-events", invHandler.ListForProduct)
				ownerDash.GET("/reports/daily-summary", reportHandler.DailySummary)
				ownerDash.GET("/reports/range", reportHandler.Range)
				ownerDash.GET("/reports/low-stock", reportHandler.LowStock)
				ownerDash.GET("/reports/staff-activity", reportHandler.StaffActivity)
				ownerDash.GET("/dashboard/overview", reportHandler.Overview)
				ownerDash.POST("/catalog/import", middleware.RateLimit(importLimit, time.Minute, func(c *gin.Context) string {
					return "import:" + c.GetString(middleware.CtxUserID)
				}), syncHandler.ImportCatalog)
			}

			authed.PATCH("/devices/:id", middleware.RequireRoles("owner"), devHandler.Rename)

			shop := authed.Group("")
			shop.Use(middleware.RequireRoles("owner", "staff", "dashboard_viewer"))
			{
				shop.GET("/categories", catHandler.List)
				shop.GET("/products", prodHandler.List)
				shop.GET("/products/:id", prodHandler.Get)
				shop.GET("/sales", saleHandler.List)
				shop.GET("/sales/:id", saleHandler.Get)
				shop.GET("/expenses", expHandler.List)
			}

			pos := authed.Group("")
			pos.Use(middleware.RequireRoles("owner", "staff"))
			{
				pos.POST("/sync/events", middleware.RateLimit(syncLimit, time.Minute, func(c *gin.Context) string {
					return "sync:" + c.GetString(middleware.CtxDeviceID)
				}), syncHandler.SubmitEvents)
				pos.GET("/sync/pull", syncHandler.Pull)
			}
		}
	}
	return r
}
