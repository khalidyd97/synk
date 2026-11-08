extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	game.recorder_note_speed=1.0
	game.document.load_notes([])
	game.record_here(); game.countdown=0; game.song_time=5.2
	var hold=SynkChart.note(3,4,"hold"); hold.duration=2
	game.capture.notes=[hold]; game.reset_take_history()
	game.toggle_arrange()
	game.arrange_selection={"note":hold,"document":false,"index":0}
	game.refresh_arrange_controls()
	game.note_arranger._process(0)
	check(game.note_arranger.handles().size()==2,"Hold has start/end handles")
	var edited=game.note_arranger.edit(hold,"end",.5,0,-1,game.length())
	game.note_arranger.replace_note(hold,edited); game.commit_take_history()
	check(is_equal_approx(hold.duration,2.5),"Hold end extends independently")
	game.undo_record_note(); check(is_equal_approx(game.capture.notes[0].duration,2),"Undo restores duration")
	game.redo_record_note(); check(is_equal_approx(game.capture.notes[0].duration,2.5),"Redo restores edited duration")
	var near=SynkChart.note(6,2); game.capture.notes.append(near)
	check(is_equal_approx(game.snap_recorder_move(6.03,10,game.capture.notes[0]),6),"Moved note aligns to nearby note time")
	game.arrange_preview.request(4); game.arrange_preview._process(.05)
	check(game.arrange_preview.seeks==0 and not game.arrange_preview.player.playing,"Correct mode stays silent while notes are moved")
	game.arrange_preview.stop()
	var corrected_at=game.song_time
	game.toggle_arrange()
	check(is_equal_approx(game.ready_point,corrected_at),"Leaving correction resumes where it was, not at the final chart note")
	check(is_equal_approx(game.song_time,maxf(0.0,corrected_at-2)),"Resume gives two seconds before that position")
	game.audio.stop(); game.song_time=5.5; game.toggle_arrange()
	game.arrange_selection={"note":game.capture.notes[0],"document":false,"index":0}
	game.refresh_arrange_controls(); game.flash=0
	var slide=SynkChart.note(2,1,"slide"); slide.duration=2; slide.end_lane=7
	slide.path=[{"offset":0.0,"lane":1.0},{"offset":1.0,"lane":8.0},{"offset":2.0,"lane":7.0}]
	game.capture.notes.append(slide)
	game.commit_take_history()
	game.arrange_selection={"note":slide,"document":false,"index":game.capture.notes.size()-1}
	game.note_arranger.reshape("straighten")
	check(slide.path.size()==2,"Straighten keeps endpoints only")
	game.undo_record_note()
	check(game.capture.notes[-1].path.size()==3,"Undo restores slide shape")
	game.arrange_selection={"note":game.capture.notes[0],"document":false,"index":0}
	game.refresh_arrange_controls(); game.flash=0
	game.aids_drawer.hide(); game.field.show(); game.field.screen.show()
	game.field.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	for child in game.get_children():
		if child is CanvasLayer: child.hide()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/recorder-restored-preview.png")
	print("Recorder restoration failures: ",failures)
	game.queue_free(); await process_frame; quit(failures)
