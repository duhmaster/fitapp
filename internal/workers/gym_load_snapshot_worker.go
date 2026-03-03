package workers

import (
	"context"
	"time"

	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
	gymusecase "github.com/fitflow/fitflow/internal/gym/usecase"
	"github.com/google/uuid"
	"github.com/rs/zerolog"
)

// GymLoadSnapshotWorker periodically snapshots gym realtime load into Postgres hourly buckets.
type GymLoadSnapshotWorker struct {
	log       zerolog.Logger
	gyms      gymdomain.GymRepository
	snapshots gymdomain.LoadSnapshotRepository
	load      gymusecase.LoadService

	interval  time.Duration
	batchSize int
}

func NewGymLoadSnapshotWorker(
	log zerolog.Logger,
	gyms gymdomain.GymRepository,
	snapshots gymdomain.LoadSnapshotRepository,
	load gymusecase.LoadService,
	interval time.Duration,
	batchSize int,
) *GymLoadSnapshotWorker {
	if interval <= 0 {
		interval = 5 * time.Minute
	}
	if batchSize <= 0 {
		batchSize = 1000
	}
	return &GymLoadSnapshotWorker{
		log:       log,
		gyms:      gyms,
		snapshots: snapshots,
		load:      load,
		interval:  interval,
		batchSize: batchSize,
	}
}

func (w *GymLoadSnapshotWorker) Run(ctx context.Context) {
	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	w.log.Info().Dur("interval", w.interval).Int("batch_size", w.batchSize).Msg("gym load snapshot worker started")
	defer w.log.Info().Msg("gym load snapshot worker stopped")

	// Run immediately once, then on ticker.
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

func (w *GymLoadSnapshotWorker) runOnce(ctx context.Context) {
	if w.load == nil {
		return
	}

	now := time.Now()
	hourBucket := now.UTC().Truncate(time.Hour)
	after := uuid.Nil

	for {
		select {
		case <-ctx.Done():
			return
		default:
		}

		ids, err := w.gyms.ListIDsAfter(ctx, after, w.batchSize)
		if err != nil {
			w.log.Error().Err(err).Msg("snapshot: list gyms failed")
			return
		}
		if len(ids) == 0 {
			return
		}

		for _, id := range ids {
			load, err := w.load.GetLoad(ctx, id, now)
			if err != nil {
				w.log.Error().Err(err).Str("gym_id", id.String()).Msg("snapshot: get load failed")
				continue
			}
			if err := w.snapshots.UpsertHour(ctx, id, hourBucket, load); err != nil {
				w.log.Error().Err(err).Str("gym_id", id.String()).Msg("snapshot: upsert failed")
				continue
			}
			after = id
		}
	}
}

