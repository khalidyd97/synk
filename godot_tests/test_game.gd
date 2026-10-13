extends SceneTree

var failures=0
func check(condition: bool, message: String) -> void:
	if not condition: failures+=1; push_error(message)

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game); await process_frame; await process_frame
	check(game.mode=="menu" and game.primary.text=="PLAY ORIGINAL","Main scene boots to playable menu")
	check(game.waveform.size()==512,"Waveform samples decoded")
	game.start_game([SynkChart.note(1,6)])
	game.countdown=0; game.song_time=1
	game.pointer_event(1,Vector2(.5,.765),true,false,false)
	check(game.score==1000000 and game.combo==1,"Perfect tap scores correctly")
	game.pointer_event(1,Vector2(.5,.765),false,true,false)
	var flick=SynkChart.note(1,6,"flick"); flick.direction=1
	game.start_game([flick]); game.countdown=0; game.song_time=1
	game.pointer_event(1,Vector2(.5,.765),true,false,false); game.pointer_event(1,Vector2(.6,.765),false,true,false)
	check(game.score==1000000,"Final flick motion judges on release")
	game.start_game([SynkChart.note(1,6)]); game.countdown=0; game.song_time=1
	var click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=game.size*Vector2(.5,.765)
	root.push_input(click,true)
	check(game.score==1000000,"Viewport mouse input reaches the highway")
	click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=false; click.position=game.size*Vector2(.5,.765); root.push_input(click,true)
	game.open_editor(); game.document.load_notes([]); game.document.add(12,6); game.cursor=10
	game.record_here(); check(game.mode=="record" and game.start_position==10,"Recording seeks to selected section")
	game.countdown=0; game.song_time=11
	game.pointer_event(2,Vector2(.4,.765),true,false,false); game.song_time=11.08; game.pointer_event(2,Vector2(.4,.765),false,true,false)
	game.stop_take(); check(game.mode=="editor" and game.document.notes.size()==2,"Overdub keeps previous notes")
	game.document.undo(); check(game.document.notes.size()==1,"Undo removes entire take")
	game.document.selected=0; game.document.convert("flick",.5,game.length()); game.refresh_editor()
	check(game.info.text.contains("FLICK"),"Inspector updates after note conversion")
	game.document.dirty=false; game.close_editor(); check(game.mode=="menu","Studio closes back to menu")
	if DisplayServer.get_name()!="headless":
		await process_frame; await process_frame
		root.get_texture().get_image().save_png("res://.tools/godot-menu.png")
		game.start_game(SynkChart.demo()); game.countdown=0; game.audio.play(20)
		await process_frame; await process_frame
		root.get_texture().get_image().save_png("res://.tools/godot-highway.png")
		game.open_editor(); game.document.load_notes(SynkChart.demo()); game.cursor=12; game.refresh_editor(); await process_frame; await process_frame
		root.get_texture().get_image().save_png("res://.tools/godot-studio.png")
	print("Scene integration: ","PASS" if failures==0 else str(failures)+" FAILED")
	game.queue_free(); await process_frame; quit(0 if failures==0 else 1)
