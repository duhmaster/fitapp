package admin

import (
	"errors"
	"fmt"
	"html/template"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	billingdomain "github.com/fitflow/fitflow/internal/billing/domain"
	photodomain "github.com/fitflow/fitflow/internal/photo/domain"
	systemmessagedomain "github.com/fitflow/fitflow/internal/systemmessage/domain"
	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

// ListRow is one row in the admin table (ID + cells for display).
type ListRow struct {
	ID    string
	Cells []string
}

// ListData for list template.
type ListData struct {
	Title             string
	Headers           []string
	Rows              []ListRow
	ListPath          string
	NewPath           string
	EditPath          string
	DeletePath        string
	AllowDelete       bool
	SearchQ           string
	FilterValue       string
	FilterPlaceholder string
	HasPrev           bool
	HasNext           bool
	PrevURL           string
	NextURL           string
	PaginationSummary string
	RowAction         string // e.g. Edit, View
}

// Handler for admin panel.
type Handler struct {
	Deps   *Deps
	tmpl   *template.Template
	secret string
}

// NewHandler builds admin handler and parses templates.
func NewHandler(d *Deps) *Handler {
	if d == nil {
		d = &Deps{}
	}
	secret := d.SessionSecret
	if secret == "" {
		secret = d.AdminPassword
	}
	t := template.New("")
	t = template.Must(t.Parse(layoutHTML))
	t = template.Must(t.Parse(loginHTML))
	t = template.Must(t.Parse(dashboardHTML))
	t = template.Must(t.Parse(listHTML))
	t = template.Must(t.Parse(formHTML))
	t = template.Must(t.Parse(viewHTML))
	t = template.Must(t.Parse(uploadFormHTML))
	return &Handler{Deps: d, tmpl: t, secret: secret}
}

// RequireAdmin is middleware that redirects to /admin/login if not authenticated.
func (h *Handler) RequireAdmin(c *gin.Context) {
	if _, ok := validateSession(c.Request, h.secret); ok {
		c.Next()
		return
	}
	c.Redirect(http.StatusFound, "/admin/login")
	c.Abort()
}

// LoginPage renders login form.
func (h *Handler) LoginPage(c *gin.Context) {
	h.renderOK(c, loginHTML, gin.H{"ShowBar": false})
}

// LoginPost handles login and sets session.
func (h *Handler) LoginPost(c *gin.Context) {
	user := c.PostForm("username")
	pass := c.PostForm("password")
	if user != h.Deps.AdminUsername || pass != h.Deps.AdminPassword || pass == "" {
		h.renderOK(c, loginHTML, gin.H{"ShowBar": false, "Flash": "Invalid login or password", "FlashClass": "err"})
		return
	}
	setSession(c.Writer, user, h.secret)
	c.Redirect(http.StatusFound, "/admin/dashboard")
}

// LogoutPost clears session.
func (h *Handler) LogoutPost(c *gin.Context) {
	clearSession(c.Writer)
	c.Redirect(http.StatusFound, "/admin/login")
}

// Dashboard renders dashboard.
func (h *Handler) Dashboard(c *gin.Context) {
	h.renderOK(c, dashboardHTML, gin.H{"ShowBar": true})
}

// GamificationLevelsEdit renders level thresholds editor.
func (h *Handler) GamificationLevelsEdit(c *gin.Context) {
	if h.Deps.GamificationGetLevelThresholds == nil {
		c.String(http.StatusNotImplemented, "gamification levels are not configured")
		return
	}
	thresholds, err := h.Deps.GamificationGetLevelThresholds(c.Request.Context())
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	values := make([]string, 0, len(thresholds))
	for _, v := range thresholds {
		values = append(values, strconv.Itoa(v))
	}
	fields := `<label>XP thresholds</label>
<textarea name="thresholds" rows="6" placeholder="0, 100, 250, 500">` + template.HTMLEscaper(strings.Join(values, ", ")) + `</textarea>
<p class="muted">Comma or newline separated. Must start with 0 and be strictly increasing.</p>`
	h.renderOK(c, formHTML, gin.H{
		"ShowBar":     true,
		"Title":       "Gamification levels",
		"Action":      "/admin/entities/gamification/levels/update",
		"FieldsHTML":  template.HTML(fields),
		"SubmitLabel": "Save",
		"CancelURL":   "/admin/dashboard",
	})
}

// GamificationLevelsUpdate saves thresholds from admin form.
func (h *Handler) GamificationLevelsUpdate(c *gin.Context) {
	if h.Deps.GamificationSetLevelThresholds == nil {
		c.String(http.StatusNotImplemented, "gamification levels are not configured")
		return
	}
	raw := c.PostForm("thresholds")
	raw = strings.ReplaceAll(raw, ";", ",")
	raw = strings.ReplaceAll(raw, "\n", ",")
	parts := strings.Split(raw, ",")
	thresholds := make([]int, 0, len(parts))
	for _, p := range parts {
		s := strings.TrimSpace(p)
		if s == "" {
			continue
		}
		n, err := strconv.Atoi(s)
		if err != nil {
			c.Redirect(http.StatusFound, "/admin/entities/gamification/levels?flash="+url.QueryEscape("Invalid number: "+s))
			return
		}
		thresholds = append(thresholds, n)
	}
	if len(thresholds) < 2 {
		c.Redirect(http.StatusFound, "/admin/entities/gamification/levels?flash="+url.QueryEscape("Provide at least 2 thresholds"))
		return
	}
	if err := h.Deps.GamificationSetLevelThresholds(c.Request.Context(), thresholds); err != nil {
		c.Redirect(http.StatusFound, "/admin/entities/gamification/levels?flash="+url.QueryEscape("Save failed: "+err.Error()))
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/gamification/levels?flash=Updated")
}

// Index redirects /admin to dashboard or login.
func (h *Handler) Index(c *gin.Context) {
	if _, ok := validateSession(c.Request, h.secret); ok {
		c.Redirect(http.StatusFound, "/admin/dashboard")
	} else {
		c.Redirect(http.StatusFound, "/admin/login")
	}
}

func (h *Handler) renderOK(c *gin.Context, bodyTmpl string, data gin.H) {
	if data == nil {
		data = gin.H{}
	}
	data["ShowBar"] = true
	if data["Flash"] == nil && c.Query("flash") != "" {
		data["Flash"] = c.Query("flash")
		data["FlashClass"] = "ok"
	}
	clone, _ := h.tmpl.Clone()
	t := template.Must(clone.Parse(bodyTmpl))
	c.Header("Content-Type", "text/html; charset=utf-8")
	if err := t.Execute(c.Writer, data); err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
}

func (h *Handler) listData(entity, listPath, newPath, editPath, deletePath string, headers []string, rows []ListRow, searchQ string, allowDelete bool, page, limit, offset int, totalCount int, rowAction string) ListData {
	if rowAction == "" {
		rowAction = "Edit"
	}
	prevURL := ""
	nextURL := ""
	qParam := ""
	if searchQ != "" {
		qParam = "&q=" + url.QueryEscape(searchQ)
	}
	if page > 1 {
		prevURL = listPath + "?page=" + strconv.Itoa(page-1) + qParam
	}
	var hasNext bool
	paginationSummary := ""
	if totalCount >= 0 {
		hasNext = offset+len(rows) < totalCount
		if totalCount == 0 {
			paginationSummary = "0 of 0"
		} else if len(rows) == 0 {
			paginationSummary = fmt.Sprintf("0 of %d", totalCount)
		} else {
			paginationSummary = fmt.Sprintf("%d–%d of %d", offset+1, offset+len(rows), totalCount)
		}
	} else {
		hasNext = len(rows) == limit
	}
	if hasNext {
		nextURL = listPath + "?page=" + strconv.Itoa(page+1) + qParam
	}
	return ListData{
		Title:             entity,
		Headers:           headers,
		Rows:              rows,
		ListPath:          listPath,
		NewPath:           newPath,
		EditPath:          editPath,
		DeletePath:        deletePath,
		AllowDelete:       allowDelete,
		SearchQ:           searchQ,
		HasPrev:           page > 1,
		HasNext:           hasNext,
		PrevURL:           prevURL,
		NextURL:           nextURL,
		PaginationSummary: paginationSummary,
		RowAction:         rowAction,
	}
}

const defaultLimit = 20

func pageLimit(c *gin.Context) (page, limit, offset int) {
	page, _ = strconv.Atoi(c.DefaultQuery("page", "1"))
	if page < 1 {
		page = 1
	}
	limit = defaultLimit
	offset = (page - 1) * limit
	return page, limit, offset
}

// --- Users
func (h *Handler) UsersList(c *gin.Context) {
	page, limit, offset := pageLimit(c)
	q := strings.TrimSpace(c.Query("q"))
	list, err := h.Deps.UsersList(c.Request.Context(), limit, offset, q)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	rows := make([]ListRow, 0, len(list))
	for _, u := range list {
		paid := "no"
		if u.PaidSubscriber {
			paid = "yes"
		}
		rows = append(rows, ListRow{
			ID:    u.ID.String(),
			Cells: []string{u.Email, string(u.Role), paid, u.CreatedAt.Format("2006-01-02 15:04")},
		})
	}
	data := h.listData("Users", "/admin/entities/users", "/admin/entities/users/new", "/admin/entities/users", "/admin/entities/users/delete", []string{"Email", "Role", "Paid", "Created"}, rows, q, false, page, limit, offset, -1, "")
	data.FilterPlaceholder = ""
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL, "PaginationSummary": data.PaginationSummary, "RowAction": data.RowAction})
}

