extends Control
# Home screen wordmark in the app's own type: a small cyan label, then SYNK set in Fira Sans
# Bold with a slow cyan-to-pink gradient and a soft glow. Drawn in code, so it stays crisp at
# any size and matches the rest of the interface.
const BOLD = preload("res://assets/fonts/FiraSans-Bold.ttf")
const CYAN = Color("ffb3bd")
# Warm stage tones to sit on the red concert footage.
const COLORS = [Color("ffffff"), Color("ffd9de"), Color("ff9aa8"), Color("ff5c74")]

var eyebrow = "CHOOSE YOUR RHYTHM"
var word = "SYNK"
var time = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta
	queue_redraw()

func _draw() -> void:
	var regular = ThemeDB.fallback_font
	var small = roundi(size.y * .085)
	var spaced = " ".join(eyebrow.split(""))
	var width = regular.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	draw_string(regular, Vector2((size.x - width) * .5, small * 1.2), spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, small, CYAN)
	var big = roundi(size.y * .62)
	var gap = big * .06
	var widths: Array = []
	var total = 0.0
	for letter in word:
		var w = BOLD.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
		widths.append(w); total += w
	total += gap * (word.length() - 1)
	var x = (size.x - total) * .5
	var baseline = size.y * .9
	# The gradient drifts slowly across the letters.
	var shift = .5 + .5 * sin(time * .6)
	for i in word.length():
		var t = clampf(float(i) / maxf(1, word.length() - 1) * .85 + shift * .15, 0, 1)
		var color = gradient(t)
		var glow = .22 + .06 * sin(time * 1.6 + i)
		for spread in [10, 6, 3]:
			draw_string_outline(BOLD, Vector2(x, baseline), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, big, spread * 2, Color(color, glow / spread * 2.0))
		draw_string(BOLD, Vector2(x, baseline), word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, big, color.lerp(Color.WHITE, .12))
		x += widths[i] + gap

func gradient(t: float) -> Color:
	var scaled = t * (COLORS.size() - 1)
	var index = mini(int(scaled), COLORS.size() - 2)
	return COLORS[index].lerp(COLORS[index + 1], scaled - index)
