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
	fx.origin = xf * (_scaled() * (size * .5)); fx.start_radius = radius() * xf.get_scale().x * (1.0 + .03 * hover - .03 * press)
	fx.accent = accent; fx.kind = kind
	layer.add_child(fx)
	fx.arrived.connect(func(): warping = false; activated.emit())
	fx.tree_exited.connect(func(): layer.queue_free())

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_READY: set_process(is_visible_in_tree())

# Circular outline, inset by `inset` pixels, closed (last point repeats the first).
func radius() -> float: return minf(size.x, size.y) * .5
var outline_cache: Dictionary={}
var outline_size=Vector2(-1,-1)
func hex(inset: float) -> PackedVector2Array:
	if outline_size!=size:
		outline_cache.clear(); outline_size=size
	if outline_cache.has(inset): return outline_cache[inset]
	var points=build_outline(inset)
	outline_cache[inset]=points
	return points
func build_outline(inset: float) -> PackedVector2Array:
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
	for i in range(sparks.size()-1,-1,-1):
		if sparks[i].life<=0.0: sparks.remove_at(i)
	if randf() < delta * 6.0:
		var right = randf() < .5
		glitches.append({"y": randf_range(.15, .85), "x": (1.0 + randf_range(.02, .1)) if right else randf_range(-.1, -.02), "w": randf_range(10, 46), "life": randf_range(.08, .3)})
	for g in glitches: g.life -= delta
	for i in range(glitches.size()-1,-1,-1):
		if glitches[i].life<=0.0: glitches.remove_at(i)
	queue_redraw()

func _draw() -> void:
	draw_float_shadow()
	draw_set_transform_matrix(_scaled())
	var inner = hex(14)
	var fill = inner.duplicate(); fill.remove_at(fill.size() - 1)
	if kind == "play":
		draw_note_button()
		fill = hex(0).slice(0,96)
	else:
		draw_sequencer_pad()
		fill = PackedVector2Array()
		for i in 96: fill.append(size * .5 + note_face_offset() + Vector2.from_angle(TAU * i / 96.0) * radius())
	# Icon in the upper half, caption below.
	var icon_center = Vector2(size.x * .5, size.y * .4)
	if kind == "play": draw_play_core()
	else: draw_create_icon(icon_center + note_face_offset())
	if press > 0.0: draw_colored_polygon(fill, Color(1, .95, .97, .55 * press * press))
	if kind != "play": draw_caption()
	# Sparks and glitch dashes drift with their floating button.
	for s in sparks:
		var a = clampf(s.life / s.max, 0.0, 1.0)
		draw_line(s.pos, s.pos - s.vel * .05, Color(1, .62, .45, a), 2.5, true)
		draw_circle(s.pos, 2.2, Color(1, .95, .85, a))
	for g in glitches:
		var gx = g.x * size.x; var gy = g.y * size.y
		draw_rect(Rect2(gx - g.w * .5, gy, g.w, 3), Color(accent.lightened(.3), .8))
		draw_rect(Rect2(gx - g.w * .2, gy + 6, g.w * .4, 2), Color(1, 1, 1, .5))

	draw_set_transform(Vector2.ZERO)

# Layered bevels shade the note like a raised, polished arcade button.
func note_face_offset() -> Vector2:
	return Vector2(0, -radius() * (.045 + .018 * hover) * (1.0 - press))

func shaded_disc(center: Vector2, r: float, edge: Color, light: Color) -> void:
	draw_circle(center, r, edge)
	for i in range(1, 33):
		var t = float(i) / 32.0
		draw_circle(center + Vector2(-r * .12, -r * .16) * t, r * (1.0 - t * .92), edge.lerp(light, t))

