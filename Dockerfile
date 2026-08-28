# Build stage — runs natively on GitHub's AMD64 runner
FROM --platform=linux/amd64 golang:1.27-alpine AS builder

WORKDIR /src

COPY app/go.mod app/go.sum ./
RUN go mod download

COPY app/ ./

RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
    go build -trimpath -ldflags="-s -w" \
    -o /server ./cmd/server


# Runtime stage — ARM64 for ECS
FROM --platform=linux/arm64 alpine:3.22

RUN addgroup -S app && adduser -S app -G app

WORKDIR /app

COPY --from=builder /server /app/server

USER app

EXPOSE 8080

ENTRYPOINT ["/app/server"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O - http://localhost:8080/health || exit 1