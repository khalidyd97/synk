extends Control
# Correct mode's one toolbar, along the bottom. It changes with what is selected:
#   nothing     → Undo · Redo · Type text · overlaps (only when there are some) · Aids
#   a note      → Undo · Redo · Tap Hold Slide Flick · [hold/slide: Move Bend Draw Connector
#                 More Letter] · overlaps · Delete
# Every button calls the recorder's existing actions; this file only decides what shows.

const ACTION = preload("res://scripts/recorder_action.gd")
const A = preload("res://scripts/arcade_style.gd")
var game: Control
var plate: Panel
var buttons: Dictionary = {}
var layout_key = ""
const KINDS = ["tap", "hold", "slide", "flick"]
const MODES = {"move": "Move", "shape": "Bend", "draw": "Draw", "points": "Connector"}
# Bar placement (fractions of the screen) and the room between groups.
const TOP = .842
const BOTTOM = .918
const GROUP_GAP = .012

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate = Panel.new(); add_child(plate); plate.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new(); style.bg_color = Color(.05, .05, .06, .92)
	style.border_color = Color(1, 1, 1, .07); style.set_border_width_all(1); style.set_corner_radius_all(22)
	style.shadow_color = Color(0, 0, 0, .45); style.shadow_size = 16
	plate.add_theme_stylebox_override("panel", style)
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
	add("copy", "Copy part", begin_copy)
	add("start", "Start here", mark_start)
	add("end", "End here", mark_end)
	add("paste", "Paste here", paste_here)
	add("cancel", "Cancel", cancel_copy)
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
	if copy_stage != "":
		keys.append("start" if copy_stage == "start" else "end")
		keys.append_array(["|", "cancel"])
		return keys
	if note.is_empty():
		keys.append("text")
		keys.append_array(["|", "copy"])
		if not clipboard.is_empty(): keys.append("paste")
		if overlaps: keys.append_array(["|", "overlaps"])
		keys.append_array(["|", "aids"])
		return keys
	keys.append_array(KINDS)
	if note.kind in ["hold", "slide"]:
		keys.append("|"); keys.append_array(MODES.keys()); keys.append_array(["more", "|", "letter"])
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
	var count = keys.filter(func(k): return k != "|").size()
	var gaps = keys.size() - count
	# Buttons are as wide as the room allows, up to a comfortable pill.
	var unit = minf(.082, (.9 - gaps * GROUP_GAP) / maxf(1, count))
	var total = unit * count + gaps * GROUP_GAP
	var x = .5 - total * .5
	for k in keys:
		if k == "|": x += GROUP_GAP; continue
		var b: Control = buttons[k]; b.visible = true
		b.anchor_left = x + .003; b.anchor_right = x + unit - .003; b.anchor_top = TOP + .012; b.anchor_bottom = BOTTOM - .012
		b.offset_left = 0; b.offset_right = 0; b.offset_top = 0; b.offset_bottom = 0
		x += unit
	plate.anchor_left = .5 - total * .5 - .008; plate.anchor_right = .5 + total * .5 + .008
	plate.anchor_top = TOP; plate.anchor_bottom = BOTTOM
	plate.offset_left = 0; plate.offset_right = 0; plate.offset_top = 0; plate.offset_bottom = 0

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
	copy_stage = "start"; game.refresh_arrange_controls()

func cancel_copy() -> void:
	copy_stage = ""; game.refresh_arrange_controls()

func mark_start() -> void:
	copy_start = here(); copy_stage = "end"; game.refresh_arrange_controls()

func mark_end() -> void:
	var from = minf(copy_start, here()); var to = maxf(copy_start, here())
	if to - from < .05: game.tell("Scroll to the end of the part first."); return
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
	if copy_stage == "start": return "Scroll so the start of the part is on the line, then tap Start here."
	if copy_stage == "end": return "Start at %.2f s. Scroll to the end of the part, then tap End here." % copy_start
	return ""

func refresh() -> void:
	buttons.undo.disabled = game.take_undo.is_empty()
	buttons.redo.disabled = game.take_redo.is_empty()
	buttons.aids.set_selected(game.aids_drawer.visible)
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
