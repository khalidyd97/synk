extends CanvasLayer
# Private sign-in for the whole game. local/ssrg_login.json (username + SHA-256 of the password,
# made by tools/make_ssrg_login.py, git-ignored, bundled into local builds) turns it on; without
# that file the game opens normally. Once signed in, the device stays signed in until LOG OUT
# (SSRG Playables header). Drawn above everything, so nothing behind it can be used.
const LOGIN_FILE = "res://local/ssrg_login.json"
const Action = preload("res://scripts/settings_action.gd")
const ACCENT = Color("ffd36a")
const MUTED = Color(.8,.82,.95,.6)
var game: Control
var root: Control
var user_field: LineEdit
var pass_field: LineEdit
var error_label: Label

static func record() -> Dictionary:
	if not FileAccess.file_exists(LOGIN_FILE): return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(LOGIN_FILE))
	return data if data is Dictionary and data.has("user") and data.has("sha256") else {}

static func token(entry: Dictionary) -> String:
	return (str(entry.user) + "|" + str(entry.sha256)).sha256_text()

func required() -> bool: return not record().is_empty()

func unlocked() -> bool:
	var entry = record()
	return entry.is_empty() or str(game.prefs.get_value("ssrg","login","")) == token(entry)

func _ready() -> void:
	layer = 100
	root = Control.new(); add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	preload("res://scripts/modal_input.gd").register(root)
	var dim = ColorRect.new(); place(dim,root,0,0,1,1); dim.color = Color(0.016,0.016,0.026)
	var card = Panel.new(); place(card,root,.33,.14,.67,.86)
	card.add_theme_stylebox_override("panel",box(Color(0.045,0.045,0.06),Color(ACCENT,.55),22))
	label(card,"SYNK",.08,.04,.92,.17,38,Color.WHITE)
	label(card,"Sign in to continue.",.08,.17,.92,.25,15,MUTED)
	user_field = field(card,"Username",.29)
	pass_field = field(card,"Password",.45); pass_field.secret = true
	pass_field.text_submitted.connect(func(_t): try_sign_in())
	user_field.text_submitted.connect(func(_t): pass_field.grab_focus())
	error_label = label(card,"",.08,.59,.92,.68,15,Color("ff8a8a"))
	var sign_in = Action.new(); sign_in.text = "SIGN IN"; sign_in.primary = true; sign_in.caption_size = 22
	place(sign_in,card,.08,.71,.92,.84); sign_in.pressed.connect(try_sign_in)
	root.visible = not unlocked()

func place(node: Control, parent: Control, left: float, top: float, right: float, bottom: float) -> void:
	parent.add_child(node)
	node.anchor_left = left; node.anchor_top = top; node.anchor_right = right; node.anchor_bottom = bottom
	node.offset_left = 0; node.offset_top = 0; node.offset_right = 0; node.offset_bottom = 0

func box(fill: Color, edge: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new(); style.bg_color = fill; style.set_corner_radius_all(radius)
	style.border_color = edge; style.set_border_width_all(1); return style

func label(parent: Control, value: String, left: float, top: float, right: float, bottom: float, size: int, color: Color) -> Label:
	var result = Label.new(); place(result,parent,left,top,right,bottom); result.text = value
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size",size); result.add_theme_color_override("font_color",color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func field(parent: Control, hint: String, top: float) -> LineEdit:
	var result = LineEdit.new(); place(result,parent,.08,top,.92,top+.13)
	result.placeholder_text = hint; result.add_theme_font_size_override("font_size",18)
	var normal = box(Color(1,1,1,.06),Color(1,1,1,.16),14); normal.content_margin_left = 16
	var focus = box(Color(1,1,1,.08),Color(ACCENT,.6),14); focus.content_margin_left = 16
	result.add_theme_stylebox_override("normal",normal); result.add_theme_stylebox_override("focus",focus)
	return result

func try_sign_in() -> void:
	var entry = record()
	if user_field.text.strip_edges() == str(entry.get("user","")) and pass_field.text.sha256_text() == str(entry.get("sha256","")):
		game.prefs.set_value("ssrg","login",token(entry)); game.prefs.save("user://preferences.cfg")
		pass_field.text = ""; error_label.text = ""; root.visible = false
	else:
		error_label.text = "Wrong username or password."; pass_field.text = ""

func sign_out() -> void:
	game.prefs.set_value("ssrg","login",""); game.prefs.save("user://preferences.cfg")
	user_field.text = ""; pass_field.text = ""; error_label.text = ""
	root.visible = not unlocked()
