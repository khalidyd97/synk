extends Control
# The lobby's living concert stage: one photo cut into depth planes (tools/lobby_layers/build.py)
# plus generated light sprites, composited back to front with parallax from the pointer or
# device tilt. Everything that pulses follows one slow house tempo so the room "breathes".
const BPM = 96.0
const L = "res://assets/lobby/layers/"
const BACK = preload(L + "stage_back.png")
const PROPS = preload(L + "stage_props.png")
const FLOOR = preload(L + "stage_floor.png")
const BEAM = preload(L + "beam.png")
const HAZE = preload(L + "haze.png")
const GLOW = preload(L + "glow.png")
const STREAK = preload(L + "flare_streak.png")
const MOTE = preload(L + "mote.png")
const BOKEH = preload(L + "bokeh.png")
const CROWD = preload(L + "crowd.png")
# Lamp heads in the stage photo (normalised), with the direction each beam leans toward.
const LAMPS = [
	[Vector2(.087,.012), .16], [Vector2(.135,.032), .05], [Vector2(.266,.015), -.10],
	[Vector2(.718,.018), .10], [Vector2(.861,.033), -.05], [Vector2(.906,.012), -.16]]
const FLOOR_LAMPS = [Vector2(.137,.708), Vector2(.779,.708), Vector2(.982,.708)]
# How far each plane travels at full tilt, in pixels at 1080p (nearer planes move more).
const DEPTH = {"back": 7.0, "props": 11.0, "floor": 15.0, "haze": 20.0, "crowd_back": 26.0, "crowd": 36.0, "bokeh": 54.0}

static var tilt := Vector2.ZERO        # shared with the cards so they float at their own depth

var elapsed := 0.0
var pointer_tilt := Vector2.ZERO
var gravity_rest := Vector3.ZERO
var motes: Array = []
var bokeh: Array = []
var phones: Array = []
var additive := CanvasItemMaterial.new()
var lights: Control
var front: Control

static func beat() -> float:
	return Time.get_ticks_msec() / 1000.0 * BPM / 60.0

# A sharp attack that decays over the beat, for light hits.
static func pulse(offset: float = 0.0) -> float:
	var phase := fposmod(beat() + offset, 1.0)
	return exp(-phase * 5.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var rng := RandomNumberGenerator.new(); rng.seed = 96
	for i in 70:
		motes.append({"p": Vector2(rng.randf(), rng.randf_range(.05, .78)), "v": Vector2(rng.randf_range(-.006, .006), rng.randf_range(-.012, -.003)),
			"s": rng.randf_range(.5, 1.4), "phase": rng.randf() * TAU})
	for i in 9:
		bokeh.append({"p": Vector2(rng.randf(), rng.randf_range(.55, 1.0)), "s": rng.randf_range(.05, .12), "phase": rng.randf() * TAU, "warm": rng.randf()})
	var text := FileAccess.get_file_as_string(L + "crowd_phones.txt")
	for line in text.split("\n", false):
		var v := line.split(",")
		phones.append({"p": Vector2(float(v[0]), float(v[1])), "s": float(v[2]), "phase": rng.randf() * TAU})
	# Light layers sit above the photo planes and blend additively; the crowd silhouettes go on top.
	lights = Control.new(); lights.name = "StageLights"; lights.material = additive
	lights.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(lights)
	lights.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lights.draw.connect(draw_lights)
	front = Control.new(); front.name = "StageFront"; front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(front); front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front.draw.connect(draw_front)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed += delta
	update_tilt(delta)
	for m in motes:
		m.p += m.v * delta
		m.p.x += sin(elapsed * .4 + m.phase) * .0004
		if m.p.y < .02: m.p = Vector2(randf(), .8)
		m.p.x = fposmod(m.p.x, 1.0)
	queue_redraw(); lights.queue_redraw(); front.queue_redraw()

func update_tilt(delta: float) -> void:
	var target := Vector2(sin(elapsed * .21) * .25, sin(elapsed * .17 + 1.3) * .18)   # idle drift
	var accel := Input.get_accelerometer()
	if accel.length() > 1.0:
		if gravity_rest == Vector3.ZERO: gravity_rest = accel
		gravity_rest = gravity_rest.lerp(accel, 1.0 - exp(-delta * .25))       # slowly re-centre to how it's held
		var d := (accel - gravity_rest) / 3.0
		target += Vector2(clampf(d.x, -1, 1), clampf(-d.y, -1, 1))
	elif get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position()):
		var mouse := get_viewport().get_mouse_position() / get_viewport().get_visible_rect().size
		pointer_tilt = (mouse - Vector2(.5, .5)) * 2.0
		target += pointer_tilt * .8
	tilt = tilt.lerp(target.clamp(Vector2(-1, -1), Vector2(1, 1)), 1.0 - exp(-delta * 3.0))

