extends Control
const ScreenStyle = preload("res://scripts/screen_style.gd")
const Action = preload("res://scripts/settings_action.gd")
const Levels = preload("res://scripts/chart_levels.gd")
const SsrgImport = preload("res://scripts/ssrg_import.gd")
const TEXT = Color("eef0ff")
const MUTED = Color(.8,.82,.95,.6)
const ACCENT = Color("ffd36a")
const STAR = "★"
const STAR_OFF = "☆"
const KEY_COLORS = {4: Color("5fd0ff"), 7: Color("ffd36a"), 13: Color("ff7ac8")}

# SSRG Playables (lobby button). The player picks the files of an SSRG song from their own copy
# of the game: the song audio (.bytes, really Ogg) and its 4, 7 and 13 key charts (.bytes).
# Importing adds the song to the library with one chart per key count (saved as Lv 4, Lv 7 and
# Lv 13). Nothing from SSRG ships with SYNK.
#   left:  searchable song list with cover, key chips and best rank
#   right: the selected song - banner, one card per chart (notes, density, best score),
#          PLAY / AUTO PLAY, gameplay background and delete
#   IMPORT opens the import panel. SCAN PHONE reads the ssrg folder on the phone's storage:
#   ssrg/<GAME>/seq (charts), ssrg/<GAME>/music and ssrg/<GAME>/background, one game per folder. Songs play on the player's regular SYNK highway.

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
var speed_label: Label
var search: LineEdit
# Category tabs: one per game folder (SSYG, SSFNC, ...) plus ALL; "" shows every game.
var game_tabs: HBoxContainer
var game_filter = ""
# List order (cycled by SORT) and favourites (a star on a song; the star tab shows only those).
const SORTS = ["GAME", "TITLE", "ARTIST", "NEWEST", "BEST"]
var sort_mode = "GAME"
var sort_button: Button
var favorites: Array = []
# A short clip of the selected song (PREVIEW in the song panel turns it off).
var preview_player: AudioStreamPlayer
var preview_delay = -1.0
var preview_id = ""
# The preview's audio is read on a worker thread so tapping a song never stalls the screen.
var preview_loader = -1
var preview_loaded: AudioStream
# LOG OUT for the game-wide sign-in (app_login.gd); shown only when that sign-in is on.
var logout_button: Button
# With hundreds of songs the list must stay cheap: chart details are read once per song and
# kept, and picking a song only restyles two rows instead of rebuilding the list.
var chart_cache: Dictionary = {}
var rows: Dictionary = {}   # song id -> {"row": Button, "trash": Button}
# Rows still to add; the list is built a few dozen rows per frame.
var row_queue: Array = []
const ROWS_PER_FRAME = 12
var song_list: VBoxContainer
var detail: Control
var selected_id = ""
var selected_variant = ""
var delete_armed = 0.0
var delete_button: Button
# Song whose row delete button was tapped once (a second tap within a few seconds deletes it).
var row_armed_id = ""
var pending: Dictionary = {}
# Songs found by SCAN PHONE, imported one per frame so the screen keeps drawing.
var scan_queue: Array = []
var scan_done = 0
var scan_added = 0
# The run started from this screen: its best score is kept when the results appear.
var running: Dictionary = {}

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
	# A flat backdrop: the old full-screen picture was 86% covered and cost a full extra fill.
	var shade = ColorRect.new(); place(shade,self,0,0,1,1); shade.color = Color(0.024,0.024,0.034); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_content=game.safe_parent("SafeSsrgControls",self)
	action(self,"‹  BACK",.035,.035,.15,.14,close,"nav")
	text(self,"SSRG PLAYABLES",.17,.035,.5,.1,40)
	status_label = text(self,"Play SSRG songs from your own game files.",.17,.095,.6,.15,16,MUTED)
	action(self,"SCAN PHONE",.8,.045,.965,.135,scan_phone,"primary")
	action(self,"+ FILES",.455,.045,.555,.135,open_import,"small")
	logout_button = action(self,"LOG OUT",.37,.045,.445,.135,log_out,"small")
	# Note speed for SSRG songs only (0.5x to 4x).
	action(self,"−",.57,.045,.62,.135,func(): change_speed(-.25),"small")
	speed_label = text(self,"",.625,.045,.725,.135,18); speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action(self,"+",.73,.045,.78,.135,func(): change_speed(.25),"small")
	ScreenStyle.rule(self,.035,.965,.165)

	# Song list
	var list_panel = panel(self,.035,.19,.4,.96)
	search = LineEdit.new(); place(search,list_panel,.04,.025,.5,.11)
	sort_button = action(list_panel,"",.52,.025,.76,.11,cycle_sort,"small")
	action(list_panel,"SHUFFLE",.78,.025,.96,.11,shuffle,"small")
	search.placeholder_text = "Search songs"; search.clear_button_enabled = true
	search.add_theme_font_size_override("font_size",17)
	for state in ["normal","focus"]:
		var field = box(Color(1,1,1,.05 if state=="normal" else .07),Color(1,1,1,.12) if state=="normal" else Color(ACCENT,.5),14)
		field.content_margin_left = 16; field.content_margin_right = 12
		search.add_theme_stylebox_override(state,field)
	search.text_changed.connect(func(_t): refresh_songs())
	var tab_scroll = ScrollContainer.new(); place(tab_scroll,list_panel,.04,.125,.96,.205)
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	game_tabs = HBoxContainer.new(); tab_scroll.add_child(game_tabs); game_tabs.add_theme_constant_override("separation",8)
	var scroll = ScrollContainer.new(); place(scroll,list_panel,.04,.22,.96,.98)
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
	preview_player = AudioStreamPlayer.new(); add_child(preview_player); preview_player.volume_db = -10
	var stored = game.prefs.get_value("ssrg","favorites",[])
	favorites = stored if stored is Array else []
	sort_mode = str(game.prefs.get_value("ssrg","sort","GAME"))
	if sort_mode not in SORTS: sort_mode = "GAME"
	refresh_staged(); refresh_speed(); refresh_sort_button()

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
	logout_button.visible = game.app_login != null and game.app_login.required()
	refresh_songs()

