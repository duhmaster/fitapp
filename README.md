# FITFLOW API

Go API for the FITFLOW fitness app: auth, users, gyms, workouts, progress, social, blog, trainer, notifications.

## Prerequisites

- Go 1.23+
- PostgreSQL 16+
- Redis 7+

## Quick run (full stack + Flutter web)

From the project root, rebuild and run API + Postgres + Redis in Docker, apply migrations, then start the Flutter web app and open it in Chrome:

```bash
./scripts/run-all-web.sh
```

Requires: Docker (Compose), Flutter in PATH. Optional: `migrate` CLI (otherwise the script runs migrations via a one-off container).

## Setup

1. Copy env and set DB/Redis/JWT:

   ```bash
   cp .env.example .env
   # Edit .env: DB_PASSWORD, JWT_SECRET, etc.
   ```

2. Create DB and run migrations:

   ```bash
   # Create database (or use your own method)
   createdb fitflow

   # Migrate (install: go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest)
   migrate -path ./migrations -database "postgres://USER:PASS@localhost:5432/fitflow?sslmode=disable" up
   ```

3. Run the API:

   ```bash
   go run ./cmd/api
   ```

   Health: [http://localhost:8080/health](http://localhost:8080/health), version: [http://localhost:8080/version](http://localhost:8080/version)

## Makefile

```bash
make build          # build binary
make test           # run tests
make run            # build and run
make lint           # run golangci-lint
make migrate-up     # apply migrations (DSN=... to override)
make docker-up      # start API + Postgres + Redis
make docker-down    # stop stack
make openapi-sync   # copy OpenAPI spec from internal to docs
```

Auth endpoints (login, register, refresh) are rate-limited to 20 requests per minute per IP.

## Docker

Run API + Postgres + Redis with Docker Compose (from this directory):

```bash
docker compose -f deployments/docker/docker-compose.yml up -d
```

Then run migrations (see [deployments/docker/README.md](deployments/docker/README.md)).

For Kubernetes, see [deployments/k8s/README.md](deployments/k8s/README.md).

## API overview

- **Auth** – `POST /api/v1/auth/register`, `login`, `refresh`; `GET /api/v1/me` (JWT)
- **Users** – profile, avatar, metrics (JWT)
- **Gyms** – search, check-in, load/history (public + JWT); admin: create gym
- **Workouts** – exercises, create/list workouts, log sets (JWT)
- **Progress** – weight, body-fat, health metrics (JWT)
- **Social** – follow, friend requests, feed, posts, likes, comments (JWT)
- **Blog** – blog posts, photos, tags (JWT + public list/get)
- **Trainer** – clients, programs, comments (JWT)
- **Notifications** – list, get, mark read (JWT)

Protected routes require header: `Authorization: Bearer <access_token>`. Responses include `X-Request-Id` for tracing. **CORS:** in development, all origins are allowed by default; otherwise set `CORS_ALLOWED_ORIGINS` (see [docs/CORS.md](docs/CORS.md)). API requests have a 30s context timeout.

OpenAPI 3 spec: [GET /openapi.yaml](http://localhost:8080/openapi.yaml) when the API is running; source `internal/delivery/http/spec/openapi.yaml`.

## Project layout

See [docs/FOLDER_STRUCTURE.md](docs/FOLDER_STRUCTURE.md).
