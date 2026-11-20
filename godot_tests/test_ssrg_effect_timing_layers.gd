extends SceneTree
var failures=0
func check(ok: bool,label: String):
	if not ok: failures+=1;push_error(label)
func freeze(node: Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func solid(color: Color) -> Texture2D:
	var image=Image.create(8,8,false,Image.FORMAT_RGBA8);image.fill(color)
	return ImageTexture.create_from_image(image)
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1440,640)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.ssrg_playable_run=true;game.ssrg_lane_count=13;game.set_mode("play");game.countdown=0
	game.field.sync_projection_style();freeze(game)
	game.field.show();game.field.screen.show();game.field.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var world=game.field.world;world.apply_camera();world.update_ssrg_warp()
	var effect=world.ssrg_theme
	effect.spawn(4.5,"tap",{},-999)
	var hit:Dictionary=effect.hits[0]
	effect._process(1.0/33.0+.00001)
	check(hit.material.get_shader_parameter("atlas")==effect.imported_frames[1],"Source frame interval is 1/33 second")
	game.set_mode("paused");game.paused_mode="play"
	var age:float=hit.age;effect._process(.2)
	check(is_equal_approx(hit.age,age),"Pause freezes effect playback")
	game.set_mode("play");effect._process(.29)
	check(effect.hits.size()==1,"Tap remains until the final source frame finishes")
	effect._process(.02)
	check(effect.hits.is_empty(),"Tap hides at one third second")
	var entry={"done":false,"note":SynkChart.note(0,4.5,"hold")}
	effect.spawn(4.5,"hold",entry,-999);hit=effect.hits[0]
	check(hit.frames==effect.imported_frames,"Ordinary sustains use source effect A")
	effect._process(.101)
	check(is_equal_approx(hit.age,.101-effect.HOLD_RETRIGGER),"Held effect preserves excess frame time when restarting")
	entry.done=true;effect._process(.32)
	check(effect.hits.size()==1,"Released effect completes its remaining animation (got %d)" % effect.hits.size())
	effect._process(.02);check(effect.hits.is_empty(),"Released effect returns to pool")
	var slide_note=SynkChart.note(0,2,"slide");slide_note.duration=10.0;slide_note.end_lane=8
	var slide_entry={"done":false,"note":slide_note,"pointer":17,"sustain_last_pointer":17,"sustain_last_identity":71,"ssrg_contact":true}
	game.pointers[17]={"world":Vector3(world.note_x(2),.035,0),"ssrg_identity":71}
	effect.spawn(2,"slide",slide_entry,17)
	effect.advance_hits(.001,true)
	game.pointers[17].world.x=world.note_x(5)
	effect.advance_hits(.001,true)
	check(effect.hits.size()==4,"Sliding across three new lanes leaves one independent flash on every crossed lane (got %d)" % effect.hits.size())
	var occupied:Dictionary={}
	for lane_hit in effect.hits:occupied[roundi(world.world_lane(float(lane_hit.x)))]=true
	check(occupied.has(2) and occupied.has(3) and occupied.has(4) and occupied.has(5),"Crossed-lane flashes occupy the complete finger path")
	game.pointers[17].world.x=world.note_x(4)
	effect.advance_hits(.001,true)
	check(effect.hits.size()==5,"Re-entering a lane emits a fresh flash (got %d)" % effect.hits.size())
	game.pointers.erase(17);slide_entry.done=true
	world.clear_hit_effects()
	for i in 40:effect.spawn(4.5,"tap",{},-999)
	check(effect.hits.size()==40,"Dense hits preserve all overlapping instances")
	world.clear_hit_effects()
	check(effect.hits.is_empty() and effect.hit_pool.is_empty(),"Chart cleanup also removes SSRG flashes")
	var near=SynkChart.note(1,4.5);var far=SynkChart.note(2,4.5)
	near.lane=4.5;far.lane=4.5
	world.build_note_node("near",near);world.build_note_node("far",far)
	# Draw at one point to make the overlap unambiguous; far is deliberately created last.
	var near_head=world.notes.near.node.get_child(0);var far_head=world.notes.far.node.get_child(0)
	world.own_material(near_head).set_shader_parameter("artwork",solid(Color.BLUE))
	world.own_material(far_head).set_shader_parameter("artwork",solid(Color.RED))
	var slide=SynkChart.note(1,4.5,"hold");slide.duration=1
	world.build_note_node("hold",slide)
	var trail=world.notes.hold.node.get_child(1)
	check(trail.mesh.surface_get_material(0).render_priority<near_head.material_override.render_priority,"Connector layer sits behind note heads")
	check(world.ssrg_finger_beam_material.render_priority<trail.mesh.surface_get_material(0).render_priority,"Beams sit behind connectors")
	check(effect.original_stage.receptors[0].material_override.render_priority<near_head.material_override.render_priority,"Guides sit behind note heads")
	world.notes.hold.node.hide()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image=game.field.viewport.get_texture().get_image()
	var pixel=Vector2i(world.camera.unproject_position(Vector3(0,.13,0)))
	var color=image.get_pixelv(pixel)
	check(color.b>.8 and color.r<.2,"Earlier note is visibly above a later note regardless of construction order")
	image.save_png("res://.tools/ssrg-layer-overlap.png")
	game.queue_free();await process_frame
	print("SSRG source effect timing and layering failures: ",failures);quit(failures)
