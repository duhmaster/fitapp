package admin

import (
	"github.com/gin-gonic/gin"
)

// RegisterRoutes registers admin panel routes on the given router.
// Mount at /admin (e.g. group := router.Group("/admin"); RegisterRoutes(group, handler)).
// Public: GET/POST /admin/login, GET /admin. Protected: rest.
func RegisterRoutes(g *gin.RouterGroup, h *Handler) {
	if h == nil {
		return
	}

	// Public (no auth)
	g.GET("", h.Index)
	g.GET("/login", h.LoginPage)
	g.POST("/login", h.LoginPost)

	// Protected
	admin := g.Group("")
	admin.Use(h.RequireAdmin)
	{
		admin.POST("/logout", h.LogoutPost)
		admin.GET("/dashboard", h.Dashboard)

		// Users
		admin.GET("/entities/users", h.UsersList)
		admin.GET("/entities/users/new", h.UsersNew)
		admin.GET("/entities/users/:id", h.UsersEdit)
		admin.POST("/entities/users/update", h.UsersUpdate)

		// Gyms
		admin.GET("/entities/gyms", h.GymsList)
		admin.GET("/entities/gyms/new", h.GymsNew)
		admin.POST("/entities/gyms/create", h.GymsCreate)
		admin.GET("/entities/gyms/:id", h.GymsEdit)
		admin.POST("/entities/gyms/update", h.GymsUpdate)
		admin.POST("/entities/gyms/delete/:id", h.GymsDelete)

		// Exercises
		admin.GET("/entities/exercises", h.ExercisesList)
		admin.GET("/entities/exercises/new", h.ExercisesNew)
		admin.POST("/entities/exercises/create", h.ExercisesCreate)
		admin.GET("/entities/exercises/:id", h.ExercisesEdit)
		admin.POST("/entities/exercises/update", h.ExercisesUpdate)
		admin.POST("/entities/exercises/delete/:id", h.ExercisesDelete)

		// Programs
		admin.GET("/entities/programs", h.ProgramsList)
		admin.GET("/entities/programs/new", h.ProgramsNew)
		admin.POST("/entities/programs/create", h.ProgramsCreate)
		admin.GET("/entities/programs/:id", h.ProgramsEdit)
		admin.POST("/entities/programs/update", h.ProgramsUpdate)
		admin.POST("/entities/programs/delete/:id", h.ProgramsDelete)

		// Tags
		admin.GET("/entities/tags", h.TagsList)
		admin.GET("/entities/tags/new", h.TagsNew)
		admin.POST("/entities/tags/create", h.TagsCreate)
		admin.POST("/entities/tags/delete/:id", h.TagsDelete)

		// Blog posts
		admin.GET("/entities/blog_posts", h.BlogPostsList)
		admin.GET("/entities/blog_posts/new", h.BlogPostsNew)
		admin.POST("/entities/blog_posts/create", h.BlogPostsCreate)
		admin.GET("/entities/blog_posts/:id", h.BlogPostsEdit)
		admin.POST("/entities/blog_posts/update", h.BlogPostsUpdate)
		admin.POST("/entities/blog_posts/delete/:id", h.BlogPostsDelete)

		// System messages
		admin.GET("/entities/system_messages", h.SystemMessagesList)
		admin.GET("/entities/system_messages/new", h.SystemMessagesNew)
		admin.POST("/entities/system_messages/create", h.SystemMessagesCreate)
		admin.GET("/entities/system_messages/:id", h.SystemMessagesEdit)
		admin.POST("/entities/system_messages/update", h.SystemMessagesUpdate)
		admin.POST("/entities/system_messages/delete/:id", h.SystemMessagesDelete)
	}
}
