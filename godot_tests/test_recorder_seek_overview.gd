extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.document.load_notes([])
	game.cursor=0
	game.record_here()
	check(game.record_overview.horizontal and game.record_overview.recorder_mode,"Recorder has the horizontal whole-song overview")
	game.countdown=0
	game.song_time=1.0
	game.capture.begin(1,.5,Vector2(.5,.8),"hold")
	var overview=game.record_overview
	overview.seek_at(Vector2(34.0+(overview.size.x-42.0)*.5,overview.size.y*.5))
	var expected=game.length()*.5
	check(game.arranging and absf(game.song_time-expected)<.02,"Seeking opens correction mode at the chosen song position")
	check(game.capture.gestures.is_empty() and game.capture.notes.size()==1,"Seeking seals an in-progress hold without losing it")
	game.toggle_arrange()
	check(not game.arranging and absf(game.song_time-maxf(0.0,expected-game.recorder.resume_lead))<.02,"Resuming starts ahead of the chosen position")
	game.audio.stop()
	game.queue_free()
	await process_frame
	print("Recorder seek overview failures: ",failures)
	quit(failures)
