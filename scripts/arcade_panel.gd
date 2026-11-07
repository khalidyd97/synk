extends Panel
# Signal Arcade panel: dark glass with a hairline edge, bright corner brackets and a
# short signal bar on the top edge. Never takes pointer input.
const Arcade = preload("res://scripts/arcade_style.gd")
var accent := Arcade.CYAN
var fill := Color(Arcade.NIGHT, .9)
var bracket := 18.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	draw_rect(r, fill)
	draw_rect(r, Color(accent, .18), false, 1.0)
	var c = Color(accent, .85); var b = minf(bracket, minf(size.x, size.y) * .25); var w = 2.0
	for corner in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), size]:
		var sx = 1.0 if corner.x == 0 else -1.0; var sy = 1.0 if corner.y == 0 else -1.0
		draw_line(corner, corner + Vector2(b * sx, 0), c, w)
		draw_line(corner, corner + Vector2(0, b * sy), c, w)
	draw_rect(Rect2(b + 10, -1, minf(90.0, size.x * .25), 3), Arcade.MAGENTA)
