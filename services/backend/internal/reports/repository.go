package reports

import (
	"context"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"

	"github.com/zwecodes/g9pos/backend/internal/devices"
	"github.com/zwecodes/g9pos/backend/internal/products"
	"github.com/zwecodes/g9pos/backend/pkg/timezone"
)

type DailySummary struct {
	Date             string         `json:"date"`
	RevenueMmk       int            `json:"revenue_mmk"`
	ProfitMmk        int            `json:"profit_mmk"`
	TransactionCount int            `json:"transaction_count"`
	IncompleteProfit bool           `json:"incomplete_profit"`
	TopProducts      []TopProduct   `json:"top_products"`
}

type TopProduct struct {
	ProductID   string `db:"product_id" json:"product_id"`
	Name        string `db:"name" json:"name"`
	Quantity    int    `db:"quantity" json:"quantity"`
	RevenueMmk  int    `db:"revenue_mmk" json:"revenue_mmk"`
}

type RangePoint struct {
	Bucket      time.Time `db:"bucket" json:"-"`
	Period      string    `json:"period"`
	RevenueMmk  int       `db:"revenue_mmk" json:"revenue_mmk"`
	ProfitMmk   int       `db:"profit_mmk" json:"profit_mmk"`
	Count       int       `db:"txn_count" json:"transaction_count"`
}

type StaffRow struct {
	OperatorID       string `db:"operator_id" json:"operator_id"`
	Name             string `db:"name" json:"name"`
	SalesCount       int    `db:"sales_count" json:"sales_count"`
	SalesValueMmk    int    `db:"sales_value_mmk" json:"sales_value_mmk"`
}

type Overview struct {
	Date           string           `json:"date"`
	RevenueMmk     int              `json:"revenue_mmk"`
	LowStockCount  int              `json:"low_stock_count"`
	ActiveDevice   *devices.Device  `json:"active_device"`
	Devices        []devices.Device `json:"devices"`
}

type Repository struct{ db *sqlx.DB }

func NewRepository(db *sqlx.DB) *Repository { return &Repository{db: db} }

func (r *Repository) Daily(ctx context.Context, start, end time.Time) (revenue, count int, err error) {
	err = r.db.QueryRowxContext(ctx, `
		SELECT COALESCE(SUM(total_amount_mmk), 0), COUNT(*)
		FROM sales
		WHERE status = 'completed' AND created_at >= $1 AND created_at < $2`,
		start, end).Scan(&revenue, &count)
	if err != nil {
		return 0, 0, fmt.Errorf("reports.Daily: %w", err)
	}
	return revenue, count, nil
}

func (r *Repository) Profit(ctx context.Context, start, end time.Time) (profit int, incomplete bool, err error) {
	err = r.db.QueryRowxContext(ctx, `
		SELECT
			COALESCE(SUM(CASE WHEN p.cost_price_mmk IS NOT NULL THEN si.subtotal_mmk - p.cost_price_mmk * si.quantity ELSE 0 END), 0),
			COALESCE(BOOL_OR(p.cost_price_mmk IS NULL), false)
		FROM sale_items si
		JOIN sales s ON s.id = si.sale_id
		JOIN products p ON p.id = si.product_id
		WHERE s.status = 'completed' AND s.created_at >= $1 AND s.created_at < $2`,
		start, end).Scan(&profit, &incomplete)
	if err != nil {
		return 0, false, fmt.Errorf("reports.Profit: %w", err)
	}
	return profit, incomplete, nil
}

func (r *Repository) TopProducts(ctx context.Context, start, end time.Time) ([]TopProduct, error) {
	var rows []TopProduct
	err := r.db.SelectContext(ctx, &rows, `
		SELECT p.id AS product_id, p.name, SUM(si.quantity) AS quantity, SUM(si.subtotal_mmk) AS revenue_mmk
		FROM sale_items si
		JOIN sales s ON s.id = si.sale_id
		JOIN products p ON p.id = si.product_id
		WHERE s.status = 'completed' AND s.created_at >= $1 AND s.created_at < $2
		GROUP BY p.id, p.name
		ORDER BY revenue_mmk DESC
		LIMIT 10`, start, end)
	if err != nil {
		return nil, fmt.Errorf("reports.TopProducts: %w", err)
	}
	return rows, nil
}

func (r *Repository) Range(ctx context.Context, start, end time.Time, trunc string) ([]RangePoint, error) {
	var rows []RangePoint
	err := r.db.SelectContext(ctx, &rows, fmt.Sprintf(`
		WITH sales_agg AS (
			SELECT date_trunc('%s', s.created_at AT TIME ZONE '%s') AS bucket,
			       COALESCE(SUM(s.total_amount_mmk), 0) AS revenue_mmk,
			       COUNT(*) AS txn_count
			FROM sales s
			WHERE s.status = 'completed' AND s.created_at >= $1 AND s.created_at < $2
			GROUP BY 1
		),
		profit_agg AS (
			SELECT date_trunc('%s', s.created_at AT TIME ZONE '%s') AS bucket,
			       COALESCE(SUM(CASE WHEN p.cost_price_mmk IS NOT NULL THEN si.subtotal_mmk - p.cost_price_mmk * si.quantity ELSE 0 END), 0) AS profit_mmk
			FROM sales s
			JOIN sale_items si ON si.sale_id = s.id
			JOIN products p ON p.id = si.product_id
			WHERE s.status = 'completed' AND s.created_at >= $1 AND s.created_at < $2
			GROUP BY 1
		)
		SELECT s.bucket,
		       s.revenue_mmk,
		       COALESCE(p.profit_mmk, 0) AS profit_mmk,
		       s.txn_count
		FROM sales_agg s
		LEFT JOIN profit_agg p ON p.bucket = s.bucket
		ORDER BY 1`, trunc, timezone.ShopTimezone, trunc, timezone.ShopTimezone), start, end)
	if err != nil {
		return nil, fmt.Errorf("reports.Range: %w", err)
	}
	return rows, nil
}

