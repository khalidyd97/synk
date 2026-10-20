extends Button
# Lobby portal button, drawn entirely in code so every part can animate:
# a circular frame with a double neon outline whose border pulses (and sends rings outward), a glossy dark panel,
# an animated icon (PLAY: sound wave into a play arrow; CREATE: waveform with mixer sliders),
# a slanted italic caption, sparks thrown off the corners and flickering glitch dashes.
const BOLD = preload("res://assets/fonts/FiraSans-Bold.ttf")
var kind = "play"            # "play" or "create"
var caption = "PLAY"
var accent = Color("ff2d55")
var time = 0.0
var hover = 0.0
var press = 0.0
var sparks: Array = []       # {pos, vel, life, max}
var glitches: Array = []     # {y, x, w, life}
var spark_timer = 0.0
var warping = false
signal activated   # emitted when the portal warp reaches its destination (use instead of pressed)

func _ready() -> void:
	text = ""; focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button_down.connect(func():
		press = 1.0
		for i in 18: emit_spark(true))
	time = randf() * 10.0
	pressed.connect(warp)

# Tapping opens a full-screen portal from this button (portal_warp.gd); the destination
# screen appears when it arrives.
func warp() -> void:
	if warping: return
	warping = true
	preload("res://scripts/ui_sound.gd").play(self, "whoosh")
	var layer = CanvasLayer.new(); layer.layer = 95; get_tree().root.add_child(layer)
	var fx = preload("res://scripts/portal_warp.gd").new()
	var xf = get_global_transform_with_canvas()
	fx.origin = xf * (size * .5); fx.start_radius = radius() * xf.get_scale().x
	fx.accent = accent; fx.kind = kind
	layer.add_child(fx)
	fx.arrived.connect(func(): warping = false; activated.emit())
	fx.tree_exited.connect(func(): layer.queue_free())

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_READY: set_process(is_visible_in_tree())

# Circular outline, inset by `inset` pixels, closed (last point repeats the first).
func radius() -> float: return minf(size.x, size.y) * .5
func hex(inset: float) -> PackedVector2Array:
	var c = size * .5; var r = radius() - inset
	var pts = PackedVector2Array()
	for i in 97: pts.append(c + Vector2.from_angle(TAU * i / 96.0) * r)
	return pts

func emit_spark(burst := false) -> void:
	# Sparks leave from the upper-right and lower-left corners, like welding sparks.
	var upper = randf() < .5
	var angle = (-PI * .25 if upper else PI * .75) + randf_range(-.25, .25)
	var origin = size * .5 + Vector2.from_angle(angle) * radius()
	var dir = Vector2(randf_range(.2, 1.0), randf_range(-1.0, -.2)) if upper else Vector2(randf_range(-1.0, -.2), randf_range(.2, 1.0))
	var speed = randf_range(120, 360) * (1.6 if burst else 1.0)
	var life = randf_range(.35, .8)
	sparks.append({"pos": origin, "vel": dir.normalized() * speed, "life": life, "max": life})

func _process(delta: float) -> void:
	time += delta
	hover = lerpf(hover, 1.0 if is_hovered() else 0.0, 1.0 - exp(-delta * 12.0))
	press = move_toward(press, 0.0, delta * 3.0)
	spark_timer -= delta
	if spark_timer <= 0.0:
		spark_timer = randf_range(.012, .04) * (0.6 if hover > .5 else 1.0)
		emit_spark()
	for s in sparks:
		s.pos += s.vel * delta; s.vel.y += 260.0 * delta; s.vel *= pow(.35, delta); s.life -= delta
	sparks = sparks.filter(func(s): return s.life > 0.0)
	if randf() < delta * 6.0:
		var right = randf() < .5
		glitches.append({"y": randf_range(.15, .85), "x": (1.0 + randf_range(.02, .1)) if right else randf_range(-.1, -.02), "w": randf_range(10, 46), "life": randf_range(.08, .3)})
	for g in glitches: g.life -= delta
	glitches = glitches.filter(func(g): return g.life > 0.0)
	queue_redraw()

