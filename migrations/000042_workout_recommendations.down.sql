DROP INDEX IF EXISTS idx_recommendation_outbox_pending;
DROP TABLE IF EXISTS recommendation_outbox;

DROP INDEX IF EXISTS idx_workout_recommendations_expires;
DROP INDEX IF EXISTS idx_workout_recommendations_user_unread;
DROP INDEX IF EXISTS idx_workout_recommendations_user_created;
DROP TABLE IF EXISTS workout_recommendations;
