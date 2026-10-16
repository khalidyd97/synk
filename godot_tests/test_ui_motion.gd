extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(.5).timeout
	game.set_process(false)
	game.open_lobby_settings()
	var overlay=root.get_node_or_null("ScreenTransition")
	check(overlay!=null,"Navigation retains the outgoing screen")
	if overlay:
		check(overlay.get_child(0).mouse_filter==Control.MOUSE_FILTER_IGNORE,"Transition never blocks destination input")
	await create_timer(.12).timeout
	if overlay: check(overlay.get_child(0).modulate.a>0 and overlay.get_child(0).modulate.a<1,"Outgoing screen fades continuously")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/motion-mid-transition.png")
	game.close_lobby_settings(); game.open_lobby_settings()
	await create_timer(.6).timeout
	check(root.get_node_or_null("ScreenTransition")==null,"Rapid navigation releases transition textures")
	check(is_equal_approx(game.settings_panel.modulate.a,1),"Destination ends fully visible")
	game.features.open_tools("Effects")
	await create_timer(.5).timeout
	var panel=game.features.tabs.get_parent()
	check(panel.scale.is_equal_approx(Vector2.ONE),"Tool panel settles at its exact layout size")
	game.features.close_tools()
	game.set_mode("editor"); game.features.open_tools()
	game.features.show_scope("THIS SONG"); game.features.show_scope("THIS CHART")
	await create_timer(.6).timeout
	check(is_equal_approx(game.features.tabs.get_current_tab_control().modulate.a,1),"Interrupted tab transitions settle visibly")
	game.features.close_tools(); game.queue_free(); await process_frame
	print("UI motion and navigation: ","PASS" if failures==0 else str(failures)+" FAILED")
	quit(0 if failures==0 else 1)
