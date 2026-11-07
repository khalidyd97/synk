extends Control
# Signal Arcade wordmark: SYNK with a cyan/magenta split, a live equalizer under it
# and a small tagline. Drawn in code; the equalizer breathes at 120 BPM.
const Arcade = preload("res://scripts/arcade_style.gd")
var tagline := "CHOOSE YOUR RHYTHM"
var time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta; queue_redraw()

func _draw() -> void:
	var fs = int(size.y * .62)
	var split = 3.0 + 2.0 * maxf(0.0, sin(time * TAU * 2.0)) ** 8   # jolts on the beat
	Arcade.draw_split_text(self, Arcade.HEAD, Vector2(0, fs * .86), "SYNK", fs, Arcade.TEXT, split, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	# Equalizer bars.
	var bars = 26; var bar_w = 6.0; var gap = 4.0
	var total = bars * bar_w + (bars - 1) * gap
	var x0 = (size.x - total) * .5; var base_y = fs * .86 + size.y * .17
	for i in bars:
		var phase = time * (3.0 + float(i * 37 % 7) * .6) + float(i * 13 % 9)
		var h = size.y * .13 * (.25 + .75 * absf(sin(phase)))
		var c = Arcade.CYAN.lerp(Arcade.MAGENTA, float(i) / bars)
		draw_rect(Rect2(x0 + i * (bar_w + gap), base_y - h, bar_w, h), c)
	draw_string(Arcade.mono(), Vector2(0, base_y + size.y * .12), Arcade.spaced(tagline), HORIZONTAL_ALIGNMENT_CENTER, size.x, maxi(12, int(size.y * .065)), Arcade.MUTED)
