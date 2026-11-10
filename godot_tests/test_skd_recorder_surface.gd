extends SceneTree
var failures=0
func check(ok:bool,message:String)->void:
	if not ok:failures+=1;push_error(message)
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,720)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.stage_intro_enabled=false;game.document.load_notes([]);game.record_here();game.countdown=0;game.song_time=5.0
	var world=game.field.world;world.apply_camera();world.refresh_highway_look();world._process(0.0)
	check(game.uses_skd_recorder_surface() and game.uses_skd_stage(),"Recorder selects the SKD visual surface")
	check(not game.uses_ssrg_gameplay(),"Recorder does not enable SKD gameplay rules")
	check(world.uses_projected_highway() and world.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Recorder uses the recovered SKD projection")
	check(is_equal_approx(game.note_travel_seconds(),3.5/game.recorder_note_speed),"Recorder uses SKD's recovered 3.5-second base travel")
	check(world.ssrg_theme.active and world.ssrg_theme.original_stage.visible,"Recovered SKD rails and judgment stage are active")
	check(not game.recorder_angle_slider.visible,"Fixed SKD camera removes the obsolete angle control")
	check(not world.recorder_guides.visible and not world.recorder_channels.visible,"Live recording hides SYNK grid and pad overlays")
	var tap=SynkChart.note(4.8,6,"tap");game.capture.notes=[tap];world._process(0.0)
	check(world.notes.has("captured0"),"Recorded notes remain visible on the SKD surface")
	if world.notes.has("captured0"):
		var head=world.notes.captured0.node.get_child(0)
		var mat=head.material_override as ShaderMaterial
		var art=mat.get_shader_parameter("artwork") if mat else null
		check(art!=null and str(art.resource_path).contains("ssrg"),"Recorder note faces use recovered SKD artwork")
	game.arranging=true;world._process(0.0)
	check(world.recorder_guides.visible,"Correction mode restores authoring guides")
	print("SKD recorder surface failures: ",failures)
	game.queue_free();await process_frame;quit(failures)
