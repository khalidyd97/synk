extends Control
# Correct-mode overlap tools: find notes that sit on top of each other across the lanes,
# step through them, fix one (spread, stagger, keep one) or auto-space them all at once.

var game: Control
var groups: Array = []
var current = -1
# How far apart (in lanes) overlapping notes must sit; 0 = as close as the notes allow.
var gap_lanes = 2.0
var bar: Panel
var count_label: Label
var buttons: Dictionary = {}
# Auto-space picker: choose the gap, preview what still overlaps, then space everything.
var picker: Panel
var picker_count: Label
var gap_chips: Dictionary = {}
var gap_value: Label
const MAX_GAP = 12.0
const ACTION = preload("res://scripts/recorder_action.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var old_mode = {"tight": 0.0, "normal": 2.0, "wide": 3.0}.get(str(game.prefs.get_value("editor", "overlap_gap", "normal")), 2.0)
	gap_lanes = float(game.prefs.get_value("editor", "overlap_gap_lanes", old_mode))
	gap_lanes = clampf(roundf(gap_lanes), 0.0, MAX_GAP)
	bar = Panel.new();add_child(bar);bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.anchor_left = 0.155;bar.anchor_right = 0.845;bar.anchor_top = 0.842;bar.anchor_bottom = 0.918
	var style = StyleBoxFlat.new();style.bg_color = Color(0.05, 0.05, 0.06, 0.92)
	style.border_color = Color(1, 1, 1, 0.07);style.set_border_width_all(1);style.set_corner_radius_all(22)
	style.shadow_color = Color(0, 0, 0, 0.45);style.shadow_size = 16
	bar.add_theme_stylebox_override("panel", style)
	var columns = [["prev", "‹", 0.0, 0.05], ["count", "", 0.05, 0.2], ["next", "›", 0.2, 0.25],
		["spread", "SPREAD", 0.265, 0.375], ["stagger", "STAGGER", 0.38, 0.49], ["keep", "KEEP ONE", 0.495, 0.605],
		["gap", "", 0.61, 0.76], ["auto", "AUTO-SPACE ALL", 0.77, 0.995]]
	for column in columns:
		var key: String = column[0]
		if key == "count":
			count_label = Label.new();bar.add_child(count_label)
			count_label.anchor_left = column[2];count_label.anchor_right = column[3];count_label.anchor_top = 0;count_label.anchor_bottom = 1
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			count_label.add_theme_font_size_override("font_size", 17);count_label.add_theme_color_override("font_color", Color("e6e1d7"))
			continue
		var b = ACTION.new();b.text = column[1];b.caption_size = 17;b.compact = true
		b.variant = "record" if key == "auto" else "tool";bar.add_child(b)
		b.anchor_left = column[2] + 0.004;b.anchor_right = column[3] - 0.004;b.anchor_top = 0.14;b.anchor_bottom = 0.86
		b.pressed.connect(func(): press(key))
		buttons[key] = b
	buttons.prev.tooltip_text = "Previous overlap";buttons.next.tooltip_text = "Next overlap"
	buttons.spread.tooltip_text = "Move this overlap's notes apart across the lanes"
	buttons.stagger.tooltip_text = "Offset the later notes by a sixteenth so they play as a quick roll"
	buttons.keep.tooltip_text = "Keep the selected note and delete the others in this overlap"
	buttons.gap.tooltip_text = "Choose how much room notes need beside each other"
	buttons.auto.tooltip_text = "Choose a gap, then spread every overlap in the take"
	build_picker()

func build_picker() -> void:
	picker = Panel.new();add_child(picker);picker.mouse_filter = Control.MOUSE_FILTER_STOP;picker.visible = false
	picker.anchor_left = 0.155;picker.anchor_right = 0.845;picker.anchor_top = 0.712;picker.anchor_bottom = 0.83
	picker.add_theme_stylebox_override("panel", bar.get_theme_stylebox("panel"))
	var title = Label.new();picker.add_child(title);title.text = "Space notes by"
	title.anchor_left = 0.02;title.anchor_right = 0.16;title.anchor_top = 0;title.anchor_bottom = 1
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18);title.add_theme_color_override("font_color", Color("e6e1d7"))
	# "Closest" packs notes as tight as their bodies allow; − / + choose any lane count.
	var closest = picker_button("Closest", 0.16, 0.26, "Notes sit as close as their bodies allow")
	closest.pressed.connect(func(): choose_gap(0.0))
	gap_chips[0.0] = closest
	var minus = picker_button("−", 0.27, 0.33, "One lane less between overlapping notes")
	minus.pressed.connect(func(): choose_gap(maxf(0.0, gap_lanes - 1.0)))
	buttons["less"] = minus
	gap_value = Label.new();picker.add_child(gap_value)
	gap_value.anchor_left = 0.33;gap_value.anchor_right = 0.47;gap_value.anchor_top = 0;gap_value.anchor_bottom = 1
	gap_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;gap_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gap_value.add_theme_font_size_override("font_size", 22);gap_value.add_theme_color_override("font_color", Color("f4f1ea"))
	var plus = picker_button("+", 0.47, 0.53, "One lane more between overlapping notes")
	plus.pressed.connect(func(): choose_gap(minf(MAX_GAP, gap_lanes + 1.0)))
	buttons["more"] = plus
	picker_count = Label.new();picker.add_child(picker_count)
	picker_count.anchor_left = 0.54;picker_count.anchor_right = 0.765;picker_count.anchor_top = 0;picker_count.anchor_bottom = 1
	picker_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;picker_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	picker_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	picker_count.add_theme_font_size_override("font_size", 17)
	var apply = ACTION.new();apply.text = "SPACE ALL";apply.caption_size = 17;apply.compact = true;apply.variant = "record"
	picker.add_child(apply)
	apply.anchor_left = 0.774;apply.anchor_right = 0.991;apply.anchor_top = 0.16;apply.anchor_bottom = 0.84
	apply.tooltip_text = "Spread every overlap using the chosen gap"
	apply.pressed.connect(func(): auto_space_all();picker.visible = false;refresh())
	buttons["apply"] = apply

