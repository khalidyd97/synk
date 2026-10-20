extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	var start=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<4200: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://lobby3d.png")
	quit()
