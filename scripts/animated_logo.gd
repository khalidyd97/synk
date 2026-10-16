extends TextureRect

# SVG animation baked into a transparent atlas for Android's native renderer.
const ATLASES = [preload("res://assets/brand/logo_animation.png"),
	preload("res://assets/brand/logo_animation_1.png"),
	preload("res://assets/brand/logo_animation_2.png"),
	preload("res://assets/brand/logo_animation_3.png")]
const FRAME_SIZE = Vector2(512,182)
const FRAME_COUNT = 450
const FPS = 60.0
var elapsed = 0.0
var frame_texture: AtlasTexture
var last_frame = -1

func _ready() -> void:
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame_texture=AtlasTexture.new()
	frame_texture.atlas=ATLASES[0]
	frame_texture.filter_clip=true
	texture=frame_texture
	update_frame()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed=fmod(elapsed+delta,FRAME_COUNT/FPS)
	update_frame()

func update_frame() -> void:
	var frame=int(elapsed*FPS)%FRAME_COUNT
	if frame==last_frame: return
	last_frame=frame
	frame_texture.atlas=ATLASES[frame/120]
	var local_frame=frame%120
	frame_texture.region=Rect2(Vector2(local_frame%6,local_frame/6)*FRAME_SIZE,FRAME_SIZE)
