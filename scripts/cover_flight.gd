extends RefCounted
# The album art flies from where it sat during play to the results screen's cover. The real
# results cover stays hidden until the flying copy lands on it, then takes over.
const DURATION = .62

static func fly(game: Control, target: Control) -> void:
	var cover = game.stage_intro.play_cover if game.stage_intro else null
	if cover == null or target == null or cover.art.texture == null: return
	var source = cover.target_rect()
	var transform = cover.get_global_transform_with_canvas()
	var from = Rect2(transform * source.position, source.size * transform.get_scale())
	var layer = CanvasLayer.new(); layer.layer = 110; game.add_child(layer)
	var flyer = TextureRect.new(); layer.add_child(flyer); flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.texture = cover.art.texture; flyer.self_modulate = cover.art.self_modulate
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var rounded = ShaderMaterial.new(); rounded.shader = preload("res://scripts/rounded_image.gdshader"); flyer.material = rounded
	flyer.position = from.position; flyer.size = from.size
	target.modulate.a = 0.0
	# Wait one frame so the results layout (and the cover's final rectangle) has settled.
	await game.get_tree().process_frame
	if not is_instance_valid(target) or not is_instance_valid(flyer): return
	var to = target.get_global_rect()
	var step = func(t: float):
		if not is_instance_valid(flyer): return
		var k = t * t * (3.0 - 2.0 * t)
		var lift = sin(t * PI) * from.size.y * .12
		flyer.position = from.position.lerp(to.position, k) - Vector2(0, lift)
		flyer.size = from.size.lerp(to.size, k)
		rounded.set_shader_parameter("rect_size", flyer.size)
		rounded.set_shader_parameter("radius", lerpf(from.size.x * .14, to.size.x * .2, k))
	step.call(0.0)
	var tween = flyer.create_tween()
	tween.tween_method(step, 0.0, 1.0, DURATION)
	tween.tween_callback(func():
		if is_instance_valid(target): target.modulate.a = 1.0
		layer.queue_free())
