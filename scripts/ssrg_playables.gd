extends Control
const ScreenStyle = preload("res://scripts/screen_style.gd")
const Action = preload("res://scripts/settings_action.gd")
const Levels = preload("res://scripts/chart_levels.gd")
const SsrgImport = preload("res://scripts/ssrg_import.gd")
const TEXT = Color("f4f1ea")
const MUTED = Color(.8,.82,.95,.6)
const ACCENT = Color("ffd36a")
const STAR = "★"
const STAR_OFF = "☆"
const KEY_COLORS = {4: Color("5fd0ff"), 7: Color("ffd36a"), 13: Color("ff8a5b")}

# SSRG Playables (lobby button). The player picks the files of an SSRG song from their own copy
# of the game: the song audio (.bytes, really Ogg) and its 4, 7 and 13 key charts (.bytes).
# Importing adds the song to the library with one chart per key count (saved as Lv 4, Lv 7 and
# Lv 13). Nothing from SSRG ships with SYNK.
#   Song select: the selected song's art fills the background. On the left, search, the tabs
#   with sort and shuffle, and a vertical list of compact song rows. On the right, the song
#   panel: cover, title, best result, difficulties, play settings, AUTO and START; song tools
#   are in its ··· menu. The header keeps only back, the title, ADD SONGS and settings.
#   ADD SONGS offers the import wizard or a scan; the scan reads the ssrg folder on the phone's storage:
#   ssrg/<GAME>/seq (charts), ssrg/<GAME>/music and ssrg/<GAME>/background, one game per folder. Songs play on the player's regular SYNK highway.

var game: Control
var safe_content: Control
var song_page:Control
var games_page:Control
var selected_game=""
var title_label:Label
var picker: FileDialog
var image_picker: FileDialog
# Which picture the image picker is choosing: "background" or "cover".
var image_target = "background"
var staged_audio = ""
var staged_charts: Dictionary = {}
var staged_label: Label
var import_status: Label
var import_button: Button
var import_panel: Control
var import_wizard:Control
var status_label: Label
var speed_label: Label
var note_size_button: Button
# Speed goes from 1.0 to 10.0 in steps of 0.1; holding − or + keeps stepping.
const SPEED_STEP = 0.1
var speed_held_step = 0.0
var speed_held_time = 0.0
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
# The selected song's panel (right side) and its fixed play settings, in screen fractions.
const HERO = Rect2(.425,.15,.555,.825)
var hero: Panel
var play_settings: Control
var add_button: Button
# A small menu opened from a button (Add songs, the song's ⋯), closed by tapping outside it.
var menu_layer: Control
func hero_rect(left: float, top: float, right: float, bottom: float) -> Rect2:
	return Rect2(HERO.position+HERO.size*Vector2(left,top),HERO.size*Vector2(right-left,bottom-top))
var carousel: ScrollContainer
var backdrop_layers:Array[TextureRect]=[]
var backdrop: TextureRect
var empty_label: Label
# Shown when no SSRG songs are imported yet: an illustration and the two ways to add songs.
var empty_state: Control
var list_arrows: Array = []
# Horizontal drag on the carousel: a press that moves is a scroll, not a card tap.
var carousel_press = false
var carousel_dragged = false
var carousel_tween: Tween
var carousel_drag:Node
var detail: Control
var selected_id = ""
var selected_variant = ""
var delete_armed = 0.0
var delete_button: Button
# Song whose row delete button was tapped once (a second tap within a few seconds deletes it).
var row_armed_id = ""
var pending: Dictionary = {}
# The run started from this screen: its best score is kept when the results appear.
var running: Dictionary = {}