# Cover-fit rect for the stage photo, enlarged a little so parallax never reveals an edge.
func stage_rect(depth: float) -> Rect2:
	var src := Vector2(BACK.get_width(), BACK.get_height())
	var scale := maxf(size.x / src.x, size.y / src.y) * 1.045
	var fitted := src * scale
	var unit := size.y / 1080.0
	return Rect2((size - fitted) * .5 - tilt * depth * unit, fitted)

func to_stage(p: Vector2, depth: float) -> Vector2:
	var r := stage_rect(depth)
	return r.position + p * r.size

func _draw() -> void:
	draw_texture_rect(BACK, stage_rect(DEPTH.back), false)
	draw_texture_rect(PROPS, stage_rect(DEPTH.props), false)
	draw_texture_rect(FLOOR, stage_rect(DEPTH.floor), false)
	# Keep the middle calm for the cards: a soft dark band behind them.
	draw_rect(Rect2(Vector2.ZERO, size), Color(.02, .015, .02, .22))

func draw_lights() -> void:
	var c := lights
	var unit := size.y / 1080.0
	var b := beat()
	var warm := Color(1.0, .66, .32)
	# Haze: two tiling sheets drifting opposite ways, brightest in the upper stage.
	for sheet in 2:
		var drift := elapsed * (14.0 if sheet == 0 else -9.0) * unit
		var w := HAZE.get_width() * unit * (1.6 if sheet == 0 else 2.2)
		var h := HAZE.get_height() * unit * (1.4 if sheet == 0 else 1.8)
		var off := -tilt * DEPTH.haze * unit * (1.0 + sheet * .4)
		var x := fposmod(drift + off.x, w) - w
		while x < size.x:
			c.draw_texture_rect(HAZE, Rect2(x, size.y * (.02 + sheet * .18) + off.y, w, h), false, Color(warm, .085 - sheet * .03))
			x += w
	# Beams sway across a four-bar phrase; alternate lamps hit on alternate beats.
	for i in LAMPS.size():
		var lamp: Vector2 = LAMPS[i][0]; var lean: float = LAMPS[i][1]
		var origin := to_stage(lamp, DEPTH.back)
		var sway := sin(b * TAU / 16.0 + i * 1.1) * .11 + sin(b * TAU / 6.0 + i) * .025
		var hit := .55 + .45 * pulse(.0 if i % 2 == 0 else .5)
		var length := size.y * (.95 if i % 3 != 1 else .78)
		var width := size.y * .30
		c.draw_set_transform(origin, lean + sway, Vector2.ONE)
		c.draw_texture_rect(BEAM, Rect2(-width * .5, 0, width, length), false, Color(warm, .30 * hit))
		c.draw_texture_rect(BEAM, Rect2(-width * .18, 0, width * .36, length * .8), false, Color(1, .86, .62, .22 * hit))
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var glow := size.y * .16 * (.85 + .3 * hit)
		c.draw_texture_rect(GLOW, Rect2(origin - Vector2.ONE * glow * .5, Vector2.ONE * glow), false, Color(warm, .55 * hit))
		c.draw_texture_rect(STREAK, Rect2(origin - Vector2(size.y * .22, size.y * .012), Vector2(size.y * .44, size.y * .024)), false, Color(1, .8, .55, .35 * hit))
	for p in FLOOR_LAMPS:
		var o := to_stage(p, DEPTH.floor)
		var s := size.y * .13 * (.9 + .15 * pulse(.25))
		c.draw_texture_rect(GLOW, Rect2(o - Vector2.ONE * s * .5, Vector2.ONE * s), false, Color(warm, .45))
	# Dust only shows where a beam catches it.
	for m in motes:
		var pos := Vector2(m.p.x * size.x, m.p.y * size.y) - tilt * DEPTH.haze * unit
		var lit := 0.0
		for i in LAMPS.size():
			var lamp_x: float = to_stage(LAMPS[i][0], DEPTH.back).x / size.x
			var reach := absf(m.p.x - (lamp_x + (LAMPS[i][1] + sin(b * TAU / 16.0 + i * 1.1) * .11) * m.p.y * .56))
			lit = maxf(lit, clampf(1.0 - reach / (.035 + m.p.y * .09), 0, 1))
		var twinkle := .6 + .4 * sin(elapsed * 2.0 + m.phase)
		var s: float = 9.0 * unit * m.s
		c.draw_texture_rect(MOTE, Rect2(pos - Vector2.ONE * s * .5, Vector2.ONE * s), false, Color(1, .82, .6, (.05 + .65 * lit) * twinkle))

