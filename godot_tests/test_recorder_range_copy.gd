extends SceneTree
# Correct mode: copy a part by marking its start and end at the line, then paste it elsewhere.
# Also checks the beat grid follows the SKD highway and the recorded notes.
var failures=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	game.set_process(false); game.recorder.set_process(false); game.stage_intro_enabled=false
	game.set_mode("editor"); game.document.load_notes([],{"bpm":120.0,"beat_offset":0.0}); game.record_here(); game.countdown=0
	game.recorder.division=4
	var hold=SynkChart.note(10.5,4,"hold"); hold.duration=.5
	game.capture.notes=[SynkChart.note(10.0,2),hold,SynkChart.note(11.0,8),SynkChart.note(12.5,6)]
	game.reset_take_history()
	game.song_time=10.0; game.toggle_arrange()
	var bar=game.correct_bar
	bar._process(0)
	check(bar.wanted().has("copy") and not bar.wanted().has("paste"),"Nothing selected offers Copy part, not Paste yet")
	bar.begin_copy(); bar._process(0)
	check(bar.wanted().has("start") and bar.wanted().has("cancel") and not bar.wanted().has("text"),"Copying shows only Start here and Cancel")
	check(game.record_help.text.begins_with("Scroll so the start"),"The help line says what to do")
	game.song_time=10.0; bar.mark_start()
	check(bar.wanted().has("end"),"After the start, it asks for the end")
	game.song_time=11.0; bar.mark_end()
	check(bar.clipboard.size()==3 and is_equal_approx(bar.clipboard_span,1.0),"Copies the three notes from 10.0 to 11.0 s")
	check(bar.copy_stage=="" and bar.wanted().has("paste"),"Paste here appears once something is copied")
	# Paste a little off the grid: it lands on the grid, keeping the part's rhythm.
	game.song_time=14.03; bar.paste_here()
	var times=game.capture.notes.map(func(n): return snappedf(float(n.time),.001))
	check(game.capture.notes.size()==7,"Paste adds the three notes")
	check(times.has(14.0) and times.has(14.5) and times.has(15.0),"The part lands on the grid at 14.0 s with its spacing kept")
	var pasted_hold=game.capture.notes.filter(func(n): return n.kind=="hold" and is_equal_approx(float(n.time),14.5))
	check(pasted_hold.size()==1 and is_equal_approx(float(pasted_hold[0].duration),.5),"A pasted hold keeps its length")
	game.undo_record_note()
	check(game.capture.notes.size()==4,"Undo removes the pasted part")
	# Marking the end before the start still copies the part between them.
	bar.begin_copy(); game.song_time=12.6; bar.mark_start(); game.song_time=11.9; bar.mark_end()
	check(bar.clipboard.size()==1 and is_equal_approx(bar.copy_start,11.9),"Start and end can be marked in either order")
	bar.begin_copy(); bar.cancel_copy()
	check(bar.copy_stage=="" and bar.clipboard.size()==1,"Cancel leaves the last copy in place")
	game.toggle_arrange()
	# Beat grid on SKD: drawn on the projected highway, flowing up with recorded notes.
	game.record_aids_enabled=true
	var world=game.field.world
	var aids=world.get_children().filter(func(c): return c.get_script()==preload("res://scripts/record_aids.gd"))[0]
	aids._process(0.0)
	check(aids.visible and aids.laid_out_skd,"Grid and wave lay out for the SKD highway")
	check(aids.grid.mesh.subdivide_depth>=100,"The grid has enough rows to follow the SKD curve")
	check(aids.grid_material.get_shader_parameter("flow_up")==true,"Beat lines travel up the track like recorded notes")
	check(aids.grid_material.render_priority>-2 and aids.grid_material.render_priority<3,"Beat lines draw above the stage floor and under the notes")
	check(aids.lane.position.x>absf(world.note_x(12.0)),"The waveform sits beside the lanes, outside lane 12")
	game.record_aids_enabled=false
	print("Recorder range copy: ","PASS" if failures==0 else str(failures)+" FAILED")
	game.queue_free(); await process_frame; quit(failures)
