extends Control
# Correct mode's tools, in two columns beside the highway so nothing covers the track.
# They change with what is selected:
#   nothing     → left: Type text · Copy part · Paste here      right: Undo Redo · overlaps · Aids
#   a note      → left: Tap Hold Slide Flick · Delete            right: [hold/slide: Move Bend
#                 Draw Connector More Letter] · Undo Redo · overlaps
# Every button calls the recorder's existing actions; this file only decides what shows.

const ACTION = preload("res://scripts/recorder_action.gd")
const A = preload("res://scripts/arcade_style.gd")
var game: Control
var plate: Panel
var buttons: Dictionary = {}
var layout_key = ""
const KINDS = ["tap", "hold", "slide", "flick"]
const MODES = {"move": "Move", "shape": "Bend", "draw": "Draw", "points": "Connector"}
# Column placement (fractions of the screen): the room left of and right of the highway,
# below the top controls, where the track is still narrow.
const COLUMN_TOP = .15
const ROW = .072
const LEFT_X = [.012, .115]
const RIGHT_X = [.885, .988]
const GROUP_GAP = .012
# Which column a button lives in, top to bottom; "|" marks a gap between groups.
# Two keys in one entry share a row.
const LEFT_ORDER = ["tap", "hold", "slide", "flick", "|", ["earlier", "later"], ["lane_left", "lane_right"], "|", "delete", "text", "copy", "stagger", "paste", "|", "step", ["back", "rest"], "start", "end", "up", "down", "zigzag", "alternate", "|", "cancel"]
const RIGHT_ORDER = ["move", "shape", "draw", "points", "more", "letter", "|", "undo", "redo", "|", "overlaps", "aids"]
var right_plate: Panel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new(); style.bg_color = Color(.05, .05, .06, .92)
	style.border_color = Color(1, 1, 1, .07); style.set_border_width_all(1); style.set_corner_radius_all(22)
	plate = Panel.new(); add_child(plate); plate.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.add_theme_stylebox_override("panel", style)
	right_plate = Panel.new(); add_child(right_plate); right_plate.mouse_filter = Control.MOUSE_FILTER_STOP
	right_plate.add_theme_stylebox_override("panel", style)
	add("undo", "Undo", game.undo_record_note)
	add("redo", "Redo", game.redo_record_note)
	add("text", "Type text", game.open_text_slides)
	for kind in KINDS: add(kind, kind.capitalize(), func(): game.change_arrange_note_type(kind))
	for key in MODES: add(key, MODES[key], func(): choose_mode(key))
	add("more", "More", func(): game.note_arranger.expanded = not game.note_arranger.expanded)
	add("letter", "Letter", game.open_shape_picker)
	add("overlaps", "", func(): game.overlap_tools.toggle_open())
	add("aids", "Aids", game.toggle_record_aids)
	add("delete", "DELETE", game.delete_arrange_note)
	add("earlier", "Earlier", func(): game.nudge_arrange_note(-1, 0))
	add("later", "Later", func(): game.nudge_arrange_note(1, 0))
	add("lane_left", "◂ Lane", func(): game.nudge_arrange_note(0, -1))
	add("lane_right", "Lane ▸", func(): game.nudge_arrange_note(0, 1))
	for key in ["earlier", "later", "lane_left", "lane_right"]: buttons[key].caption_size = 14
	buttons.earlier.tooltip_text = "Move the note one grid step earlier"
	buttons.later.tooltip_text = "Move the note one grid step later"
	add("copy", "Copy part", begin_copy)
	add("start", "Start here", mark_start)
	add("end", "End here", mark_end)
	add("paste", "Paste here", paste_here)
	add("cancel", "Cancel", cancel_copy)
	# Step entry: tap lanes to place notes one grid step apart, with no timing needed.
	add("step", "Step entry", func(): game.toggle_step_entry())
	add("back", "Back", func(): game.step_entry_advance(-1))
	add("rest", "Rest", func(): game.step_entry_advance(1))
	for key in ["back", "rest"]: buttons[key].caption_size = 15
	buttons.step.tooltip_text = "Tap a lane to place a note at the line; each tap moves one grid step on"
	buttons.back.tooltip_text = "Go back one grid step"
	buttons.rest.tooltip_text = "Skip one grid step without a note"
	# Stagger: keep the timing of a marked part and lay its notes out as a pattern.
	add("stagger", "Stagger part", begin_stagger)
	add("up", "Stairs up", func(): apply_pattern("up"))
	add("down", "Stairs down", func(): apply_pattern("down"))
	add("zigzag", "Zigzag", func(): apply_pattern("zigzag"))
	add("alternate", "Alternate", func(): apply_pattern("alternate"))
	buttons.stagger.tooltip_text = "Mark a part, then turn its notes into stairs, a zigzag or alternating lanes"
	buttons.copy.tooltip_text = "Copy a part: mark its start and end at the line"
	buttons.paste.tooltip_text = "Paste the copied part so it starts at the line"
	buttons.text.tooltip_text = "Insert typed letters or numbers as shaped slides"
	buttons.letter.tooltip_text = "Turn this hold or slide into a letter or number"
	buttons.shape.tooltip_text = "Drag the trail to bend or stretch it"
	buttons.points.tooltip_text = "Tap the trail to add or remove a connector"
	buttons.more.tooltip_text = "Snap, curves, endpoints and one-tap shapes"