func (h *Handler) UsersNew(c *gin.Context) {
	c.Redirect(http.StatusFound, "/admin/entities/users")
}

func (h *Handler) UsersEdit(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	u, err := h.Deps.UsersGet(c.Request.Context(), id)
	if err != nil {
		c.String(http.StatusNotFound, err.Error())
		return
	}
	subExp := ""
	if u.SubscriptionExpiresAt != nil {
		subExp = u.SubscriptionExpiresAt.UTC().Format(time.RFC3339)
	}
	paidChk := ""
	if u.PaidSubscriber {
		paidChk = " checked"
	}
	var coach *billingdomain.CoachSubscriptionInfo
	if h.Deps.CoachSubscriptionGet != nil {
		coach, err = h.Deps.CoachSubscriptionGet(c.Request.Context(), id)
		if err != nil {
			c.String(http.StatusInternalServerError, err.Error())
			return
		}
	}
	coachSel := ""
	coachPeriod := ""
	coachSection := ""
	if h.Deps.CoachSubscriptionSet != nil {
		if coach != nil {
			coachSel = coach.PlanCode
			coachPeriod = coach.CurrentPeriodEnd.UTC().Format(time.RFC3339)
		}
		coachMeta := ""
		if coach != nil {
			coachMeta = `<p class="muted">Coach subscription: ` + template.HTMLEscaper(coach.Status) + `, period ends ` + template.HTMLEscaper(coach.CurrentPeriodEnd.UTC().Format("2006-01-02 15:04 UTC")) + `</p>`
		}
		coachSection = `<hr style="margin:16px 0;border:none;border-top:1px solid #ddd;">
<h3 style="margin:0 0 8px;">Trainer (coach) billing</h3>
` + coachMeta + `
<label>Coach plan</label><select name="coach_plan">` +
			coachPlanOption("", "None — cancel coach subscription rows", coachSel) +
			coachPlanOption("free_coach", "free_coach", coachSel) +
			coachPlanOption("coach_pro", "coach_pro (monthly)", coachSel) +
			coachPlanOption("coach_pro_yearly", "coach_pro_yearly", coachSel) +
			`</select>
<label>Coach period ends (RFC3339 UTC, empty = default for plan)</label><input type="text" name="coach_period_end" value="` + template.HTMLEscaper(coachPeriod) + `" placeholder="2026-12-31T23:59:59Z">
<p class="muted">Applies coach-tier rows in user_subscriptions. None removes active coach rows; entitlements fall back until Stripe or another purchase applies.</p>`
	}
	fields := `<label>Email</label><input type="email" name="email" value="` + template.HTMLEscaper(u.Email) + `" required>
<label>Role</label><select name="role">` +
		option("user", string(u.Role)) + option("trainer", string(u.Role)) + option("admin", string(u.Role)) +
		`</select>
<label>Theme</label><input type="text" name="theme" value="` + template.HTMLEscaper(u.Theme) + `" placeholder="e.g. gaming, light">
<label>Locale</label><input type="text" name="locale" value="` + template.HTMLEscaper(u.Locale) + `" placeholder="ru, en">
<label style="display:block;margin-top:8px;"><input type="checkbox" name="paid_subscriber" value="1"` + paidChk + `> Paid subscriber</label>
<label>Subscription expires (RFC3339 UTC, empty = none)</label><input type="text" name="subscription_expires_at" value="` + template.HTMLEscaper(subExp) + `" placeholder="2026-12-31T23:59:59Z">
<p class="muted">Leave subscription empty and uncheck paid for a free account.</p>
<label>New password</label><input type="password" name="new_password" autocomplete="new-password" placeholder="leave blank to keep current">
` + coachSection + `
<input type="hidden" name="id" value="` + u.ID.String() + `">`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "Edit user", "Action": "/admin/entities/users/update", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Save", "CancelURL": "/admin/entities/users"})
}

