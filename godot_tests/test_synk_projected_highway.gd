extends SceneTree
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1440,640)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.highway_style="gold";game.stage_intro_enabled=false;game.note_speed=1;game.note_size=1.0;game.ssrg_playable_run=false
	game.set_mode("play");game.countdown=0;freeze(game)
	for child in game.get_children():
		if child is CanvasLayer:child.hide()
	game.field.show();game.field.screen.show();game.field.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var world=game.field.world;world.apply_palette(SynkCoverPalette.fallback());world.apply_camera();world.update_ssrg_warp()
	check(world.uses_projected_highway() and not game.uses_ssrg_gameplay(),"SYNK shares projection without activating SSRG judgment or artwork")
	check(world.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"SYNK uses the source flat-canvas camera")
	check(is_equal_approx(world.ssrg_approach(-15),pow(.75,6)),"SYNK position and scale use source progress power")
	check(not world.ssrg_theme.active,"Original SSRG stage is absent from SYNK play")
	var line=world.camera.unproject_position(Vector3(world.note_x(4),.035,0))
	var input=game.field.input_position(line/Vector2(game.field.viewport.size))
	check(absf(SynkCapture.lane(input.x)-4)<.001,"Projected judgment touch maps back to the correct SYNK lane")
	for style in ["gold","neon"]:
		game.highway_style=style;world.refresh_highway_look()
		check(world.track_nodes.all(func(n):return n.visible),"SYNK floor is retained for "+style)
		check((world.gold_nodes if style=="gold" else world.neon_nodes).all(func(n):return n.visible),"Selected SYNK rails are retained for "+style)
		for variant in [["puck","solid"],["circle","solid"],["rectangle","solid"],["puck","neon"],["circle","neon"],["rectangle","neon"]]:
			var shape=str(variant[0]);game.trail_style=str(variant[1])
			game.note_shape=shape;world.clear_notes()
			var tap=SynkChart.note(5,4)
			world.build_note_node("near",tap);world.notes.near.node.position.z=-3
			world.build_note_node("far",SynkChart.note(6,7));world.notes.far.node.position.z=-15
			var hold=SynkChart.note(5,2,"hold");hold.duration=.8
			world.build_note_node("hold",hold);world.notes.hold.node.position.z=-2
			var slide=SynkChart.note(5,5,"slide");slide.duration=1;slide.end_lane=8;slide.path=[{"offset":0.0,"lane":5.0},{"offset":.5,"lane":3.0},{"offset":1.0,"lane":8.0}]
			world.build_note_node("slide",slide);world.notes.slide.node.position.z=-1
			check(world.notes.near.node.get_child(0).material_override.get_shader_parameter("artwork").resource_path.begins_with("res://assets/neon/"),"SYNK artwork remains selected for "+shape)
			world.notes.near.node.hide();world.notes.far.node.hide();world.notes.hold.node.hide();world.notes.slide.node.hide()
			await process_frame;await RenderingServer.frame_post_draw
			var baseline=game.field.viewport.get_texture().get_image()
			for key in ["near","far","hold","slide"]:world.notes[key].node.show()
			await process_frame;await RenderingServer.frame_post_draw
			var image=game.field.viewport.get_texture().get_image()
			var raw=-15.0;var expected=Vector3(world.note_x(7)*world.ssrg_approach(raw),.13,world.ssrg_warped_z(raw))
			var pixel=Vector2i(world.camera.unproject_position(expected));var difference=0.0
			for x in range(-6,7):
				for y in range(-4,5):
					var p=pixel+Vector2i(x,y)
					if p.x>=0 and p.y>=0 and p.x<image.get_width() and p.y<image.get_height():
						var a=image.get_pixelv(p);var b=baseline.get_pixelv(p);difference=maxf(difference,Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length())
			check(difference>.05,"Far note renders at its projected position in "+style+"/"+shape)
			image.save_png("res://.tools/synk-projected-"+style+"-"+shape+"-"+game.trail_style+".png")
	world.clear_notes()
	for dimensions in [Vector2i(2400,1080),Vector2i(1280,720),Vector2i(1024,768)]:
		root.size=dimensions;game.size=dimensions;game.field.size=dimensions;game.field.resize_viewport()
		world.apply_camera();world.update_ssrg_warp()
		var bar=world.get_node("JudgmentPads")
		world.clear_hit_effects();game.pointers.clear()
		for style in ["gold","neon"]:
			game.highway_style=style;world.refresh_highway_look()
			bar.hide();await process_frame;await RenderingServer.frame_post_draw
			var without_bar=game.field.viewport.get_texture().get_image()
			bar.show();await process_frame;await RenderingServer.frame_post_draw
			var with_bar=game.field.viewport.get_texture().get_image()
			with_bar.save_png("res://.tools/judgment-corrected-%s-%d.png" % [style,dimensions.x])
			for z in [-.65,.65]:
				var q=world.ssrg_approach(z)
				for side in [-1,1]:
					for margin in [-.15,.15]:
						var point=Vector3(side*(world.PAD_HALF_WIDTH*q+margin),.035,world.ssrg_warped_z(z))
						var sample=Vector2i(world.camera.unproject_position(point))
						var a=with_bar.get_pixelv(sample);var b=without_bar.get_pixelv(sample)
						var difference=Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()
						check(difference>.1 if margin<0 else difference<.03,"Judgment band follows both rail edges above and below timing line: "+style+" "+str(dimensions))
		for lane in [0.0,6.0,12.0]:
			for z in [-.65,.65]:
				var point=Vector3(world.note_x(lane)*world.ssrg_approach(z),.035,world.ssrg_warped_z(z))
				var pixel=world.camera.unproject_position(point)/Vector2(dimensions)
				var row_input=game.field.input_position(pixel)
				check(absf(world.lane_world_x(SynkCapture.lane(row_input.x))-world.note_x(lane))<.001,"Both edges of tapered judgment band map to the correct lane")
		var center=world.camera.unproject_position(bar.position)
		var near_edge=world.camera.unproject_position(Vector3(0,.035,world.JUDGMENT_DEPTH*.5))
		var far_edge=world.camera.unproject_position(Vector3(0,.035,-world.JUDGMENT_DEPTH*.5))
		check(center.y>dimensions.y*.75 and near_edge.y<dimensions.y and far_edge.y>0,"Judgment band stays inside the lower screen at "+str(dimensions))
		for lane in [0.0,6.0,12.0]:
			var pixel=game.field.project(lane,0)
			check(absf(pixel.y-center.y)<.01,"Arriving note and judgment band share the exact centerline")
			var touch=game.field.input_position(pixel/Vector2(dimensions))
			var hit=game.field.touch_world_position(pixel/Vector2(dimensions))
			check(absf(hit.z)<.001,"Visible bar maps to the timing plane")
			check(absf(world.lane_world_x(SynkCapture.lane(touch.x))-world.note_x(lane))<.001,"Outer and center touches match the drawn note positions")
			game.auto_play=false;game.song_time=5.0;game.live_cursor=0;game.pointers.clear()
			var entry={"note":SynkChart.note(5,lane),"key":"fit-tap","started":false,"done":false,"pointer":-999,"error":0.0}
			game.live=[entry]
			game.pointer_event(1,pixel/Vector2(dimensions),true,false,false)
			check(entry.done and entry.started and is_zero_approx(float(entry.error)),"Touching the visible bar judges the on-time note in each outer/center lane")
		var hold=SynkChart.note(5,0,"hold");hold.duration=1.0
		world.build_note_node("held",hold);world.notes.held.node.position.z=.2*world.travel_speed()
		world.set_trail_clip(world.notes.held.node,.02)
		world.notes.held.node.hide()
		await process_frame;await RenderingServer.frame_post_draw
		var baseline=game.field.viewport.get_texture().get_image()
		world.notes.held.node.show()
		await process_frame;await RenderingServer.frame_post_draw
		var image=game.field.viewport.get_texture().get_image()
		var pixel=Vector2i(world.camera.unproject_position(Vector3(world.note_x(0),.035,.3)))
		var a=image.get_pixelv(pixel);var b=baseline.get_pixelv(pixel)
		check(Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()<.03,"Held ribbon ends at judgment instead of drawing across the bottom band")
		image.save_png("res://.tools/synk-judgment-fit-%d.png" % dimensions.x)
		world.clear_notes()
	game.set_mode("record");world.apply_camera();world.update_ssrg_warp()
	check(not world.uses_projected_highway() and world.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Recorder retains its independent editable camera")
	game.queue_free();await process_frame
	print("SYNK projected highway failures: ",failures);quit(failures)