func draw_note_button() -> void:
	var beat = pow(.5 + .5 * sin(time * 3.4), 3.0)
	var c = size * .5
	var r = radius() * (1.0 + .02 * beat)
	var face = c + note_face_offset()
	var energy = .55 + beat * .45 + hover * .35 + press * .5
	# Broad halo breathes behind the solid note; ripples dissolve into the lobby.
	for layer in range(8, 0, -1):
		var spread = float(layer) / 8.0
		draw_circle(face, r * (1.0 + spread * .3), Color(1, .08, .25, .018 * energy))
	for k in 2:
		var phase = fposmod(time * .42 + k * .5, 1.0)
		draw_arc(face, r * (1.03 + phase * .28), 0, TAU, 96, Color(1, .22, .4, (1.0 - phase) * .24 * energy), r * .009, true)
	# Soft cast shadow and a burgundy side wall remain below the moving face.
	for i in range(6, 0, -1):
		draw_circle(c + Vector2(0, r * .095), r + i * 2.0, Color(0, 0, 0, .025))
	shaded_disc(c + Vector2(0, r * .055), r, Color("480a20"), Color("ac1636"))
	shaded_disc(face, r, Color("a80d30"), Color("ff5868").lightened(hover * .08 + beat * .07))
	draw_arc(face, r * .975, PI * 1.05, PI * 1.9, 64, Color(1, .65, .69, .8), r * .018, true)
	draw_arc(face, r * .96, .1, PI * .88, 64, Color(.32, .01, .07, .65), r * .028, true)
	# Pearl ring, recessed red channel, and domed pink center.
	shaded_disc(face, r * .815, Color("b65c73"), Color("fff5f2"))
	shaded_disc(face, r * .73, Color("790c2a"), Color("f43b58"))
	draw_arc(face, r * .715, PI * 1.05, PI * 1.9, 64, Color(.28, .01, .06, .7), r * .025, true)
	shaded_disc(face, r * .52, Color("d26b87"), Color("ffe9e7"))
	draw_arc(face, r * .5, PI * 1.08, PI * 1.8, 48, Color(1, .98, .97, .7), r * .014, true)
	# Two traveling highlights trace the bevel, leaving a soft luminous tail.
	for k in 2:
		var angle = time * .8 + k * PI
		for trail in range(10):
			var strength = 1.0 - float(trail) / 10.0
			var start = angle - trail * .045
			draw_arc(face, r * .965, start, start + .07, 8, Color(1, .66, .76, strength * .65 * energy), r * .035, true)
		var glint = face + Vector2.from_angle(angle + .07) * r * .965
		draw_circle(glint, r * .027, Color(1, .35, .52, .3 * energy))
		draw_circle(glint, r * .011, Color(1, .94, .96, .9))
	draw_arc(face, r * .795, 0, TAU, 96, Color(1, .8, .85, .18 + beat * .32), r * .025, true)

func draw_wave(center: Vector2, width: float, height: float, bars: int, phase: float, color: Color) -> void:
	for i in bars:
		var u = float(i) / (bars - 1) - .5
		var envelope = 1.0 - pow(abs(u) * 2.0, 1.4)
		var h = height * envelope * (.35 + .65 * abs(sin(time * 5.0 + i * .9 + phase)))
		var x = center.x + u * width
		draw_line(Vector2(x, center.y - h * .5), Vector2(x, center.y + h * .5), color, 3.0, true)

