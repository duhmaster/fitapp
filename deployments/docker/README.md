# Docker

Run the API with Postgres and Redis:

```bash
# From project root (directory containing go.mod)
docker compose -f deployments/docker/docker-compose.yml up -d
```

Apply migrations (one-time or after adding new migrations):

```bash
# Install migrate CLI: go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
migrate -path ./migrations -database "postgres://fitflow:fitflow@localhost:5432/fitflow?sslmode=disable" up
```

Or run migrate in a one-off container:

```bash
docker run --rm --network host -v "$(pwd)/migrations:/migrations" migrate/migrate -path /migrations -database "postgres://fitflow:fitflow@localhost:5432/fitflow?sslmode=disable" up
```

- API: http://localhost:8080
- Health: http://localhost:8080/health
- Postgres: localhost:5432 (user `fitflow`, password `fitflow`, db `fitflow`)
- Redis: localhost:6379

### pgAdmin (optional)

To run Postgres + Redis + API + **pgAdmin**:

```bash
docker compose -f deployments/docker/docker-compose.yml --profile tools up -d
```

- pgAdmin: http://localhost:5050
- Login: **Email** `admin@fitflow.local`, **Password** `admin`

**Add server in pgAdmin:**
1. Right-click "Servers" → Register → Server
2. **General** tab: Name = `fitflow` (any label)
3. **Connection** tab:
   - Host: `postgres` (when using from host machine use `localhost`)
   - Port: `5432`
   - Maintenance database: `fitflow`
   - Username: `fitflow`
   - Password: `fitflow`
4. Save

If pgAdmin runs in Docker and Postgres is in the same compose, use host `postgres`. If you open pgAdmin in browser and add server from your machine, use host `localhost`.

### If Docker build runs out of disk space

Build the binary on the host (needs Go installed), then build a runtime-only image:

```bash
# From project root
CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o fitflow-api ./cmd/api
docker build -f deployments/docker/Dockerfile.runtime -t fitflow-api .
```

Then start the stack using the pre-built image (no build in Docker):

```bash
docker compose -f deployments/docker/docker-compose.yml -f deployments/docker/docker-compose.runtime.yml up -d
```

Also free disk space: `docker system prune -a` and `docker builder prune -a`.
