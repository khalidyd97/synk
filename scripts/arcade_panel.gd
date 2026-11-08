extends Panel
# Album Takeover card: a soft frosted pane with rounded corners, no outline.
# Never takes pointer input.
const Arcade = preload("res://scripts/arcade_style.gd")
var accent := Arcade.CYAN
var fill := Color(1, 1, 1, .05)
var bracket := 18.0   # kept for callers; unused

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _draw() -> void:
	var s = StyleBoxFlat.new(); s.bg_color = fill; s.set_corner_radius_all(22); s.anti_aliasing = true; s.corner_detail = 10
	draw_style_box(s, Rect2(Vector2.ZERO, size))
