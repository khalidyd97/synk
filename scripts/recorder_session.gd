extends Node

const Motion = preload("res://scripts/ui_motion.gd")
const Action = preload("res://scripts/recorder_action.gd")
const Audit = preload("res://scripts/chart_audit.gd")
const Icons = preload("res://scripts/ui_icons.gd")
# Solid sheet and inner cards for recorder dialogs (readable over the chart editor).
const SHEET = Color("17181b")
const CARD = Color("212226")
static func sheet_title(label: Label) -> void:
	label.add_theme_font_override("font", preload("res://scripts/arcade_style.gd").SERIF)
	label.add_theme_color_override("font_color", Color("f4f1ea"))
var progress: ProgressBar
var game: Control
var region = Vector2.ZERO
var use_range = false
var replace = false
var loop_takes = false
var pre_roll = 0

var resume_lead = 2
var quantize = "free"
var division = 4
var pass_kind = "all"
var locked: Array = []
var takes: Array = []
var baseline: Array = []
var active = false
var continuing = false
var provisional = false
var bank_key = ""
var review: Control
var setup: Control
var take_picker: OptionButton
var compare_label: Label
var headline_label: Label
var warnings_label: Label
var highlights: Dictionary = {}
var selected_take = 0
var reviewing_audio = false
var review_panel: Control
var review_dim: ColorRect
var replay_return: Button
var auto_round = false
var pending_warnings: Array = []
var review_notes: Array = []
var config: Dictionary = {}

func _ready() -> void :
	pre_roll = clampi(int(game.prefs.get_value("recorder", "pre_roll", 0)), 0, 4)
	resume_lead = clampi(int(game.prefs.get_value("recorder", "resume_lead", 2)), 1, 3)
	quantize = str(game.prefs.get_value("recorder", "quantize", "free"))
	if quantize not in ["free", "soft", "strict"]: quantize = "free"
	division = clampi(int(game.prefs.get_value("recorder", "division", 4)), 1, 8)

func key() -> String: return str(game.song.id) + ":" + game.features.current_variant
func locks() -> Array: return config.get("locked", locked)
func current_pass() -> String: return str(config.get("pass", pass_kind))
func looping() -> bool: return bool(config.get("loop", loop_takes))
func writable(n: Dictionary) -> bool:
	return n.kind not in locks() and (current_pass() == "all" or n.kind == current_pass())
func can_capture(at: float) -> bool: return active and at >= region.x and at < region.y
func allowed_types() -> Array:
	if current_pass()!="all":return [current_pass()] if current_pass() not in locks() else []
	return game.record_types.filter(func(kind):return kind not in locks())
func capture_tool() -> String:
	var allowed=allowed_types()
	return str(allowed[0]) if allowed.size()==1 else "auto"

func begin() -> void :
	close_review()
	if setup: setup.queue_free();setup = null
	if not continuing or bank_key != key():
		config = {"locked": locked.duplicate(), "pass": pass_kind, "loop": loop_takes, "replace": replace, "pre_roll": pre_roll, "quantize": quantize, "division": division}
		takes.clear();highlights.clear();provisional = false
		baseline = game.document.notes.duplicate(true)
		var start = clampf(game.cursor, 0, maxf(0, game.length() - 0.02))
		region = Vector2(start, game.length())
		if use_range and game.timeline and game.timeline.range_active:
			region = Vector2(game.timeline.range_start, game.timeline.range_end)
		elif use_range and game.loop_b > game.loop_a + 0.05:
			region = Vector2(game.loop_a, game.loop_b)
		region.x = clampf(region.x, 0, maxf(0, game.length() - 0.02))
		region.y = clampf(region.y, region.x + 0.01, game.length())
		bank_key = key()
	continuing = false;active = true;auto_round = false
	game.start_position = maxf(0, region.x - int(config.pre_roll) * 4 * 60.0 / game.chart_bpm())
	game.song_time = game.start_position - game.countdown
	game.tool = capture_tool()

func seal_gestures() -> void :
	for id in game.capture.gestures.keys():
		var g: Dictionary = game.capture.gestures[id]
		game.capture.end(id, minf(game.song_time, region.y), g.position)

func snap_time(at: float) -> float:
	var step = 60.0 / game.chart_bpm() / int(config.get("division", division))
	return game.chart_offset() + roundf((at - game.chart_offset()) / step) * step