func (h *Handler) UsersUpdate(c *gin.Context) {
	id, err := uuid.Parse(c.PostForm("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	email := strings.TrimSpace(c.PostForm("email"))
	if email == "" {
		c.String(http.StatusBadRequest, "email required")
		return
	}
	role := authdomain.Role(c.PostForm("role"))
	if role != authdomain.RoleUser && role != authdomain.RoleTrainer && role != authdomain.RoleAdmin {
		role = authdomain.RoleUser
	}
	theme := strings.TrimSpace(c.PostForm("theme"))
	locale := strings.TrimSpace(c.PostForm("locale"))
	paid := c.PostForm("paid_subscriber") == "1"
	var subExp *time.Time
	if s := strings.TrimSpace(c.PostForm("subscription_expires_at")); s != "" {
		t, err := time.Parse(time.RFC3339, s)
		if err != nil {
			c.String(http.StatusBadRequest, "subscription_expires_at: use RFC3339, e.g. 2026-12-31T23:59:59Z")
			return
		}
		subExp = &t
	}
	newPw := strings.TrimSpace(c.PostForm("new_password"))
	hashStr := ""
	if newPw != "" {
		if len(newPw) < 6 {
			c.String(http.StatusBadRequest, "password must be at least 6 characters")
			return
		}
		hBytes, err := bcrypt.GenerateFromPassword([]byte(newPw), bcrypt.DefaultCost)
		if err != nil {
			c.String(http.StatusInternalServerError, err.Error())
			return
		}
		hashStr = string(hBytes)
	}
	if h.Deps.UsersUpdate == nil {
		c.String(http.StatusInternalServerError, "UsersUpdate not configured")
		return
	}
	if err := h.Deps.UsersUpdate(c.Request.Context(), id, email, role, theme, locale, paid, subExp, hashStr); err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	if h.Deps.CoachSubscriptionSet != nil {
		coachPlan := strings.TrimSpace(c.PostForm("coach_plan"))
		var coachEnd *time.Time
		if s := strings.TrimSpace(c.PostForm("coach_period_end")); s != "" {
			t, err := time.Parse(time.RFC3339, s)
			if err != nil {
				c.String(http.StatusBadRequest, "coach_period_end: use RFC3339, e.g. 2026-12-31T23:59:59Z")
				return
			}
			coachEnd = &t
		}
		if err := h.Deps.CoachSubscriptionSet(c.Request.Context(), id, coachPlan, coachEnd); err != nil {
			c.String(http.StatusInternalServerError, err.Error())
			return
		}
	}
	c.Redirect(http.StatusFound, "/admin/entities/users?flash=Updated")
}

func adminFmtTime(t *time.Time) string {
	if t == nil {
		return "—"
	}
	return t.UTC().Format("2006-01-02 15:04")
}

// --- Workouts (read-only list + detail)
func (h *Handler) WorkoutsList(c *gin.Context) {
	if h.Deps.WorkoutsList == nil || h.Deps.WorkoutsCount == nil {
		c.String(http.StatusNotImplemented, "workouts admin not configured")
		return
	}
	page, limit, offset := pageLimit(c)
	total, err := h.Deps.WorkoutsCount(c.Request.Context())
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	list, err := h.Deps.WorkoutsList(c.Request.Context(), limit, offset)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	rows := make([]ListRow, 0, len(list))
	for _, w := range list {
		tpl := "—"
		if w.TemplateID != nil {
			s := w.TemplateID.String()
			if len(s) >= 8 {
				tpl = s[:8]
			}
		}
		gym := "—"
		if w.GymName != nil && strings.TrimSpace(*w.GymName) != "" {
			gym = *w.GymName
			if len(gym) > 28 {
				gym = gym[:25] + "..."
			}
		}
		uid := w.UserID.String()
		if len(uid) >= 8 {
			uid = uid[:8]
		}
		rows = append(rows, ListRow{
			ID: w.ID.String(),
			Cells: []string{
				uid,
				tpl,
				adminFmtTime(w.ScheduledAt),
				adminFmtTime(w.StartedAt),
				adminFmtTime(w.FinishedAt),
				w.CreatedAt.UTC().Format("2006-01-02 15:04"),
				gym,
			},
		})
	}
	data := h.listData("Workouts", "/admin/entities/workouts", "", "/admin/entities/workouts", "",
		[]string{"User", "Template", "Scheduled", "Started", "Finished", "Created", "Gym"},
		rows, "", false, page, limit, offset, total, "View")
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL, "PaginationSummary": data.PaginationSummary, "RowAction": data.RowAction})
}

