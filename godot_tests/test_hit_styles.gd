extends SceneTree
# Two hit styles, both drawn by the SKD hit pipeline: SKD's flash art, and Lumen. Classic and
# Bloom are gone; an old saved choice opens as SKD.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: run.call_deferred()
func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	for i in 4: await process_frame
	check(game.HIT_STYLES == ["ssrg", "lumen"], "Only the SKD and Lumen hit styles are offered")
	for old in ["classic", "bloom", "anything"]:
		game.change_hit_style(old)
		check(game.hit_style == "ssrg", "An old or unknown hit style (%s) falls back to SKD" % old)
	freeze(game)
	game.ssrg_playable_run = true; game.set_mode("play"); game.countdown = 0
	var w = game.field.world; var effect = w.ssrg_theme
	var hold = SynkChart.note(0, 6, "hold"); hold.duration = 2.0
	for style in ["ssrg", "lumen"]:
		for highway in ["ssrg", "gold"]:
			effect.clear_hits()
			game.hit_style = style; game.highway_style = highway; w.refresh_highway_look()
			w.spawn_hit(6, "tap")
			check(effect.hits.size() == 1 and effect.hits[0].style == style, "%s hits on the %s highway use the %s style" % [style, highway, style])
			var expected = "res://scripts/lumen_hit.gdshader" if style == "lumen" else "res://scripts/ssrg_hit.gdshader"
			check(effect.hits[0].material.shader.resource_path == expected, "%s hits draw with their own picture" % style)
			check(is_equal_approx(effect.hits[0].node.position.x, w.note_x(6)), "%s hits sit on their lane" % style)
			# Same frame clock and lifetime as SKD.
			for i in 4: effect._process(1.0 / 60.0)
			if style == "lumen":
				check(is_equal_approx(effect.hits[0].material.get_shader_parameter("frame"), float(int(4.0 / 60.0 * effect.HIT_FPS))), "Lumen steps its frames on the 33 fps clock")
			for i in 30: effect._process(1.0 / 60.0)
			check(effect.hits.is_empty(), "%s hits end after the SKD lifetime" % style)
			# A resumed sustain flashes once, in the chosen style.
			var entry = {"key": "h1", "note": hold, "pointer": -999, "done": false}
			effect.resume_sustain(entry); effect.resume_sustain(entry)
			check(effect.hits.filter(func(h): return h.sustain_entry.get("key", "") == "h1").size() == 1 and effect.hits[0].style == style, "A resumed %s sustain flashes once" % style)
	# Lumen colours follow the note type, and a chosen hit colour replaces them.
	effect.clear_hits(); game.hit_style = "lumen"; game.hit_color = ""; game.highway_colors = "adaptive"
	for kind in ["tap", "hold", "slide", "flick"]: w.spawn_hit(6, kind, 1)
	var tints = effect.hits.map(func(h): return h.material.get_shader_parameter("tint"))
	check(tints[0] != tints[1] and tints[1] == tints[2] and tints[3] != tints[0] and tints[3] != tints[1], "Lumen tints taps, sustains and flicks differently")
	check(is_equal_approx(effect.hits[3].material.get_shader_parameter("direction"), 1.0) and effect.hits[0].material.get_shader_parameter("direction") < 0.0, "Only flicks throw their shards in a direction")
	game.hit_color = "33ff66"; w.spawn_hit(6, "tap")
	check(effect.hits.back().material.get_shader_parameter("tint") == Color("33ff66"), "A chosen hit colour replaces Lumen's")
	game.hit_color = ""
	# Pooled flashes follow a style change, so the warm-up prepares the right picture.
	effect.clear_hits(); effect.prefill(4); game.hit_style = "ssrg"; effect.prefill(4)
	check(effect.hit_pool.all(func(h): return h.style == "ssrg"), "Pooled flashes take the style in use")
	check(not "bursts" in w and not "blooms" in w, "The Classic and Bloom effects are removed")
	print("Hit style failures: %d" % failures)
	game.queue_free(); await process_frame
	quit(failures)
