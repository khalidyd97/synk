extends Control
# The song's album art at the highway entrance. The loading card glides into
# this exact rectangle, then this panel takes over with the same look.
const RADIUS = 22.0
var game: Control
var frame: Panel
var art: TextureRect
var rim: Panel
var song_id = ""
var hit_glow=0.0
var glare_age=1.0
var glow_style:StyleBoxFlat
var base_shadow=Color.TRANSPARENT
var base_shadow_size=0

func _ready() -> void:
	name = "PlayCover"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame = Panel.new(); add_child(frame); frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art = TextureRect.new(); frame.add_child(art); art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rounded = ShaderMaterial.new(); rounded.shader = preload("res://scripts/rounded_image.gdshader")
	rounded.set_shader_parameter("radius",RADIUS); art.material = rounded
	rim = Panel.new(); frame.add_child(rim); rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

# Where the loading cover lands; results flights use this same rectangle.
func target_rect() -> Rect2:
	var side = clampf(size.y*.20,72.0,170.0)
	var entrance=game.field.get_global_transform_with_canvas()*game.field.project(game.field.world.CENTER_LANE,1.0)
	var center=get_global_transform_with_canvas().affine_inverse()*entrance
	return Rect2(Vector2(clampf(center.x-side*.5,0.0,maxf(0.0,size.x-side)),size.y*.025),Vector2(side,side))

func wanted() -> bool:
	return game.mode in ["play","paused"] and not game.uses_recorder_colors() and not game.stage_intro.running()

# Called by the loading screen on its last frame, so the panel appears in that same frame.
func take_over() -> void:
	_process(0.0)

# Copies the loading card's art and frame colours so the hand-off is seamless.
func style_from(texture: Texture2D, tint: Color, frame_style: StyleBox, rim_style: StyleBox) -> void:
	art.texture = texture; art.self_modulate = tint
	frame.add_theme_stylebox_override("panel",frame_style.duplicate())
	glow_style=frame.get_theme_stylebox("panel") as StyleBoxFlat
	if glow_style:
		base_shadow=glow_style.shadow_color;base_shadow_size=glow_style.shadow_size
	hit_glow=0.0;glare_age=1.0
	rim.add_theme_stylebox_override("panel",rim_style)
	song_id = str(game.song.id)

func on_note_hit(grade:String) -> void:
	if grade=="MISS" or game.mode!="play" or not wanted():return
	hit_glow=maxf(hit_glow,1.0 if grade=="PERFECT" else .7)
	# Dense runs keep one flowing sweep instead of pinning it at its first frame.
	if glare_age>=.32:glare_age=0.0

func _process(_delta: float) -> void:
	visible = wanted() and art.texture != null and song_id == str(game.song.id)
	if not visible: return
	if game.mode=="play":
		hit_glow*=exp(-_delta*6.0)
		glare_age=minf(1.0,glare_age+_delta)
	art.material.set_shader_parameter("hit_glow",hit_glow)
	art.material.set_shader_parameter("glare_progress",clampf(glare_age/.45,0,1))
	if glow_style:
		glow_style.shadow_color=Color(base_shadow,clampf(base_shadow.a+hit_glow*.55,0,1))
		glow_style.shadow_size=base_shadow_size+roundi(hit_glow*18)
	var rect = target_rect()
	frame.position = rect.position; frame.size = rect.size
	art.material.set_shader_parameter("rect_size",rect.size)
	modulate.a = float(game.score_panel.modulate.a) if game.score_panel else 1.0
