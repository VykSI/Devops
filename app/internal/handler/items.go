package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

type Item struct {
	ID        int       `json:"id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}

type CreateItemRequest struct {
	Name string `json:"name"`
}

type ItemHandler struct {
	DB itemStore
}

type itemStore interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
	QueryRow(context.Context, string, ...any) pgx.Row
}

func NewItemHandler(db itemStore) *ItemHandler {
	return &ItemHandler{
		DB: db,
	}
}

func (h *ItemHandler) List(w http.ResponseWriter, r *http.Request) {
	rows, err := h.DB.Query(
		r.Context(),
		`SELECT id, name, created_at
		 FROM items
		 ORDER BY id`,
	)
	if err != nil {
		http.Error(w, "failed to query items", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	items := make([]Item, 0)

	for rows.Next() {
		var item Item

		if err := rows.Scan(
			&item.ID,
			&item.Name,
			&item.CreatedAt,
		); err != nil {
			http.Error(w, "failed to read item", http.StatusInternalServerError)
			return
		}

		items = append(items, item)
	}

	if err := rows.Err(); err != nil {
		http.Error(w, "failed to iterate items", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusOK, items)
}

func (h *ItemHandler) Create(w http.ResponseWriter, r *http.Request) {
	var request CreateItemRequest

	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	request.Name = strings.TrimSpace(request.Name)

	if request.Name == "" {
		http.Error(w, "name is required", http.StatusBadRequest)
		return
	}

	var item Item

	err := h.DB.QueryRow(
		r.Context(),
		`INSERT INTO items (name)
		 VALUES ($1)
		 RETURNING id, name, created_at`,
		request.Name,
	).Scan(
		&item.ID,
		&item.Name,
		&item.CreatedAt,
	)

	if err != nil {
		http.Error(w, "failed to create item", http.StatusInternalServerError)
		return
	}

	writeJSON(w, http.StatusCreated, item)
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)

	_ = json.NewEncoder(w).Encode(value)
}