func (h *Handler) WorkoutsView(c *gin.Context) {
	if h.Deps.WorkoutsGetByID == nil {
		c.String(http.StatusNotImplemented, "workouts admin not configured")
		return
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	w, err := h.Deps.WorkoutsGetByID(c.Request.Context(), id)
	if err != nil {
		if errors.Is(err, workoutdomain.ErrWorkoutNotFound) {
			c.String(http.StatusNotFound, "workout not found")
			return
		}
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	uuidOpt := func(u *uuid.UUID) string {
		if u == nil {
			return "—"
		}
		return u.String()
	}
	fields := `<p><strong>ID</strong> ` + w.ID.String() + `</p>
<p><strong>User ID</strong> ` + w.UserID.String() + `</p>
<p><strong>Template ID</strong> ` + uuidOpt(w.TemplateID) + `</p>
<p><strong>Program ID</strong> ` + uuidOpt(w.ProgramID) + `</p>
<p><strong>Trainer ID</strong> ` + uuidOpt(w.TrainerID) + `</p>
<p><strong>Gym ID</strong> ` + uuidOpt(w.GymID) + `</p>
<p><strong>Scheduled</strong> ` + adminFmtTime(w.ScheduledAt) + `</p>
<p><strong>Started</strong> ` + adminFmtTime(w.StartedAt) + `</p>
<p><strong>Finished</strong> ` + adminFmtTime(w.FinishedAt) + `</p>
<p><strong>Created</strong> ` + w.CreatedAt.UTC().Format(time.RFC3339) + `</p>`
	h.renderOK(c, viewHTML, gin.H{"ShowBar": true, "Title": "Workout", "FieldsHTML": template.HTML(fields), "CancelURL": "/admin/entities/workouts"})
}

func option(val, selected string) string {
	s := `<option value="` + val + `"`
	if val == selected {
		s += ` selected`
	}
	return s + ">" + val + "</option>"
}

func coachPlanOption(val, label, selected string) string {
	s := `<option value="` + template.HTMLEscaper(val) + `"`
	if val == selected {
		s += ` selected`
	}
	return s + `>` + template.HTMLEscaper(label) + `</option>`
}

// --- Gyms
func (h *Handler) GymsList(c *gin.Context) {
	page, limit, offset := pageLimit(c)
	q := strings.TrimSpace(c.Query("q"))
	list, err := h.Deps.GymsSearch(c.Request.Context(), q, "", nil, nil, limit, offset)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	rows := make([]ListRow, 0, len(list))
	for _, g := range list {
		addr := g.Address
		if len(addr) > 40 {
			addr = addr[:37] + "..."
		}
		rows = append(rows, ListRow{ID: g.ID.String(), Cells: []string{g.Name, addr, g.CreatedAt.Format("2006-01-02")}})
	}
	data := h.listData("Gyms", "/admin/entities/gyms", "/admin/entities/gyms/new", "/admin/entities/gyms", "/admin/entities/gyms/delete", []string{"Name", "Address", "Created"}, rows, q, true, page, limit, offset, -1, "")
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL, "PaginationSummary": data.PaginationSummary, "RowAction": data.RowAction})
}

func (h *Handler) GymsNew(c *gin.Context) {
	fields := `<label>Name</label><input type="text" name="name" required>
<label>Address</label><input type="text" name="address">
<label>Latitude</label><input type="number" step="any" name="latitude">
<label>Longitude</label><input type="number" step="any" name="longitude">`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "New gym", "Action": "/admin/entities/gyms/create", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Create", "CancelURL": "/admin/entities/gyms"})
}

func (h *Handler) GymsCreate(c *gin.Context) {
	name := strings.TrimSpace(c.PostForm("name"))
	address := strings.TrimSpace(c.PostForm("address"))
	var lat, lng *float64
	if v := c.PostForm("latitude"); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			lat = &f
		}
	}
	if v := c.PostForm("longitude"); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			lng = &f
		}
	}
	_, err := h.Deps.GymsCreate(c.Request.Context(), name, lat, lng, address)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/gyms?flash=Created")
}

func (h *Handler) GymsEdit(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	g, err := h.Deps.GymsGet(c.Request.Context(), id)
	if err != nil {
		c.String(http.StatusNotFound, err.Error())
		return
	}
	latStr := ""
	if g.Latitude != nil {
		latStr = strconv.FormatFloat(*g.Latitude, 'f', -1, 64)
	}
	lngStr := ""
	if g.Longitude != nil {
		lngStr = strconv.FormatFloat(*g.Longitude, 'f', -1, 64)
	}
	fields := `<label>Name</label><input type="text" name="name" value="` + template.HTMLEscaper(g.Name) + `" required>
<label>Address</label><input type="text" name="address" value="` + template.HTMLEscaper(g.Address) + `">
<label>Latitude</label><input type="number" step="any" name="latitude" value="` + latStr + `">
<label>Longitude</label><input type="number" step="any" name="longitude" value="` + lngStr + `">
<input type="hidden" name="id" value="` + g.ID.String() + `">`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "Edit gym", "Action": "/admin/entities/gyms/update", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Save", "CancelURL": "/admin/entities/gyms"})
}

func (h *Handler) GymsUpdate(c *gin.Context) {
	id, err := uuid.Parse(c.PostForm("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	name := strings.TrimSpace(c.PostForm("name"))
	address := strings.TrimSpace(c.PostForm("address"))
	var lat, lng *float64
	if v := c.PostForm("latitude"); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			lat = &f
		}
	}
	if v := c.PostForm("longitude"); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			lng = &f
		}
	}
	_, err = h.Deps.GymsUpdate(c.Request.Context(), id, name, lat, lng, address)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/gyms?flash=Updated")
}

func (h *Handler) GymsDelete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.Deps.GymsDelete(c.Request.Context(), id); err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/gyms?flash=Deleted")
}

// --- Exercises
func (h *Handler) ExercisesList(c *gin.Context) {
	page, limit, offset := pageLimit(c)
	q := strings.TrimSpace(c.Query("q"))
	filters := &workoutdomain.ExerciseFilters{}
	if q != "" {
		filters.NameSearch = &q
	}
	total, err := h.Deps.ExercisesCount(c.Request.Context(), filters)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	list, err := h.Deps.ExercisesList(c.Request.Context(), limit, offset, filters)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	rows := make([]ListRow, 0, len(list))
	for _, e := range list {
		mg := exerciseMuscleGroupsDisplay(e)
		rows = append(rows, ListRow{ID: e.ID.String(), Cells: []string{e.Name, mg, e.CreatedAt.Format("2006-01-02")}})
	}
	data := h.listData("Exercises", "/admin/entities/exercises", "/admin/entities/exercises/new", "/admin/entities/exercises", "/admin/entities/exercises/delete", []string{"Name", "Muscle groups", "Created"}, rows, q, true, page, limit, offset, total, "")
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL, "PaginationSummary": data.PaginationSummary, "RowAction": data.RowAction})
}