func add(key: String, text: String, action: Callable) -> void:
	var b = ACTION.new(); b.text = text; b.caption_size = 17; b.compact = true; b.variant = "tool"
	add_child(b); b.pressed.connect(action); buttons[key] = b

func choose_mode(key: String) -> void:
	var arranger = game.note_arranger
	arranger.edit_mode = "shape" if key == "points" else key
	game.dots_mode = key == "points" and not game.dots_mode
	game.refresh_arrange_controls()

func selected_note() -> Dictionary: return game.arrange_selection.get("note", {})

# Which buttons show, in order; "|" marks a gap between groups.
func wanted() -> Array:
	var note = selected_note()
	var overlaps = not game.overlap_tools.groups.is_empty()
	var keys: Array = ["undo", "redo", "|"]
	if copy_stage == "pattern":
		keys.append_array(["up", "down", "zigzag", "alternate", "|", "cancel"])
		return keys
	if copy_stage != "":
		keys.append("start" if copy_stage == "start" else "end")
		keys.append_array(["|", "cancel"])
		return keys
	if note.is_empty():
		keys.append("text")
		keys.append_array(["|", "copy", "stagger"])
		if not clipboard.is_empty(): keys.append("paste")
		keys.append_array(["|", "step"])
		if game.step_entry: keys.append_array(["back", "rest"])
		if overlaps: keys.append_array(["|", "overlaps"])
		keys.append_array(["|", "aids"])
		return keys
	keys.append_array(KINDS)
	keys.append_array(["earlier", "later", "lane_left", "lane_right"])
	if note.kind in ["hold", "slide"]:
		keys.append("|")
		if game.uses_skd_recorder_surface():
			# SKD authors an ordered chain of discrete channel nodes. Freehand curves and
			# text silhouettes belong to SYNK's Classic recorder, not the source format.
			keys.append_array(["move","shape","points","more"])
		else:keys.append_array(MODES.keys());keys.append_array(["more", "|", "letter"])
	if overlaps: keys.append_array(["|", "overlaps"])
	keys.append_array(["|", "delete"])
	return keys

func _process(_delta: float) -> void:
	visible = game.mode == "record" and game.arranging and not (game.aids_drawer and game.aids_drawer.visible)
	if not game.arranging and copy_stage != "": copy_stage = ""
	if not visible: return
	var keys = wanted()
	var key = ",".join(keys)
	if key != layout_key: layout_key = key; arrange(keys)
	refresh()

func arrange(keys: Array) -> void:
	for b in buttons.values(): b.visible = false
	column(keys, LEFT_ORDER, LEFT_X, plate)
	column(keys, RIGHT_ORDER, RIGHT_X, right_plate)

# Stacks the wanted buttons of one column and fits its plate around them.
func column(keys: Array, order: Array, x: Array, panel: Panel) -> void:
	var y = COLUMN_TOP + .008
	var any = false; var gap = false
	for entry in order:
		if entry is String and entry == "|": gap = any; continue
		var row: Array = (entry if entry is Array else [entry]).filter(func(k): return k in keys)
		if row.is_empty(): continue
		if gap: y += GROUP_GAP; gap = false
		var width = (x[1] - x[0] - .012) / row.size()
		for i in row.size():
			var b: Control = buttons[row[i]]; b.visible = true; any = true
			b.anchor_left = x[0] + .006 + width * i + (.002 if i > 0 else 0.0); b.anchor_right = x[0] + .006 + width * (i + 1) - (.002 if i < row.size() - 1 else 0.0)
			b.anchor_top = y; b.anchor_bottom = y + ROW - .012
			b.offset_left = 0; b.offset_right = 0; b.offset_top = 0; b.offset_bottom = 0
		y += ROW
	panel.visible = any
	panel.anchor_left = x[0]; panel.anchor_right = x[1]; panel.anchor_top = COLUMN_TOP; panel.anchor_bottom = y - .004
	panel.offset_left = 0; panel.offset_right = 0; panel.offset_top = 0; panel.offset_bottom = 0

