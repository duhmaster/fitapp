-- Best-effort revert: append " мышца" where it is not already present.
-- If you added muscles/keys without this suffix manually, review after rollback.

UPDATE muscles
SET name = name || ' мышца'
WHERE name IS NOT NULL
  AND name <> ''
  AND name !~ ' мышца$';

UPDATE exercises e
SET muscle_loads = (
  SELECT COALESCE(
    jsonb_object_agg(
      CASE
        WHEN t.key ~ ' мышца$' THEN t.key
        ELSE t.key || ' мышца'
      END,
      t.value
    ),
    '{}'::jsonb
  )
  FROM jsonb_each(e.muscle_loads) AS t
)
WHERE e.muscle_loads IS NOT NULL
  AND jsonb_typeof(e.muscle_loads) = 'object'
  AND e.muscle_loads <> '{}'::jsonb;