func place(node: Control, parent: Control, left: float, top: float, right: float, bottom: float) -> void:
	if parent==self and safe_content!=null: parent=song_page if song_page!=null else safe_content
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
	# The selected song's art, dimmed, behind everything (refresh_detail swaps it).
	var base = ColorRect.new(); place(base,self,0,0,1,1); base.color = Color.WHITE; base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Signal Arcade lane grid; the selected game's art glows faintly over it.
	preload("res://scripts/background_motion.gd").attach(base,preload("res://scripts/song_browser_background.gdshader"))
	backdrop = TextureRect.new(); place(backdrop,self,0,0,1,1); backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(1,1,1,.55)
	# Album Takeover: the game's art becomes soft coloured light rather than a photo.
	var blur = ShaderMaterial.new(); blur.shader = preload("res://scripts/blurred_art.gdshader"); blur.set_shader_parameter("radius",0.0)
	backdrop.material = blur
	backdrop_layers.append(backdrop)
	var shade = TextureRect.new(); place(shade,self,0,0,1,1); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient = Gradient.new(); gradient.colors = PackedColorArray([Color(0.03,0.03,0.06,.5),Color(0.03,0.03,0.06,.05),Color(0.03,0.03,0.06,.55)])
	gradient.offsets = PackedFloat32Array([0,.45,1])
	var fill = GradientTexture2D.new(); fill.gradient = gradient; fill.fill_from = Vector2(0,0); fill.fill_to = Vector2(0,1)
	shade.texture = fill; shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; shade.stretch_mode = TextureRect.STRETCH_SCALE
	safe_content=game.safe_parent("SafeSsrgControls",self)
	song_page=Control.new();safe_content.add_child(song_page);song_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Header: back and the game's name on the left; adding songs and settings on the right.
	# Everything else lives where it is used: finding songs on the left, playing on the right.
	action(self,"‹  GAMES",.02,.03,.12,.12,show_games,"nav")
	title_label=text(self,"SSRG PLAYABLES",.135,.022,.6,.09,32)
	title_label.add_theme_font_override("font",preload("res://scripts/arcade_style.gd").SERIF)
	status_label = text(self,"Play SSRG songs from your own game files.",.135,.085,.6,.125,14,MUTED)
	logout_button = action(self,"LOG OUT",.685,.035,.775,.115,log_out,"small")
	add_button = action(self,"+  ADD SONGS",.785,.035,.925,.115,func(): open_menu(add_button,[["Choose files",open_import],["Scan phone folder",scan_phone]]),"small")
	game.settings_gear(self,.935,.035,.98,.115)

	# Left column: search, tabs with sort and shuffle, then the song list.
	search = LineEdit.new(); place(search,self,.02,.15,.4,.225)
	search.placeholder_text = "Search title, artist or album"; search.clear_button_enabled = true
	search.add_theme_font_size_override("font_size",17)
	for state in ["normal","focus"]:
		var field = box(Color(0,0,0,.3 if state=="normal" else .45),Color(1,1,1,.1) if state=="normal" else Color(ACCENT,.5),24)
		field.content_margin_left = 20; field.content_margin_right = 12
		search.add_theme_stylebox_override(state,field)
	search.text_changed.connect(func(_t): refresh_songs())
	# Game tabs (one per game folder, plus favourites).
	var tab_scroll = ScrollContainer.new(); place(tab_scroll,self,.02,.245,.255,.31)
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var tab_drag=preload("res://scripts/drag_scroll.gd").attach(tab_scroll);tab_drag.horizontal=true
	game_tabs = HBoxContainer.new(); tab_scroll.add_child(game_tabs); game_tabs.add_theme_constant_override("separation",6); game_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sort_button = action(self,"",.26,.245,.34,.31,cycle_sort,"small")
	action(self,"SHUFFLE",.345,.245,.4,.31,shuffle,"small")
	# The song list: one compact row per song, scrolling vertically.
	carousel = ScrollContainer.new(); place(carousel,self,.02,.33,.4,.975)
	carousel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	carousel.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	carousel_drag=preload("res://scripts/song_list_scroll.gd").new();carousel_drag.name="DragScroll";carousel_drag.scroll=carousel;carousel_drag.horizontal=false;carousel.add_child(carousel_drag)
	carousel_drag.on_press=func():
		carousel_press=true;carousel_dragged=false
		if carousel_tween:carousel_tween.kill()
	carousel_drag.on_drag=func():carousel_dragged=true
	carousel_drag.on_release=func():carousel_press=false
	song_list = VBoxContainer.new(); carousel.add_child(song_list)
	song_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	song_list.add_theme_constant_override("separation",6)
	empty_label = text(self,"",.03,.4,.39,.6,17,MUTED); empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Right: the selected song. The panel and the play settings stay; refresh_detail fills the rest.
	hero = Panel.new(); place(hero,self,HERO.position.x,HERO.position.y,HERO.end.x,HERO.end.y)
	hero.add_theme_stylebox_override("panel",box(Color(0.03,0.03,0.04,.72),Color(1,1,1,.08),28))
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_settings = Control.new(); place(play_settings,self,0,0,1,1); play_settings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r = hero_rect(.035,.79,.235,.95)
	var speed_box = Panel.new(); place(speed_box,play_settings,r.position.x,r.position.y,r.end.x,r.end.y)
	speed_box.add_theme_stylebox_override("panel",box(Color(1,1,1,.05),Color(1,1,1,.08),20)); speed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text(speed_box,"SPEED",0,.06,1,.36,12,MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hold_speed(action(speed_box,"−",.04,.38,.3,.92,func(): pass,"small"),-SPEED_STEP)
	speed_label = text(speed_box,"",.3,.36,.7,.94,22); speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hold_speed(action(speed_box,"+",.7,.38,.96,.92,func(): pass,"small"),SPEED_STEP)
	# SKD's own three note sizes (100%, 90%, 80%); SYNK's note-size setting doesn't apply here.
	r = hero_rect(.25,.79,.37,.95)
	var size_box = Panel.new(); place(size_box,play_settings,r.position.x,r.position.y,r.end.x,r.end.y)
	size_box.add_theme_stylebox_override("panel",box(Color(1,1,1,.05),Color(1,1,1,.08),20)); size_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text(size_box,"NOTE SIZE",0,.06,1,.36,12,MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_size_button = action(size_box,"",.08,.38,.92,.92,cycle_note_size,"small")
	empty_state = Control.new(); place(empty_state,self,.1,.16,.9,.92); empty_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art = Control.new(); place(art,empty_state,.3,0,.7,.42); art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(func(): draw_empty_art(art))
	var heading = text(empty_state,"No SSRG songs yet",0,.44,1,.56,30,TEXT); heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font",preload("res://scripts/arcade_style.gd").SERIF)
	var hint = text(empty_state,"Add .ssrg files or a folder of charts." + "\n" + "Songs with only some levels import too.",0,.56,1,.72,18,MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action(empty_state,"+  ADD SONGS",.2,.78,.49,.92,open_import,"primary")
	action(empty_state,"SCAN FOR SONGS",.51,.78,.8,.92,scan_phone,"large")
	empty_state.visible = false

	# Difficulties, song details and START are rebuilt for each selected song.
	detail = Control.new(); place(detail,self,0,0,1,1); detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	song_page.move_child(play_settings,song_page.get_child_count()-1)

	build_import_panel()
	picker = FileDialog.new(); add_child(picker)
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILES; picker.access = FileDialog.ACCESS_FILESYSTEM; picker.use_native_dialog = true
	picker.filters = PackedStringArray(["*.bytes,*.ogg;SSRG files;*/*"])
	picker.files_selected.connect(add_files)
	picker.file_selected.connect(func(path): add_files(PackedStringArray([path])))
	image_picker = FileDialog.new(); add_child(image_picker)
	image_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE; image_picker.access = FileDialog.ACCESS_FILESYSTEM; image_picker.use_native_dialog = true
	image_picker.filters = PackedStringArray(["*.png,*.jpg,*.jpeg;Images;image/png,image/jpeg"])
	image_picker.file_selected.connect(func(path): set_cover(path) if image_target=="cover" else set_background(path))
	move_child(safe_content,get_child_count()-1)
	preview_player = AudioStreamPlayer.new(); add_child(preview_player); preview_player.volume_db = -10
	var stored = game.prefs.get_value("ssrg","favorites",[])
	favorites = stored if stored is Array else []
	sort_mode = str(game.prefs.get_value("ssrg","sort","GAME"))
	if sort_mode not in SORTS: sort_mode = "GAME"
	refresh_staged(); refresh_speed(); refresh_sort_button()
	games_page=preload("res://scripts/ssrg_games.gd").new();games_page.host=self;safe_content.add_child(games_page);games_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func build_import_panel() -> void:
	import_wizard=preload("res://scripts/ssrg_import_wizard.gd").new();import_wizard.host=self
	place(import_wizard,self,0,0,1,1);import_panel=import_wizard

func open() -> void:
	pending = {}; delete_armed = 0
	visible = true
	logout_button.visible = game.app_login != null and game.app_login.required()
	show_games()
	for child in safe_content.get_children():
		if child is Control and child.visible and child!=detail and child!=import_panel:
			soft_reveal(child,minf(child.get_index()*.012,.10))

func show_games() -> void:
	close_menu();stop_preview();carousel_drag.stop()
	if import_wizard.job.busy():return
	import_wizard.hide();song_page.hide();games_page.show();games_page.refresh()
	selected_game="";backdrop.texture=null

func open_game(id:String) -> void:
	selected_game=preload("res://scripts/ssrg_game_catalog.gd").normalize(id)
	game_filter=selected_game;search.clear();selected_id=""
	games_page.hide();song_page.show()
	title_label.text=preload("res://scripts/ssrg_game_catalog.gd").display_name(selected_game)
	refresh_songs()

func back() -> void:
	if import_wizard.visible:
		if not import_wizard.job.busy():import_wizard.hide()
	elif song_page.visible:show_games()
	else:close()

func close() -> void:
	close_menu();stop_preview()
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
	if preview_enabled() and visible and song_page.visible and not selected_id.is_empty(): preview_delay = .45

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
	var songs = shown_songs() if not selected_game.is_empty() else ssrg_songs()
	var games = {}
	for song in songs: games[category(song)] = true
	var liked = favorites.filter(func(id): return songs.any(func(x): return str(x.id)==id)).size()
	status_label.text = ("%d songs  ·  %d favourites" % [songs.size(),liked]) if not selected_game.is_empty() else ("%d songs  ·  %d games  ·  %d favourites" % [songs.size(),games.size(),liked])

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
	var value = game.prefs.get_value("ssrg_best_v2",id+"|"+variant,{})
	return value if value is Dictionary else {}

func song_length(song: Dictionary) -> float:
	var meta: Dictionary = game.song_metadata.get(str(song.id),{})
	return float(meta.get("duration",song.get("length",0.0)))

func refresh_songs() -> void:
	if carousel_drag:carousel_drag.stop()
	if carousel_tween:carousel_tween.kill()
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
	for song in songs:
		var haystack = " ".join([str(song.title),str(song.get("artist","")),str(song.get("album",""))]).to_lower()
		if not query.is_empty() and not haystack.contains(query): continue
		shown += 1
		row_queue.append(song)
	empty_state.visible = songs.is_empty() and game_filter != STAR
	# With no songs at all, only the empty state shows; the song panel needs a song.
	for node in [hero,play_settings,carousel,search,sort_button]: node.visible = not empty_state.visible
	hero.visible = hero.visible and shown > 0; play_settings.visible = hero.visible
	empty_label.text = "" if shown > 0 or empty_state.visible else ("No favourites yet. Tap the star on a song." if game_filter == STAR else "No songs match your search.")
	carousel.scroll_vertical = 0
	refresh_detail(); refresh_stats()

func in_filter(song: Dictionary) -> bool:
	if not selected_game.is_empty() and category(song)!=selected_game:return false
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
	return preload("res://scripts/ssrg_game_catalog.gd").category(song)

func refresh_game_tabs(songs: Array) -> void:
	for child in game_tabs.get_children():game_tabs.remove_child(child);child.queue_free()
	if not selected_game.is_empty():
		for favorite in [false,true]:
			var tab=Action.new();tab.text="FAVOURITES" if favorite else "SONGS";tab.caption_size=15;tab.custom_minimum_size=Vector2(140,38);tab.primary=(game_filter==STAR)==favorite
			tab.pressed.connect(func():game_filter=STAR if favorite else selected_game;refresh_songs());game_tabs.add_child(tab)
		return
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

# One carousel card: cover, title, artist, key counts with best ranks, and a favourite star.
func song_row(song: Dictionary) -> Control:
	# A compact row: small cover, title over artist, key counts and a favourite star on the right.
	var id = str(song.id)
	var height = ROW_HEIGHT
	var card = Button.new(); card.custom_minimum_size = Vector2(0,height); card.focus_mode = Control.FOCUS_NONE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true; card.set_meta("song_id",id)
	style_row(card,id == selected_id)
	card.pressed.connect(func():
		if carousel_dragged or id == selected_id: return
		select_song(id))
	var art_size = height-20.0
	var cover = TextureRect.new(); card.add_child(cover); cover.position = Vector2(14,10); cover.size = Vector2(art_size,art_size)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE; cover.texture = game.cover_texture_for_id(id)
	if not game.has_custom_cover(id): cover.modulate = game.cover_tint_for_id(id)
	var text_left = 14.0+art_size+16.0
	var title = Label.new(); card.add_child(title); title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.set_anchors_preset(Control.PRESET_TOP_WIDE); title.offset_left = text_left; title.offset_right = -190; title.offset_top = height*.17; title.offset_bottom = height*.5
	title.text = str(song.title); title.clip_text = true; title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size",19); title.add_theme_color_override("font_color",TEXT)
	var byline = Label.new(); card.add_child(byline); byline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	byline.set_anchors_preset(Control.PRESET_TOP_WIDE); byline.offset_left = text_left; byline.offset_right = -190; byline.offset_top = height*.5; byline.offset_bottom = height*.82
	byline.text = str(song.get("artist","")) if not str(song.get("artist","")).is_empty() else category(song)
	byline.clip_text = true; byline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	byline.add_theme_font_size_override("font_size",15); byline.add_theme_color_override("font_color",MUTED)
	# Key counts, each with its best rank once played.
	var chips = HBoxContainer.new(); card.add_child(chips); chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.set_anchors_preset(Control.PRESET_RIGHT_WIDE); chips.offset_left = -186; chips.offset_right = -62; chips.offset_top = height*.3; chips.offset_bottom = -height*.3
	chips.alignment = BoxContainer.ALIGNMENT_END
	chips.add_theme_constant_override("separation",4)
	for chart in charts_for(id):
		var color: Color = KEY_COLORS.get(int(chart.keys),ACCENT)
		var record = best(id,chart.variant)
		var chip = Label.new(); chip.text = " %dK%s " % [int(chart.keys)," "+str(record.rank) if record.has("rank") else ""]
		chip.add_theme_font_size_override("font_size",13); chip.add_theme_color_override("font_color",color)
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_stylebox_override("normal",box(Color(color,.1),Color(color,.4),10))
		chips.add_child(chip)
	var star = Button.new(); card.add_child(star); star.focus_mode = Control.FOCUS_NONE
	star.set_anchors_preset(Control.PRESET_CENTER_RIGHT); star.offset_left = -54; star.offset_right = -10; star.offset_top = -22; star.offset_bottom = 22
	star.add_theme_font_size_override("font_size",22)
	var clear = StyleBoxEmpty.new()
	for state in ["normal","hover","pressed","focus"]: star.add_theme_stylebox_override(state,clear)
	style_star(star,is_favorite(id)); star.tooltip_text = "Favourite"
	star.pressed.connect(func():
		if carousel_dragged: return
		toggle_favorite(id))
	rows[id] = {"row":card,"trash":null,"star":star}
	return card
const ROW_HEIGHT = 92.0

func soft_reveal(target:Control,delay:float=0.0) -> void:
	if not target.is_visible_in_tree():return
	var previous:Tween=target.get_meta("ssrg_reveal") if target.has_meta("ssrg_reveal") else null
	if previous:previous.kill()
	target.modulate.a=.18
	target.pivot_offset=target.size*.5
	target.scale=Vector2.ONE*.99
	var tween=target.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target,"modulate:a",1.0,.24).set_delay(delay)
	tween.tween_property(target,"scale",Vector2.ONE,.28).set_delay(delay)
	target.set_meta("ssrg_reveal",tween)

func change_backdrop(texture:Texture2D) -> void:
	texture=preload("res://scripts/gaussian_blur.gd").of(texture,32,3.2)
	if backdrop.texture==texture:return
	# Fade from every live layer's current opacity; rapid selection never restarts a fade at full opacity.
	for layer in backdrop_layers.duplicate():
		var previous:Tween=layer.get_meta("ssrg_fade") if layer.has_meta("ssrg_fade") else null
		if previous:previous.kill()
		var fade=layer.create_tween()
		fade.tween_property(layer,"modulate:a",0.0,.32)
		fade.tween_callback(func():backdrop_layers.erase(layer);layer.queue_free())
		layer.set_meta("ssrg_fade",fade)
	backdrop=TextureRect.new();add_child(backdrop);move_child(backdrop,1)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture=texture;backdrop.modulate=Color(1,1,1,0)
	var blur=ShaderMaterial.new(); blur.shader=preload("res://scripts/blurred_art.gdshader"); blur.set_shader_parameter("radius",0.0); backdrop.material=blur
	backdrop_layers.append(backdrop)
	var fade=backdrop.create_tween()
	fade.tween_property(backdrop,"modulate:a",.55,.32)
	backdrop.set_meta("ssrg_fade",fade)

func style_row(row: Button, selected: bool) -> void:
	# Rows sit quietly on the page; the selected one gets a lighter plate and a gold edge.
	var normal = box(Color(1,1,1,.09) if selected else Color(0,0,0,.18),Color(ACCENT,.9) if selected else Color(0,0,0,0),18)
	normal.set_border_width_all(0)
	if selected: normal.border_width_left = 5
	var hover = normal.duplicate(); hover.bg_color = Color(1,1,1,.12) if selected else Color(1,1,1,.05)
	for state in ["normal","focus"]: row.add_theme_stylebox_override(state,normal)
	for state in ["hover","pressed"]: row.add_theme_stylebox_override(state,hover)
	var scale_target=Vector2.ONE
	var tint=Color.WHITE if selected else Color(1,1,1,.86)
	var previous:Tween=row.get_meta("ssrg_selection") if row.has_meta("ssrg_selection") else null
	if previous:previous.kill()
	if not row.is_inside_tree():row.scale=scale_target;row.modulate=tint;return
	var tween=row.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(row,"scale",scale_target,.24)
	tween.tween_property(row,"modulate",tint,.24)
	row.set_meta("ssrg_selection",tween)

func select_song(id: String) -> void:
	if rows.has(selected_id) and is_instance_valid(rows[selected_id].row): style_row(rows[selected_id].row,false)
	selected_id = id; selected_variant = ""; delete_armed = 0; disarm_row()
	if rows.has(id): style_row(rows[id].row,true)
	center_selected(true)
	refresh_detail()
	schedule_preview()

# Previous or next song in the carousel.
func step_song(direction: int) -> void:
	var ids: Array = []
	for child in song_list.get_children():
		if child.has_meta("song_id"): ids.append(str(child.get_meta("song_id")))
	if ids.is_empty(): return
	var at = ids.find(selected_id)
	select_song(ids[clampi(at+direction,0,ids.size()-1)] if at >= 0 else ids[0])

func center_selected(animate: bool) -> void:
	if not rows.has(selected_id) or not is_instance_valid(rows[selected_id].row): return
	var card: Control = rows[selected_id].row
	if not card.is_inside_tree(): return
	# Scroll only as far as needed to show the whole row.
	var top = carousel.scroll_vertical; var view = carousel.size.y
	var target = top
	if card.position.y < top: target = int(card.position.y)
	elif card.position.y+card.size.y > top+view: target = int(card.position.y+card.size.y-view)
	if carousel_tween: carousel_tween.kill()
	if carousel_drag:carousel_drag.stop()
	if target == top: return
	if not animate: carousel.scroll_vertical = target; return
	carousel_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	carousel_tween.tween_property(carousel,"scroll_vertical",target,.24)


func disarm_row() -> void:
	if rows.has(row_armed_id) and rows[row_armed_id].trash != null and is_instance_valid(rows[row_armed_id].trash):
		rows[row_armed_id].trash.text = "✕"; rows[row_armed_id].trash.anchor_left = .86
		if rows[row_armed_id].has("star") and is_instance_valid(rows[row_armed_id].star): rows[row_armed_id].star.visible = true
	row_armed_id = ""

func refresh_detail() -> void:
	for child in detail.get_children():
		detail.remove_child(child);child.queue_free()
	delete_button = null
	var song: Dictionary = {}
	for s in ssrg_songs():
		if str(s.id) == selected_id: song = s
	if song.is_empty():
		change_backdrop(null)
		return
	var id = str(song.id)
	# The song's own background or album art; songs without art keep the plain backdrop.
	change_backdrop(game.stage_backdrop_for_id(id))

	# The song panel (HERO, right side): cover and facts on top, difficulties across the middle,
	# play settings, AUTO and START along the bottom. Song tools sit in the ⋯ menu.
	var charts = charts_for(id)
	if not charts.is_empty() and not charts.any(func(c): return c.variant == selected_variant): selected_variant = charts[-1].variant
	var chosen_chart: Dictionary = {}
	for chart in charts:
		if chart.variant == selected_variant: chosen_chart = chart
	var r = hero_rect(.035,.055,.3,.47)
	var frame = Panel.new(); place(frame,detail,r.position.x,r.position.y,r.end.x,r.end.y); frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel",box(Color(0,0,0,.4),Color(1,1,1,.1),20)); frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var cover = TextureRect.new(); frame.add_child(cover); cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE; cover.texture = game.cover_texture_for_id(id)
	if not game.has_custom_cover(id): cover.modulate = game.cover_tint_for_id(id)
	# Title, favourite and the ⋯ menu.
	r = hero_rect(.33,.055,.8,.17)
	var heading = text(detail,str(song.title),r.position.x,r.position.y,r.end.x,r.end.y,34)
	heading.add_theme_font_override("font",preload("res://scripts/arcade_style.gd").SERIF)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF; heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	r = hero_rect(.815,.06,.89,.165)
	var star = Button.new(); place(star,detail,r.position.x,r.position.y,r.end.x,r.end.y); star.focus_mode = Control.FOCUS_NONE
	star.add_theme_font_size_override("font_size",28)
	for state in ["normal","hover","pressed","focus"]: star.add_theme_stylebox_override(state,box(Color(1,1,1,.06 if state=="normal" else .12),Color(1,1,1,.08),22))
	style_star(star,is_favorite(id)); star.tooltip_text = "Favourite"
	star.pressed.connect(func(): toggle_favorite(id))
	r = hero_rect(.9,.06,.965,.165)
	var more: Button = action(detail,"···",r.position.x,r.position.y,r.end.x,r.end.y,func(): pass,"small")
	more.tooltip_text = "Song options"
	more.pressed.connect(func(): open_menu(more,song_tools(id)))
	var length = song_length(song)
	var facts: Array = [str(song.get("artist","")),category(song)].filter(func(t): return not t.is_empty())
	if length > 0: facts.append(game.lobby.duration_text(length))
	if float(song.get("bpm",0)) > 0: facts.append("%d BPM" % roundi(float(song.bpm)))
	r = hero_rect(.33,.17,.965,.245)
	text(detail,"  ·  ".join(facts),r.position.x,r.position.y,r.end.x,r.end.y,17,MUTED)
	# Best result on the chosen difficulty, as a small score card.
	r = hero_rect(.33,.29,.965,.47)
	var card = Panel.new(); place(card,detail,r.position.x,r.position.y,r.end.x,r.end.y); card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel",box(Color(1,1,1,.04),Color(1,1,1,.07),20))
	if chosen_chart.is_empty():
		text(card,"This song has no playable charts. Import its chart files again.",.05,.1,.95,.9,15,MUTED)
	else:
		var record = best(id,selected_variant)
		text(card,"BEST · %dK" % int(chosen_chart.keys),.05,.1,.5,.36,12,MUTED)
		if record.is_empty():
			text(card,"Not played yet",.05,.36,.6,.86,24,Color(TEXT,.75))
		else:
			var rank = text(card,str(record.get("rank","")),.05,.3,.22,.92,40,ACCENT)
			rank.add_theme_font_override("font",preload("res://scripts/arcade_style.gd").SERIF)
			text(card,"%s" % str(record.get("score",0)),.22,.32,.6,.66,26)
			text(card,"Max combo %d" % int(record.get("combo",0)),.22,.62,.6,.9,14,MUTED)
		var stats = text(card,"%d notes\n%.1f notes / sec" % [int(chosen_chart.notes),float(chosen_chart.get("density",0))],.6,.15,.95,.85,15,MUTED)
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Difficulties: one segment per chart, fewest keys first.
	r = hero_rect(.035,.52,.5,.57)
	text(detail,"DIFFICULTY",r.position.x,r.position.y,r.end.x,r.end.y,13,MUTED)
	var count = maxi(1,charts.size())
	for i in charts.size():
		var chart: Dictionary = charts[i]
		var chosen = chart.variant == selected_variant
		var color: Color = KEY_COLORS.get(int(chart.keys),ACCENT)
		var span = (.93-.02*(count-1))/count
		r = hero_rect(.035+i*(span+.02),.585,.035+i*(span+.02)+span,.735)
		var pick = Button.new(); place(pick,detail,r.position.x,r.position.y,r.end.x,r.end.y); pick.focus_mode = Control.FOCUS_NONE
		var style = box(Color(color,.9) if chosen else Color(0,0,0,.28),Color(color,1.0) if chosen else Color(color,.35),22)
		style.set_border_width_all(2)
		var hover = style.duplicate(); hover.bg_color = Color(color,.9) if chosen else Color(color,.12)
		for state in ["normal","focus"]: pick.add_theme_stylebox_override(state,style)
		for state in ["hover","pressed"]: pick.add_theme_stylebox_override(state,hover)
		pick.pressed.connect(func(): selected_variant = chart.variant; refresh_detail())
		var ink = Color(0.06,0.05,0.07) if chosen else color
		var keys = text(pick,"%d KEYS" % int(chart.keys),0,.1,1,.6,24,ink)
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var record = best(id,chart.variant)
		var under = "%d notes" % int(chart.notes) + ("  ·  " + str(record.rank) if record.has("rank") else "")
		var notes = text(pick,under,0,.56,1,.9,14,Color(ink,.75) if chosen else MUTED)
		notes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not charts.is_empty():
		r = hero_rect(.4,.79,.555,.95)
		action(detail,"AUTO",r.position.x,r.position.y,r.end.x,r.end.y,func(): play(id,selected_variant,true))
		r = hero_rect(.575,.79,.965,.95)
		var start = action(detail,"START",r.position.x,r.position.y,r.end.x,r.end.y,func(): play(id,selected_variant,false),"primary")
		start.caption_size = 30
	for child in detail.get_children():
		if child is Control:soft_reveal(child,minf(child.get_index()*.018,.08))

# The song's ⋯ menu. Delete keeps the menu open: its first tap arms it, the second deletes.
func song_tools(id: String) -> Array:
	var tools: Array = [["Song details",func(): game.open_song_details(selected_id)],["Change cover",choose_cover],["Change background",choose_background]]
	if game.has_custom_cover(id): tools.append(["Remove cover",func(): game.remove_cover(id); refresh_songs()])
	if game.has_background(id): tools.append(["Remove background",func(): game.remove_background(id); refresh_detail()])
	tools.append(["Preview: " + ("on" if preview_enabled() else "off"),toggle_preview])
	tools.append(["Delete song",delete_selected,true])
	return tools

func open_menu(anchor: Control, items: Array) -> void:
	close_menu()
	menu_layer = Control.new(); add_child(menu_layer); menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var catcher = Button.new(); menu_layer.add_child(catcher); catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.focus_mode = Control.FOCUS_NONE
	for state in ["normal","hover","pressed","focus"]: catcher.add_theme_stylebox_override(state,box(Color(0,0,0,.25),Color(0,0,0,0),0))
	catcher.pressed.connect(close_menu)
	var row_height = 64.0; var width = maxf(300.0,anchor.size.x)
	var sheet = Panel.new(); menu_layer.add_child(sheet)
	sheet.add_theme_stylebox_override("panel",box(Color(0.07,0.065,0.08,.97),Color(1,1,1,.12),22))
	var corner = anchor.get_global_rect().end - menu_layer.get_global_rect().position
	sheet.size = Vector2(width,items.size()*row_height+16)
	sheet.position = Vector2(clampf(corner.x-width,8,menu_layer.size.x-width-8),minf(corner.y+10,menu_layer.size.y-sheet.size.y-8))
	for i in items.size():
		var item: Array = items[i]
		var button = Button.new(); sheet.add_child(button); button.focus_mode = Control.FOCUS_NONE
		button.position = Vector2(8,8+i*row_height); button.size = Vector2(width-16,row_height-4)
		button.text = "   " + str(item[0]); button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size",19)
		var danger = str(item[0]).begins_with("Delete")
		for color_state in ["font_color","font_hover_color","font_pressed_color"]: button.add_theme_color_override(color_state,Color("ff8a7a") if danger else TEXT)
		for state in ["normal","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for state in ["hover","pressed"]: button.add_theme_stylebox_override(state,box(Color(1,1,1,.08),Color(0,0,0,0),14))
		var keep_open = item.size() > 2 and bool(item[2])
		if keep_open: delete_button = button
		var callback: Callable = item[1]
		button.pressed.connect(func():
			if not keep_open: close_menu()
			callback.call())

func close_menu() -> void:
	if menu_layer and is_instance_valid(menu_layer): menu_layer.queue_free()
	menu_layer = null

func change_speed(step: float) -> void:
	game.prefs.set_value("ssrg","speed_value",clampf(snappedf(game.ssrg_speed_setting()+step,SPEED_STEP),1.0,10.0))
	game.prefs.save("user://preferences.cfg")
	refresh_speed()

# One step on touch, then repeating while held (also used by the pause menu's − and +).
func hold_speed(button: BaseButton, step: float) -> void:
	button.button_down.connect(func(): change_speed(step); speed_held_step = step; speed_held_time = 0.0)
	button.button_up.connect(func(): speed_held_step = 0.0)

func repeat_held_speed(delta: float) -> void:
	if speed_held_step == 0.0: return
	var before = speed_held_time; speed_held_time += delta
	# After 0.4 s, about 12 steps a second.
	var steps = int(maxf(0.0,speed_held_time-.4)/.08)-int(maxf(0.0,before-.4)/.08)
	for i in steps: change_speed(speed_held_step)

func refresh_speed() -> void:
	speed_label.text = "%.1f" % game.ssrg_speed_setting()
	if note_size_button: note_size_button.text = "%d%%" % roundi(game.ssrg_note_scale()*100.0)

func cycle_note_size() -> void:
	game.prefs.set_value("ssrg","note_scale_index",(game.ssrg_note_scale_index()+1)%game.SSRG_NOTE_SCALES.size())
	game.prefs.save("user://preferences.cfg")
	refresh_speed()

# --- Actions ---------------------------------------------------------------------------
func choose_background() -> void:
	image_target = "background"
	if NativeFilePicker.open_image(func(paths): set_background(paths[0])): return
	if OS.get_name()=="iOS": image_picker.access=FileDialog.ACCESS_USERDATA; image_picker.current_dir="user://"
	image_picker.popup_centered_ratio(.8)

func choose_cover() -> void:
	image_target = "cover"
	if NativeFilePicker.open_image(func(paths): set_cover(paths[0])): return
	if OS.get_name()=="iOS": image_picker.access=FileDialog.ACCESS_USERDATA; image_picker.current_dir="user://"
	image_picker.popup_centered_ratio(.8)

func set_cover(path: String) -> void:
	var picked = game.load_picked_image(path)
	if picked is String: status_label.text = picked; return
	var problem = game.save_cover_image(selected_id,picked)
	refresh_songs(); refresh_detail()
	status_label.text = problem if not problem.is_empty() else "Cover saved."

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
		if delete_button: delete_button.text = "   Tap again to delete"
		return
	delete_song(selected_id)

func delete_song(id: String) -> void:
	close_menu()
	delete_armed = 0; row_armed_id = ""; chart_cache.erase(id)
	var title = ""
	for s in ssrg_songs():
		if str(s.id) == id: title = str(s.title)
	if str(game.song.id) == id: game.select_song(0)
	if game.library.delete_song(id) != OK: status_label.text = "Could not delete this song."; return
	for count in [4,7,13]:
		var key = id+"|"+Levels.key(count)
		if game.prefs.has_section_key("ssrg_best",key): game.prefs.erase_section_key("ssrg_best",key)
		if game.prefs.has_section_key("ssrg_best_v2",key): game.prefs.erase_section_key("ssrg_best_v2",key)
	game.prefs.save("user://preferences.cfg")
	game.song_metadata.erase(id)
	game.refresh_library()
	if game.lobby: game.lobby.refresh()
	if selected_id == id: selected_id = ""
	status_label.text = "Deleted %s." % title
	refresh_songs()

# --- Import ----------------------------------------------------------------------------
func open_import() -> void:
	if selected_game.is_empty():show_games();return
	import_wizard.open()

func choose_files() -> void:
	import_wizard.open();import_wizard.choose_files()

func add_files(paths:PackedStringArray) -> void:
	import_wizard.open();import_wizard.add_sources(paths)

func clear_staged() -> void:
	staged_audio="";staged_charts.clear();import_wizard.clear()

func refresh_staged() -> void:
	# Kept for older callers; the review wizard owns its current selection.
	if import_wizard:import_wizard.update_controls()

func staged_title() -> String:
	for keys in staged_charts:
		if not str(staged_charts[keys].title).is_empty(): return str(staged_charts[keys].title)
	return ""

func import_staged() -> void:
	import_wizard.start_import()

func store_song(audio_path:String,charts:Dictionary,meta:Dictionary) -> Dictionary:
	# Compatibility entry point; interactive imports prepare on the worker instead.
	var item={"audio":audio_path,"audio_hash":FileAccess.get_sha256(audio_path),"charts":{},"parsed_charts":charts,"selected_keys":charts.keys(),"title":str(meta.get("title","Imported song")),"artist":str(meta.get("artist","")),"game":str(meta.get("album","SSRG")),"background":str(meta.get("background","")),"policy":"add_missing"}
	if not selected_game.is_empty():item.target_game=selected_game;item.game=selected_game
	if meta.get("presentation") is Dictionary:item.presentation=meta.presentation
	var transaction=preload("res://scripts/ssrg_import_transaction.gd")
	var prepared=transaction.prepare(game.library.root_path,item,game.library.songs)
	var result=transaction.commit(game.library.root_path,prepared,game.library.songs)
	if result.has("songs"):
		game.library.songs=result.songs;chart_cache.erase(str(result.id));game.song_metadata.erase(str(result.id));game.song_background_textures.erase(str(result.id))
	return result

func phone_root() -> String:
	if OS.get_name() == "Android": return "/storage/emulated/0/ssrg"
	if OS.get_name() == "iOS": return "user://ssrg"
	# Desktop: an "ssrg" folder beside Documents (for testing).
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).get_base_dir().path_join("ssrg")

func scan_phone() -> void:
	if import_wizard.job.busy():import_wizard.open();return
	if OS.get_name()=="Android" and "android.permission.MANAGE_EXTERNAL_STORAGE" not in OS.get_granted_permissions():
		OS.request_permission("android.permission.MANAGE_EXTERNAL_STORAGE")
		status_label.text="Allow All files access for SYNK, then tap SCAN PHONE again."
		return
	import_wizard.open()
	var folder=phone_root()
	if DirAccess.dir_exists_absolute(folder):import_wizard.add_sources(PackedStringArray([folder]))
	else:import_wizard.choose_folder()


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
	repeat_held_speed(delta)
	finish_preview_load()
	if preview_delay >= 0:
		preview_delay -= delta
		if preview_delay < 0: start_preview()
	for i in mini(ROWS_PER_FRAME,row_queue.size()):
		var item = row_queue.pop_front()
		song_list.add_child(item if item is Control else song_row(item))
	if delete_armed > 0:
		delete_armed -= delta
		if delete_armed <= 0:
			if delete_button and is_instance_valid(delete_button): delete_button.text = "   Delete song"
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
	game.prefs.set_value("ssrg_best_v2",key,{"score":int(game.score),"rank":game.rank_name(),"combo":int(game.max_combo),"accuracy":snappedf(game.accuracy(),.01)})
	game.prefs.save("user://preferences.cfg")

# Stacked cover cards with a play mark and a coral "+": the empty library's illustration.
func draw_empty_art(art: Control) -> void:
	var side = minf(art.size.x,art.size.y)*.78; var c = art.size*.5
	for card in [[Vector2(-side*.18,side*.04),-.17,Color(1,1,1,.13)],[Vector2(side*.16,-side*.02),.14,Color("34323a")],[Vector2.ZERO,0.0,Color("f4f1ea")]]:
		art.draw_set_transform(c+card[0],card[1],Vector2.ONE)
		var plate = StyleBoxFlat.new(); plate.bg_color = card[2]; plate.set_corner_radius_all(roundi(side*.14))
		art.draw_style_box(plate,Rect2(-Vector2.ONE*side*.5,Vector2.ONE*side))
	art.draw_set_transform(Vector2.ZERO)
	var r = side*.2
	art.draw_colored_polygon(PackedVector2Array([c+Vector2(-r*.6,-r*.8),c+Vector2(r*.9,0),c+Vector2(-r*.6,r*.8)]),Color("1a1720"))
	var badge = c+Vector2(side*.52,-side*.46)
	art.draw_circle(badge,side*.12,Color("ff8a5b"))
	preload("res://scripts/ui_icons.gd").draw(art,"add",badge,side*.16,Color.WHITE)
