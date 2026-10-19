extends Control
# Version history of one chart level: every save as v1, v2, ... newest first. SWITCH makes
# any version the live chart for that level (the previous live chart is kept as a version).
const Action = preload("res://scripts/settings_action.gd")
const UiMotion = preload("res://scripts/ui_motion.gd")
const BOLD = preload("res://assets/fonts/FiraSans-Bold.ttf")
const CYAN = Color("50daec")
const MUTED = Color("a7aac6")

var game: Control
var song_id = ""
var level = "original"
var canvas: Control
var list: VBoxContainer
var heading: Label
var empty: Label

func style(fill: Color, edge: Color, radius: int) -> StyleBoxFlat:
	var box = StyleBoxFlat.new(); box.bg_color = fill; box.border_color = edge; box.set_corner_radius_all(radius); box.set_border_width_all(1); return box
func label(parent: Control, value: String, x: float, y: float, w: float, h: float, font_size: int, tint: Color = Color("f5f3ff")) -> Label:
	var n = Label.new(); parent.add_child(n); n.position = Vector2(x, y); n.size = Vector2(w, h); n.text = value
	n.add_theme_font_size_override("font_size", font_size); n.add_theme_color_override("font_color", tint)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return n
func action(parent: Control, value: String, callback: Callable, primary: bool = false) -> Button:
	var n = Action.new(); n.text = value; n.primary = primary; n.caption_size = 18; parent.add_child(n)
	n.pressed.connect(func(): if not Action.was_dragged(n): callback.call())
	return n

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim = ColorRect.new(); add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.color = Color(0.006,0.006,0.006,.78)
	canvas = Control.new(); add_child(canvas); canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(layout); layout()
	var card = Panel.new(); canvas.add_child(card); card.position = Vector2(258, 70); card.size = Vector2(940, 680)
	card.add_theme_stylebox_override("panel", style(Color(0.041,0.041,0.041,.97), Color("2b263b"), 26))
	var eyebrow = label(card, " ".join("VERSION HISTORY".split("")), 36, 24, 600, 24, 14, CYAN)
	heading = label(card, "", 36, 50, 700, 52, 34); heading.add_theme_font_override("font", BOLD)
	label(card, "Every save is kept. Switch makes a version the live chart; the current one stays in this list.", 36, 102, 860, 28, 17, MUTED)
	var close = action(card, "CLOSE", func(): close_view()); close.position = Vector2(764, 30); close.size = Vector2(140, 62)
	var scroll = ScrollContainer.new(); card.add_child(scroll); scroll.position = Vector2(36, 146); scroll.size = Vector2(868, 506)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var drag = preload("res://scripts/song_list_scroll.gd").new(); drag.scroll = scroll; scroll.add_child(drag)
	list = VBoxContainer.new(); scroll.add_child(list); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	empty = label(card, "No saved versions yet. Each SAVE in Chart Studio adds one.", 36, 300, 868, 60, 20, MUTED)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	refresh()
	UiMotion.pop(card)

func layout() -> void:
	if not canvas: return
	var k = maxf(.1, minf(size.x / 1456.0, size.y / 819.0))
	canvas.scale = Vector2.ONE * k; canvas.size = Vector2(1456, 819); canvas.position = (size - Vector2(1456, 819) * k) * .5

func refresh() -> void:
	var entry: Dictionary = game.song_details_entry(song_id)
	heading.text = preload("res://scripts/lobby.gd").display_title(str(entry.get("title", "Chart"))) + "  ·  " + level.capitalize()
	for child in list.get_children(): child.queue_free()
	var versions = SynkChartVersions.list(song_id, level)
	var live = SynkChartVersions.current_number(song_id, level)
	empty.visible = versions.is_empty()
	for version in versions: list.add_child(row(version, int(version.number) == live))

func row(version: Dictionary, is_live: bool) -> Control:
	var panel = PanelContainer.new(); panel.custom_minimum_size = Vector2(0, 92)
	panel.add_theme_stylebox_override("panel", style(Color("103043") if is_live else Color("101010"), CYAN if is_live else Color("2c2d44"), 18))
	var holder = Control.new(); panel.add_child(holder); holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number = label(holder, "v%d" % int(version.number), 22, 0, 90, 92, 30); number.add_theme_font_override("font", BOLD)
	var when = str(version.saved_at).replace("T", "  ·  ").left(20)
	label(holder, "%d notes   ·   %s" % [int(version.notes), when], 120, 14, 520, 34, 20)
	label(holder, str(version.note) if not str(version.note).is_empty() else "Saved from Chart Studio", 120, 46, 520, 30, 16, MUTED)
	if is_live:
		label(holder, "LIVE", 724, 0, 120, 92, 18, CYAN).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var path = str(version.path)
		var b = action(holder, "SWITCH", func(): switch(path, int(version.number)), true); b.position = Vector2(690, 14); b.size = Vector2(150, 64)
	return panel

func switch(path: String, number: int) -> void:
	var loaded = str(game.song.id) == song_id and game.features.current_variant == level
	if loaded and game.document.dirty: game.features.autosave()
	if SynkChartVersions.switch_to(song_id, level, path) != OK:
		game.tell("Could not switch versions. Check storage."); return
	if loaded:
		game.document.dirty = false; game.features.load_variant()
	if level == "original" and game.song_metadata.has(song_id):
		var notes: Array = game.library.load_chart(song_id)
		game.song_metadata[song_id].notes = notes; game.song_metadata[song_id].note_count = notes.size(); game.song_metadata[song_id].has_chart = true
	game.chart_library.cache.clear(); game.chart_library.refresh(); game.lobby.refresh()
	game.tell("Switched %s to v%d. The previous chart is kept in history." % [level.capitalize(), number])
	refresh()

func close_view() -> void:
	queue_free()
