extends Node3D
# Reconstruction of Perspective2dParticle. The original fever-state selection is
# not modelled by SYNK: use the source's first profile until that mapping is known.
const DATA = preload("res://scripts/ssrg_background_particle_data.gd")
const UNIT = 9.75 / 512.0
var profile_index: int = 0
var particles: Array = []
var rng = RandomNumberGenerator.new()
var elapsed: float = 0.0
var frame_credit: float = 0.0
var momentum: float = 0.0
var meshes: Array = []
var materials: Array = []
var instance_buffers:Array=[]
var intensity: float = 1.0
var tint: Color = Color.WHITE

func _init() -> void:
	name = "SSRGOriginalBackground"
	rng.randomize()

func configure(index: int = 0) -> void:
	profile_index = clampi(index, 0, DATA.PROFILES.size() - 1)
	particles.clear()
	frame_credit = 0.0
	momentum = 0.0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	meshes.clear()
	materials.clear()
	instance_buffers.clear()
	for texture_name in DATA.PROFILES[profile_index].textures:
		var node = MultiMeshInstance3D.new()
		var batch=MultiMesh.new()
		batch.transform_format=MultiMesh.TRANSFORM_3D
		batch.use_colors=true;batch.use_custom_data=true
		batch.mesh=QuadMesh.new()
		batch.instance_count=int(DATA.PROFILES[profile_index].countmax)*DATA.PROFILES[profile_index].polygons.size()
		batch.visible_instance_count=0;node.multimesh=batch
		var buffer=PackedFloat32Array();buffer.resize(batch.instance_count*20)
		instance_buffers.append(buffer)
		var material = ShaderMaterial.new()
		material.shader = preload("res://scripts/ssrg_background.gdshader")
		material.set_shader_parameter("artwork", load("res://assets/ssrg/imported/background/" + str(texture_name) + ".png"))
		material.render_priority = -19
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb=AABB(Vector3(-100,-1,-100),Vector3(200,2,200))
		add_child(node)
		meshes.append(batch)
		materials.append(material)

static func progress(raw_age: float, accel: float, decel: float) -> float:
	if raw_age <= 0.0:
		return 0.0
	var q = pow(raw_age, accel)
	return pow(q, decel / q) if decel != 1.0 else q

static func source_vertices(pos: Vector3, direction: Vector3, size: Vector2, z_max: float) -> PackedVector2Array:
	# RenderParticle 0x251e8b8..0x251e93c: the farther end widens
	# according to its z, rather than drawing a rotated rectangular streak.
	var scale_z = pos.z / z_max
	var half_near = size.y * scale_z * 0.5
	var length_now = size.x * scale_z
	var far_pos = pos - direction * length_now
	var half_far = size.y * (scale_z + far_pos.z / z_max) * 0.5
	return PackedVector2Array([
		Vector2(pos.x, pos.y - half_near), Vector2(pos.x, pos.y + half_near),
		Vector2(far_pos.x, far_pos.y + half_far), Vector2(far_pos.x, far_pos.y - half_far)])

static func particle_color(poly: Dictionary, chosen: Color, q: float) -> Color:
	var color = chosen
	if q < float(poly.colorintime):
		color = _color(poly.colorin).lerp(color, clampf(q / float(poly.colorintime), 0, 1))
	if q > float(poly.colorouttime):
		color = color.lerp(_color(poly.colorout), clampf((q - float(poly.colorouttime)) / (1.0 - float(poly.colorouttime)), 0, 1))
	return color

static func _color(values: Array) -> Color:
	return Color(values[0], values[1], values[2], values[3])

