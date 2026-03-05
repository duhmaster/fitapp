-- Rollback seed fitness data (run after 000012, 000011 for full schema rollback)
DELETE FROM program_exercises;
DELETE FROM programs;
DELETE FROM exercise_muscles;
DELETE FROM muscles;
