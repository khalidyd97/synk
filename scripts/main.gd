extends Control

const UiMotion = preload("res://scripts/ui_motion.gd")
const NeonAction = preload("res://scripts/neon_action.gd")
const ECLIPSE_COVER = preload("res://assets/lobby/eclipse_cover.png")
const CUSTOM_COVER = preload("res://assets/lobby/custom_cover.png")

const COMBO_ATLAS = preload("res://assets/hud/Combo_Digits_1_to_9.png")
const COMBO_ZERO = preload("res://assets/hud/Combo_Digit_0.png")
const JUDGEMENT_ART = {
	"PERFECT": preload("res://assets/hud/PERFECT.png"),
	"GREAT": preload("res://assets/hud/GREAT.png"),
	"GOOD": preload("res://assets/hud/GOOD.png"),
	"MISS": preload("res://assets/hud/MISS.png")
}

var library = SynkLibrary.new()
var document = SynkChart.new()
var capture = SynkCapture.new()
var audio = AudioStreamPlayer.new()
var demo_stream: AudioStream
var song_metadata: Dictionary = {}
var song_cover_textures: Dictionary = {}
var metadata_queue: Array[String] = []
var metadata_worker = Thread.new()
var worker_song_id = ""
var loading_song_index = -1
var loading_open_editor = false
var song = {"id":"eclipse", "title":"Eclipse", "bpm":128.0}
var saved_notes: Array = []
var mode = "menu"
var paused_mode = "play"
var auto_play = false
var pause_had_audio = false
var song_time = 0.0
var visual_song_time = 0.0
var visual_clock_ready = false
var live: Array = []
var pointers: Dictionary = {}
var score = 0
var displayed_score = 0.0
var combo = 0
var combo_pulse = 0.0
var rank_pulse = 0.0
var shown_rank = ""
var hud_motion_time = 0.0
var hold_pulse_time = 0.0
var max_combo = 0
var earned = 0.0
var judged = 0
var flash = 0.0
var flash_lane = 6
var judgement = ""
var judgement_kind = "tap"
var countdown = 0.0
var resume_countdown = 0.0
var resume_start_audio = false
var start_position = 0.0
var timing_ms = 0.0
var bluetooth_mode = false
var bluetooth_latency_ms = 180.0
var note_speed = 1.0
var resume_grace = 0.0
var overdub = false
var tool = "auto"
var cursor = 0.0
var zoom_seconds = 8.0
var snap_division = 4
var loop_a = 0.0
var loop_b = 8.0
var loop_enabled = false
var audition_speed = 1.0
var waveform: PackedFloat32Array = []
var prefs = ConfigFile.new()
var field: Control
var ui: Control
var lobby: Control
var chart_library: Control
var menu_settings_open = false
var modal: Panel
var pause_backdrop: ColorRect
var pause_tween: Tween
var modal_title: Label
var modal_body: Label
var settings_panel: Control
var bluetooth_toggle: CheckButton
var bluetooth_latency_input: SpinBox
var primary: Button
var pause_home: Button
var pause_restart: Button
var countdown_label: Label
var actions: Control
var hud: Label
var combo_hud: Control
var combo_digit_textures: Array[Texture2D] = []
var combo_art_value = -1
var combo_art_size = Vector2.ZERO
var song_hud: Label
var rank_hud: Label
var difficulty_hud: Label
var auto_play_hud: Label
var guide_button: Button
var guide_back: Button
var hit_label: Label
var hit_art: TextureRect
var pause_button: Button
var record_tools: Control
var studio: Panel
var studio_cover: TextureRect
var studio_cover_button: Button
var status: Label
var info: Label
var title_label: Label
var play_button: Button
var snap_button: Button
var loop_button: Button
var speed_button: Button
var seek: HSlider
var timeline: Control
var song_list: ItemList
var picker: FileDialog
var cover_picker: FileDialog
var bpm_input: SpinBox
var updating = false
var last_play_notes: Array = []
var record_info: Label
var record_help: Label
var arrange_button: Button
var kind_buttons: Array[Button] = []
var arrange_selection: Dictionary = {}
var arranging = false
var arrange_touches: Dictionary = {}

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	process_priority=-10
	Engine.max_fps = 120
	if OS.has_feature("android"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	prefs.load("user://preferences.cfg"); timing_ms = float(prefs.get_value("audio","offset_ms",0))
	bluetooth_mode=bool(prefs.get_value("audio","bluetooth_mode",false))
	bluetooth_latency_ms=clampf(float(prefs.get_value("audio","bluetooth_latency_ms",180)),0,600)
	note_speed = clampf(float(prefs.get_value("gameplay","note_speed",1.0)), .5, 3.0)
	add_child(audio); demo_stream = SynkLibrary.synth_demo(); audio.stream = demo_stream
	audio.finished.connect(_audio_finished)
	field = Control.new(); field.set_script(load("res://scripts/highway.gd")); field.game = self; add_child(field); field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui = Control.new(); add_child(ui); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_safe_area(); get_viewport().size_changed.connect(apply_safe_area)
	build_combo_digit_textures()
	build_ui()
	lobby=Control.new(); lobby.set_script(load("res://scripts/lobby.gd")); lobby.game=self
	ui.add_child(lobby); lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.move_child(lobby,0)
	build_studio()
	chart_library=Control.new(); chart_library.set_script(load("res://scripts/chart_library.gd")); chart_library.game=self
	ui.add_child(chart_library); chart_library.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.move_child(chart_library,1)
	saved_notes = library.load_chart("eclipse")
	get_window().files_dropped.connect(func(files):
		if files.size()>0 and mode in ["menu","library","editor"]:
			open_editor(); import_audio(files[0]))
	get_tree().auto_accept_quit = false
	set_mode("menu")
	build_waveform()
	queue_song_metadata()

func _exit_tree() -> void:
	if not worker_song_id.is_empty(): metadata_worker.wait_to_finish()

func queue_song_metadata() -> void:
	for entry in library.songs:
		var id=str(entry.id)
		if not song_metadata.has(id) and worker_song_id!=id and not metadata_queue.has(id): metadata_queue.append(id)
	start_song_worker()

func song_entry_for_id(id: String) -> Dictionary:
	for entry in library.songs:
		if str(entry.id)==id: return entry
	return {}

func start_song_worker() -> void:
	if not worker_song_id.is_empty(): return
	if loading_song_index<0 and mode in ["play","record","paused"]: return
	var id=""
	if loading_song_index>0 and loading_song_index<=library.songs.size(): id=str(library.songs[loading_song_index-1].id)
	elif not metadata_queue.is_empty(): id=metadata_queue.pop_front()
	if id.is_empty(): return
	var entry=song_entry_for_id(id)
	if entry.is_empty(): return
	metadata_queue.erase(id)
	worker_song_id=id
	var analyze=not song_metadata.has(id)
	var audio_path="user://songs/"+str(entry.file)
	var chart_path="user://charts/"+id+".json"
	var error=metadata_worker.start(SynkLibrary.inspect_song.bind(audio_path,chart_path,id,cover_path(id),analyze))
	if error!=OK:
		worker_song_id=""
		if loading_song_index>0: loading_song_index=-1; tell("Could not start the song loader.")

func poll_song_worker() -> void:
	if worker_song_id.is_empty() or metadata_worker.is_alive(): return
	var result: Dictionary=metadata_worker.wait_to_finish()
	var id=worker_song_id; worker_song_id=""
	var selected=loading_song_index>0 and loading_song_index<=library.songs.size() and str(library.songs[loading_song_index-1].id)==id
	if result.has("error"):
		song_metadata[id]={"error":result.error}
		if chart_library: chart_library.update_card_metadata(id)
		if selected:
			loading_song_index=-1; loading_open_editor=false; tell(str(result.error))
			if lobby:
				lobby.update_selected_track()
				if mode=="menu": lobby.detail_label.text=str(result.error)
	else:
		if not song_metadata.has(id):
			song_metadata[id]={"duration":result.duration,"waveform":result.waveform,"notes":result.notes,"note_count":result.note_count,"has_chart":result.has_chart}
			if result.has("chart_error"): song_metadata[id].chart_error=result.chart_error
			if result.has("cover") and not song_cover_textures.has(id): song_cover_textures[id]=ImageTexture.create_from_image(result.cover)
		if chart_library: chart_library.update_card_metadata(id)
		if selected:
			var entry: Dictionary=library.songs[loading_song_index-1]
			var open_studio=loading_open_editor
			loading_song_index=-1; loading_open_editor=false
			apply_song(entry,result.stream,song_metadata[id])
			if lobby: lobby.update_selected_track()
			if open_studio and mode=="library":
				set_mode("editor"); tell("Tap notes to select. Drag to move. SAVE keeps your chart.")
		else: result.erase("stream")
	start_song_worker()

func apply_safe_area() -> void:
	var safe = DisplayServer.get_display_safe_area()
	var window_size = DisplayServer.window_get_size()
	if OS.has_feature("mobile") and safe.size.x>0 and safe.size.y>0:
		ui.anchor_left=float(safe.position.x)/window_size.x; ui.anchor_top=float(safe.position.y)/window_size.y
		ui.anchor_right=float(safe.end.x)/window_size.x; ui.anchor_bottom=float(safe.end.y)/window_size.y

func rect(node: Control, parent: Node, x: float, y: float, right: float, bottom: float) -> void:
	parent.add_child(node); node.anchor_left=x; node.anchor_top=y; node.anchor_right=right; node.anchor_bottom=bottom
	node.offset_left=0; node.offset_top=0; node.offset_right=0; node.offset_bottom=0

func label(parent: Node, text: String, x: float,y: float,right: float,bottom: float,font_size=22) -> Label:
	var result=Label.new(); rect(result,parent,x,y,right,bottom); result.text=text; result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",Color("eee9ff")); result.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

func button(parent: Node,text: String,x: float,y: float,right: float,bottom: float,action: Callable) -> Button:
	var result=NeonAction.new()
	result.text=text; result.caption_size=18; result.compact=true
	result.accent_color=Color("9862ee")
	rect(result,parent,x,y,right,bottom)
	result.pressed.connect(action)
	return result

func build_ui() -> void:
	song_hud=label(ui,"",.105,.015,.37,.105,25)
	difficulty_hud=label(ui,"EXPERT   Lv. 12",.105,.105,.35,.15,18); difficulty_hud.add_theme_color_override("font_color",Color("ed42ff"))
	auto_play_hud=label(ui,"AUTO PLAY  •  PREVIEW",.39,.13,.61,.19,22); auto_play_hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	auto_play_hud.add_theme_color_override("font_color",Color("38baff"))
	hud=label(ui,"",.68,.015,.91,.12,42); hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	combo_hud=Control.new(); rect(combo_hud,ui,.3,.30,.7,.46)
	combo_hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	rank_hud=label(ui,"SS",.925,.015,.99,.12,46); rank_hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	rank_hud.add_theme_color_override("font_color",Color("b985ff")); rank_hud.add_theme_color_override("font_outline_color",Color("5921a8")); rank_hud.add_theme_constant_override("outline_size",5)
	pause_button=button(ui,"II",.02,.025,.08,.105,toggle_pause)
	hit_label=label(ui,"",.3,.465,.7,.535,40); hit_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hit_label.add_theme_color_override("font_outline_color",Color("6228c7")); hit_label.add_theme_constant_override("outline_size",5)
	hit_art=TextureRect.new(); rect(hit_art,ui,.29,.435,.71,.555)
	hit_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	hit_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hit_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	countdown_label=label(ui,"",.35,.28,.65,.55,128); countdown_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_color_override("font_outline_color",Color("5c23ac")); countdown_label.add_theme_constant_override("outline_size",10)
	guide_button=button(ui,"NOTE GUIDE",.84,.16,.98,.22,func(): set_mode("guide"))
	guide_back=button(ui,"BACK",.42,.88,.58,.95,func(): set_mode("menu"))
	pause_backdrop=ColorRect.new(); rect(pause_backdrop,ui,0,0,1,1); pause_backdrop.color=Color(0,0,.04,.6)
	pause_backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	modal=Panel.new(); rect(modal,ui,.19,.11,.81,.89)
	var style=StyleBoxFlat.new(); style.bg_color=Color("080c20"); style.border_color=Color("6651a0"); style.set_border_width_all(1); style.set_corner_radius_all(20); modal.add_theme_stylebox_override("panel",style)
	modal_title=label(modal,"S Y N K",.04,.025,.96,.17,48); modal_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	modal_body=label(modal,"",.06,.17,.94,.43,22); modal_body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; modal_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	primary=button(modal,"PLAY",.23,.88,.77,.97,primary_action)
	pause_restart=button(modal,"RESTART",.36,.88,.64,.97,restart_from_pause)
	pause_home=button(modal,"HOME",.66,.88,.94,.97,return_home)
	settings_panel=Control.new(); rect(settings_panel,modal,.08,.45,.92,.86)
	label(settings_panel,"Timing offset (ms)",.02,.0,.5,.19,18)
	var offset=SpinBox.new(); rect(offset,settings_panel,.60,.0,.95,.19); offset.min_value=-200; offset.max_value=200; offset.value=timing_ms
	offset.value_changed.connect(change_audio_offset)
	label(settings_panel,"Note speed",.02,.25,.5,.44,18)
	var scroll=SpinBox.new(); rect(scroll,settings_panel,.60,.25,.95,.44); scroll.min_value=.5; scroll.max_value=3; scroll.step=.25; scroll.suffix="×"; scroll.value=note_speed
	scroll.tooltip_text="Falling note speed. Music and hit timing stay the same."
	scroll.value_changed.connect(func(value): note_speed=value; prefs.set_value("gameplay","note_speed",value); prefs.save("user://preferences.cfg"))
	bluetooth_toggle=CheckButton.new(); rect(bluetooth_toggle,settings_panel,.02,.50,.95,.69)
	bluetooth_toggle.text="Bluetooth headset mode"; bluetooth_toggle.button_pressed=bluetooth_mode
	bluetooth_toggle.add_theme_font_size_override("font_size",19)
	bluetooth_toggle.toggled.connect(change_bluetooth_mode)
	label(settings_panel,"Extra headset delay",.02,.76,.57,.95,18)
	bluetooth_latency_input=SpinBox.new(); rect(bluetooth_latency_input,settings_panel,.60,.76,.95,.95)
	bluetooth_latency_input.min_value=0; bluetooth_latency_input.max_value=600; bluetooth_latency_input.step=5
	bluetooth_latency_input.suffix=" ms"; bluetooth_latency_input.value=bluetooth_latency_ms
	bluetooth_latency_input.editable=bluetooth_mode
	bluetooth_latency_input.tooltip_text="Increase this if you hear Bluetooth audio after the notes reach the hit bar."
	bluetooth_latency_input.value_changed.connect(change_bluetooth_latency)
	actions=Control.new(); rect(actions,ui,0,0,1,1); actions.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button(actions,"RECORD NEW",.02,.91,.20,.98,start_new_recording)
	button(actions,"PLAY SAVED",.22,.91,.39,.98,func(): start_game(saved_notes))
	button(actions,"AUTO PLAY",.41,.91,.58,.98,start_autoplay)
	button(actions,"CHART STUDIO / IMPORT AUDIO",.60,.91,.98,.98,open_editor)
	record_tools=Control.new(); rect(record_tools,ui,0,0,1,1); record_tools.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var kinds=["auto","tap","hold","slide","flick"]
	for i in kinds.size():
		var kind=kinds[i]
		kind_buttons.append(button(record_tools,kind.to_upper(),.12+i*.105,.025,.215+i*.105,.095,func():
			if arranging:
				if kind=="auto": delete_arrange_note()
				else: change_arrange_note_type(kind)
			else:
				tool=kind; judgement=kind.to_upper()+" TOOL"; flash=1))
	arrange_button=button(record_tools,"ARRANGE",.65,.025,.76,.095,toggle_arrange)
	button(record_tools,"UNDO",.77,.025,.87,.095,undo_record_note)
	button(record_tools,"STOP",.89,.025,.98,.095,stop_take)
	record_info=label(record_tools,"",.65,.12,.97,.21,24); record_info.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	record_help=label(record_tools,"AUTO records taps, holds and slides. Choose FLICK for a directed swipe.\nRecord near the glowing line. STOP to edit your take.",.05,.91,.95,.99,18); record_help.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func set_mode(value: String) -> void:
	if value in ["play","record"] and loading_song_index>0:
		loading_song_index=-1; loading_open_editor=false
	mode=value; menu_settings_open=false
	if mode in ["menu","library","editor"]: start_song_worker()
	studio.visible=mode=="editor"; modal.visible=mode in ["paused","results"]
	lobby.visible=mode=="menu"
	chart_library.visible=mode=="library"
	pause_backdrop.visible=mode=="paused"
	actions.visible=mode=="results"; record_tools.visible=mode=="record"
	hud.visible=mode in ["play","paused"]; hit_label.visible=mode in ["play","record"]; pause_button.visible=mode in ["play","record","paused"]
	hit_art.visible=false
	combo_hud.visible=mode in ["play","paused"]
	song_hud.visible=mode in ["play","paused"]; song_hud.text=str(song.title)+"\n"+str(song.bpm)+" BPM / CUSTOM" if song.id!="eclipse" else "Eclipse\nSYNK Originals / EXPERT"
	song_hud.text=str(song.title)+"\n"+("SYNK Originals" if song.id=="eclipse" else "Custom chart")
	difficulty_hud.visible=mode in ["play","paused"]; difficulty_hud.text="EXPERT   Lv. 12" if song.id=="eclipse" else str(song.bpm)+" BPM"
	auto_play_hud.visible=auto_play and mode in ["play","paused"]
	rank_hud.visible=mode in ["play","paused"]
	guide_button.visible=false; guide_back.visible=mode=="guide"
	pause_home.visible=mode=="paused"; pause_restart.visible=mode=="paused"
	settings_panel.visible=false
	modal.anchor_top=.22 if mode=="paused" else .11
	modal.anchor_bottom=.78 if mode=="paused" else .89
	var button_top=.76 if mode=="paused" else .88
	var button_bottom=.94 if mode=="paused" else .97
	for action_button in [primary,pause_restart,pause_home]:
		action_button.anchor_top=button_top; action_button.anchor_bottom=button_bottom
	modal_body.anchor_bottom=.65 if mode=="paused" else .43
	primary.anchor_left=.06 if mode=="paused" else .23
	primary.anchor_right=.34 if mode=="paused" else .77
	if mode=="menu":
		lobby.refresh()
		UiMotion.reveal(lobby)
	if mode=="library":
		chart_library.refresh()
		UiMotion.reveal(chart_library)
	if mode=="editor":
		refresh_editor()
		UiMotion.reveal(studio)

func open_lobby_settings() -> void:
	if mode!="menu": return
	menu_settings_open=true
	pause_backdrop.visible=true; pause_backdrop.modulate.a=1
	modal.visible=true; modal.scale=Vector2.ONE; modal.modulate.a=1
	settings_panel.visible=true
	modal_title.text="SETTINGS"
	modal_body.text="Adjust timing and note speed. For Bluetooth, enable headset mode and increase the extra delay until the notes match what you hear."
	primary.text="DONE"

func close_lobby_settings() -> void:
	menu_settings_open=false
	modal.visible=false; pause_backdrop.visible=false

func return_home() -> void:
	if mode!="paused": return
	if pause_tween and pause_tween.is_running(): pause_tween.kill()
	if paused_mode=="record" and not capture.notes.is_empty():
		document.checkpoint(); document.notes.append_array(capture.notes.duplicate(true))
		document.dirty=true
	audio.stop(); audio.stream_paused=false; audio.pitch_scale=1
	arranging=false; arrange_touches.clear(); arrange_selection.clear(); arrange_button.text="ARRANGE"
	pointers.clear(); capture.gestures.clear(); live.clear()
	countdown=0; resume_countdown=0; song_time=0; flash=0
	set_mode("menu")
	modal.scale=Vector2.ONE; modal.modulate.a=1

func restart_from_pause() -> void:
	if mode!="paused": return
	if pause_tween and pause_tween.is_running(): pause_tween.kill()
	modal.scale=Vector2.ONE; modal.modulate.a=1
	resume_countdown=0
	if paused_mode=="record":
		cursor=start_position
		record_here()
	else:
		start_game(last_play_notes,auto_play)

func primary_action() -> void:
	if mode=="menu" and menu_settings_open: close_lobby_settings()
	elif mode=="paused": toggle_pause()
	elif mode=="results": start_game(last_play_notes,auto_play)
	else: start_game(SynkChart.demo() if song.id=="eclipse" else saved_notes)

func start_autoplay() -> void:
	var notes=baseline_notes()
	if notes.is_empty():
		modal_body.text="This song has no chart yet. Record or add notes in Chart Studio, then save it to preview with Auto Play."
		return
	start_game(notes,true)

func baseline_notes() -> Array:
	return saved_notes if library.has_chart(song.id) else (SynkChart.demo() if song.id=="eclipse" else [])

func audio_time() -> float:
	return maxf(0,audio.get_playback_position()+AudioServer.get_time_since_last_mix()*audio.pitch_scale-AudioServer.get_output_latency())
func effective_timing_ms() -> float: return timing_ms-(bluetooth_latency_ms if bluetooth_mode else 0.0)
func chart_time() -> float: return maxf(0,audio_time()+effective_timing_ms()/1000.0)
func apply_timing_change(previous_ms: float) -> void:
	if mode in ["play","paused","record"] and countdown==0 and (audio.playing or (mode=="paused" and pause_had_audio)):
		song_time=maxf(0,song_time+(effective_timing_ms()-previous_ms)/1000.0)
		visual_song_time=song_time
		visual_clock_ready=false

func change_audio_offset(value: float) -> void:
	var previous=effective_timing_ms()
	timing_ms=value
	apply_timing_change(previous)
	prefs.set_value("audio","offset_ms",value); prefs.save("user://preferences.cfg")

func change_bluetooth_mode(value: bool) -> void:
	var previous=effective_timing_ms()
	bluetooth_mode=value
	bluetooth_latency_input.editable=value
	apply_timing_change(previous)
	prefs.set_value("audio","bluetooth_mode",value); prefs.save("user://preferences.cfg")

func change_bluetooth_latency(value: float) -> void:
	var previous=effective_timing_ms()
	bluetooth_latency_ms=value
	apply_timing_change(previous)
	prefs.set_value("audio","bluetooth_latency_ms",value); prefs.save("user://preferences.cfg")
func smooth_visual_time(target: float,delta: float) -> void:
	if not visual_clock_ready or absf(target-visual_song_time)>.12:
		visual_song_time=target; visual_clock_ready=true; return
	var predicted=visual_song_time+delta
	var correction=(target-predicted)*minf(1.0,delta*10.0)
	visual_song_time=predicted+clampf(correction,-delta*.5,delta*.5)
func note_travel_seconds() -> float: return 2.6 / note_speed
func length() -> float: return audio.stream.get_length()
func accuracy() -> float: return 100.0 if judged==0 else earned/judged*100
func total_judgements() -> int:
	var total = live.size()
	for entry in live:
		if entry.note.kind=="hold": total+=1
	return total
func rank_name() -> String:
	var a=accuracy(); return "SS" if a>=98 else ("S" if a>=95 else ("A" if a>=90 else ("B" if a>=80 else "C")))

func start_game(notes: Array,automated: bool = false) -> void:
	audio.stop(); audio.pitch_scale=1; pointers.clear(); live.clear()
	field.world.clear_hit_effects()
	field.world.clear_notes()
	auto_play=automated
	visual_clock_ready=false
	resume_countdown=0
	arranging=false; arrange_touches.clear(); arrange_selection.clear(); arrange_button.text="ARRANGE"
	var sorted=notes.duplicate(true); sorted.sort_custom(func(a,b): return a.time<b.time)
	for n in sorted:
		if n.kind=="flick" and int(n.direction)==2: n.direction=0
	last_play_notes=sorted.duplicate(true)
	for n in sorted: live.append({"note":n,"started":false,"done":false,"pointer":-999,"error":0.0})
	score=0; displayed_score=0; combo=0; combo_pulse=0; rank_pulse=0; shown_rank="SS"; hold_pulse_time=0; max_combo=0; earned=0; judged=0; countdown=2; start_position=0; song_time=-2; judgement="READY"; flash=1
	set_mode("play")
	for banner in [song_hud,difficulty_hud]:
		banner.modulate.a=0
		banner.scale=Vector2(.96,.96)
		var entrance=create_tween().set_parallel(true)
		entrance.tween_property(banner,"modulate:a",1.0,.35).set_ease(Tween.EASE_OUT)
		entrance.tween_property(banner,"scale",Vector2.ONE,.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func start_new_recording() -> void:
	if document.dirty:
		set_mode("editor"); tell("Save or reload your edits before starting a new chart."); return
	document.load_notes([]); document.dirty=true; cursor=0; record_here()

func record_here() -> void:
	audio.stop(); audio.pitch_scale=1; capture.notes.clear(); capture.gestures.clear(); pointers.clear(); tool="auto"
	visual_clock_ready=false
	resume_countdown=0
	arranging=false; arrange_touches.clear(); arrange_selection.clear(); arrange_button.text="ARRANGE"
	overdub=true; start_position=clampf(cursor,0,maxf(0,length()-.02)); countdown=3; song_time=start_position-3; set_mode("record")
	refresh_arrange_controls()

func stop_take() -> void:
	audio.stop(); capture.gestures.clear()
	arranging=false; arrange_touches.clear(); arrange_selection.clear(); arrange_button.text="ARRANGE"
	if not capture.notes.is_empty(): document.checkpoint(); document.notes.append_array(capture.notes.duplicate(true))
	cursor=clampf(song_time,0,length()); set_mode("editor"); tell("Take added. Previous notes kept. Undo removes this take. Save when ready.")

func toggle_pause() -> void:
	if mode in ["play","record"]:
		resume_countdown=0
		paused_mode=mode; pause_had_audio=audio.playing; audio.stream_paused=true; pointers.clear(); capture.gestures.clear()
		for entry in live:
			if entry.started and not entry.done: entry.pointer=-999
		set_mode("paused"); modal_title.text="PAUSED"; modal_body.text="Take a breath.\n\nRestart begins this run again.\nUnfinished recording gestures are discarded."; primary.text="RESUME"
		if pause_tween and pause_tween.is_running(): pause_tween.kill()
		modal.pivot_offset=modal.size*.5; modal.scale=Vector2(.86,.86); modal.modulate.a=0
		pause_backdrop.modulate.a=0
		pause_tween=create_tween().set_parallel(true)
		pause_tween.tween_property(modal,"scale",Vector2.ONE,.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pause_tween.tween_property(modal,"modulate:a",1.0,.18)
		pause_tween.tween_property(pause_backdrop,"modulate:a",1.0,.22)
	elif mode=="paused":
		if pause_tween and pause_tween.is_running(): pause_tween.kill()
		resume_start_audio=not pause_had_audio
		countdown=0; resume_countdown=3.0; judgement=""; flash=0
		set_mode(paused_mode)
		modal.scale=Vector2.ONE; modal.modulate.a=1

func toggle_arrange() -> void:
	if mode!="record": return
	arranging=not arranging; arrange_touches.clear(); arrange_selection.clear(); capture.gestures.clear()
	arrange_button.text="RECORD" if arranging else "ARRANGE"
	refresh_arrange_controls()
	if arranging:
		countdown=0; audio.stream_paused=true
	else:
		var playback_time=clampf(song_time-effective_timing_ms()/1000.0,0,maxf(0,length()-.02))
		if audio.playing: audio.seek(playback_time); audio.stream_paused=false
		else: audio.play(playback_time)

func refresh_arrange_controls() -> void:
	kind_buttons[0].text="DELETE" if arranging else "AUTO"
	for kind_button in kind_buttons: kind_button.disabled=arranging and arrange_selection.is_empty()
	if arranging:
		if arrange_selection.is_empty(): record_help.text="Tap a note on the highway to select or drag it. Scroll from either side of the highway.\nChoose TAP, HOLD, SLIDE or FLICK to change its type; DELETE removes it."
		else:
			var n: Dictionary=arrange_selection.note
			record_help.text="SELECTED  %s  •  LANE %d  •  %.2f s\nDrag to move. Use the type buttons or DELETE above; scroll outside the highway." % [str(n.kind).to_upper(),int(n.lane)+1,float(n.time)]
	else: record_help.text="AUTO records taps, holds and slides. Choose FLICK for a directed swipe.\nRecord near the glowing line. STOP to edit your take."

func undo_record_note() -> void:
	if not capture.notes.is_empty(): capture.notes.pop_back()
	arrange_selection.clear()
	refresh_arrange_controls()

func delete_arrange_note() -> void:
	if not arranging or arrange_selection.is_empty(): return
	var index=int(arrange_selection.index)
	if arrange_selection.document:
		document.selected=index
		document.delete()
	elif index>=0 and index<capture.notes.size(): capture.notes.remove_at(index)
	arrange_selection.clear(); arrange_touches.clear()
	refresh_arrange_controls()

func change_arrange_note_type(kind: String) -> void:
	if not arranging or arrange_selection.is_empty() or kind not in SynkChart.TYPES: return
	var n: Dictionary=arrange_selection.note
	if n.kind==kind: return
	if arrange_selection.document:
		document.selected=int(arrange_selection.index)
		document.convert(kind,60.0/float(song.bpm),length())
	else:
		n.kind=kind
		if kind in ["tap","flick"]:
			n.duration=0.0; n.path=[]; n.end_lane=n.lane
		else:
			n.duration=maxf(.04,float(n.duration) if float(n.duration)>0 else 60.0/float(song.bpm))
			if kind=="hold": n.path=[]; n.end_lane=n.lane
		n.time=clampf(float(n.time),0,maxf(0,length()-float(n.duration)))
		if kind=="flick" and int(n.direction)==2: n.direction=0
	refresh_arrange_controls()

func stage_time_at(p: Vector2) -> float:
	var point=p*Vector2(field.viewport.size)
	var origin=field.world.camera.project_ray_origin(point)
	var direction=field.world.camera.project_ray_normal(point)
	var hit=Plane(Vector3.UP,0).intersects_ray(origin,direction)
	return song_time+hit.z/field.world.travel_speed() if hit!=null else song_time

func outside_highway(p: Vector2) -> bool:
	var point=p*Vector2(field.viewport.size)
	var far_left=field.project(-.5,1)
	var near_left=field.project(-.5,0)
	var far_right=field.project(12.5,1)
	var near_right=field.project(12.5,0)
	if point.y<far_left.y: return true
	var depth=clampf((point.y-far_left.y)/maxf(1,near_left.y-far_left.y),0,1)
	var left_edge=lerpf(far_left.x,near_left.x,depth)
	var right_edge=lerpf(far_right.x,near_right.x,depth)
	return point.x<left_edge-12 or point.x>right_edge+12

func arrange_pointer_event(id: int,p: Vector2,began: bool,ended: bool,canceled: bool) -> void:
	if began:
		if outside_highway(p):
			arrange_selection.clear(); refresh_arrange_controls()
			arrange_touches[id]={"kind":"scroll","start_y":p.y,"start_time":song_time}
			return
		var selected: Dictionary={}
		var closest=.09
		var sources=[capture.notes,document.notes]
		for source_index in sources.size():
			var source: Array=sources[source_index]
			for note_index in source.size():
				var n: Dictionary=source[note_index]
				if float(n.time)>song_time or song_time-float(n.time)>note_travel_seconds(): continue
				var position=Vector3(field.world.lane_x(float(n.lane)),.2,(float(n.time)-song_time)*field.world.travel_speed())
				var screen_point=field.world.camera.unproject_position(position)/Vector2(field.viewport.size)
				var distance=p.distance_to(screen_point)
				if distance<closest: closest=distance; selected={"note":n,"document":source_index==1,"index":note_index}
		arrange_selection=selected
		refresh_arrange_controls()
		if selected.is_empty(): arrange_touches[id]={"kind":"empty"}
		else:
			arrange_touches[id]={"kind":"note","note":selected.note,"document":selected.document,"changed":false,"start_time":float(selected.note.time),"start_lane":int(selected.note.lane),"touch_time":stage_time_at(p)}
	if canceled or ended:
		arrange_touches.erase(id); return
	if not arrange_touches.has(id): return
	var touch: Dictionary=arrange_touches[id]
	if touch.kind=="scroll":
		song_time=clampf(float(touch.start_time)+(float(touch.start_y)-p.y)*note_travel_seconds()*1.3,0,length())
	elif touch.kind=="note":
		var n: Dictionary=touch.note
		var target_time=stage_time_at(p)-float(touch.touch_time)+float(touch.start_time)
		var mapped=field.input_position(p)
		var lane_delta=clampi(roundi(SynkCapture.lane(mapped.x))-int(touch.start_lane),-12,12)
		var new_lane=clampi(int(touch.start_lane)+lane_delta,0,12)
		if not touch.changed and (absf(float(n.time)-target_time)>.001 or int(n.lane)!=new_lane):
			if touch.document: document.checkpoint()
			touch.changed=true
		n.time=clampf(target_time,0,minf(song_time,maxf(0,length()-float(n.duration))))
		var change=new_lane-int(n.lane)
		n.lane=new_lane; n.end_lane=clampi(int(n.end_lane)+change,0,12)
		for point in n.path: point.lane=clampf(float(point.lane)+change,0,12)
		if touch.changed: refresh_arrange_controls()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		if mode in ["play","record"]: toggle_pause()
		elif mode=="editor" and audio!=null: stop_audition()
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if document.dirty: set_mode("editor"); tell("Save your draft or RELOAD to discard edits before closing.")
		else: get_tree().quit()

func _process(delta: float) -> void:
	poll_song_worker()
	hud_motion_time+=delta if mode=="play" else 0.0
	if mode!="paused": flash=maxf(0,flash-delta*2.5)
	if mode!="paused": combo_pulse=maxf(0,combo_pulse-delta*4.0)
	if mode!="paused": rank_pulse=maxf(0,rank_pulse-delta*3.5)
	resume_grace=maxf(0,resume_grace-delta)
	if mode in ["play","record"] and not arranging:
		if resume_countdown>0:
			resume_countdown=maxf(0,resume_countdown-delta)
			if resume_countdown==0:
				if resume_start_audio: audio.play(start_position)
				audio.stream_paused=false; resume_grace=.35
		elif countdown>0:
			countdown=maxf(0,countdown-delta); song_time=start_position-countdown
			visual_song_time=song_time; visual_clock_ready=false
			judgement="READY "+str(ceili(countdown)); flash=1
			if countdown==0: audio.stream_paused=false; audio.play(start_position)
		else:
			song_time=maxf(song_time,chart_time())
			smooth_visual_time(song_time,delta)
			if mode=="play":
				if auto_play: update_autoplay()
				else: update_game()
	elif mode in ["play","record"] and resume_countdown>0:
		resume_countdown=maxf(0,resume_countdown-delta)
		if resume_countdown==0: resume_grace=.35
	var counting=mode in ["play","record"] and (countdown>0 or resume_countdown>0)
	var active_hold=mode=="play" and not counting and has_active_hold()
	hold_pulse_time=hold_pulse_time+delta if active_hold else 0.0
	var hold_pulse=(0.5+0.5*sin(hold_pulse_time*TAU*2.0))*.55 if active_hold else 0.0
	var displayed_pulse=maxf(combo_pulse,hold_pulse)
	align_gameplay_hud()
	combo_hud.pivot_offset=combo_hud.size*.5
	combo_hud.scale=Vector2.ONE*(1.0+displayed_pulse*.28)
	combo_hud.modulate=Color.WHITE.lerp(Color("fff0ff"),displayed_pulse)
	countdown_label.visible=counting
	if counting:
		var remaining=resume_countdown if resume_countdown>0 else countdown
		countdown_label.text=str(ceili(remaining))
		countdown_label.pivot_offset=countdown_label.size*.5
		countdown_label.scale=Vector2.ONE*(1.0+fmod(remaining,1.0)*.2)
	combo_hud.visible=mode in ["play","paused"] and not counting
	hit_label.visible=mode in ["play","record"] and not counting
	if mode=="editor" and audio.playing:
		cursor=clampf(chart_time(),0,length())
		if loop_enabled and loop_b>loop_a+.1 and cursor>=loop_b: audio.play(loop_a); cursor=loop_a
		refresh_editor()
	if mode=="play":
		displayed_score=lerpf(displayed_score,float(score),clampf(delta*11.0,0,1))
		if absf(displayed_score-score)<1.0: displayed_score=score
	hud.text=str(roundi(displayed_score)).pad_zeros(7)
	var current_rank=rank_name()
	if current_rank!=shown_rank:
		if mode=="play" and judged>0: rank_pulse=1.0
		shown_rank=current_rank
	rank_hud.text=current_rank
	rank_hud.pivot_offset=rank_hud.size*.5
	rank_hud.scale=Vector2.ONE*(1.0+rank_pulse*.22)
	rank_hud.modulate=Color.WHITE.lerp(Color("fff1ff"),rank_pulse)
	if auto_play_hud.visible and mode=="play": auto_play_hud.modulate.a=.78+.22*sin(hud_motion_time*2.2)
	else: auto_play_hud.modulate.a=1.0
	if combo_art_value!=combo or combo_art_size!=combo_hud.size: update_combo_art()
	record_info.text=("ARRANGE  %.1f s\n%d NOTES" if arranging else "● RECORDING  %.1f s\n%d NOTES / %s") % ([maxf(0,song_time),capture.notes.size()] if arranging else [maxf(0,song_time),capture.notes.size(),tool.to_upper()])
	var show_hit_art=mode=="play" and not counting and JUDGEMENT_ART.has(judgement)
	hit_art.visible=show_hit_art
	if show_hit_art:
		hit_art.texture=JUDGEMENT_ART[judgement]
		hit_art.modulate.a=1.0
		hit_art.pivot_offset=hit_art.size*.5
		hit_art.scale=Vector2.ONE*(1.0+(0.0 if active_hold else flash*.08))
	hit_label.visible=mode=="record" and not counting
	hit_label.text=judgement; hit_label.modulate.a=flash

func has_active_hold() -> bool:
	for entry in live:
		if entry.done or not entry.started or entry.note.kind!="hold": continue
		if auto_play or pointers.has(entry.pointer): return true
	return false

func align_gameplay_hud() -> void:
	var screen_center=field.get_global_transform_with_canvas()*field.project(6,0)
	var center_x=(ui.get_global_transform_with_canvas().affine_inverse()*screen_center).x
	for element in [combo_hud,hit_art,hit_label]:
		element.position.x=center_x-element.size.x*.5

func update_combo_art() -> void:
	combo_art_value=combo; combo_art_size=combo_hud.size
	for child in combo_hud.get_children():
		combo_hud.remove_child(child)
		child.queue_free()
	var digits=str(combo)
	var digit_height=minf(combo_hud.size.y*.96,combo_hud.size.x/maxf(1,digits.length())*.82)
	var digit_width=digit_height*(float(COMBO_ATLAS.get_width())/3.0)/(float(COMBO_ATLAS.get_height())/3.0)
	var spacing=digit_width*.84
	var total_width=digit_width+spacing*(digits.length()-1)
	var left=(combo_hud.size.x-total_width)*.5
	for i in digits.length():
		var digit=TextureRect.new()
		combo_hud.add_child(digit)
		digit.texture=combo_digit_textures[int(digits[i])]
		digit.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		digit.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		digit.mouse_filter=Control.MOUSE_FILTER_IGNORE
		digit.position=Vector2(left+i*spacing,(combo_hud.size.y-digit_height)*.5)
		digit.size=Vector2(digit_width,digit_height)

func build_combo_digit_textures() -> void:
	combo_digit_textures.clear()
	var cell_width=float(COMBO_ATLAS.get_width())/3.0
	var cell_height=float(COMBO_ATLAS.get_height())/3.0
	combo_digit_textures.append(COMBO_ZERO)
	for value in range(1,10):
		var cell=value-1
		var atlas_texture=AtlasTexture.new()
		atlas_texture.atlas=COMBO_ATLAS
		atlas_texture.region=Rect2(Vector2(cell%3*cell_width,floori(float(cell)/3.0)*cell_height),Vector2(cell_width,cell_height))
		atlas_texture.filter_clip=true
		combo_digit_textures.append(atlas_texture)

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==-1: return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		if mode=="guide": set_mode("menu")
		elif mode=="library": set_mode("menu")
		elif mode=="editor": close_editor()
		else: toggle_pause()
	if mode not in ["play","record"] or countdown>0 or resume_countdown>0 or (mode=="play" and auto_play): return
	if event is InputEventScreenTouch: pointer_event(event.index,event.position/size,event.pressed,not event.pressed,event.canceled)
	elif event is InputEventScreenDrag: pointer_event(event.index,event.position/size,false,false,false)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT: pointer_event(-1,event.position/size,event.pressed,not event.pressed,false)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): pointer_event(-1,event.position/size,false,false,false)

func pointer_event(id: int,p: Vector2,began: bool,ended: bool,canceled: bool) -> void:
	if mode=="play" and auto_play: return
	if mode=="record" and arranging:
		arrange_pointer_event(id,p,began,ended,canceled); return
	p = field.input_position(p)
	if mode=="record":
		if began: capture.begin(id,song_time,p,tool)
		capture.move(id,song_time,p)
		if ended:
			var n=capture.end(id,song_time,p,canceled)
			if not n.is_empty(): judgement=n.kind.to_upper()+" RECORDED"; flash=1; flash_lane=int(n.end_lane)
		return
	if began:
		pointers[id]={"start":p,"position":p}
		if p.y>=.6 and p.y<=.92:
			var nearest: Dictionary={}; var best=.231
			for entry in live:
				if float(entry.note.time)>song_time+.23: break
				if entry.done: continue
				var n: Dictionary=entry.note
				if entry.started:
					if entry.pointer==-999 and absf(SynkCapture.lane(p.x)-SynkChart.lane_at(n,song_time))<.85: entry.pointer=id
					continue
				var error=absf(song_time-float(n.time))
				var timing_limit=.23 if n.kind=="slide" else .16
				var lane_limit=1.8 if n.kind=="slide" else .85
				if error<=minf(best,timing_limit) and absf(SynkCapture.lane(p.x)-float(n.lane))<lane_limit: best=error; nearest=entry
			if not nearest.is_empty():
				nearest.started=true; nearest.pointer=id; nearest.error=best
				if nearest.note.kind=="tap": judge(nearest,best)
				elif nearest.note.kind=="hold": judge(nearest,best,false)
	if pointers.has(id): pointers[id].position=p
	if ended:
		# Process final swipe motion before removing the finger.
		update_game()
		for entry in live:
			if entry.done or entry.pointer!=id or entry.note.kind!="hold": continue
			var hold_end=float(entry.note.time)+float(entry.note.duration)
			judge(entry,absf(song_time-hold_end) if not canceled and absf(song_time-hold_end)<=.16 else -1)
		for entry in live:
			if entry.done or entry.pointer!=id or entry.note.kind!="slide": continue
			var end_time=float(entry.note.time)+float(entry.note.duration)
			var lane_error=absf(SynkCapture.lane(p.x)-SynkChart.lane_at(entry.note,end_time))
			if not canceled and lane_error<=2.75 and p.y>=.5 and song_time>=end_time-.20 and song_time<=end_time+.20:
				judge(entry,float(entry.error))
		pointers.erase(id)
		if canceled:
			for entry in live:
				if entry.pointer==id and not entry.done: judge(entry,-1)

func update_autoplay() -> void:
	for entry in live:
		if float(entry.note.time)>song_time: break
		if entry.done: continue
		var n: Dictionary=entry.note
		if not entry.started and song_time>=float(n.time):
			entry.started=true
			if n.kind=="hold": judge(entry,0.0,false)
			elif n.kind in ["tap","flick"]: judge(entry,0.0)
		if entry.started and not entry.done and song_time>=float(n.time)+float(n.duration):
			judge(entry,0.0)

func update_game() -> void:
	for entry in live:
		if float(entry.note.time)>song_time+.23: break
		if entry.done: continue
		var n: Dictionary=entry.note
		if not entry.started:
			if song_time>float(n.time)+(.23 if n.kind=="slide" else .16):
				judge(entry,-1)
				if n.kind=="hold": judged+=1
			continue
		if entry.pointer==-999 and resume_grace>0: continue
		if not pointers.has(entry.pointer): judge(entry,-1); continue
		var p: Dictionary=pointers[entry.pointer]
		if n.kind=="flick":
			var displacement: Vector2=p.position-p.start
			var direction: Vector2=[Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][int(n.direction)]
			if displacement.dot(direction)>.035 and displacement.dot(direction)>absf(displacement.dot(direction.orthogonal())): judge(entry,float(entry.error))
			elif song_time>float(n.time)+.16: judge(entry,-1)
		elif n.kind=="slide":
			var end_time=float(n.time)+float(n.duration)
			if song_time>=end_time-.045:
				var lane_error=absf(SynkCapture.lane(p.position.x)-SynkChart.lane_at(n,end_time))
				if lane_error<=2.75 and p.position.y>=.5: judge(entry,float(entry.error))
				elif song_time>end_time+.20: judge(entry,-1)
		elif n.kind=="hold":
			var hold_end=float(n.time)+float(n.duration)
			if song_time>=hold_end-.045: judge(entry,absf(song_time-hold_end))

func judge(entry: Dictionary,error: float,complete: bool = true) -> void:
	if error>=0: field.world.spawn_hit(SynkChart.lane_at(entry.note,song_time),str(entry.note.kind),int(entry.note.direction),entry if entry.note.kind=="hold" and not complete else {})
	else: field.world.shake_on_miss()
	if error<0 and entry.note.kind=="slide":
		entry.missed_at=song_time
		entry.missed_visual_time=field.world.render_time()
	judgement_kind = str(entry.note.kind)
	entry.done=complete; judged+=1; flash=1; flash_lane=roundi(SynkChart.lane_at(entry.note,song_time))
	if error<0: judgement="MISS"; combo=0; combo_pulse=0
	else:
		combo+=1; combo_pulse=1.0; max_combo=maxi(combo,max_combo)
		if error<=.045: judgement="PERFECT"; earned+=1
		elif error<=.09: judgement="GREAT"; earned+=.8
		else: judgement="GOOD"; earned+=.5
	score=roundi(1000000*earned/maxi(1,total_judgements()))

func _audio_finished() -> void:
	if mode=="record": stop_take()
	elif mode=="play":
		for entry in live:
			if not entry.done:
				judge(entry,-1)
				if entry.note.kind=="hold" and not entry.started: judged+=1
		var chart_key=(str(song.id)+JSON.stringify(live.map(func(e):return e.note))).sha256_text()
		var best=int(prefs.get_value("scores",chart_key,0))
		if not auto_play:
			best=maxi(score,best); prefs.set_value("scores",chart_key,best); prefs.save("user://preferences.cfg")
		set_mode("results"); modal_title.text=("AUTO PLAY" if auto_play else rank_name())+"  /  "+str(score)
		modal_body.text="PREVIEW COMPLETE\n\n%d notes played automatically.\n\nPersonal bests are saved from manual play only." % live.size() if auto_play else "TRACK COMPLETE\n\n%.2f%% accuracy   •   %d max combo\n\nPersonal best %d\n\nOpen Chart Studio to keep editing." % [accuracy(),max_combo,best]
		primary.text="PLAY AGAIN"
	elif mode=="editor":
		if loop_enabled and loop_b>loop_a+.1: audio.play(loop_a); cursor=loop_a
		else: cursor=length(); refresh_transport()

func build_studio() -> void:
	studio=Panel.new(); rect(studio,ui,0,0,1,1)
	var style=StyleBoxFlat.new(); style.bg_color=Color("080c20"); studio.add_theme_stylebox_override("panel",style)
	title_label=label(studio,"SYNK STUDIO",.02,.015,.7,.085,28)
	button(studio,"SAVE",.73,.02,.84,.08,save_editor); button(studio,"LIBRARY",.86,.02,.98,.08,close_editor)
	label(studio,"CURRENT TRACK",.025,.11,.22,.16,19).add_theme_color_override("font_color",Color("cbb8ff"))
	var cover_frame=Panel.new(); rect(cover_frame,studio,.025,.175,.22,.53)
	var cover_style=StyleBoxFlat.new(); cover_style.bg_color=Color("140d30"); cover_style.border_color=Color("a45dff")
	cover_style.set_border_width_all(2); cover_style.set_corner_radius_all(10); cover_frame.add_theme_stylebox_override("panel",cover_style)
	cover_frame.clip_contents=true
	studio_cover=TextureRect.new(); rect(studio_cover,cover_frame,.012,.012,.988,.988)
	studio_cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	studio_cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	studio_cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
	studio_cover_button=button(studio,"SET COVER ART",.025,.555,.22,.62,choose_cover)
	button(studio,"IMPORT AUDIO  +",.025,.65,.22,.72,choose_audio)
	status=label(studio,"",.025,.755,.22,.97,18); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	play_button=button(studio,"PLAY",.26,.12,.35,.18,toggle_audition)
	button(studio,"REC HERE",.36,.12,.48,.18,record_here)
	button(studio,"−5s",.49,.12,.56,.18,func(): seek_to(cursor-5)); button(studio,"+5s",.57,.12,.64,.18,func(): seek_to(cursor+5))
	button(studio,"ZOOM +",.65,.12,.75,.18,func(): zoom_seconds=maxf(2,zoom_seconds/2)); button(studio,"ZOOM −",.76,.12,.86,.18,func(): zoom_seconds=minf(64,zoom_seconds*2))
	speed_button=button(studio,"1× SPEED",.87,.12,.98,.18,func(): audition_speed=.75 if audition_speed==1 else (.5 if audition_speed==.75 else 1.0); audio.pitch_scale=audition_speed; refresh_editor())
	timeline=Control.new(); timeline.set_script(load("res://scripts/timeline.gd")); timeline.game=self; rect(timeline,studio,.26,.21,.98,.57)
	seek=HSlider.new(); rect(seek,studio,.26,.59,.98,.62); seek.step=.001; seek.value_changed.connect(func(value): if not updating: seek_to(value))
	snap_button=button(studio,"SNAP 1/16",.26,.64,.41,.7,func(): snap_division=2 if snap_division==4 else (1 if snap_division==2 else (0 if snap_division==1 else 4)); refresh_editor())
	button(studio,"SET A",.42,.64,.51,.7,func(): loop_a=cursor; loop_b=maxf(loop_b,minf(length(),loop_a+4)); refresh_editor())
	button(studio,"SET B",.52,.64,.61,.7,func(): if cursor>loop_a+.1: loop_b=cursor; refresh_editor())
	loop_button=button(studio,"LOOP OFF",.62,.64,.75,.7,func(): loop_enabled=not loop_enabled; refresh_editor())
	bpm_input=SpinBox.new(); rect(bpm_input,studio,.77,.64,.98,.7); bpm_input.min_value=30; bpm_input.max_value=300; bpm_input.prefix="BPM "; bpm_input.value=128
	bpm_input.value_changed.connect(func(value): song.bpm=value; library.atomic_write("user://songs/library.json",library.songs); refresh_editor())
	info=label(studio,"",.26,.72,.98,.78,19)
	for i in 4:
		var kind=SynkChart.TYPES[i]
		button(studio,kind.to_upper(),.26+i*.105,.79,.355+i*.105,.845,func(): document.convert(kind,60.0/song.bpm,length()); refresh_editor())
	button(studio,"DIRECTION",.69,.79,.83,.845,func(): var n=document.selection(); if not n.is_empty(): document.checkpoint(); n.direction=1 if int(n.direction)==0 else (3 if int(n.direction)==1 else 0); refresh_editor())
	button(studio,"DELETE",.84,.79,.98,.845,func(): document.delete(); refresh_editor())
	button(studio,"LANE −",.26,.855,.35,.91,func(): nudge(0,-1)); button(studio,"LANE +",.36,.855,.45,.91,func(): nudge(0,1))
	button(studio,"TIME −",.46,.855,.55,.91,func(): nudge(-1,0)); button(studio,"TIME +",.56,.855,.65,.91,func(): nudge(1,0))
	button(studio,"TAIL −",.66,.855,.75,.91,func(): resize_note(-1)); button(studio,"TAIL +",.76,.855,.85,.91,func(): resize_note(1))
	button(studio,"END LANE",.86,.855,.98,.91,func(): var n=document.selection(); if not n.is_empty() and n.kind=="slide": document.checkpoint(); n.end_lane=(int(n.end_lane)+1)%13; n.path=[]; refresh_editor())
	button(studio,"ADD",.26,.925,.35,.98,func(): document.add(SynkChart.snap(cursor,song.bpm,snap_division),6); refresh_editor())
	button(studio,"UNDO",.36,.925,.45,.98,func(): document.undo(); refresh_editor()); button(studio,"REDO",.46,.925,.55,.98,func(): document.redo(); refresh_editor())
	button(studio,"RELOAD",.56,.925,.68,.98,func(): document.load_notes(baseline_notes()); refresh_editor(); tell("Unsaved changes discarded."))
	button(studio,"TEST CHART",.69,.925,.83,.98,func(): start_game(document.notes))
	button(studio,"DUPLICATE",.84,.925,.98,.98,duplicate_note)
	picker=FileDialog.new(); add_child(picker); picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE; picker.access=FileDialog.ACCESS_FILESYSTEM; picker.use_native_dialog=true
	picker.filters=PackedStringArray(["*.mp3,*.wav,*.ogg;Audio;audio/mpeg,audio/wav,audio/ogg"]); picker.file_selected.connect(import_audio)
	cover_picker=FileDialog.new(); add_child(cover_picker)
	cover_picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE; cover_picker.access=FileDialog.ACCESS_FILESYSTEM; cover_picker.use_native_dialog=true
	cover_picker.filters=PackedStringArray(["*.png,*.jpg,*.jpeg;Album art;image/png,image/jpeg"])
	cover_picker.file_selected.connect(import_cover)
	refresh_library()

func open_editor() -> void:
	stop_audition()
	if not document.dirty and document.notes.is_empty(): document.load_notes(baseline_notes())
	set_mode("library")
	chart_library.set_message("Choose a chart to edit, or import audio to start a new one.")

func open_chart(index: int) -> void:
	if select_song(index,true):
		set_mode("editor")
		tell("Tap notes to select. Drag to move. SAVE keeps your chart.")
	elif loading_song_index==index: chart_library.set_message("Loading audio and chart information…")

func close_editor() -> void:
	stop_audition()
	if document.dirty: tell("Save your draft or RELOAD before closing."); return
	set_mode("library")

func tell(message: String) -> void:
	status.text=message
	if chart_library: chart_library.set_message(message)
func refresh_library() -> void:
	if chart_library: chart_library.refresh()

func choose_audio() -> void:
	if document.dirty:
		save_editor()
		if document.dirty: return
	stop_audition()
	if OS.get_name()=="iOS":
		picker.access=FileDialog.ACCESS_USERDATA; picker.current_dir="user://"
		tell("In the Files app, copy music into On My iPhone → SYNK, then choose it here.")
	picker.popup_centered_ratio(.8)

func cover_path(id: String) -> String:
	return "user://covers/"+id+".png"

func has_custom_cover(id: String) -> bool:
	return FileAccess.file_exists(cover_path(id))

func cover_texture_for_id(id: String) -> Texture2D:
	if id=="eclipse": return ECLIPSE_COVER
	if song_cover_textures.has(id): return song_cover_textures[id]
	return CUSTOM_COVER

func cover_tint_for_id(id: String) -> Color:
	return Color.from_hsv(float(posmod(id.hash(),360))/360.0,.18,1.0)

func choose_cover() -> void:
	if song.id=="eclipse": return
	if OS.get_name()=="iOS":
		cover_picker.access=FileDialog.ACCESS_USERDATA; cover_picker.current_dir="user://"
	cover_picker.popup_centered_ratio(.75)

func import_cover(path: String) -> void:
	if song.id=="eclipse": return
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>12*1024*1024:
		tell("Choose a PNG or JPG cover under 12 MB."); return
	var data=file.get_buffer(file.get_length()); file.close()
	var image=Image.new()
	if image.load_png_from_buffer(data)!=OK and image.load_jpg_from_buffer(data)!=OK:
		tell("Choose a valid PNG or JPG cover."); return
	if image.get_width()<64 or image.get_height()<64:
		tell("Choose a cover at least 64 × 64 pixels."); return
	image.convert(Image.FORMAT_RGBA8)
	var square=mini(image.get_width(),image.get_height())
	image=image.get_region(Rect2i((image.get_width()-square)/2,(image.get_height()-square)/2,square,square))
	image.resize(512,512,Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute("user://covers")
	if image.save_png(cover_path(str(song.id)))!=OK:
		tell("Could not save cover art on this device."); return
	song_cover_textures[str(song.id)]=ImageTexture.create_from_image(image)
	refresh_library(); refresh_editor(); tell("Cover art saved for this chart.")

func import_audio(path: String) -> void:
	if document.dirty:
		save_editor()
		if document.dirty: return
	loading_song_index=-1; loading_open_editor=false
	stop_audition(); tell("Importing audio…")
	var result=library.import_song(path)
	if result.is_empty(): tell(library.message); return
	if song_metadata.get(str(result.song.id),{}).has("error"): song_metadata.erase(str(result.song.id))
	apply_song(result.song,result.stream); refresh_library(); set_mode("editor")
	tell("Audio imported. Add notes or record from the playhead, then SAVE your chart.")

func select_song(index: int, open_studio: bool = false) -> bool:
	if document.dirty: tell("Save or RELOAD before changing songs."); return false
	if index==0:
		loading_song_index=-1; loading_open_editor=false
		apply_song({"id":"eclipse","title":"Eclipse","bpm":128.0},demo_stream)
		return true
	if index<1 or index>library.songs.size(): return false
	var entry: Dictionary=library.songs[index-1]
	if str(entry.id)==str(song.id) and audio.stream!=null: return true
	loading_song_index=index; loading_open_editor=open_studio
	if song_metadata.has(str(entry.id)) and song_metadata[str(entry.id)].has("error"):
		song_metadata.erase(str(entry.id))
	start_song_worker()
	return false

func apply_song(entry: Dictionary,stream: AudioStream, prepared: Dictionary = {}) -> void:
	stop_audition(); song=entry; audio.stream=stream; cursor=0; loop_a=0; loop_b=minf(8,length()); loop_enabled=false
	var metadata=prepared if not prepared.is_empty() else song_metadata.get(str(song.id),{})
	saved_notes=metadata.notes.duplicate(true) if metadata.has("notes") else library.load_chart(song.id)
	document.load_notes(baseline_notes())
	bpm_input.set_value_no_signal(song.bpm)
	if metadata.has("waveform"): waveform=metadata.waveform
	else: build_waveform()
	if not song_metadata.has(str(song.id)):
		song_metadata[str(song.id)]={"duration":length(),"waveform":waveform,"notes":saved_notes.duplicate(true),"note_count":saved_notes.size(),"has_chart":library.has_chart(str(song.id))}
	if chart_library:
		chart_library.update_selection()
		chart_library.update_card_metadata(str(song.id))
	refresh_editor()
	if metadata.has("chart_error"): tell(str(metadata.chart_error))
	if not library.message.is_empty(): tell(library.message)

func save_editor() -> void:
	stop_audition()
	var sorted=document.notes.duplicate(true); sorted.sort_custom(func(a,b):return a.time<b.time)
	if library.save_chart(song.id,sorted)!=OK: tell("Could not save. Your draft is still here; check storage."); return
	saved_notes=sorted; document.dirty=false
	if song_metadata.has(str(song.id)):
		song_metadata[str(song.id)].notes=sorted.duplicate(true)
		song_metadata[str(song.id)].note_count=sorted.size()
		song_metadata[str(song.id)].has_chart=true
	refresh_editor(); refresh_library()
	tell("Chart saved. Open LIBRARY to choose another song, or TEST CHART to play it.")

func refresh_editor() -> void:
	title_label.text="SYNK STUDIO / "+song.title+("  *" if document.dirty else "")
	studio_cover.texture=cover_texture_for_id(str(song.id))
	studio_cover.modulate=cover_tint_for_id(str(song.id)) if song.id!="eclipse" and not has_custom_cover(str(song.id)) else Color.WHITE
	studio_cover_button.visible=song.id!="eclipse"
	var n=document.selection()
	info.text="%d notes   •   %.2f / %.2f s   •   %s BPM" % [document.notes.size(),cursor,length(),song.bpm] if n.is_empty() else "%s   %.3f s   LANE %d   TAIL %.2f s   END %d   %s" % [n.kind.to_upper(),n.time,int(n.lane)+1,n.duration,int(n.end_lane)+1,["UP","RIGHT","DOWN","LEFT"][int(n.direction)] if n.kind=="flick" else ""]
	snap_button.text="SNAP OFF" if snap_division==0 else "SNAP 1/"+str(snap_division*4)
	loop_button.text="LOOP ON" if loop_enabled else "LOOP OFF"; speed_button.text=str(audition_speed)+"× SPEED"; refresh_transport()
func refresh_transport() -> void:
	updating=true; seek.max_value=length(); seek.set_value_no_signal(cursor); updating=false; play_button.text="PAUSE" if audio.playing else "PLAY"
func seek_to(time: float) -> void:
	cursor=clampf(time,0,maxf(0,length()-.001))
	if audio.playing: audio.seek(cursor)
	refresh_editor()
func toggle_audition() -> void:
	if audio.playing: stop_audition()
	else: audio.pitch_scale=audition_speed; audio.play(clampf(cursor,0,maxf(0,length()-.001)))
	refresh_editor()
func stop_audition() -> void: audio.stop(); audio.stream_paused=false; audio.pitch_scale=1
func nudge(direction: int,lane: int) -> void:
	var n=document.selection()
	if n.is_empty(): return
	document.checkpoint(); document.move_note(float(n.time)+direction*(.01 if snap_division==0 else 60.0/song.bpm/snap_division),int(n.lane)+lane,length()); refresh_editor()
func resize_note(direction: int) -> void:
	var n=document.selection()
	if not n.is_empty(): document.resize(float(n.duration)+direction*60.0/song.bpm/4,length()); refresh_editor()
func duplicate_note() -> void:
	var n=document.selection()
	if n.is_empty(): return
	document.checkpoint(); n=n.duplicate(true); n.time=minf(maxf(0,length()-float(n.duration)),float(n.time)+60.0/song.bpm); document.notes.append(n); document.selected=document.notes.size()-1; refresh_editor()

func build_waveform() -> void:
	waveform=SynkLibrary.waveform_for_stream(audio.stream)