func (h *Handler) ExercisesNew(c *gin.Context) {
	fields := `<label>Name</label><input type="text" name="name" required>
<label>Muscle groups</label><textarea name="muscle_groups" rows="4" placeholder="One per line, or comma-separated"></textarea>
<p class="muted">Load is split equally between groups (stored in muscle_loads). First group is the primary filter (muscle_group).</p>
<label>Difficulty</label><input type="text" name="difficulty_level">
<label>Description</label><textarea name="description"></textarea>
<label>Formula</label><input type="text" name="formula">
<label>Base</label><input type="checkbox" name="is_base" value="1">
<label>Popular</label><input type="checkbox" name="is_popular" value="1">
<label>Free</label><input type="checkbox" name="is_free" value="1" checked>`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "New exercise", "Action": "/admin/entities/exercises/create", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Create", "CancelURL": "/admin/entities/exercises"})
}

func (h *Handler) ExercisesCreate(c *gin.Context) {
	e := &workoutdomain.Exercise{
		Name:        strings.TrimSpace(c.PostForm("name")),
		MuscleLoads: make(map[string]float64),
		IsFree:      c.PostForm("is_free") == "1",
		IsBase:      c.PostForm("is_base") == "1",
		IsPopular:   c.PostForm("is_popular") == "1",
	}
	applyExerciseMuscleGroupsFromForm(e, c.PostForm("muscle_groups"))
	if v := c.PostForm("difficulty_level"); v != "" {
		e.DifficultyLevel = &v
	}
	if v := c.PostForm("description"); v != "" {
		e.Description = &v
	}
	if v := c.PostForm("formula"); v != "" {
		e.Formula = &v
	}
	_, err := h.Deps.ExercisesCreate(c.Request.Context(), e)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/exercises?flash=Created")
}

func (h *Handler) ExercisesEdit(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	e, err := h.Deps.ExercisesGet(c.Request.Context(), id)
	if err != nil {
		c.String(http.StatusNotFound, err.Error())
		return
	}
	mg := exerciseMuscleGroupsFormValue(e)
	diff := ""
	if e.DifficultyLevel != nil {
		diff = *e.DifficultyLevel
	}
	desc := ""
	if e.Description != nil {
		desc = *e.Description
	}
	formula := ""
	if e.Formula != nil {
		formula = *e.Formula
	}
	baseChk := ""
	if e.IsBase {
		baseChk = " checked"
	}
	popChk := ""
	if e.IsPopular {
		popChk = " checked"
	}
	freeChk := ""
	if e.IsFree {
		freeChk = " checked"
	}
	fields := `<label>Name</label><input type="text" name="name" value="` + template.HTMLEscaper(e.Name) + `" required>
<label>Muscle groups</label><textarea name="muscle_groups" rows="4">` + template.HTMLEscaper(mg) + `</textarea>
<p class="muted">One per line or comma-separated. Equal load share per group.</p>
<label>Difficulty</label><input type="text" name="difficulty_level" value="` + template.HTMLEscaper(diff) + `">
<label>Description</label><textarea name="description">` + template.HTMLEscaper(desc) + `</textarea>
<label>Formula</label><input type="text" name="formula" value="` + template.HTMLEscaper(formula) + `">
<label>Base</label><input type="checkbox" name="is_base" value="1"` + baseChk + `>
<label>Popular</label><input type="checkbox" name="is_popular" value="1"` + popChk + `>
<label>Free</label><input type="checkbox" name="is_free" value="1"` + freeChk + `>
<input type="hidden" name="id" value="` + e.ID.String() + `">`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "Edit exercise", "Action": "/admin/entities/exercises/update", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Save", "CancelURL": "/admin/entities/exercises"})
}

func (h *Handler) ExercisesUpdate(c *gin.Context) {
	id, err := uuid.Parse(c.PostForm("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	e, err := h.Deps.ExercisesGet(c.Request.Context(), id)
	if err != nil {
		c.String(http.StatusNotFound, err.Error())
		return
	}
	e.Name = strings.TrimSpace(c.PostForm("name"))
	e.IsFree = c.PostForm("is_free") == "1"
	e.IsBase = c.PostForm("is_base") == "1"
	e.IsPopular = c.PostForm("is_popular") == "1"
	applyExerciseMuscleGroupsFromForm(e, c.PostForm("muscle_groups"))
	if v := c.PostForm("difficulty_level"); v != "" {
		e.DifficultyLevel = &v
	} else {
		e.DifficultyLevel = nil
	}
	if v := c.PostForm("description"); v != "" {
		e.Description = &v
	} else {
		e.Description = nil
	}
	if v := c.PostForm("formula"); v != "" {
		e.Formula = &v
	} else {
		e.Formula = nil
	}
	_, err = h.Deps.ExercisesUpdate(c.Request.Context(), e)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/exercises?flash=Updated")
}

func (h *Handler) ExercisesDelete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.Deps.ExercisesDelete(c.Request.Context(), id); err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/exercises?flash=Deleted")
}

// --- Programs
func (h *Handler) ProgramsList(c *gin.Context) {
	page, limit, offset := pageLimit(c)
	list, err := h.Deps.ProgramsList(c.Request.Context(), nil, limit, offset)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	rows := make([]ListRow, 0, len(list))
	for _, p := range list {
		rows = append(rows, ListRow{ID: p.ID.String(), Cells: []string{p.Name, p.CreatedAt.Format("2006-01-02")}})
	}
	data := h.listData("Programs", "/admin/entities/programs", "/admin/entities/programs/new", "/admin/entities/programs", "/admin/entities/programs/delete", []string{"Name", "Created"}, rows, "", true, page, limit, offset, -1, "")
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL, "PaginationSummary": data.PaginationSummary, "RowAction": data.RowAction})
}

func (h *Handler) ProgramsNew(c *gin.Context) {
	fields := `<label>Name</label><input type="text" name="name" required>
<label>Description</label><textarea name="description"></textarea>`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "New program", "Action": "/admin/entities/programs/create", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Create", "CancelURL": "/admin/entities/programs"})
}

