extends Button
# "Resume" chip on the home screen: a pulsing signal dot, a mono label and the song.
const Arcade = preload("res://scripts/arcade_style.gd")
var label := "RESUME"
var song := "":
	set(v): song = v; queue_redraw()
var time := 0.0
var hover_amount := 0.0

func _ready() -> void:
	flat = true; text = ""; focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(func(): hover_amount = 1.0; queue_redraw())
	mouse_exited.connect(func(): hover_amount = 0.0; queue_redraw())

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta; queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2(4, 4), size - Vector2(8, 8))
	Arcade.draw_slant(self, rect, Color(Arcade.INK, .8), Color(Arcade.CYAN, .45 + .4 * hover_amount), 1.5, rect.size.y * .2)
	var cy = rect.get_center().y
	var dot = Vector2(rect.position.x + 30, cy)
	var t = fmod(time * 2.0, 1.0)
	draw_arc(dot, 7.0 + 12.0 * t, 0, TAU, 28, Color(Arcade.CYAN, 1.0 - t), 2.0, true)
	draw_circle(dot, 7.0, Arcade.CYAN)
	var x = dot.x + 24
	var small = maxi(12, int(rect.size.y * .26))
	draw_string(Arcade.mono(), Vector2(x, cy + small * .35), Arcade.spaced(label), HORIZONTAL_ALIGNMENT_LEFT, -1, small, Arcade.MUTED)
	var lw = Arcade.mono().get_string_size(Arcade.spaced(label), HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	var big = maxi(16, int(rect.size.y * .4))
	draw_string(Arcade.HEAD, Vector2(x + lw + 16, cy + big * .36), song.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, rect.end.x - (x + lw + 30), big, Arcade.TEXT)