func close() -> void:
	stop_preview()
	visible = false
	game.close_ssrg_playables()

func log_out() -> void:
	stop_preview()
	close()
	if game.app_login: game.app_login.sign_out()

# --- Sort, favourites, shuffle, preview ----------------------------------------------
func refresh_sort_button() -> void:
	sort_button.text = "SORT: " + sort_mode

func cycle_sort() -> void:
	sort_mode = SORTS[(SORTS.find(sort_mode)+1) % SORTS.size()]
	game.prefs.set_value("ssrg","sort",sort_mode); game.prefs.save("user://preferences.cfg")
	refresh_sort_button(); refresh_songs()

func best_score(id: String) -> int:
	var top = -1
	for count in [4,7,13]: top = maxi(top, int(best(id,Levels.key(count)).get("score",-1)))
	return top

func sort_key(song: Dictionary) -> Array:
	match sort_mode:
		"TITLE": return [str(song.title).to_lower()]
		"ARTIST": return [str(song.get("artist","")).to_lower(), str(song.title).to_lower()]
		"NEWEST": return [-float(song.get("added",0)), str(song.title).to_lower()]
		"BEST": return [-best_score(str(song.id)), str(song.title).to_lower()]
	return [category(song), str(song.title).to_lower()]

func is_favorite(id: String) -> bool: return id in favorites

func toggle_favorite(id: String) -> void:
	if id in favorites: favorites.erase(id)
	else: favorites.append(id)
	game.prefs.set_value("ssrg","favorites",favorites); game.prefs.save("user://preferences.cfg")
	if rows.has(id) and is_instance_valid(rows[id].star): style_star(rows[id].star,is_favorite(id))
	if game_filter == STAR: refresh_songs()
	else: refresh_game_tabs(ssrg_songs()); refresh_detail(); refresh_stats()

func style_star(button: Button, on: bool) -> void:
	button.text = STAR if on else STAR_OFF
	button.add_theme_color_override("font_color",ACCENT if on else MUTED)
	button.add_theme_color_override("font_hover_color",ACCENT)

func shuffle() -> void:
	var pool = shown_songs()
	if pool.size() < 2: return
	var pick = pool[randi() % pool.size()]
	while str(pick.id) == selected_id: pick = pool[randi() % pool.size()]
	select_song(str(pick.id))
	status_label.text = "Shuffled: %s" % str(pick.title)

