extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.ssrg_playable_run = false
	game.highway_style = "gold"
	game.mode = "play"
	var world = game.field.world
	world.clear_notes()
	var slide = SynkChart.note(2,2,"slide")
	slide.duration = 1.0;slide.end_lane = 8
	slide.path = [{"offset":0.0,"lane":2.0},{"offset":.25,"lane":4.5},{"offset":.5,"lane":7.0},{"offset":1.0,"lane":8.0}]
	slide.checkpoints = [.375]
	world.build_note_node("synk_slide",slide)
	var node: Node3D = world.notes.synk_slide.node
	var head: MeshInstance3D = node.get_child(0)
	var tail: MeshInstance3D = node.get_node("SustainEndCap")
	check(not game.uses_ssrg_gameplay() and world.source_long_visuals(),"Regular SYNK play uses source long note visuals")
	check(head.material_override.get_shader_parameter("artwork").resource_path.contains("note_animation/nb"),"SYNK slide starts with the SSRG hold head")
	check(tail.material_override.get_shader_parameter("artwork").resource_path.contains("note_animation/nc"),"SYNK slide ends with the SSRG continuation cap")
	var connectors = node.get_children().filter(func(child): return child.has_meta("checkpoint_offset") and child.name.begins_with("SlideTurnCap"))
	check(connectors.size()==1 and is_equal_approx(float(connectors[0].get_meta("checkpoint_offset")),.375),"Only the playable continuation has a visible cap")
	var ribbons = node.get_children().filter(func(child): return child is MeshInstance3D and child.mesh is ArrayMesh)
	check(ribbons.size()==1 and ribbons[0].mesh.surface_get_array_len(0)==24,"Slide uses one continuous face across sharp segments")
	check(node.get_children().filter(func(child):return child.name.begins_with("LongNoteTrailCover")).is_empty(),"Slide notes do not add a dark cover above their faces")
	check(ribbons[0].mesh.surface_get_material(0).get_shader_parameter("source_art"),"SYNK slide uses the gold trail")
	check(ribbons[0].mesh.surface_get_material(0).get_shader_parameter("joined_source"),"SYNK slide shares warped edges at bends")
	var neighbors=ribbons[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM2]
	check(neighbors is PackedFloat32Array and neighbors.size()==24*4,"Each ribbon vertex carries projected join neighbors")
	if neighbors.size()>=7*4:
		for component in 4: check(is_equal_approx(neighbors[4+component],neighbors[6*4+component]),"Both segments use the same bend neighbors")
	check(not ribbons[0].mesh.surface_get_material(0).get_shader_parameter("enhanced_synk"),"SYNK slide keeps its sharp connector geometry")
	check(node.get_children().filter(func(child):return child.name.begins_with("LongNoteGlow")).is_empty(),"Source connector has no added glow layer")
	var hold = SynkChart.note(3,4,"hold");hold.duration=1.0
	world.build_note_node("synk_hold",hold)
	check(world.notes.synk_hold.node.get_child(0).material_override.get_shader_parameter("artwork").resource_path.contains("note_animation/nb"),"SYNK hold uses the same source head")
	var tap = SynkChart.note(4,5)
	world.build_note_node("synk_tap",tap)
	check(not world.notes.synk_tap.node.get_child(0).material_override.get_shader_parameter("artwork").resource_path.contains("note_animation/"),"SYNK tap keeps its own art")
	game.queue_free()
	await process_frame
	print("SYNK long note visuals failures: ",failures)
	quit(failures)
