-- Remove seeded exercises

DELETE FROM exercises WHERE name IN (
  'Bench Press', 'Incline Bench Press', 'Dumbbell Flyes', 'Push-Ups', 'Cable Crossover',
  'Deadlift', 'Pull-Ups', 'Barbell Row', 'Lat Pulldown', 'T-Bar Row',
  'Overhead Press', 'Lateral Raise', 'Front Raise', 'Face Pull', 'Arnold Press',
  'Squat', 'Leg Press', 'Romanian Deadlift', 'Leg Curl', 'Leg Extension',
  'Calf Raise', 'Lunges',
  'Barbell Curl', 'Tricep Pushdown', 'Hammer Curl', 'Overhead Tricep Extension',
  'Preacher Curl', 'Skull Crushers',
  'Plank', 'Cable Crunch', 'Hanging Leg Raise', 'Russian Twist'
);
