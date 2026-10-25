extends Control
const ScreenStyle = preload("res://scripts/screen_style.gd")
const Action = preload("res://scripts/settings_action.gd")
const Levels = preload("res://scripts/chart_levels.gd")
const SsrgImport = preload("res://scripts/ssrg_import.gd")
const BACKGROUND = preload("res://assets/lobby/city_background.png")
const TEXT = Color("eef0ff")
const MUTED = Color(.8,.82,.95,.6)
const ACCENT = Color("ffd36a")
const KEY_COLORS = {4: Color("5fd0ff"), 7: Color("ffd36a"), 13: Color("ff7ac8")}

# SSRG Playables (lobby button). The player picks the files of an SSRG song from their own copy
# of the game: the song audio (.bytes, really Ogg) and its 4, 7 and 13 key charts (.bytes).
# Importing adds the song to the library with one chart per key count (saved as Lv 4, Lv 7 and
# Lv 13). Nothing from SSRG ships with SYNK.
#   left:  searchable song list with cover, key chips and best rank
#   right: the selected song - banner, one card per chart (notes, density, best score),
#          PLAY / AUTO PLAY, gameplay background and delete
#   IMPORT opens the import panel; the SSRG STAGE switch plays these songs on the SSRG
#   highway style without changing the player's own highway setting.

var game: Control
var safe_content: Control
var picker: FileDialog
var image_picker: FileDialog
var staged_audio = ""
var staged_charts: Dictionary = {}
var staged_label: Label
var import_status: Label
var import_button: Button
var import_panel: Control
var status_label: Label
var search: LineEdit
var song_list: VBoxContainer
var detail: Control
var stage_button: Button
var selected_id = ""
var selected_variant = ""
var delete_armed = 0.0
var delete_button: Button
# Song whose row delete button was tapped once (a second tap within a few seconds deletes it).
var row_armed_id = ""
var pending: Dictionary = {}
# The run started from this screen: its best score is kept when the results appear.
var running: Dictionary = {}
var restore_style = ""

func place(node: Control, parent: Control, left: float, top: float, right: float, bottom: float) -> void:
	if parent==self and safe_content!=null: parent=safe_content
	parent.add_child(node)
	node.anchor_left = left; node.anchor_top = top; node.anchor_right = right; node.anchor_bottom = bottom
	node.offset_left = 0; node.offset_top = 0; node.offset_right = 0; node.offset_bottom = 0

func text(parent: Control, value: String, left: float, top: float, right: float, bottom: float, font_size: int, color: Color = TEXT) -> Label:
	var result = Label.new(); place(result,parent,left,top,right,bottom)
	result.text = value; result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func action(parent: Control, caption: String, left: float, top: float, right: float, bottom: float, callback: Callable, variant: String = "tool") -> Button:
	var result=Action.new(); result.text=caption; result.primary=variant=="primary"
	result.caption_size=16 if variant=="small" else (18 if variant=="tool" else 22)
	place(result,parent,left,top,right,bottom); result.pressed.connect(callback)
	return result

func box(fill: Color, edge: Color, radius: int = 22) -> StyleBoxFlat:
	var style = StyleBoxFlat.new(); style.bg_color = fill; style.set_corner_radius_all(radius)
	style.border_color = edge; style.set_border_width_all(1)
	return style