func preview_enabled() -> bool: return bool(game.prefs.get_value("ssrg","preview",true))

func toggle_preview() -> void:
	game.prefs.set_value("ssrg","preview",not preview_enabled()); game.prefs.save("user://preferences.cfg")
	if preview_enabled(): schedule_preview()
	else: stop_preview()
	refresh_detail()

func stop_preview() -> void:
	preview_delay = -1.0
	if preview_player: preview_player.stop()

func schedule_preview() -> void:
	stop_preview()
	if preview_enabled() and visible and not selected_id.is_empty(): preview_delay = .45

func start_preview() -> void:
	var song: Dictionary = game.song_entry_for_id(selected_id)
	if song.is_empty() or not visible: return
	if preview_id == selected_id and preview_player.stream != null: play_preview(); return
	if preview_loader >= 0: return
	var path = "user://songs/"+str(song.file); var id = selected_id
	preview_loaded = null
	preview_loader = WorkerThreadPool.add_task(func(): preview_loaded = SynkLibrary.decode(path))
	set_meta("preview_for", id)

func finish_preview_load() -> void:
	if preview_loader < 0 or not WorkerThreadPool.is_task_completed(preview_loader): return
	WorkerThreadPool.wait_for_task_completion(preview_loader); preview_loader = -1
	var id = str(get_meta("preview_for",""))
	if preview_loaded == null: return
	preview_player.stream = preview_loaded; preview_id = id
	# Still the selected song: play it; otherwise start loading the newly selected one.
	if id == selected_id and preview_enabled() and visible: play_preview()
	elif preview_enabled() and visible: start_preview()

func play_preview() -> void:
	var length = preview_player.stream.get_length()
	preview_player.play(minf(length*.3, maxf(0.0,length-12.0)))

func refresh_stats() -> void:
	var songs = ssrg_songs()
	var games = {}
	for song in songs: games[category(song)] = true
	var liked = favorites.filter(func(id): return songs.any(func(x): return str(x.id)==id)).size()
	status_label.text = "%d songs  ·  %d games  ·  %d favourites" % [songs.size(), games.size(), liked]

# --- SSRG songs ------------------------------------------------------------------------
func ssrg_songs() -> Array:
	return game.library.songs.filter(func(s): return s.has("ssrg"))

func charts_for(id: String) -> Array:
	# [{keys, variant, notes, density, length}] for each saved key count, fewest keys first.
	if chart_cache.has(id): return chart_cache[id]
	# Songs imported by this version carry a summary, so the chart files need not be read.
	var entry: Dictionary = game.song_entry_for_id(id)
	if entry.get("ssrg_charts") is Array and not entry.ssrg_charts.is_empty():
		chart_cache[id] = entry.ssrg_charts; return chart_cache[id]
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
	chart_cache[id] = result
	return result

func best(id: String, variant: String) -> Dictionary:
	var value = game.prefs.get_value("ssrg_best",id+"|"+variant,{})
	return value if value is Dictionary else {}

func song_length(song: Dictionary) -> float:
	var meta: Dictionary = game.song_metadata.get(str(song.id),{})
	return float(meta.get("duration",song.get("length",0.0)))

func refresh_songs() -> void:
	for child in song_list.get_children():
		song_list.remove_child(child); child.queue_free()
	rows.clear(); row_queue.clear()
	var query = search.text.strip_edges().to_lower()
	var all_songs = ssrg_songs()
	refresh_game_tabs(all_songs)
	# Grouped by game folder, A to Z, then by title; a heading starts each game.
	var songs = all_songs.filter(func(x): return in_filter(x))
	songs.sort_custom(func(a, b): return sort_key(a) < sort_key(b))
	if not songs.any(func(s): return str(s.id)==selected_id): selected_id = str(songs[0].id) if not songs.is_empty() else ""
	var shown = 0
	var heading = null
	for song in songs:
		var haystack = " ".join([str(song.title),str(song.get("artist","")),str(song.get("album",""))]).to_lower()
		if not query.is_empty() and not haystack.contains(query): continue
		if sort_mode == "GAME" and category(song) != heading:
			heading = category(song)
			var count = songs.filter(func(x): return category(x) == heading).size()
			var label = Label.new(); label.text = "%s  ·  %d" % [heading, count]
			label.add_theme_font_size_override("font_size",15); label.add_theme_color_override("font_color",ACCENT)
			row_queue.append(label)
		shown += 1
		row_queue.append(song)
	if shown == 0:
		var empty = Label.new(); empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = "No SSRG songs yet.\nTap SCAN PHONE or + FILES to add some." if all_songs.is_empty() else ("No favourites yet. Tap the star on a song." if game_filter == STAR else "No songs match your search.")
		empty.add_theme_color_override("font_color",MUTED); empty.add_theme_font_size_override("font_size",17)
		song_list.add_child(empty)
	refresh_detail(); refresh_stats()