func (h *Handler) ProgramsCreate(c *gin.Context) {
	name := strings.TrimSpace(c.PostForm("name"))
	desc := strings.TrimSpace(c.PostForm("description"))
	_, err := h.Deps.ProgramsCreate(c.Request.Context(), name, desc, nil)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/programs?flash=Created")
}

func (h *Handler) ProgramsEdit(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	p, err := h.Deps.ProgramsGet(c.Request.Context(), id)
	if err != nil {
		c.String(http.StatusNotFound, err.Error())
		return
	}
	desc := ""
	if p.Description != nil {
		desc = *p.Description
	}
	fields := `<label>Name</label><input type="text" name="name" value="` + template.HTMLEscaper(p.Name) + `" required>
<label>Description</label><textarea name="description">` + template.HTMLEscaper(desc) + `</textarea>
<input type="hidden" name="id" value="` + p.ID.String() + `">`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "Edit program", "Action": "/admin/entities/programs/update", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Save", "CancelURL": "/admin/entities/programs"})
}

func (h *Handler) ProgramsUpdate(c *gin.Context) {
	id, err := uuid.Parse(c.PostForm("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	name := strings.TrimSpace(c.PostForm("name"))
	desc := strings.TrimSpace(c.PostForm("description"))
	_, err = h.Deps.ProgramsUpdate(c.Request.Context(), id, name, desc, nil)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/programs?flash=Updated")
}

func (h *Handler) ProgramsDelete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.Deps.ProgramsDelete(c.Request.Context(), id); err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/programs?flash=Deleted")
}

// --- Tags
func (h *Handler) TagsList(c *gin.Context) {
	page, limit, offset := pageLimit(c)
	list, err := h.Deps.TagsList(c.Request.Context(), limit, offset)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	rows := make([]ListRow, 0, len(list))
	for _, t := range list {
		rows = append(rows, ListRow{ID: t.ID.String(), Cells: []string{t.Name}})
	}
	data := h.listData("Tags", "/admin/entities/tags", "/admin/entities/tags/new", "/admin/entities/tags", "/admin/entities/tags/delete", []string{"Name"}, rows, "", true, page, limit, offset, -1, "")
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL, "PaginationSummary": data.PaginationSummary, "RowAction": data.RowAction})
}

func (h *Handler) TagsNew(c *gin.Context) {
	fields := `<label>Name</label><input type="text" name="name" required>`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "New tag", "Action": "/admin/entities/tags/create", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Create", "CancelURL": "/admin/entities/tags"})
}

func (h *Handler) TagsCreate(c *gin.Context) {
	name := strings.TrimSpace(c.PostForm("name"))
	if name == "" {
		c.String(http.StatusBadRequest, "name required")
		return
	}
	_, err := h.Deps.TagsCreate(c.Request.Context(), name)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/tags?flash=Created")
}

func (h *Handler) TagsDelete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.Deps.TagsDelete(c.Request.Context(), id); err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/tags?flash=Deleted")
}

// --- Blog posts
func (h *Handler) BlogPostsList(c *gin.Context) {
	page, limit, offset := pageLimit(c)
	list, err := h.Deps.BlogPostsList(c.Request.Context(), nil, limit, offset)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	rows := make([]ListRow, 0, len(list))
	for _, p := range list {
		rows = append(rows, ListRow{ID: p.ID.String(), Cells: []string{p.Title, p.UserID.String(), p.CreatedAt.Format("2006-01-02")}})
	}
	data := h.listData("Blog posts", "/admin/entities/blog_posts", "/admin/entities/blog_posts/new", "/admin/entities/blog_posts", "/admin/entities/blog_posts/delete", []string{"Title", "User ID", "Created"}, rows, "", true, page, limit, offset, -1, "")
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL, "PaginationSummary": data.PaginationSummary, "RowAction": data.RowAction})
}

func (h *Handler) BlogPostsNew(c *gin.Context) {
	fields := `<label>User ID (UUID)</label><input type="text" name="user_id" required>
<label>Title</label><input type="text" name="title" required>
<label>Content</label><textarea name="content"></textarea>`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "New blog post", "Action": "/admin/entities/blog_posts/create", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Create", "CancelURL": "/admin/entities/blog_posts"})
}

func (h *Handler) BlogPostsCreate(c *gin.Context) {
	userID, err := uuid.Parse(c.PostForm("user_id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid user_id")
		return
	}
	title := strings.TrimSpace(c.PostForm("title"))
	content := strings.TrimSpace(c.PostForm("content"))
	var contentP *string
	if content != "" {
		contentP = &content
	}
	_, err = h.Deps.BlogPostsCreate(c.Request.Context(), userID, title, contentP)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/blog_posts?flash=Created")
}

func (h *Handler) BlogPostsEdit(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	p, err := h.Deps.BlogPostsGet(c.Request.Context(), id)
	if err != nil {
		c.String(http.StatusNotFound, err.Error())
		return
	}
	content := ""
	if p.Content != nil {
		content = *p.Content
	}
	fields := `<label>Title</label><input type="text" name="title" value="` + template.HTMLEscaper(p.Title) + `" required>
<label>Content</label><textarea name="content">` + template.HTMLEscaper(content) + `</textarea>
<input type="hidden" name="id" value="` + p.ID.String() + `">`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "Edit blog post", "Action": "/admin/entities/blog_posts/update", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Save", "CancelURL": "/admin/entities/blog_posts"})
}

func (h *Handler) BlogPostsUpdate(c *gin.Context) {
	id, err := uuid.Parse(c.PostForm("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	title := strings.TrimSpace(c.PostForm("title"))
	content := strings.TrimSpace(c.PostForm("content"))
	var contentP *string
	if content != "" {
		contentP = &content
	}
	_, err = h.Deps.BlogPostsUpdate(c.Request.Context(), id, title, contentP)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/blog_posts?flash=Updated")
}

func (h *Handler) BlogPostsDelete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.Deps.BlogPostsDelete(c.Request.Context(), id); err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/blog_posts?flash=Deleted")
}

// --- System messages
func (h *Handler) SystemMessagesList(c *gin.Context) {
	page, limit, offset := pageLimit(c)
	list, err := h.Deps.SystemMessagesList(c.Request.Context(), limit, offset)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	rows := make([]ListRow, 0, len(list))
	for _, m := range list {
		active := "no"
		if m.IsActive {
			active = "yes"
		}
		body := m.Body
		if len(body) > 80 {
			body = body[:80] + "…"
		}
		rows = append(rows, ListRow{ID: m.ID.String(), Cells: []string{m.Title, active, m.CreatedAt.Format("2006-01-02"), body}})
	}
	data := h.listData("System messages", "/admin/entities/system_messages", "/admin/entities/system_messages/new", "/admin/entities/system_messages", "/admin/entities/system_messages/delete", []string{"Title", "Active", "Created", "Body"}, rows, "", true, page, limit, offset, -1, "")
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL, "PaginationSummary": data.PaginationSummary, "RowAction": data.RowAction})
}

