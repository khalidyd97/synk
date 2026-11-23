extends SceneTree

func _initialize() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var notes:Array=game.flick_test_chart()
	var settings={"bpm":128.0,"beat_offset":0.0,"verse2":-1.0,"bridge":-1.0,"bookmarks":[]}
	var payload={"version":SynkChart.FORMAT_VERSION,"song_id":"eclipse","chart_name":"lv30","title":"Eclipse · Flick Test","bpm":128.0,"beat_offset":0.0,"chart_settings":settings,"notes":notes}
	DirAccess.make_dir_recursive_absolute("res://builds/android")
	var file=FileAccess.open("res://builds/android/eclipse_lv30.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(payload,"\t"));file.close()
	game.queue_free();await process_frame
	quit(0)
