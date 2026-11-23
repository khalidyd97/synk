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
	check(visual.get_child_count()==1 and visual.get_child(0).name=="AnimatedFlick","SSRG flicks use the six-frame animated sprite")
	var recorded=Node3D.new();game.field.world.add_child(recorded)
	game.field.world.make_flick(recorded,note,2,true)
	var chevrons=recorded.get_children().filter(func(child):return child.has_meta("flick_chevron_index"))
	check(chevrons.size()==1,"Recorder flicks keep one clean chevron flat on the highway")
	check(float(chevrons[0].position.z)<0.0 and is_equal_approx(float(chevrons[0].rotation.x),0.0),"The chevron lies on the highway over the puck")
	var special=Node3D.new();game.field.world.add_child(special)
	var item=SynkChart.note(0,6,"flick");item.ssrg_special=1
	game.field.world.make_flick(special,item,2)
	check(special.get_node_or_null("AnimatedFlick")==null,"SSRG special item flicks keep their static item puck")
	game.queue_free();await process_frame
	print("Flick visual: ","PASS" if failures==0 else str(failures)+" FAILED")
	quit(failures)
