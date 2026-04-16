package http

import (
	"github.com/brojyf/CoLiz/internal/http/handler"
	"github.com/gin-gonic/gin"
)

func RegisterRouter(r *gin.Engine, m func(*gin.Context), h *handler.Handlers) *gin.Engine {
	api := r.Group("/api")
	api.GET("/ping", h.Auth.Ping)

	auth := api.Group("/auth")
	auth.POST("/request-otp", h.Auth.RequestOTP)
	auth.POST("/verify-otp", h.Auth.VerifyOTP)
	auth.POST("/register", h.Auth.Register)
	auth.POST("/reset-password", h.Auth.ResetPassword)
	auth.POST("/login", h.Auth.Login)
	auth.POST("/logout", m, h.Auth.Logout)
	auth.POST("/refresh", h.Auth.Refresh)
	auth.POST("/change-password", m, h.Auth.ChangePassword)

	users := api.Group("/users")
	users.GET("/:user_id/avatar", h.User.GetAvatar)
	users.Use(m)
	users.GET("/me", h.User.GetMe)
	users.PATCH("/me", h.User.UpdateUsername)
	users.GET("/search", h.User.SearchByEmail)
	users.PUT("/me/avatar", h.User.UploadAvatar)
	users.POST("/me/device-token", h.User.UpsertDeviceToken)

	friend := api.Group("/friends")
	friend.Use(m)
	friend.GET("", h.Friend.List)
	friend.GET("/:uid", h.Friend.GetByUID)
	friend.DELETE("/:uid", h.Friend.Delete)

	friendReq := api.Group("/friend-requests")
	friendReq.Use(m)
	friendReq.GET("", h.Friend.ListRequests)
	friendReq.POST("", h.Friend.SendRequest)
	friendReq.POST("/:request_id/accept", h.Friend.AcceptRequest)
	friendReq.POST("/:request_id/decline", h.Friend.DeclineRequest)
	friendReq.POST("/:request_id/cancel", h.Friend.CancelRequest)

	group := api.Group("/groups")
	group.GET("/:group_id/avatar", h.Group.GetAvatar)
	group.Use(m)

	// Group info & management
	group.GET("", h.Group.List)
	group.POST("", h.Group.Create)
	group.GET("/:group_id", h.Group.GetDetail)
	group.PATCH("/:group_id", h.Group.Update)
	group.DELETE("/:group_id", h.Group.Delete)
	group.GET("/:group_id/members", h.Group.GetMembers)
	group.POST("/:group_id/invite", h.Group.Invite)
	group.POST("/:group_id/leave", h.Group.Leave)
	group.DELETE("/:group_id/members/:uid", h.Group.RemoveMember)
	group.PUT("/:group_id/avatar", h.Group.UploadAvatar)
	// todos in group
	group.GET("/:group_id/todos", h.Todo.GetGroup)
	group.POST("/:group_id/todos", h.Todo.Create)
	// expenses in group
	group.GET("/:group_id/expenses", h.Expense.GetByGroup)
	group.POST("/:group_id/expenses", h.Expense.Create)
	group.GET("/:group_id/balance", h.Expense.GetBalance)
	group.GET("/:group_id/transactions/plan", h.Expense.GetTransactionPlan)
	group.POST("/:group_id/transactions/apply", h.Expense.ApplyTransactionPlan)
	group.POST("/:group_id/transaction", h.Expense.CreateTransaction)

	todo := api.Group("/todos")
	todo.Use(m)
	todo.GET("", h.Todo.GetAll)
	todo.GET("/:todo_id", h.Todo.GetDetail)
	todo.PATCH("/:todo_id", h.Todo.Update)
	todo.PATCH("/:todo_id/mark", h.Todo.Mark)
	todo.DELETE("/:todo_id", h.Todo.Delete)

	expense := api.Group("/expenses")
	expense.Use(m)
	expense.GET("/overview", h.Expense.GetOverview)
	expense.GET("/:expense_id", h.Expense.GetDetail) // TODO
	expense.PATCH("/:expense_id", h.Expense.Update)  // TODO
	expense.DELETE("/:expense_id", h.Expense.Delete) // TODO

	return r
}
