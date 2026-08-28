package metrics

import (
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

var (
	RequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests.",
		},
		[]string{"method", "path", "status"},
	)

	RequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name: "http_request_duration_seconds",
			Help: "HTTP request duration in seconds.",
		},
		[]string{"method", "path"},
	)
)

func Init() {
	prometheus.MustRegister(RequestsTotal)
	prometheus.MustRegister(RequestDuration)
}

func Observe(method, path string, status int, duration time.Duration) {
	RequestsTotal.WithLabelValues(
		method,
		path,
		strconv.Itoa(status),
	).Inc()

	RequestDuration.WithLabelValues(
		method,
		path,
	).Observe(duration.Seconds())
}
