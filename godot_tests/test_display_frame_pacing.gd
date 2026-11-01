extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var saved=game.prefs.get_value("gameplay","frame_rate",0)
	for limit in [0,30,60,90,120,0]:
		game.prefs.set_value("gameplay","frame_rate",limit)
		game.apply_frame_rate()
		assert(Engine.max_fps==limit,"Auto removes the software limiter; explicit limits remain available")
	game.prefs.set_value("gameplay","frame_rate",saved)
	game.apply_frame_rate()
	game.queue_free()
	await process_frame
	print("Display frame pacing: PASS")
	quit()
