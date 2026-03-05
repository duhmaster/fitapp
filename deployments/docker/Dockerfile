# FITFLOW API image. If you get "no space left on device" during build,
# use the host-build path instead: ./scripts/build-api-runtime.sh
# (or see Dockerfile.runtime and deployments/docker/README.md)
#
# Build stage (use BuildKit: DOCKER_BUILDKIT=1 so cache mount works)
FROM golang:1.23-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
# Cache mount avoids storing full module cache in image layer (saves disk)
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .
# Use cache mounts for mod cache, build cache, and temp dir to avoid filling container layer
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/gocache \
    --mount=type=cache,target=/gotmp \
    GOCACHE=/gocache GOTMPDIR=/gotmp \
    CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /fitflow-api ./cmd/api

# Run stage
FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata wget

WORKDIR /app

COPY --from=builder /fitflow-api .
COPY migrations ./migrations

EXPOSE 8080

ENTRYPOINT ["./fitflow-api"]
