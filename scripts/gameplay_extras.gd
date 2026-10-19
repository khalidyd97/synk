extends Node
# Gameplay extras: hit sounds, haptics, combo milestones, the song intro card, judgement
# leniency, touch assist, play modifiers, per-chart stats, the daily challenge and replays.
# main.gd owns judging and input; it calls the on_* hooks here. Preferences live in the
# "gameplay_extras" section of preferences.cfg.
const SOUNDS = {
	"tap": preload("res://assets/sfx/hit_tap.wav"),
	"hold": preload("res://assets/sfx/hit_hold.wav"),
	"flick": preload("res://assets/sfx/hit_flick.wav"),
}
const VOICES = 6
const MILESTONES = [50, 100, 200, 300, 500, 750, 1000]
const BOLD = preload("res://assets/fonts/FiraSans-Bold.ttf")
# Judgement windows in seconds for Normal; Easy widens them by EASY_SCALE.
const PERFECT = .045
const GREAT = .09
const GOOD = .16
const EASY_SCALE = 1.4

var game: Control
var settings: Dictionary = {
	"hit_volume": .6, "vibration": true, "lane_hints": false, "window_preview": true,
	"judgement": "normal", "touch_assist": true, "mirror": false, "hidden": false, "sudden": false,
}
var players: Array[AudioStreamPlayer] = []
var next_voice = 0
var milestone_label: Label
var intro_card: Control
var intro_title: Label
var intro_artist: Label
# Replays: every touch of the last real run, by song time; played back through the same input path.
var recording: Array = []
var replay_events: Array = []
var replay_index = 0
var replaying = false
var replay_pending = false
var last_replay: Dictionary = {}

func _ready() -> void:
	for key in settings: settings[key] = game.prefs.get_value("gameplay_extras", key, settings[key])
	for i in VOICES:
		var player = AudioStreamPlayer.new(); add_child(player); players.append(player)
	milestone_label = Label.new(); game.ui.add_child(milestone_label)
	milestone_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); milestone_label.anchor_top = .40; milestone_label.anchor_bottom = .50
	milestone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; milestone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	milestone_label.add_theme_font_override("font", BOLD); milestone_label.add_theme_font_size_override("font_size", 44)
	milestone_label.add_theme_color_override("font_color", Color("fff1cf"))
	milestone_label.add_theme_color_override("font_outline_color", Color(1, .6, .2, .55)); milestone_label.add_theme_constant_override("outline_size", 10)
	milestone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; milestone_label.modulate.a = 0
	build_intro_card()

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	game.prefs.set_value("gameplay_extras", key, value); game.prefs.save("user://preferences.cfg")
	if game.field and game.field.world: game.field.world.refresh_play_aids()

func scale() -> float: return EASY_SCALE if str(settings.judgement) == "easy" else 1.0
func perfect_window() -> float: return PERFECT * scale()
func great_window() -> float: return GREAT * scale()
func good_window() -> float: return GOOD * scale()

# --- Hits ---------------------------------------------------------------------------
func on_judged(entry: Dictionary, judgement: String, combo: int) -> void:
	if judgement == "MISS":
		if game.field: game.field.world.flash_miss_lane(SynkChart.lane_at(entry.note, game.song_time))
		return
	var kind = str(entry.note.kind)
	play_hit("flick" if kind == "flick" else ("hold" if kind in ["hold", "slide"] else "tap"))
	if bool(settings.vibration) and not game.auto_play and (judgement == "PERFECT" or kind == "flick"):
		Input.vibrate_handheld(20 if kind == "flick" else 12)
	if combo in MILESTONES: show_milestone(combo)

func play_hit(kind: String) -> void:
	var volume = float(settings.hit_volume)
	if volume <= 0.0 or DisplayServer.get_name() == "headless": return
	var player = players[next_voice]; next_voice = (next_voice + 1) % VOICES
	player.stream = SOUNDS[kind]; player.volume_db = linear_to_db(volume) - 4.0
	player.play()

func show_milestone(combo: int) -> void:
	milestone_label.text = "%d COMBO" % combo
	milestone_label.pivot_offset = milestone_label.size * .5
	milestone_label.scale = Vector2.ONE * 1.25; milestone_label.modulate.a = 1.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(milestone_label, "scale", Vector2.ONE, .35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(milestone_label, "modulate:a", 0.0, .5).set_delay(.9)
	if game.field: game.field.world.rail_flare()

# --- Song intro card -----------------------------------------------------------------
func build_intro_card() -> void:
	intro_card = Control.new(); game.ui.add_child(intro_card); intro_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); intro_card.anchor_top = .2; intro_card.anchor_bottom = .4
	intro_title = Label.new(); intro_card.add_child(intro_title)
	intro_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); intro_title.anchor_bottom = .62
	intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; intro_title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	intro_title.add_theme_font_override("font", BOLD); intro_title.add_theme_font_size_override("font_size", 56)
	intro_artist = Label.new(); intro_card.add_child(intro_artist)
	intro_artist.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); intro_artist.anchor_top = .64
	intro_artist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; intro_artist.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	intro_artist.add_theme_font_size_override("font_size", 24); intro_artist.add_theme_color_override("font_color", Color("cfd2ec"))
	for label_node in [intro_title, intro_artist]:
		label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_node.add_theme_color_override("font_shadow_color", Color(0, 0, .02, .8)); label_node.add_theme_constant_override("shadow_offset_y", 3)
	intro_card.modulate.a = 0

