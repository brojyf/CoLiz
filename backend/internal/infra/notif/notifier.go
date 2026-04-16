package notif

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/brojyf/CoLiz/internal/domain"
	"github.com/brojyf/CoLiz/internal/repo/device"
	"github.com/brojyf/CoLiz/internal/util/logx"
)

// Notifier sends push notifications for key domain events.
// All public methods are safe to call in a goroutine (fire-and-forget).
// If apns is nil the Notifier is a no-op.
type Notifier struct {
	apns       *APNSClient
	deviceRepo device.Repo
	db         *sql.DB
}

func NewNotifier(apns *APNSClient, deviceRepo device.Repo, db *sql.DB) *Notifier {
	return &Notifier{apns: apns, deviceRepo: deviceRepo, db: db}
}

// NewNoopNotifier returns a Notifier that silently discards all events.
func NewNoopNotifier() *Notifier {
	return &Notifier{}
}

const notifTimeout = 5 * time.Second

// NotifyTodoCreated notifies all group members (except the creator) about a new todo.
func (n *Notifier) NotifyTodoCreated(todo *domain.Todo) {
	if n.apns == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), notifTimeout)
	defer cancel()

	memberIDs, err := n.groupMemberIDs(ctx, todo.GroupID, todo.CreatedBy)
	if err != nil {
		logx.Error(ctx, "notif.todo_created.members", err)
		return
	}
	if len(memberIDs) == 0 {
		return
	}

	tokens, err := n.deviceRepo.GetByUserIDs(ctx, memberIDs)
	if err != nil {
		logx.Error(ctx, "notif.todo_created.tokens", err)
		return
	}

	actorName := n.usernameOrDefault(ctx, todo.CreatedBy)

	for _, dt := range tokens {
		if err := n.apns.Send(ctx, dt.Token,
			"New task added",
			fmt.Sprintf("%s: %s", actorName, todo.Message),
			"todo.created",
			map[string]string{"group_id": todo.GroupID},
		); err != nil {
			logx.Error(ctx, "notif.todo_created.send", fmt.Errorf("user=%s %w", dt.UserID, err))
		}
	}
}

// NotifyExpenseCreated notifies group members about a new expense.
func (n *Notifier) NotifyExpenseCreated(expense *domain.Expense) {
	if n.apns == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), notifTimeout)
	defer cancel()

	memberIDs, err := n.groupMemberIDs(ctx, expense.GroupID, expense.CreatedBy)
	if err != nil {
		logx.Error(ctx, "notif.expense_created.members", err)
		return
	}
	if len(memberIDs) == 0 {
		return
	}

	tokens, err := n.deviceRepo.GetByUserIDs(ctx, memberIDs)
	if err != nil {
		logx.Error(ctx, "notif.expense_created.tokens", err)
		return
	}

	actorName := n.usernameOrDefault(ctx, expense.CreatedBy)

	for _, dt := range tokens {
		if err := n.apns.Send(ctx, dt.Token,
			"New expense added",
			fmt.Sprintf("%s added: %s (%s)", actorName, expense.Name, expense.Amount),
			"expense.created",
			map[string]string{"group_id": expense.GroupID},
		); err != nil {
			logx.Error(ctx, "notif.expense_created.send", fmt.Errorf("user=%s %w", dt.UserID, err))
		}
	}
}

// NotifyExpenseUpdated notifies group members that an expense was updated.
func (n *Notifier) NotifyExpenseUpdated(expense *domain.Expense, actorID string) {
	if n.apns == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), notifTimeout)
	defer cancel()

	memberIDs, err := n.groupMemberIDs(ctx, expense.GroupID, actorID)
	if err != nil {
		logx.Error(ctx, "notif.expense_updated.members", err)
		return
	}
	if len(memberIDs) == 0 {
		return
	}

	tokens, err := n.deviceRepo.GetByUserIDs(ctx, memberIDs)
	if err != nil {
		logx.Error(ctx, "notif.expense_updated.tokens", err)
		return
	}

	actorName := n.usernameOrDefault(ctx, actorID)

	for _, dt := range tokens {
		if err := n.apns.Send(ctx, dt.Token,
			"Expense updated",
			fmt.Sprintf("%s updated: %s (%s)", actorName, expense.Name, expense.Amount),
			"expense.updated",
			map[string]string{"group_id": expense.GroupID},
		); err != nil {
			logx.Error(ctx, "notif.expense_updated.send", fmt.Errorf("user=%s %w", dt.UserID, err))
		}
	}
}

