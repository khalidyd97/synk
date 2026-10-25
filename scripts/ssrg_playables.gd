extends Control
const ScreenStyle = preload("res://scripts/screen_style.gd")
const Action = preload("res://scripts/settings_action.gd")
const Levels = preload("res://scripts/chart_levels.gd")
const SsrgImport = preload("res://scripts/ssrg_import.gd")
const BACKGROUND = preload("res://assets/lobby/city_background.png")
const TEXT = Color("eef0ff")
const MUTED = Color(.8,.82,.95,.6)
const ACCENT = Color("ffd36a")

# SSRG Playables (lobby button). The player picks the files of an SSRG song from their own copy
# of the game: the song audio (.bytes, really Ogg) and its 4, 7 and 13 key charts (.bytes).
# Importing adds the song to the library with one chart per key count (saved as Lv 4, Lv 7 and
# Lv 13), and the list on the right plays them.

var game: Control
var safe_content: Control
var picker: FileDialog
var staged_audio = ""
var staged_charts: Dictionary = {}
var staged_label: Label
var status_label: Label
var import_button: Button
var song_list: VBoxContainer
var pending: Dictionary = {}

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
	result.caption_size=18 if variant=="tool" else 22
	place(result,parent,left,top,right,bottom); result.pressed.connect(callback)
	return result

func panel(left: float, top: float, right: float, bottom: float) -> Panel:
	var result = Panel.new(); place(result,self,left,top,right,bottom)
	var style = StyleBoxFlat.new(); style.bg_color = Color(0.041,0.041,0.041,.84); style.set_corner_radius_all(22)
	style.border_color = Color(ACCENT,.30); style.set_border_width_all(1)
	result.add_theme_stylebox_override("panel",style)
	return result

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background = TextureRect.new(); place(background,self,0,0,1,1)
	background.texture = BACKGROUND; background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade = ColorRect.new(); place(shade,self,0,0,1,1); shade.color = Color(0.017,0.017,0.017,.86); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_content=game.safe_parent("SafeSsrgControls",self)
	action(self,"‹  BACK",.035,.035,.17,.15,close,"nav")
	text(self,"SSRG PLAYABLES",.2,.04,.7,.115,42)
	ScreenStyle.rule(self,.035,.965,.18)
	text(self,"Bring an SSRG song from your own game files and play it. For the SSRG look, pick Highway style → SSRG in Settings.",.2,.11,.93,.17,17,MUTED)

	var left = panel(.035,.2,.46,.95)
	text(left,"IMPORT A SONG",.07,.03,.93,.11,20,ACCENT)
	text(left,"Choose the song's .bytes files: the audio file (the large one) and its 4, 7 or 13 key charts. You can add them one at a time.",.07,.11,.93,.27,15,MUTED)
	action(left,"ADD FILES",.07,.29,.52,.41,choose_files)
	action(left,"CLEAR",.55,.29,.93,.41,clear_staged)
	staged_label = text(left,"",.07,.43,.93,.72,17)
	staged_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	import_button = action(left,"IMPORT SONG",.07,.74,.93,.87,import_staged,"primary")
	status_label = text(left,"",.07,.87,.93,.98,14,MUTED)

	var right = panel(.48,.2,.965,.95)
	text(right,"YOUR SSRG SONGS",.06,.03,.94,.11,20,ACCENT)
	var scroll = ScrollContainer.new(); place(scroll,right,.04,.13,.96,.97)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	song_list = VBoxContainer.new(); scroll.add_child(song_list)
	song_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	song_list.add_theme_constant_override("separation",10)

	picker = FileDialog.new(); add_child(picker)
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILES; picker.access = FileDialog.ACCESS_FILESYSTEM; picker.use_native_dialog = true
	picker.filters = PackedStringArray(["*.bytes,*.ogg;SSRG files;*/*"])
	picker.files_selected.connect(add_files)
	picker.file_selected.connect(func(path): add_files(PackedStringArray([path])))
	move_child(safe_content,get_child_count()-1)
	refresh_staged()

func open() -> void:
	pending = {}
	visible = true
	refresh_songs()

func close() -> void:
	visible = false
	game.close_ssrg_playables()

