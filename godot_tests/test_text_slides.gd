extends SceneTree
# Letter/number shaped slides: every glyph builds valid, forward-in-time slides, and
# Correct mode inserts typed text into the take.
var failures=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var Glyphs=preload("res://scripts/slide_glyphs.gd")
	var all_ok=true
	for character in Glyphs.GLYPHS:
		var notes=Glyphs.build(character,1.0,1.0)
		if notes.is_empty() or not SynkChart.valid(notes): all_ok=false; push_error("Glyph %s is invalid" % character)
	check(all_ok,"Every letter and number builds valid notes")
	# Hold shapes: at most two slides, all inside the hold's time and lanes 1-13.
	var shapes_ok=true
	for character in Glyphs.SHAPE_ORDER:
		for lane in [0,6,12]:
			var shaped=Glyphs.shape_notes(character,2.0,1.2,lane)
			var end=0.0
			for n in shaped:
				end=maxf(end,float(n.time)+float(n.duration))
				for p in n.path: if float(p.lane)<0.0 or float(p.lane)>12.0: shapes_ok=false
			if shaped.is_empty() or shaped.size()>2 or not SynkChart.valid(shaped) or end>3.2+.001:
				shapes_ok=false; push_error("Shape %s at lane %d is invalid" % [character,lane])
	check(shapes_ok,"Every hold shape is one or two valid slides inside the hold")
	var heads_ok=true
	for character in Glyphs.SHAPE_ORDER:
		var pair=Glyphs.shape_notes(character,2.0,1.2,6)
		if pair.size()==2 and SynkNoteSpacing.conflict(pair[0],pair[1],2.0):
			heads_ok=false; push_error("Shape %s starts its slides on top of each other" % character)
	check(heads_ok,"A shape's two slides never start on top of each other")
	check(Glyphs.SHAPE_ORDER.length()==Glyphs.SHAPES.size(),"Every shape is offered in the picker")
	check(Glyphs.clean("ab 1?!")=="AB 1","Unsupported characters are dropped and letters upper-cased")
	# A turns back at its apex: two legs, both running forward in time, meeting at the top.
	var a=Glyphs.build("A",0.0,1.2,6.0,4.0)
	check(Glyphs.build("H",0.0,1.0)[2].path[0].lane==2.0 and Glyphs.build("H",0.0,1.0)[1].path[0].lane==10.0,"Letters span eight lanes by default")
	check(a.size()==3,"A is two legs plus its bar")
	var legs=a.filter(func(n): return n.duration>.5)
	check(legs.size()==2 and is_equal_approx(float(legs[0].time)+float(legs[0].duration),1.2) and is_equal_approx(float(legs[1].time)+float(legs[1].duration),1.2),"Both legs of A end together at the apex")
	check(int(legs[0].lane) in [4,8] and int(legs[1].lane) in [4,8] and int(legs[0].end_lane)==6,"A spans lanes 4 to 8 with its apex in the centre")
	var bar=a.filter(func(n): return n.duration<.5)[0]
	check(absf(float(bar.path[-1].lane)-float(bar.path[0].lane))==2.0 and bar.duration<.1,"A's bar is a short, nearly level slide")
	# Text runs on in time, one glyph after another.
	var two=Glyphs.build("I1",0.0,1.0)
	var latest=0.0
	for n in two: latest=maxf(latest,float(n.time)+float(n.duration))
	check(latest>2.3 and latest<2.6,"Glyphs follow one another in time")
	# Insert from Correct mode.
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	game.set_process(false); game.recorder.set_process(false); game.stage_intro_enabled=false
	game.set_mode("editor"); game.document.load_notes([]); game.record_here(); game.countdown=0
	game.capture.notes=[]; game.toggle_arrange(); game.song_time=20.0
	game.update_recorder_focus()
	check(game.text_slides_button.visible,"Correct mode shows the TEXT button")
	var before=game.take_undo.size()
	var added=game.insert_text_slides("Hi 7")
	check(added>0 and game.capture.notes.size()==added,"Typed text is inserted as slides")
	check(SynkChart.valid(game.capture.notes),"Inserted text slides are valid chart notes")
	var finish=0.0
	for n in game.capture.notes: finish=maxf(finish,float(n.time)+float(n.duration))
	check(finish<=20.0 and finish>19.0,"Inserted text ends just before the current position")
	check(game.take_undo.size()>before,"Inserting text can be undone")
	game.recorder.config.locked=["slide"]
	check(game.insert_text_slides("A")==0,"Locked slides block text insertion")
	game.recorder.config.locked=[]
	# A recorded hold, selected in Correct mode, becomes a letter or number of at most two slides.
	game.capture.notes=[]
	var hold=SynkChart.note(10.0,6,"hold"); hold.duration=1.5; game.capture.notes.append(hold)
	game.arrange_selection={"note":hold,"index":0,"document":false}
	game.refresh_arrange_controls()
	check(game.text_slides_button.text=="SHAPE","Selecting a hold turns TEXT into SHAPE")
	game.open_text_slides()
	check(game.shape_picker!=null and game.shape_picker.visible,"SHAPE opens the letter and number picker")
	check(game.shape_selected_note("8")==2 and game.capture.notes.size()==2,"The hold is replaced by the shape's two slides")
	check(not game.shape_picker.visible and game.text_slides_button.text=="TEXT","The picker closes and the selection clears")
	check(SynkChart.valid(game.capture.notes),"Shaped slides are valid chart notes")
	var first=10.0; var last=0.0
	for n in game.capture.notes: first=minf(first,float(n.time)); last=maxf(last,float(n.time)+float(n.duration))
	check(is_equal_approx(first,10.0) and absf(last-11.5)<.06,"The shape fills the hold's own time")
	var undo_size=game.take_undo.size()
	check(undo_size>0,"Shaping can be undone")
	var tap=SynkChart.note(12.0,3,"tap"); game.capture.notes.append(tap)
	game.arrange_selection={"note":tap,"index":game.capture.notes.size()-1,"document":false}
	check(game.shape_selected_note("A")==0,"Only holds and slides can be shaped")
	game.arrange_selection.clear()
	game.toggle_arrange(); game.update_recorder_focus()
	check(not game.text_slides_button.visible,"TEXT is hidden while recording")
	print("Text slides: ","PASS" if failures==0 else str(failures)+" FAILED")
	game.queue_free(); await process_frame; quit(failures)
