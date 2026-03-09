package admin

import (
	"html/template"
	"net/http"
	"strconv"
	"strings"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// ListRow is one row in the admin table (ID + cells for display).
type ListRow struct {
	ID    string
	Cells []string
}

// ListData for list template.
type ListData struct {
	Title            string
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

func (h *Handler) listData(entity, listPath, newPath, editPath, deletePath string, headers []string, rows []ListRow, searchQ string, allowDelete bool, page, limit int, total int) ListData {
	prevURL := ""
	nextURL := ""
	if page > 1 {
		prevURL = listPath + "?page=" + strconv.Itoa(page-1)
		if searchQ != "" {
			prevURL += "&q=" + searchQ
		}
	}
	if total >= limit && len(rows) == limit {
		nextURL = listPath + "?page=" + strconv.Itoa(page+1)
		if searchQ != "" {
			nextURL += "&q=" + searchQ
		}
	}
	return ListData{
		Title:      entity,
		Headers:    headers,
		Rows:       rows,
		ListPath:   listPath,
		NewPath:    newPath,
		EditPath:   editPath,
		DeletePath: deletePath,
		AllowDelete: allowDelete,
		SearchQ:    searchQ,
		HasPrev:    page > 1,
		HasNext:    len(rows) == limit && total >= limit,
		PrevURL:    prevURL,
		NextURL:    nextURL,
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
		rows = append(rows, ListRow{
			ID:    u.ID.String(),
			Cells: []string{u.Email, string(u.Role), u.CreatedAt.Format("2006-01-02 15:04")},
		})
	}
	data := h.listData("Users", "/admin/entities/users", "/admin/entities/users/new", "/admin/entities/users", "/admin/entities/users/delete", []string{"Email", "Role", "Created"}, rows, q, false, page, limit, len(list))
	data.FilterPlaceholder = ""
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL})
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
	fields := `<label>Email</label><input type="text" value="` + template.HTMLEscaper(u.Email) + `" disabled>
<label>Role</label><select name="role">` +
		option("user", string(u.Role)) + option("trainer", string(u.Role)) + option("admin", string(u.Role)) +
		`</select>
<input type="hidden" name="id" value="` + u.ID.String() + `">`
	h.renderOK(c, formHTML, gin.H{"ShowBar": true, "Title": "Edit user", "Action": "/admin/entities/users/update", "FieldsHTML": template.HTML(fields), "SubmitLabel": "Save", "CancelURL": "/admin/entities/users"})
}

func (h *Handler) UsersUpdate(c *gin.Context) {
	id, err := uuid.Parse(c.PostForm("id"))
	if err != nil {
		c.String(http.StatusBadRequest, "invalid id")
		return
	}
	role := authdomain.Role(c.PostForm("role"))
	if role != authdomain.RoleUser && role != authdomain.RoleTrainer && role != authdomain.RoleAdmin {
		role = authdomain.RoleUser
	}
	if err := h.Deps.UsersUpdateRole(c.Request.Context(), id, role); err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	c.Redirect(http.StatusFound, "/admin/entities/users?flash=Updated")
}

func option(val, selected string) string {
	s := `<option value="` + val + `"`
	if val == selected {
		s += ` selected`
	}
	return s + ">" + val + "</option>"
}

// --- Gyms
func (h *Handler) GymsList(c *gin.Context) {
	page, limit, offset := pageLimit(c)
	q := strings.TrimSpace(c.Query("q"))
	list, err := h.Deps.GymsSearch(c.Request.Context(), q, nil, nil, limit, offset)
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
	data := h.listData("Gyms", "/admin/entities/gyms", "/admin/entities/gyms/new", "/admin/entities/gyms", "/admin/entities/gyms/delete", []string{"Name", "Address", "Created"}, rows, q, true, page, limit, len(list))
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL})
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
		// Exercise repo filter by name would need adding; for now list all and filter in memory for display
	}
	list, err := h.Deps.ExercisesList(c.Request.Context(), limit, offset, filters)
	if err != nil {
		c.String(http.StatusInternalServerError, err.Error())
		return
	}
	rows := make([]ListRow, 0, len(list))
	for _, e := range list {
		mg := ""
		if e.MuscleGroup != nil {
			mg = *e.MuscleGroup
		}
		rows = append(rows, ListRow{ID: e.ID.String(), Cells: []string{e.Name, mg, e.CreatedAt.Format("2006-01-02")}})
	}
	data := h.listData("Exercises", "/admin/entities/exercises", "/admin/entities/exercises/new", "/admin/entities/exercises", "/admin/entities/exercises/delete", []string{"Name", "Muscle group", "Created"}, rows, q, true, page, limit, len(list))
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL})
}

func (h *Handler) ExercisesNew(c *gin.Context) {
	fields := `<label>Name</label><input type="text" name="name" required>
<label>Muscle group</label><input type="text" name="muscle_group">
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
		Name:            strings.TrimSpace(c.PostForm("name")),
		MuscleLoads:     make(map[string]float64),
		IsFree:          c.PostForm("is_free") == "1",
		IsBase:          c.PostForm("is_base") == "1",
		IsPopular:       c.PostForm("is_popular") == "1",
	}
	if v := c.PostForm("muscle_group"); v != "" {
		e.MuscleGroup = &v
	}
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
	mg := ""
	if e.MuscleGroup != nil {
		mg = *e.MuscleGroup
	}
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
<label>Muscle group</label><input type="text" name="muscle_group" value="` + template.HTMLEscaper(mg) + `">
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
	if v := c.PostForm("muscle_group"); v != "" {
		e.MuscleGroup = &v
	} else {
		e.MuscleGroup = nil
	}
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
	data := h.listData("Programs", "/admin/entities/programs", "/admin/entities/programs/new", "/admin/entities/programs", "/admin/entities/programs/delete", []string{"Name", "Created"}, rows, "", true, page, limit, len(list))
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL})
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
	data := h.listData("Tags", "/admin/entities/tags", "/admin/entities/tags/new", "/admin/entities/tags", "/admin/entities/tags/delete", []string{"Name"}, rows, "", true, page, limit, len(list))
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL})
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
	data := h.listData("Blog posts", "/admin/entities/blog_posts", "/admin/entities/blog_posts/new", "/admin/entities/blog_posts", "/admin/entities/blog_posts/delete", []string{"Title", "User ID", "Created"}, rows, "", true, page, limit, len(list))
	h.renderOK(c, listHTML, gin.H{"ShowBar": true, "Title": data.Title, "Headers": data.Headers, "Rows": data.Rows, "ListPath": data.ListPath, "NewPath": data.NewPath, "EditPath": data.EditPath, "DeletePath": data.DeletePath, "AllowDelete": data.AllowDelete, "SearchQ": data.SearchQ, "HasPrev": data.HasPrev, "HasNext": data.HasNext, "PrevURL": data.PrevURL, "NextURL": data.NextURL})
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
