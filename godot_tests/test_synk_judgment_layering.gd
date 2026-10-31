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
	var bar=w.get_node("JudgmentPads")
	for style in ["gold","neon"]:
		game.highway_style=style;w.refresh_highway_look()
		w.judgment_material.set_shader_parameter("base_color",Color.RED);w.judgment_material.set_shader_parameter("sweep_color",Color.RED)
		for shape in ["puck","circle","rectangle"]:
			game.note_shape=shape
			for kind in ["tap","hold","slide","flick"]:
				for at in [5.0,500.0]:
					for z in [-.3,0.0,.3]:
						w.clear_notes()
						var note=SynkChart.note(at,4.5,kind)
						if kind in ["hold","slide"]:
							note.duration=1.0;note.path=[{"offset":0.0,"lane":4.5},{"offset":1.0,"lane":4.5}]
						w.build_note_node("tap",note);w.notes.tap.node.position.z=z
						bar.hide();await process_frame;await RenderingServer.frame_post_draw
						var reference=game.field.viewport.get_texture().get_image()
						bar.show();await process_frame;await RenderingServer.frame_post_draw
						var actual=game.field.viewport.get_texture().get_image()
						var pixel=Vector2i(w.camera.unproject_position(Vector3(w.note_x(4.5)*w.ssrg_approach(z),.2,w.ssrg_warped_z(z))))
						var original_blue=0.0;var visible_blue=0.0
						for x in range(-3,4):
							for y in range(-3,4):
								original_blue+=reference.get_pixelv(pixel+Vector2i(x,y)).b
								visible_blue+=actual.get_pixelv(pixel+Vector2i(x,y)).b
						check(visible_blue>=original_blue*.9,"Note stays in front of bar: %s/%s time %.0f z %.1f" % [style,shape+"/"+kind,at,z])
						if kind=="tap" and at==500.0 and is_zero_approx(z):actual.save_png("res://.tools/bar-layer-%s-%s.png" % [style,shape])
	game.queue_free();await process_frame
	print("Judgment bar layering failures: ",failures);quit(failures)