func in_filter(song: Dictionary) -> bool:
	if game_filter.is_empty(): return true
	if game_filter == STAR: return is_favorite(str(song.id))
	return category(song) == game_filter

# The songs the list currently shows (tab and search applied).
func shown_songs() -> Array:
	var query = search.text.strip_edges().to_lower()
	return ssrg_songs().filter(func(x):
		var haystack = " ".join([str(x.title),str(x.get("artist","")),str(x.get("album",""))]).to_lower()
		return in_filter(x) and (query.is_empty() or haystack.contains(query)))

# The game folder a song was scanned from; songs added with + FILES go under IMPORTED.
func category(song: Dictionary) -> String:
	var album = str(song.get("album","")).strip_edges()
	return "IMPORTED" if album.is_empty() or album == "SSRG" else album.to_upper()

func refresh_game_tabs(songs: Array) -> void:
	for child in game_tabs.get_children(): child.queue_free()
	var names: Array = []
	for song in songs:
		if category(song) not in names: names.append(category(song))
	names.sort()
	var has_favorites = songs.any(func(x): return is_favorite(str(x.id)))
	if game_filter not in names and not (game_filter == STAR and has_favorites): game_filter = ""
	if names.size() < 2 and not has_favorites and game_filter.is_empty(): return
	for name in [""] + ([STAR] if has_favorites else []) + names:
		var tab = Action.new(); tab.text = "ALL" if name.is_empty() else name; tab.caption_size = 15
		tab.primary = name == game_filter; tab.custom_minimum_size = Vector2(maxf(84, tab.text.length()*11+36), 38)
		tab.pressed.connect(func(): game_filter = name; refresh_songs())
		game_tabs.add_child(tab)

func song_row(song: Dictionary) -> Control:
	var id = str(song.id)
	var row = Button.new(); row.custom_minimum_size = Vector2(0,92); row.focus_mode = Control.FOCUS_NONE
	var selected = id == selected_id
	style_row(row,selected)
	row.pressed.connect(func():
		if Action.was_dragged(row): return
		select_song(id))
	# Real album art when the song has it, otherwise a flat tile in the song's hue (no shader).
	if game.has_custom_cover(id):
		var cover = TextureRect.new(); row.add_child(cover)
		cover.position = Vector2(12,12); cover.size = Vector2(68,68)
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE; cover.texture = game.cover_texture_for_id(id)
	else:
		var tile = Panel.new(); row.add_child(tile); tile.position = Vector2(12,12); tile.size = Vector2(68,68)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hue = float(posmod(id.hash(),360))/360.0
		tile.add_theme_stylebox_override("panel",box(Color.from_hsv(hue,.6,.5),Color.from_hsv(hue,.5,.85),12))
	var title = Label.new(); row.add_child(title); title.position = Vector2(96,6); title.size = Vector2(260,30)
	title.text = str(song.title); title.clip_text = true; title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size",20)
	# Artist · game folder (SSYG, SSFNC, ...) when the song came from a phone scan.
	var byline = Label.new(); row.add_child(byline); byline.position = Vector2(96,34); byline.size = Vector2(260,22)
	byline.text = "  ·  ".join([str(song.get("artist","")),str(song.get("album",""))].filter(func(t): return not t.is_empty() and t != "SSRG"))
	byline.clip_text = true; byline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	byline.add_theme_font_size_override("font_size",14); byline.add_theme_color_override("font_color",MUTED)
	var chips = HBoxContainer.new(); row.add_child(chips); chips.position = Vector2(96,60); chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	# A plain button (no per-frame animation), so hundreds of rows cost nothing while idle.
	var trash = Button.new(); place(trash,row,.86,.25,.97,.75); trash.text = "✕"; trash.focus_mode = Control.FOCUS_NONE
	trash.add_theme_font_size_override("font_size",15)
	for state in ["normal","hover","pressed"]: trash.add_theme_stylebox_override(state,box(Color(1,1,1,.05 if state=="normal" else .12),Color(1,1,1,.14),14))
	trash.tooltip_text = "Delete this song"
	trash.pressed.connect(func():
		if Action.was_dragged(row): return
		if row_armed_id == id and delete_armed > 0: delete_song(id); return
		disarm_row()
		row_armed_id = id; delete_armed = 3.0
		trash.text = "DELETE?"; trash.anchor_left = .74
		if rows.has(id): rows[id].star.visible = false)
	var star = Button.new(); place(star,row,.74,.25,.85,.75); star.focus_mode = Control.FOCUS_NONE
	star.add_theme_font_size_override("font_size",20)
	for state in ["normal","hover","pressed"]: star.add_theme_stylebox_override(state,box(Color(1,1,1,0),Color(1,1,1,0),14))
	style_star(star,is_favorite(id)); star.tooltip_text = "Favourite"
	star.pressed.connect(func():
		if Action.was_dragged(row): return
		toggle_favorite(id))
	rows[id] = {"row":row,"trash":trash,"star":star}
	return row

