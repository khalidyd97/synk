extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	# SKD runs use only SKD's note-size option: NoteScaleConst {1.0,.9,.8} times
	# NoteScaleMaximum 212x116 (heads) and LongNoteScaleMaximum 132x72 (pucks).
	# SYNK's own note-size setting (here 1.25) must not change them.
	game.note_size=1.25
	game.ssrg_playable_run=true
	game.set_mode("play")
	var world=game.field.world
	var saved_index=game.prefs.get_value("ssrg","note_scale_index") if game.prefs.has_section_key("ssrg","note_scale_index") else null
	if game.prefs.has_section_key("ssrg","note_scale_index"): game.prefs.erase_section_key("ssrg","note_scale_index")
	assert(is_equal_approx(game.ssrg_note_scale(),1.0),"SKD's default note size is NoteScaleConst[0] = 1.0")
	for index in 3:
		game.prefs.set_value("ssrg","note_scale_index",index)
		var scale=[1.0,.9,.8][index]
		var holder=Node3D.new()
		world.add_child(holder)
		var head=world.make_ssrg_cap(holder,Vector3.ZERO,0)
		var tail=world.make_ssrg_cap(holder,Vector3.ZERO,1,.6*scale)
		assert(head.mesh.size.is_equal_approx(Vector2(212,116)*scale*world.SSRG_UNIT),"Head is 212x116 x SKD note size")
		assert(tail.mesh.size.is_equal_approx(Vector2(132,72)*scale*world.SSRG_UNIT),"Pucks are 132x72 x SKD note size")
		var note=SynkChart.note(4,4,"hold")
		note.duration=1.0
		world.make_ribbon(holder,note,1)
		var matched=false
		for child in holder.get_children():
			if child is MeshInstance3D and child.get_active_material(0) is ShaderMaterial:
				var material=child.get_active_material(0)
				if material.shader.resource_path.ends_with("solid_trail.gdshader"):
					matched=true
					assert(is_equal_approx(material.get_shader_parameter("ssrg_half_width"),116.0*.4*.5*scale*world.SSRG_UNIT),"Connectors scale with the pucks")
					assert(not material.get_shader_parameter("joined_source"),"SKD renders each linked hold section independently")
		assert(matched,"Hold connector material inspected")
		holder.queue_free()
	game.prefs.set_value("ssrg","note_scale_index",0)
	var holder=Node3D.new()
	world.add_child(holder)
	# Size correction must not change the motion curve, timing plane, or input geometry.
	var prefs_speed=game.prefs.get_value("ssrg","speed_value",null)
	game.prefs.set_value("ssrg","speed_value",3.6)
	assert(is_equal_approx(game.note_travel_seconds(),35.0/12.0),"3.6 retains the packaged default duration")
	assert(is_zero_approx(world.ssrg_warped_z(0)),"Notes still arrive on the timing line")
	assert(is_equal_approx(world.ssrg_approach(-world.TRACK_LENGTH*.25),pow(.75,6)),"Acceleration is unchanged")
	if prefs_speed==null: game.prefs.erase_section_key("ssrg","speed_value")
	else: game.prefs.set_value("ssrg","speed_value",prefs_speed)
	assert(is_equal_approx(game.note_size,1.25),"SYNK's own preference is left alone")
	game.ssrg_playable_run=false
	var normal=world.make_ssrg_cap(holder,Vector3.ZERO,0,1.25)  # make_cap passes size x note size
	assert(normal.mesh.size.is_equal_approx(Vector2(212,116)*1.25*world.SSRG_UNIT),"Other styles keep SYNK's note size and do not reuse the SKD cached mesh")
	if saved_index==null: game.prefs.erase_section_key("ssrg","note_scale_index")
	else: game.prefs.set_value("ssrg","note_scale_index",saved_index)
	game.queue_free()
	await process_frame
	print("SSRG reference note footprint: PASS")
	quit()
