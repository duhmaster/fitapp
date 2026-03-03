package logger

import (
	"io"
	"os"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

// New creates a zerolog logger with appropriate config for the environment.
// Development: human-readable console output.
// Production: JSON output for log aggregators.
func New(env string) zerolog.Logger {
	var output io.Writer = os.Stdout

	if env == "development" {
		output = zerolog.ConsoleWriter{Out: os.Stdout}
	}

	return zerolog.New(output).
		With().
		Timestamp().
		Logger()
}

// SetGlobal assigns the logger as the global zerolog logger.
func SetGlobal(l zerolog.Logger) {
	log.Logger = l
}
