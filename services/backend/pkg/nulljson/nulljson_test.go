package nulljson

import (
	"encoding/json"
	"testing"
)

func TestStringMarshalsAsJSONStringOrNull(t *testing.T) {
	b, err := json.Marshal(Text("abc"))
	if err != nil {
		t.Fatal(err)
	}
	if string(b) != `"abc"` {
		t.Fatalf("got %s", b)
	}
	b, err = json.Marshal(String{})
	if err != nil {
		t.Fatal(err)
	}
	if string(b) != "null" {
		t.Fatalf("got %s", b)
	}
}