func spacing_blockers() -> Array:
	var result: Array = []
	for note in game.document.notes:
		if bool(config.get("replace", replace)) and writable(note) and float(note.time) >= region.x and float(note.time) < region.y: continue
		result.append(note)
	return result

func prepare(source: Array) -> Array:
	var result: Array = []
	for original in source:
		if not writable(original) or float(original.time) < region.x or float(original.time) >= region.y: continue
		var n: Dictionary = original.duplicate(true)
		var old_duration = float(n.duration)
		var old_end = float(n.time) + old_duration
		var timing = str(config.get("quantize", quantize))
		var strength = 0.0 if timing == "free" else (0.5 if timing == "soft" else 1.0)
		n.time = clampf(lerpf(float(n.time), snap_time(float(n.time)), strength), region.x, region.y - 0.001)
		if n.kind in ["hold", "slide"]:
			var new_end = clampf(lerpf(old_end, snap_time(old_end), strength), float(n.time) + 0.001, region.y)
			n.duration = new_end - float(n.time)
			if n.duration < 0.04: continue
			var ratio = float(n.duration) / maxf(0.001, old_duration)
			for point in n.path: point.offset = float(point.offset) * ratio
			if n.has("checkpoints"):
				for i in n.checkpoints.size(): n.checkpoints[i] = float(n.checkpoints[i]) * ratio
		result.append(n)
	result.sort_custom( func(a, b): return float(a.time) < float(b.time))
	game.space_authored_notes(result, spacing_blockers())
	return result

func merged(notes: Array) -> Array:
	var result: Array = []
	for n in baseline:
		if not notes.is_empty() and bool(config.get("replace", replace)) and writable(n) and float(n.time) >= region.x and float(n.time) < region.y: continue
		result.append(n.duplicate(true))
	result.append_array(notes.duplicate(true))
	result.sort_custom( func(a, b): return float(a.time) < float(b.time))
	return result

func finish() -> bool:
	if not active: return false
	seal_gestures();active = false
	var notes = prepare(game.capture.notes)
	takes.append({"notes": notes, "raw": game.capture.notes.duplicate(true)})
	selected_take = takes.size() - 1
	if looping() and auto_round and takes.size() < 32:
		continuing = true
		game.record_here()
		return true

	baseline = game.document.notes.duplicate(true)
	return false

func apply_take(notes: Array) -> void :
	review_notes = notes.duplicate(true)
	if notes.is_empty() and not provisional:
		pending_warnings = quality(game.document.notes);return
	if not provisional:
		game.document.checkpoint();provisional = true
	game.document.notes = merged(notes);game.document.selected = -1;game.document.dirty = true
	highlights.clear()
	for n in notes: highlights[JSON.stringify(n)] = true
	pending_warnings = quality(game.document.notes)
	game.features.autosave();game.refresh_editor()

func quality(notes: Array) -> Array:
	var result = Audit.inspect(notes, game.length())
	var ordered = notes.duplicate();ordered.sort_custom( func(a, b): return float(a.time) < float(b.time))
	for i in ordered.size():
		var n: Dictionary = ordered[i]
		if n.kind in ["hold", "slide"] and float(n.duration) < 0.12:
			result.append({"time": n.time, "message": "Very short sustained note; check for an accidental hold"})
		for j in range(i + 1, mini(i + 12, ordered.size())):
			var other: Dictionary = ordered[j]
			if float(other.time) - float(n.time) > 0.075: break
			if n.lane == other.lane:
				result.append({"time": other.time, "message": "Possible accidental double tap in lane %d" % (int(n.lane) + 1)});break
		if result.size() >= 250: break
	return result

func comparison(before: Array, after: Array) -> Dictionary:
	var used: Dictionary = {}; var added = 0; var shifted = 0; var total = 0.0
	for n in after:
		var best = -1; var distance = 0.251
		for i in before.size():
			var previous: Dictionary = before[i]
			if used.has(i) or n.lane != previous.lane or n.kind != previous.kind: continue
			var delta = absf(float(n.time) - float(previous.time))
			if delta < distance: best = i;distance = delta
		if best < 0: added += 1
		else:
			used[best] = true
			if distance > 0.002: shifted += 1;total += distance
	return {"added": added, "removed": before.size() - used.size(), "shifted": shifted, "ms": total * 1000 / maxi(1, shifted)}