// NotifyTodoUpdated notifies group members that a todo was updated or marked.
func (n *Notifier) NotifyTodoUpdated(todo *domain.Todo, actorID string) {
	if n.apns == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), notifTimeout)
	defer cancel()

	memberIDs, err := n.groupMemberIDs(ctx, todo.GroupID, actorID)
	if err != nil {
		logx.Error(ctx, "notif.todo_updated.members", err)
		return
	}
	if len(memberIDs) == 0 {
		return
	}

	tokens, err := n.deviceRepo.GetByUserIDs(ctx, memberIDs)
	if err != nil {
		logx.Error(ctx, "notif.todo_updated.tokens", err)
		return
	}

	actorName := n.usernameOrDefault(ctx, actorID)
	body := fmt.Sprintf("%s updated: %s", actorName, todo.Message)
	if todo.Done {
		body = fmt.Sprintf("%s completed: %s", actorName, todo.Message)
	}

	for _, dt := range tokens {
		if err := n.apns.Send(ctx, dt.Token,
			"Task updated",
			body,
			"todo.updated",
			map[string]string{"group_id": todo.GroupID},
		); err != nil {
			logx.Error(ctx, "notif.todo_updated.send", fmt.Errorf("user=%s %w", dt.UserID, err))
		}
	}
}

// NotifyFriendRequest notifies the recipient of a new friend request.
func (n *Notifier) NotifyFriendRequest(req *domain.FriendRequest) {
	if n.apns == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), notifTimeout)
	defer cancel()

	tokens, err := n.deviceRepo.GetByUserIDs(ctx, []string{req.To})
	if err != nil {
		logx.Error(ctx, "notif.friend_req.tokens", err)
		return
	}

	actorName := n.usernameOrDefault(ctx, req.From)

	for _, dt := range tokens {
		if err := n.apns.Send(ctx, dt.Token,
			"Friend request",
			fmt.Sprintf("%s wants to be your friend", actorName),
			"friend_request.sent",
			nil,
		); err != nil {
			logx.Error(ctx, "notif.friend_req.send", fmt.Errorf("user=%s %w", dt.UserID, err))
		}
	}
}

// NotifyGroupInvited notifies the invitee about a group invitation.
func (n *Notifier) NotifyGroupInvited(groupID, inviterID, inviteeID string) {
	if n.apns == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), notifTimeout)
	defer cancel()

	tokens, err := n.deviceRepo.GetByUserIDs(ctx, []string{inviteeID})
	if err != nil {
		logx.Error(ctx, "notif.group_invited.tokens", err)
		return
	}

	inviterName := n.usernameOrDefault(ctx, inviterID)
	groupName := n.groupNameOrDefault(ctx, groupID)

	for _, dt := range tokens {
		if err := n.apns.Send(ctx, dt.Token,
			"Group invitation",
			fmt.Sprintf("%s invited you to join %s", inviterName, groupName),
			"group.invited",
			map[string]string{"group_id": groupID},
		); err != nil {
			logx.Error(ctx, "notif.group_invited.send", fmt.Errorf("user=%s %w", dt.UserID, err))
		}
	}
}

// DB helpers

func (n *Notifier) groupMemberIDs(ctx context.Context, groupID, excludeUID string) ([]string, error) {
	rows, err := n.db.QueryContext(ctx,
		`SELECT user_id FROM group_members WHERE group_id = ? AND user_id != ?`,
		groupID, excludeUID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

func (n *Notifier) usernameOrDefault(ctx context.Context, userID string) string {
	var name string
	if err := n.db.QueryRowContext(ctx,
		`SELECT username FROM users WHERE user_id = ?`, userID,
	).Scan(&name); err != nil {
		return "Someone"
	}
	return name
}

func (n *Notifier) groupNameOrDefault(ctx context.Context, groupID string) string {
	var name string
	if err := n.db.QueryRowContext(ctx,
		"SELECT `name` FROM `groups` WHERE id = ?", groupID,
	).Scan(&name); err != nil {
		return "a group"
	}
	return name
}
