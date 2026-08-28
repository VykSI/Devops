package handler

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/pashagolub/pgxmock/v4"
)

func TestCreateRejectsMalformedJSON(t *testing.T) {
	h := NewItemHandler(nil)
	req := httptest.NewRequest(http.MethodPost, "/api/items", bytes.NewBufferString("{"))
	recorder := httptest.NewRecorder()

	h.Create(recorder, req)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d, got %d", http.StatusBadRequest, recorder.Code)
	}
}

func TestCreateRejectsBlankName(t *testing.T) {
	h := NewItemHandler(nil)
	req := httptest.NewRequest(http.MethodPost, "/api/items", bytes.NewBufferString(`{"name":"  "}`))
	recorder := httptest.NewRecorder()

	h.Create(recorder, req)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d, got %d", http.StatusBadRequest, recorder.Code)
	}
}

func TestCreateReturnsCreatedItem(t *testing.T) {
	mock, err := pgxmock.NewPool()
	if err != nil {
		t.Fatalf("create database mock: %v", err)
	}
	defer mock.Close()

	createdAt := time.Date(2026, time.August, 28, 12, 0, 0, 0, time.UTC)
	mock.ExpectQuery(`INSERT INTO items`).
		WithArgs("widget").
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "created_at"}).AddRow(7, "widget", createdAt))

	req := httptest.NewRequest(http.MethodPost, "/api/items", bytes.NewBufferString(`{"name":"  widget "}`))
	recorder := httptest.NewRecorder()
	NewItemHandler(mock).Create(recorder, req)

	if recorder.Code != http.StatusCreated {
		t.Fatalf("expected status %d, got %d", http.StatusCreated, recorder.Code)
	}

	var item Item
	if err := json.NewDecoder(recorder.Body).Decode(&item); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if item.ID != 7 || item.Name != "widget" || !item.CreatedAt.Equal(createdAt) {
		t.Fatalf("unexpected item: %+v", item)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("database expectations: %v", err)
	}
}

func TestListReturnsItems(t *testing.T) {
	mock, err := pgxmock.NewPool()
	if err != nil {
		t.Fatalf("create database mock: %v", err)
	}
	defer mock.Close()

	createdAt := time.Date(2026, time.August, 28, 12, 0, 0, 0, time.UTC)
	mock.ExpectQuery(`SELECT id, name, created_at`).
		WillReturnRows(pgxmock.NewRows([]string{"id", "name", "created_at"}).
			AddRow(1, "first", createdAt).
			AddRow(2, "second", createdAt.Add(time.Minute)))

	req := httptest.NewRequest(http.MethodGet, "/api/items", nil)
	recorder := httptest.NewRecorder()
	NewItemHandler(mock).List(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, recorder.Code)
	}

	var items []Item
	if err := json.NewDecoder(recorder.Body).Decode(&items); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(items) != 2 || items[0].Name != "first" || items[1].Name != "second" {
		t.Fatalf("unexpected items: %+v", items)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("database expectations: %v", err)
	}
}

func TestListReturnsServerErrorWhenDatabaseFails(t *testing.T) {
	mock, err := pgxmock.NewPool()
	if err != nil {
		t.Fatalf("create database mock: %v", err)
	}
	defer mock.Close()

	mock.ExpectQuery(`SELECT id, name, created_at`).WillReturnError(assertionError("database unavailable"))

	req := httptest.NewRequest(http.MethodGet, "/api/items", nil)
	recorder := httptest.NewRecorder()
	NewItemHandler(mock).List(recorder, req)

	if recorder.Code != http.StatusInternalServerError {
		t.Fatalf("expected status %d, got %d", http.StatusInternalServerError, recorder.Code)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatalf("database expectations: %v", err)
	}
}

type assertionError string

func (e assertionError) Error() string { return string(e) }
