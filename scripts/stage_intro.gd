extends Control

# Song intro before gameplay: a loading screen built from the cover art and the song's colors,
# then an entrance where the cover and details slide away over the stationary highway.
const LOAD_TIME = 5.0
const ENTER_TIME = .95
const NAVY = Color(.006,.008,.025)
const TIPS = [
	"Hold notes: keep your finger down until the ring reaches the bar.",
	"Slides: follow the trail with your finger — the lane under it counts.",
	"Flicks: swipe in the arrow's direction as the note hits the bar.",
	"Notes feel early or late? Tune the timing offset in Audio & sync.",
	"Customize the rails, band and colors in Settings → Visual effects.",
	"Chords: tap every note in the row at the same time.",
]

var game: Control
var elapsed = 0.0
var load_time = LOAD_TIME
var backdrop: ColorRect
var backdrop_art: TextureRect
var fx: Control
var card: Panel
var card_art: TextureRect
var card_rim: Panel
var reflection: TextureRect
var eyebrow: Label
var title: Label
var meta_label: Label
var status: Label
var percent: Label
var tip: Label
var bar: Control
var chips: Array = []
var loading_shadow = NAVY
var accent = Color("a36aff")
var accent_2 = Color("38baff")
var info_x = 0.0
var info_width = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = ColorRect.new(); add_child(backdrop); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = NAVY; backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_art = TextureRect.new(); add_child(backdrop_art); backdrop_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; backdrop_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preload("res://scripts/background_motion.gd").attach(backdrop_art,preload("res://scripts/image_atmosphere.gdshader"))
	# Gradient wash, light streaks and the equalizer are drawn here, between backdrop and card.
	fx = Control.new(); add_child(fx); fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE; fx.draw.connect(draw_fx)
	reflection = TextureRect.new(); add_child(reflection); reflection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reflection.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; reflection.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	reflection.flip_v = true
	var fade = ShaderMaterial.new(); fade.shader = Shader.new()
	fade.shader.code = "shader_type canvas_item;\nvoid fragment(){ vec4 c=texture(TEXTURE,UV); COLOR=vec4(c.rgb,c.a*0.28*pow(max(0.0,1.0-UV.y*2.2),1.6)); }"
	reflection.material = fade
	card = Panel.new(); add_child(card); card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_art = TextureRect.new(); card.add_child(card_art); card_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rounded = ShaderMaterial.new(); rounded.shader = preload("res://scripts/rounded_image.gdshader")
	rounded.set_shader_parameter("radius",22.0); card_art.material = rounded
	card_rim = Panel.new(); card.add_child(card_rim); card_rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bold = FontVariation.new(); bold.base_font = ThemeDB.fallback_font; bold.variation_embolden = .8
	var spaced = FontVariation.new(); spaced.base_font = ThemeDB.fallback_font; spaced.variation_embolden = .5; spaced.spacing_glyph = 5
	eyebrow = caption(19,accent_2,spaced)
	title = caption(66,Color("f6efff"),bold); title.add_theme_constant_override("outline_size",6)
	meta_label = caption(21,Color("cbbcff")); meta_label.visible = false
	status = caption(17,Color("cfd6ff"),spaced)
	percent = caption(17,Color("f6efff"),spaced); percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tip = caption(18,Color(.82,.84,.98,.8)); tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar = Control.new(); add_child(bar); bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(draw_bar)
	resized.connect(layout)
	visible = false

