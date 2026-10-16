extends Control

# Original concert lighting; every motion closes over the same twelve-second loop.
const LOOP_SECONDS = 12.0

var art_material: ShaderMaterial
var elapsed = 0.0

func _ready() -> void:
	var art = ColorRect.new(); add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_material = ShaderMaterial.new(); art_material.shader = load("res://loop.gdshader")
	art.material = art_material
	art_material.set_shader_parameter("phase", 0.0)
	# Optional "-- --phase=0.25" starts mid-loop, for checking single frames.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): elapsed = float(arg.get_slice("=", 1)) * LOOP_SECONDS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--still="): save_still.call_deferred(arg.trim_prefix("--still="))

func save_still(path: String) -> void:
	await RenderingServer.frame_post_draw
	var error = get_viewport().get_texture().get_image().save_png(path)
	print("Lobby still saved: ", error)
	get_tree().quit(error)

func _process(delta: float) -> void:
	# Movie Maker runs at a fixed frame rate, so delta is exactly 1/fps for every frame.
	art_material.set_shader_parameter("phase", fmod(elapsed / LOOP_SECONDS, 1.0))
	elapsed += delta