func picker_button(text: String, left: float, right: float, tip: String) -> Control:
	var b = ACTION.new();b.text = text;b.caption_size = 17;b.compact = true;b.variant = "tool"
	picker.add_child(b);b.tooltip_text = tip
	b.anchor_left = left + 0.004;b.anchor_right = right - 0.004;b.anchor_top = 0.16;b.anchor_bottom = 0.84
	return b

func gap_name(value: float) -> String:
	if value == 1.0: return "1 lane"
	return "Closest" if value == 0.0 else "%d lanes" % int(value)

func choose_gap(value: float) -> void:
	gap_lanes = value
	game.prefs.set_value("editor", "overlap_gap_lanes", gap_lanes);game.prefs.save("user://preferences.cfg")
	refresh()

func press(key: String) -> void:
	match key:
		"prev": step(-1)
		"next": step(1)
		"spread": fix_current("spread")
		"stagger": fix_current("stagger")
		"keep": fix_current("keep")
		"gap", "auto": picker.visible = not picker.visible;refresh()

func gap() -> float:
	return maxf(float(game.authoring_lane_gap()), gap_lanes)

# Notes the recorder can change: the take, plus chart notes of writable types.
func editable_entries() -> Array:
	var result: Array = []
	for i in game.capture.notes.size(): result.append({"note": game.capture.notes[i], "document": false, "index": i})
	for i in game.document.notes.size(): result.append({"note": game.document.notes[i], "document": true, "index": i})
	return result

# Groups of notes that overlap across the lanes, in time order. Notes that overlap a
# shared neighbour form one group (a chord of three is one overlap, not three pairs).
func find_groups() -> Array:
	var entries = editable_entries().filter(func(e): return e.note.kind not in game.recorder.locks())
	entries.sort_custom(func(a, b): return float(a.note.time) < float(b.note.time))
	var g = gap();var parent: Array = range(entries.size());var linked: Dictionary = {}
	var root = func(i: int) -> int:
		while parent[i] != i: i = parent[i]
		return i
	for i in entries.size():
		var a: Dictionary = entries[i]
		for j in range(i + 1, entries.size()):
			var b: Dictionary = entries[j]
			if float(b.note.time) > float(a.note.time) + float(a.note.duration) + .002: break
			if SynkNoteSpacing.conflict(a.note, b.note, g):
				parent[root.call(j)] = root.call(i);linked[i] = true;linked[j] = true
	var by_root: Dictionary = {}
	for i in entries.size():
		if not linked.has(i): continue
		var r = root.call(i)
		if not by_root.has(r): by_root[r] = []
		by_root[r].append(entries[i])
	var found: Array = []
	for r in by_root:
		var members: Array = by_root[r]
		var heads = members.map(func(e): return float(e.note.time))
		# "at" is where the notes actually collide: the latest head in the group.
		found.append({"time": heads.min(), "at": heads.max(), "entries": members})
	found.sort_custom(func(a, b): return a.time < b.time)
	return found

func _process(_delta: float) -> void:
	visible = game.mode == "record" and game.arranging
	if not visible: groups = [];current = -1;picker.visible = false;return
	if Engine.get_process_frames() % 6 == 0: refresh()
	queue_redraw()

func refresh() -> void:
	groups = find_groups()
	if current >= groups.size(): current = groups.size() - 1
	var any = not groups.is_empty()
	count_label.text = ("Overlap %d of %d" % [current + 1, groups.size()] if current >= 0 else "%d overlap%s" % [groups.size(), "" if groups.size() == 1 else "s"]) if any else "No overlaps"
	count_label.add_theme_color_override("font_color", Color("ff8a5b") if any else Color("bcb7ad"))
	buttons.prev.disabled = not any;buttons.next.disabled = not any
	for key in ["spread", "stagger", "keep"]: buttons[key].disabled = current < 0 or not any
	buttons.gap.text = "GAP · " + gap_name(gap_lanes).to_upper()
	buttons.gap.set_selected(picker.visible);buttons.auto.set_selected(picker.visible)
	gap_chips[0.0].set_selected(gap_lanes == 0.0)
	gap_value.text = "Closest" if gap_lanes == 0.0 else gap_name(gap_lanes)
	buttons.less.disabled = gap_lanes <= 0.0;buttons.more.disabled = gap_lanes >= MAX_GAP
	picker_count.text = ("%d overlap%s at this gap" % [groups.size(), "" if groups.size() == 1 else "s"]) if any else "Nothing overlaps at this gap"
	picker_count.add_theme_color_override("font_color", Color("ff8a5b") if any else Color("bcb7ad"))
	buttons.apply.disabled = not any

