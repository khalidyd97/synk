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
		for i in 60:effect._process(1.0/60.0)
		return float(effect.hits[0].node.position.x)
	game.pointers={7:{"world":Vector3(world.note_x(6),.035,0),"ssrg_identity":41}}
	effect.spawn(6,"hold",entry,7)
	check(is_equal_approx(effect.hits[0].node.position.x,world.note_x(6)),"A flash starts on its lane")
	var step=world.note_x(7)-world.note_x(6)
	check(is_equal_approx(finger.call(world.note_x(8)+step*.3),world.note_x(8)),"A finger a little off a lane keeps the flash on that lane")
	check(is_equal_approx(finger.call(world.note_x(8)+step*.7),world.note_x(9)),"Past halfway, the flash moves to the next lane")
	check(is_equal_approx(finger.call(world.note_x(12)+step*4.0),world.note_x(12)),"A finger beyond lane 13 leaves the flash on lane 13")
	check(is_equal_approx(finger.call(world.note_x(0)-step*4.0),world.note_x(0)),"A finger beyond lane 1 leaves the flash on lane 1")
	# It glides from lane to lane, passing every connector on the way, instead of jumping.
	game.pointers={7:{"world":Vector3(world.note_x(6),.035,0),"ssrg_identity":41}}
	effect._process(1.0/60.0)
	var before=float(effect.hits[0].node.position.x)
	check(before<world.note_x(0)+step*2.0 and before>world.note_x(0),"One frame moves the flash part of the way, not all of it")
	var passed:={}
	for i in 40:
		effect._process(1.0/60.0);passed[roundi((float(effect.hits[0].node.position.x)-world.note_x(0))/step)]=true
	check(is_equal_approx(effect.hits[0].node.position.x,world.note_x(6)) and [1,2,3,4,5,6].all(func(lane):return passed.has(lane)),"The glide passes every lane on the way and rests on the target")
	# A slide too quick to follow: when it ends, the flash still finishes on the last connector.
	effect.clear_hits()
	var quick=SynkChart.note(0,2,"slide");quick.duration=.05;quick.end_lane=9;quick.ssrg_path=true
	quick.path=[{"offset":0.0,"lane":2.0},{"offset":.05,"lane":9.0}]
	var quick_entry={"done":false,"note":quick,"key":"q","pointer":-999}
	game.pointers={};game.song_time=0.0;game.visual_song_time=0.0
	effect.spawn(2,"slide",quick_entry,-999);effect._process(1.0/60.0)
	game.song_time=.06;game.visual_song_time=.06;quick_entry.done=true
	effect._process(1.0/60.0)
	check(effect.hits.size()==1 and effect.hits[0].node.position.x<world.note_x(9)-step,"The quick slide ends before the flash has arrived")
	var seconds=0.0
	while effect.hits.size()==1 and not is_equal_approx(effect.hits[0].node.position.x,world.note_x(9)) and seconds<1.0:
		effect._process(1.0/60.0);seconds+=1.0/60.0
	check(effect.hits.size()==1 and is_equal_approx(effect.hits[0].node.position.x,world.note_x(9)) and seconds<=effect.GLIDE_AFTER+.02,"It reaches the last connector within the brief glide (%.2f s)" % seconds)
	for i in 60:effect._process(1.0/60.0)
	check(effect.hits.is_empty(),"Then the flash plays out and goes")
	var missed=quick_entry.duplicate();missed.done=false;missed.erase("ssrg_effect_until")
	effect.spawn(2,"slide",missed,-999);effect._process(1.0/60.0)
	missed.done=true;missed["missed_at"]=.06;effect._process(1.0/60.0)
	var stopped=float(effect.hits[0].node.position.x)
	for i in 5:effect._process(1.0/60.0)
	check(is_equal_approx(effect.hits[0].node.position.x,stopped),"A missed slide does not glide on")
	effect.clear_hits();game.song_time=0.0;game.visual_song_time=0.0
	for lane in 13:
		check(is_equal_approx(effect.lane_flash_x(world.note_x(lane)),world.note_x(lane)),"Lane %d is a flash position" % (lane+1))
	# Each countdown number carries one visual-only swipe across the empty line.
	effect.clear_hits();effect.update_countdown_sweep(2.99);effect.update_countdown_sweep(2.01)
	check(effect.hits.size()==13 and is_equal_approx(effect.hits[0].node.position.x,world.note_x(0)) and is_equal_approx(effect.hits[-1].node.position.x,world.note_x(12)),"Three swipes lanes 1 to 13")
	var three_color:Color=effect.hits[0].material.get_shader_parameter("tint")
	effect.clear_hits();effect.update_countdown_sweep(1.99);effect.update_countdown_sweep(1.01)
	check(effect.hits.size()==13 and is_equal_approx(effect.hits[0].node.position.x,world.note_x(12)) and is_equal_approx(effect.hits[-1].node.position.x,world.note_x(0)),"Two swipes lanes 13 to 1")
	var two_color:Color=effect.hits[0].material.get_shader_parameter("tint")
	effect.clear_hits();effect.update_countdown_sweep(.99);effect.update_countdown_sweep(.01)
	check(effect.hits.size()==13 and is_equal_approx(effect.hits[0].node.position.x,world.note_x(0)) and is_equal_approx(effect.hits[-1].node.position.x,world.note_x(12)),"One swipes lanes 1 to 13")
	var one_color:Color=effect.hits[0].material.get_shader_parameter("tint")
	check(three_color!=two_color and two_color!=one_color and three_color!=one_color,"Each countdown swipe receives a different random color")
	check(effect.hits.all(func(hit):return hit.sustain_entry.is_empty()),"Countdown swipes have no gameplay notes")
	effect.update_countdown_sweep(0.0)
	# Once 1 finishes, the highway scan gets its own final beat before notes move.
	game.countdown=.01;game.gameplay_start_lead=2.0;game.post_countdown_flash=0.0;game.start_position=0.0;game.song_time=-2.01
	game._process(.02)
	check(is_equal_approx(game.post_countdown_flash,game.POST_COUNTDOWN_FLASH_TIME),"Finishing the count starts the final highway flash")
	var held_lead=game.gameplay_start_lead
	game._process(.1)
	check(game.post_countdown_flash<game.POST_COUNTDOWN_FLASH_TIME and is_equal_approx(game.gameplay_start_lead,held_lead),"Note approach waits while the final flash travels upward")
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