func select_take(index: int) -> void :
	selected_take = index
	apply_take(takes[index].notes)
	update_review()

func combine(first: int, second: int, split: float) -> Array:
	var result: Array = []
	for n in takes[first].notes:
		if float(n.time) < split: result.append(n.duplicate(true))
	for n in takes[second].notes:
		if float(n.time) >= split: result.append(n.duplicate(true))

	for n in result:
		if float(n.time) < split and float(n.time) + float(n.duration) > split:
			n.duration = split - float(n.time)
			if n.kind == "slide":
				var end = SynkChart.lane_at(n, split)
				n.path = n.path.filter( func(p): return float(p.offset) < float(n.duration))
				n.end_lane = clampi(roundi(end), 0, SynkChart.MAX_LANE)
				n.path.append({"offset": float(n.duration), "lane": float(n.end_lane)})
			if n.has("checkpoints"): n.checkpoints = n.checkpoints.filter( func(t): return float(t) < float(n.duration))
	return result

func undo_take() -> void :
	if provisional and bank_key == key():
		game.document.undo();provisional = false;game.features.draft_hash = 0;game.features.autosave();game.refresh_editor()
	highlights.clear()

func retry() -> void :
	undo_take();close_review()
	continuing = true;game.cursor = region.x;game.record_here()

func close_review() -> void :
	if reviewing_audio: game.stop_audition();reviewing_audio = false
	if review: review.queue_free();review = null
	review_panel = null;review_dim = null;replay_return = null

func keep() -> void :
	close_review();provisional = false;highlights.clear();game.refresh_editor()
	game.tell("Take kept.")

func preview() -> void :
	if reviewing_audio: stop_preview();return
	game.stop_audition();game.cursor = maxf(0, region.x - 0.3)
	game.audio.pitch_scale = game.audition_speed;game.audio.play(game.cursor)
	reviewing_audio = true
	if review_panel: review_panel.visible = false
	if review_dim: review_dim.color.a = 0
	if replay_return: replay_return.visible = true

func stop_preview() -> void :
	game.stop_audition();reviewing_audio = false
	if review_panel: review_panel.visible = true
	if review_dim: review_dim.color.a = 0.55
	if replay_return: replay_return.visible = false

func _process(_delta: float) -> void :
	if progress and game.mode == "record":
		progress.value = clampf((game.song_time - region.x) / maxf(0.001, region.y - region.x) * 100, 0, 100)
	if active and game.mode == "record" and not game.arranging and game.countdown == 0 and game.resume_countdown == 0 and game.song_time >= region.y:
		auto_round = true;game.stop_take()
	if reviewing_audio and (game.mode != "editor" or game.chart_time() >= region.y or not game.audio.playing):
		stop_preview()

func text(parent: Node, value: String, font_size: int = 18) -> Label:
	var label = Label.new();parent.add_child(label);label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
func button(parent: Node, title: String, callback: Callable, role: String = "tool") -> Button:
	var b = Action.new();b.text = title;b.variant = role;b.caption_size = 21;b.custom_minimum_size = Vector2(0, 60)
	parent.add_child(b);b.pressed.connect(callback);return b
func choice(parent: Node, title: String, items: Array, current: int, callback: Callable) -> OptionButton:
	text(parent, title, 16)
	var picker = OptionButton.new();parent.add_child(picker);picker.custom_minimum_size.y = 56
	picker.add_theme_font_size_override("font_size", 20)
	picker.get_popup().add_theme_font_size_override("font_size", 20)
	picker.get_popup().add_theme_constant_override("v_separation", 16)
	for item in items: picker.add_item(str(item))
	picker.select(clampi(current, 0, items.size() - 1));picker.item_selected.connect(callback);return picker
func number(parent: Node, title: String, value: float, low: float, high: float, step: float, callback: Callable) -> SpinBox:
	text(parent, title, 16)
	var spinner = SpinBox.new();parent.add_child(spinner);spinner.min_value = low;spinner.max_value = high;spinner.step = step;spinner.value = value;spinner.custom_minimum_size.y = 56
	spinner.add_theme_font_size_override("font_size", 20)
	spinner.value_changed.connect(callback);return spinner