func on_song_start() -> void:
	var song: Dictionary = game.song
	intro_title.text = preload("res://scripts/lobby.gd").display_title(str(song.get("title", "")))
	var artist = str(song.get("artist", "")).strip_edges()
	intro_artist.text = artist if not artist.is_empty() else game.album_name(song)
	intro_card.position.x = -60; intro_card.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(intro_card, "modulate:a", 1.0, .35)
	tween.parallel().tween_property(intro_card, "position:x", 0.0, .45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.4)
	tween.tween_property(intro_card, "modulate:a", 0.0, .5)

# --- Modifiers -----------------------------------------------------------------------
func apply_mods(notes: Array) -> Array:
	if not bool(settings.mirror): return notes
	var mirrored: Array = []
	for original in notes:
		var n: Dictionary = original.duplicate(true)
		n.lane = SynkChart.MAX_LANE - int(n.lane); n.end_lane = SynkChart.MAX_LANE - int(n.get("end_lane", n.lane))
		for point in n.get("path", []): point.lane = float(SynkChart.MAX_LANE) - float(point.lane)
		if n.kind == "flick" and int(n.get("direction", 0)) in [1, 3]: n.direction = 4 - int(n.direction)
		mirrored.append(n)
	return mirrored

func mods_text() -> String:
	var parts: Array = []
	for key in ["mirror", "hidden", "sudden"]:
		if bool(settings[key]): parts.append(key.capitalize())
	if str(settings.judgement) == "easy": parts.append("Easy judge")
	return " · ".join(parts)

# --- Stats ---------------------------------------------------------------------------
func record_result(chart_key: String, counts: Dictionary, total: int) -> Dictionary:
	var stats: Dictionary = game.prefs.get_value("chart_stats", chart_key, {"plays": 0, "full_combo": false, "all_perfect": false})
	stats.plays = int(stats.plays) + 1
	var misses = int(counts.get("MISS", 0))
	if misses == 0 and total > 0: stats.full_combo = true
	if misses == 0 and int(counts.get("GREAT", 0)) == 0 and int(counts.get("GOOD", 0)) == 0 and total > 0: stats.all_perfect = true
	game.prefs.set_value("chart_stats", chart_key, stats); game.prefs.save("user://preferences.cfg")
	return stats

func stats_for(chart_key: String) -> Dictionary:
	return game.prefs.get_value("chart_stats", chart_key, {"plays": 0, "full_combo": false, "all_perfect": false})

# --- Daily challenge -----------------------------------------------------------------
# One song and one modifier per day, the same for everyone on the same date.
func daily() -> Dictionary:
	var date = Time.get_date_dict_from_system()
	var seed_value = int(date.year) * 10000 + int(date.month) * 100 + int(date.day)
	var entries: Array = game.lobby.all_entries() if game.lobby else []
	if entries.is_empty(): return {}
	var rng = RandomNumberGenerator.new(); rng.seed = seed_value
	var entry: Dictionary = entries[rng.randi_range(0, entries.size() - 1)]
	var mod: String = ["mirror", "hidden", "sudden", "none"][rng.randi_range(0, 3)]
	return {"id": str(entry.id), "title": str(entry.title), "mod": mod}

func start_daily() -> void:
	var challenge = daily()
	if challenge.is_empty(): return
	for key in ["mirror", "hidden", "sudden"]: settings[key] = key == str(challenge.mod)
	if game.field: game.field.world.refresh_play_aids()
	game.tell("Daily challenge: %s%s" % [challenge.title, "" if challenge.mod == "none" else " · " + str(challenge.mod).capitalize()])

# --- Replays -------------------------------------------------------------------------
func begin_run(notes: Array, is_replay: bool) -> void:
	replaying = is_replay; replay_index = 0
	if not is_replay: recording = []
	last_replay.notes = notes.duplicate(true) if not is_replay else last_replay.get("notes", notes)

func record_input(id: int, p: Vector2, began: bool, ended: bool, canceled: bool) -> void:
	if replaying or game.auto_play or game.mode != "play": return
	recording.append([game.song_time, id, p.x, p.y, began, ended, canceled])

func finish_run() -> void:
	if not replaying and not recording.is_empty(): last_replay.events = recording.duplicate()

func has_replay() -> bool: return last_replay.has("events") and not (last_replay.events as Array).is_empty()

func start_replay() -> void:
	if not has_replay(): return
	replay_events = last_replay.events
	replay_pending = true
	game.start_game(last_replay.notes, false, game.last_section)
	replay_pending = false; replaying = true; replay_index = 0

func _process(_delta: float) -> void:
	step_replay()

# Feeds recorded touches whose time has come, through the normal input path.
func step_replay() -> void:
	if not replaying or game.mode != "play" or game.countdown > 0: return
	while replay_index < replay_events.size() and float(replay_events[replay_index][0]) <= game.song_time:
		var e: Array = replay_events[replay_index]; replay_index += 1
		# Judge at the exact recorded moment, so the replay matches the run frame for frame.
		var now = game.song_time
		game.song_time = float(e[0])
		game.pointer_event(int(e[1]), Vector2(float(e[2]), float(e[3])), bool(e[4]), bool(e[5]), bool(e[6]), true)
		game.song_time = maxf(game.song_time, now)