# PLAY's content, centred as one group inside the note's light core (radius .5 r):
# a compact wave + arrow above the middle and the caption below it.
func draw_play_core() -> void:
	var c = size * .5 + note_face_offset(); var core = radius() * .5
	var ink = Color("b0102c")
	var s = core * .34
	var ic = c + Vector2(0, -core * .2)
	var nudge = 3.0 * sin(time * 3.0) + 4.0 * hover
	# Small sound wave to the left of a centred arrow; the pair is centred on ic.
	draw_wave(ic + Vector2(-s * 1.25, 0), s * 1.3, s * 1.2, 9, 0.0, Color(ink, .7))
	var tri = PackedVector2Array([ic + Vector2(-s * .35 + nudge, -s * .8), ic + Vector2(s * .95 + nudge, 0), ic + Vector2(-s * .35 + nudge, s * .8)])
	draw_colored_polygon(tri, ink)
	var fs = roundi(core * .36)
	var w = BOLD.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base = c + Vector2(0, core * .55)
	draw_set_transform_matrix(_scaled() * Transform2D(Vector2(1, 0), Vector2(-.22, 1), base))
	draw_string(BOLD, Vector2(-w * .5, 0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	draw_set_transform_matrix(_scaled())

func draw_play_icon(c: Vector2, on_light := false) -> void:
	var s = size.y * .2
	var ink = Color("b0102c") if on_light else Color.WHITE
	# Sound wave trailing into the arrow, as if the arrow were made of sound.
	draw_wave(c + Vector2(-s * 1.15, 0), s * 2.0, s * 1.1, 17, 0.0, Color(ink, .75))
	var nudge = 6.0 * sin(time * 3.0) + 8.0 * hover
	var tri = PackedVector2Array([c + Vector2(-s * .25 + nudge, -s * .75), c + Vector2(s * .95 + nudge, 0), c + Vector2(-s * .25 + nudge, s * .75)])
	draw_colored_polygon(tri, Color(ink, .95))
	var chevron = PackedVector2Array([c + Vector2(s * .55 + nudge, -s * .8), c + Vector2(s * 1.45 + nudge, 0), c + Vector2(s * .55 + nudge, s * .8)])
	draw_polyline(chevron, Color(ink, .85) if kind == "play" else Color(accent.lightened(.35), .9), 4.0, true)

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
func draw_sequencer_pad() -> void:
	var beat = pow(.5 + .5 * sin(time * 3.4), 3.0)
	var c = size * .5
	var r = radius() * (1.0 + .02 * beat)
	var face = c + note_face_offset()
	var energy = .55 + beat * .45 + hover * .35 + press * .5
	# Match the Play note's radius, lift, and side wall, with dark sequencer glass.
	for layer in range(8, 0, -1):
		var spread = float(layer) / 8.0
		draw_circle(face, r * (1.0 + spread * .3), Color(1,.08,.25,.018 * energy))
	for i in range(6, 0, -1):
		draw_circle(c + Vector2(0,r*.095),r+i*2.0,Color(0,0,0,.025))
	shaded_disc(c + Vector2(0,r*.055),r,Color("480a20"),Color("ac1636"))
	shaded_disc(face,r,Color("a80d30"),Color("ff5868").lightened(hover*.08+beat*.07))
	shaded_disc(face,r*.91,Color("381426"),Color("8e365c"))
	shaded_disc(face,r*.86,Color("0b0a15"),Color("292033"))
	draw_arc(face,r*.975,PI*1.05,PI*1.9,64,Color(1,.65,.69,.8),r*.018,true)
	draw_arc(face,r*.96,.1,PI*.88,64,Color(.32,.01,.07,.65),r*.028,true)
	draw_arc(face,r*.875,0,TAU,96,Color(1,.5,.7,.35+beat*.3),r*.012,true)
	for k in 2:
		var angle = time*.8+k*PI
		draw_arc(face,r*.965,angle-.35,angle,32,Color(1,.66,.76,.7*energy),r*.025,true)
		draw_circle(face+Vector2.from_angle(angle)*r*.965,r*.011,Color("fff0fa"))
	# Small transport lights flicker in sequence above the lanes.
	for i in 8:
		var active = posmod(int(time*4.0),8) == i
		draw_circle(size*Vector2(.27+i*.066,.18)+note_face_offset(),size.x*.009,Color("fff0fa") if active else Color("863051"))

func draw_create_icon(c: Vector2) -> void:
	var s = size.y * .18
	var far_l = track_point(c, s, -1, 0); var far_r = track_point(c, s, 1, 0)
	var near_l = track_point(c, s, -1, 1); var near_r = track_point(c, s, 1, 1)
	draw_colored_polygon(PackedVector2Array([far_l, far_r, near_r, near_l]), Color("171322"))
	for i in 6:
		var d = fposmod(float(i) / 6.0 + time * .38, 1.0)
		draw_line(track_point(c, s, -1, d), track_point(c, s, 1, d), Color(1,.65,.85,.06 + .12 * d), 1.2, true)
	for lane in [-.333, .333]:
		draw_line(track_point(c, s, lane, 0), track_point(c, s, lane, 1), Color(1,.65,.85,.23), 1.2, true)
	for side in [-1,1]:
		draw_line(track_point(c, s, side, 0), track_point(c, s, side, 1), Color(accent,.85), 2.5, true)
	draw_line(near_l, near_r, Color(1,.5,.75,.25), 12, true)
	draw_line(near_l, near_r, Color("ffb2d7"), 3, true)
	var notes = [[-.66,0.0],[0.0,.333],[.66,.666]]
	for n in notes:
		var cycle = fposmod(time * .55 + n[1], 1.0)
		var d = minf(cycle / .83, 1.0)
		var point = track_point(c,s,n[0],d)
		var w = lerpf(s * .32,s * .6,d)
		if cycle < .83:
			var tint = Color("66eaff") if n[0] < 0 else (Color("d5a4ff") if n[0] == 0 else Color("ff7dae"))
			draw_line(point-Vector2(w*.5,0),point+Vector2(w*.5,0),Color(tint,.16),w*.48,true)
			draw_line(point-Vector2(w*.5,0),point+Vector2(w*.5,0),tint,w*.24,true)
			draw_line(point-Vector2(w*.43,w*.06),point+Vector2(w*.43,-w*.06),Color(1,1,1,.85),1.5,true)
		else:
			var hit = (cycle - .83) / .17
			var strength = 1.0 - hit
			draw_circle(point,w*(.35+hit*.5),Color(1,.4,.7,strength*.16))
			draw_arc(point,w*(.2+hit*.65),0,TAU,32,Color(1,.75,.9,strength),2,true)
			draw_line(point-Vector2(w*.7,0),point+Vector2(w*.7,0),Color(1,.92,1,strength),5*strength+1,true)

func draw_caption() -> void:
	var font_size = roundi(size.y * .15)
	var width = BOLD.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if width > size.x * .66:
		font_size = roundi(font_size * size.x * .66 / width)
		width = BOLD.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var base = Vector2(size.x * .5, size.y * .76) + note_face_offset()
	# Slanted like italic type: shear the drawing around the caption's baseline.
	var shear = Transform2D(Vector2(1, 0), Vector2(-.22, 1), base)
	draw_set_transform_matrix(_scaled() * shear)
	var origin = Vector2(-width * .5, 0)
	if kind != "play": draw_string_outline(BOLD, origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color(accent, .55))
	draw_string(BOLD, origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("b0102c") if kind == "play" else Color(1, .97, .98))

# Move the artwork as one object; the touch rectangle stays in its layout slot.
func float_phase() -> float:
	return time * 1.25 + (1.7 if kind == "create" else 0.0)

func float_offset() -> Vector2:
	var phase = float_phase()
	return Vector2(sin(phase * .7) * size.x * .008, sin(phase) * size.y * .032 - hover * size.y * .018) * (1.0 - press * .8)

func draw_float_shadow() -> void:
	var height = .5 - .5 * sin(float_phase())
	var width = size.x * lerpf(.29, .24, height)
	var center = size * Vector2(.5, 1.13)
	for layer in range(7, 0, -1):
		var spread = float(layer) / 7.0
		draw_set_transform(center, 0.0, Vector2(1.0, .13))
		draw_circle(Vector2.ZERO, width * (1.0 + spread * .4), Color(0, 0, 0, .035 * (1.0 - height * .3)))
		draw_circle(Vector2.ZERO, width * (.8 + spread * .3), Color(accent, .009 * (1.0 - height * .4)))
	draw_set_transform(Vector2.ZERO)

# Share this transform with all captions, decorations, and the portal origin.
func _scaled() -> Transform2D:
	var lift = 1.0 + .03 * hover - .03 * press
	var pivot = size * .5
	var angle = sin(float_phase() * .8) * .018 * (1.0 - press)
	var basis = Transform2D(angle, Vector2.ONE * lift, 0.0, Vector2.ZERO)
	basis.origin = pivot + float_offset() - basis * pivot
	return basis