func caption(font_size: int, color: Color, font: Font = null) -> Label:
	var label = Label.new(); add_child(label)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0,0,.02,.75)); label.add_theme_constant_override("shadow_offset_y",3)
	label.add_theme_color_override("font_outline_color",Color(0,0,.02,.55))
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if font: label.add_theme_font_override("font",font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func song_colors(cover: Texture2D=null) -> Array:
	# Loading follows the displayed artwork independently of the gameplay color setting.
	if cover==null and game!=null: cover=game.cover_texture_for_id(str(game.song.id))
	if cover!=null:
		var image=cover.get_image()
		if image!=null and not image.is_empty():
			var palette=SynkCoverPalette.from_image(image)
			if palette.from_cover:
				loading_shadow=palette.stage.darkened(.55)
				return [palette.notes[0],palette.notes[1]]
			# Monochrome covers get neutral accents rather than unrelated neon colors.
			loading_shadow=Color(.008,.008,.008)
			return [Color(.70,.70,.70),Color(.86,.86,.86)]
	loading_shadow=NAVY
	return [Color("a36aff"),Color("38baff")]

func begin(cover: Texture2D, tint: Color, song_title: String, details: String, skip_loading: bool) -> void:
	for art in [backdrop_art,card_art,reflection]: art.texture = cover; art.self_modulate = tint
	var picked = song_colors(cover); accent = picked[0]; accent_2 = picked[1]
	backdrop.color=loading_shadow
	backdrop_art.material.set_shader_parameter("artwork_palette",1.0)
	backdrop_art.material.set_shader_parameter("palette_primary",accent)
	backdrop_art.material.set_shader_parameter("palette_secondary",accent_2)
	status.add_theme_color_override("font_color",accent_2.lightened(.65))
	tip.add_theme_color_override("font_color",Color(accent_2.lightened(.8),.8))
	eyebrow.add_theme_color_override("font_color",accent_2.lightened(.25))
	title.text = song_title.to_upper(); meta_label.text = details
	chips = []
	for part in details.split("•"):
		if part.strip_edges() != "": chips.append(part.strip_edges())
	tip.text = "TIP  ·  " + TIPS[randi() % TIPS.size()]
	# Glow behind the cover, and a light rim drawn over its rounded edge.
	var frame = StyleBoxFlat.new(); frame.bg_color = accent.darkened(.92); frame.set_corner_radius_all(22)
	frame.shadow_color = Color(accent,.24); frame.shadow_size = 24
	card.add_theme_stylebox_override("panel",frame)
	var rim = StyleBoxFlat.new(); rim.bg_color = Color(0,0,0,0); rim.set_corner_radius_all(22)
	rim.border_color = Color(accent.lerp(Color.WHITE,.45),.45); rim.set_border_width_all(2)
	card_rim.add_theme_stylebox_override("panel",rim)
	load_time = 0.0 if skip_loading else LOAD_TIME
	elapsed = 0.0; visible = true
	layout(); animate()

func skip() -> void:
	elapsed = load_time + ENTER_TIME; visible = false

func running() -> bool: return visible and elapsed < load_time + ENTER_TIME

# 0 while the loading screen is up, easing to 1 as the stage finishes entering.
func entrance() -> float:
	if not visible: return 1.0
	var e = clampf((elapsed - load_time) / ENTER_TIME, 0.0, 1.0)
	return e * e * (3.0 - 2.0 * e)

func card_side() -> float: return minf(size.y * .54, size.x * .3)
func card_home() -> Vector2: return Vector2(size.x * .1, (size.y - card_side()) * .42)

func layout() -> void:
	var side = card_side()
	card.size = Vector2(side, side); card.pivot_offset = card.size * .5
	card_art.material.set_shader_parameter("rect_size",card.size)
	reflection.size = Vector2(side, side * .5)
	info_x = card_home().x + side + size.x * .055
	info_width = size.x * .9 - info_x
	var top = card_home().y
	for label in [eyebrow,title,status,percent]: label.position.x = info_x; label.size = Vector2(info_width, 40)
	eyebrow.position.y = top + side * .06
	title.size.y = 84; title.position.y = top + side * .15
	status.size.x = info_width * .6; status.position.y = top + side * .76
	percent.position.y = status.position.y
	bar.size = Vector2(info_width, 18); bar.position = Vector2(info_x, top + side * .86)
	tip.size = Vector2(size.x * .8, 36); tip.position = Vector2(size.x * .1, size.y * .87)

func vanishing_point() -> Vector2:
	# Far end of the highway, converted from the stage's screen space into this control.
	if game == null or game.field == null: return Vector2(size.x * .5, size.y * .1)
	var far = game.field.get_global_transform_with_canvas() * game.field.project(game.field.world.CENTER_LANE, 1.0)
	return get_global_transform_with_canvas().affine_inverse() * far

# The bar shows real work: the chart's notes being built. It never runs ahead of them, and
# the card stays up until they're done (small charts finish well inside the minimum time).
func build_progress() -> float:
	if game == null or game.field == null: return 1.0
	return game.field.world.prebuild_progress()
func load_progress() -> float:
	if load_time <= 0.0: return 1.0
	var t = clampf(elapsed / (load_time * .9), 0.0, 1.0)
	return minf(1.0 - pow(1.0 - t, 2.2), build_progress())

func _process(delta: float) -> void:
	if not visible: return
	if game and game.mode == "play":
		elapsed += delta
		# Hold on the loading card until every note is built.
		if load_time > 0.0 and build_progress() < 1.0: elapsed = minf(elapsed, load_time * .95)
	elif game and game.mode != "paused": visible = false; return
	animate()
	if elapsed >= load_time + ENTER_TIME: visible = false

func animate() -> void:
	var appear = clampf(elapsed / .45, 0.0, 1.0) if load_time > 0.0 else 1.0
	appear = 1.0 - pow(1.0 - appear, 3.0)
	var e = entrance()
	var float_y = sin(elapsed * 1.8) * 5.0 * (1.0 - e)
	backdrop.color.a = 1.0 - smoothstep(.12, .8, e)
	backdrop_art.modulate.a = .12 * appear * (1.0 - smoothstep(0.0, .6, e))
	backdrop_art.pivot_offset = size * .5
	backdrop_art.scale = Vector2.ONE * (1.04 + elapsed * .012)
	# The cover rises in, floats while loading, then sweeps off to the left.
	var home = card_home() + Vector2(-size.x * .45 * e * e, (1.0 - appear) * 40.0 + float_y)
	card.position = home
	card.rotation = (1.0 - appear) * -.06 - e * .08
	card.scale = Vector2.ONE * lerpf(.92, 1.0, appear)
	card.modulate = Color(.52, .52, .52, appear * (1.0 - smoothstep(0.2, .8, e)))
	reflection.position = home + Vector2(0, card.size.y + 10)
	reflection.modulate = Color(.30,.30,.30,card.modulate.a * .35 * (1.0 - absf(card.rotation) * 8.0))
	# Details slide in from the right a beat after the cover, and leave to the right.
	var info_appear = clampf((elapsed - .12) / .45, 0.0, 1.0) if load_time > 0.0 else 1.0
	info_appear = 1.0 - pow(1.0 - info_appear, 3.0)
	var info_alpha = info_appear * (1.0 - smoothstep(0.0, .45, e))
	var shift = (1.0 - info_appear) * 60.0 + e * e * size.x * .25
	for label in [eyebrow,title,status,percent]:
		label.modulate.a = info_alpha; label.position.x = info_x + shift
	bar.modulate = Color(.60,.60,.60,info_alpha); bar.position.x = info_x + shift
	tip.modulate.a = appear * (1.0 - smoothstep(0.0, .3, e))
	var dots = ".".repeat(1 + int(elapsed * 3.0) % 3)
	eyebrow.text = "NOW LOADING" if load_progress() < 1.0 else "READY"
	var world = game.field.world if game and game.field else null
	if world and world.prebuilding: status.text = "BUILDING NOTES  ·  %d / %d" % [world.prebuild_total - world.prebuild_queue.size(), world.prebuild_total]
	else: status.text = ("LOADING STAGE" + dots) if load_progress() < 1.0 else "GET READY"
	percent.text = "%d%%" % roundi(load_progress() * 100.0)
	bar.queue_redraw(); fx.queue_redraw()

func draw_fx() -> void:
	var alpha = .35 * (1.0 - smoothstep(0.0, .6, entrance()))
	if alpha <= 0.0: return
	var w = size.x; var h = size.y
	# Color wash: the song's accent glows from the cover side and fades out across the screen.
	fx.draw_polygon(PackedVector2Array([Vector2(0,0),Vector2(w,0),Vector2(w,h),Vector2(0,h)]),
		PackedColorArray([Color(accent,.30*alpha),Color(loading_shadow,.55*alpha),Color(loading_shadow,.75*alpha),Color(accent_2,.22*alpha)]))
	# Slow diagonal light streaks.
	for i in 7:
		var phase = fmod(elapsed * (.08 + i * .013) + i * .37, 1.0)
		var x = lerpf(-w * .3, w * 1.2, phase)
		var color = Color(accent if i % 2 == 0 else accent_2, .10 * alpha)
		fx.draw_line(Vector2(x, -10), Vector2(x - h * .55, h + 10), color, 26.0 + i * 6.0, true)
		fx.draw_line(Vector2(x, -10), Vector2(x - h * .55, h + 10), Color(Color.WHITE, .05 * alpha), 2.0, true)
	# Equalizer along the bottom edge, gently pulsing at the song's tempo.
	var bpm = float(game.chart_bpm()) if game != null else 128.0
	var beat = exp(-fmod(elapsed * bpm / 60.0, 1.0) * 4.0)
	var count = 64
	var bar_w = w / count
	for i in count:
		var n = .5 + .5 * sin(i * 1.7 + elapsed * 3.1) * sin(i * .43 + elapsed * 1.3)
		var height = h * (.02 + .07 * n * (.6 + .4 * beat))
		var color = accent_2.lerp(accent, float(i) / count)
		fx.draw_rect(Rect2(i * bar_w + 2, h - height, bar_w - 4, height), Color(color, .55 * alpha))
		fx.draw_rect(Rect2(i * bar_w + 2, h - height, bar_w - 4, 3), Color(color.lightened(.5), .8 * alpha))
	# Detail chips under the title: difficulty, section, tempo and play mode.
	var font = ThemeDB.fallback_font
	var info_alpha = eyebrow.modulate.a
	var x = title.position.x; var y = title.position.y + title.size.y + 14
	for chip in chips:
		var text_w = font.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var rect = Rect2(x, y, text_w + 32, 38)
		var box = StyleBoxFlat.new(); box.set_corner_radius_all(19)
		box.bg_color = Color(accent.darkened(.55), .75 * info_alpha); box.border_color = Color(accent.lerp(Color.WHITE,.35), .8 * info_alpha)
		box.set_border_width_all(1)
		fx.draw_style_box(box, rect)
		fx.draw_string(font, Vector2(x + 16, y + 25), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, info_alpha))
		x += rect.size.x + 10

func draw_bar() -> void:
	var width = bar.size.x; var height = bar.size.y
	var fill = load_progress()
	var segments = 28
	var gap = 4.0
	var seg_w = (width - gap * (segments - 1)) / segments
	var lit = fill * segments
	for i in segments:
		var rect = Rect2(i * (seg_w + gap), 0, seg_w, height)
		var amount = clampf(lit - i, 0.0, 1.0)
		bar.draw_rect(rect, Color(1, 1, 1, .08))
		if amount > 0.0:
			var color = accent_2.lerp(accent, float(i) / segments)
			bar.draw_rect(Rect2(rect.position - Vector2(0, 3), Vector2(seg_w, height + 6)), Color(color, .18 * amount))
			bar.draw_rect(Rect2(rect.position, Vector2(seg_w * amount, height)), Color(color.lightened(.15), amount))
	# A bright glint sweeps along the lit segments.
	var filled = width * fill
	if filled > 6.0:
		var glint_x = fmod(elapsed * 520.0, filled + 80.0) - 40.0
		bar.draw_rect(Rect2(clampf(glint_x, 0.0, filled - 6.0), 0, 6, height), Color(1, 1, 1, .75))
