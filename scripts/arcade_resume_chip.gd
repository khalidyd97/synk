extends Button
# Home hero: "Pick up where you left off" and the song's name set big in the serif,
# its second line in italic. Tapping it opens the song list on that song.
const Arcade = preload("res://scripts/arcade_style.gd")
var label := "Pick up where you left off":
	set(v): label = v; queue_redraw()
var song := "":
	set(v): song = v; queue_redraw()
var detail := "":
	set(v): detail = v; queue_redraw()
var hover_amount := 0.0

func _ready() -> void:
	flat = true; text = ""; focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(func(): if preload("res://scripts/ui_motion.gd").hover_allowed(): _hover(1.0))
	mouse_exited.connect(func(): _hover(0.0))

func _hover(value: float) -> void:
	var t = create_tween(); t.tween_method(func(v): hover_amount = v; queue_redraw(), hover_amount, value, .25)

# Splits a title into two balanced lines at a space.
static func two_lines(value: String) -> Array:
	var words = value.split(" ", false)
	if words.size() < 2: return [value, ""]
	var best = 1; var best_gap = INF
	for i in range(1, words.size()):
		var a = " ".join(words.slice(0, i)); var b = " ".join(words.slice(i))
		var gap = absf(a.length() - b.length())
		if gap < best_gap: best_gap = gap; best = i
	return [" ".join(words.slice(0, best)), " ".join(words.slice(best))]

func _draw() -> void:
	var cap = maxi(16, int(size.y * .065))
	draw_string(Arcade.semi(), Vector2(0, cap), label, HORIZONTAL_ALIGNMENT_LEFT, size.x, cap, Arcade.MUTED)
	var lines = two_lines(song)
	var fs = int(size.y * .36)
	for line in lines:
		while fs > 24 and Arcade.SERIF_ITALIC.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 20: fs -= 2
	var y = cap + fs * 1.0
	var x = 10.0 * hover_amount
	draw_string(Arcade.SERIF, Vector2(x - 4, y), lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Arcade.TEXT)
	if lines[1] != "":
		y += fs * .92
		draw_string(Arcade.SERIF_ITALIC, Vector2(x - 4, y), lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Arcade.TEXT)
	if detail != "":
		draw_string(Arcade.mono(), Vector2(0, y + cap * 2.0), detail, HORIZONTAL_ALIGNMENT_LEFT, size.x, int(cap * 1.1), Color(Arcade.TEXT, .7))
