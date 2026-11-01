extends SceneTree
# SSRG runs have no 100-combo score multiplier or multiplier effects; normal runs keep them.
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	game.ssrg_playable_run=false; game.combo=250
	check(is_equal_approx(game.combo_multiplier(),1.2),"Normal runs keep the combo multiplier")
	game.ssrg_playable_run=true
	check(is_equal_approx(game.combo_multiplier(),1.0),"SSRG runs have no combo multiplier")
	game.score=0; game.add_points("PERFECT")
	check(game.score==1000,"SSRG points are not boosted by combo")
	game.mode="play"; game.multiplier_step=0; game.combo=99; game.update_combo_art(); game.combo=100; game.update_combo_art()
	check(game.multiplier_step==0,"No multiplier step (wave and bonus sound) at 100 combo in SSRG")
	check(game.combo_view.badge_age<0.0 and is_equal_approx(game.combo_view.multiplier(),1.0),"No ×badge in SSRG")
	game.ssrg_playable_run=false; game.combo=0; game.multiplier_step=0; game.update_combo_art()
	game.combo=100; game.update_combo_art()
	check(game.multiplier_step==1 and game.combo_view.badge_age>=0.0,"Normal runs still show the ×1.1 step")
	game.mode="menu"; game.queue_free(); await process_frame
	if failures==0: print("SSRG combo multiplier removed: PASS")
	quit(failures)
