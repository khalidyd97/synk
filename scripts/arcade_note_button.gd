extends Button
# Album Takeover action. "hot" is the screen's main step: a paper-white disc with a play
# triangle and a big serif word beside it; the disc breathes and sends out a slow ring.
# Others are plain text links: a sans title, a muted line under it, and an underline that
# draws in on hover. No boxes.
const Arcade = preload("res://scripts/arcade_style.gd")

var title := "Play"
var subtitle := "":
	set(v): subtitle = v; queue_redraw()
var hot := false
var accent := Arcade.CYAN
var title_size := 64
var covers: Array = []   # kept for callers that pass recent covers; not drawn
var hover_amount := 0.0
var press_amount := 0.0
var time := 0.0

func _ready() -> void:
	flat = true; focus_mode = Control.FOCUS_ALL; text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(func(): if preload("res://scripts/ui_motion.gd").hover_allowed(): _tween("hover_amount", 1.0, .22))
	mouse_exited.connect(func(): _tween("hover_amount", 0.0, .28))
	button_down.connect(func(): _tween("press_amount", 1.0, .06))
	button_up.connect(func(): _tween("press_amount", 0.0, .22))

func _tween(property: String, value: float, seconds: float) -> void:
	var t = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v): set(property, v); queue_redraw(), float(get(property)), value, seconds)

var hover: float:
	get: return hover_amount

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta
	# Keyboard or controller focus lights the action just like a pointer hover.
	if has_focus() and hover_amount < 1.0: hover_amount = minf(1.0, hover_amount + delta * 5.0); queue_redraw()
	if hot: queue_redraw()

static func sentence(value: String) -> String:
	var lower = value.to_lower()
	return lower.substr(0, 1).to_upper() + lower.substr(1)

func _draw() -> void:
	if hot: _draw_hot()
	else: _draw_link()
	if has_focus():
		Arcade.draw_slant(self, Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(0, 0, 0, 0), Color(Arcade.TEXT, .35), 1.5)

func _draw_hot() -> void:
	var d = minf(size.y * .86, size.x * .4)
	var c = Vector2(d * .5 + 6, size.y * .5)
	var r = d * .5 * (1.0 + .06 * hover_amount - .06 * press_amount)
	# A ring leaves the disc every two beats (120 BPM).
	var t = fmod(time * .5, 1.0)
	draw_arc(c, r + 8.0 + 46.0 * t, 0, TAU, 64, Color(Arcade.TEXT, .35 * (1.0 - t)), 2.0, true)
	var breathe = .5 + .5 * sin(time * TAU * .5)
	draw_circle(c + Vector2(0, 8), r + 2, Color(0, 0, 0, .35))
	draw_circle(c, r + 4.0 * breathe, Color(Arcade.TEXT, .12))
	draw_circle(c, r, Arcade.TEXT.lightened(.05 * hover_amount), true, -1.0, true)
	var k = r * .36
	draw_colored_polygon(PackedVector2Array([c + Vector2(-k * .7, -k), c + Vector2(k * 1.05, 0), c + Vector2(-k * .7, k)]), Arcade.INK)
	var x = c.x + r + 34 + 10 * hover_amount
	var fs = int(title_size * clampf(size.y / 200.0, .5, 1.4))
	var shown = sentence(title)
	while fs > 18 and Arcade.HEAD.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - x - 8: fs -= 2
	var base = size.y * .5 + fs * .28 - (fs * .16 if subtitle != "" else 0.0)
	draw_string(Arcade.HEAD, Vector2(x, base), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Arcade.TEXT)
	if subtitle != "":
		draw_string(Arcade.mono(), Vector2(x + 4, base + fs * .42), subtitle, HORIZONTAL_ALIGNMENT_LEFT, size.x - x, maxi(16, int(fs * .22)), Arcade.MUTED)

func _draw_link() -> void:
	var fs = int(title_size * clampf(size.y / 260.0, .35, .8))
	var shown = sentence(title)
	var font = Arcade.semi()
	while fs > 14 and font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 40: fs -= 2
	var sink = 2.0 * press_amount
	var base = size.y * .5 + fs * .3 - (fs * .4 if subtitle != "" else 0.0) + sink
	var colour = Arcade.TEXT.lerp(Color.WHITE, hover_amount)
	draw_string(font, Vector2(4, base), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, colour)
	var w = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# Underline draws in from the left on hover; an arrow slides out after the word.
	draw_line(Vector2(4, base + fs * .22), Vector2(4 + w * hover_amount, base + fs * .22), Color(Arcade.TEXT, .8), 2.0, true)
	draw_string(font, Vector2(14 + w + 10 * hover_amount, base), "→", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Arcade.TEXT, .35 + .55 * hover_amount))
	if subtitle != "":
		draw_string(Arcade.mono(), Vector2(4, base + fs * .95), subtitle, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, maxi(16, int(fs * .5)), Arcade.MUTED)
