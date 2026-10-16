extends Control

# Song intro before gameplay: a loading card built from the cover art, then an entrance
# where the loading card fades away while the camera zooms into the highway.
const LOAD_TIME = 1.15
const ENTER_TIME = .95
const NAVY = Color(.006,.008,.025)

var game: Control
var elapsed = 0.0
var load_time = LOAD_TIME
var backdrop: ColorRect
var backdrop_art: TextureRect
var card: Control
var card_art: TextureRect
var title: Label
var meta_label: Label
var status: Label
var bar: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = ColorRect.new(); add_child(backdrop); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = NAVY; backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_art = TextureRect.new(); add_child(backdrop_art); backdrop_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; backdrop_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card = Panel.new(); add_child(card); card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame = StyleBoxFlat.new(); frame.bg_color = Color("140d30"); frame.set_corner_radius_all(14)
	frame.shadow_color = Color(Color("a36aff"),.55); frame.shadow_size = 28
	card.add_theme_stylebox_override("panel",frame); card.clip_contents = true
	card_art = TextureRect.new(); card.add_child(card_art); card_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title = caption(52,Color("f6efff")); title.add_theme_color_override("font_outline_color",Color("5a1fb0")); title.add_theme_constant_override("outline_size",5)
	meta_label = caption(21,Color("cbbcff"))
	status = caption(18,Color("86d9ff"))
	bar = Control.new(); add_child(bar); bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(draw_bar)
	resized.connect(layout)
	visible = false

func caption(font_size: int, color: Color) -> Label:
	var label = Label.new(); add_child(label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0,0,.02,.7)); label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func begin(cover: Texture2D, tint: Color, song_title: String, details: String, skip_loading: bool) -> void:
	for art in [backdrop_art,card_art]: art.texture = cover; art.self_modulate = tint
	title.text = song_title.to_upper(); meta_label.text = details
	load_time = 0.0 if skip_loading else LOAD_TIME
	elapsed = 0.0; visible = true
	layout(); animate()

func skip() -> void:
	elapsed = load_time + ENTER_TIME; visible = false

func running() -> bool: return visible and elapsed < load_time + ENTER_TIME

# 0 while the loading card is up, easing to 1 as the stage finishes entering.
func entrance() -> float:
	if not visible: return 1.0
	var e = clampf((elapsed - load_time) / ENTER_TIME, 0.0, 1.0)
	return e * e * (3.0 - 2.0 * e)

func layout() -> void:
	var side = minf(size.y * .46, size.x * .3)
	card.size = Vector2(side, side)
	card.pivot_offset = card.size * .5
	for label in [title,meta_label,status]: label.size = Vector2(size.x * .8, 60); label.position.x = size.x * .1
	title.position.y = size.y * .62
	meta_label.position.y = size.y * .70
	bar.size = Vector2(minf(size.x * .34, 460), 10); bar.position = Vector2((size.x - bar.size.x) * .5, size.y * .80)
	status.position.y = size.y * .82

func card_home() -> Vector2: return Vector2((size.x - card.size.x) * .5, size.y * .12)

func vanishing_point() -> Vector2:
	# Far end of the highway, converted from the stage's screen space into this control.
	if game == null or game.field == null: return Vector2(size.x * .5, size.y * .1)
	var far = game.field.get_global_transform_with_canvas() * game.field.project(game.field.world.CENTER_LANE, 1.0)
	return get_global_transform_with_canvas().affine_inverse() * far

func load_progress() -> float:
	if load_time <= 0.0: return 1.0
	return clampf(elapsed / (load_time * .9), 0.0, 1.0)

func _process(delta: float) -> void:
	if not visible: return
	if game and game.mode == "play": elapsed += delta
	elif game and game.mode != "paused": visible = false; return
	animate()
	if elapsed >= load_time + ENTER_TIME: visible = false

func animate() -> void:
	var appear = clampf(elapsed / .35, 0.0, 1.0) if load_time > 0.0 else 1.0
	appear = 1.0 - pow(1.0 - appear, 3.0)
	var e = entrance()
	var drift = sin(elapsed * 2.2) * 4.0
	backdrop.color.a = 1.0 - smoothstep(.12, .8, e)
	backdrop_art.modulate.a = .32 * appear * (1.0 - smoothstep(0.0, .6, e))
	backdrop_art.pivot_offset = size * .5
	backdrop_art.scale = Vector2.ONE
	# Keep the card at its full size as it fades into the stage zoom.
	var home = card_home() + Vector2(0, (1.0 - appear) * 30.0 + drift * (1.0 - e))
	card.position = home
	card.scale = Vector2.ONE
	card.modulate = Color(1, 1, 1, appear * (1.0 - smoothstep(0.0, .5, e)))
	var text_alpha = appear * (1.0 - smoothstep(0.0, .3, e))
	for label in [title,meta_label,status,bar]: label.modulate.a = text_alpha
	var dots = ".".repeat(1 + int(elapsed * 3.0) % 3)
	status.text = ("LOADING" + dots) if load_progress() < 1.0 else "GET READY"
	bar.queue_redraw()

func draw_bar() -> void:
	var width = bar.size.x; var height = bar.size.y
	var fill = load_progress()
	bar.draw_rect(Rect2(0, height * .3, width, height * .4), Color(.6, .5, 1.0, .18))
	var filled = width * fill
	for layer in [5.0, 3.0, 1.6]:
		bar.draw_rect(Rect2(0, height * .5 - layer * 1.6, filled, layer * 3.2), Color(Color("a36aff"), .12))
	bar.draw_rect(Rect2(0, height * .3, filled, height * .4), Color("c99bff"))
	# A bright glint runs along the filled part.
	var glint_x = fmod(elapsed * 420.0, maxf(1.0, filled + 60.0)) - 30.0
	if filled > 4.0:
		bar.draw_circle(Vector2(clampf(glint_x, 0.0, filled), height * .5), height * .55, Color(1, 1, 1, .85))
