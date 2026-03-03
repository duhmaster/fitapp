DROP INDEX IF EXISTS idx_trainer_comments_client_id;
DROP INDEX IF EXISTS idx_trainer_comments_trainer_id;
DROP INDEX IF EXISTS idx_training_programs_client_id;
DROP INDEX IF EXISTS idx_training_programs_trainer_id;
DROP INDEX IF EXISTS idx_trainer_clients_client_id;
DROP INDEX IF EXISTS idx_trainer_clients_trainer_id;

DROP TABLE IF EXISTS trainer_comments;
DROP TABLE IF EXISTS training_programs;
DROP TABLE IF EXISTS trainer_clients;
