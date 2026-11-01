extends SceneTree
var failures=0
func check(ok:bool,label:String) -> void:
	if not ok:failures+=1;push_error(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	var score=game.ui.find_child("SSRGScoreHud",true,false)
	check(score!=null and score.digits.size()==10,"Source HUD and all score digits load")
	game.ssrg_playable_run=true;game.set_mode("play");game.countdown=0
	score._process(0)
	check(score.visible and not game.score_panel.visible and not game.hud_shadow.visible,"SSRG replaces the SYNK score panel")
	for dimensions in [Vector2i(1440,640),Vector2i(2400,1080),Vector2i(1024,768)]:
		root.size=dimensions;await process_frame;await process_frame
		check(score.size.x>0 and score.size.y>0,"Source HUD has a valid canvas at %s" % dimensions)
		var layout=score.hud_layout()
		var gauge=score.get_global_transform_with_canvas()*(layout.origin+Vector2(85,42)*layout.unit)
		var expected=game.get_global_transform_with_canvas()*Vector2(game.size.x*.1125,42*layout.unit)
		check(gauge.distance_to(expected)<1,"Gauge follows the reference position in the full stage")
		var pause_rect=game.ssrg_screens.pause_icon_rect()
		var pause_right=game.ssrg_screens.get_global_transform_with_canvas()*pause_rect.end
		check(pause_right.x<gauge.x+1,"Pause hit target sits to the left of the gauge")
		check(pause_rect.size.is_equal_approx(Vector2(80,85)*layout.unit),"Pause icon retains its source aspect and target size")
	game.paused_mode="play";game.set_mode("paused");score._process(0)
	check(score.visible,"Pause retains source score HUD")
	game.set_mode("menu");score._process(0)
	check(not score.visible,"Menu hides source score HUD")
	game.start_game([SynkChart.note(4,4)],true);score._process(0)
	check(not score.visible and game.score_panel.visible,"Regular SYNK OG play restores its score panel")
	game.queue_free();await process_frame
	print("SSRG source score HUD failures: ",failures);quit(failures)
