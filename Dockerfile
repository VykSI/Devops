# Build stage
FROM golang:1.27-alpine AS builder

WORKDIR /src

COPY app/go.mod app/go.sum ./
RUN go mod download

COPY app/ ./

RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
    go build -trimpath -ldflags="-s -w" \
    -o /server ./cmd/server


# Runtime stage
FROM alpine:3.22

RUN addgroup -S app && adduser -S app -G app

WORKDIR /app

COPY --from=builder /server /app/server

USER app

EXPOSE 8080

ENTRYPOINT ["/app/server"]