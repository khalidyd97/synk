extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame;await process_frame
	game.set_process(false)
	game.ssrg_playable_run=true;game.set_mode("play")
	var cover=game.stage_intro.play_cover
	for dimensions in [Vector2i(1564,720),Vector2i(2400,1080),Vector2i(1024,768)]:
		root.size=dimensions;game.size=dimensions
		game.field.size=dimensions;game.field.resize_viewport()
		game.apply_safe_area()
		await process_frame
		var target=cover.target_rect()
		var entrance=game.field.get_global_transform_with_canvas()*game.field.project(game.field.world.CENTER_LANE,1.0)
		var center=cover.get_global_transform_with_canvas()*target.get_center()
		assert(absf(center.x-entrance.x)<1,"Album art is centered on the highway entrance")
		assert(target.position.y>=0 and target.end.y<cover.size.y*.27,"Album card stays in the top card area")
		assert(is_equal_approx(target.size.x,target.size.y),"Album art remains square")
	# The existing loading glide must land on this exact gameplay rectangle.
	game.stage_intro.begin(game.cover_texture_for_id("eclipse"),Color.WHITE,"Eclipse","TEST",true)
	game.stage_intro.elapsed=game.stage_intro.ENTER_TIME+1.0
	game.stage_intro.glide_card(1.0)
	var target=cover.target_rect()
	var landing=cover.get_global_transform_with_canvas()*target.position
	assert(game.stage_intro.card.get_global_rect().position.distance_to(landing)<1,"Loading cover transitions into the card slot")
	game.stage_intro.hide();cover._process(0)
	cover.on_note_hit("PERFECT");cover._process(.1)
	assert(cover.hit_glow>0 and cover.hit_glow<1,"Artwork hit glow decays smoothly")
	var held=cover.hit_glow
	game.mode="paused";cover._process(.5)
	assert(cover.hit_glow==held,"Pause freezes artwork effects")
	game.mode="play";cover.on_note_hit("MISS")
	assert(cover.hit_glow==held,"Miss does not trigger artwork glow")
	cover._process(2)
	assert(cover.hit_glow<.001,"Artwork glow settles between notes")
	game.ssrg_playable_run=false;game.highway_style="gold"
	assert(cover.target_rect().position.x>cover.size.x*.65,"Other highway styles keep their corner cover")
	game.toggle_pause(false)
	assert(game.pause_backdrop.visible and game.pause_backdrop.material==null,"Pause uses a solid backdrop without screen sampling")
	assert(is_equal_approx(game.pause_backdrop.color.a,1.0) and is_equal_approx(game.pause_backdrop.modulate.a,1.0),"Pause covers gameplay immediately")
	assert(is_equal_approx(game.modal.get_theme_stylebox("panel").bg_color.a,1.0),"Pause card is opaque")
	assert(game.pause_layer.visible and game.modal.get_parent().get_parent().get_parent()==game.pause_layer,"Pause controls belong to their own overlay")
	for overlay in [game.toast_layer,game.floating_text_input,game.app_login]:
		assert(game.pause_layer.layer>overlay.layer,"Pause appears above app overlays")
	if game.pause_tween:game.pause_tween.kill()
	game.queue_free();await process_frame
	print("SSRG album card, loading glide and solid pause: PASS")
	quit()
