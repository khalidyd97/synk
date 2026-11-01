extends SceneTree
const SOURCE=preload("res://scripts/ssrg_hud_source_data.gd")
func _initialize():run.call_deferred()
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.set_process(false);game.ssrg_playable_run=true;game.set_mode("play");game.countdown=0
	var hud:Control
	for child in game.ui.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("ssrg_judgement.gd"):hud=child
	assert(hud!=null)
	game.combo=13;hud.since_hit=.2;hud.displayed_grade="PERFECT"
	var unit=game.size.y/game.field.world.ssrg_canvas_height()
	var rects=hud.combo_rects()
	var word_rect=hud.super_word_rect()
	assert(word_rect.size.is_equal_approx(Vector2(272,54)*unit),"Authored super-word size")
	assert(is_equal_approx(word_rect.get_center().y,hud.size.y*.5-60*unit),"Authored super-word center")
	assert(rects.size()==2 and rects[0].size.is_equal_approx(Vector2(56,90)*unit),"Serialized combo quad size")
	assert(is_equal_approx(rects[1].get_center().x-rects[0].get_center().x,176.0/3*unit),"Native centered UINumber spacing")
	assert(is_equal_approx(rects[0].get_center().y,hud.size.y*.5+3*unit),"Serialized combo parent Y")
	hud.displayed_grade="GOOD";rects=hud.combo_rects()
	assert(is_equal_approx(rects[1].size.x,60*unit),"GOOD keeps the authored wider least-significant slot")
	assert(is_equal_approx(rects[1].get_center().x-rects[0].get_center().x,172.0/3*unit),"GOOD uses its own native bounds calculation")
	assert(hud.digit_art[0].resource_path.ends_with("combo/super_0.png"),"Main combo uses the bound HUD atlas instead of effects artwork")
	assert(SOURCE.PERFECT[0].resource_path.ends_with("combo/perfect_0.png") and SOURCE.GOOD[0].resource_path.ends_with("combo/good_0.png"),"Grade-specific source fonts")
	assert(hud.combo_back.show_behind_parent and hud.combo_back.material.blend_mode==CanvasItemMaterial.BLEND_MODE_ADD,"Super secondary atlas uses its source additive blend behind the HUD font")
	assert(SOURCE.SCORE_COMMA.get_size()==Vector2(16,19),"Bound score comma crop")
	assert(SOURCE.SCORE_RIGHT_EDGES==[249.0,229.0,209.0,179.0,159.0,139.0,109.0],"Serialized fixed score slots including group gaps")
	game.queue_free();await process_frame
	print("SSRG source fonts, fixed score slots, comma and combo layout: PASS");quit()
