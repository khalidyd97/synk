extends SceneTree
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func freeze(n:Node):
	n.set_process(false);n.set_physics_process(false)
	for c in n.get_children():freeze(c)
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(2025,900)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.set_mode("play");game.ssrg_playable_run=false;game.countdown=0;freeze(game)
	game.ui.hide()
	for c in game.get_children():
		if c is CanvasLayer:c.hide()
	game.field.show();game.field.screen.show();game.field.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var w=game.field.world;w.apply_palette(SynkCoverPalette.fallback());w.apply_camera();w.update_ssrg_warp();game.field.sync_projection_style()
	game.note_shape="rectangle";w.colors[1]=Color(1,.15,.55)
	game.highway_style="gold";w.refresh_highway_look()
	w.judgment_material.set_shader_parameter("base_color",Color.YELLOW);w.judgment_material.set_shader_parameter("sweep_color",Color.YELLOW)
	for i in 5:
		var n=SynkChart.note(500+i*.1,4.5,"hold");n.duration=1
		w.build_note_node(str(i),n);w.notes[str(i)].node.position.z=.3-i*1.4
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var raw=game.field.viewport.get_texture().get_image();var displayed=root.get_texture().get_image()
	raw.save_png("res://.tools/notes-shape-raw.png");displayed.save_png("res://.tools/notes-shape-displayed.png")
	game.field.screen.material.set_shader_parameter("ssrg_canvas",false)
	await process_frame;await RenderingServer.frame_post_draw
	var legacy=root.get_texture().get_image();legacy.save_png("res://.tools/notes-shape-legacy-bloom.png")
	game.field.screen.material.set_shader_parameter("ssrg_canvas",true)
	var rect=game.field.screen.get_global_rect();var candidates=0;var matching=0;var legacy_matching=0;var max_delta=0.0
	for x in range(raw.get_width()/2-150,raw.get_width()/2+150):
		for y in range(int(raw.get_height()*.72),int(raw.get_height()*.95)):
			var a=raw.get_pixel(x,y)
			if a.r>.5 and a.b>.35 and a.g<.65 and a.r-a.g>.25 and a.b-a.g>.15:
				var logical=rect.position+Vector2(x,y)/Vector2(raw.get_size())*rect.size
				var p=Vector2i(logical/root.get_visible_rect().size*Vector2(displayed.get_size()))
				var b=displayed.get_pixelv(p);var delta=Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()
				candidates+=1;max_delta=maxf(max_delta,delta)
				if delta<.08:matching+=1
				var old=legacy.get_pixelv(p)
				if Vector3(a.r-old.r,a.g-old.g,a.b-old.b).length()<.08:legacy_matching+=1
	check(candidates>100 and matching>candidates*.95,"Final screen preserves note silhouette and color over bar (%d/%d, max delta %.3f)" % [matching,candidates,max_delta])
	check(legacy_matching<matching*.5,"Regression fixture reproduces bright-bar contamination in the legacy bloom pass")
	game.queue_free();await process_frame
	print("Final highway compositing failures: ",failures);quit(failures)
