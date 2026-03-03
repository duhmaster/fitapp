DROP INDEX IF EXISTS idx_comments_created_at;
DROP INDEX IF EXISTS idx_comments_target;
DROP INDEX IF EXISTS idx_comments_user_id;
DROP INDEX IF EXISTS idx_likes_target;
DROP INDEX IF EXISTS idx_likes_user_id;
DROP INDEX IF EXISTS idx_posts_created_at;
DROP INDEX IF EXISTS idx_posts_user_id;
DROP INDEX IF EXISTS idx_friend_requests_to;
DROP INDEX IF EXISTS idx_friend_requests_from;
DROP INDEX IF EXISTS idx_follows_following;
DROP INDEX IF EXISTS idx_follows_follower;

DROP TABLE IF EXISTS comments;
DROP TABLE IF EXISTS likes;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS friend_requests;
DROP TABLE IF EXISTS follows;
