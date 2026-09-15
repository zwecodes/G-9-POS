package nulljson

import (
	"database/sql"
	"encoding/json"
)

type String struct {
	sql.NullString
}

func Text(s string) String {
	return String{sql.NullString{String: s, Valid: true}}
}

func (s String) MarshalJSON() ([]byte, error) {
	if !s.Valid {
		return []byte("null"), nil
	}
	return json.Marshal(s.String)
}

func (s *String) UnmarshalJSON(b []byte) error {
	if string(b) == "null" {
		s.Valid = false
		s.String = ""
		return nil
	}
	var v string
	if err := json.Unmarshal(b, &v); err != nil {
		return err
	}
	s.String = v
	s.Valid = true
	return nil
}

type Int64 struct {
	sql.NullInt64
}

func Int(n int64) Int64 {
	return Int64{sql.NullInt64{Int64: n, Valid: true}}
}

func (n Int64) MarshalJSON() ([]byte, error) {
	if !n.Valid {
		return []byte("null"), nil
	}
	return json.Marshal(n.Int64)
}

func (n *Int64) UnmarshalJSON(b []byte) error {
	if string(b) == "null" {
		n.Valid = false
		n.Int64 = 0
		return nil
	}
	var v int64
	if err := json.Unmarshal(b, &v); err != nil {
		return err
	}
	n.Int64 = v
	n.Valid = true
	return nil
}
