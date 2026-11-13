extends SceneTree
# SSRG speed moves in 0.1 steps between 1.0 and 10.0, and holding a button repeats the step.
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	var saved=game.prefs.get_value("ssrg","speed_value",null)
	var playables=game.ssrg_playables
	game.prefs.set_value("ssrg","speed_value",3.0)
	playables.change_speed(.1);check(is_equal_approx(game.ssrg_speed_setting(),3.1),"+ adds 0.1 (%s)" % game.ssrg_speed_setting())
	playables.change_speed(-.1);playables.change_speed(-.1);check(is_equal_approx(game.ssrg_speed_setting(),2.9),"− takes 0.1")
	game.prefs.set_value("ssrg","speed_value",9.95);playables.change_speed(.1);check(is_equal_approx(game.ssrg_speed_setting(),10.0),"Capped at 10.0")
	game.prefs.set_value("ssrg","speed_value",1.05);playables.change_speed(-.1);check(is_equal_approx(game.ssrg_speed_setting(),1.0),"Floor at 1.0")
	check(playables.speed_label.text=="1.0","Label shows one decimal (%s)" % playables.speed_label.text)
	game.prefs.set_value("ssrg","speed_value",5.0)
	playables.speed_held_step=.1;playables.speed_held_time=0.0
	playables.repeat_held_speed(.3);check(is_equal_approx(game.ssrg_speed_setting(),5.0),"No repeat before 0.4 s")
	playables.repeat_held_speed(.5);check(is_equal_approx(game.ssrg_speed_setting(),5.5),"Holding repeats (%s)" % game.ssrg_speed_setting())
	playables.speed_held_step=0.0
	if saved==null:game.prefs.erase_section_key("ssrg","speed_value")
	else:game.prefs.set_value("ssrg","speed_value",saved)
	game.prefs.save("user://preferences.cfg")
	game.queue_free();await process_frame
	if failures==0:print("SSRG speed steps: PASS")
	quit(failures)
