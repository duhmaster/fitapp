DROP INDEX IF EXISTS idx_blog_post_tags_tag_id;
DROP INDEX IF EXISTS idx_blog_post_tags_post_id;
DROP INDEX IF EXISTS idx_blog_post_photos_post_id;
DROP INDEX IF EXISTS idx_blog_posts_deleted_at;
DROP INDEX IF EXISTS idx_blog_posts_created_at;
DROP INDEX IF EXISTS idx_blog_posts_user_id;

DROP TABLE IF EXISTS blog_post_tags;
DROP TABLE IF EXISTS blog_post_photos;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS blog_posts;
