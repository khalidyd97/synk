extends SceneTree
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func freeze(n:Node):
	n.set_process(false);n.set_physics_process(false)
	for c in n.get_children():freeze(c)
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(2025,900)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.stage_intro_enabled=false;game.ssrg_playable_run=false;game.note_speed=1;game.note_size=1
	game.start_game([SynkChart.note(3,4.5)],true);game.countdown=0;freeze(game)
	var w=game.field.world;w.apply_camera();w.update_ssrg_warp();game.field.sync_projection_style()
	check(not w.uses_projected_highway() and not game.uses_ssrg_gameplay(),"Regular SYNK is separate from SSRG projection and judging")
	check(w.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"OG SYNK perspective camera restored")
	check(is_equal_approx(game.note_travel_seconds(),2.6),"OG SYNK approach timing restored")
	check(is_equal_approx(w.ssrg_warped_z(-15),-15),"Normal notes retain their original world depth")
	check(not game.field.screen.material.get_shader_parameter("ssrg_canvas"),"OG SYNK bloom and entrance shading restored")
	for style in ["gold","neon"]:
		game.highway_style=style;w.refresh_highway_look()
		check((w.gold_nodes if style=="gold" else w.neon_nodes).all(func(n):return n.visible),"OG rail design retained: "+style)
	for style in ["classic","bloom"]:
		w.clear_hit_effects();game.hit_style=style;w.spawn_hit(4.5,"tap");w.animate_effects(.1)
		check(w.synk_hits.hits.is_empty(),"Experimental SYNK hit renderer is not used")
		if style=="classic":check(w.bursts.size()==1 and w.bursts[0].node.scale.is_equal_approx(Vector3.ONE),"Original Classic effect and sizing restored")
		else:check(w.blooms.size()==1 and w.blooms[0].node.scale.is_equal_approx(Vector3.ONE),"Original Bloom effect and sizing restored")
	game.ssrg_playable_run=true;game.ssrg_lane_count=13;w.apply_camera();w.update_ssrg_warp();w.refresh_highway_look();game.field.sync_projection_style()
	check(w.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and w.ssrg_theme.active,"Imported SSRG retains its own highway")
	check(is_equal_approx(game.note_travel_seconds(),3.5/game.ssrg_note_speed()),"Imported SSRG retains its own approach speed")
	game.queue_free();await process_frame
	print("OG SYNK restoration failures: ",failures);quit(failures)
