extends SceneTree
func _initialize():run.call_deferred()
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	var helper=game.sync_helper
	helper.open();assert(game.cached_output_latency>=0)
	assert(helper.clock()>=0)
	var tap=InputEventScreenTouch.new();tap.pressed=true
	helper.lane_input(tap);helper.lane_input(tap)
	assert(helper.taps.size()==1,"Duplicate tap events are filtered")
	helper.taps=[.01,.10,.18,.23,.34,.39,.44,.49];helper.refresh_taps()
	assert(helper.use_tap_button.disabled)
	helper.taps=[.1,.101,.098,.102,.103,.099,.1,.45];helper.refresh_taps()
	assert(not helper.use_tap_button.disabled)
	helper.use_measurement();assert(absf(helper.delay_input.value-100.0)<=1.0)
	helper.reset_taps();assert(helper.taps.is_empty() and helper.use_tap_button.disabled)
	helper.player.stop();game.queue_free();await process_frame
	print("Audio sync screen: shared clock, duplicate suppression, quality gate and measured delay passed")
	quit()
