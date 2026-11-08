extends Button
# Lobby home cards are layered concert-poster plates (cut by tools/lobby_layers/build.py).
# Play: the record behind the sleeves spins and slides out on hover, its label showing the
# latest cover. Create: the mixer faders ride the lobby tempo. Both float over the stage floor
# with a soft shadow and reflection, and drift at their own depth with the stage parallax.
const Stage = preload("res://scripts/lobby_stage.gd")
const L = "res://assets/lobby/layers/"
const PLAY_PLATE = preload(L + "play_plate.png")
const PLAY_SLEEVES = preload(L + "play_sleeves.png")
const PLAY_VINYL = preload(L + "play_vinyl.png")
const CREATE_PLATE = preload(L + "create_plate.png")
const KNOBS = [preload(L + "create_knob_0.png"), preload(L + "create_knob_1.png"), preload(L + "create_knob_2.png")]
const GLOW = preload(L + "glow.png")
# Sprite-space layout of the moving parts.
const SLEEVES_AT = Vector2(180, 140)
const VINYL_CENTER = Vector2(665, 428)
const VINYL_RADIUS = 213.0
const LABEL_RADIUS = .33
const KNOB_SLOTS = [[335.0, 325.0, 550.0, 397.0], [433.0, 360.0, 550.0, 472.0], [528.0, 325.0, 550.0, 430.0]]   # x, top, bottom, rest y
var kind = "play"
var title = "Play"
var subtitle = ""
var covers: Array = []   # up to three Texture2D, front cover first
var hover = 0.0
var press = 0.0
var spin = 0.0
var elapsed = 0.0

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button_down.connect(func(): press = 1.0; preload("res://scripts/ui_sound.gd").play(self,"play" if kind=="play" else "click"))

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed += delta
	hover = lerpf(hover,1.0 if preload("res://scripts/ui_motion.gd").hovered(self) or has_focus() else 0.0,1-exp(-delta*10))
	press = move_toward(press,1.0 if is_pressed() else 0.0,delta*8)
	spin += delta*(.7+3.6*hover)
	queue_redraw()

func source_rect() -> Rect2:
	return Rect2(80,90,1720,670) if kind=="play" else Rect2(75,110,1730,630)

# Maps sprite pixels into the card, including lift, press and parallax depth.
func sprite_transform(depth: float = 0.0) -> Transform2D:
	var source := source_rect()
	var factor := minf(size.x/source.size.x,size.y/source.size.y)
	var fitted := source.size*factor
	var unit := size.y/290.0
	var lift := Vector2(0,(-9*hover+6*press)*unit) - Stage.tilt*(10.0+depth)*unit
	var origin := (size-fitted)*.5 + lift - source.position*factor
	return Transform2D(0,Vector2(factor,factor),0,origin)

func _draw() -> void:
	var source := source_rect()
	var plate: Texture2D = PLAY_PLATE if kind=="play" else CREATE_PLATE
	var base := sprite_transform()
	var unit := size.y/290.0
	var accent := Color("d7a66f") if kind=="play" else Color("ae718d")
	# Contact shadow on the floor tightens as the card lifts.
	var card := Rect2(base*source.position, base.basis_xform(source.size))
	var shadow := Rect2(card.position.x+card.size.x*.04, card.end.y-card.size.y*.16+9*hover*unit, card.size.x*.92, card.size.y*.42)
	draw_texture_rect(GLOW, shadow, false, Color(0,0,0,.75-.2*hover))
	draw_reflection(plate, source, base)
	# Accent halo when hovered or focused.
	if hover > .01:
		var halo := StyleBoxFlat.new(); halo.draw_center = false; halo.set_corner_radius_all(roundi(30*unit))
		halo.shadow_color = Color(accent, .38*hover); halo.shadow_size = roundi(30*unit)
		draw_style_box(halo, card.grow(-8*unit))
	draw_set_transform_matrix(base)
	var bright := Color(1,1,1).lerp(Color(1.08,1.05,1.0), hover)
	draw_texture_rect_region(plate, source, source, bright)
	if kind=="play":
		draw_record(base)
		draw_texture(PLAY_SLEEVES, SLEEVES_AT, bright)
	else:
		draw_faders(base)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_sheen(card, unit)

