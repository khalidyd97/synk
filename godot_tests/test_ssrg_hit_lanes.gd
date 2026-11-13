extends SceneTree
# SKD hit flashes sit on the chart's lanes: the lane nearest the finger on a hold or slide,
# and never outside the first and last lane, however far the finger strays.
var failures=0
func check(ok:bool,label:String) -> void:
	if not ok:failures+=1;push_error(label)
func _initialize() -> void: run.call_deferred()
func freeze(node:Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run() -> void:
	root.size=Vector2i(1440,640)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	freeze(game)
	game.highway_style="ssrg";game.ssrg_playable_run=true;game.ssrg_lane_count=13;game.set_mode("play");game.countdown=0
	var world=game.field.world;var effect=world.ssrg_theme
	world.refresh_highway_look()
	var hold=SynkChart.note(0,6,"hold");hold.duration=4.0
	var entry={"done":false,"note":hold,"key":"h","pointer":7,"sustain_last_pointer":7,"sustain_last_identity":41}
	var finger=func(x:float) -> float:
		game.pointers={7:{"world":Vector3(x,.035,0),"ssrg_identity":41}}
		effect._process(0)
		return float(effect.hits[0].node.position.x)
	game.pointers={7:{"world":Vector3(world.note_x(6),.035,0),"ssrg_identity":41}}
	effect.spawn(6,"hold",entry,7)
	check(is_equal_approx(effect.hits[0].node.position.x,world.note_x(6)),"A flash starts on its lane")
	var step=world.note_x(7)-world.note_x(6)
	check(is_equal_approx(finger.call(world.note_x(8)+step*.3),world.note_x(8)),"A finger a little off a lane keeps the flash on that lane")
	check(is_equal_approx(finger.call(world.note_x(8)+step*.7),world.note_x(9)),"Past halfway, the flash moves to the next lane")
	check(is_equal_approx(finger.call(world.note_x(12)+step*4.0),world.note_x(12)),"A finger beyond lane 13 leaves the flash on lane 13")
	check(is_equal_approx(finger.call(world.note_x(0)-step*4.0),world.note_x(0)),"A finger beyond lane 1 leaves the flash on lane 1")
	for lane in 13:
		check(is_equal_approx(effect.lane_flash_x(world.note_x(lane)),world.note_x(lane)),"Lane %d is a flash position" % (lane+1))
	# Charts with fewer keys only use their own lanes.
	game.ssrg_lane_count=7
	check(is_equal_approx(effect.lane_flash_x(world.note_x(3)),world.note_x(4)) and is_equal_approx(effect.lane_flash_x(world.note_x(2.9)),world.note_x(2)),"A 7-key chart flashes on its seven lanes")
	game.ssrg_lane_count=4
	check(is_equal_approx(effect.lane_flash_x(world.note_x(5.5)),world.note_x(4)) and is_equal_approx(effect.lane_flash_x(world.note_x(11)),world.note_x(12)),"A 4-key chart flashes on its four lanes")
	game.ssrg_lane_count=13
	# The same rule on SYNK's own highway look, which keeps SKD rules and can use SKD flashes.
	effect.clear_hits()
	game.highway_style="gold";game.hit_style="ssrg";world.refresh_highway_look()
	effect.spawn(6,"hold",entry,7)
	check(is_equal_approx(finger.call(world.note_x(12)+absf(world.note_x(12)-world.note_x(11))*5.0),world.note_x(12)),"The classic look also keeps the flash inside lane 13")
	print("SKD hit lane failures: %d" % failures)
	game.queue_free();await process_frame
	quit(failures)
