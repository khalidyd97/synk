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
# Multiplier-up effect (every full 100 combo): shockwave rings, gold light rays, a burst of
# sparks and a "×1.2" badge that pops in over the number, holds, then floats up and fades.
const GOLD = Color("ffd257")
var wave = 0.0           # 1 when the multiplier steps up, decays to 0
var badge_age = -1.0     # seconds since the badge appeared; < 0 when hidden
var badge_text = ""
var sparks: Array = []   # {pos, vel, life}

func multiplier() -> float: return minf(2.0, 1.0 + .1 * floori(combo / 100.0))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_combo(value: int) -> void:
	if value > combo: punch = 1.0
	var stepped = value > combo and floori(value / 100.0) > floori(combo / 100.0) and value <= 1000
	combo = value
	if stepped: multiplier_up()
	queue_redraw()

func milestone(value: int) -> void:
	flare = 1.0; caption = "%d COMBO" % value; caption_until = Time.get_ticks_msec() + 1400

func multiplier_up() -> void:
	wave = 1.0; flare = 1.0; badge_age = 0.0
	badge_text = "×%.1f" % multiplier()
	var c = Vector2(size.x * .5, size.y * .30)
	for i in 40:
		var a = randf() * TAU; var speed = size.y * .55 * randf_range(2.5, 5.5)
		sparks.append({"pos": c, "vel": Vector2(cos(a), sin(a)) * speed, "life": randf_range(.5, .9)})

func tier_color() -> Color:
	for tier in TIERS:
		if combo >= int(tier[0]): return tier[1]
	return Color.WHITE

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta
	punch = move_toward(punch, 0.0, delta * 5.0)
	flare = move_toward(flare, 0.0, delta * 1.4)
	wave = move_toward(wave, 0.0, delta * 1.1)
	if badge_age >= 0.0:
		badge_age += delta
		if badge_age > 1.6: badge_age = -1.0
	for spark in sparks:
		spark.pos += spark.vel * delta; spark.vel *= pow(.12, delta); spark.vel.y += size.y * .66 * delta
		spark.life -= delta
	sparks = sparks.filter(func(sp): return sp.life > 0.0)
	if caption_until > 0 and Time.get_ticks_msec() > caption_until: caption = "COMBO"; caption_until = 0
	queue_redraw()

func _draw() -> void:
	if combo <= 0: return
	var h = size.y
	var tint = tier_color()
	var text = str(combo)
	# Punch: quick overshoot that settles, scaling around the number's centre.
	# The font size stays fixed (one glyph cache); the punch is a transform scale instead,
	# because a new font size every frame re-rasterises the glyphs and is slow on phones.
	var bounce = 1.0 + .22 * punch * punch + .1 * flare
	var number_size = roundi(h * .58)
	var width = BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size).x
	var baseline = h * .30 + number_size * .36
	var x = (size.x - width) * .5
	var c = Vector2(size.x * .5, h * .30)
	# Effects keep their original scale; only the number and caption grew.
	var fx = h * .55
	if wave > 0.0:
		# Slowly turning light rays behind everything.
		var spin = time * .6
		for i in 12:
			var a = spin + i * TAU / 12.0; var w = .09
			var reach = fx * (1.2 + 2.2 * (1.0 - wave)) * (1.0 if i % 2 == 0 else .7)
			var pts = PackedVector2Array([c, c + Vector2(cos(a - w), sin(a - w)) * reach, c + Vector2(cos(a + w), sin(a + w)) * reach])
			draw_colored_polygon(pts, Color(GOLD, .3 * wave))
		# Two shockwave rings racing outward, thick and bright at first.
		for k in 2:
			var t = ease(clampf(1.0 - wave - k * .15, 0.0, 1.0), .5)
			if t <= 0.0: continue
			var r = fx * (.3 + 2.8 * t)
			draw_arc(c, r, 0, TAU, 72, Color(GOLD, (1.0 - t) * .4), 26.0 * (1.0 - t) + 4.0, true)
			draw_arc(c, r, 0, TAU, 72, Color(Color("fff6d8"), (1.0 - t) * .95), 2.0 + 4.0 * (1.0 - t), true)
	for spark in sparks:
		var fade = clampf(spark.life / .5, 0.0, 1.0)
		draw_line(spark.pos, spark.pos - spark.vel * .045, Color(GOLD, fade), 4.0, true)
		draw_circle(spark.pos, 3.5, Color(1, .97, .85, fade))
	var pivot = Vector2(size.x * .5, h * .30)
	draw_set_transform(pivot - pivot * bounce, 0.0, Vector2.ONE * bounce)
	# Glow behind the digits, stronger as the combo climbs and on milestones.
	var heat = clampf(combo / 200.0, .15, 1.0)
	var glow = (.10 + .12 * heat + .18 * flare + .08 * punch) * (.85 + .15 * sin(time * 3.0))
	for spread in [14, 9, 5]:
		draw_string_outline(BOLD, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, spread, Color(tint, glow * (16.0 / spread) * .35))
	# Number: white with a thin tier-coloured edge.
	draw_string_outline(BOLD, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, 3, Color(tint.darkened(.35), .9))
	draw_string(BOLD, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, Color.WHITE.lerp(tint, .15 + .25 * flare))
	draw_set_transform(Vector2.ZERO)
	# Caption and progress toward the next milestone.
	var caption_size = roundi(h * (.15 if caption == "COMBO" else .17))
	var spaced = " ".join(caption.split("")) if caption == "COMBO" else caption
	# Score multiplier earned every 100 combo (see main.gd combo_multiplier).
	var mult = minf(2.0, 1.0 + .1 * floori(combo / 100.0))
	if caption == "COMBO" and mult > 1.0: spaced += "   ×%.1f" % mult
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
	# The multiplier badge: pops in with an overshoot above the number, then floats up and fades.
	if badge_age >= 0.0:
		var pop = 1.0 + .6 * exp(-badge_age * 9.0) * cos(badge_age * 22.0) if badge_age < .5 else 1.0
		var grow = clampf(badge_age / .12, 0.0, 1.0)
		var rise = maxf(0.0, badge_age - 1.0) * h * .5
		var alpha = 1.0 - clampf((badge_age - 1.1) / .5, 0.0, 1.0)
		var scale_now = pop * grow
		var bsize = roundi(fx * .48)
		if scale_now > .02:
			var by0 = h * -.1 - rise
			var anchor = Vector2(c.x, by0 - bsize * .3)
			draw_set_transform(anchor - anchor * scale_now, 0.0, Vector2.ONE * scale_now)
			var label = "SCORE " + badge_text
			var bw = BOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, bsize).x
			var by = by0
			var plate = Rect2(c.x - bw * .5 - bsize * .45, by - bsize * .95, bw + bsize * .9, bsize * 1.3)
			var box = StyleBoxFlat.new(); box.bg_color = Color(.12, .08, 0, .75 * alpha); box.set_corner_radius_all(int(plate.size.y * .5))
			box.border_color = Color(GOLD, alpha); box.set_border_width_all(2); box.shadow_color = Color(GOLD, .45 * alpha); box.shadow_size = 14
			draw_style_box(box, plate)
			draw_string(BOLD, Vector2(c.x - bw * .5, by), label, HORIZONTAL_ALIGNMENT_LEFT, -1, bsize, Color(Color("fff3c4"), alpha))
			draw_set_transform(Vector2.ZERO)
