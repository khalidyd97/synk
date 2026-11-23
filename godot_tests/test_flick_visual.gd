extends SceneTree

var failures=0
func check(ok:bool,label:String) -> void:
	if not ok:failures+=1;push_error(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process(false);game.ssrg_playable_run=true;game.highway_style="ssrg";game.ssrg_lane_count=13
	game.field.world.refresh_highway_look()
	var visual=Node3D.new();game.field.world.add_child(visual)
	var note=SynkChart.note(0,6,"flick");note.direction=0
	game.field.world.make_flick(visual,note,2)
	var chevrons=visual.get_children().filter(func(child):return child.has_meta("flick_chevron_index"))
	check(chevrons.size()==1,"A flick has one clean flat directional arrow")
	check(is_equal_approx(float(visual.get_child(0).material_override.get_shader_parameter("hue_shift")),.37),"The flick puck uses its vivid rose treatment")
	check(float(chevrons[0].position.z)<0.0,"The arrow begins over the puck and points up the highway")
	game.queue_free();await process_frame
	print("Flick visual: ","PASS" if failures==0 else str(failures)+" FAILED")
	quit(failures)
