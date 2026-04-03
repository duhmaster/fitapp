-- Remove trailing " мышца" from muscle catalog names and from muscle_loads JSON keys on exercises.
-- Examples: "Ноги мышца" -> "Ноги", "Функциональные мышца" -> "Функциональные"

UPDATE muscles
SET name = regexp_replace(name, ' мышца$', '')
WHERE name ~ ' мышца$';

UPDATE exercises e
SET muscle_loads = (
  SELECT COALESCE(
    jsonb_object_agg(regexp_replace(t.key, ' мышца$', ''), t.value),
    '{}'::jsonb
  )
  FROM jsonb_each(e.muscle_loads) AS t
)
WHERE e.muscle_loads IS NOT NULL
  AND jsonb_typeof(e.muscle_loads) = 'object'
  AND e.muscle_loads <> '{}'::jsonb;
