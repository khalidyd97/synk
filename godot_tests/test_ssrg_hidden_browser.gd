extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.lobby.hide()
	var selected=game.song.duplicate(true)
	selected.id="ssrg_hidden_browser_probe"; selected.ssrg=[13]
	game.song=selected
	game.lobby.refresh_tracks()
	assert(game.song.id==selected.id,"Hidden normal browser must not replace the SSRG song")
	game.features.load_variant()
	assert(game.song.id==selected.id,"Loading an SSRG chart must preserve its selected audio")
	print("SSRG hidden browser regression: PASS")
	game.queue_free()
	quit()
