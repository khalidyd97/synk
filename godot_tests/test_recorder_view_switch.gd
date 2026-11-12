extends SceneTree
# The recorder opens on the classic SYNK highway; SKD VIEW in the aids switches the same
# take onto the SKD gameplay highway and back.
var failures=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	game.recorder_skd_view=false
	game.set_process(false); game.recorder.set_process(false); game.stage_intro_enabled=false
	game.set_mode("editor"); game.document.load_notes([]); game.record_here(); game.countdown=0
	var world=game.field.world
	game.update_recorder_focus(); world._process(0.0)
	check(not game.uses_skd_recorder_surface() and not game.uses_skd_stage() and not world.uses_projected_highway(),"The recorder opens on the classic highway")
	check(world.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Classic recorder uses the tilted perspective camera")
	check(is_equal_approx(game.note_travel_seconds()*game.recorder_note_speed,2.6),"Classic recorder keeps its 2.6-second base travel")
	check(world.recorder_guides.visible,"Classic recorder shows its lane guides while recording")
	game.toggle_arrange(); game.update_recorder_focus()
	check(not game.uses_even_correct_view() and game.recorder_angle_slider.visible,"Classic Correct mode keeps the angle slider and its own view")
	var notes=[SynkChart.note(1.0,4)]; game.capture.notes=notes
	game.toggle_recorder_skd_view(); world._process(0.0)
	check(game.uses_skd_recorder_surface() and world.uses_projected_highway() and world.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"SKD VIEW moves the take onto the SKD highway")
	check(is_equal_approx(game.note_travel_seconds()*game.recorder_note_speed,3.5) and not game.recorder_angle_slider.visible,"SKD view uses SKD's travel time and fixed camera")
	check(game.capture.notes==notes and game.arranging,"Switching views keeps the take and stays in Correct mode")
	check(game.recorder_skd_button.text=="SKD view: on","The aids button shows the view in use")
	game.toggle_recorder_skd_view(); world._process(0.0)
	check(not world.uses_projected_highway() and game.recorder_skd_button.text=="SKD view: off","Switching back restores the classic highway")
	game.prefs.set_value("editor","recorder_skd_view",false); game.prefs.save("user://preferences.cfg")
	print("Recorder view switch: ","PASS" if failures==0 else str(failures)+" FAILED")
	game.queue_free(); await process_frame; quit(failures)
