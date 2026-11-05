extends SceneTree
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	game.stage_intro_enabled=false; game.note_speed=1; game.note_size=1.0; game.recorder_note_speed=1
	var slide=SynkChart.note(4,2,"slide"); slide.duration=1; slide.end_lane=7
	slide.path=[{"offset":0.0,"lane":2.0},{"offset":.5,"lane":6.0},{"offset":1.0,"lane":7.0}]
	var notes=[SynkChart.note(3,4),slide]
	game.start_game(notes,true)
	game.countdown=0; game.song_time=2.0
	var world=game.field.world
	check(not game.ssrg_playable_run,"Normal song does not become an SSRG import")
	check(not game.uses_ssrg_gameplay() and not world.ssrg_theme.active,"Normal play uses SYNK OG stage")
	check(not game.live[1].note.get("ssrg_path",false),"Normal slides retain OG curves")
	check(not slide.has("ssrg_path"),"Source chart remains intact")
	check(is_equal_approx(game.note_travel_seconds(),3.5),"Normal play uses the SSRG approach mechanism")
	game.paused_mode="play"; game.set_mode("paused")
	check(not game.uses_ssrg_gameplay(),"Normal pause retains OG stage")
	game.set_mode("menu")
	game.prefs.set_value("ssrg","speed_value",3.0)
	game.ssrg_playable_run=true
	game.start_game(notes,true)
	game.countdown=0; game.song_time=2.0
	check(game.uses_ssrg_gameplay() and world.ssrg_theme.active,"SSRG playable uses SSRG stage")
	var previous_old_ui=game.prefs.get_value("highway","old_ssrg_ui",false)
	game.prefs.set_value("highway","old_ssrg_ui",true)
	world.refresh_highway_look()
	check(world.uses_projected_highway() and world.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Old SSRG art retains the source 2D highway projection")
	check(world.ssrg_theme.original_stage.old_rails.all(func(rail):return rail.visible) and world.ssrg_theme.original_stage.rails.all(func(rail):return not rail.visible),"Old SSRG mode uses the silver rails")
	check(world.ssrg_theme.original_stage.old_rails[0].material_override.shader.resource_path.ends_with("ssrg_old_rail.gdshader"),"Old SSRG mode uses the striped silver rail")
	check(world.ssrg_theme.original_stage.old_rail_glows.all(func(rail):return rail.visible),"Old SSRG mode uses the separate source light strips")
	check(world.ssrg_theme.original_stage.old_rail_dots.all(func(dot):return dot.visible and dot.material_override.get_shader_parameter("artwork").resource_path.contains("Main_side light_R")),"Old SSRG rail dots use the extracted side-light sprite")
	check(world.ssrg_theme.original_stage.old_rails[0].mesh.get_aabb().end.z>3.0 and world.ssrg_theme.original_stage.old_rail_glows[0].mesh.get_aabb().end.z>3.0,"Old SSRG rail and light extend below the screen")
	check(world.trail_color(3)==world.trail_color(1),"Old SSRG slides use the same yellow trail as holds")
	world.ssrg_theme.original_stage.update(world)
	check(world.ssrg_theme.original_stage.old_rail_glows[0].material_override.get_shader_parameter("accent") is Color,"Old SSRG rail light receives the live rave color")
	check(world.ssrg_theme.original_stage.old_rail_dots[0].position.x<0 and world.ssrg_theme.original_stage.old_rail_dots[1].position.x>0,"Both moving dots stay on their respective rail")
	var old_cap=world.make_ssrg_cap(world,Vector3.ZERO,1)
	check(old_cap.material_override.get_shader_parameter("artwork").resource_path.contains("old_ui/normal/nb"),"Old SSRG mode loads the STAYC hold sprite")
	var old_trail_holder=Node3D.new();world.add_child(old_trail_holder)
	world.make_ribbon(old_trail_holder,slide,3)
	var old_trail=old_trail_holder.get_children().filter(func(child):return child is MeshInstance3D and child.mesh is ArrayMesh)[0]
	check(float(old_trail.mesh.surface_get_material(0).get_shader_parameter("ssrg_half_width"))*2.0<old_cap.mesh.size.x*.5,"Old SSRG slide trail fits beneath connector artwork")
	old_trail_holder.queue_free()
	old_cap.queue_free()
	game.prefs.set_value("highway","old_ssrg_ui",previous_old_ui)
	world.refresh_highway_look()
	check(game.live[1].note.get("ssrg_path",false),"SSRG slides use straight connectors")
	check(is_equal_approx(game.note_travel_seconds(),3.5),"SSRG timing remains intact")
	check(world.ssrg_theme.original_stage.receptors[0].mesh!=null,"Receptors have visible geometry")
	world.ssrg_theme.original_stage.update(world)
	check(not world.ssrg_theme.original_stage.receptors.any(func(n):return n.visible),"Receptors wait for the original projected-progress threshold")
	game.song_time=2.85; world.ssrg_theme.original_stage.update(world)
	check(world.ssrg_theme.original_stage.receptors.any(func(n):return n.visible),"Approaching notes reveal a receptor")
	game.song_time=2.9; world.ssrg_theme.original_stage.update(world)
	check(world.ssrg_theme.original_stage.receptors.any(func(n):return n.visible and is_equal_approx(float(n.material_override.get_shader_parameter("progress")),1.0)),"Original guide becomes fully visible by projected progress .8")
	check(world.ssrg_theme.original_stage.receptors[0].material_override.get_shader_parameter("artwork").resource_path.ends_with("guide_original.png"),"Guide uses APK sprite padding and ellipse position")
	var holder=Node3D.new(); world.add_child(holder)
	var head=world.make_ssrg_cap(holder,Vector3.ZERO,1)
	check(head.material_override.get_shader_parameter("artwork").resource_path.contains("note_animation/nb"),"Hold uses original animated yellow artwork")
	for i in 35: world.ssrg_theme.spawn(4,"tap",{},-999)
	check(world.ssrg_theme.hits.size()==35,"Dense hits do not evict preceding effects")
	check(world.ssrg_theme.special_frames.size()==11,"Special-event artwork remains available")
	game.paused_mode="play"; game.set_mode("paused")
	check(game.uses_ssrg_gameplay(),"Pause keeps the shared stage")
	game.set_mode("record")
	check(not game.uses_ssrg_gameplay() and not world.ssrg_theme.active,"Recorder remains separate")
	check(is_equal_approx(game.note_travel_seconds(),2.6),"Recorder travel remains unchanged")
	game.set_mode("menu")
	check(not game.uses_ssrg_gameplay(),"Menu does not inherit gameplay presentation")
	# The "ssrg" highway style: SYNK songs draw on the SSRG stage with SYNK's own rules.
	game.ssrg_playable_run=false; game.highway_style="ssrg"
	check(not game.uses_ssrg_gameplay(),"SSRG style stays out of the menus")
	game.start_game(notes,true)
	game.countdown=0; game.song_time=2.0
	check(game.uses_ssrg_gameplay() and world.ssrg_theme.active,"SSRG style plays SYNK songs on the SSRG stage")
	check(not game.ssrg_playable_run and not game.live[1].note.get("ssrg_path",false),"SSRG style keeps SYNK rules and curved slides")
	check(is_equal_approx(game.note_travel_seconds(),3.5/game.note_speed),"SSRG style follows SYNK's note speed")
	game.set_mode("menu")
	check(game.highway_style=="ssrg" and not world.ssrg_theme.active,"Leaving play keeps the style and drops the stage")
	# SSRG mode: the switch makes SYNK songs use SSRG rules too, then SYNK's own results.
	var saved_mode=game.prefs.get_value("highway","ssrg_mode",false)
	game.prefs.set_value("highway","ssrg_mode",true)
	game.start_game(notes,true)
	game.countdown=0; game.song_time=2.0
	check(game.ssrg_playable_run and game.ssrg_forced_run,"SSRG mode plays the SYNK song with SSRG rules")
	check(is_equal_approx(game.note_travel_seconds(),3.5/game.ssrg_note_speed()),"SSRG mode uses the SSRG note speed")
	check(game.live[1].note.get("ssrg_path",false),"SSRG mode uses straight SSRG connectors")
	var results={}; game.begin_finish(results)
	check(not results.ssrg,"SSRG mode keeps SYNK's results screen")
	game.finishing=false; game.set_mode("menu")
	check(not game.ssrg_playable_run and not game.ssrg_forced_run and game.highway_style=="ssrg","Leaving SSRG mode restores the SSRG style")
	game.highway_style="gold"
	game.start_game(notes,true)
	check(not game.ssrg_playable_run,"SSRG mode needs the SSRG style")
	game.set_mode("menu")
	game.prefs.set_value("highway","ssrg_mode",saved_mode); game.prefs.save("user://preferences.cfg")
	game.queue_free(); await process_frame
	print("Shared SSRG gameplay failures: ",failures)
	quit(failures)
