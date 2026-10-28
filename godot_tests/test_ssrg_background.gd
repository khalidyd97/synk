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
	var batch:MultiMesh=bg.meshes[0]
	var rid=batch.get_rid()
	var capacity=batch.instance_count
	assert(capacity>=int(Background.DATA.PROFILES[0].countmax))
	bg.advance(1.0/60)
	assert(bg.meshes[0].get_rid()==rid and batch.instance_count==capacity,"Rendering reuses fixed GPU batches")
	for mesh in bg.meshes:assert(mesh.visible_instance_count<=mesh.instance_count)
	var first:Dictionary=bg.particles[0]
	var first_unit:Dictionary=first.units[0]
	var source_q=Background.progress((bg.elapsed-float(first.birth))/float(first.life),first.accel,first.decel)
	var position:Vector3=first.start.lerp(Vector3(0,280,0),source_q)
	var expected=Background.source_vertices(position,first.direction,first_unit.size,Background.DATA.PROFILES[0].zmax)
	var first_batch:MultiMesh=bg.meshes[int(first_unit.texture)]
	var custom=first_batch.get_instance_custom_data(0)
	var transform=first_batch.get_instance_transform(0)
	var near=transform*Vector3(0,-custom.b,0)
	# The headless dummy renderer does not retain per-instance GPU data.
	if DisplayServer.get_name()!="headless":
		assert(near.distance_to(Vector3(expected[0].x*Background.UNIT,-.1,-(expected[0].y+234)*Background.UNIT))<.001,"GPU batch preserves source near edge")
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