func (r *Repository) StaffActivity(ctx context.Context, start, end time.Time) ([]StaffRow, error) {
	var rows []StaffRow
	err := r.db.SelectContext(ctx, &rows, `
		SELECT s.operator_id, u.name, COUNT(*) AS sales_count, COALESCE(SUM(s.total_amount_mmk), 0) AS sales_value_mmk
		FROM sales s
		JOIN users u ON u.id = s.operator_id
		WHERE s.status = 'completed' AND s.created_at >= $1 AND s.created_at < $2
		GROUP BY s.operator_id, u.name
		ORDER BY sales_value_mmk DESC`, start, end)
	if err != nil {
		return nil, fmt.Errorf("reports.StaffActivity: %w", err)
	}
	return rows, nil
}

type Service struct {
	repo     *Repository
	products *products.Service
	devices  *devices.Service
}

func NewService(repo *Repository, products *products.Service, devices *devices.Service) *Service {
	return &Service{repo: repo, products: products, devices: devices}
}

func (s *Service) DailySummary(ctx context.Context, date string) (DailySummary, error) {
	if date == "" {
		date = timezone.ShopDateString(time.Now())
	}
	start, end, err := timezone.ShopDayBounds(date)
	if err != nil {
		return DailySummary{}, err
	}
	start, end = start.UTC(), end.UTC()
	revenue, count, err := s.repo.Daily(ctx, start, end)
	if err != nil {
		return DailySummary{}, err
	}
	profit, incomplete, err := s.repo.Profit(ctx, start, end)
	if err != nil {
		return DailySummary{}, err
	}
	top, err := s.repo.TopProducts(ctx, start, end)
	if err != nil {
		return DailySummary{}, err
	}
	if top == nil {
		top = []TopProduct{}
	}
	return DailySummary{
		Date: date, RevenueMmk: revenue, ProfitMmk: profit,
		TransactionCount: count, IncompleteProfit: incomplete, TopProducts: top,
	}, nil
}

func (s *Service) Range(ctx context.Context, dateFrom, dateTo, groupBy string) ([]RangePoint, error) {
	if dateFrom == "" {
		dateFrom = timezone.ShopDateString(time.Now().Add(-30 * 24 * time.Hour))
	}
	if dateTo == "" {
		dateTo = timezone.ShopDateString(time.Now())
	}
	start, _, err := timezone.ShopDayBounds(dateFrom)
	if err != nil {
		return nil, err
	}
	_, end, err := timezone.ShopDayBounds(dateTo)
	if err != nil {
		return nil, err
	}
	trunc := "day"
	switch groupBy {
	case "week":
		trunc = "week"
	case "month":
		trunc = "month"
	}
	rows, err := s.repo.Range(ctx, start.UTC(), end.UTC(), trunc)
	if err != nil {
		return nil, err
	}
	for i := range rows {
		rows[i].Period = rows[i].Bucket.Format("2006-01-02")
	}
	if rows == nil {
		rows = []RangePoint{}
	}
	return rows, nil
}

func (s *Service) LowStock(ctx context.Context) ([]products.Product, error) {
	return s.products.List(ctx, "", "", nil, true)
}

func (s *Service) StaffActivity(ctx context.Context, dateFrom, dateTo string) ([]StaffRow, error) {
	if dateFrom == "" {
		dateFrom = timezone.ShopDateString(time.Now().Add(-30 * 24 * time.Hour))
	}
	if dateTo == "" {
		dateTo = timezone.ShopDateString(time.Now())
	}
	start, _, err := timezone.ShopDayBounds(dateFrom)
	if err != nil {
		return nil, err
	}
	_, end, err := timezone.ShopDayBounds(dateTo)
	if err != nil {
		return nil, err
	}
	rows, err := s.repo.StaffActivity(ctx, start.UTC(), end.UTC())
	if err != nil {
		return nil, err
	}
	if rows == nil {
		rows = []StaffRow{}
	}
	return rows, nil
}

func (s *Service) Overview(ctx context.Context) (Overview, error) {
	date := timezone.ShopDateString(time.Now())
	start, end, err := timezone.ShopDayBounds(date)
	if err != nil {
		return Overview{}, err
	}
	revenue, _, err := s.repo.Daily(ctx, start.UTC(), end.UTC())
	if err != nil {
		return Overview{}, err
	}
	low, err := s.products.List(ctx, "", "", nil, true)
	if err != nil {
		return Overview{}, err
	}
	devs, err := s.devices.List(ctx)
	if err != nil {
		return Overview{}, err
	}
	var active *devices.Device
	for i := range devs {
		if devs[i].IsActivePOS && !devs[i].RevokedAt.Valid {
			d := devs[i]
			active = &d
			break
		}
	}
	return Overview{
		Date: date, RevenueMmk: revenue, LowStockCount: len(low),
		ActiveDevice: active, Devices: devs,
	}, nil
}