# --- Copy a part and paste it somewhere else --------------------------------------------
# Correct mode's line is "here": scroll so the start of the part is on the line and mark it,
# scroll to its end and mark that, then scroll anywhere and paste. The copy keeps its place
# on the beat grid, so a part copied on the beat lands on the beat.
var copy_stage = ""          # "" · "start" (waiting for the start mark) · "end" (waiting for the end)
var copy_start = 0.0
var clipboard: Array = []    # copied notes, times relative to copy_start
var clipboard_span = 0.0

func here() -> float: return float(game.song_time)

func begin_copy() -> void:
	game.arrange_selection = {}
	mark_purpose = "copy"; copy_stage = "start"; game.refresh_arrange_controls()

func cancel_copy() -> void:
	copy_stage = ""; stagger_notes = []; game.refresh_arrange_controls()

# --- Stagger a part ---------------------------------------------------------------------
# Mark a part the same way as for a copy, then pick a pattern. The notes keep their times;
# only their lanes change, so a rhythm that was played right can be laid out as stairs.
var mark_purpose = "copy"     # what the start and end marks are for: "copy" or "stagger"
var stagger_notes: Array = [] # the marked notes themselves (not copies), in time order
func begin_stagger() -> void:
	game.arrange_selection = {}
	mark_purpose = "stagger"; copy_stage = "start"; game.refresh_arrange_controls()

# Notes that start together (a chord) move as one step of the pattern.
func stagger_groups() -> Array:
	var groups: Array = []
	for note in stagger_notes:
		if groups.is_empty() or float(note.time) - float(groups[-1][0].time) > .012: groups.append([note])
		else: groups[-1].append(note)
	return groups

# Lane of step `i` for a pattern that starts on `base`.
func pattern_lane(kind: String, base: int, i: int, second: int) -> int:
	var top = SynkChart.MAX_LANE
	if kind == "alternate":
		var other = second if second != base else (base + 2 if base + 2 <= top else base - 2)
		return base if i % 2 == 0 else other
	if kind == "zigzag":
		# Three lanes out and back: 0 1 2 3 2 1 0 ..., toward whichever side has the room.
		var along = i % 6
		var offset = along if along <= 3 else 6 - along
		return base + offset if base + 3 <= top else base - offset
	# Stairs run to the edge of the highway and come back.
	var walk = posmod(base + (i if kind == "up" else -i), top * 2)
	return walk if walk <= top else top * 2 - walk

func apply_pattern(kind: String) -> void:
	var groups = stagger_groups()
	if groups.is_empty(): cancel_copy(); return
	var lowest = func(group: Array) -> int:
		var low = SynkChart.MAX_LANE
		for note in group: low = mini(low, int(note.lane))
		return low
	var base: int = lowest.call(groups[0])
	var second: int = lowest.call(groups[1]) if groups.size() > 1 else base
	var in_document = false
	for note in stagger_notes:
		if game.document.notes.any(func(other): return is_same(other, note)): in_document = true
	if in_document: game.document.checkpoint()
	for i in groups.size():
		var change = pattern_lane(kind, base, i, second) - int(lowest.call(groups[i]))
		for note in groups[i]:
			# Keep every note of a chord on the highway.
			var shift = clampi(change, -int(note.lane), SynkChart.MAX_LANE - int(note.lane))
			note.lane = int(note.lane) + shift
			note.end_lane = clampi(int(note.end_lane) + shift, 0, SynkChart.MAX_LANE)
			for point in note.get("path", []): point.lane = clampf(float(point.lane) + shift, 0, SynkChart.MAX_LANE)
	if in_document: game.document.dirty = true
	var count = stagger_notes.size()
	copy_stage = ""; stagger_notes = []
	game.commit_take_history()
	if game.overlap_tools: game.overlap_tools.refresh()
	game.refresh_arrange_controls()
	game.tell("%d note%s laid out as %s." % [count, "" if count == 1 else "s", {"up": "stairs up", "down": "stairs down", "zigzag": "a zigzag", "alternate": "alternating lanes"}[kind]])

