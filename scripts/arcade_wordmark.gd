extends Control
# Album Takeover wordmark: a quiet lowercase "synk" with a four-bar level meter that
# moves to the music. The covers do the shouting; the name stays small.
const Arcade = preload("res://scripts/arcade_style.gd")
var tagline := ""
var text := "SYNK"   # the name it shows (drawn in lowercase)
var time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta; queue_redraw()

func _draw() -> void:
	var fs = int(size.y * .62)
	var font = Arcade.mono_bold()
	draw_string(font, Vector2(0, size.y * .5 + fs * .35), "synk", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Arcade.TEXT)
	var x = font.get_string_size("synk", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * .35
	var base = size.y * .5 + fs * .3
	for i in 4:
		var h = fs * (.2 + .5 * absf(sin(time * (2.6 + i * .9) + i * 1.7)))
		draw_rect(Rect2(x + i * fs * .2, base - h, fs * .1, h), Color(Arcade.TEXT, .75))
	if tagline != "":
		draw_string(Arcade.mono(), Vector2(x + fs * 1.1, base), tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * .4), Arcade.MUTED)
