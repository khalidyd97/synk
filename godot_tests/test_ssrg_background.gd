extends SceneTree
const Background = preload("res://scripts/ssrg_background.gd")
func _initialize() -> void:
	var bg = Background.new()
	root.add_child(bg)
	bg.rng.seed = 73
	bg.configure(0)
	assert(bg.materials[0].get_shader_parameter("artwork") is Texture2D)
	assert(is_zero_approx(Background.progress(0, 1, 0.05)))
	assert(is_equal_approx(Background.progress(0.5, 1, 0.05), pow(0.5, 0.1)))
	for _i in 180:
		bg.advance(1.0 / 60.0)
	assert(bg.particles.size() >= 10 and bg.particles.size() <= 65)
	assert(bg.meshes.size() == 2)
	var time: float = bg.elapsed
	var count: int = bg.particles.size()
	bg.advance(1, true)
	assert(bg.elapsed == time and bg.particles.size() == count)
	var q = Background.source_vertices(Vector3(100, 400, 200), Vector3(-1, -1, -1).normalized(), Vector2(2000, 8), 300)
	assert(is_equal_approx(q[1].y - q[0].y, 8.0 * 200.0 / 300.0))
	for profile in 4:
		bg.configure(profile)
		for _i in 120:
			bg.advance(1.0 / 60.0)
		assert(bg.particles.size() <= int(Background.DATA.PROFILES[profile].countmax))
	print("SSRG background source profiles, native warp/geometry, pooling bounds and pause checks passed")
	quit()

