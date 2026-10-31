extends SceneTree
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func freeze(n:Node):
	n.set_process(false);n.set_physics_process(false)
	for c in n.get_children():freeze(c)
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1440,640)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.set_mode("play");game.ssrg_playable_run=false;game.countdown=0;freeze(game)
	game.field.show();game.field.screen.show();game.field.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var w=game.field.world;w.apply_palette(SynkCoverPalette.fallback());w.apply_camera();w.update_ssrg_warp()
	game.note_shape="rectangle";w.colors[1]=Color(1,.15,.55)
	var bar=w.get_node("JudgmentPads")
	for style in ["gold","neon"]:
		game.highway_style=style;w.refresh_highway_look()
		w.judgment_material.set_shader_parameter("base_color",Color.YELLOW);w.judgment_material.set_shader_parameter("sweep_color",Color.YELLOW)
		for z in [-.25,0.0,.25]:
			w.clear_notes();var n=SynkChart.note(500,4.5,"hold");n.duration=1;w.build_note_node("pink",n);w.notes.pink.node.position.z=z
			bar.hide();await process_frame;await RenderingServer.frame_post_draw
			var reference=game.field.viewport.get_texture().get_image()
			bar.show();await process_frame;await RenderingServer.frame_post_draw
			var actual=game.field.viewport.get_texture().get_image()
			var head=w.notes.pink.node.get_child(0);var q=w.ssrg_approach(z)
			var center=w.camera.unproject_position(Vector3(w.note_x(4.5)*q,.2,w.ssrg_warped_z(z)))
			var pixels_per_unit=game.field.viewport.size.y/w.camera.size
			var half=Vector2(head.mesh.size)*q*pixels_per_unit*.5
			var candidates=0;var matching=0
			for x in range(int(center.x-half.x*.55),int(center.x+half.x*.55)):
				for y in range(int(center.y-half.y*.6),int(center.y+half.y*.6)):
					var a=reference.get_pixel(x,y);var b=actual.get_pixel(x,y)
					if a.r>.5 and a.b>.35 and a.g<.65 and a.r-a.g>.25 and a.b-a.g>.15:
						candidates+=1
						if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()<.08:matching+=1
			check(candidates>20 and matching>candidates*.8,"Pink note color survives yellow bar: %s z %.2f (%d/%d)" % [style,z,matching,candidates])
			if is_zero_approx(z):actual.save_png("res://.tools/yellow-bar-pink-note-"+style+".png")
	game.queue_free();await process_frame
	print("Yellow bar note color failures: ",failures);quit(failures)