func mark_start() -> void:
	copy_start = here(); copy_stage = "end"; game.refresh_arrange_controls()

func mark_end() -> void:
	var from = minf(copy_start, here()); var to = maxf(copy_start, here())
	if to - from < .05: game.tell("Scroll to the end of the part first."); return
	if mark_purpose == "stagger":
		stagger_notes = []
		for note in game.capture.notes + game.document.notes:
			if float(note.time) >= from - .001 and float(note.time) <= to + .001 and game.recorder.writable(note): stagger_notes.append(note)
		if stagger_notes.size() < 2: stagger_notes = []; game.tell("Mark a part with at least two notes to stagger."); return
		stagger_notes.sort_custom(func(a, b): return float(a.time) < float(b.time))
		copy_start = from; copy_stage = "pattern"
		game.refresh_arrange_controls(); return
	var found: Array = []
	for note in game.capture.notes + game.document.notes:
		if float(note.time) >= from - .001 and float(note.time) <= to + .001:
			var copy: Dictionary = note.duplicate(true); copy.time = float(note.time) - from; found.append(copy)
	if found.is_empty(): game.tell("There are no notes between %.2f and %.2f s." % [from, to]); return
	found.sort_custom(func(a, b): return float(a.time) < float(b.time))
	clipboard = found; clipboard_span = to - from; copy_start = from; copy_stage = ""
	game.refresh_arrange_controls()
	game.tell("Copied %d note%s. Scroll to a new place and tap Paste here." % [found.size(), "" if found.size() == 1 else "s"])

# One step of the recorder's grid (its subdivision of the beat).
func grid_step() -> float:
	return 60.0 / maxf(1.0, float(game.chart_bpm())) / maxf(1.0, float(game.recorder.division))

func paste_here() -> void:
	if clipboard.is_empty(): return
	var step = grid_step()
	var shift = roundf((here() - copy_start) / step) * step
	var at = copy_start + shift
	var copies: Array = []
	var locks = game.recorder.locks()
	for source in clipboard:
		if source.kind in locks: continue
		var note: Dictionary = source.duplicate(true); note.time = float(source.time) + at
		if float(note.time) < 0 or float(note.time) + float(note.duration) > game.length() + .001:
			game.tell("The copied part doesn't fit before the end of the song."); return
		copies.append(note)
	if copies.is_empty(): game.tell("Those note types are locked."); return
	game.space_authored_notes(copies, game.capture.notes + game.document.notes)
	game.capture.notes.append_array(copies)
	game.capture.notes.sort_custom(func(a, b): return float(a.time) < float(b.time))
	game.commit_take_history()
	if game.overlap_tools: game.overlap_tools.refresh()
	game.refresh_arrange_controls()
	game.tell("Pasted %d note%s at %.2f s." % [copies.size(), "" if copies.size() == 1 else "s", at])

# The help line while copying, or "" when not copying.
func copy_help() -> String:
	if copy_stage == "pattern": return "%d notes marked. Choose a pattern; their timing stays as recorded." % stagger_notes.size()
	if copy_stage == "start": return "Scroll so the start of the part is on the line, then tap Start here."
	if copy_stage == "end": return "Start at %.2f s. Scroll to the end of the part, then tap End here." % copy_start
	return ""

func refresh() -> void:
	buttons.undo.disabled = game.take_undo.is_empty()
	buttons.redo.disabled = game.take_redo.is_empty()
	buttons.aids.set_selected(game.aids_drawer.visible)
	buttons.step.set_selected(game.step_entry)
	var tools = game.overlap_tools
	var n = tools.groups.size()
	buttons.overlaps.text = "%d overlap%s" % [n, "" if n == 1 else "s"]
	buttons.overlaps.set_selected(tools.open)
	var note = selected_note()
	if note.is_empty(): return
	var locks = game.recorder.locks()
	var pass_name = game.recorder.current_pass()
	for kind in KINDS:
		buttons[kind].set_selected(note.kind == kind)
		buttons[kind].disabled = note.kind in locks or kind in locks or (pass_name != "all" and kind != pass_name)
	var arranger = game.note_arranger
	for key in MODES:
		buttons[key].set_selected(game.dots_mode if key == "points" else (not game.dots_mode and arranger.edit_mode == key))
	buttons.more.set_selected(arranger.expanded)
	buttons.letter.disabled = "slide" in locks or note.kind in locks
	buttons.delete.disabled = note.kind in locks