func panel(parent: Control, left: float, top: float, right: float, bottom: float, edge: Color = Color(ACCENT,.3)) -> Panel:
	var result = Panel.new(); place(result,parent,left,top,right,bottom)
	result.add_theme_stylebox_override("panel",box(Color(0.041,0.041,0.041,.86),edge))
	return result

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background = TextureRect.new(); place(background,self,0,0,1,1)
	background.texture = BACKGROUND; background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade = ColorRect.new(); place(shade,self,0,0,1,1); shade.color = Color(0.017,0.017,0.017,.86); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_content=game.safe_parent("SafeSsrgControls",self)
	action(self,"‹  BACK",.035,.035,.15,.14,close,"nav")
	text(self,"SSRG PLAYABLES",.17,.035,.5,.1,40)
	status_label = text(self,"Play SSRG songs from your own game files.",.17,.095,.6,.15,16,MUTED)
	stage_button = action(self,"",.6,.045,.78,.135,toggle_stage)
	action(self,"+  IMPORT SONG",.8,.045,.965,.135,open_import,"primary")
	ScreenStyle.rule(self,.035,.965,.165)

	# Song list
	var list_panel = panel(self,.035,.19,.4,.96)
	search = LineEdit.new(); place(search,list_panel,.05,.025,.95,.11)
	search.placeholder_text = "Search songs"; search.clear_button_enabled = true
	search.add_theme_font_size_override("font_size",17)
	for state in ["normal","focus"]:
		var field = box(Color(1,1,1,.05 if state=="normal" else .07),Color(1,1,1,.12) if state=="normal" else Color(ACCENT,.5),14)
		field.content_margin_left = 16; field.content_margin_right = 12
		search.add_theme_stylebox_override(state,field)
	search.text_changed.connect(func(_t): refresh_songs())
	var scroll = ScrollContainer.new(); place(scroll,list_panel,.04,.13,.96,.98)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	preload("res://scripts/drag_scroll.gd").attach(scroll)
	song_list = VBoxContainer.new(); scroll.add_child(song_list)
	song_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	song_list.add_theme_constant_override("separation",8)

	# Selected song
	detail = panel(self,.415,.19,.965,.96)

	build_import_panel()
	picker = FileDialog.new(); add_child(picker)
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILES; picker.access = FileDialog.ACCESS_FILESYSTEM; picker.use_native_dialog = true
	picker.filters = PackedStringArray(["*.bytes,*.ogg;SSRG files;*/*"])
	picker.files_selected.connect(add_files)
	picker.file_selected.connect(func(path): add_files(PackedStringArray([path])))
	image_picker = FileDialog.new(); add_child(image_picker)
	image_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE; image_picker.access = FileDialog.ACCESS_FILESYSTEM; image_picker.use_native_dialog = true
	image_picker.filters = PackedStringArray(["*.png,*.jpg,*.jpeg;Images;image/png,image/jpeg"])
	image_picker.file_selected.connect(set_background)
	move_child(safe_content,get_child_count()-1)
	refresh_stage_button(); refresh_staged()

func build_import_panel() -> void:
	import_panel = Control.new(); place(import_panel,self,0,0,1,1); import_panel.visible = false
	import_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim = ColorRect.new(); place(dim,import_panel,0,0,1,1); dim.color = Color(0,0,0,.6)
	var card = panel(import_panel,.25,.14,.75,.9,Color(ACCENT,.55))
	text(card,"IMPORT AN SSRG SONG",.07,.03,.8,.12,24,ACCENT)
	action(card,"✕",.86,.035,.95,.13,func(): import_panel.visible = false,"small")
	text(card,"Pick the song's .bytes files from your own SSRG game files: the audio (the large file) and its 4, 7 or 13 key charts. Select them together or one at a time.",.07,.13,.93,.29,15,MUTED)
	action(card,"ADD FILES",.07,.31,.6,.43,choose_files)
	action(card,"CLEAR",.63,.31,.93,.43,clear_staged)
	staged_label = text(card,"",.07,.46,.93,.74,18)
	staged_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	import_button = action(card,"IMPORT SONG",.07,.76,.93,.88,import_staged,"primary")
	import_status = text(card,"",.07,.88,.93,.98,14,MUTED)

func open() -> void:
	pending = {}; delete_armed = 0
	visible = true
	refresh_stage_button()
	refresh_songs()

func close() -> void:
	visible = false
	game.close_ssrg_playables()

# --- SSRG songs ------------------------------------------------------------------------
func ssrg_songs() -> Array:
	return game.library.songs.filter(func(s): return s.has("ssrg"))

func charts_for(id: String) -> Array:
	# [{keys, variant, notes, density, length}] for each saved key count, fewest keys first.
	var result: Array = []
	for count in [4,7,13]:
		var variant = Levels.key(count)
		var path = Levels.chart_path(id,variant)
		if not FileAccess.file_exists(path): continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		var notes = SynkChart.notes_from_file(data)
		if not notes is Array or notes.is_empty(): continue
		var span = maxf(1.0,float(notes[-1].time)-float(notes[0].time))
		result.append({"keys":count,"variant":variant,"notes":notes.size(),"density":notes.size()/span,"bpm":float(data.get("bpm",0))})
	return result