func toggle(parent: Node, title: String, value: bool, callback: Callable) -> void :
	var b = button(parent, title + (" · ON" if value else " · OFF"), func(): pass)
	b.toggle_mode = true;b.button_pressed = value;b.set_selected(value)
	b.toggled.connect( func(on): b.text = title + (" · ON" if on else " · OFF");b.set_selected(on);callback.call(on))
func shell(title: String, narrow: bool = false) -> Dictionary:
	if game.toast_layer: game.toast_layer.clear()
	var root = Control.new();game.ui.add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The app's menu look: Inter Tight, sentence-case captions, frosted controls.
	root.theme = preload("res://scripts/game_theme.gd").arcade()
	preload("res://scripts/modal_input.gd").register(root)
	var dim = ColorRect.new();root.add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color = Color(0.0, 0.0, 0.0, 0.74)
	var safe_content = game.safe_parent("SafeDialogControls", root)
	var panel = Panel.new();game.rect(panel, safe_content, 0.55 if narrow else 0.14, 0.05, 0.98 if narrow else 0.86, 0.95)
	var style = StyleBoxFlat.new();style.bg_color = Color(0.035, 0.035, 0.035, 0.96);style.border_color = Color(1, 1, 1, 0.1);style.set_border_width_all(1)
	style.set_corner_radius_all(26);style.shadow_color = Color(0, 0, 0, 0.5);style.shadow_size = 24;panel.add_theme_stylebox_override("panel", style)
	panel.set_meta("keep_caption_size", true)
	style.bg_color = SHEET; style.border_color = Color(1, 1, 1, 0.07)
	sheet_title(game.label(panel, title, 0.04, 0.015, 0.76, 0.11, 40))
	var done = Action.new();done.text = "KEEP" if narrow else "DONE";done.variant = "primary";done.caption_size = 21
	game.rect(done, panel, 0.79, 0.025, 0.96, 0.1)
	done.pressed.connect( func():
		if narrow: keep()
		elif setup: setup.queue_free();setup = null)
	var scroll = ScrollContainer.new();scroll.name = "SetupScroll";game.rect(scroll, panel, 0.04, 0.13, 0.96, 0.97)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var drag = preload("res://scripts/song_list_scroll.gd").new()
	drag.name = "DragScroll";drag.scroll = scroll;scroll.add_child(drag)
	var box = VBoxContainer.new();scroll.add_child(box);box.size_flags_horizontal = Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation", 12)
	preload("res://scripts/interface_life.gd").mount(panel)
	Motion.pop(panel);return {"root": root, "box": box, "panel": panel, "dim": dim}
func persist(name: String, value: Variant) -> void :
	game.prefs.set_value("recorder", name, value);game.prefs.save("user://preferences.cfg")

func setup_group(parent: Node, title: String) -> VBoxContainer:
	var card = PanelContainer.new();parent.add_child(card)
	var plate = StyleBoxFlat.new();plate.bg_color = CARD;plate.set_corner_radius_all(18)
	for edge in ["left", "right", "top", "bottom"]: plate.set("content_margin_" + edge, 20)
	card.add_theme_stylebox_override("panel", plate)
	var contents = VBoxContainer.new();card.add_child(contents);contents.add_theme_constant_override("separation", 12)
	var heading = text(contents, Icons.menu_case(title), 17);heading.add_theme_color_override("font_color", Color("bcb7ad"))
	return contents

# --- Recording setup: one line per setting, the everyday ones first -----------------------
# A setting on one line: its name (and a short hint) on the left, its control on the right.
func setup_line(parent: Node, title: String, hint: String, control: Control, width: float = 330) -> void:
	var line = HBoxContainer.new();parent.add_child(line);line.add_theme_constant_override("separation", 18)
	var captions = VBoxContainer.new();line.add_child(captions);captions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	captions.size_flags_vertical = Control.SIZE_SHRINK_CENTER;captions.add_theme_constant_override("separation", 2)
	text(captions, title, 20)
	if hint != "": text(captions, hint, 15).add_theme_color_override("font_color", Color("9a968d"))
	line.add_child(control);control.custom_minimum_size = Vector2(width, 54);control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