func style_row(row: Button, selected: bool) -> void:
	var normal = box(Color(1,1,1,.09) if selected else Color(1,1,1,.035),Color(ACCENT,.7) if selected else Color(1,1,1,.06),16)
	for state in ["normal","hover","pressed","focus"]: row.add_theme_stylebox_override(state,normal)

func select_song(id: String) -> void:
	if rows.has(selected_id): style_row(rows[selected_id].row,false)
	selected_id = id; selected_variant = ""; delete_armed = 0; disarm_row()
	if rows.has(id): style_row(rows[id].row,true)
	refresh_detail()
	schedule_preview()

func disarm_row() -> void:
	if rows.has(row_armed_id) and is_instance_valid(rows[row_armed_id].trash):
		rows[row_armed_id].trash.text = "✕"; rows[row_armed_id].trash.anchor_left = .86
		if rows[row_armed_id].has("star") and is_instance_valid(rows[row_armed_id].star): rows[row_armed_id].star.visible = true
	row_armed_id = ""

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
	var facts: Array = [str(song.get("artist","")),str(song.get("album","SSRG"))].filter(func(t): return not t.is_empty())
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
	action(detail,"PREVIEW  " + ("ON" if preview_enabled() else "OFF"),.38,.895,.68,.97,toggle_preview,"small")
	var star = Button.new(); place(star,detail,.88,.045,.955,.14); star.focus_mode = Control.FOCUS_NONE
	star.add_theme_font_size_override("font_size",30)
	for state in ["normal","hover","pressed"]: star.add_theme_stylebox_override(state,box(Color(0,0,0,.35),Color(1,1,1,.12),14))
	style_star(star,is_favorite(id)); star.tooltip_text = "Favourite"
	star.pressed.connect(func(): toggle_favorite(id))
	delete_button = action(detail,"DELETE SONG",.7,.895,.96,.97,delete_selected,"small")

func change_speed(step: float) -> void:
	game.prefs.set_value("ssrg","speed",clampf(snappedf(game.ssrg_note_speed()+step,.25),.5,4.0))
	game.prefs.save("user://preferences.cfg")
	refresh_speed()

func refresh_speed() -> void:
	speed_label.text = "SPEED %s×" % str(game.ssrg_note_speed())

# --- Actions ---------------------------------------------------------------------------
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
	delete_armed = 0; row_armed_id = ""; chart_cache.erase(id)
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
	import_status.text = "Importing…"
	var stored = store_song(staged_audio,staged_charts,{"title":staged_title()})
	if stored.has("error"): import_status.text = stored.error; return
	game.refresh_library()
	if game.lobby: game.lobby.refresh()
	staged_audio = ""; staged_charts.clear()
	refresh_staged()
	import_panel.visible = false
	selected_id = stored.id; selected_variant = ""
	status_label.text = "Imported %s with %d chart%s." % [stored.title, stored.saved, "" if stored.saved==1 else "s"]
	refresh_songs()