func best(id: String, variant: String) -> Dictionary:
	var value = game.prefs.get_value("ssrg_best",id+"|"+variant,{})
	return value if value is Dictionary else {}

func song_length(song: Dictionary) -> float:
	var meta: Dictionary = game.song_metadata.get(str(song.id),{})
	return float(meta.get("duration",song.get("length",0.0)))

func refresh_songs() -> void:
	for child in song_list.get_children(): child.queue_free()
	var query = search.text.strip_edges().to_lower()
	var songs = ssrg_songs()
	if not songs.any(func(s): return str(s.id)==selected_id): selected_id = str(songs[0].id) if not songs.is_empty() else ""
	var shown = 0
	for song in songs:
		if not query.is_empty() and not str(song.title).to_lower().contains(query): continue
		shown += 1
		song_list.add_child(song_row(song))
	if shown == 0:
		var empty = Label.new(); empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = "No SSRG songs yet.\nTap + IMPORT SONG to add one." if songs.is_empty() else "No songs match your search."
		empty.add_theme_color_override("font_color",MUTED); empty.add_theme_font_size_override("font_size",17)
		song_list.add_child(empty)
	refresh_detail()

func song_row(song: Dictionary) -> Control:
	var id = str(song.id)
	var row = Button.new(); row.custom_minimum_size = Vector2(0,92); row.focus_mode = Control.FOCUS_NONE
	var selected = id == selected_id
	var normal = box(Color(1,1,1,.09) if selected else Color(1,1,1,.035),Color(ACCENT,.7) if selected else Color(1,1,1,.06),16)
	for state in ["normal","hover","pressed","focus"]: row.add_theme_stylebox_override(state,normal)
	row.pressed.connect(func():
		if Action.was_dragged(row): return
		selected_id = id; selected_variant = ""; delete_armed = 0; refresh_songs())
	var cover = TextureRect.new(); row.add_child(cover)
	cover.position = Vector2(12,12); cover.size = Vector2(68,68)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.texture = game.lobby.cover_for(id); game.lobby.style_cover(cover,id,12)
	var title = Label.new(); row.add_child(title); title.position = Vector2(96,14); title.size = Vector2(260,32)
	title.text = str(song.title); title.clip_text = true; title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size",20)
	var chips = HBoxContainer.new(); row.add_child(chips); chips.position = Vector2(96,52); chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override("separation",6)
	for chart in charts_for(id):
		var chip = Label.new(); chip.text = " %dK " % chart.keys; chip.add_theme_font_size_override("font_size",13)
		chip.add_theme_color_override("font_color",KEY_COLORS[chart.keys])
		chip.add_theme_stylebox_override("normal",box(Color(KEY_COLORS[chart.keys],.12),Color(KEY_COLORS[chart.keys],.5),8))
		chips.add_child(chip)
		var record = best(id,chart.variant)
		if not record.is_empty():
			var rank = Label.new(); rank.text = str(record.get("rank","")); rank.add_theme_font_size_override("font_size",13)
			rank.add_theme_color_override("font_color",MUTED); chips.add_child(rank)
	# Delete right from the list: tap ✕, then tap DELETE? to confirm.
	var armed = row_armed_id == id and delete_armed > 0
	var trash = action(row,"DELETE?" if armed else "✕",.8 if armed else .88,.25,.97,.75,func():
		if Action.was_dragged(row): return
		if row_armed_id == id and delete_armed > 0: delete_song(id)
		else:
			row_armed_id = id; delete_armed = 3.0; refresh_songs(),"small")
	trash.tooltip_text = "Delete this song"
	return row

