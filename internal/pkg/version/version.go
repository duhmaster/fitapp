package version

// Version is set at build time via ldflags, e.g.:
//   go build -ldflags "-X github.com/fitflow/fitflow/internal/pkg/version.Version=1.0.0"
var Version = "dev"
