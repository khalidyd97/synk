extends SceneTree
# The import wizard's song list scrolls when a drag starts on a row, without tapping that row;
# a plain tap still selects the row.
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func _initialize() -> void: run.call_deferred()
func mouse(position:Vector2,pressed:bool) -> void:
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;event.position=position;event.global_position=position
	root.push_input(event,true);await process_frame;await process_frame
func move(position:Vector2,relative:Vector2) -> void:
	var event=InputEventMouseMotion.new();event.button_mask=MOUSE_BUTTON_MASK_LEFT;event.position=position;event.global_position=position;event.relative=relative
	root.push_input(event,true);await process_frame
func run() -> void:
	root.size=Vector2i(1560,720)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in 60:await process_frame
	# The launch intro covers the screen until it ends; this test only needs the wizard.
	for node in game.find_children("*","Control",true,false):
		if node.get_script() and node.get_script().resource_path=="res://scripts/app_intro.gd":node.queue_free()
	game.app_login.hide()
	for child in game.get_children():
		if child is CanvasLayer and child.layer>=90:child.hide()
	game.open_ssrg_playables();for i in 5:await process_frame
	game.prefs.set_value("ssrg","preview",false)
	for i in 20:
		game.library.songs.append({"id":"scroll-test-%d" % i,"title":"Scroll song %02d" % i,"file":"none.wav","ssrg":{},"ssrg_charts":[{"keys":7,"variant":"7k","notes":1,"density":1,"length":60}]})
	var screen=game.ssrg_playables;screen.open_game("IMPORTED")
	for i in 30:await process_frame
	var chosen=screen.selected_id
	var card_center=screen.rows[chosen].row.get_global_rect().get_center()
	await mouse(card_center,true)
	await move(card_center-Vector2(250,0),Vector2(-250,0))
	await mouse(card_center-Vector2(250,0),false)
	check(screen.carousel.scroll_horizontal>150,"SSRG song cards follow horizontal drags")
	check(screen.selected_id==chosen,"Swiping a song card does not select it")
	screen.carousel_drag.velocity=500
	var wizard=screen.import_wizard;wizard.open()
	await process_frame
	check(screen.carousel_drag.velocity==0,"Import popup stops the carousel beneath it")
	for i in 40:wizard.public_items.append({"title":"Song %d" % i,"ready":true,"selected_keys":[7],"warnings":[],"errors":[]})
	wizard.render_list();wizard.selected=-1
	for i in 10:await process_frame
	var first=wizard.row_buttons[2].get_global_rect().get_center()
	await mouse(first,true);await mouse(first,false)
	check(wizard.selected==2,"A tap before any drag selects a row (selected %d)" % wizard.selected)
	wizard.selected=-1
	var row=wizard.row_buttons[1];var start=row.get_global_rect().get_center()
	await mouse(start,true)
	var at=start
	for i in 15:
		at+=Vector2(0,-20);await move(at,Vector2(0,-20))
	await mouse(at,false)
	check(wizard.list_scroll.scroll_vertical>200,"Dragging from a row scrolls the list (%d)" % wizard.list_scroll.scroll_vertical)
	check(wizard.selected==-1,"A drag does not tap the row it started on")
	for i in 30:await process_frame
	var settled=wizard.list_scroll.scroll_vertical
	check(settled>=300,"A flick keeps gliding after release (%d)" % settled)
	var target=wizard.row_buttons[wizard.row_buttons.size()-1]
	wizard.list_scroll.scroll_vertical=100000;for i in 5:await process_frame
	var center=target.get_global_rect().get_center()
	await mouse(center,true);await mouse(center,false)
	check(wizard.selected==wizard.row_buttons.size()-1,"A tap still selects a row (selected %d)" % wizard.selected)
	game.queue_free();await process_frame
	if failures==0:print("Import list scroll: PASS")
	quit(failures)
