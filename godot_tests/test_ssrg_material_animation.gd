extends SceneTree
func _initialize(): run.call_deferred()
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	freeze(game);game.ssrg_playable_run=true;game.set_mode("play");game.countdown=0
	var world=game.field.world
	world.clear_notes();world.build_note_node("one",SynkChart.note(2,4))
	assert(not world.ssrg_note_materials.is_empty())
	var original=world.ssrg_note_materials[0].get_ref()
	var mesh=MeshInstance3D.new();mesh.material_override=original;root.add_child(mesh)
	var private_material=world.own_material(mesh)
	assert(private_material!=original)
	private_material.set_shader_parameter("core_tint",Color(.2,.2,.2,.25))
	game.song_time=2.2;game.visual_song_time=2.2;game.visual_clock_ready=true
	world.ssrg_animation_frame=-1;world.animate_ssrg_notes()
	assert(private_material.get_shader_parameter("artwork")==original.get_shader_parameter("artwork"))
	assert(private_material.get_shader_parameter("core_tint")==Color(.2,.2,.2,.25))
	mesh.queue_free();await process_frame
	world.ssrg_animation_frame=-1;world.animate_ssrg_notes()
	world.clear_notes();assert(world.ssrg_note_materials.is_empty())
	print("SSRG shared/private artwork animation and state isolation passed")
	game.queue_free();await process_frame;quit()
