# FITFLOW API image. If you get "no space left on device" during build,
# use the host-build path instead: ./scripts/build-api-runtime.sh
# (or see Dockerfile.runtime and deployments/docker/README.md)
#
# Build stage (works without BuildKit)
FROM golang:1.23-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /fitflow-api ./cmd/api

# Run stage
FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata wget

WORKDIR /app

COPY --from=builder /fitflow-api .
COPY migrations ./migrations

EXPOSE 8080

ENTRYPOINT ["./fitflow-api"]
