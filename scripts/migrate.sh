#```bash
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
#```

## Usage

#```bash
# Apply all migrations
migrate -path ./migrations -database "postgres://user:pass@localhost:5432/fitflow?sslmode=disable" up

# Rollback last migration
#migrate -path ./migrations -database "postgres://user:pass@localhost:5432/fitflow?sslmode=disable" down 1

# Rollback all
#migrate -path ./migrations -database "postgres://user:pass@localhost:5432/fitflow?sslmode=disable" down

# Check version
#migrate -path ./migrations -database "postgres://user:pass@localhost:5432/fitflow?sslmode=disable" version