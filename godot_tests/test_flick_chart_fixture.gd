extends SceneTree

func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process(false)
	var notes:Array=game.flick_test_chart()
	var flicks=notes.filter(func(note):return note.kind=="flick")
	assert(notes.size()==180 and flicks.size()>=130,"Lv 30 review chart is dense and flick-heavy")
	assert(flicks.all(func(note):return int(note.direction)==0),"Every review flick points up")
	assert(SynkChart.valid(notes),"Lv 30 review chart is structurally valid")
	game.queue_free();await process_frame
	print("Flick Lv 30 fixture: PASS")
	quit(0)
