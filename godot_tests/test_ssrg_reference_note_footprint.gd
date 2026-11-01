extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.note_size=1.0
	game.ssrg_playable_run=true
	game.set_mode("play")
	var world=game.field.world
	var holder=Node3D.new()
	world.add_child(holder)
	var head=world.make_ssrg_cap(holder,Vector3.ZERO,0)
	var tail=world.make_ssrg_cap(holder,Vector3.ZERO,1,.6)
	assert(head.mesh.size.is_equal_approx(Vector2(169.6,92.8)*world.SSRG_UNIT),"Reference tap footprint at the hit line")
	assert(tail.mesh.size.is_equal_approx(Vector2(105.6,57.6)*world.SSRG_UNIT),"Continuation pucks share the artwork correction")
	var note=SynkChart.note(4,4,"hold")
	note.duration=1.0
	world.make_ribbon(holder,note,1)
	var matched=false
	for child in holder.get_children():
		if child is MeshInstance3D and child.get_active_material(0) is ShaderMaterial:
			var material=child.get_active_material(0)
			if material.shader.resource_path.ends_with("solid_trail.gdshader"):
				matched=true
				assert(is_equal_approx(material.get_shader_parameter("ssrg_half_width"),18.56*world.SSRG_UNIT),"Connectors scale with the pucks")
	assert(matched,"Hold connector material inspected")
	# Size correction must not change the motion curve, timing plane, or input geometry.
	var prefs_speed=game.prefs.get_value("ssrg","speed_value",null)
	game.prefs.set_value("ssrg","speed_value",3.6)
	assert(is_equal_approx(game.note_travel_seconds(),35.0/12.0),"3.6 retains the packaged default duration")
	assert(is_zero_approx(world.ssrg_warped_z(0)),"Notes still arrive on the timing line")
	assert(is_equal_approx(world.ssrg_approach(-world.TRACK_LENGTH*.25),pow(.75,6)),"Acceleration is unchanged")
	if prefs_speed==null: game.prefs.erase_section_key("ssrg","speed_value")
	else: game.prefs.set_value("ssrg","speed_value",prefs_speed)
	assert(is_equal_approx(game.note_size,1.0),"User preference is preserved")
	game.ssrg_playable_run=false
	var normal=world.make_ssrg_cap(holder,Vector3.ZERO,0)
	assert(normal.mesh.size.is_equal_approx(Vector2(212,116)*world.SSRG_UNIT),"Other styles retain their note size and do not reuse the smaller cached mesh")
	game.queue_free()
	await process_frame
	print("SSRG reference note footprint: PASS")
	quit()