# The plate has no record baked in: it sits between the plate and the sleeve stack.
func draw_record(base: Transform2D) -> void:
	var slide := Vector2(105*hover, 0)
	var pop := sprite_transform(6.0)
	var center := VINYL_CENTER + slide
	var spin_at := pop * Transform2D(spin, center)
	draw_set_transform_matrix(spin_at)
	draw_texture_rect(GLOW, Rect2(Vector2(-1.25, -1.15)*VINYL_RADIUS + Vector2(14, 22), Vector2(2.5, 2.5)*VINYL_RADIUS), false, Color(0,0,0,.6))
	draw_texture_rect(PLAY_VINYL, Rect2(-Vector2.ONE*(VINYL_RADIUS+4), Vector2.ONE*(VINYL_RADIUS+4)*2), false)
	# The label carries the latest cover when there is one.
	if covers.size() > 0 and covers[0] is Texture2D:
		var points := PackedVector2Array(); var uvs := PackedVector2Array()
		var r := VINYL_RADIUS*(LABEL_RADIUS-.03)
		for i in 40:
			var a := TAU*i/40.0
			points.append(Vector2(cos(a), sin(a))*r)
			uvs.append(Vector2(.5,.5)+Vector2(cos(a), sin(a))*.5)
		draw_polygon(points, PackedColorArray([Color(.92,.92,.92)]), uvs, covers[0])
		draw_circle(Vector2.ZERO, 7, Color(.03,.03,.04))
	draw_set_transform_matrix(base)

func draw_faders(base: Transform2D) -> void:
	var pop := sprite_transform(6.0)
	var b := Stage.beat()
	var reach := lerpf(.32, 1.0, hover)
	for i in 3:
		var slot: Array = KNOB_SLOTS[i]
		# Each fader rides to a new level every two beats, offset per channel like a live mix.
		var step := b*.5 + i*.37
		var n := floori(step)
		var t := smoothstep(0.0, 1.0, clampf((step-n)*2.2, 0, 1))
		var level := lerpf(fader_level(n, i), fader_level(n+1, i), t)
		var y := lerpf(float(slot[3]), lerpf(float(slot[1]), float(slot[2]), level), reach)
		var at := Vector2(float(slot[0]), y)
		var knob: Texture2D = KNOBS[i]
		draw_set_transform_matrix(pop)
		var shade := knob.get_size()*1.5
		draw_texture_rect(GLOW, Rect2(at - shade*.5 + Vector2(5, 11), shade), false, Color(0,0,0,.7))
		draw_texture(knob, at - knob.get_size()*.5)
	draw_set_transform_matrix(base)

static func fader_level(n: int, channel: int) -> float:
	var h := hash(Vector2i(n, channel)) % 1000
	return h / 999.0

# Mirrored plate fading into the glossy stage floor below the card.
func draw_reflection(plate: Texture2D, source: Rect2, base: Transform2D) -> void:
	var floor_y := (base*source.end).y + 6*size.y/290.0
	var mirror := Transform2D(0, Vector2(1,-1), 0, Vector2(0, floor_y*2)) * base
	var bands := 10
	var band := source.size.y*.045
	for k in bands:
		var src := Rect2(source.position.x, source.end.y-(k+1)*band, source.size.x, band)
		var fade: float = pow(1.0-float(k)/bands, 2.0)*.16*(1.0-.4*hover)
		draw_set_transform_matrix(mirror)
		draw_texture_rect_region(plate, src, src, Color(1,1,1,fade))
	draw_set_transform_matrix(Transform2D.IDENTITY)

# A slow diagonal glint crosses each card once every eight beats.
func draw_sheen(card: Rect2, unit: float) -> void:
	var phase := fposmod(Stage.beat()/8.0 + (0.0 if kind=="play" else .5), 1.0)
	if phase > .22: return
	var inner := card.grow(-26*unit)
	var x := lerpf(inner.position.x - inner.size.y, inner.end.x, phase/.22)
	var w := 46*unit
	var box := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)])
	# Nested bands build a soft-edged glint instead of a hard stripe.
	for layer in 3:
		var grow := w*(.25+layer*.45)
		var band := PackedVector2Array([Vector2(x-grow, inner.end.y), Vector2(x+w+grow, inner.end.y), Vector2(x+w+grow+inner.size.y*.6, inner.position.y), Vector2(x-grow+inner.size.y*.6, inner.position.y)])
		for piece in Geometry2D.intersect_polygons(band, box):
			draw_colored_polygon(piece, Color(1, .93, .8, .014 + .01*hover))
