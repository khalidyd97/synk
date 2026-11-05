extends SceneTree

var failures=0
func check(ok:bool,message:String)->void:
	if not ok:failures+=1;push_error(message)
func _initialize()->void:run.call_deferred()
func run()->void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process(false)
	var picker=game.chart_library
	picker.show_available_levels(["lv2","lv5"])
	picker.level_popup.visible=true
	check(picker.level_popup.visible and picker.level_buttons.size()==30,"New level opens a 30-button screen")
	check(picker.level_buttons[1].disabled and picker.level_buttons[4].disabled,"Occupied levels are disabled")
	check(picker.selected_level==1 and not picker.level_create_button.disabled,"First unused level is selected")
	picker.select_level(2)
	check(picker.selected_level==1,"Occupied level cannot be selected")
	picker.select_level(7)
	check(picker.selected_level==7 and picker.level_buttons[6].selected,"Free level can be selected directly")
	picker.show_available_levels(preload("res://scripts/chart_levels.gd").all_keys())
	check(picker.selected_level==0 and picker.level_create_button.disabled,"A full song cannot create another level")
	game.queue_free();await process_frame
	print("Level picker failures: ",failures);quit(failures)
