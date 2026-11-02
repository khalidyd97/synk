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
	check(w.uses_projected_highway() and not game.uses_ssrg_gameplay(),"SYNK shares SSRG projection while preserving its own judging")
	check(w.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"SYNK uses the same canvas camera as SSRG")
	check(is_equal_approx(game.note_travel_seconds(),3.5),"SYNK uses the SSRG approach time")
	check(is_equal_approx(w.ssrg_warped_z(-15),w.SSRG_STAGE_DISTANCE*(pow(.75,6)-1.0)),"SYNK notes follow the SSRG depth curve")
	check(game.field.screen.material.get_shader_parameter("ssrg_canvas"),"Projected sprites avoid duplicate bloom")
	for style in ["gold","neon"]:
		game.highway_style=style;w.refresh_highway_look()
		check((w.gold_nodes if style=="gold" else w.neon_nodes).all(func(n):return n.visible),"OG rail design retained: "+style)
	for style in ["classic","bloom"]:
		w.clear_hit_effects();game.hit_style=style;w.spawn_hit(4.5,"tap");w.animate_effects(.1)
		check(w.synk_hits.hits.is_empty(),"Original hit styles never use the replacement burst")
		if style=="classic":
			check(w.bursts.size()==1 and w.blooms.is_empty(),"Classic retains original sprite, fill, ring and sparks")
			check(w.bursts[0].flash.material_override.get_shader_parameter("artwork")!=null,"Classic uses its original artwork")
		else:
			check(w.blooms.size()==1 and w.bursts.is_empty(),"Bloom retains its original halo and spark shaders")
			check(w.blooms[0].flat.shader.resource_path=="res://scripts/bloom_hit.gdshader","Bloom uses the original halo")
		w.clear_hit_effects()
		check(w.bursts.is_empty() and w.blooms.is_empty(),"Switching hit styles clears old effects")
	game.change_synk_speed(3.6)
	var regular_travel=game.note_travel_seconds()
	game.prefs.set_value("ssrg","speed_value",3.6)
	game.ssrg_playable_run=true;game.ssrg_lane_count=13;w.apply_camera();w.update_ssrg_warp();w.refresh_highway_look();game.field.sync_projection_style()
	check(w.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and w.ssrg_theme.active,"Imported SSRG retains its own highway")
	check(is_equal_approx(game.note_travel_seconds(),3.5/game.ssrg_note_speed()),"Imported SSRG retains its own approach speed")
	check(is_equal_approx(regular_travel,game.note_travel_seconds()),"Matching speed numbers now give matching approach times in SYNK and SSRG")
	game.queue_free();await process_frame
	print("SYNK shared projection and style preservation failures: ",failures);quit(failures)