func setup_choice(parent: Node, title: String, hint: String, items: Array, current: int, callback: Callable) -> OptionButton:
	var picker = OptionButton.new()
	picker.add_theme_font_size_override("font_size", 19);picker.get_popup().add_theme_font_size_override("font_size", 20)
	picker.get_popup().add_theme_constant_override("v_separation", 16)
	for item in items: picker.add_item(str(item))
	picker.select(clampi(current, 0, items.size() - 1));picker.item_selected.connect(callback)
	setup_line(parent, title, hint, picker);return picker
# An On / Off pill.
func setup_switch(parent: Node, title: String, hint: String, value: bool, callback: Callable) -> Button:
	var b = Action.new();b.text = "On" if value else "Off";b.variant = "secondary";b.caption_size = 19
	b.toggle_mode = true;b.button_pressed = value;b.set_selected(value)
	b.toggled.connect( func(on): b.text = "On" if on else "Off";b.set_selected(on);callback.call(on))
	setup_line(parent, title, hint, b, 130);return b

func setup_summary() -> String:
	var parts = ["Selected range" if use_range else "From the playhead"]
	parts.append({"free": "Free timing", "soft": "Soft snap", "strict": "Strict snap"}.get(quantize, "Free timing"))
	parts.append("No count-in" if pre_roll <= 0 else "%d bar count-in" % pre_roll)
	if replace: parts.append("Replaces notes")
	return " · ".join(parts)

func show_setup(global_only: bool = false) -> void :
	if setup: return
	if game.mode == "record": game.toggle_pause()
	if reviewing_audio: game.stop_audition();reviewing_audio = false
	var s = shell("Recording setup");setup = s.root; var box: VBoxContainer = s.box
	var main = setup_group(box, "RECORDER PREFERENCES" if global_only else "YOUR NEXT TAKE")
	if not global_only:
		setup_switch(main, "Record only the selected range", "Select a range in the editor, or set A and B.", use_range, func(on): use_range = on)
		setup_choice(main, "Notes already in that part", "", ["Keep them", "Replace them"], 1 if replace else 0, func(i): replace = i == 1)
	setup_choice(main, "Count-in", "Bars you hear before recording starts.", ["Off", "1 bar", "2 bars", "3 bars", "4 bars"], pre_roll, func(i): pre_roll = i;persist("pre_roll", i))
	setup_choice(main, "Timing", "How closely your notes are pulled to the grid.", ["Free", "Soft snap", "Strict snap"], ["free", "soft", "strict"].find(quantize), func(i): quantize = ["free", "soft", "strict"][i];persist("quantize", quantize))
	setup_choice(main, "Grid", "", ["Quarter notes", "Eighth notes", "Sixteenth notes", "Thirty-second notes"], [1, 2, 4, 8].find(division), func(i): division = [1, 2, 4, 8][i];persist("division", division))
	# Everything else stays folded away until asked for.
	var more = setup_group(box, "MORE OPTIONS");more.get_parent().visible = false
	var opener = button(box, "More options", func(): pass)
	opener.pressed.connect( func(): more.get_parent().visible = not more.get_parent().visible;opener.text = "Fewer options" if more.get_parent().visible else "More options")
	if not global_only:
		setup_switch(more, "Loop takes", "Record the part again and again, then pick the best take.", loop_takes, func(on): loop_takes = on)
		setup_choice(more, "Record one note type", "A pass that only listens for that type.", ["All types", "Taps only", "Holds only", "Slides only", "Flicks only"], ["all", "tap", "hold", "slide", "flick"].find(pass_kind), func(i): pass_kind = ["all", "tap", "hold", "slide", "flick"][i])
		var chips = HBoxContainer.new();chips.add_theme_constant_override("separation", 8)
		for kind in SynkChart.TYPES:
			var chip = Action.new();chip.text = str(kind).capitalize() + "s";chip.variant = "secondary";chip.caption_size = 17
			chip.toggle_mode = true;chip.button_pressed = kind in locked;chip.set_selected(kind in locked)
			chip.custom_minimum_size = Vector2(88, 50);chips.add_child(chip)
			chip.toggled.connect( func(on):
				chip.set_selected(on)
				if on and kind not in locked: locked.append(kind)
				elif not on: locked.erase(kind))
		setup_line(more, "Lock finished types", "Locked types can't be replaced or corrected.", chips, 376)
	setup_choice(more, "Lead-in after Correct", "Music you hear before recording resumes.", ["1 second", "2 seconds", "3 seconds"], resume_lead - 1, func(i): resume_lead = i + 1;persist("resume_lead", i + 1))
	setup_switch(more, "Rhythm guide", "A click on the beat, accented on the downbeat.", game.beat_clock.enabled, func(on):
		game.beat_clock.enabled = on;game.beat_clock.last_time = -1;game.prefs.set_value("editor", "metronome", on);game.prefs.save("user://preferences.cfg"))
	setup_choice(more, "Guide clicks on", "", ["Beats", "Eighths", "Sixteenths"], [1, 2, 4].find(game.beat_clock.subdivision), func(i): game.beat_clock.subdivision = [1, 2, 4][i];persist("guide_subdivision", game.beat_clock.subdivision))
	var volume = SpinBox.new();volume.min_value = -30;volume.max_value = 0;volume.step = 1;volume.value = game.beat_clock.guide_db;volume.suffix = "dB"
	volume.add_theme_font_size_override("font_size", 19)
	volume.value_changed.connect( func(v): game.beat_clock.guide_db = v;persist("guide_db", v))
	setup_line(more, "Guide volume", "", volume, 200)