func _draw() -> void:
	var breathe = .5 + .5 * sin(time * 2.4)
	var glow = .55 + .25 * breathe + .35 * hover + .4 * press
	var lift = 1.0 + .03 * hover - .03 * press
	var pivot = size * .5
	draw_set_transform(pivot - pivot * lift, 0.0, Vector2.ONE * lift)
	# Soft outer glow: the frame drawn several times, wide and faint.
	var outer = hex(0)
	for layer in [[46.0, .04], [30.0, .07], [18.0, .12], [10.0, .2]]:
		draw_polyline(outer, Color(accent, layer[1] * glow * 1.6), layer[0], true)
	# Panel: dark glassy fill with a light sheen across the top half.
	var inner = hex(14)
	var fill = inner.duplicate(); fill.remove_at(fill.size() - 1)
	draw_colored_polygon(fill, Color(.07, .05, .07, .92))
	# Sheen over the upper half of the disc.
	var sheen = PackedVector2Array()
	for i in range(48, 97): sheen.append(inner[i % 96])
	draw_colored_polygon(sheen, Color(1, 1, 1, .07 + .04 * hover))
	# Light sweeping across the panel every few seconds.
	var sweep = fmod(time * .35, 1.6) - .3
	if sweep > 0.0 and sweep < 1.0:
		var x = lerpf(size.x * .3, size.x * .7, sweep)
		draw_line(Vector2(x + 20, size.y * .2), Vector2(x - 30, size.y * .8), Color(1, 1, 1, .06), 22, true)
	# Pulsing border: the rim swells with a heartbeat and sends rings rippling outward.
	var beat = pow(.5 + .5 * sin(time * 3.4), 3.0)
	for k in 2:
		var phase = fmod(time * .7 + k * .5, 1.0)
		var ring = PackedVector2Array()
		for i in 97: ring.append(size * .5 + Vector2.from_angle(TAU * i / 96.0) * (radius() + 6.0 + phase * radius() * .28))
		draw_polyline(ring, Color(accent.lightened(.2), (1.0 - phase) * .55), 3.0 * (1.0 - phase) + 1.0, true)
	# Double neon outline: outer bright rim, thin inner line.
	draw_polyline(outer, Color(accent.lightened(.25), .95), 4.0 + 5.0 * beat, true)
	draw_polyline(outer, Color(1, 1, 1, .55 + .3 * breathe), 1.5, true)
	draw_polyline(hex(8), Color(accent, .55 + .2 * breathe), 2.0, true)
	draw_polyline(inner, Color(1, 1, 1, .18), 1.5, true)
	# Icon in the upper half, caption below.
	var icon_center = Vector2(size.x * .5, size.y * .4)
	if kind == "play": draw_play_icon(icon_center)
	else: draw_create_icon(icon_center)
	if press > 0.0: draw_colored_polygon(fill, Color(1, .95, .97, .55 * press * press))
	draw_caption()
	draw_set_transform(Vector2.ZERO)
	# Sparks and glitch dashes sit outside the frame and are not scaled.
	for s in sparks:
		var a = clampf(s.life / s.max, 0.0, 1.0)
		draw_line(s.pos, s.pos - s.vel * .05, Color(1, .62, .45, a), 2.5, true)
		draw_circle(s.pos, 2.2, Color(1, .95, .85, a))
	for g in glitches:
		var gx = g.x * size.x; var gy = g.y * size.y
		draw_rect(Rect2(gx - g.w * .5, gy, g.w, 3), Color(accent.lightened(.3), .8))
		draw_rect(Rect2(gx - g.w * .2, gy + 6, g.w * .4, 2), Color(1, 1, 1, .5))

func draw_wave(center: Vector2, width: float, height: float, bars: int, phase: float, color: Color) -> void:
	for i in bars:
		var u = float(i) / (bars - 1) - .5
		var envelope = 1.0 - pow(abs(u) * 2.0, 1.4)
		var h = height * envelope * (.35 + .65 * abs(sin(time * 5.0 + i * .9 + phase)))
		var x = center.x + u * width
		draw_line(Vector2(x, center.y - h * .5), Vector2(x, center.y + h * .5), color, 3.0, true)

func draw_play_icon(c: Vector2) -> void:
	var s = size.y * .2
	# Sound wave trailing into the arrow, as if the arrow were made of sound.
	draw_wave(c + Vector2(-s * 1.15, 0), s * 2.0, s * 1.1, 17, 0.0, Color(1, 1, 1, .75))
	var nudge = 6.0 * sin(time * 3.0) + 8.0 * hover
	var tri = PackedVector2Array([c + Vector2(-s * .25 + nudge, -s * .75), c + Vector2(s * .95 + nudge, 0), c + Vector2(-s * .25 + nudge, s * .75)])
	draw_colored_polygon(tri, Color(1, 1, 1, .95))
	var chevron = PackedVector2Array([c + Vector2(s * .55 + nudge, -s * .8), c + Vector2(s * 1.45 + nudge, 0), c + Vector2(s * .55 + nudge, s * .8)])
	draw_polyline(chevron, Color(accent.lightened(.35), .9), 4.0, true)

