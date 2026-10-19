extends Control
# Live combo display: a bold number that punches on every hit, a soft glow in the current
# tier's colour, a small caption, and a slim bar filling toward the next milestone.
# Tiers: white below 50, cyan from 50, gold from 100, magenta from 200.
const BOLD = preload("res://assets/fonts/FiraSans-Bold.ttf")
const MILESTONES = [25, 50, 100, 200, 300, 500, 750, 1000]
const TIERS = [[200, Color("ff6ad5")], [100, Color("ffd257")], [50, Color("5fe3ff")], [0, Color("e9e4ff")]]

var combo = 0
var punch = 0.0          # 1 right after a hit, decays to 0
var flare = 0.0          # 1 on a milestone, decays to 0
var caption = "COMBO"
var caption_until = 0
var time = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_combo(value: int) -> void:
	if value > combo: punch = 1.0
	combo = value
	queue_redraw()

func milestone(value: int) -> void:
	flare = 1.0; caption = "%d COMBO" % value; caption_until = Time.get_ticks_msec() + 1400

func tier_color() -> Color:
	for tier in TIERS:
		if combo >= int(tier[0]): return tier[1]
	return Color.WHITE

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta
	punch = move_toward(punch, 0.0, delta * 5.0)
	flare = move_toward(flare, 0.0, delta * 1.4)
	if caption_until > 0 and Time.get_ticks_msec() > caption_until: caption = "COMBO"; caption_until = 0
	queue_redraw()

func _draw() -> void:
	if combo <= 0: return
	var h = size.y
	var tint = tier_color()
	var text = str(combo)
	# Punch: quick overshoot that settles, scaling around the number's centre.
	var bounce = 1.0 + .22 * punch * punch + .1 * flare
	var number_size = roundi(h * .58 * bounce)
	var width = BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x
	var baseline = h * .30 + number_size * .36
	var x = (size.x - width) * .5
	# Glow behind the digits, stronger as the combo climbs and on milestones.
	var heat = clampf(combo / 200.0, .15, 1.0)
	var glow = (.10 + .12 * heat + .18 * flare + .08 * punch) * (.85 + .15 * sin(time * 3.0))
	for spread in [14, 9, 5]:
		draw_string_outline(BOLD, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, spread, Color(tint, glow * (16.0 / spread) * .35))
	# Number: white with a thin tier-coloured edge.
	draw_string_outline(BOLD, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, 3, Color(tint.darkened(.35), .9))
	draw_string(BOLD, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, Color.WHITE.lerp(tint, .15 + .25 * flare))
	# Caption and progress toward the next milestone.
	var caption_size = roundi(h * (.15 if caption == "COMBO" else .17))
	var spaced = " ".join(caption.split("")) if caption == "COMBO" else caption
	var caption_width = BOLD.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x
	var caption_y = h * .80
	draw_string(BOLD, Vector2((size.x - caption_width) * .5, caption_y), spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size,
		Color("ffe08a") if caption != "COMBO" else tint.lerp(Color.WHITE, .4))
	var previous = 0; var next = MILESTONES[-1]
	for m in MILESTONES:
		if combo < m: next = m; break
		previous = m
	var progress = clampf(float(combo - previous) / maxf(1.0, next - previous), 0.0, 1.0)
	var bar_width = maxf(caption_width * 1.3, h * .9); var bar_y = caption_y + h * .07
	var bar = Rect2((size.x - bar_width) * .5, bar_y, bar_width, maxf(2.0, h * .028))
	draw_rect(bar, Color(1, 1, 1, .14))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), Color(tint, .9))
