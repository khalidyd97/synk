extends Control

# Song intro before gameplay: a loading screen built from the cover art and the song's colors,
# then an entrance where the cover and details slide away over the stationary highway.
# The loading screen previews the stage being built: the cover sits centred near the top,
# where it stays during play; two rails of light draw themselves up from the bottom corners
# toward it as the song loads; the title stands on the road between them; and a line of
# light grows from the centre outward, like the judgment bar, as the percentage climbs.
const LOAD_TIME = 5.0
const ENTER_TIME = 2.40
# The post-load handoff is deliberately serial: first resolve the full-screen
# artwork into its Gaussian version, crossfade that unchanged dim background into
# the gameplay backdrop, then reveal the highway while moving the card.
const LOADING_UI_FADE_TIME = .24
const BLUR_TIME = .32
const BACKGROUND_FADE_TIME = .20
const BACKDROP_DIM = .70
const NAVY = Color(.006,.008,.025)
const TIPS = [
	"Hold notes: keep your finger down until the ring reaches the bar.",
	"Slides: move your finger through every connector to the final note.",
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
var blur_backdrop = true
var info_x = 0.0
var info_width = 0.0
# Every song: the cover glides into the play_cover panel instead of sliding away.
var play_cover: Control
var gliding = false
# Pressing Play: the cover starts where it sat in the song list and grows into the loading card.
const ARRIVE_TIME = .55
var arrive_from = Rect2()
var arriving = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = ColorRect.new(); add_child(backdrop); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = NAVY; backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_art = TextureRect.new(); add_child(backdrop_art); backdrop_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; backdrop_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blur_material=ShaderMaterial.new();blur_material.shader=preload("res://scripts/loading_blur.gdshader")
	backdrop_art.material=blur_material
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
	var wide = FontVariation.new(); wide.base_font = ThemeDB.fallback_font; wide.variation_embolden = .55; wide.spacing_glyph = 7
	title = caption(66,Color("fffaf0"),wide); title.add_theme_constant_override("outline_size",6)
	meta_label = caption(21,Color("e9dccb")); meta_label.visible = false
	status = caption(17,Color("cfd6ff"),spaced)
	percent = caption(17,Color("f6efff"),spaced); percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tip = caption(18,Color(.82,.84,.98,.8)); tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for label in [eyebrow,title,meta_label,status]: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	var song_id=str(game.song.id) if game and not game.song.is_empty() else ""
	var backdrop_source=game.stage_backdrop_for_id(song_id) if game else cover
	blur_backdrop=game==null or (not game.has_background(song_id) and game.has_album_art(song_id))
	backdrop_art.texture=backdrop_source;backdrop_art.self_modulate=tint
	for art in [card_art,reflection]: art.texture=cover;art.self_modulate=tint
	# Only an album-art fallback receives the Gaussian treatment. A dedicated
	# gameplay background remains sharp while retaining the same fixed dimming.
	var blurred=preload("res://scripts/gaussian_blur.gd").of(backdrop_source,72,4.0) if backdrop_source and blur_backdrop else backdrop_source
	backdrop_art.material.set_shader_parameter("blurred_art",blurred if blurred else backdrop_source)
	backdrop_art.material.set_shader_parameter("blur_amount",1.0 if skip_loading and blur_backdrop else 0.0)
	backdrop_art.material.set_shader_parameter("dim_amount",BACKDROP_DIM)
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
	style_cover(cover,tint)
	load_time = 0.0 if skip_loading else LOAD_TIME
	elapsed = 0.0; visible = true
	arriving = arrive_from.has_area() and not skip_loading
	layout(); animate()
	if not arriving: arrive_from = Rect2()

func style_cover(cover: Texture2D, tint: Color) -> void:
	# Glow behind the cover, and a light rim drawn over its rounded edge.
	var frame = StyleBoxFlat.new(); frame.bg_color = accent.darkened(.92); frame.set_corner_radius_all(22)
	frame.shadow_color = Color(accent,.24); frame.shadow_size = 24
	card.add_theme_stylebox_override("panel",frame)
	var rim = StyleBoxFlat.new(); rim.bg_color = Color(0,0,0,0); rim.set_corner_radius_all(22)
	rim.border_color = Color(accent.lerp(Color.WHITE,.45),.45); rim.set_border_width_all(2)
	card_rim.add_theme_stylebox_override("panel",rim)
	gliding = game != null and play_cover != null and not game.uses_recorder_colors()
	if gliding: play_cover.style_from(cover,tint,frame,rim)

func show_gameplay_cover(cover: Texture2D, tint: Color) -> void:
	accent = song_colors(cover)[0]
	style_cover(cover,tint)
	skip()
	if gliding: play_cover.take_over()

# Called just before begin(): the on-screen rectangle the cover flies in from.
func arrive(global_rect: Rect2) -> void:
	var to_local = get_global_transform_with_canvas().affine_inverse()
	arrive_from = Rect2(to_local * global_rect.position, to_local.basis_xform(global_rect.size))

# The card's resting rectangle on the loading screen, or on its way there from the song list.
func home_rect(appear: float) -> Rect2:
	var side = card_side()
	if not arriving: return Rect2(card_home()+Vector2(0,(1.0-appear)*25),Vector2(side,side))
	var k = smoothstep(0.0,ARRIVE_TIME,elapsed)
	var rect = Rect2(arrive_from.position.lerp(card_home(),k),arrive_from.size.lerp(Vector2(side,side),k))
	rect.position.y -= sin(k*PI)*size.y*.03
	if k >= 1.0: arriving = false; arrive_from = Rect2()
	return rect

func skip() -> void:
	elapsed = load_time + ENTER_TIME; visible = false

func running() -> bool: return visible and elapsed < load_time + ENTER_TIME

# 0 while the loading screen is up, easing to 1 as the stage finishes entering.
func entrance() -> float:
	if not visible: return 1.0
	var background_wait=(LOADING_UI_FADE_TIME+BLUR_TIME+BACKGROUND_FADE_TIME) if load_time>0.0 else 0.0
	var e = clampf((elapsed-load_time-background_wait)/maxf(.001,ENTER_TIME-background_wait),0.0,1.0)
	return e * e * (3.0 - 2.0 * e)

# Separate windows let the world assemble in readable layers without moving the camera.
func reveal_part(start:float,finish:float) -> float:
	if not visible:return 1.0
	var background_wait=(LOADING_UI_FADE_TIME+BLUR_TIME+BACKGROUND_FADE_TIME) if load_time>0.0 else 0.0
	var raw=clampf((elapsed-load_time-background_wait)/maxf(.001,ENTER_TIME-background_wait),0.0,1.0)
	return smoothstep(start,finish,raw)

func card_side() -> float: return minf(size.y*.40,size.x*.24)

# Centred near the top: the far end of the highway the rails are drawn toward.
func card_home() -> Vector2: return Vector2((size.x-card_side())*.5,size.y*.11)

func layout() -> void:
	var side=card_side()
	card.size=Vector2(side,side);card.pivot_offset=card.size*.5
	card_art.material.set_shader_parameter("rect_size",card.size)
	reflection.size=Vector2(side,side*.3)
	# Everything is centred on the road between the two rails.
	info_width=size.x*.56;info_x=(size.x-info_width)*.5
	for label in [eyebrow,title,meta_label,status,tip]:label.position.x=info_x;label.size=Vector2(info_width,40)
	eyebrow.position.y=size.y*.035
	eyebrow.add_theme_font_size_override("font_size",clampi(roundi(size.y*.022),11,19))
	var below=card_home().y+side
	title.position.y=below+size.y*.035;title.size.y=size.y*.16
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size",clampi(roundi(size.y*.062),22,54))
	meta_label.visible=true;meta_label.position.y=below+size.y*.20
	meta_label.add_theme_font_size_override("font_size",clampi(roundi(size.y*.026),12,20))
	status.position.y=size.y*.80
	status.add_theme_font_size_override("font_size",clampi(roundi(size.y*.022),11,17))
	percent.visible=false
	bar.size=Vector2(size.x*.46,4);bar.position=Vector2((size.x-bar.size.x)*.5,size.y*.865)
	tip.position.y=size.y*.90
	tip.add_theme_font_size_override("font_size",clampi(roundi(size.y*.024),11,17))

func vanishing_point() -> Vector2:
	# Far end of the highway, converted from the stage's screen space into this control.
	if game == null or game.field == null: return Vector2(size.x * .5, size.y * .1)
	var far = game.field.get_global_transform_with_canvas() * game.field.project(game.field.world.CENTER_LANE, 1.0)
	return get_global_transform_with_canvas().affine_inverse() * far

# The bar shows real work: the chart's notes being built and the stage's shaders being
# prepared. It never runs ahead of them, and the card stays up until they're done (small
# charts finish well inside the minimum time).
func build_progress() -> float:
	if game == null or game.field == null: return 1.0
	return minf(game.field.world.prebuild_progress(), game.field.world.warmup_progress())
func load_progress() -> float:
	if load_time <= 0.0: return 1.0
	var t = clampf(elapsed / (load_time * .9), 0.0, 1.0)
	return minf(1.0 - pow(1.0 - t, 2.2), build_progress())

func _process(delta: float) -> void:
	if not visible: return
	if game and game.mode == "play":
		# The first loading frames can stall while the chart builds; the arrival still plays out.
		elapsed += minf(delta,.034) if arriving else delta
		# Hold on the loading card until every note is built.
		if load_time > 0.0 and build_progress() < 1.0: elapsed = minf(elapsed, load_time * .95)
	elif game and game.mode != "paused": visible = false; return
	animate()
	if elapsed >= load_time + ENTER_TIME:
		visible = false
		if gliding: play_cover.take_over()

func animate() -> void:
	var appear=smoothstep(0.0,.5,elapsed) if load_time>0 else 1.0
	var e=entrance()
	# Loading stays completely sharp. Only a genuinely completed load starts this clock.
	var after_load=maxf(0.0,elapsed-load_time)
	var ui_alpha=0.0 if load_time<=0.0 else appear*(1.0-smoothstep(0.0,LOADING_UI_FADE_TIME,after_load))
	var blur_start=LOADING_UI_FADE_TIME
	var blur_progress=1.0 if load_time<=0.0 else smoothstep(blur_start,blur_start+BLUR_TIME,after_load)
	backdrop_art.material.set_shader_parameter("blur_amount",blur_progress if blur_backdrop else 0.0)
	# Blur never changes brightness. Once it is fully resolved, crossfade to the
	# identically blurred gameplay backdrop before any highway geometry enters.
	var background_start=LOADING_UI_FADE_TIME+BLUR_TIME
	var background_mix=1.0 if load_time<=0.0 else smoothstep(background_start,background_start+BACKGROUND_FADE_TIME,after_load)
	var curtain_alpha=1.0-background_mix
	backdrop.color=Color(loading_shadow,curtain_alpha)
	backdrop_art.modulate.a=.52*appear*curtain_alpha
	backdrop_art.pivot_offset=size*.5;backdrop_art.scale=Vector2.ONE*1.06
	if gliding: glide_card(appear)
	else:
		var rest=home_rect(appear); card.size=rest.size; card.pivot_offset=card.size*.5
		card_art.material.set_shader_parameter("rect_size",card.size)
		card.position=rest.position+Vector2(e*e*size.x*.35,0)
		card.rotation=0.0
		card.scale=Vector2.ONE*lerpf(.96,1.0,appear)
		card.modulate=Color(.9,.9,.9,ui_alpha if not arriving else 1.0-smoothstep(0.0,.8,e))
	reflection.visible=false
	for label in [eyebrow,title,meta_label]:
		label.modulate.a=ui_alpha;label.position.x=info_x+(1.0-appear)*15
	for label in [status,percent,tip]:label.modulate.a=ui_alpha
	bar.modulate=Color(1,1,1,ui_alpha)
	eyebrow.text="NEXT  TRACK"
	status.text="BUILDING YOUR STAGE   %d%%" % roundi(load_progress()*100) if load_progress()<1 else "READY"
	bar.queue_redraw();fx.queue_redraw()

# The cover keeps full opacity and travels on an eased curve from the loading card to the
# gameplay panel's rectangle, shrinking as it goes, so the hand-off has no visible jump.
func glide_card(appear: float) -> void:
	var background_wait=(LOADING_UI_FADE_TIME+BLUR_TIME+BACKGROUND_FADE_TIME) if load_time>0.0 else 0.0
	var raw=clampf((elapsed-load_time-background_wait)/maxf(.001,ENTER_TIME-background_wait),0.0,1.0) if visible else 1.0
	var t=raw*raw*raw*(raw*(raw*6.0-15.0)+10.0)
	var flying=arriving
	var start=home_rect(appear)
	var target=play_cover.target_rect()
	var to_local=get_global_transform_with_canvas().affine_inverse()*play_cover.get_global_transform_with_canvas()
	var end=Rect2(to_local*target.position,to_local.basis_xform(target.size))
	card.size=start.size.lerp(end.size,t);card.pivot_offset=card.size*.5
	card.position=start.position.lerp(end.position,t)
	# A gentle lift along the way instead of a straight line.
	card.position.y-=sin(t*PI)*size.y*.04
	card.rotation=0.0
	card.scale=Vector2.ONE*lerpf(.96,1.0,appear)
	var light=lerpf(.9,1.0,t)
	card.modulate=Color(light,light,light,1.0 if flying else appear)
	card_art.material.set_shader_parameter("rect_size",card.size)

# One rail of light from `from` toward `to`, drawn as far as `drawn` (0..1): a faint guide
# for the whole path, then a soft glow, a body and a white-hot core up to a bright head.
func draw_rail(from: Vector2, to: Vector2, drawn: float, color: Color, alpha: float) -> void:
	var unit=size.y/720.0
	fx.draw_line(from,to,Color(color,.07*alpha),maxf(1.0,1.5*unit),true)
	if drawn<=0.0:return
	var head=from.lerp(to,drawn)
	# A wide soft glow, a tighter one, then the rail's coloured body.
	for layer in [[34.0,.06],[18.0,.11],[9.0,.2],[4.5,.7]]:
		fx.draw_line(from,head,Color(color,layer[1]*alpha),layer[0]*unit,true)
	fx.draw_line(from,head,Color(color.lerp(Color.WHITE,.8),.95*alpha),maxf(1.0,2.2*unit),true)
	for glow in [[16.0,.10],[9.0,.22]]:
		fx.draw_circle(head,glow[0]*unit,Color(color,glow[1]*alpha))
	fx.draw_circle(head,3.4*unit,Color(1,1,1,alpha))

func draw_fx() -> void:
	var after_load=maxf(0.0,elapsed-load_time)
	var alpha=0.0 if load_time<=0.0 else (1.0-smoothstep(0.0,LOADING_UI_FADE_TIME,after_load))
	if alpha<=0:return
	var w=size.x;var h=size.y
	var side=card_side();var home=card_home()
	# A floor of light under the road, in the song's colours.
	fx.draw_polygon(PackedVector2Array([Vector2(0,h),Vector2(w,h),Vector2(w,h*.55),Vector2(0,h*.55)]),PackedColorArray([Color(accent,.16*alpha),Color(accent_2,.16*alpha),Color(accent_2,0),Color(accent,0)]))
	var centre=home+Vector2.ONE*side*.5
	# The two rails, from the bottom corners up to the cover's lower corners, drawn as far
	# as the load has got: the highway is the progress bar.
	var drawn=load_progress()
	var foot_y=h*1.02
	var top_y=home.y+side+h*.012
	draw_rail(Vector2(w*-.02,foot_y),Vector2(centre.x-side*.46,top_y),drawn,accent,alpha)
	draw_rail(Vector2(w*1.02,foot_y),Vector2(centre.x+side*.46,top_y),drawn,accent_2,alpha)

# A line of light growing from the centre outward as the load completes, with a bright dot
# at each end, like the judgment bar.
func draw_bar() -> void:
	var width=bar.size.x;var fill=load_progress()
	var unit=size.y/720.0
	var mid=Vector2(width*.5,bar.size.y*.5)
	bar.draw_line(Vector2(0,mid.y),Vector2(width,mid.y),Color(1,1,1,.12),maxf(1.0,1.2*unit),true)
	if fill<=0:return
	var reach=width*.5*fill
	var warm=accent_2.lerp(Color.WHITE,.25)
	for layer in [[9.0,.10],[4.0,.22]]:
		bar.draw_line(mid-Vector2(reach,0),mid+Vector2(reach,0),Color(warm,layer[1]),layer[0]*unit,true)
	# White across the middle, warming to the song's colour at the ends.
	bar.draw_polyline_colors(PackedVector2Array([mid-Vector2(reach,0),mid,mid+Vector2(reach,0)]),PackedColorArray([warm,Color.WHITE,warm]),maxf(1.0,2.0*unit),true)
	for side in [-1,1]:
		bar.draw_circle(mid+Vector2(side*reach,0),3.2*unit,Color.WHITE)
