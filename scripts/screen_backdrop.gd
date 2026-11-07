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
var art_front: TextureRect   # the cover at its own square shape, over the wide blurred fill
var stack: Control           # art mode: one layer per cover; a new cover fades in on top
const FADE_SECONDS = .6
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
		stack = Control.new(); add_child(stack); stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		make_layer(null)
	else:
		# Signal Arcade: menu screens draw the lane-grid stage instead of stage footage.
		var stage = ColorRect.new(); add_child(stage); stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE; stage.color = Color.WHITE
		var mat = preload("res://scripts/background_motion.gd").attach(stage, preload("res://scripts/song_browser_background.gdshader"))
		mat.set_shader_parameter("ambience", Color.from_hsv(fposmod(.75 + hue_shift, 1.0), .7, .5))
		return
	shade = ColorRect.new(); add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(.06, .055, .07, maxf(dim, .62)); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Darker toward the bottom, where buttons and lists sit.
	var fall = TextureRect.new(); add_child(fall); fall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fall.mouse_filter = Control.MOUSE_FILTER_IGNORE; fall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; fall.stretch_mode = TextureRect.STRETCH_SCALE
	var ramp = Gradient.new(); ramp.set_color(0, Color(.06, .055, .07, 0)); ramp.set_color(1, Color(.06, .055, .07, .55))
	var fall_texture = GradientTexture2D.new(); fall_texture.gradient = ramp; fall_texture.fill_from = Vector2(0, 0); fall_texture.fill_to = Vector2(0, 1)
	fall_texture.width = 4; fall_texture.height = 64; fall.texture = fall_texture
	# The arcade lane grid glows over the blurred cover.
	var grid = ColorRect.new(); add_child(grid); grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE; grid.color = Color.WHITE
	var grid_mat = preload("res://scripts/background_motion.gd").attach(grid, preload("res://scripts/song_browser_background.gdshader"))
	grid_mat.set_shader_parameter("overlay", 1.0); grid_mat.set_shader_parameter("grid_strength", .8)
	resized.connect(fit); fit()

func fit() -> void:
	if player:
		var k = maxf(size.x / VIDEO_SIZE.x, size.y / VIDEO_SIZE.y)
		player.size = VIDEO_SIZE * k; player.position = (size - player.size) * .5
	if stack:
		for layer in stack.get_children(): fit_layer(layer)

# Art mode: a wide blurred fill plus the cover at its own square shape, as one layer.
func make_layer(texture: Texture2D) -> Control:
	var layer = Control.new(); stack.add_child(layer); layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var wide = TextureRect.new(); layer.add_child(wide); wide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wide.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; wide.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var wide_mat = ShaderMaterial.new(); wide_mat.shader = preload("res://scripts/blurred_art.gdshader"); wide.material = wide_mat
	wide_mat.set_shader_parameter("radius", .1)
	var front = TextureRect.new(); layer.add_child(front); front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; front.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var front_mat = ShaderMaterial.new(); front_mat.shader = preload("res://scripts/blurred_art.gdshader"); front.material = front_mat
	front_mat.set_shader_parameter("radius", .03); front_mat.set_shader_parameter("edge_fade", .3)
	wide.texture = texture; front.texture = texture
	art = wide; art_front = front; art_material = wide_mat
	fit_layer(layer)
	return layer

func fit_layer(layer: Control) -> void:
	if layer.get_child_count() < 2: return
	var wide: TextureRect = layer.get_child(0); var front: TextureRect = layer.get_child(1)
	wide.size = size * 1.04; wide.position = -size * .02; wide.pivot_offset = wide.size * .5
	# The cover itself: a square as tall as the screen, so it is not blown up to the width.
	var side = size.y * 1.1
	front.size = Vector2(side, side); front.position = (size - front.size) * .5; front.pivot_offset = front.size * .5

# Crossfades to a new cover (art mode). The new cover fades in over whatever is showing,
# and older layers are only removed once something fully opaque covers them, so quick
# taps through the list blend smoothly instead of cutting.
func set_art(texture: Texture2D) -> void:
	if not stack or art.texture == texture: return
	var layer = make_layer(texture)
	layer.modulate.a = 0.0
	var tween = layer.create_tween()
	tween.tween_property(layer, "modulate:a", 1.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		for older in stack.get_children():
			if older == layer: break
			older.queue_free())
	# Keep the stack short even under very fast scrolling.
	while stack.get_child_count() > 5: stack.get_child(0).free()

func _process(delta: float) -> void:
	var showing = is_visible_in_tree()
	if player:
		if showing and not player.is_playing(): player.play()
		player.paused = not showing
	if stack and showing:
		time += delta
		var zoom = Vector2.ONE * (1.0 + .02 * sin(time * .12)); var front_zoom = Vector2.ONE * (1.0 + .015 * sin(time * .1))
		for layer in stack.get_children():
			if layer.get_child_count() < 2: continue
			layer.get_child(0).scale = zoom; layer.get_child(1).scale = front_zoom
