# FITFLOW — Project Folder Structure

```
fitapp/
├── cmd/
│   └── api/                    # API server entrypoint
│
├── internal/
│   ├── auth/                   # Authentication module
│   │   ├── domain/
│   │   ├── usecase/
│   │   ├── repository/
│   │   └── delivery/
│   │
│   ├── user/                   # User profile & metrics
│   │   ├── domain/
│   │   ├── usecase/
│   │   ├── repository/
│   │   └── delivery/
│   │
│   ├── gym/                    # Gym search, check-in, load
│   │   ├── domain/
│   │   ├── usecase/
│   │   ├── repository/
│   │   └── delivery/
│   │
│   ├── workout/                # Workouts, sessions, exercises
│   │   ├── domain/
│   │   ├── usecase/
│   │   ├── repository/
│   │   └── delivery/
│   │
│   ├── progress/               # Aggregations, 1RM, tracking
│   │   ├── domain/
│   │   ├── usecase/
│   │   ├── repository/
│   │   └── delivery/
│   │
│   ├── health/                 # Health metrics, integrations
│   │   ├── domain/
│   │   ├── usecase/
│   │   ├── repository/
│   │   └── delivery/
│   │
│   ├── social/                 # Follow, feed, like, comment
│   │   ├── domain/
│   │   ├── usecase/
│   │   ├── repository/
│   │   └── delivery/
│   │
│   ├── blog/                   # Posts, photos, tags
│   │   ├── domain/
│   │   ├── usecase/
│   │   ├── repository/
│   │   └── delivery/
│   │
│   ├── trainer/                # Trainer-client, programs
│   │   ├── domain/
│   │   ├── usecase/
│   │   ├── repository/
│   │   └── delivery/
│   │
│   ├── notification/           # Pub/Sub, push
│   │   ├── domain/
│   │   ├── usecase/
│   │   ├── repository/
│   │   └── delivery/
│   │
│   ├── config/                 # App configuration
│   ├── pkg/                    # Shared internal packages
│   ├── delivery/
│   │   └── middleware/         # HTTP middleware (auth, RBAC, rate limit)
│   ├── events/                 # Internal event bus
│   └── workers/                # Background jobs
│
├── migrations/                 # SQL migrations
├── deployments/
│   ├── docker/                 # Dockerfile, docker-compose
│   └── k8s/                    # Kubernetes manifests
├── docs/                       # OpenAPI, ER diagram, docs
├── mobile/                     # Flutter app (step 19)
│
├── go.mod
├── go.sum
└── README.md
```
