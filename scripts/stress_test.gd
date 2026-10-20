extends Node
# Debug-build-only gameplay stress test, started by a trigger file:
#   user://stress_test.json  ->  {"levels": [{"nps": 16, "speed": 2.5, "seconds": 20}, ...]}
# The file is deleted as soon as it is read, so the test runs once. Each level plays a dense
# generated chart on the built-in song in Auto Play, then leaves through the pause menu's
# HOME (no score, recent or chart is saved). Note speed is changed in memory only.
# Results go to the log as lines starting with "SYNK_STRESS".
const TRIGGER = "user://stress_test.json"
var game: Control
var frames: Array = []
var proc: Array = []      # script _process time per frame (ms)
var cpu_render: Array = []
var gpu_render: Array = []
var sampling = false

# Two marker nodes run first and last each frame, timing all script _process work between them.
static var script_usec = 0
static var script_start = 0
class Marker extends Node:
	var tag = ""
	func _process(_d: float) -> void:
		var host = load("res://scripts/stress_test.gd")
		if tag == "first": host.script_start = Time.get_ticks_usec()
		else: host.script_usec += Time.get_ticks_usec() - host.script_start

func _ready() -> void:
	var first = Marker.new(); first.tag = "first"; first.process_priority = -100000
	var last = Marker.new(); last.tag = "last"; last.process_priority = 100000
	add_child.call_deferred(first); add_child.call_deferred(last)
	if not FileAccess.file_exists(TRIGGER): queue_free(); return
	var text = FileAccess.get_file_as_string(TRIGGER)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TRIGGER))
	var config = JSON.parse_string(text)
	if not config is Dictionary: config = {}
	run.call_deferred(config.get("levels", [{"nps": 8, "speed": 1.5, "seconds": 20}, {"nps": 16, "speed": 2.5, "seconds": 20}, {"nps": 24, "speed": 3.0, "seconds": 20}]))

func chart(nps: float, seconds: float, seed_value: int) -> Array:
	var rng = RandomNumberGenerator.new(); rng.seed = seed_value
	var notes: Array = []
	var t = 3.0
	while t < 3.0 + seconds:
		var lane = rng.randi_range(0, SynkChart.MAX_LANE)
		var roll = rng.randf()
		if roll < .5: notes.append(SynkChart.note(t, lane))
		elif roll < .65:
			notes.append(SynkChart.note(t, lane)); notes.append(SynkChart.note(t, (lane + 5) % SynkChart.LANES))
		elif roll < .77:
			var n = SynkChart.note(t, lane, "hold"); n.duration = rng.randf_range(.3, .8); notes.append(n)
		elif roll < .89:
			var n = SynkChart.note(t, lane, "slide"); n.duration = rng.randf_range(.4, .9)
			n.end_lane = clampi(lane + rng.randi_range(-4, 4), 0, SynkChart.MAX_LANE); notes.append(n)
		else:
			var n = SynkChart.note(t, lane, "flick"); n.direction = [0, 1, 3][rng.randi_range(0, 2)]; notes.append(n)
		t += 1.0 / nps
	return notes

