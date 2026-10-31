extends Control
# The song's album art on the right side with the SSRG look (imports and the "ssrg" style). The loading card glides into
# this exact rectangle (stage_intro.gd), then this panel takes over with the same look.
const RADIUS = 22.0
var game: Control
var frame: Panel
var art: TextureRect
var rim: Panel
var song_id = ""

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

# Where the art sits during play, in this control's coordinates: right side, below the BEST line.
func target_rect() -> Rect2:
	var side = clampf(size.y*.24,96.0,260.0)
	return Rect2(Vector2(size.x-side-size.x*.03,size.y*.15),Vector2(side,side))

func wanted() -> bool:
	return game.uses_ssrg_gameplay() and game.mode in ["play","paused"] and not game.stage_intro.running()

# Called by the loading screen on its last frame, so the panel appears in that same frame.
func take_over() -> void:
	_process(0.0)

# Copies the loading card's art and frame colours so the hand-off is seamless.
func style_from(texture: Texture2D, tint: Color, frame_style: StyleBox, rim_style: StyleBox) -> void:
	art.texture = texture; art.self_modulate = tint
	frame.add_theme_stylebox_override("panel",frame_style)
	rim.add_theme_stylebox_override("panel",rim_style)
	song_id = str(game.song.id)

func _process(_delta: float) -> void:
	visible = wanted() and art.texture != null and song_id == str(game.song.id)
	if not visible: return
	var rect = target_rect()
	frame.position = rect.position; frame.size = rect.size
	art.material.set_shader_parameter("rect_size",rect.size)
	modulate.a = float(game.score_panel.modulate.a) if game.score_panel else 1.0
