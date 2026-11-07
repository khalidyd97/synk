extends Button
# Signal Arcade action: a big slanted note plate with a title and a small mono
# subtitle. "hot" plates are magenta with a pulsing neon halo (the main action);
# others are deep navy with a cyan edge. Used on the home screen and as the main
# action on other menu screens.
const Arcade = preload("res://scripts/arcade_style.gd")

var title := "PLAY"
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
	mouse_entered.connect(func(): _tween("hover_amount", 1.0, .16))
	mouse_exited.connect(func(): _tween("hover_amount", 0.0, .22))
	button_down.connect(func(): _tween("press_amount", 1.0, .06))
	button_up.connect(func(): _tween("press_amount", 0.0, .18))

func _tween(property: String, value: float, seconds: float) -> void:
	var t = create_tween(); t.tween_method(func(v): set(property, v); queue_redraw(), float(get(property)), value, seconds)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta
	if hot: queue_redraw()

func _draw() -> void:
	var sink = 3.0 * press_amount
	var rect = Rect2(Vector2(8, 8 + sink), size - Vector2(16, 18))
	var shift = Arcade.shift_for(rect.size.y)
	if hot:
		var pulse = .75 + .25 * sin(time * TAU * 2.0)   # 120 BPM breathing
		Arcade.draw_glow(self, rect, Arcade.MAGENTA, (1.1 + .5 * hover_amount) * pulse, shift)
	elif hover_amount > 0.0:
		Arcade.draw_glow(self, rect, accent, .7 * hover_amount, shift)
	Arcade.draw_slant(self, Rect2(rect.position + Vector2(0, lerpf(6.0, 2.0, press_amount)), rect.size), Color(0, 0, 0, .55), Color(0, 0, 0, 0), 0.0, shift)
	if hot:
		Arcade.draw_slant_gradient(self, rect, Arcade.MAGENTA.lightened(.08 * hover_amount), Arcade.MAGENTA_DEEP, shift)
		Arcade.draw_slant(self, rect.grow(5), Color(0, 0, 0, 0), Color(Arcade.MAGENTA, .9), 2.0, shift)
	else:
		Arcade.draw_slant_gradient(self, rect, Arcade.PANEL.lightened(.06 * hover_amount), Arcade.NIGHT, shift)
		Arcade.draw_slant(self, rect.grow(5), Color(0, 0, 0, 0), Color(accent, .55 + .45 * hover_amount), 2.0, shift)
	Arcade.draw_slant(self, rect, Color(0, 0, 0, 0), Color(1, 1, 1, .22 if hot else .08), 1.0, shift)
	# Diagonal light streaks inside the plate.
	for i in 3:
		var x = rect.position.x + rect.size.x * (.55 + i * .12) + fmod(time * 40.0, rect.size.x * .3) * (1.0 if hot else 0.0)
		draw_line(Vector2(x + shift * .9, rect.position.y + 4), Vector2(x - shift * .1 + 10, rect.end.y - 4), Color(1, 1, 1, .05), 6.0)
	var font = Arcade.HEAD
	var fs = int(title_size * clampf(rect.size.y / 140.0, .55, 1.2))
	var room = rect.size.x - shift * 2.0 - 28.0
	while fs > 14 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room: fs -= 2
	var text_color = Color.WHITE if hot else accent
	var block_h = fs * .9 + (fs * .3 if subtitle != "" else 0.0)
	var baseline = rect.position.y + (rect.size.y - block_h) * .5 + fs * .82
	draw_string(font, Vector2(rect.position.x, baseline), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, text_color)
	if subtitle != "":
		var sub_size = maxi(12, int(fs * .22))
		var sub = Arcade.spaced(subtitle.to_upper()) if subtitle.length() < 26 else subtitle.to_upper()
		draw_string(Arcade.mono(), Vector2(rect.position.x, baseline + sub_size * 1.7), sub, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, sub_size, Color(1, .9, .96, .9) if hot else Arcade.MUTED)
	if has_focus():
		Arcade.draw_slant(self, rect.grow(9), Color(0, 0, 0, 0), Color(Arcade.TEXT, .5), 1.0, shift)