# Adds one song (audio file + parsed charts by key count) to the library; meta may carry
# title, artist, album (the game) and background (an image path).
func store_song(audio_path: String, charts: Dictionary, meta: Dictionary) -> Dictionary:
	var library: SynkLibrary = game.library
	var result = library.import_song(audio_path)
	if result.is_empty(): return {"error": library.message}
	var song: Dictionary = result.song
	var id = str(song.id)
	var any: Dictionary = charts.values()[0]
	if not str(meta.get("title","")).is_empty(): song.title = str(meta.title)
	if not str(meta.get("artist","")).is_empty(): song.artist = str(meta.artist)
	song.bpm = float(any.bpm); song.album = str(meta.get("album","SSRG"))
	if not song.has("added"): song.added = Time.get_unix_time_from_system()
	var length = result.stream.get_length()
	song.length = length
	var keys: Array = song.get("ssrg",[]).duplicate()
	var saved = 0
	for count in charts:
		var chart: Dictionary = charts[count]
		var notes = chart.notes.filter(func(n): return float(n.time)+float(n.duration) <= length)
		if not SynkChart.valid(notes): continue
		var settings = {"bpm":float(chart.bpm),"beat_offset":0.0,"verse2":-1.0,"bridge":-1.0}
		var variant = Levels.key(int(count))
		var data = {"version":SynkChart.FORMAT_VERSION,"song_id":id,"chart_name":variant,"title":str(song.title),"bpm":float(chart.bpm),"beat_offset":0.0,"chart_settings":settings,"notes":notes}
		if SynkLibrary.atomic_write(Levels.chart_path(id,variant),data) != OK: continue
		if int(count) not in keys: keys.append(int(count))
		saved += 1
	keys.sort(); song.ssrg = keys
	chart_cache.erase(id); song.erase("ssrg_charts")
	song.ssrg_charts = charts_for(id)
	SynkLibrary.atomic_write(library.root_path.path_join("songs/library.json"),library.songs)
	game.song_metadata.erase(id)
	var art = str(meta.get("background",""))
	if not art.is_empty():
		var picked = game.load_picked_image(art)
		if picked is Image: game.save_background_image(id,picked)
	return {"id":id,"title":str(song.title),"saved":saved}

# --- Phone library ---------------------------------------------------------------------
func phone_root() -> String:
	if OS.get_name() == "Android": return "/storage/emulated/0/ssrg"
	# Desktop: an "ssrg" folder beside Documents (for testing).
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).get_base_dir().path_join("ssrg")

func scan_phone() -> void:
	if not scan_queue.is_empty(): return
	# Reading another app's files needs Android's "All files access" for SYNK.
	if OS.get_name() == "Android" and "android.permission.MANAGE_EXTERNAL_STORAGE" not in OS.get_granted_permissions():
		OS.request_permission("android.permission.MANAGE_EXTERNAL_STORAGE")
		status_label.text = "Allow \"All files access\" for SYNK, then come back and tap SCAN PHONE again."
		return
	var root = phone_root()
	if not DirAccess.dir_exists_absolute(root):
		status_label.text = "No ssrg folder found. Create %s with one folder per game (seq, music, background inside)." % root
		return
	var found = SsrgImport.scan(root)
	var seen: Dictionary = game.prefs.get_value("ssrg","scanned",{})
	scan_queue = []; scan_done = 0; scan_added = 0
	var missing = 0
	var example = ""
	for entry in found:
		if str(entry.audio).is_empty():
			missing += 1
			# Say what was looked for and where, so a naming mismatch is easy to spot.
			if example.is_empty():
				var folder = "no music folder in %s" % entry.game if str(entry.music_dir).is_empty() else "%s/%s has %d audio files" % [entry.game, str(entry.music_dir).get_file(), int(entry.music_files)]
				example = " Song %s looks for \"%s\" (%s)." % [entry.song_id, entry.name, folder]
			continue
		var key = str(entry.game)+"/"+str(entry.song_id)
		var known = seen.get(key,{})
		if known is Dictionary and str(known.get("signature","")) == SsrgImport.signature(entry) and game.library.songs.any(func(s): return str(s.id)==str(known.get("id",""))): continue
		scan_queue.append(entry)
	if scan_queue.is_empty():
		status_label.text = "Found %d songs; nothing new to import.%s" % [found.size(), " %d have no music file.%s" % [missing, example] if missing else ""]
		return
	status_label.text = "Importing 0 / %d…" % scan_queue.size()
	set_meta("scan_missing", missing); set_meta("scan_total", scan_queue.size()); set_meta("scan_example", example)