func refresh_detail() -> void:
	for child in detail.get_children(): child.queue_free()
	delete_button = null
	var song: Dictionary = {}
	for s in ssrg_songs():
		if str(s.id) == selected_id: song = s
	if song.is_empty():
		text(detail,"Import an SSRG song to start.\n\nYou need the song's audio .bytes file and at least one chart .bytes file from your own copy of the game.",.08,.2,.92,.7,18,MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	var id = str(song.id)
	# Banner: the gameplay background (or cover) behind the title.
	var banner = Panel.new(); place(banner,detail,.03,.03,.97,.36); banner.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	banner.add_theme_stylebox_override("panel",box(Color(0,0,0,1),Color(1,1,1,.08),18))
	var art = TextureRect.new(); place(art,banner,0,0,1,1); art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var backdrop: Texture2D = game.stage_backdrop_for_id(id)
	if backdrop: art.texture = backdrop
	else:
		# No picture yet: a soft gradient in the song's own hue.
		var hue = float(posmod(id.hash(),360))/360.0
		var gradient = Gradient.new(); gradient.colors = PackedColorArray([Color.from_hsv(hue,.7,.55),Color.from_hsv(fmod(hue+.2,1),.75,.3)])
		var fill = GradientTexture2D.new(); fill.gradient = gradient; fill.fill_to = Vector2(1,1)
		art.texture = fill
	var fade = ColorRect.new(); place(fade,banner,0,.45,1,1); fade.color = Color(0,0,0,.55); fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text(banner,str(song.title),.04,.5,.96,.78,30)
	var length = song_length(song)
	var facts: Array = ["SSRG"]
	if float(song.get("bpm",0)) > 0: facts.append("%d BPM" % roundi(float(song.bpm)))
	if length > 0: facts.append(game.lobby.duration_text(length))
	text(banner,"  ·  ".join(facts),.04,.76,.96,.95,16,Color(1,1,1,.75))

	# One card per chart.
	var charts = charts_for(id)
	if charts.is_empty():
		text(detail,"This song has no playable charts. Import its chart files again.",.05,.4,.95,.6,17,MUTED); return
	if not charts.any(func(c): return c.variant == selected_variant): selected_variant = charts[-1].variant
	text(detail,"CHARTS",.04,.38,.5,.44,15,ACCENT)
	var width = .92/charts.size()
	for i in charts.size():
		var chart: Dictionary = charts[i]
		var left = .04+i*width; var right = left+width-.015
		var chosen = chart.variant == selected_variant
		var color: Color = KEY_COLORS[chart.keys]
		var card = Button.new(); place(card,detail,left,.45,right,.72); card.focus_mode = Control.FOCUS_NONE
		var style = box(Color(color,.16) if chosen else Color(1,1,1,.035),Color(color,.9) if chosen else Color(1,1,1,.08),16)
		if chosen: style.set_border_width_all(2)
		for state in ["normal","hover","pressed","focus"]: card.add_theme_stylebox_override(state,style)
		card.pressed.connect(func(): selected_variant = chart.variant; refresh_detail())
		var heading = text(card,"%d KEYS" % chart.keys,.08,.05,.92,.3,22,color)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var stats = text(card,"%d notes\n%.1f notes / sec" % [chart.notes,chart.density],.08,.3,.92,.66,14,Color(1,1,1,.8))
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var record = best(id,chart.variant)
		var best_text = "Best  %s  ·  %s" % [str(record.get("rank","")),str(record.get("score",0))] if not record.is_empty() else "Not played yet"
		var best_label = text(card,best_text,.05,.68,.95,.94,13,MUTED)
		best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	action(detail,"▶  PLAY",.04,.76,.5,.88,func(): play(id,selected_variant,false),"primary")
	action(detail,"AUTO PLAY",.52,.76,.72,.88,func(): play(id,selected_variant,true))
	action(detail,"BACKGROUND",.74,.76,.96,.88,choose_background)
	if game.has_background(id): action(detail,"REMOVE BACKGROUND",.04,.895,.36,.97,func(): game.remove_background(id); refresh_detail(),"small")
	delete_button = action(detail,"DELETE SONG",.7,.895,.96,.97,delete_selected,"small")

# --- Actions ---------------------------------------------------------------------------
func refresh_stage_button() -> void:
	var on = bool(game.prefs.get_value("ssrg","use_stage",true))
	stage_button.text = "SSRG STAGE  ON" if on else "SSRG STAGE  OFF"
	stage_button.tooltip_text = "Play these songs on the SSRG highway style (your own style setting is kept)."

func toggle_stage() -> void:
	game.prefs.set_value("ssrg","use_stage",not bool(game.prefs.get_value("ssrg","use_stage",true)))
	game.prefs.save("user://preferences.cfg")
	refresh_stage_button()

func choose_background() -> void:
	if OS.get_name()=="iOS": image_picker.access=FileDialog.ACCESS_USERDATA; image_picker.current_dir="user://"
	image_picker.popup_centered_ratio(.8)

func set_background(path: String) -> void:
	var picked = game.load_picked_image(path)
	if picked is String: status_label.text = picked; return
	var problem = game.save_background_image(selected_id,picked)
	status_label.text = problem if not problem.is_empty() else "Background saved. It shows behind the highway in play."
	refresh_detail()

func delete_selected() -> void:
	# Two taps: the first arms the button for a few seconds.
	if delete_armed <= 0:
		delete_armed = 3.0; row_armed_id = ""
		if delete_button: delete_button.text = "TAP AGAIN TO DELETE"
		return
	delete_song(selected_id)

func delete_song(id: String) -> void:
	delete_armed = 0; row_armed_id = ""
	var title = ""
	for s in ssrg_songs():
		if str(s.id) == id: title = str(s.title)
	if str(game.song.id) == id: game.select_song(0)
	if game.library.delete_song(id) != OK: status_label.text = "Could not delete this song."; return
	for count in [4,7,13]:
		var key = id+"|"+Levels.key(count)
		if game.prefs.has_section_key("ssrg_best",key): game.prefs.erase_section_key("ssrg_best",key)
	game.prefs.save("user://preferences.cfg")
	game.song_metadata.erase(id)
	game.refresh_library()
	if game.lobby: game.lobby.refresh()
	if selected_id == id: selected_id = ""
	status_label.text = "Deleted %s." % title
	refresh_songs()

# --- Import ----------------------------------------------------------------------------
func open_import() -> void:
	import_status.text = ""
	refresh_staged()
	import_panel.visible = true

func choose_files() -> void:
	if OS.get_name()=="iOS":
		picker.access=FileDialog.ACCESS_USERDATA; picker.current_dir="user://"
		import_status.text = "In the Files app, copy the files into On My iPhone → SYNK first."
	picker.popup_centered_ratio(.8)

func add_files(paths: PackedStringArray) -> void:
	var problems: Array = []
	for path in paths:
		var bytes = FileAccess.get_file_as_bytes(path)
		var name = path.uri_decode().get_file()
		if bytes.is_empty(): problems.append(name+": could not read"); continue
		if SsrgImport.is_audio(bytes): staged_audio = path; continue
		var chart = SsrgImport.parse(bytes)
		if chart.is_empty(): problems.append(name+": not an SSRG chart"); continue
		staged_charts[int(chart.keys)] = chart
	import_status.text = "\n".join(problems)
	refresh_staged()

func clear_staged() -> void:
	staged_audio = ""; staged_charts.clear(); import_status.text = ""
	refresh_staged()

func refresh_staged() -> void:
	var lines: Array = []
	var title = staged_title()
	if not title.is_empty(): lines.append(title)
	lines.append("Audio:  " + ("ready ✓" if not staged_audio.is_empty() else "not added yet"))
	for keys in [4,7,13]:
		var chart: Dictionary = staged_charts.get(keys,{})
		lines.append("%d keys:  %s" % [keys, "%d notes ✓" % chart.notes.size() if not chart.is_empty() else "—"])
	staged_label.text = "\n".join(lines)
	import_button.disabled = staged_audio.is_empty() or staged_charts.is_empty()

func staged_title() -> String:
	for keys in staged_charts:
		if not str(staged_charts[keys].title).is_empty(): return str(staged_charts[keys].title)
	return ""

func import_staged() -> void:
	if staged_audio.is_empty() or staged_charts.is_empty(): return
	var library: SynkLibrary = game.library
	import_status.text = "Importing…"
	var result = library.import_song(staged_audio)
	if result.is_empty(): import_status.text = library.message; return
	var song: Dictionary = result.song
	var id = str(song.id)
	var any: Dictionary = staged_charts.values()[0]
	var title = staged_title()
	if not title.is_empty(): song.title = title
	song.bpm = float(any.bpm); song.album = "SSRG"
	var length = result.stream.get_length()
	song.length = length
	var keys: Array = song.get("ssrg",[]).duplicate()
	var saved = 0
	for count in staged_charts:
		var chart: Dictionary = staged_charts[count]
		var notes = chart.notes.filter(func(n): return float(n.time)+float(n.duration) <= length)
		if not SynkChart.valid(notes): continue
		var settings = {"bpm":float(chart.bpm),"beat_offset":0.0,"verse2":-1.0,"bridge":-1.0}
		var variant = Levels.key(int(count))
		var data = {"version":SynkChart.FORMAT_VERSION,"song_id":id,"chart_name":variant,"title":str(song.title),"bpm":float(chart.bpm),"beat_offset":0.0,"chart_settings":settings,"notes":notes}
		if SynkLibrary.atomic_write(Levels.chart_path(id,variant),data) != OK: continue
		if int(count) not in keys: keys.append(int(count))
		saved += 1
	keys.sort(); song.ssrg = keys
	SynkLibrary.atomic_write(library.root_path.path_join("songs/library.json"),library.songs)
	game.song_metadata.erase(id)
	game.refresh_library()
	if game.lobby: game.lobby.refresh()
	staged_audio = ""; staged_charts.clear()
	refresh_staged()
	import_panel.visible = false
	selected_id = id; selected_variant = ""
	status_label.text = "Imported %s with %d chart%s." % [song.title, saved, "" if saved==1 else "s"]
	refresh_songs()

# --- Playing ---------------------------------------------------------------------------
func play(id: String, variant: String, automated: bool) -> void:
	var index = -1
	for i in game.library.songs.size():
		if str(game.library.songs[i].id) == id: index = i + 1
	if index < 0 or variant.is_empty(): return
	game.prefs.set_value("charts",id,variant); game.prefs.save("user://preferences.cfg")
	pending = {"id":id,"variant":variant,"auto":automated}
	status_label.text = "Loading…"
	if game.select_song(index): launch()

func _process(delta: float) -> void:
	if delete_armed > 0:
		delete_armed -= delta
		if delete_armed <= 0:
			if delete_button and is_instance_valid(delete_button): delete_button.text = "DELETE SONG"
			if not row_armed_id.is_empty(): row_armed_id = ""; refresh_songs()
	if not running.is_empty():
		if game.mode == "results" and not running.get("recorded",false):
			running.recorded = true; record_result()
		elif game.mode in ["menu","library","editor"]:
			running = {}
			if not restore_style.is_empty(): game.change_highway_look("style",restore_style); restore_style = ""
			if visible: refresh_songs()
	if not visible or pending.is_empty() or game.loading_song_index > 0: return
	if str(game.song.id) == str(pending.id): launch()
	else: pending = {}; status_label.text = "Could not load this song."

func launch() -> void:
	var run = pending; pending = {}
	game.features.choose_level(str(run.variant))
	var notes: Array = game.baseline_notes()
	if notes.is_empty(): status_label.text = "This chart could not be loaded."; return
	status_label.text = ""
	if bool(game.prefs.get_value("ssrg","use_stage",true)) and game.highway_style != "ssrg":
		restore_style = game.highway_style; game.change_highway_look("style","ssrg")
	running = run
	visible = false
	game.start_game(notes,bool(run.auto))

func record_result() -> void:
	if bool(running.get("auto",false)): return
	var key = str(running.id)+"|"+str(running.variant)
	var previous = best(str(running.id),str(running.variant))
	if int(game.score) <= int(previous.get("score",-1)): return
	game.prefs.set_value("ssrg_best",key,{"score":int(game.score),"rank":game.rank_name(),"combo":int(game.max_combo),"accuracy":snappedf(game.accuracy(),.01)})
	game.prefs.save("user://preferences.cfg")
