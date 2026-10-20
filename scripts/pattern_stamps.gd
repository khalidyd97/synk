extends Control
# Pattern stamps: phrases saved from a range in Chart Studio and stamped anywhere, in any song.
# Times are kept in beats (not seconds), so a stamp fits the tempo of the song it lands in.
# Stored in user://stamps.json. This control is the popup that lists, stamps and deletes them.
const FILE = "user://stamps.json"
const Action = preload("res://scripts/settings_action.gd")
var game: Control
var list: VBoxContainer

static func load_all() -> Array:
	if not FileAccess.file_exists(FILE): return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return data if data is Array else []
static func save_all(stamps: Array) -> void:
	var f = FileAccess.open(FILE, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(stamps))

# Saves the notes of the current range selection as a new stamp.
static func save_range(g: Control) -> void:
	var timeline = g.timeline; timeline.collect_range()
	if not timeline.range_active or timeline.range_indices.is_empty():
		g.tell("Select a range containing notes first."); return
	var beat = 60.0 / maxf(1.0, float(g.chart_bpm()))
	var start = float(timeline.range_start)
	var notes: Array = []
	for i in timeline.range_indices:
		var n: Dictionary = g.document.notes[i].duplicate(true)
		n.time = (float(n.time) - start) / beat
		n.duration = float(n.duration) / beat
		for p in n.get("path", []): p.offset = float(p.offset) / beat
		if n.has("checkpoints"): n.checkpoints = n.checkpoints.map(func(c): return float(c) / beat)
		notes.append(n)
	var stamps = load_all()
	stamps.append({"name": "Stamp %d" % (stamps.size() + 1), "beats": (float(timeline.range_end) - start) / beat, "notes": notes, "count": notes.size()})
	save_all(stamps)
	g.tell("Saved “Stamp %d” (%d notes). Open STAMPS to place it in any song." % [stamps.size(), notes.size()])

# Places a stamp at the playhead (snapped to the grid), optionally mirrored left-right.
static func place(g: Control, stamp: Dictionary, mirror: bool) -> void:
	var beat = 60.0 / maxf(1.0, float(g.chart_bpm()))
	var destination = SynkChart.snap(g.cursor, g.chart_bpm(), g.snap_division, g.chart_offset())
	var copies: Array = []
	for source in stamp.notes:
		var n: Dictionary = source.duplicate(true)
		n.time = destination + float(n.time) * beat
		n.duration = float(n.duration) * beat
		for p in n.get("path", []): p.offset = float(p.offset) * beat
		if n.has("checkpoints"): n.checkpoints = n.checkpoints.map(func(c): return float(c) * beat)
		n.lane = int(n.lane); n.end_lane = int(n.end_lane); n.direction = int(n.get("direction", 0))
		if mirror:
			n.lane = SynkChart.MAX_LANE - n.lane; n.end_lane = SynkChart.MAX_LANE - n.end_lane
			for p in n.get("path", []): p.lane = SynkChart.MAX_LANE - float(p.lane)
			if n.kind == "flick" and n.direction in [1, 3]: n.direction = 4 - n.direction
		if float(n.time) + float(n.duration) > g.length() + .001:
			g.tell("This stamp does not fit before the end of the song."); return
		copies.append(n)
	g.stop_audition(); g.document.checkpoint()
	g.space_authored_notes(copies, g.document.notes)
	g.document.notes.append_array(copies); g.document.selected = -1
	g.timeline.range_active = true; g.timeline.range_start = destination
	g.timeline.range_end = destination + float(stamp.beats) * beat
	g.timeline.reveal_time(destination); g.timeline.update_range(); g.refresh_editor()
	g.tell("Stamped %d notes%s. UNDO removes the whole stamp." % [copies.size(), " (mirrored)" if mirror else ""])

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim = ColorRect.new(); add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.color = Color(0, 0, 0, .7)
	var card = Panel.new(); add_child(card)
	card.anchor_left = .25; card.anchor_right = .75; card.anchor_top = .12; card.anchor_bottom = .88
	var style = StyleBoxFlat.new(); style.bg_color = Color(.04, .04, .04, .97); style.border_color = Color(1, 1, 1, .12)
	style.set_border_width_all(1); style.set_corner_radius_all(24); card.add_theme_stylebox_override("panel", style)
	var box = VBoxContainer.new(); card.add_child(box); box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	box.add_theme_constant_override("separation", 12)
	var title = Label.new(); box.add_child(title); title.text = "PATTERN STAMPS"; title.add_theme_font_size_override("font_size", 26)
	var hint = Label.new(); box.add_child(hint); hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Stamps are saved from a RANGE selection (SAVE AS STAMP) and fit any song's tempo. They are placed at the playhead."
	hint.add_theme_font_size_override("font_size", 15); hint.add_theme_color_override("font_color", Color("a7aac6"))
	var scroll = ScrollContainer.new(); box.add_child(scroll); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list = VBoxContainer.new(); scroll.add_child(list); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	var close = Action.new(); close.text = "CLOSE"; close.custom_minimum_size = Vector2(0, 60); box.add_child(close)
	close.pressed.connect(queue_free)
	refresh()

func refresh() -> void:
	for c in list.get_children(): c.queue_free()
	var stamps = load_all()
	if stamps.is_empty():
		var none = Label.new(); list.add_child(none); none.text = "No stamps yet."; none.add_theme_font_size_override("font_size", 18)
	for i in stamps.size():
		var stamp: Dictionary = stamps[i]; var index = i
		var row = HBoxContainer.new(); list.add_child(row); row.add_theme_constant_override("separation", 8)
		var name = Label.new(); row.add_child(name); name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.text = "%s  ·  %d notes  ·  %.1f beats" % [stamp.name, int(stamp.get("count", stamp.notes.size())), float(stamp.beats)]
		name.add_theme_font_size_override("font_size", 17)
		for spec in [["STAMP", false], ["MIRROR", true]]:
			var b = Action.new(); b.text = spec[0]; b.custom_minimum_size = Vector2(120, 54); row.add_child(b)
			var mirrored: bool = spec[1]
			b.pressed.connect(func(): place(game, stamp, mirrored); queue_free())
		var del = Action.new(); del.text = "DELETE"; del.accent = Color("ff5f7e"); del.custom_minimum_size = Vector2(110, 54); row.add_child(del)
		del.pressed.connect(func():
			var all = load_all(); all.remove_at(index); save_all(all); refresh())
