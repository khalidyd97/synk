extends Control
# Start-up intro, drawn in code to match the app icon (about 2.6 s, tap to skip):
#   0.0-0.5  a sound wave rises from the centre line
#   0.3-0.9  the italic "S" pops in with a red glow, the wave cutting across it
#   0.9-1.6  sparks burst; the S slides left as "YNK" types in beside it, tagline fades up
#   2.1-2.6  everything fades into the lobby underneath
signal finished
signal revealing   # the backdrop starts clearing: the lobby should animate in now
var revealed = false
const BOLD = preload("res://assets/fonts/FiraSans-Bold.ttf")
const RED = Color("ff2d55")
const LENGTH = 2.6
var t = 0.0
var sparks: Array = []
var burst_done = false
var done = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _gui_input(event: InputEvent) -> void:
	# Any tap skips straight to the fade.
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed and t < LENGTH - .75:
		t = LENGTH - .75

func _process(delta: float) -> void:
	t += delta
	if t > .95 and not burst_done:
		burst_done = true
		var c = size * .5
		for i in 48:
			var a = randf() * TAU; var sp = randf_range(200, 700) * size.y / 900.0
			sparks.append({"pos": c, "vel": Vector2(cos(a), sin(a)) * sp, "life": randf_range(.4, 1.0), "max": 1.0})
	for s in sparks:
		s.pos += s.vel * delta; s.vel *= pow(.2, delta); s.vel.y += 120.0 * delta; s.life -= delta
	sparks = sparks.filter(func(s): return s.life > 0.0)
	if t >= LENGTH - .5 and not revealed:
		revealed = true; revealing.emit()
	if t >= LENGTH and not done:
		done = true; finished.emit(); queue_free(); return
	queue_redraw()

func ease_out(x: float) -> float: return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)
func back_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0); var k = 1.7
	return 1.0 + (k + 1.0) * pow(x - 1.0, 3.0) + k * pow(x - 1.0, 2.0)

func _draw() -> void:
	# The wordmark leaves first (slight zoom-out), then the dark backdrop clears to the lobby.
	var fade = 1.0 - clampf((t - (LENGTH - .75)) / .3, 0.0, 1.0)
	var backdrop = 1.0 - clampf((t - (LENGTH - .45)) / .45, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, backdrop))  # same black as the launch splash
	if fade <= 0.0: return
	var h = size.y
	var c = size * .5
	# Soft wine glow behind everything.
	for i in 6:
		draw_circle(c, h * (.55 - i * .07), Color(.25, .02, .08, .05 * fade))
	# The S slides left once the wordmark starts typing in.
	var slide = ease_out((t - 1.0) / .55)
	var letter_size = roundi(h * .42)
	var word = "YNK"
	var word_w = BOLD.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size).x
	var s_w = BOLD.get_string_size("S", HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size).x
	var s_center = Vector2(c.x - (word_w * .5 + h * .015) * slide, c.y)
	# Sound wave.
	var grow = ease_out(t / .5)
	var bars = 27
	var span = h * .62
	for i in bars:
		var u = float(i) / (bars - 1) - .5
		var env = 1.0 - pow(abs(u) * 2.0, 1.5)
		var bar = h * .2 * env * grow * (.45 + .55 * abs(sin(t * 6.0 + i * 1.7)))
		var x = s_center.x + u * span * (1.0 - .35 * slide)
		draw_line(Vector2(x, c.y - bar * .5), Vector2(x, c.y + bar * .5), Color(1, .82, .86, .9 * fade * (1.0 - .6 * slide)), maxf(2.0, h * .006), true)
	# The S: pops in with an overshoot, glowing red, slanted like italic.
	var pop = back_out((t - .3) / .45)
	if pop > 0.0:
		var shear = Transform2D(Vector2(1, 0), Vector2(-.2, 1), Vector2.ZERO)
		var scale_now = pop
		var xf = Transform2D(0.0, Vector2.ONE * scale_now, 0.0, s_center) * shear
		draw_set_transform_matrix(xf)
		var origin = Vector2(-s_w * .5, letter_size * .36)
		for spread in [26, 16, 9]:
			draw_string_outline(BOLD, origin, "S", HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size, spread, Color(RED, .18 * fade))
		draw_string(BOLD, origin, "S", HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size, Color(1, .93, .95, fade))
		draw_set_transform(Vector2.ZERO)
	# "YNK" types in beside the S, one letter at a time.
	if t > 1.05:
		var x = s_center.x + s_w * .5 + h * .01
		for i in word.length():
			var appear = clampf((t - 1.05 - i * .12) / .18, 0.0, 1.0)
			if appear <= 0.0: break
			var ch = word[i]
			var cw = BOLD.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size).x
			var col = Color(1, .95 - .35 * (i + 1) / 3.0, .96 - .3 * (i + 1) / 3.0, appear * fade)
			var pos = Vector2(x, c.y + letter_size * .36 + (1.0 - appear) * h * .04)
			draw_string_outline(BOLD, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size, 14, Color(RED, .14 * appear * fade))
			draw_string(BOLD, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size, col)
			x += cw
	# Tagline.
	var tag_a = clampf((t - 1.5) / .4, 0.0, 1.0) * fade
	if tag_a > 0.0:
		var tag = " ".join("CHOOSE YOUR RHYTHM".split(""))
		var ts = roundi(h * .028)
		var tw = BOLD.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		draw_string(BOLD, Vector2(c.x - tw * .5, c.y + letter_size * .62), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(.86, .74, .8, tag_a))
	# Sparks.
	for s in sparks:
		var a = clampf(s.life / s.max, 0.0, 1.0) * fade
		draw_line(s.pos, s.pos - s.vel * .04, Color(1, .6, .45, a), 2.5, true)
		draw_circle(s.pos, 2.0, Color(1, .95, .85, a))
