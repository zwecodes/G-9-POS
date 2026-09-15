package timezone

import (
	"fmt"
	"os"
	"sync"
	"time"
)

const ShopTimezone = "Asia/Yangon"

var (
	locOnce sync.Once
	loc     *time.Location
)

func ShopLocation() *time.Location {
	locOnce.Do(func() {
		name := os.Getenv("SHOP_TIMEZONE")
		if name == "" {
			name = ShopTimezone
		}
		loaded, err := time.LoadLocation(name)
		if err != nil {
			panic(fmt.Sprintf("could not load shop timezone %s: %v", name, err))
		}
		loc = loaded
	})
	return loc
}

func NowInShop() time.Time {
	return time.Now().In(ShopLocation())
}

func ShopDateString(t time.Time) string {
	return t.In(ShopLocation()).Format("2006-01-02")
}

func IsSameShopDay(a, b time.Time) bool {
	if a.IsZero() || b.IsZero() {
		return false
	}
	return ShopDateString(a) == ShopDateString(b)
}

func ParseShopDate(date string) (time.Time, error) {
	return time.ParseInLocation("2006-01-02", date, ShopLocation())
}

func ShopDayBounds(date string) (time.Time, time.Time, error) {
	start, err := ParseShopDate(date)
	if err != nil {
		return time.Time{}, time.Time{}, err
	}
	end := start.Add(24 * time.Hour)
	return start, end, nil
}

func UnixMs(t time.Time) int64 {
	if t.IsZero() {
		return 0
	}
	return t.UnixMilli()
}

func FromUnixMs(ms int64) time.Time {
	if ms <= 0 {
		return time.Time{}
	}
	return time.UnixMilli(ms).UTC()
}
