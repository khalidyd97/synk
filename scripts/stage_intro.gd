extends Control

# Song intro before gameplay: a loading screen built from the cover art and the song's colors,
# then an entrance where the cover and details slide away over the stationary highway.
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
	# One moderate Gaussian treatment for backgrounds and album-art-only songs.
	# The square loading card stays sharp and floats above this transitioning layer.
	var blurred=preload("res://scripts/gaussian_blur.gd").of(cover,72,4.0) if cover else null
	backdrop_art.material.set_shader_parameter("blurred_art",blurred if blurred else cover)
	backdrop_art.material.set_shader_parameter("blur_amount",1.0 if skip_loading else 0.0)
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

func card_side() -> float: return minf(size.y*.55,size.x*.28)

func card_home() -> Vector2: return Vector2(size.x*.64,(size.y-card_side())*.42)

func layout() -> void:
	var side=card_side()
	card.size=Vector2(side,side);card.pivot_offset=card.size*.5
	card_art.material.set_shader_parameter("rect_size",card.size)
	reflection.size=Vector2(side,side*.3)
	info_x=size.x*.08;info_width=size.x*.49
	var top=size.y*.20
	for label in [eyebrow,title,status,percent]:label.position.x=info_x;label.size=Vector2(info_width,40)
	eyebrow.position.y=top
	title.position.y=top+size.y*.09;title.size.y=size.y*.23
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size",clampi(roundi(size.y*.085),28,66))
	meta_label.visible=true;meta_label.position=Vector2(info_x,top+size.y*.34);meta_label.size=Vector2(info_width,40)
	meta_label.add_theme_font_size_override("font_size",clampi(roundi(size.y*.029),14,21))
	status.position=Vector2(info_x,size.y*.77);status.size=Vector2(size.x*.58,30)
	percent.position=Vector2(size.x*.80,size.y*.77);percent.size=Vector2(size.x*.12,30)
	bar.position=Vector2(info_x,size.y*.85);bar.size=Vector2(size.x*.84,4)
	tip.position=Vector2(info_x,size.y*.90);tip.size=Vector2(size.x*.84,30)
	tip.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	tip.add_theme_font_size_override("font_size",clampi(roundi(size.y*.025),12,18))

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
	backdrop_art.material.set_shader_parameter("blur_amount",blur_progress)
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
		card.rotation=-.025*(1.0-e)
		card.scale=Vector2.ONE*lerpf(.96,1.0,appear)
		card.modulate=Color(.9,.9,.9,ui_alpha if not arriving else 1.0-smoothstep(0.0,.8,e))
	reflection.visible=false
	for label in [eyebrow,title,meta_label]:
		label.modulate.a=ui_alpha;label.position.x=info_x+(1.0-appear)*15
	for label in [status,percent,tip]:label.modulate.a=ui_alpha
	bar.modulate=Color(1,1,1,ui_alpha)
	eyebrow.text="SYNK  /  ON STAGE"
	status.text="PREPARING YOUR STAGE" if load_progress()<1 else "READY TO PLAY"
	percent.text="%02d%%" % roundi(load_progress()*100)
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
	card.rotation=-.025*(1.0-t)*(1.0-t)
	card.scale=Vector2.ONE*lerpf(.96,1.0,appear)
	var light=lerpf(.9,1.0,t)
	card.modulate=Color(light,light,light,1.0 if flying else appear)
	card_art.material.set_shader_parameter("rect_size",card.size)

func draw_fx() -> void:
	var after_load=maxf(0.0,elapsed-load_time)
	var alpha=0.0 if load_time<=0.0 else (1.0-smoothstep(0.0,LOADING_UI_FADE_TIME,after_load))
	if alpha<=0:return
	var w=size.x;var h=size.y
	# A quiet editorial stage card: oversized artwork, cropped orbital lines,
	# and one luminous horizon instead of the former moving stripes/equalizer.
	fx.draw_polygon(PackedVector2Array([Vector2(w*.57,0),Vector2(w,0),Vector2(w,h),Vector2(w*.48,h)]),PackedColorArray([Color(accent,.04*alpha),Color(accent,.16*alpha),Color(accent_2,.04*alpha),Color(accent_2,0)]))
	var center=card_home()+Vector2.ONE*card_side()*.5
	for i in 3:
		var radius=card_side()*(.66+i*.09)
		fx.draw_arc(center,radius,-PI*.95,PI*.65,96,Color(accent_2,(.16-i*.04)*alpha),1.0,true)
	fx.draw_line(Vector2(w*.08,h*.12),Vector2(w*.92,h*.12),Color(1,1,1,.12*alpha),1,true)
	fx.draw_string(ThemeDB.fallback_font,Vector2(w*.08,h*.10),"THE NEXT TRACK",HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(12,roundi(h*.022)),Color(1,1,1,.55*alpha))
	var travel=fposmod(elapsed*.2,1.0)
	fx.draw_circle(Vector2(w*.08+w*.84*travel,h*.12),2.5,Color(accent_2,alpha))

func draw_bar() -> void:
	var width=bar.size.x;var height=bar.size.y;var fill=load_progress()
	bar.draw_rect(Rect2(0,0,width,height),Color(1,1,1,.12))
	if fill<=0:return
	bar.draw_rect(Rect2(0,-4,width*fill,height+8),Color(accent_2,.10))
	bar.draw_rect(Rect2(0,0,width*fill,height),accent_2.lerp(Color.WHITE,.4))
	bar.draw_circle(Vector2(width*fill,height*.5),4,Color.WHITE)