func report(label: String) -> void:
	if frames.is_empty(): return
	var sorted = frames.duplicate(); sorted.sort()
	var total = 0.0
	for f in frames: total += f
	var avg = total / frames.size()
	var target = 1000.0 / maxf(1.0, Engine.max_fps if Engine.max_fps > 0 else DisplayServer.screen_get_refresh_rate())
	var janks = frames.filter(func(f): return f > target * 1.5).size()
	print("SYNK_STRESS %s frames=%d avg_ms=%.2f fps=%.1f p95_ms=%.2f p99_ms=%.2f worst_ms=%.2f janks=%d (%.1f%%) target_ms=%.2f draws=%d objects=%d nodes=%d mem_mb=%.1f" % [
		label, frames.size(), avg, 1000.0 / avg, sorted[int(sorted.size() * .95)], sorted[int(sorted.size() * .99)], sorted[-1],
		janks, 100.0 * janks / frames.size(), target,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	var mean = func(a: Array) -> float:
		var t = 0.0
		for v in a: t += v
		return t / maxf(1, a.size())
	print("SYNK_STRESS %s split process_ms=%.2f render_cpu_ms=%.2f render_gpu_ms=%.2f" % [label, mean.call(proc), mean.call(cpu_render), mean.call(gpu_render)])
	print("SYNK_STRESS %s scripts_ms=%.2f" % [label, script_usec / 1000.0 / maxf(1, frames.size())])
	script_usec = 0
	var w = game.field.world
	print("SYNK_STRESS %s counts animated=%d bursts=%d notes=%d visible_notes=%d" % [label, w.animated_materials.size(), w.bursts.size(), w.notes.size(), w.notes.values().filter(func(n): return n.node.visible).size()])
	frames.clear(); proc.clear(); cpu_render.clear(); gpu_render.clear()

var last_usec = 0
# Real wall-clock time between frames (the engine's delta is smoothed and hides stutters).
func _process(_delta: float) -> void:
	var now = Time.get_ticks_usec()
	if sampling and last_usec > 0:
		frames.append((now - last_usec) / 1000.0)
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		var vp = get_viewport().get_viewport_rid()
		cpu_render.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		gpu_render.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	last_usec = now

func run(levels: Array) -> void:
	await get_tree().create_timer(4.0).timeout
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	print("SYNK_STRESS start device=%s refresh=%.0f max_fps=%d" % [OS.get_model_name(), DisplayServer.screen_get_refresh_rate(), Engine.max_fps])
	var saved_speed = game.note_speed
	# start_game marks the song as recently played; put the list back afterwards.
	var saved_recent: Dictionary = game.lobby.recent.duplicate() if game.lobby else {}
	if str(game.song.id) != "eclipse": game.select_song(0)
	var index = 0
	for level in levels:
		index += 1
		var nps = float(level.get("nps", 8)); var seconds = float(level.get("seconds", 20))
		game.note_speed = float(level.get("speed", 1.5))
		var vp: SubViewport = game.field.viewport
		vp.msaa_3d = int(level.get("msaa", vp.msaa_3d))
		vp.scaling_3d_scale = float(level.get("scale", game.render_scale()))
		var notes = chart(nps, seconds, 1000 + index)
		var label = "L%d nps=%.0f speed=%.1f msaa=%d scale=%.2f notes=%d" % [index, nps, game.note_speed, vp.msaa_3d, vp.scaling_3d_scale, notes.size()]
		var started = Time.get_ticks_msec()
		game.start_game(notes, true)
		while game.countdown > 0 or game.resume_countdown > 0 or game.mode != "play":
			if game.mode == "paused": game.toggle_pause()
			await get_tree().process_frame
		print("SYNK_STRESS %s load_ms=%d" % [label, Time.get_ticks_msec() - started])
		var by_script: Dictionary = {}
		var stack: Array = [get_tree().root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n.is_processing() and n.get_script():
				var key = str(n.get_script().resource_path).get_file()
				by_script[key] = by_script.get(key, 0) + 1
		print("SYNK_STRESS processing ", by_script)
		frames.clear(); last_usec = 0; sampling = true
		script_usec = 0
		var elapsed = 0.0; var chunk = 0
		while elapsed < seconds + 1.5:
			await get_tree().process_frame
			if game.mode == "paused": game.toggle_pause()
			elapsed += get_process_delta_time()
			if elapsed > (chunk + 1) * 5.0: chunk += 1; report("%s t=%ds" % [label, chunk * 5])
		report("%s end" % label)
		sampling = false
		print("SYNK_STRESS %s judged=%d combo=%d max_combo=%d" % [label, game.judged, game.combo, game.max_combo])
		if game.mode == "play": game.toggle_pause()
		await get_tree().process_frame
		game.return_home()
		await get_tree().create_timer(2.0).timeout
	game.note_speed = saved_speed
	if game.lobby:
		game.lobby.recent = saved_recent
		game.prefs.set_value("lobby", "recent", saved_recent); game.prefs.save("user://preferences.cfg")
	print("SYNK_STRESS done")
	queue_free()
