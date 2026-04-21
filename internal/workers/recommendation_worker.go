package workers

import (
	"context"
	"time"

	recdomain "github.com/fitflow/fitflow/internal/recommendation/domain"
	"github.com/rs/zerolog"
)

type RecommendationWorker struct {
	log      zerolog.Logger
	repo     recdomain.Repository
	interval time.Duration
	batch    int
}

func NewRecommendationWorker(log zerolog.Logger, repo recdomain.Repository, interval time.Duration, batch int) *RecommendationWorker {
	if interval <= 0 {
		interval = 20 * time.Second
	}
	if batch <= 0 {
		batch = 50
	}
	return &RecommendationWorker{log: log, repo: repo, interval: interval, batch: batch}
}

func (w *RecommendationWorker) Run(ctx context.Context) {
	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	w.log.Info().Dur("interval", w.interval).Int("batch_size", w.batch).Msg("recommendation worker started")
	defer w.log.Info().Msg("recommendation worker stopped")

	w.runOnce(ctx)
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			w.runOnce(ctx)
		}
	}
}

func (w *RecommendationWorker) runOnce(ctx context.Context) {
	processed, err := w.repo.ProcessOutbox(ctx, w.batch)
	if err != nil {
		w.log.Error().Err(err).Msg("recommendation worker process outbox failed")
		return
	}
	if processed > 0 {
		w.log.Debug().Int("processed", processed).Msg("recommendation worker processed events")
	}
}