func (h *Handler) SystemMessagesNew(c *gin.Context) {
	fields := `<label>Title</label><input type="text" name="title" required>
<label>Body</label><textarea name="body" required></textarea>
<label style="display:block; margin-top:8px;"><input type="checkbox" name="is_active" value="1" checked> Active</label>`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "New system message", "Action": "/admin/entities/system_messages/create", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Create", "CancelURL": "/admin/entities/system_messages"})
}

func (h *Handler) SystemMessagesCreate(c *gin.Context) {
	title := strings.TrimSpace(c.PostForm("title"))
	body := strings.TrimSpace(c.PostForm("body"))
	isActive := c.PostForm("is_active") == "1"
	if title == "" || body == "" {
		c.String(http.StatusBadRequest, "title and body required")
		return
	}
	_, err := h.Deps.SystemMessagesCreate(c.Request.Context(), title, body, isActive)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/system_messages?flash=Created")
}

func (h *Handler) SystemMessagesEdit(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	m, err := h.Deps.SystemMessagesGet(c.Request.Context(), id)
	if err != nil {
		c.String(http.StatusNotFound, err.Error())
		return
	}
	checked := ""
	if m.IsActive {
		checked = " checked"
	}
	fields := `<label>Title</label><input type="text" name="title" value="` + template.HTMLEscaper(m.Title) + `" required>
<label>Body</label><textarea name="body" required>` + template.HTMLEscaper(m.Body) + `</textarea>
<label style="display:block; margin-top:8px;"><input type="checkbox" name="is_active" value="1"` + checked + `> Active</label>
<input type="hidden" name="id" value="` + m.ID.String() + `">`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "Edit system message", "Action": "/admin/entities/system_messages/update", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Save", "CancelURL": "/admin/entities/system_messages"})
}

