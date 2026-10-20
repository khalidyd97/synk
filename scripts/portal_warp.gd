extends Control
# Full-screen "portal warp" played when a lobby mode button is tapped.
#   0.00-0.12  the button is squashed and flashes (drawn by the button itself)
#   0.08-0.55  a disc in the button's colour bursts open from its centre to cover the screen,
#              led by a bright rim and two shockwave rings, with speed streaks flying outward
#              and the icon reacting (PLAY: arrows shoot forward; CREATE: notes rush at you)
#   0.50       `arrived` is emitted: the destination screen switches in underneath
#   0.50-0.85  the portal fades away to reveal it
signal arrived
const CIRCLE_NOTE = preload("res://assets/neon/Circle_Note_Reference.png")
var origin = Vector2.ZERO
var start_radius = 100.0
var accent = Color("ff2d55")
var kind = "play"
var t = 0.0
var sent = false
var streaks: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # no double taps while warping
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 70:
		var a = randf() * TAU
		streaks.append({"angle": a, "speed": randf_range(.8, 1.6), "offset": randf_range(0, .25), "width": randf_range(1.5, 4.0)})

func _process(delta: float) -> void:
	t += delta
	if t >= .5 and not sent:
		sent = true; arrived.emit()
	if t >= .85:
		queue_free(); return
	queue_redraw()

func ease_in(x: float) -> float: return pow(clampf(x, 0.0, 1.0), 2.4)
func ease_out(x: float) -> float: return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)

func _draw() -> void:
	var far = maxf((origin - Vector2.ZERO).length(), maxf((origin - size).length(), maxf((origin - Vector2(size.x, 0)).length(), (origin - Vector2(0, size.y)).length())))
	var open = ease_in((t - .08) / .42)
	var reveal = 1.0 - clampf((t - .5) / .35, 0.0, 1.0)
	var r = lerpf(start_radius * .9, far * 1.05, open)
	# Speed streaks racing outward from the portal.
	if t < .6:
		for s in streaks:
			var p = clampf((t - .05) * s.speed * 1.6 - s.offset, 0.0, 1.0)
			if p <= 0.0: continue
			var dir = Vector2.from_angle(s.angle)
			var a = start_radius + p * far * 1.2
			var b = a - (80.0 + 260.0 * p)
			draw_line(origin + dir * maxf(b, start_radius), origin + dir * a, Color(accent.lightened(.5), (1.0 - p) * .8 * reveal), s.width, true)
	# The portal disc: the button's colour fading to black at its heart, with a hot rim.
	if open > 0.0:
		draw_circle(origin, r, Color(accent.darkened(.55), .96 * reveal))
		draw_circle(origin, r * .82, Color(.05, .01, .03, .97 * reveal))
		for layer in [[36.0, .12], [18.0, .3], [6.0, .9]]:
			draw_arc(origin, r, 0, TAU, 128, Color(accent.lightened(.35), layer[1] * reveal), layer[0], true)
		draw_arc(origin, r, 0, TAU, 128, Color(1, .95, .97, .9 * reveal), 2.0, true)
	# Shockwave rings running ahead of the rim.
	for k in 2:
		var q = ease_out((t - .02 - k * .09) / .45)
		if q <= 0.0 or q >= 1.0: continue
		draw_arc(origin, lerpf(start_radius, far * 1.3, q), 0, TAU, 128, Color(1, .9, .95, (1.0 - q) * .7 * reveal), 3.0 + 6.0 * (1.0 - q), true)
	# The icon reacting inside the portal.
	var icon_a = clampf(1.0 - (t - .35) / .3, 0.0, 1.0) * reveal
	if icon_a > 0.0 and open > 0.0:
		if kind == "play":
			# A train of chevrons shooting forward out of the centre.
			for i in 4:
				var x = (t * 2600.0 - i * 120.0)
				if x < 0: continue
				var c = origin + Vector2(x * .6, 0)
				var s = 40.0 + x * .08
				draw_polyline(PackedVector2Array([c + Vector2(-s * .5, -s), c + Vector2(s * .5, 0), c + Vector2(-s * .5, s)]), Color(1, 1, 1, icon_a * (1.0 - i * .2)), 8.0, true)
		else:
			# The sequencer lanes expand out of the pad into Chart Studio.
			var spread = lerpf(start_radius * .45, far * .85, open)
			var top = origin - Vector2(0, spread * .48)
			for lane in [-1.0, -.333, .333, 1.0]:
				var from = top + Vector2(lane * spread * .26, 0)
				var to = origin + Vector2(lane * spread, spread * .55)
				draw_line(from, to, Color(accent, icon_a * .2), 12.0, true)
				draw_line(from, to, Color(1, .6, .8, icon_a * .85), 2.5, true)
			draw_line(origin + Vector2(-spread, spread * .55), origin + Vector2(spread, spread * .55), Color(1, .8, .9, icon_a), 5.0, true)
			# Notes rushing toward the camera from the portal's heart.
			for i in 6:
				var a = TAU * i / 6.0 + .4
				var z = clampf((t - .1 - i * .03) / .45, 0.0, 1.0)
				var w = lerpf(30.0, 260.0, z * z)
				var p = origin + Vector2.from_angle(a) * z * far * .45
				var h = w * CIRCLE_NOTE.get_height() / CIRCLE_NOTE.get_width()
				draw_texture_rect(CIRCLE_NOTE, Rect2(p - Vector2(w, h) * .5, Vector2(w, h)), false, Color(1, 1, 1, icon_a * (1.0 - z * .6)))
	# Full-screen flash as the portal swallows the screen.
	var flash = clampf(1.0 - abs(t - .48) / .06, 0.0, 1.0)
	if flash > 0.0: draw_rect(Rect2(Vector2.ZERO, size), Color(1, .92, .95, .35 * flash))
