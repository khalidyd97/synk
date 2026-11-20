extends SceneTree
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func entry(note:Dictionary,key:String)->Dictionary:
	return {"note":note,"key":key,"started":false,"done":false,"pointer":-999,"error":0.0}
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1440,640)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	freeze(game);game.ssrg_playable_run=true;game.ssrg_lane_count=13;game.set_mode("play");game.countdown=0;game.auto_play=false
	game.audio.stop()
	game.field.sync_projection_style()
	var world=game.field.world;world.apply_camera();world.update_ssrg_warp()
	var bar=world.ssrg_theme.original_stage.press
	check(bar.material_override.get_shader_parameter("artwork").resource_path.ends_with("judgment_Main_black_BG3.png"),"Judgment bar uses source slanted artwork")
	check(bar.material_override.get_shader_parameter("base_color").is_equal_approx(Color8(255,220,65,149)),"Judgment bar stays the exact fixed source gold")
	var bar_glow=world.ssrg_theme.original_stage.press_glow
	check(bar_glow.visible and is_equal_approx(bar_glow.mesh.size.x,bar.mesh.size.x) and is_equal_approx(bar_glow.mesh.size.y,32.0*world.SSRG_UNIT),"Judgment glow spans the bar and occupies the recorded 32-unit under-band falloff")
	check(bar_glow.material_override.shader.resource_path.ends_with("ssrg_judgment_glow.gdshader"),"Judgment glow uses a continuous soft falloff rather than the striped bar artwork")
	var glow_color:Color=bar_glow.material_override.get_shader_parameter("glow_color")
	var bar_color:Color=bar.material_override.get_shader_parameter("base_color")
	check(Vector3(glow_color.r,glow_color.g,glow_color.b).is_equal_approx(Vector3(bar_color.r,bar_color.g,bar_color.b)) and is_equal_approx(glow_color.a,150.0/255.0),"Under-bar halo follows the current judgment-bar RGB")
	check(bar.material_override.render_priority>world.ssrg_theme.original_stage.rails[0].material_override.render_priority,"Gold bar draws above the rail's dark road shading")
	game.song_time=5.0;game.visual_clock_ready=false
	var point=world.camera.unproject_position(Vector3(0,.035,0))/Vector2(game.field.viewport.size)
	var tap=SynkChart.note(5.12,6);tap.lane=6.0
	var hit=entry(tap,"tap");game.live=[hit];game.live_cursor=0
	game.pointer_event(1,point,true,false,false)
	game.update_game() # Flush the source-style per-frame touch batch.
	check(hit.done and game.judgement=="GREAT","Imported tap uses packaged 210ms ordinary-perfect threshold")
	game.pointers.clear();game.ssrg_touch_router.reset();world.clear_hit_effects()
	tap=SynkChart.note(5.25,6);tap.lane=6.0;hit=entry(tap,"early");game.live=[hit];game.live_cursor=0
	game.pointer_event(1,point,true,false,false)
	game.update_game() # Flush the source-style per-frame touch batch.
	check(hit.done and game.judgement=="GOOD","Imported tap accepts the full packaged 300ms good window")
	game.pointers.clear();game.ssrg_touch_router.reset();world.clear_hit_effects()
	hit=entry(tap,"wrong_lane");game.live=[hit];game.live_cursor=0
	var other=world.camera.unproject_position(Vector3(world.SSRG_STEP*2,.035,0))/Vector2(game.field.viewport.size)
	game.pointer_event(1,other,true,false,false)
	game.update_game() # Flush the source-style per-frame touch batch.
	check(not hit.started,"Touch outside the recovered head autoaim rectangle cannot hit a puck")
	game.pointers.clear();game.ssrg_touch_router.reset();world.clear_hit_effects()
	var slide=SynkChart.note(5,6,"slide");slide.lane=6.0;slide.end_lane=6.0;slide.duration=1
	slide.path=[{"offset":0.0,"lane":6.0},{"offset":1.0,"lane":6.0}];slide.ssrg_path=true
	hit=entry(slide,"slide");game.live=[hit];game.live_cursor=0;game.judged=0;game.judgement_total_size=-1
	game.pointer_event(1,point,true,false,false)
	game.update_game() # Flush the source-style per-frame touch batch.
	check(hit.started and not hit.done and game.judged==1,"Imported slide scores its start immediately")
	check(game.total_judgements()==2,"Imported slide includes both start and end in accuracy total")
	game.song_time=6.0;game.update_game()
	check(hit.done and game.judged==2,"Imported slide end is a separate judgment")
	game.pointers.clear();game.ssrg_touch_router.reset();world.clear_hit_effects()
	game.pointers={1:{"position":Vector2(.113,.85)},2:{"position":Vector2(.5,.85)}}
	world.update_finger_beams()
	var released=world.finger_beams[0];var retained:float=released.position.x
	game.pointers.erase(1);game.pointers[3]={"position":Vector2(.887,.85)}
	world.update_finger_beams(.05)
	check(released.visible and is_equal_approx(released.position.x,retained),"Released beam retains its channel when another finger arrives")
	check(is_equal_approx(float(released.material_override.get_shader_parameter("release_alpha")),.5),"Beam fades halfway after 50ms")
	game.mode="paused";world.update_finger_beams(.2)
	check(is_equal_approx(float(released.material_override.get_shader_parameter("release_alpha")),.5),"Pause freezes released beams")
	game.mode="play";world.update_finger_beams(.051)
	check(not released.visible,"Released beam disappears after 100ms")
	world.clear_hit_effects();game.pointers.clear()
	var hold=SynkChart.note(8,6,"hold");hold.duration=1;hold.lane=6.0;hold.ssrg_order=40;hold.ssrg_orders=[{"offset":1.0,"order":44}]
	world.build_note_node("miss",hold);world.notes.miss.head_hit=true
	world.fade_missed_slide("miss",0)
	var head=world.notes.miss.node.get_child(0)
	check(head.material_override.get_shader_parameter("source_tint")==Color.WHITE,"Successful hold start stays bright after a later miss")
	var cap=world.notes.miss.node.find_child("SustainEndCap",false,false)
	check(cap.material_override.get_shader_parameter("source_tint")==world.SsrgNotes.MISSED_TINT,"Missed end uses exact source dark tint immediately")
	check(is_equal_approx(cap.sorting_offset,-44),"Sustain end preserves source record order")
	var chain=hold.duplicate(true);chain.checkpoints=[.5];chain.ssrg_orders=[{"offset":0.0,"order":40},{"offset":.5,"order":42},{"offset":1.0,"order":44}]
	world.build_note_node("ordered",chain)
	var segments=world.notes.ordered.node.get_children().filter(func(n):return n is MeshInstance3D and n.mesh is ArrayMesh)
	check(segments.size()==2 and is_equal_approx(segments[0].sorting_offset,-40) and is_equal_approx(segments[1].sorting_offset,-42),"Crossing-chain connectors retain separate source segment order")
	check(segments[0].mesh.surface_get_array_len(0)==18,"Each source connector has exactly three overlapping quads")
	game.live=[entry(slide,"miss_all")];game.live_cursor=0;game.song_time=8.0;game.judged=0;game.judgment_counts={"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0}
	game.update_game()
	check(game.judged==2 and game.judgment_counts.MISS==2,"Missing an imported slide start accounts for both head and end")
	var effect=world.ssrg_theme.make_hit()
	check(effect.node.mesh.size.is_equal_approx(Vector2(620,372)*world.SSRG_UNIT),"SKD hit flash uses the full packaged def_c_trans 2x footprint")
	effect.node.queue_free()
	game.prefs.set_value("ssrg","speed",1.0)
	if game.prefs.has_section_key("ssrg","speed_value"):game.prefs.erase_section_key("ssrg","speed_value")
	check(is_equal_approx(game.ssrg_speed_setting(),3.0) and is_equal_approx(game.ssrg_note_speed(),1.0),"Previous speed migrates without changing travel time")
	game.ssrg_playables.change_speed(1)
	check(is_equal_approx(game.ssrg_speed_setting(),4.0) and is_equal_approx(game.ssrg_note_speed(),4.0/3.0),"Original speed setting maps to value divided by three")
	game.set_mode("record")
	check(not game.ssrg_playable_run and not game.uses_ssrg_gameplay(),"Recorder does not inherit SSRG input rules")
	game.queue_free();await process_frame
	print("SSRG full integration failures: ",failures);quit(failures)