func (h *Handler) SystemMessagesUpdate(c *gin.Context) {
	id, err := uuid.Parse(c.PostForm("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	title := strings.TrimSpace(c.PostForm("title"))
	body := strings.TrimSpace(c.PostForm("body"))
	isActive := c.PostForm("is_active") == "1"
	if title == "" || body == "" {
		c.String(http.StatusBadRequest, "title and body required")
		return
	}
	_, err = h.Deps.SystemMessagesUpdate(c.Request.Context(), id, title, body, isActive)
	if err != nil {
		if err == systemmessagedomain.ErrSystemMessageNotFound {
			c.String(http.StatusNotFound, err.Error())
			return
		}
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/system_messages?flash=Updated")
}

func (h *Handler) SystemMessagesDelete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.Deps.SystemMessagesDelete(c.Request.Context(), id); err != nil {
		if err == systemmessagedomain.ErrSystemMessageNotFound {
			c.String(http.StatusNotFound, err.Error())
			return
		}
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/system_messages?flash=Deleted")
}

// --- Buckets
func (h *Handler) BucketsList(c *gin.Context) {
	list, err := h.Deps.BucketsList(c.Request.Context())
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	rows := make([]ListRow, 0, len(list))
	for _, b := range list {
		rows = append(rows, ListRow{ID: b.ID.String(), Cells: []string{b.Name, b.Endpoint, b.Region, b.PublicURL}})
	}
	data := h.listData("Buckets", "/admin/entities/buckets", "/admin/entities/buckets/new", "/admin/entities/buckets", "/admin/entities/buckets/delete", []string{"Name", "Endpoint", "Region", "Public URL"}, rows, "", false, 1, len(list), 0, len(list), "")
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL, "PaginationSummary": data.PaginationSummary, "RowAction": data.RowAction})
}

func (h *Handler) BucketsNew(c *gin.Context) {
	fields := `<label>Name</label><input type="text" name="name" required>
<label>Endpoint</label><input type="text" name="endpoint" placeholder="s3.ru-7.storage.selcloud.ru">
<label>Region</label><input type="text" name="region" placeholder="ru-7">
<label>Public URL</label><input type="text" name="public_url" placeholder="http://s3.gymmore.ru">`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "New bucket", "Action": "/admin/entities/buckets/create", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Create", "CancelURL": "/admin/entities/buckets"})
}

func (h *Handler) BucketsCreate(c *gin.Context) {
	name := strings.TrimSpace(c.PostForm("name"))
	endpoint := strings.TrimSpace(c.PostForm("endpoint"))
	region := strings.TrimSpace(c.PostForm("region"))
	publicURL := strings.TrimSpace(c.PostForm("public_url"))
	if name == "" {
		c.String(http.StatusBadRequest, "name required")
		return
	}
	_, err := h.Deps.BucketsCreate(c.Request.Context(), name, endpoint, region, publicURL)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/buckets?flash=Created")
}

func (h *Handler) BucketsEdit(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	b, err := h.Deps.BucketsGet(c.Request.Context(), id)
	if err != nil {
		c.String(http.StatusNotFound, err.Error())
		return
	}
	fields := `<label>Name</label><input type="text" name="name" value="` + template.HTMLEscaper(b.Name) + `" required>
<label>Endpoint</label><input type="text" name="endpoint" value="` + template.HTMLEscaper(b.Endpoint) + `">
<label>Region</label><input type="text" name="region" value="` + template.HTMLEscaper(b.Region) + `">
<label>Public URL</label><input type="text" name="public_url" value="` + template.HTMLEscaper(b.PublicURL) + `">
<input type="hidden" name="id" value="` + b.ID.String() + `">`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "Edit bucket", "Action": "/admin/entities/buckets/update", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Save", "CancelURL": "/admin/entities/buckets"})
}

func (h *Handler) BucketsUpdate(c *gin.Context) {
	id, err := uuid.Parse(c.PostForm("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	name := strings.TrimSpace(c.PostForm("name"))
	endpoint := strings.TrimSpace(c.PostForm("endpoint"))
	region := strings.TrimSpace(c.PostForm("region"))
	publicURL := strings.TrimSpace(c.PostForm("public_url"))
	if name == "" {
		c.String(http.StatusBadRequest, "name required")
		return
	}
	_, err = h.Deps.BucketsUpdate(c.Request.Context(), id, name, endpoint, region, publicURL)
	if err != nil {
		if err == photodomain.ErrBucketNotFound {
			c.String(http.StatusNotFound, err.Error())
			return
		}
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/buckets?flash=Updated")
}

func (h *Handler) BucketsDelete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.Deps.BucketsDelete(c.Request.Context(), id); err != nil {
		if err == photodomain.ErrBucketNotFound {
			c.String(http.StatusNotFound, err.Error())
			return
		}
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/buckets?flash=Deleted")
}

// --- Photos
func (h *Handler) PhotosList(c *gin.Context) {
	page, limit, offset := pageLimit(c)
	list, err := h.Deps.PhotosList(c.Request.Context(), limit, offset)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	rows := make([]ListRow, 0, len(list))
	for _, p := range list {
		urlShort := p.URL
		if len(urlShort) > 60 {
			urlShort = urlShort[:57] + "…"
		}
		rows = append(rows, ListRow{ID: p.ID.String(), Cells: []string{p.ID.String()[:8], urlShort, p.CreatedAt.Format("2006-01-02 15:04")}})
	}
	data := h.listData("Photos", "/admin/entities/photos", "/admin/entities/photos/new", "/admin/entities/photos", "/admin/entities/photos/delete", []string{"ID", "URL", "Created"}, rows, "", true, page, limit, offset, -1, "")
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL, "PaginationSummary": data.PaginationSummary, "RowAction": data.RowAction})
}

func (h *Handler) PhotosNew(c *gin.Context) {
	buckets, err := h.Deps.BucketsList(c.Request.Context())
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	var opts string
	for _, b := range buckets {
		opts += `<option value="` + template.HTMLEscaper(b.Name) + `">` + template.HTMLEscaper(b.Name) + `</option>`
	}
	fields := `<label>Bucket</label><select name="bucket" required>` + opts + `</select>
<label>File</label><input type="file" name="file" accept="image/*" required>`
	h.renderOK(c, uploadFormHTML, gin.H{"ShowBar": true, "Title": "Upload photo", "Action": "/admin/entities/photos/create", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Upload", "CancelURL": "/admin/entities/photos"})
}

func (h *Handler) PhotosCreate(c *gin.Context) {
	bucket := strings.TrimSpace(c.PostForm("bucket"))
	file, err := c.FormFile("file")
	if err != nil || file == nil {
		c.String(http.StatusBadRequest, "file required")
		return
	}
	if bucket == "" {
		c.String(http.StatusBadRequest, "bucket required")
		return
	}
	f, err := file.Open()
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	defer f.Close()
	photoID, _, err := h.Deps.PhotosUpload(c.Request.Context(), bucket, f, file.Header.Get("Content-Type"))
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/photos?flash=Uploaded&created_id="+photoID.String())
}

func (h *Handler) PhotosView(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	p, err := h.Deps.PhotosGet(c.Request.Context(), id)
	if err != nil {
		c.String(http.StatusNotFound, err.Error())
		return
	}
	fields := `<p><strong>ID:</strong> ` + p.ID.String() + `</p>
<p><strong>URL:</strong> <a href="` + template.HTMLEscaper(p.URL) + `" target="_blank">` + template.HTMLEscaper(p.URL) + `</a></p>
<p><img src="` + template.HTMLEscaper(p.URL) + `" alt="Photo" style="max-width:400px;"></p>`
	h.renderOK(c, viewHTML, gin.H{"ShowBar": true, "Title": "Photo", "FieldsHTML": template.HTML(fields), "CancelURL": "/admin/entities/photos"})
}

func (h *Handler) PhotosDelete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.Deps.PhotosDelete(c.Request.Context(), id); err != nil {
		if err == photodomain.ErrPhotoNotFound {
			c.String(http.StatusNotFound, err.Error())
			return
		}
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/photos?flash=Deleted")
}

func exerciseMuscleGroupsDisplay(e *workoutdomain.Exercise) string {
	if len(e.MuscleLoads) > 0 {
		keys := make([]string, 0, len(e.MuscleLoads))
		for k := range e.MuscleLoads {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		return strings.Join(keys, ", ")
	}
	if e.MuscleGroup != nil {
		return *e.MuscleGroup
	}
	return ""
}

func exerciseMuscleGroupsFormValue(e *workoutdomain.Exercise) string {
	if len(e.MuscleLoads) > 0 {
		keys := make([]string, 0, len(e.MuscleLoads))
		for k := range e.MuscleLoads {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		return strings.Join(keys, "\n")
	}
	if e.MuscleGroup != nil {
		return *e.MuscleGroup
	}
	return ""
}

func applyExerciseMuscleGroupsFromForm(e *workoutdomain.Exercise, raw string) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		e.MuscleGroup = nil
		e.MuscleLoads = make(map[string]float64)
		return
	}
	parts := splitMuscleGroupNames(raw)
	if len(parts) == 0 {
		e.MuscleGroup = nil
		e.MuscleLoads = make(map[string]float64)
		return
	}
	w := 1.0 / float64(len(parts))
	loads := make(map[string]float64)
	for _, p := range parts {
		loads[p] = w
	}
	e.MuscleLoads = loads
	primary := parts[0]
	e.MuscleGroup = &primary
}

func splitMuscleGroupNames(raw string) []string {
	for _, sep := range []string{",", ";"} {
		raw = strings.ReplaceAll(raw, sep, "\n")
	}
	var out []string
	for _, line := range strings.Split(raw, "\n") {
		s := strings.TrimSpace(line)
		if s != "" {
			out = append(out, s)
		}
	}
	return out
}
