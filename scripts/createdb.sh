# 1. Create DB and run migrations
createdb fitflow
migrate -path ./migrations -database "postgres://fitflow@localhost:5432/fitflow?sslmode=disable" up

# 2. Start PostgreSQL and Redis (e.g. via Docker)
# 3. Run API
go run ./cmd/api