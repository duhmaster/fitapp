package admin

const (
	layoutHTML = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin – GymMore</title>
  <style>
    * { box-sizing: border-box; }
    body { font-family: system-ui, sans-serif; margin: 0; padding: 16px; background: #f5f5f5; }
    .bar { background: #333; color: #fff; padding: 12px 16px; margin: -16px -16px 16px -16px; display: flex; align-items: center; gap: 16px; }
    .bar a { color: #fff; text-decoration: none; }
    .bar a:hover { text-decoration: underline; }
    .card { background: #fff; border-radius: 8px; padding: 20px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    table { width: 100%; border-collapse: collapse; }
    th, td { text-align: left; padding: 10px; border-bottom: 1px solid #eee; }
    th { background: #fafafa; font-weight: 600; }
    input[type=text], input[type=email], input[type=number], input[type=password], select, textarea { width: 100%; max-width: 400px; padding: 8px; margin: 4px 0; }
    textarea { min-height: 80px; }
    .btn { display: inline-block; padding: 8px 16px; background: #1976d2; color: #fff; border: none; border-radius: 4px; cursor: pointer; text-decoration: none; font-size: 14px; }
    .btn:hover { background: #1565c0; }
    .btn-danger { background: #c62828; }
    .btn-danger:hover { background: #b71c1c; }
    .btn-sm { padding: 4px 10px; font-size: 12px; }
    .msg { padding: 10px; margin-bottom: 16px; border-radius: 4px; }
    .msg.err { background: #ffebee; color: #b71c1c; }
    .msg.ok { background: #e8f5e9; color: #2e7d32; }
    .pagination { margin-top: 16px; }
    .pagination a, .pagination span { margin-right: 8px; }
    .search-form { margin-bottom: 16px; display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
  </style>
</head>
<body>
  {{if .ShowBar}}
  <div class="bar">
    <a href="/admin/dashboard">GymMore Admin</a>
    <a href="/admin/entities/users">Users</a>
    <a href="/admin/entities/gyms">Gyms</a>
    <a href="/admin/entities/exercises">Exercises</a>
    <a href="/admin/entities/programs">Programs</a>
    <a href="/admin/entities/tags">Tags</a>
    <a href="/admin/entities/blog_posts">Blog posts</a>
    <a href="/admin/entities/system_messages">System messages</a>
    <a href="/admin/entities/buckets">Buckets</a>
    <a href="/admin/entities/photos">Photos</a>
    <a href="/admin/entities/gamification/levels">Gamification levels</a>
    <form action="/admin/logout" method="post" style="margin-left:auto;">
      <button type="submit" class="btn btn-sm">Logout</button>
    </form>
  </div>
  {{end}}
  {{if .Flash}}
  <div class="msg {{.FlashClass}}">{{.Flash}}</div>
  {{end}}
  {{template "body" .}}
</body>
</html>`

	loginHTML = `{{define "body"}}
<div class="card" style="max-width: 400px;">
  <h2>Admin login</h2>
  <form method="post" action="/admin/login">
    <label>Login</label>
    <input type="text" name="username" required autofocus>
    <label>Password</label>
    <input type="password" name="password" required>
    <button type="submit" class="btn" style="margin-top:12px;">Sign in</button>
  </form>
</div>
{{end}}`

	dashboardHTML = `{{define "body"}}
<div class="card">
  <h2>Dashboard</h2>
  <p><a href="/admin/entities/users">Users</a> – list, search, edit role</p>
  <p><a href="/admin/entities/gyms">Gyms</a> – list, search, CRUD</p>
  <p><a href="/admin/entities/exercises">Exercises</a> – list, filter, CRUD</p>
  <p><a href="/admin/entities/programs">Programs</a> – list, CRUD</p>
  <p><a href="/admin/entities/tags">Tags</a> – list, create, delete</p>
  <p><a href="/admin/entities/blog_posts">Blog posts</a> – list, CRUD</p>
  <p><a href="/admin/entities/system_messages">System messages</a> – list, CRUD</p>
  <p><a href="/admin/entities/buckets">Buckets</a> – S3 storage reference, CRUD</p>
  <p><a href="/admin/entities/photos">Photos</a> – uploaded images, list, upload, delete</p>
  <p><a href="/admin/entities/gamification/levels">Gamification levels</a> – edit XP thresholds for levels</p>
</div>
{{end}}`

	viewHTML = `{{define "body"}}
<div class="card">
  <h2>{{.Title}}</h2>
  {{.FieldsHTML}}
  <p><a href="{{.CancelURL}}" class="btn">Back</a></p>
</div>
{{end}}`

	uploadFormHTML = `{{define "body"}}
<div class="card">
  <h2>{{.Title}}</h2>
  <form method="post" action="{{.Action}}" enctype="multipart/form-data">
    {{.FieldsHTML}}
    <button type="submit" class="btn">{{.SubmitLabel}}</button>
    <a href="{{.CancelURL}}" class="btn">Cancel</a>
  </form>
</div>
{{end}}`

	listHTML = `{{define "body"}}
<div class="card">
  <h2>{{.Title}}</h2>
  <form class="search-form" method="get" action="{{.ListPath}}">
    <input type="text" name="q" value="{{.SearchQ}}" placeholder="Search">
    {{if .FilterPlaceholder}}<input type="text" name="filter" value="{{.FilterValue}}" placeholder="{{.FilterPlaceholder}}">{{end}}
    <button type="submit" class="btn">Search</button>
  </form>
  <p><a href="{{.NewPath}}" class="btn">New</a></p>
  <table>
    <thead><tr>{{range .Headers}}<th>{{.}}</th>{{end}}<th>Actions</th></tr></thead>
    <tbody>
    {{range .Rows}}
    <tr>{{range .Cells}}<td>{{.}}</td>{{end}}<td>
      <a href="{{$.EditPath}}/{{.ID}}" class="btn btn-sm">Edit</a>
      {{if $.AllowDelete}}<form action="{{$.DeletePath}}/{{.ID}}" method="post" style="display:inline;" onsubmit="return confirm('Delete?');"><button type="submit" class="btn btn-sm btn-danger">Delete</button></form>{{end}}
    </td></tr>
    {{end}}
    </tbody>
  </table>
  {{if .PaginationSummary}}<p class="muted">{{.PaginationSummary}}</p>{{end}}
  <div class="pagination">
  {{if .HasPrev}}<a href="{{.PrevURL}}">Prev</a>{{end}}
  {{if .HasNext}}<a href="{{.NextURL}}">Next</a>{{end}}
  </div>
</div>
{{end}}`

	formHTML = `{{define "body"}}
<div class="card">
  <h2>{{.Title}}</h2>
  <form method="post" action="{{.Action}}">
    {{.FieldsHTML}}
    <button type="submit" class="btn">{{.SubmitLabel}}</button>
    <a href="{{.CancelURL}}" class="btn">Cancel</a>
  </form>
</div>
{{end}}`
)
