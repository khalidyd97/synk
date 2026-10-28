extends SceneTree
func _initialize():run.call_deferred()
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;freeze(game)
	game.ssrg_playable_run=true;game.ssrg_lane_count=13;game.stage_intro_enabled=false
	var chart=load("res://scripts/ssrg_import.gd").parse(FileAccess.get_file_as_bytes("C:/Users/kyd970/Desktop/1004_13.seq"))
	game.start_game(chart.notes,true,"full")
	game.countdown=0;game.gameplay_start_lead=0
	var world=game.field.world
	while world.prebuilding:world.step_prebuild()
	var samples={"main":[],"world":[],"effects":[],"background":[]}
	for i in 360:
		game.song_time=8+i/60.0;game.visual_song_time=game.song_time
		for section in samples:
			var start=Time.get_ticks_usec()
			match section:
				"main":game._process(1.0/60)
				"world":world._process(1.0/60)
				"effects":world.ssrg_theme._process(1.0/60)
				"background":world.ssrg_theme.source_background._render()
			if i>=60:samples[section].append(Time.get_ticks_usec()-start)
		await process_frame
	var report={}
	for section in samples:
		samples[section].sort();report[section]={"p50_us":samples[section][150],"p95_us":samples[section][285],"max_us":samples[section][-1]}
	print("GAMEPLAY_SECTIONS ",JSON.stringify(report))
	FileAccess.open("res://.tools/gameplay-sections-latest.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.queue_free();await process_frame;quit()