func choose_files() -> void:
	if OS.get_name()=="iOS":
		picker.access=FileDialog.ACCESS_USERDATA; picker.current_dir="user://"
		status_label.text = "In the Files app, copy the files into On My iPhone → SYNK first."
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
	status_label.text = "\n".join(problems)
	refresh_staged()

func clear_staged() -> void:
	staged_audio = ""; staged_charts.clear(); status_label.text = ""
	refresh_staged()

func refresh_staged() -> void:
	var lines: Array = []
	lines.append("Audio:  " + ("ready ✓" if not staged_audio.is_empty() else "not added yet"))
	for keys in [4,7,13]:
		var chart: Dictionary = staged_charts.get(keys,{})
		lines.append("%d keys:  %s" % [keys, "%d notes ✓" % chart.notes.size() if not chart.is_empty() else "—"])
	var title = staged_title()
	if not title.is_empty(): lines.push_front(title)
	staged_label.text = "\n".join(lines)
	import_button.disabled = staged_audio.is_empty() or staged_charts.is_empty()

func staged_title() -> String:
	for keys in staged_charts:
		if not str(staged_charts[keys].title).is_empty(): return str(staged_charts[keys].title)
	return ""

func import_staged() -> void:
	if staged_audio.is_empty() or staged_charts.is_empty(): return
	var library: SynkLibrary = game.library
	var result = library.import_song(staged_audio)
	if result.is_empty(): status_label.text = library.message; return
	var song: Dictionary = result.song
	var id = str(song.id)
	var any: Dictionary = staged_charts.values()[0]
	var title = staged_title()
	if not title.is_empty(): song.title = title
	song.bpm = float(any.bpm); song.album = "SSRG"
	var keys: Array = song.get("ssrg",[]).duplicate()
	var saved = 0
	for count in staged_charts:
		var chart: Dictionary = staged_charts[count]
		var length = result.stream.get_length()
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
	status_label.text = "Imported %s with %d chart%s." % [song.title, saved, "" if saved==1 else "s"]
	staged_audio = ""; staged_charts.clear()
	refresh_staged(); refresh_songs()

func refresh_songs() -> void:
	for child in song_list.get_children(): child.queue_free()
	var found = false
	for song in game.library.songs:
		if not song.has("ssrg"): continue
		found = true
		var row = Panel.new(); row.custom_minimum_size = Vector2(0,96)
		var style = StyleBoxFlat.new(); style.bg_color = Color(1,1,1,.04); style.set_corner_radius_all(16)
		row.add_theme_stylebox_override("panel",style)
		song_list.add_child(row)
		text(row,str(song.title),.04,.08,.5,.92,22)
		var levels: Array = []
		for count in song.ssrg:
			if FileAccess.file_exists(Levels.chart_path(str(song.id),Levels.key(int(count)))): levels.append(int(count))
		var width = .46/maxf(1,levels.size())
		for i in levels.size():
			var count: int = levels[i]
			action(row,"%dK" % count,.52+i*width,.16,.52+(i+1)*width-.015,.84,play.bind(str(song.id),Levels.key(count)),"primary" if i==levels.size()-1 else "tool")
	if not found:
		var empty = Label.new(); empty.text = "No SSRG songs yet. Import one on the left."
		empty.add_theme_color_override("font_color",MUTED); empty.add_theme_font_size_override("font_size",17)
		song_list.add_child(empty)

func play(id: String, variant: String) -> void:
	var index = -1
	for i in game.library.songs.size():
		if str(game.library.songs[i].id) == id: index = i + 1
	if index < 0: return
	game.prefs.set_value("charts",id,variant); game.prefs.save("user://preferences.cfg")
	pending = {"id":id,"variant":variant}
	status_label.text = "Loading…"
	if game.select_song(index): launch()

func _process(_delta: float) -> void:
	if not visible or pending.is_empty() or game.loading_song_index > 0: return
	if str(game.song.id) == str(pending.id): launch()
	else: pending = {}; status_label.text = "Could not load this song."

func launch() -> void:
	var variant = str(pending.variant); pending = {}
	game.features.choose_level(variant)
	var notes: Array = game.baseline_notes()
	if notes.is_empty(): status_label.text = "This chart could not be loaded."; return
	status_label.text = ""
	visible = false
	game.start_game(notes,false)