# CREATE CHARTS icon: a tiny perspective highway with the game's real note artwork scrolling
# down to the judgement line (circle notes, a blue tap and a hold with its trail), over the
# faint beat-grid lines of the chart editor.
const CIRCLE_NOTE = preload("res://assets/neon/Circle_Note_Reference.png")
const TAP_NOTE = preload("res://assets/neon/Tap_Note_Blue_Preview.png")
func track_point(c: Vector2, s: float, lane: float, depth: float) -> Vector2:
	# depth 0 = far end (top), 1 = judgement line (bottom); lane -1..1 across the track.
	var y = c.y - s * 1.0 + depth * s * 1.75
	var half = lerpf(s * .55, s * 1.6, depth)
	return Vector2(c.x + lane * half, y)
func draw_create_icon(c: Vector2) -> void:
	var s = size.y * .2
	var far_l = track_point(c, s, -1, 0); var far_r = track_point(c, s, 1, 0)
	var near_l = track_point(c, s, -1, 1); var near_r = track_point(c, s, 1, 1)
	draw_colored_polygon(PackedVector2Array([far_l, far_r, near_r, near_l]), Color(.1, .05, .12, .85))
	# Beat-grid lines scrolling toward the player.
	for i in 5:
		var d = fmod(float(i) / 5.0 + time * .45, 1.0)
		draw_line(track_point(c, s, -1, d), track_point(c, s, 1, d), Color(1, 1, 1, .06 + .1 * d), 1.5, true)
	# Lane dividers and neon rails.
	for lane in [-.333, .333]:
		draw_line(track_point(c, s, lane, 0), track_point(c, s, lane, 1), Color(1, 1, 1, .08), 1.0, true)
	for side in [-1, 1]:
		draw_line(track_point(c, s, side, 0), track_point(c, s, side, 1), Color(accent.lightened(.3), .95), 3.0, true)
	# Judgement line.
	draw_line(near_l, near_r, Color(1, .55, .8, .95), 4.0, true)
	# Notes: [lane, phase offset, kind]. They loop from the far end down to the line.
	var notes = [[-.66, 0.0, "circle"], [.66, .33, "tap"], [0.0, .62, "hold"], [-.66, .78, "circle"]]
	for n in notes:
		var d = fmod(time * .42 + n[1], 1.0)
		var p = track_point(c, s, n[0], d)
		var w = lerpf(s * .55, s * 1.05, d)
		var a = clampf(d * 4.0, 0.0, 1.0) * clampf((1.0 - d) * 8.0, 0.0, 1.0)
		if n[2] == "hold":
			# Trail stretching back up the lane behind the head.
			var tail_d = maxf(0.0, d - .32)
			var tp = track_point(c, s, n[0], tail_d)
			var tw = lerpf(s * .16, s * .3, tail_d)
			var hw = w * .28
			draw_colored_polygon(PackedVector2Array([tp + Vector2(-tw, 0), tp + Vector2(tw, 0), p + Vector2(hw, 0), p + Vector2(-hw, 0)]), Color(.72, .45, 1.0, .55 * a))
		var tex: Texture2D = TAP_NOTE if n[2] == "tap" else CIRCLE_NOTE
		var h = w * tex.get_height() / tex.get_width()
		draw_texture_rect(tex, Rect2(p - Vector2(w, h) * .5, Vector2(w, h)), false, Color(1, 1, 1, a))

func draw_caption() -> void:
	var font_size = roundi(size.y * .15)
	var width = BOLD.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if width > size.x * .66:
		font_size = roundi(font_size * size.x * .66 / width)
		width = BOLD.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var base = Vector2(size.x * .5, size.y * .7)
	# Slanted like italic type: shear the drawing around the caption's baseline.
	var shear = Transform2D(Vector2(1, 0), Vector2(-.22, 1), base)
	draw_set_transform_matrix(_scaled() * shear)
	var origin = Vector2(-width * .5, 0)
	draw_string_outline(BOLD, origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color(accent, .55))
	draw_string(BOLD, origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, .97, .98))

# The hover/press scale used for the frame, so the caption scales with it.
func _scaled() -> Transform2D:
	var lift = 1.0 + .03 * hover - .03 * press
	var pivot = size * .5
	return Transform2D(0.0, Vector2.ONE * lift, 0.0, pivot - pivot * lift)