func draw_front() -> void:
	var c := front
	var unit := size.y / 1080.0
	var b := beat()
	# Two rows of audience: the far row bobs on the beat, the near row on the off-beat.
	for row in 2:
		var depth: float = DEPTH.crowd_back if row == 0 else DEPTH.crowd
		var scale := (.62 if row == 0 else .78) * unit
		var w := CROWD.get_width() * scale; var h := CROWD.get_height() * scale
		var bob := absf(sin((b + row * .5) * PI)) * 5.0 * unit
		var shift := -tilt * depth * unit
		var x := (size.x - w) * .5 + shift.x + (140.0 * unit if row == 0 else 0.0)
		var y := size.y - h * (.92 if row == 0 else .70) - bob + shift.y
		var tint := Color(.55, .45, .42, .92) if row == 0 else Color.WHITE
		c.draw_texture_rect(CROWD, Rect2(x, y, w, h), false, tint)
		if row == 1:
			for p in phones:
				var at := Vector2(x + p.p.x * w, y + p.p.y * h)
				var on := .55 + .45 * sin(elapsed * 1.3 + p.phase)
				var s: float = 26.0 * unit * p.s
				c.draw_texture_rect(GLOW, Rect2(at - Vector2.ONE * s, Vector2.ONE * s * 2), false, Color(.75, .85, 1, .5 * on))
				var screen := StyleBoxFlat.new(); screen.bg_color = Color(.9, .95, 1, .95 * on); screen.set_corner_radius_all(roundi(2 * unit))
				c.draw_style_box(screen, Rect2(at - Vector2(3.5, 6) * unit * p.s, Vector2(7, 12) * unit * p.s))
	# Out-of-focus foreground lights drift slowest-to-fastest with the tilt.
	for o in bokeh:
		var s: float = size.y * o.s
		var pos := Vector2(o.p.x * size.x, o.p.y * size.y) - tilt * DEPTH.bokeh * unit + Vector2(sin(elapsed * .2 + o.phase), cos(elapsed * .15 + o.phase)) * 10.0 * unit
		var tone := Color(1, .62, .3).lerp(Color(1, .85, .6), o.warm)
		c.draw_texture_rect(BOKEH, Rect2(pos - Vector2.ONE * s * .5, Vector2.ONE * s), false, Color(tone, .07 + .04 * pulse(o.phase)))
