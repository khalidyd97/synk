extends SceneTree
# SSRG rules run on every highway, but a finished or resumed hold/slide must flash in the
# player's hit style: SSRG art only on the SSRG stage or with the SSRG hit style.
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else: failures += 1;push_error(message);print("FAIL: ", message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	for i in 10: await process_frame
	var w=game.field.world
	var hold=SynkChart.note(3.0,6,"hold"); hold.duration=1.0
	for style in ["classic","bloom"]:
		game.highway_style="neon"; game.hit_style=style
		game.start_game([hold.duplicate(true)],true)
		for i in 8: await process_frame
		check(not w.uses_ssrg_hits(), "%s hits on the regular highway do not use SSRG art" % style)
		var entry={"key":"h1","note":hold,"pointer":-999,"done":false}
		var ssrg_before=w.ssrg_theme.hits.size()
		w.ssrg_theme.resume_sustain(entry)
		var own=(w.bursts if style=="classic" else w.blooms).filter(func(b): return b.sustain_entry.get("key","")=="h1")
		check(w.ssrg_theme.hits.size()==ssrg_before and own.size()==1, "A sustain flash uses the %s hit style, not SSRG art" % style)
		w.ssrg_theme.resume_sustain(entry)
		own=(w.bursts if style=="classic" else w.blooms).filter(func(b): return b.sustain_entry.get("key","")=="h1")
		check(own.size()==1, "Resuming the same sustain again does not stack a second %s flash" % style)
		game.return_home(); for i in 4: await process_frame
	game.highway_style="ssrg"; game.hit_style="classic"
	game.start_game([hold.duplicate(true)],true)
	for i in 8: await process_frame
	var before=w.ssrg_theme.hits.size()
	w.ssrg_theme.resume_sustain({"key":"h2","note":hold,"pointer":-999,"done":false})
	check(w.uses_ssrg_hits() and w.ssrg_theme.hits.size()==before+1, "The SSRG stage still flashes SSRG art")
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
