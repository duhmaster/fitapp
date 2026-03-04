# FITFLOW API – common targets
# Usage: make build | test | run | migrate-up | docker-up | ...

BINARY_NAME = fitflow-api
MIGRATIONS_PATH = ./migrations
# Override with: make migrate-up DSN="postgres://..."
DSN ?= postgres://fitflow:fitflow@localhost:5432/fitflow?sslmode=disable

.PHONY: build test run clean lint migrate-up migrate-down migrate-version docker-up docker-down docker-build

build:
	go build -o $(BINARY_NAME) ./cmd/api

test:
	go test ./...

test-short:
	go test -short ./...

lint:
	golangci-lint run ./...

run: build
	./$(BINARY_NAME)

clean:
	rm -f $(BINARY_NAME)

migrate-up:
	migrate -path $(MIGRATIONS_PATH) -database "$(DSN)" up

migrate-down:
	migrate -path $(MIGRATIONS_PATH) -database "$(DSN)" down 1

migrate-version:
	migrate -path $(MIGRATIONS_PATH) -database "$(DSN)" version

docker-build:
	docker build -t fitflow-api:latest -f deployments/docker/Dockerfile .

docker-up:
	docker compose -f deployments/docker/docker-compose.yml up -d

docker-down:
	docker compose -f deployments/docker/docker-compose.yml down

docker-logs:
	docker compose -f deployments/docker/docker-compose.yml logs -f api
