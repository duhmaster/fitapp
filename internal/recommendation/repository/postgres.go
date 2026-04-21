package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"time"

	recdomain "github.com/fitflow/fitflow/internal/recommendation/domain"
	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PG struct {
	pool *pgxpool.Pool
}

func NewPG(pool *pgxpool.Pool) *PG {
	return &PG{pool: pool}
}

type outboxPayload struct {
	SessionQuality   int16    `json:"session_quality"`
	OverallWellbeing int16    `json:"overall_wellbeing"`
	Fatigue          int16    `json:"fatigue"`
	MuscleSoreness   *int16   `json:"muscle_soreness,omitempty"`
	PainDiscomfort   *int16   `json:"pain_discomfort,omitempty"`
	StressLevel      *int16   `json:"stress_level,omitempty"`
	SleepHours       *float64 `json:"sleep_hours,omitempty"`
	SleepQuality     *int16   `json:"sleep_quality,omitempty"`
}

func (r *PG) EnqueueWorkoutFeedback(ctx context.Context, userID, workoutID uuid.UUID, feedback *workoutdomain.WorkoutFeedback) error {
	p := outboxPayload{
		SessionQuality:   feedback.SessionQuality,
		OverallWellbeing: feedback.OverallWellbeing,
		Fatigue:          feedback.Fatigue,
		MuscleSoreness:   feedback.MuscleSoreness,
		PainDiscomfort:   feedback.PainDiscomfort,
		StressLevel:      feedback.StressLevel,
		SleepHours:       feedback.SleepHours,
		SleepQuality:     feedback.SleepQuality,
	}
	raw, err := json.Marshal(p)
	if err != nil {
		return err
	}
	_, err = r.pool.Exec(ctx, `
		INSERT INTO recommendation_outbox (user_id, workout_id, event_type, payload)
		VALUES ($1, $2, 'workout_feedback', $3::jsonb)
	`, userID, workoutID, raw)
	return err
}

func (r *PG) ProcessOutbox(ctx context.Context, limit int) (int, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	tx, err := r.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx)

	rows, err := tx.Query(ctx, `
		SELECT id, user_id, workout_id, payload
		FROM recommendation_outbox
		WHERE processed_at IS NULL AND event_type = 'workout_feedback'
		ORDER BY created_at ASC
		FOR UPDATE SKIP LOCKED
		LIMIT $1
	`, limit)
	if err != nil {
		return 0, err
	}
	defer rows.Close()

	type item struct {
		id        uuid.UUID
		userID    uuid.UUID
		workoutID uuid.UUID
		payload   []byte
	}
	items := make([]item, 0, limit)
	for rows.Next() {
		var it item
		if err := rows.Scan(&it.id, &it.userID, &it.workoutID, &it.payload); err != nil {
			return 0, err
		}
		items = append(items, it)
	}
	if err := rows.Err(); err != nil {
		return 0, err
	}

	processed := 0
	for _, it := range items {
		var p outboxPayload
		if err := json.Unmarshal(it.payload, &p); err == nil {
			recs := applyRules(it.userID, it.workoutID, p)
			for _, rec := range recs {
				if err := upsertRecommendation(ctx, tx, rec); err != nil {
					continue
				}
			}
		}
		if _, err := tx.Exec(ctx, `UPDATE recommendation_outbox SET processed_at = NOW() WHERE id = $1`, it.id); err != nil {
			return processed, err
		}
		processed++
	}
	if err := tx.Commit(ctx); err != nil {
		return processed, err
	}
	return processed, nil
}

func (r *PG) ListByUserID(ctx context.Context, userID uuid.UUID, limit int) ([]*recdomain.Recommendation, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, user_id, workout_id, rec_type, severity, title, message, payload, rule_version, created_at, expires_at, read_at
		FROM workout_recommendations
		WHERE user_id = $1
		  AND (expires_at IS NULL OR expires_at > NOW())
		ORDER BY created_at DESC
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]*recdomain.Recommendation, 0, limit)
	for rows.Next() {
		var rec recdomain.Recommendation
		var recType, severity, ruleVersion string
		var payload []byte
		if err := rows.Scan(
			&rec.ID, &rec.UserID, &rec.WorkoutID, &recType, &severity, &rec.Title, &rec.Message, &payload,
			&ruleVersion, &rec.CreatedAt, &rec.ExpiresAt, &rec.ReadAt,
		); err != nil {
			return nil, err
		}
		rec.Type = recdomain.RecommendationType(recType)
		rec.Severity = recdomain.Severity(severity)
		rec.RuleVersion = ruleVersion
		if len(payload) > 0 {
			_ = json.Unmarshal(payload, &rec.Payload)
		}
		if rec.Payload == nil {
			rec.Payload = map[string]any{}
		}
		out = append(out, &rec)
	}
	return out, rows.Err()
}