func import_next_scanned() -> void:
	var entry: Dictionary = scan_queue.pop_front()
	var charts = {}
	for keys in entry.charts:
		var chart = SsrgImport.parse(FileAccess.get_file_as_bytes(entry.charts[keys]))
		if not chart.is_empty(): charts[int(keys) if int(keys) in [4,7,13] else int(chart.keys)] = chart
	if not charts.is_empty():
		var names = SsrgImport.artist_and_title(str(entry.name)) if not str(entry.name).is_empty() else ["",str(entry.song_id)]
		var stored = store_song(entry.audio,charts,{"artist":names[0],"title":names[1],"album":entry.game,"background":entry.background})
		if not stored.has("error"):
			scan_added += 1
			var seen: Dictionary = game.prefs.get_value("ssrg","scanned",{})
			seen[str(entry.game)+"/"+str(entry.song_id)] = {"id":stored.id,"signature":SsrgImport.signature(entry)}
			game.prefs.set_value("ssrg","scanned",seen)
	scan_done += 1
	var total = int(get_meta("scan_total",0))
	status_label.text = "Importing %d / %d…" % [scan_done,total]
	if scan_queue.is_empty():
		game.prefs.save("user://preferences.cfg")
		game.refresh_library()
		if game.lobby: game.lobby.refresh()
		var missing = int(get_meta("scan_missing",0))
		status_label.text = "Imported %d of %d songs.%s" % [scan_added,total," %d have no music file.%s" % [missing,str(get_meta("scan_example",""))] if missing else ""]
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
	finish_preview_load()
	if preview_delay >= 0:
		preview_delay -= delta
		if preview_delay < 0: start_preview()
	for i in mini(ROWS_PER_FRAME,row_queue.size()):
		var item = row_queue.pop_front()
		song_list.add_child(item if item is Control else song_row(item))
	if not scan_queue.is_empty(): import_next_scanned()
	if delete_armed > 0:
		delete_armed -= delta
		if delete_armed <= 0:
			if delete_button and is_instance_valid(delete_button): delete_button.text = "DELETE SONG"
			disarm_row()
	if not running.is_empty():
		if game.mode == "results" and not running.get("recorded",false):
			running.recorded = true; record_result()
		elif game.mode in ["menu","library","editor"]:
			running = {}
			if visible: refresh_songs()
	if not visible or pending.is_empty() or game.loading_song_index > 0: return
	if str(game.song.id) == str(pending.id): launch()
	else: pending = {}; status_label.text = "Could not load this song."

func launch() -> void:
	var run = pending; pending = {}
	game.features.choose_level(str(run.variant))
	var notes: Array = game.baseline_notes()
	if notes.is_empty(): status_label.text = "This chart could not be loaded."; return
	notes=notes.duplicate(true)
	for note in notes:
		if note.kind=="slide": note.ssrg_path=true
	status_label.text = ""
	stop_preview()
	running = run
	visible = false
	# SSRG visuals belong only to imported SSRG playables. Keep the user's normal
	# highway preference and restore it automatically when the run ends.
	game.ssrg_playable_previous_style=game.highway_style
	game.ssrg_playable_run=true
	game.ssrg_lane_count=Levels.number(str(run.variant))
	game.highway_style="ssrg"
	game.field.world.refresh_highway_look()
	game.start_game(notes,bool(run.auto))

func record_result() -> void:
	if bool(running.get("auto",false)): return
	var key = str(running.id)+"|"+str(running.variant)
	var previous = best(str(running.id),str(running.variant))
	if int(game.score) <= int(previous.get("score",-1)): return
	game.prefs.set_value("ssrg_best",key,{"score":int(game.score),"rank":game.rank_name(),"combo":int(game.max_combo),"accuracy":snappedf(game.accuracy(),.01)})
	game.prefs.save("user://preferences.cfg")
