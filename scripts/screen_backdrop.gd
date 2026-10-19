extends Control
# Full-screen background for menu screens: real footage (or the selected song's album art),
# colour-graded live, dimmed, and paused whenever its screen is hidden.
#   video mode: one shared clip, recoloured by hue rotation, so every screen gets its own
#               colour without another video in the APK.
#   art mode:   a cover texture, heavily blurred, slowly drifting and zooming.
const VIDEO = "res://assets/lobby/ui/lobby_background_v2.ogv"
const VIDEO_SIZE = Vector2(1280, 576)

var video_path = VIDEO
var hue_shift = 0.0        # turns: 0 = original red, 0.17 = violet, 0.08 = magenta, -0.11 = gold
var saturation = 1.0
var brightness = 1.0
var dim = 0.45
var player: VideoStreamPlayer
var art: TextureRect
var art_material: ShaderMaterial
var shade: ColorRect
var time = 0.0

static func video(parent: Control, hue: float, dim_amount: float = .45, sat: float = 1.0, path: String = VIDEO, light: float = 1.0) -> Control:
	var node = load("res://scripts/screen_backdrop.gd").new(); node.hue_shift = hue; node.dim = dim_amount; node.saturation = sat; node.video_path = path; node.brightness = light
	parent.add_child(node); node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return node

static func album_art(parent: Control, dim_amount: float = .55) -> Control:
	var node = load("res://scripts/screen_backdrop.gd").new(); node.hue_shift = INF; node.dim = dim_amount
	parent.add_child(node); node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return node

func _ready() -> void:
	name = "ScreenBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE; clip_contents = true
	if is_inf(hue_shift):
		art = TextureRect.new(); add_child(art); art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_material = ShaderMaterial.new(); art_material.shader = preload("res://scripts/blurred_art.gdshader"); art.material = art_material
	else:
		var stream = load(video_path)
		if stream:
			player = VideoStreamPlayer.new(); add_child(player); player.stream = stream
			player.loop = true; player.expand = true; player.volume_db = -80; player.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var grade = ShaderMaterial.new(); grade.shader = preload("res://scripts/video_grade.gdshader"); player.material = grade
			grade.set_shader_parameter("hue_shift", hue_shift); grade.set_shader_parameter("saturation", saturation)
			grade.set_shader_parameter("brightness", brightness)
	shade = ColorRect.new(); add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, .02, dim); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(fit); fit()

func fit() -> void:
	if player:
		var k = maxf(size.x / VIDEO_SIZE.x, size.y / VIDEO_SIZE.y)
		player.size = VIDEO_SIZE * k; player.position = (size - player.size) * .5
	if art:
		art.size = size * 1.12; art.position = -size * .06; art.pivot_offset = art.size * .5

# Crossfades to a new cover (art mode).
func set_art(texture: Texture2D) -> void:
	if not art or art.texture == texture: return
	var old = art.duplicate() as TextureRect; add_child(old); move_child(old, art.get_index() + 1)
	old.material = art.material.duplicate()
	art.texture = texture
	var tween = create_tween(); tween.tween_property(old, "modulate:a", 0.0, .5); tween.tween_callback(old.queue_free)

func _process(delta: float) -> void:
	var showing = is_visible_in_tree()
	if player:
		if showing and not player.is_playing(): player.play()
		player.paused = not showing
	if art and showing:
		time += delta
		art.scale = Vector2.ONE * (1.0 + .04 * sin(time * .12))
		art.rotation = .015 * sin(time * .07)
