extends SceneTree
# The recorder only uses the SKD highway, and Correct mode keeps exactly the recording view.
var failures=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	game.set_process(false); game.recorder.set_process(false); game.stage_intro_enabled=false
	game.set_mode("editor"); game.document.load_notes([]); game.record_here(); game.countdown=0
	var world=game.field.world
	game.update_recorder_focus(); world.apply_camera(); world._process(0.0)
	check(game.uses_skd_recorder_surface() and world.uses_projected_highway() and world.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"The recorder opens on the SKD highway")
	check(not game.recorder_angle_slider.visible,"There is no classic angle slider")
	var recording_camera=world.camera.global_transform
	var recording_power=world.approach_power()
	game.toggle_arrange(); game.update_recorder_focus(); world._process(0.0)
	check(game.arranging and game.uses_skd_recorder_surface() and not game.uses_even_correct_view() and not world.even_view(),"Correct mode stays on the SKD view")
	check(world.camera.global_transform.is_equal_approx(recording_camera) and is_equal_approx(world.approach_power(),recording_power),"Correct mode keeps the recording camera and spacing")
	check(not world.recorder_guides.visible,"Correct mode shows the same lanes as recording")
	check(game.recorder_skd_button==null,"The aids no longer offer a view switch")
	print("Recorder view switch: ","PASS" if failures==0 else str(failures)+" FAILED")
	game.queue_free(); await process_frame; quit(failures)