func show_review() -> void :
	if takes.is_empty(): return
	close_review()
	if game.toast_layer: game.toast_layer.clear()
	game.seek_to(region.x)
	if game.timeline: game.timeline.reveal_time(region.x)
	review = Control.new();game.ui.add_child(review);review.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	review.theme = preload("res://scripts/game_theme.gd").arcade()
	preload("res://scripts/modal_input.gd").register(review)
	review_dim = ColorRect.new();review.add_child(review_dim);review_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	review_dim.color = Color(0.007, 0.007, 0.007, 0.72)
	var safe = game.safe_parent("SafeTakeReview", review)
	review_panel = Panel.new();game.rect(review_panel, safe, 0.1, 0.07, 0.9, 0.95);review_panel.set_meta("keep_caption_size", true)
	var plate = StyleBoxFlat.new();plate.bg_color = SHEET;plate.border_color = Color(1, 1, 1, 0.07)
	plate.set_border_width_all(1);plate.set_corner_radius_all(26);plate.shadow_color = Color(0, 0, 0, 0.5);plate.shadow_size = 24
	review_panel.add_theme_stylebox_override("panel", plate)
	sheet_title(game.label(review_panel, "Take review", 0.035, 0.015, 0.8, 0.105, 42))
	var where = game.label(review_panel, "%.2f–%.2f s  ·  %s  ·  %s" % [region.x, region.y, "Replace" if bool(config.get("replace", replace)) else "Layer", current_pass().capitalize()], 0.035, 0.105, 0.965, 0.16, 17)
	where.add_theme_color_override("font_color", Color("bcb7ad"))
	# One card: what the take did, any timing flags, and (with several takes) which one to keep.
	var card = review_column(review_panel, Rect2(0.035, 0.19, 0.93, 0.545), "THIS TAKE")
	headline_label = text(card, "", 30)
	compare_label = text(card, "", 20)
	warnings_label = text(card, "", 17);warnings_label.add_theme_color_override("font_color", Color("bcb7ad"))
	var titles: Array = []
	for i in takes.size(): titles.append("Take %d · %d notes" % [i + 1, takes[i].notes.size()])
	take_picker = null
	if takes.size() > 1:
		take_picker = setup_choice(card, "Take to keep", "You recorded %d takes of this part." % takes.size(), titles, selected_take, select_take)
		# Splicing two takes is rare, so it stays folded away.
		var splice = VBoxContainer.new();splice.add_theme_constant_override("separation", 12);splice.visible = false
		var opener = button(card, "Combine two takes", func(): pass)
		opener.pressed.connect( func(): splice.visible = not splice.visible;opener.text = "Hide combine" if splice.visible else "Combine two takes")
		card.add_child(splice)
		var first = setup_choice(splice, "First part from", "", titles, 0, func(_i): pass)
		var second = setup_choice(splice, "Second part from", "", titles, selected_take, func(_i): pass)
		var split = SpinBox.new();split.min_value = region.x;split.max_value = region.y;split.step = 0.001;split.value = (region.x + region.y) * 0.5;split.suffix = "s"
		split.add_theme_font_size_override("font_size", 19)
		setup_line(splice, "Switch takes at", "Song time where the second take takes over.", split, 200)
		button(splice, "Apply combined take", func():
			var combined = combine(first.selected, second.selected, split.value)
			apply_take(combined);update_review();compare_label.text = "COMBINED · %d notes\n" % combined.size() + compare_label.text)
	game.label(review_panel, "Keep take adds it to your draft only. Keep and save also saves the chart.", 0.035, 0.755, 0.965, 0.8, 17).add_theme_color_override("font_color", Color("bcb7ad"))
	# Keep is the main action; the others are quieter, and discarding sits apart on the left.
	review_action("DISCARD TAKE", 0.035, 0.175, func(): undo_take();close_review();game.tell("Take discarded."), "danger")
	review_action("RECORD AGAIN", 0.29, 0.445, retry, "secondary")
	review_action("LISTEN BACK", 0.455, 0.61, preview, "secondary")
	review_action("KEEP TAKE", 0.62, 0.765, keep, "secondary")
	# Keeps the take and saves the chart in one step, so the save is not forgotten.
	review_action("KEEP AND SAVE", 0.775, 0.965, func(): keep();game.save_editor(), "primary")
	replay_return = Action.new();replay_return.text = "BACK TO TAKE REVIEW";replay_return.variant = "primary";replay_return.caption_size = 21
	# Solid, and wide enough to cover Chart tools, Record and Setup behind it while listening back.
	game.rect(replay_return, safe, 0.315, 0.012, 0.645, 0.085);replay_return.pressed.connect(stop_preview);replay_return.visible = false
	preload("res://scripts/interface_life.gd").mount(review_panel)
	Motion.pop(review_panel)
	update_review()

