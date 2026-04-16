# ── builder ───────────────────────────────────────────────────────────────────
FROM golang:1.25-alpine AS builder

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /build

# Cache dependency downloads before copying full source
COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -trimpath -o /out/api    ./cmd/api
RUN go build -trimpath -o /out/worker ./cmd/worker

# ── api ───────────────────────────────────────────────────────────────────────
FROM alpine:3.21 AS api

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=builder /out/api ./api

EXPOSE 8080
CMD ["./api"]

# ── worker ────────────────────────────────────────────────────────────────────
FROM alpine:3.21 AS worker

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=builder /out/worker ./worker

CMD ["./worker"]

# ── dlq_cleaner ───────────────────────────────────────────────────────────────
FROM alpine:3.21 AS dlq_cleaner

# bash: required by the script; mysql-client: mysql CLI; util-linux: flock
RUN apk add --no-cache bash mysql-client util-linux

WORKDIR /app

COPY scripts/dlq_cleaner.sh scripts/dlq_cleaner.sh

CMD ["bash", "scripts/dlq_cleaner.sh"]

# ── rotation ──────────────────────────────────────────────────────────────────
FROM alpine:3.21 AS rotation

RUN apk add --no-cache bash openssl

WORKDIR /app

COPY scripts/rotation.sh scripts/rotation.sh

CMD ["bash", "scripts/rotation.sh"]
