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
	check(game.uses_ssrg_gameplay() and world.ssrg_theme.active,"Normal gameplay activates SSRG stage")
	check(game.gameplay_lane_count()==10,"Normal charts retain 10 unique lanes")
	check(game.live[1].note.get("ssrg_path",false),"Runtime slides use straight connectors")
	check(not slide.has("ssrg_path"),"Original chart data stays intact")
	check(is_equal_approx(game.note_travel_seconds(),3.5),"Shared travel uses note speed")
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
	check(head.material_override.get_shader_parameter("artwork").resource_path.ends_with("imported/hold.png"),"Hold uses extracted yellow artwork")
	for i in 35: world.ssrg_theme.spawn(4,"tap",{},-999)
	check(world.ssrg_theme.hits.size()==35,"Dense hits do not evict preceding effects")
	check(world.ssrg_theme.sustain_frames.size()==11,"Both effect frame sets are available")
	game.paused_mode="play"; game.set_mode("paused")
	check(game.uses_ssrg_gameplay(),"Pause keeps the shared stage")
	game.set_mode("record")
	check(not game.uses_ssrg_gameplay() and not world.ssrg_theme.active,"Recorder remains separate")
	check(is_equal_approx(game.note_travel_seconds(),2.6),"Recorder travel remains unchanged")
	game.set_mode("menu")
	check(not game.uses_ssrg_gameplay(),"Menu does not inherit gameplay presentation")
	game.queue_free(); await process_frame
	print("Shared SSRG gameplay failures: ",failures)
	quit(failures)
