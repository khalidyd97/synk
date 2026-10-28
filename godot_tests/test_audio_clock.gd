extends SceneTree
const Clock=preload("res://scripts/audio_clock.gd")
const Sync=preload("res://scripts/sync_helper.gd")
func _initialize():
	assert(is_equal_approx(Clock.heard_position(5,.01,.05,1),4.96))
	assert(is_equal_approx(Clock.heard_position(5,.01,.05,.5),4.98))
	var shown=0.0
	for i in 36000:
		var target=(i+1)/60.0+sin(i*.31)*.004
		var next=Clock.visual_step(shown,target,1.0/60,1.0)
		assert(next>=shown)
		assert(next<=target+Clock.MAX_VISUAL_LEAD+.001)
		assert(next>=target-Clock.MAX_VISUAL_LAG-.001)
		shown=next
	var stale_target=shown
	for i in 180:shown=Clock.visual_step(shown,stale_target,1.0/60,1.0)
	assert(shown<=stale_target+Clock.MAX_VISUAL_LEAD+.0001,"Stale mixer cannot let notes drift indefinitely")
	var paused=Clock.visual_step(shown,stale_target,0,1.0)
	assert(is_equal_approx(paused,shown))
	assert(Sync.measurement_stable([.1,.101,.098,.102,.103,.099,.10,.45]),"Median ignores one stray tap")
	assert(not Sync.measurement_stable([.01,.10,.18,.23,.34,.39,.44,.49]),"Unsteady taps cannot be applied as reliable calibration")
	print("Audio clock: heard position, ten-minute drift/jitter, stale mixer and calibration confidence passed")
	quit()