# Jump to the previous/next overlap: bring it just past the line and select its first note.
func step(direction: int) -> void:
	refresh()
	if groups.is_empty(): return
	current = (current + direction) % groups.size() if current >= 0 else (0 if direction > 0 else groups.size() - 1)
	if current < 0: current += groups.size()
	focus(current)

func focus(index: int) -> void:
	var group: Dictionary = groups[index]
	game.song_time = clampf(float(group.at) + 0.35, 0, game.length());game.visual_song_time = game.song_time;game.visual_clock_ready = false
	var first: Dictionary = group.entries[0]
	game.arrange_selection = {"note": first.note, "document": first.document, "index": first.index}
	game.refresh_arrange_controls();refresh()

func begin_change(entries: Array) -> void:
	if entries.any(func(e): return e.document): game.document.checkpoint();game.document.dirty = true

func fix_current(action: String) -> void:
	refresh()
	if current < 0 or current >= groups.size(): return
	var group: Dictionary = groups[current];var entries: Array = group.entries
	begin_change(entries)
	match action:
		"spread": spread(entries)
		"stagger": stagger(entries)
		"keep": keep_one(entries)
	game.commit_take_history();game.refresh_arrange_controls();refresh()

# Spread a group across the lanes with the recorder's chord solver; other notes stay put.
func spread(entries: Array) -> bool:
	var movable = entries.map(func(e): return e.note)
	var fixed: Array = []
	for e in editable_entries():
		if not movable.any(func(n): return is_same(n, e.note)): fixed.append(e.note)
	# Solve each head time in the group separately; sustained notes are obstacles for later heads.
	var ok = true
	for note in movable:
		var others = movable.filter(func(n): return not is_same(n, note))
		var result = SynkNoteSpacing.place(note, others, fixed, gap())
		ok = ok and bool(result.resolved)
	return ok

# Offset every later note by a sixteenth (in time order) so the overlap becomes a roll.
func stagger(entries: Array) -> void:
	var step_seconds = 60.0 / maxf(1.0, game.chart_bpm()) / 4.0
	var ordered = entries.duplicate();ordered.sort_custom(func(a, b): return int(a.note.lane) < int(b.note.lane))
	for i in range(1, ordered.size()):
		var n: Dictionary = ordered[i].note
		n.time = clampf(float(n.time) + step_seconds * i, 0, maxf(0, game.length() - float(n.duration)))

# Keep the selected note (or the first) and delete the rest of the group.
func keep_one(entries: Array) -> void:
	var selected: Dictionary = game.arrange_selection.get("note", {})
	var keep = entries[0].note
	for e in entries:
		if is_same(e.note, selected): keep = e.note
	for e in entries:
		if is_same(e.note, keep): continue
		if e.document:
			var at = game.document.notes.find(e.note)
			if at >= 0: game.document.selected = at;game.document.delete()
		else:
			var at = game.capture.notes.find(e.note)
			if at >= 0: game.capture.notes.remove_at(at)
	game.arrange_selection = {}

# One tap: spread every overlap. Groups that cannot fit (too many notes at once) stay marked.
func auto_space_all() -> void:
	refresh()
	if groups.is_empty(): return
	var all_entries: Array = []
	for group in groups: all_entries.append_array(group.entries)
	begin_change(all_entries)
	var fixed_count = 0;var total = groups.size()
	for pass_index in 3:
		for group in find_groups(): spread(group.entries)
	var left = find_groups().size();fixed_count = total - left
	game.commit_take_history();game.refresh_arrange_controls();current = -1;refresh()
	game.tell("Spaced %d overlap%s%s" % [fixed_count, "" if fixed_count == 1 else "s", (" · %d need a manual fix" % left) if left > 0 else ""], "success" if left == 0 else "auto")

# Coral rings on every overlapping head; the current overlap gets a bright ring.
func _draw() -> void:
	if not visible or not game.note_arranger: return
	for index in groups.size():
		for e in groups[index].entries:
			var point = game.note_arranger.screen_point(float(e.note.time), float(e.note.lane))
			if point == null: continue
			var hot = index == current
			draw_arc(point, 30.0 if hot else 24.0, 0, TAU, 40, Color(0, 0, 0, 0.6), 7, true)
			draw_arc(point, 30.0 if hot else 24.0, 0, TAU, 40, Color("ffd0b8") if hot else Color("ff8a5b"), 3.5, true)