func upsertRecommendation(ctx context.Context, tx pgx.Tx, rec *recdomain.Recommendation) error {
	raw, err := json.Marshal(rec.Payload)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO workout_recommendations (
			user_id, workout_id, rec_type, severity, title, message, payload, rule_version, expires_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8, $9)
		ON CONFLICT (workout_id, rec_type, rule_version)
		DO UPDATE
		  SET severity = EXCLUDED.severity,
		      title = EXCLUDED.title,
		      message = EXCLUDED.message,
		      payload = EXCLUDED.payload,
		      expires_at = EXCLUDED.expires_at
	`, rec.UserID, rec.WorkoutID, string(rec.Type), string(rec.Severity), rec.Title, rec.Message, raw, rec.RuleVersion, rec.ExpiresAt)
	return err
}

func applyRules(userID, workoutID uuid.UUID, p outboxPayload) []*recdomain.Recommendation {
	out := make([]*recdomain.Recommendation, 0, 4)
	now := time.Now().UTC()
	expires := now.Add(72 * time.Hour)
	ruleVersion := "v1"

	// Very high fatigue or pain means reduced load for the next workout.
	if p.Fatigue >= 8 || (p.PainDiscomfort != nil && *p.PainDiscomfort >= 7) {
		out = append(out, &recdomain.Recommendation{
			UserID:      userID,
			WorkoutID:   workoutID,
			Type:        recdomain.RecommendationTypeLoadAdjust,
			Severity:    recdomain.SeverityWarning,
			Title:       "Снизьте нагрузку на следующей тренировке",
			Message:     "Уменьшите рабочий вес/объем на 10-20% и сократите подходы до техники без отказа.",
			Payload:     map[string]any{"suggested_delta_percent": -15, "fatigue": p.Fatigue},
			RuleVersion: ruleVersion,
			ExpiresAt:   &expires,
		})
	} else if p.Fatigue <= 4 && p.SessionQuality >= 4 && p.OverallWellbeing >= 4 {
		out = append(out, &recdomain.Recommendation{
			UserID:      userID,
			WorkoutID:   workoutID,
			Type:        recdomain.RecommendationTypeLoadAdjust,
			Severity:    recdomain.SeverityInfo,
			Title:       "Можно немного повысить нагрузку",
			Message:     "Попробуйте увеличить вес на 2.5-5% или добавить один рабочий подход в ключевых упражнениях.",
			Payload:     map[string]any{"suggested_delta_percent": 4, "readiness": "good"},
			RuleVersion: ruleVersion,
			ExpiresAt:   &expires,
		})
	}

	if (p.SleepHours != nil && *p.SleepHours < 6.0) || (p.SleepQuality != nil && *p.SleepQuality <= 2) {
		sleepHours := 0.0
		if p.SleepHours != nil {
			sleepHours = math.Round(*p.SleepHours*10) / 10
		}
		out = append(out, &recdomain.Recommendation{
			UserID:      userID,
			WorkoutID:   workoutID,
			Type:        recdomain.RecommendationTypeSleepRecovery,
			Severity:    recdomain.SeverityWarning,
			Title:       "Фокус на восстановление и сон",
			Message:     "Сегодня приоритет: 7-9 часов сна, легкая активность и достаточная гидратация.",
			Payload:     map[string]any{"sleep_hours": sleepHours, "sleep_quality": p.SleepQuality},
			RuleVersion: ruleVersion,
			ExpiresAt:   &expires,
		})
	}

	if p.OverallWellbeing <= 2 || (p.PainDiscomfort != nil && *p.PainDiscomfort >= 8) {
		out = append(out, &recdomain.Recommendation{
			UserID:      userID,
			WorkoutID:   workoutID,
			Type:        recdomain.RecommendationTypeWellbeing,
			Severity:    recdomain.SeverityCritical,
			Title:       "Низкое самочувствие - снизьте интенсивность",
			Message:     "Если симптомы сохраняются 24-48 часов, сделайте паузу и обратитесь к специалисту.",
			Payload:     map[string]any{"wellbeing": p.OverallWellbeing, "pain": p.PainDiscomfort},
			RuleVersion: ruleVersion,
			ExpiresAt:   &expires,
		})
	}

	if p.SessionQuality <= 3 {
		out = append(out, &recdomain.Recommendation{
			UserID:      userID,
			WorkoutID:   workoutID,
			Type:        recdomain.RecommendationTypeNextSession,
			Severity:    recdomain.SeverityInfo,
			Title:       "Сделайте следующую тренировку проще",
			Message:     "Сфокусируйтесь на технике, разминке и умеренном объеме без выхода в отказ.",
			Payload:     map[string]any{"session_quality": p.SessionQuality},
			RuleVersion: ruleVersion,
			ExpiresAt:   &expires,
		})
	}

	if len(out) == 0 {
		out = append(out, &recdomain.Recommendation{
			UserID:      userID,
			WorkoutID:   workoutID,
			Type:        recdomain.RecommendationTypeGeneralTip,
			Severity:    recdomain.SeverityInfo,
			Title:       "Продолжайте в том же духе",
			Message:     "Держите текущий режим, соблюдайте питание и сон для стабильного прогресса.",
			Payload:     map[string]any{"source": "default"},
			RuleVersion: ruleVersion,
			ExpiresAt:   &expires,
		})
	}

	return out
}

func (r *PG) String() string {
	return fmt.Sprintf("recommendation.PG")
}