func review_action(title: String, left: float, right: float, callback: Callable, role: String) -> void :
	var action = Action.new();action.text = title;action.variant = role;action.caption_size = 21
	game.rect(action, review_panel, left, 0.84, right, 0.955);action.pressed.connect(callback)

func review_column(parent: Control, bounds: Rect2, title: String) -> VBoxContainer:
	var panel = Panel.new();game.rect(panel, parent, bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y)
	var plate = StyleBoxFlat.new();plate.bg_color = CARD
	plate.set_corner_radius_all(18);panel.add_theme_stylebox_override("panel", plate)
	var scroll = ScrollContainer.new();game.rect(scroll, panel, 0.045, 0.04, 0.955, 0.96);scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var drag = preload("res://scripts/song_list_scroll.gd").new();drag.scroll = scroll;scroll.add_child(drag)
	var box = VBoxContainer.new();scroll.add_child(box);box.size_flags_horizontal = Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation", 16)
	var heading = text(box, Icons.menu_case(title), 17);heading.add_theme_color_override("font_color", Color("bcb7ad"))
	return box

func update_review() -> void :
	if not review: return
	var selected: Array = review_notes
	var replacing = bool(config.get("replace", replace))
	if headline_label: headline_label.text = "No notes recorded" if selected.is_empty() else "%d note%s recorded" % [selected.size(), "" if selected.size() == 1 else "s"]
	# Against the chart, only notes this take replaces can count as removed or moved; a layered take adds to them.
	var prior: Array = takes[selected_take - 1].notes if selected_take > 0 else (baseline.filter( func(n): return writable(n) and float(n.time) >= region.x and float(n.time) < region.y) if replacing else [])
	var diff = comparison(prior, selected)
	compare_label.text = "Compared with %s\n+%d added · −%d removed\n%d moved · %.1f ms average shift" % ["previous take" if selected_take > 0 else "existing section", diff.added, diff.removed, diff.shifted, diff.ms]
	if selected_take == 0 and not replacing: compare_label.text = "Layered on the existing section\n+%d added · existing notes kept" % diff.added
	if selected.is_empty(): compare_label.text = "EMPTY TAKE · Existing chart kept unchanged."
	var lines = PackedStringArray()
	for issue in pending_warnings.slice(0, 8): lines.append("%.2f s · %s" % [float(issue.time), str(issue.message)])
	warnings_label.text = "Quality check · " + ("No issues found" if pending_warnings.is_empty() else "%d flags\n" % pending_warnings.size() + "\n".join(lines))
	if pending_warnings.size() > 8: warnings_label.text += "\nMore flags available in Chart Tools → Validate."
