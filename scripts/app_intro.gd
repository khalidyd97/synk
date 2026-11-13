extends Control
# Start-up loader in the Album Takeover look (about 2.6 s, tap to skip):
#   0.0-0.5  a warm hairline opens from the centre of the dark ink screen
#   0.25-1.0 "Synk" rises letter by letter out of the line, the S in coral italic
#   0.5-2.0  the line becomes a slim loading bar under a sentence-case status
#   0.9-1.4  "Choose your rhythm" fades up in muted serif italic
#   2.05-2.6 the wordmark lifts away and the ink clears into the lobby underneath
signal finished
signal revealing   # the backdrop starts clearing: the lobby should animate in now
const A = preload("res://scripts/arcade_style.gd")
const LENGTH = 2.6
const STATUS = ["Tuning in", "Loading your songs", "Ready"]
var revealed = false
var done = false
var t = 0.0
var glow: GradientTexture2D

func _ready() -> void:
	preload("res://scripts/modal_input.gd").register(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# One soft radial light, so the glow has no rings.
	var g = Gradient.new()
	g.set_color(0, Color(A.MAGENTA, .30)); g.set_color(1, Color(A.MAGENTA, 0.0))
	g.add_point(.45, Color(A.MAGENTA_DEEP, .10))
	glow = GradientTexture2D.new(); glow.gradient = g; glow.width = 256; glow.height = 256
	glow.fill = GradientTexture2D.FILL_RADIAL; glow.fill_from = Vector2(.5, .5); glow.fill_to = Vector2(1, .5)

func _gui_input(event: InputEvent) -> void:
	# Any tap skips straight to the exit.
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed and t < LENGTH - .55:
		t = LENGTH - .55

func _process(delta: float) -> void:
	t += delta
	if t >= LENGTH - .45 and not revealed:
		revealed = true; revealing.emit()
	if t >= LENGTH and not done:
		done = true; finished.emit(); queue_free(); return
	queue_redraw()

func ease_out(x: float) -> float: return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)
func ease_in_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 4.0 * x * x * x if x < .5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) * .5

# How far the loading bar has filled: quick at first, easing into the finish.
func progress() -> float:
	return ease_in_out((t - .5) / 1.5)

func status_text() -> String:
	var p = progress()
	return STATUS[2] if p >= 1.0 else (STATUS[1] if p > .35 else STATUS[0])

func _draw() -> void:
	var h = size.y
	var c = size * .5
	# The wordmark leaves first, then the ink clears to the lobby.
	var leave = ease_out((t - (LENGTH - .55)) / .35)
	var fade = 1.0 - leave
	var backdrop = 1.0 - clampf((t - (LENGTH - .45)) / .45, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(A.INK, backdrop))
	if fade <= 0.0: return
	# A coral light that breathes behind the wordmark.
	var breathe = .92 + .08 * sin(t * 3.2)
	var light = ease_out(t / .8) * fade
	var gs = Vector2(h * 1.6, h * 1.1) * breathe
	draw_texture_rect(glow, Rect2(Vector2(c.x - gs.x * .5, c.y - h * .06 - gs.y * .5), gs), false, Color(1, 1, 1, light))

	var lift = -h * .03 * leave
	var base_y = c.y + h * .03 + lift
	var word_size = roundi(h * .24)
	# The hairline: opens from the centre, then settles into the loading track.
	var open = ease_out(t / .5)
	var settle = ease_out((t - .45) / .45)
	var track_w = lerpf(size.x * .62, minf(size.x * .26, h * .62), settle) * open
	var track_y = base_y + h * lerpf(.035, .14, settle)
	var track_h = maxf(1.5, h * .0035)
	draw_rect(Rect2(c.x - track_w * .5, track_y - track_h * .5, track_w, track_h), Color(A.TEXT, lerpf(.55, .14, settle) * fade))
	if settle > 0.0:
		var fill_w = track_w * progress()
		draw_rect(Rect2(c.x - track_w * .5, track_y - track_h * .5, fill_w, track_h), Color(A.MAGENTA, fade * settle))
		if fill_w > 1.0 and progress() < 1.0:
			draw_circle(Vector2(c.x - track_w * .5 + fill_w, track_y), track_h * 1.6, Color(A.TEXT, fade * settle))

	# "Synk": each letter rises out of the line, the S in coral italic.
	var letters = ["S", "y", "n", "k"]
	var fonts = [A.SERIF_ITALIC, A.SERIF, A.SERIF, A.SERIF]
	var widths: Array = []
	var total = 0.0
	for i in letters.size():
		var w = fonts[i].get_string_size(letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, word_size).x
		widths.append(w); total += w
	var x = c.x - total * .5
	for i in letters.size():
		var appear = ease_out((t - .25 - i * .09) / .5)
		if appear > 0.0:
			var col = A.MAGENTA if i == 0 else A.TEXT
			var pos = Vector2(x, base_y + (1.0 - appear) * h * .06)
			draw_string(fonts[i], pos, letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, word_size, Color(col, appear * fade))
		x += widths[i]

	# Tagline under the wordmark.
	var tag_a = ease_out((t - .9) / .5) * fade
	if tag_a > 0.0:
		var tag = "Choose your rhythm"
		var ts = roundi(h * .042)
		var tw = A.SERIF_ITALIC.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		draw_string(A.SERIF_ITALIC, Vector2(c.x - tw * .5, base_y + h * .085 + (1.0 - tag_a) * h * .01), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(A.MUTED, tag_a))

	# Status and percent at either end of the bar.
	var info_a = ease_out((t - .6) / .4) * fade
	if info_a > 0.0:
		var fs = roundi(h * .024)
		var font = A.sans(500)
		var left = c.x - track_w * .5
		var y = track_y + h * .05
		draw_string(font, Vector2(left, y), status_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(A.SUBTLE, info_a))
		var pct = "%d%%" % roundi(progress() * 100.0)
		draw_string(font, Vector2(left, y), pct, HORIZONTAL_ALIGNMENT_RIGHT, track_w, fs, Color(A.DIM, info_a))