func _spawn(at_time: float) -> void:
	var p: Dictionary = DATA.PROFILES[profile_index]
	var shared = rng.randf()
	var arc: Array = p.arcs[p.degreeindexes[rng.randi_range(0, p.degreeindexes.size() - 1)]]
	var angle = deg_to_rad(lerpf(arc[0], arc[1], rng.randf()))
	var radius = lerpf(p.distmax, p.distmin, shared)
	var start = Vector3(cos(angle) * radius, 280.0 + sin(angle) * radius, lerpf(p.zmin, p.zmax, shared))
	var direction = (Vector3(0, 280, 0) - start).normalized()
	var units: Array = []
	var size_random = rng.randf()
	for poly in p.polygons:
		units.append({"texture": poly.sprites[rng.randi_range(0, poly.sprites.size() - 1)],
			"size": Vector2(poly.sizemin[0], poly.sizemin[1]).lerp(Vector2(poly.sizemax[0], poly.sizemax[1]), size_random),
			"color": _color(poly.colormin).lerp(_color(poly.colormax), shared)})
	particles.append({"start": start, "direction": direction, "birth": at_time,
		"life": rng.randf_range(p.timemin, p.timemax) * (1.5 - 0.5 * shared),
		"accel": rng.randf_range(p.accelmin, p.accelmax),
		"decel": lerpf(p.decelmin, maxf(p.decelmin, p.decelmax), shared), "units": units})

func _generate(at_time: float) -> void:
	var p: Dictionary = DATA.PROFILES[profile_index]
	while particles.size() < int(p.countmin):
		_spawn(at_time)
	var desired = lerpf(p.countmin, p.countmax, clampf(p.density, 0, 1))
	var range_per_frame = desired / float(p.fps) * float(p.genscale)
	var credit = momentum + rng.randf_range(0, p.genscale) * range_per_frame
	var count = mini(int(credit), int(p.countmax) - particles.size())
	momentum = fposmod(credit, 1.0)
	for _i in count:
		_spawn(at_time)

func advance(delta: float, paused: bool = false) -> void:
	if meshes.is_empty():
		configure()
	if paused:
		return
	elapsed += maxf(delta, 0.0)
	var p: Dictionary = DATA.PROFILES[profile_index]
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		if (elapsed - float(particle.birth)) / float(particle.life) >= float(p.cutout):
			particles.remove_at(i)
	# Native emission is per frame at the configured 60Hz. A fixed emission clock
	# preserves density on SYNK devices running at different refresh rates.
	frame_credit += minf(delta, 0.25) * float(p.fps)
	while frame_credit >= 1.0:
		frame_credit -= 1.0
		_generate(elapsed)
	_render()

func _render() -> void:
	var p: Dictionary = DATA.PROFILES[profile_index]
	var counts: Array = []
	for _i in meshes.size():
		counts.append(0)
	for particle in particles:
		var q = progress((elapsed - float(particle.birth)) / float(particle.life), particle.accel, particle.decel)
		var pos: Vector3 = particle.start.lerp(Vector3(0, 280, 0), q)
		for i in particle.units.size():
			var unit: Dictionary = particle.units[i]
			var color = particle_color(p.polygons[i], unit.color, q) * tint
			color.a *= intensity * float(p.forcealpha)
			var texture_index=int(unit.texture)
			var index=int(counts[texture_index]);counts[texture_index]+=1
			var scale_z=pos.z/float(p.zmax)
			var far:Vector3=pos-particle.direction*unit.size.x*scale_z
			var offset=index*20
			# One packed upload per texture, rather than three rendering-server
			# calls per particle. Layout: 3x4 transform, color, custom data.
			var buffer:PackedFloat32Array=instance_buffers[texture_index]
			instance_buffers[texture_index]=null # Keep the writable array unshared during this update.
			buffer[offset]=UNIT;buffer[offset+1]=0;buffer[offset+2]=0;buffer[offset+3]=pos.x*UNIT
			buffer[offset+4]=0;buffer[offset+5]=0;buffer[offset+6]=UNIT;buffer[offset+7]=-.1
			buffer[offset+8]=0;buffer[offset+9]=-UNIT;buffer[offset+10]=0;buffer[offset+11]=-(pos.y+234)*UNIT
			buffer[offset+12]=color.r;buffer[offset+13]=color.g;buffer[offset+14]=color.b;buffer[offset+15]=color.a
			buffer[offset+16]=far.x-pos.x;buffer[offset+17]=far.y-pos.y
			buffer[offset+18]=unit.size.y*scale_z*.5;buffer[offset+19]=unit.size.y*(scale_z+far.z/float(p.zmax))*.5
			instance_buffers[texture_index]=buffer
	for i in meshes.size():
		meshes[i].buffer=instance_buffers[i]
		meshes[i].visible_instance_count=counts[i]
