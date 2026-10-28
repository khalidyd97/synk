extends SceneTree
# Desktop CPU microprofile. No phone launch, no saved chart changes, no FPS claim.
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func _initialize():run.call_deferred()
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	freeze(game);game.ssrg_playable_run=true;game.set_mode("play");game.countdown=0
	var world=game.field.world
	var report={}
	for count in [1000,6000]:
		world.clear_notes()
		for i in count:
			var note=SynkChart.note(2+i*.04,i%10)
			world.build_note_node(str(i),note)
			world.notes[str(i)].node.visible=i<40
		var samples=[]
		for i in 240:
			game.song_time=5+i*.007
			world.ssrg_animation_frame=-1
			var start=Time.get_ticks_usec()
			world.animate_ssrg_notes()
			if i>=20:samples.append(Time.get_ticks_usec()-start)
		samples.sort()
		report[str(count)]={"p50_us":samples[int(samples.size()*.5)],"p95_us":samples[int(samples.size()*.95)],"cached_notes":count,"visible_notes":40}
		await process_frame
	print("SSRG_ANIMATION_CPU ",JSON.stringify(report))
	FileAccess.open("res://.tools/ssrg-animation-profile-latest.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.queue_free();await process_frame;quit()
