extends Control

const UiMotion = preload("res://scripts/ui_motion.gd")
const ScreenStyle = preload("res://scripts/screen_style.gd")
const UiSound = preload("res://scripts/ui_sound.gd")
const StageIntro = preload("res://scripts/stage_intro.gd")
const ResultsScreen = preload("res://scripts/results_screen.gd")
const NeonAction = preload("res://scripts/neon_action.gd")
const ECLIPSE_COVER = preload("res://assets/lobby/eclipse_cover.png")
const CUSTOM_COVER = preload("res://assets/lobby/custom_cover.png")

const COMBO_ATLAS = preload("res://assets/hud/Combo_Digits_1_to_9.png")
const COMBO_ZERO = preload("res://assets/hud/Combo_Digit_0.png")
const HUD_GLOW_SHADER = preload("res://scripts/hud_glow.gdshader")
const HUD_GLOW_PAD = 0.1
const JUDGEMENT_ART = {
	"PERFECT": preload("res://assets/hud/PERFECT.png"),
	"GREAT": preload("res://assets/hud/GREAT.png"),
	"GOOD": preload("res://assets/hud/GOOD.png"),
	"MISS": preload("res://assets/hud/MISS.png")
}

var library = SynkLibrary.new()
var document = SynkChart.new()
var capture = SynkCapture.new()
var recorder: Node
var audio = AudioStreamPlayer.new()
var mr: Node
var beat_clock: Node
var menu_music: AudioStreamPlayer
var extras: Node
var practice: Node
var practice_hud: Label
var timing_label: Label
var timing_samples: Array=[]
var performance_samples: Array=[]
var demo_stream: AudioStream
var song_metadata: Dictionary = {}
var song_cover_textures: Dictionary = {}
var song_background_textures: Dictionary = {}
var song_details: Control
var cover_palettes: Dictionary = {}
var metadata_queue: Array[String] = []
var metadata_worker = Thread.new()
var worker_song_id = ""
var loading_song_index = -1
var loading_open_editor = false
var song = {"id":"eclipse", "title":"Eclipse", "bpm":128.0}
# Play modes: the whole song, or one section bounded by the song's Verse 2 / Bridge marks.
const SECTION_NAMES = {"full":"FULL SONG","verse1":"VERSE 1","verse2":"VERSE 2","bridge":"BRIDGE"}
var play_mode = "full"
var last_section = "full"
var play_range = Vector2(0,INF)
var play_finish_time = INF
# Section runs (anything but the full song) start the music early and fade it in and out.
const SECTION_LEAD_IN = 5.0
const SECTION_FADE_IN = 3.0
const SECTION_FADE_OUT = 2.5
var section_fade_in_start = -INF
var section_fade_in_end = -INF
var section_fade_out_start = INF
var saved_notes: Array = []
var saved_settings: Dictionary={}
var play_settings: Dictionary={}
var run_settings_active=false
var mode = "menu"
var paused_mode = "play"
var auto_play = false
var pause_had_audio = false
var song_time = 0.0
var visual_song_time = 0.0
var visual_clock_ready = false
var visual_clock_target = 0.0
var live: Array = []
var live_cursor = 0
var judgement_total_cache = 0
var judgement_total_size = -1
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
# "rectangle" or "circle"; chosen in Settings.
var note_shape = "circle"
# Highway slope in degrees (Settings): low is flat and far-reaching, high looks down steeply.
var highway_angle = 29.0
# Highway look: "gold" or "neon", optional custom rail/band colors ("" follows the style),
# and how dark the see-through highway surface is (1 = the style's default).
var highway_style = "gold"
var rail_color = ""
var band_color = ""
var highway_opacity = 1.0
# "adaptive" colors notes and highway from the song's artwork; "theme" keeps the style's own colors.
var highway_colors = "adaptive"
var gameplay_colors: Dictionary = {}
var rail_glow_opacity = .12
var note_size=1.0
var hold_trail_width=1.0
var trail_style="neon"
var resume_grace = 0.0
var overdub = false
var ghost_recording=true
var ghost_button: Button
var note_lines = true
var note_lines_button: Button
var record_mark_buttons: Dictionary = {}
var dots_button: Button
# Arrange tool: tap the selected hold/slide trail to add or remove checkpoint dots.
var dots_mode = false
var countdown_ring: Control
var countdown_shown = -1
# How far (in lanes) the finger may be from the trail when a checkpoint dot is judged.
const CHECKPOINT_LANE_TOLERANCE = 2.0
var studio_mark_buttons: Dictionary = {}
var tool = "auto"
var cursor = 0.0
var zoom_seconds = 8.0
var snap_division = 4
var loop_a = 0.0
var loop_b = 8.0
var loop_enabled = false
var audition_speed = 1.0
const RECORD_SPEEDS=[1.0,.75,.5,.25,1.25,1.5]
var recorder_note_speed=1.0
var recorder_note_speed_button: Button
var record_speed: float=1.0
var record_speed_button: Button
var waveform: PackedFloat32Array = []
var prefs = ConfigFile.new()
var field: Control
signal safe_area_changed
var safe_area_rect = Rect2()
var safe_control_roots: Array = []

var toast_layer: CanvasLayer
var floating_text_input: CanvasLayer
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
# The finish animation that carries the combo from the stage into the results screen.
var finish_overlay: Control
var finishing = false
var finish_elapsed = 0.0
var pending_results: Dictionary = {}
var slide_tools: Control
var sync_helper: Control
var bluetooth_toggle: Button
var bluetooth_latency_input: Control
var primary: Button
var pause_home: Button
var pause_restart: Button
var countdown_label: Label
var actions: Control
var hud: Label
var score_panel: SynkScoreHud
var hud_shadow: TextureRect
var results_screen: Control
# Judgments in the current run, for the results breakdown.
var judgment_counts = {"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0}
var combo_hud: Control
var combo_digit_textures: Array[Texture2D] = []
var combo_art_value = -1
var combo_art_size = Vector2.ZERO
var combo_glow: ShaderMaterial
var hit_glow: ShaderMaterial
var song_hud: Label
var rank_hud: Label
var difficulty_hud: Label
var auto_play_hud: Label
var guide_button: Button
var guide_back: Button
var hit_label: Label
var hit_art: TextureRect
var pause_button: Button
var stage_intro: Control
# Tests turn this off so they can drive gameplay frames directly.
var stage_intro_enabled = true
var record_tools: Control
var record_sidebar: Panel
var studio: Panel
var status: Label
var info: Label
var title_label: Label
var play_button: Button
var snap_button: Button
var loop_button: Button
var speed_button: Button
var seek: HSlider
var features: Node
var timeline: Control
var editor_tool = "select"
var song_list: ItemList
var picker: FileDialog
var updating = false
var last_play_notes: Array = []
var record_info: Label
var record_help: Label
var arrange_button: Button
var kind_buttons: Array[Button] = []
var studio_kind_buttons: Dictionary = {}
var arrange_selection: Dictionary = {}
var arranging = false
var arrange_touches: Dictionary = {}

# Fira Sans (SIL Open Font Licence, assets/fonts/OFL.txt) is the game's typeface. Every screen
# builds its fonts from ThemeDB.fallback_font, so it is swapped before any of them is created.
const GAME_FONT = preload("res://assets/fonts/FiraSans-Regular.ttf")
func _enter_tree() -> void:
	ThemeDB.fallback_font=GAME_FONT

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	process_priority=-10
	Engine.max_fps = 120
	if OS.has_feature("android"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	prefs.load("user://preferences.cfg"); timing_ms = float(prefs.get_value("audio","offset_ms",0))
	bluetooth_mode=bool(prefs.get_value("audio","bluetooth_mode",false))
	bluetooth_latency_ms=clampf(float(prefs.get_value("audio","bluetooth_latency_ms",180)),0,600)
	note_lines=bool(prefs.get_value("editor","note_lines",true))
	ghost_recording=bool(prefs.get_value("editor","ghost_recording",true))
	recorder_note_speed=clampf(float(prefs.get_value("editor","note_speed",1.0)),.5,3.0)
	record_speed=float(prefs.get_value("editor","record_speed",1.0))
	if record_speed not in RECORD_SPEEDS: record_speed=1.0
	note_speed = clampf(float(prefs.get_value("gameplay","note_speed",1.0)), .5, 3.0)
	note_shape = str(prefs.get_value("gameplay","note_shape","circle"))
	if note_shape not in ["rectangle","circle"]: note_shape="rectangle"
	highway_angle = clampf(float(prefs.get_value("gameplay","highway_angle",29.0)),18.0,44.0)
	highway_style = str(prefs.get_value("highway","style","gold"))
	if highway_style not in ["gold","neon"]: highway_style="gold"
	rail_color = str(prefs.get_value("highway","rail_color",""))
	band_color = str(prefs.get_value("highway","band_color",""))
	highway_opacity = clampf(float(prefs.get_value("highway","opacity",1.0)),.3,1.6)
	highway_colors = str(prefs.get_value("highway","colors","adaptive"))
	if highway_colors not in ["adaptive","theme"]: highway_colors="adaptive"
	var saved_colors=prefs.get_value("highway","element_colors",{})
	if saved_colors is Dictionary:
		for key in saved_colors:
			if SynkGameplayColors.valid_key(str(key)) and Color.html_is_valid(str(saved_colors[key])): gameplay_colors[str(key)]=str(saved_colors[key])
	rail_glow_opacity=clampf(float(prefs.get_value("highway","rail_glow_opacity",.12)),0,.3)
	note_size=clampf(float(prefs.get_value("gameplay","note_size",1.0)),.6,1.25)
	trail_style=str(prefs.get_value("gameplay","trail_style","neon"))
	if trail_style not in ["neon","solid"]: trail_style="neon"
	hold_trail_width=clampf(float(prefs.get_value("gameplay","hold_trail_width",1.0)),.3,1.5)
	features=load("res://scripts/workbench.gd").new(); features.game=self; add_child(features)
	song = eclipse_song()
	add_child(audio); demo_stream = SynkLibrary.synth_demo(); audio.stream = demo_stream
	mr=load("res://scripts/mr_audio.gd").new(); mr.game=self; add_child(mr); mr.set_source(demo_stream)
	beat_clock=load("res://scripts/beat_clock.gd").new(); beat_clock.game=self; add_child(beat_clock)
	menu_music=load("res://scripts/menu_music.gd").new(); menu_music.game=self; add_child(menu_music)
	recorder=load("res://scripts/recorder_session.gd").new(); recorder.game=self; add_child(recorder)
	practice=load("res://scripts/practice_mode.gd").new(); practice.game=self; add_child(practice)
	add_child(UiSound.new())
	audio.finished.connect(_audio_finished)
	field = Control.new(); field.set_script(load("res://scripts/highway.gd")); field.game = self; add_child(field); field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui = Control.new(); ui.theme=preload("res://scripts/game_theme.gd").create(); add_child(ui); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_safe_area(); get_viewport().size_changed.connect(apply_safe_area)
	toast_layer=preload("res://scripts/toast_notifications.gd").new()
	toast_layer.game=self; add_child(toast_layer)
	# Cutout insets may arrive after immersive mode, without a window resize.
	var safe_poll=Timer.new(); safe_poll.name="SafeAreaPoll"; safe_poll.wait_time=.5; safe_poll.autostart=true
	safe_poll.timeout.connect(apply_safe_area); add_child(safe_poll)
	build_combo_digit_textures()
	build_ui()
	lobby=Control.new(); lobby.set_script(load("res://scripts/lobby.gd")); lobby.game=self
	ui.add_child(lobby); lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.move_child(lobby,0)
	build_studio()
	chart_library=Control.new(); chart_library.set_script(load("res://scripts/chart_library.gd")); chart_library.game=self
	ui.add_child(chart_library); chart_library.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.move_child(chart_library,1)
	extras=preload("res://scripts/gameplay_extras.gd").new(); extras.game=self; add_child(extras)
	settings_panel=Control.new(); settings_panel.set_script(load("res://scripts/settings_screen.gd")); settings_panel.game=self
	ui.add_child(settings_panel); settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.move_child(settings_panel,2); settings_panel.visible=false
	song_details=Control.new(); song_details.set_script(load("res://scripts/song_details.gd")); song_details.game=self
	ui.add_child(song_details); song_details.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.move_child(song_details,3); song_details.visible=false
	bluetooth_toggle=settings_panel.bluetooth_toggle; bluetooth_latency_input=settings_panel.bluetooth_latency_input
	sync_helper=Control.new(); sync_helper.set_script(load("res://scripts/sync_helper.gd")); sync_helper.game=self
	ui.add_child(sync_helper); sync_helper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.move_child(sync_helper,3); sync_helper.visible=false
	saved_notes = library.load_chart("eclipse")
	get_window().files_dropped.connect(func(files):
		if files.size()>0 and mode in ["menu","library","editor"]:
			open_editor(); import_audio(files[0]))
	get_tree().auto_accept_quit = false
	finish_overlay=Control.new(); finish_overlay.set_script(load("res://scripts/finish_overlay.gd")); finish_overlay.game=self
	ui.add_child(finish_overlay)
	set_mode("menu")
	build_waveform()
	floating_text_input=preload("res://scripts/floating_text_input.gd").new()
	floating_text_input.game=self; add_child(floating_text_input)
	features.activate_song()
	for scope in [settings_panel,studio,sync_helper,record_tools]: preload("res://scripts/interface_life.gd").mount(scope)
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
	if selected and toast_layer: toast_layer.clear_progress()
	if result.has("error"):
		song_metadata[id]={"error":result.error}
		if chart_library: chart_library.update_card_metadata(id)
		# Covers and durations arrive after the lobby list is built; refresh that song's card.
		if lobby: lobby.update_track_card(id)
		if selected:
			loading_song_index=-1; loading_open_editor=false; tell(str(result.error))
			if lobby:
				lobby.update_selected_track()
	else:
		if not song_metadata.has(id):
			song_metadata[id]={"duration":result.duration,"waveform":result.waveform,"notes":result.notes,"note_count":result.note_count,"has_chart":result.has_chart}
			if result.has("chart_error"): song_metadata[id].chart_error=result.chart_error
			if result.has("cover") and not song_cover_textures.has(id): song_cover_textures[id]=ImageTexture.create_from_image(result.cover); cover_palettes.erase(id)
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
		if lobby: lobby.update_track_card(id)
	start_song_worker()

# Android returns physical display pixels; layouts use stretched scene coordinates.
func set_safe_area_pixels(display_safe: Rect2, window_pixels: Vector2) -> void:
	var available=Rect2(Vector2.ZERO,size)
	if window_pixels.x>0 and window_pixels.y>0 and display_safe.has_area():
		var clipped=display_safe.intersection(Rect2(Vector2.ZERO,window_pixels))
		if clipped.has_area(): available=Rect2(clipped.position/window_pixels*size,clipped.size/window_pixels*size)
	if safe_area_rect.is_equal_approx(available): return
	safe_area_rect=available
	refresh_safe_controls()
	safe_area_changed.emit()

func refresh_safe_controls() -> void:
	for index in range(safe_control_roots.size()-1,-1,-1):
		var root=safe_control_roots[index].get_ref()
		if root==null: safe_control_roots.remove_at(index)
		else: fit_safe_control(root,root.get_parent())

func apply_safe_area() -> void:
	# The UI, highway, backgrounds and overlays always cover the full window.
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe=Rect2(DisplayServer.get_display_safe_area()) if OS.has_feature("mobile") else Rect2()
	set_safe_area_pixels(safe,Vector2(DisplayServer.window_get_size()))

func safe_rect_for(parent: Control) -> Rect2:
	var bounds=safe_area_rect if safe_area_rect.has_area() else Rect2(Vector2.ZERO,size)
	var local=parent.get_global_transform_with_canvas().affine_inverse()*get_global_transform_with_canvas()
	return Rect2(local*bounds.position,local.basis_xform(bounds.size))

func fit_safe_control(target: Control,parent: Control) -> void:
	var bounds=safe_rect_for(parent)
	target.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	target.position=bounds.position; target.size=bounds.size

func safe_parent(layer_name: String,parent: Control=null) -> Control:
	if parent==null: parent=ui
	var layer=Control.new(); layer.name=layer_name; layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer); safe_control_roots.append(weakref(layer))
	fit_safe_control(layer,parent)
	if not parent.resized.is_connected(refresh_safe_controls): parent.resized.connect(refresh_safe_controls)
	return layer

func rect(node: Control, parent: Node, x: float, y: float, right: float, bottom: float) -> void:
	parent.add_child(node); node.anchor_left=x; node.anchor_top=y; node.anchor_right=right; node.anchor_bottom=bottom
	node.offset_left=0; node.offset_top=0; node.offset_right=0; node.offset_bottom=0

func label(parent: Node, text: String, x: float,y: float,right: float,bottom: float,font_size=22) -> Label:
	var result=Label.new(); rect(result,parent,x,y,right,bottom); result.text=text; result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",Color("eee9ff")); result.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

# variant picks the button's role in the design system (see NeonAction.VARIANTS).
func button(parent: Node,text: String,x: float,y: float,right: float,bottom: float,action: Callable,variant: String = "secondary") -> Button:
	var result=load("res://scripts/recorder_action.gd").new() if record_tools!=null and parent==record_tools else NeonAction.new()
	result.text=text; result.caption_size=19 if variant in ["primary","record"] else 17; result.compact=true
	result.variant=variant
	if record_tools!=null and parent==record_tools: result.caption_size=21
	rect(result,parent,x,y,right,bottom)
	result.pressed.connect(action)
	return result

func pause_action(parent: Node,text: String,x: float,y: float,right: float,bottom: float,action: Callable,variant: String) -> Button:
	var result=load("res://scripts/pause_action.gd").new()
	result.text=text; result.caption_size=19; result.compact=true; result.variant=variant
	rect(result,parent,x,y,right,bottom); result.pressed.connect(action)
	return result

func build_ui() -> void:
	# Song details sit top right, leaving the left side for energy and score.
	song_hud=label(ui,"",.62,.015,.91,.105,25); song_hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	difficulty_hud=label(ui,"EXPERT   Lv. 12",.62,.105,.91,.15,18); difficulty_hud.add_theme_color_override("font_color",Color(1,1,1,.62)); difficulty_hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	auto_play_hud=label(ui,"AUTO PLAY  •  PREVIEW",.39,.13,.61,.19,22); auto_play_hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	auto_play_hud.add_theme_color_override("font_color",Color("38baff"))
	# A soft dark shadow keeps the pause button, energy and score readable over any cover.
	hud_shadow=TextureRect.new(); rect(hud_shadow,ui,-.04,-.06,.40,.28); hud_shadow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shadow_texture=GradientTexture2D.new(); shadow_texture.width=256; shadow_texture.height=256
	shadow_texture.fill=GradientTexture2D.FILL_RADIAL; shadow_texture.fill_from=Vector2(.5,.5); shadow_texture.fill_to=Vector2(1,.5)
	var shadow_ramp=Gradient.new(); shadow_ramp.offsets=PackedFloat32Array([0.0,.55,1.0])
	shadow_ramp.colors=PackedColorArray([Color(0,0,.01,.72),Color(0,0,.01,.45),Color(0,0,.01,0)])
	shadow_texture.gradient=shadow_ramp; hud_shadow.texture=shadow_texture
	hud_shadow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; hud_shadow.stretch_mode=TextureRect.STRETCH_SCALE
	ui.move_child(hud_shadow,0)
	# Energy gauge and score stack on the left, next to the pause button.
	score_panel=SynkScoreHud.new(); rect(score_panel,safe_parent("SafeScoreHud"),.1,.025,.34,.205)
	hud=score_panel.score_label
	combo_hud=Control.new(); rect(combo_hud,ui,.3,.31,.7,.47)
	combo_hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	rank_hud=label(ui,"SS",.925,.015,.99,.12,46); rank_hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	rank_hud.add_theme_color_override("font_color",Color("b985ff")); rank_hud.add_theme_color_override("font_outline_color",Color("5921a8")); rank_hud.add_theme_constant_override("outline_size",5)
	pause_button=button(safe_parent("SafePauseButton"),"II",.02,.025,.08,.105,toggle_pause,"nav")
	# Judgments are plain bold white text for now, so they suit any cover palette.
	hit_label=label(ui,"",.3,.235,.7,.305,40); hit_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	timing_label=label(ui,"",.3,.305,.7,.34,18); timing_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	practice_hud=label(ui,"",.33,.025,.74,.08,18); practice_hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var bold=FontVariation.new(); bold.base_font=ThemeDB.fallback_font; bold.variation_embolden=1.0
	hit_label.add_theme_font_override("font",bold)
	hit_label.add_theme_color_override("font_shadow_color",Color(0,0,.02,.6)); hit_label.add_theme_constant_override("shadow_outline_size",8)
	hit_label.add_theme_constant_override("shadow_offset_x",0); hit_label.add_theme_constant_override("shadow_offset_y",2)
	# Judgments are smaller, silver and softly lit so they never fight the cover-colored combo.
	hit_art=TextureRect.new(); rect(hit_art,ui,.32,.452,.68,.552)
	hit_glow=glow_material(Color(1,1,1,.35)); hit_art.material=hit_glow
	hit_glow.set_shader_parameter("monochrome",1.0); hit_glow.set_shader_parameter("strength",.35)
	hit_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	hit_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hit_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# 3-2-1 countdown centered over the highway with a draining ring.
	countdown_ring=Control.new(); rect(countdown_ring,ui,.35,.24,.65,.59); countdown_ring.mouse_filter=Control.MOUSE_FILTER_IGNORE
	countdown_ring.draw.connect(draw_countdown_ring)
	countdown_label=label(ui,"",.35,.28,.65,.55,128); countdown_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_color_override("font_outline_color",Color("5c23ac")); countdown_label.add_theme_constant_override("outline_size",10)
	guide_button=button(safe_parent("SafeGuideButton"),"NOTE GUIDE",.84,.16,.98,.22,func(): set_mode("guide"))
	guide_back=button(safe_parent("SafeGuideBack"),"‹  BACK",.40,.85,.60,.96,func(): set_mode("menu"),"nav")
	# Song intro sits above the HUD and below the pause/results modal.
	stage_intro=StageIntro.new(); stage_intro.game=self; ui.add_child(stage_intro)
	results_screen=ResultsScreen.new(); results_screen.game=self; ui.add_child(results_screen)
	# Pause: the stage behind is blurred and dimmed, with a frosted card on top (same glass as
	# the lobby cards) holding three icon tiles.
	pause_backdrop=ColorRect.new(); rect(pause_backdrop,ui,0,0,1,1); pause_backdrop.color=Color.WHITE
	pause_backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var blur=ShaderMaterial.new(); blur.shader=preload("res://scripts/frosted_glass.gdshader"); pause_backdrop.material=blur
	blur.set_shader_parameter("radius",0.0); blur.set_shader_parameter("blur",3.0); blur.set_shader_parameter("tint",Color(0,0,.03,.55))
	pause_backdrop.resized.connect(func(): blur.set_shader_parameter("rect_size",pause_backdrop.size))
	modal=Panel.new(); rect(modal,safe_parent("SafeModal"),.19,.11,.81,.89)
	modal.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var glass=ColorRect.new(); glass.name="FrostedGlass"; modal.add_child(glass); glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var glass_material=ShaderMaterial.new(); glass_material.shader=preload("res://scripts/frosted_glass.gdshader"); glass.material=glass_material
	glass_material.set_shader_parameter("blur",4.0); glass_material.set_shader_parameter("tint",Color(.035,.028,.08,.62))
	glass.resized.connect(func(): glass_material.set_shader_parameter("rect_size",glass.size); glass_material.set_shader_parameter("radius",28.0))
	modal_title=label(modal,"S Y N K",.04,.025,.96,.17,48); modal_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	modal_title.add_theme_font_override("font",preload("res://assets/fonts/FiraSans-Bold.ttf"))
	modal_body=label(modal,"",.06,.17,.94,.43,22); modal_body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; modal_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	primary=pause_action(modal,"PLAY",.23,.88,.77,.97,primary_action,"primary")
	pause_restart=pause_action(modal,"RESTART",.36,.88,.64,.97,restart_from_pause,"secondary")
	pause_home=pause_action(modal,"HOME",.66,.88,.94,.97,return_home,"nav")
	actions=Control.new(); rect(actions,safe_parent("SafeActions"),0,0,1,1); actions.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button(actions,"●  RECORD NEW",.02,.91,.20,.98,start_new_recording,"record")
	button(actions,"PLAY SAVED",.22,.91,.39,.98,func(): start_game(saved_notes),"primary")
	button(actions,"AUTO PLAY",.41,.91,.58,.98,start_autoplay)
	button(actions,"CHART STUDIO / IMPORT AUDIO",.60,.91,.98,.98,open_editor)
	record_tools=Control.new(); rect(record_tools,safe_parent("SafeRecorderControls"),0,0,1,1); record_tools.mouse_filter=Control.MOUSE_FILTER_IGNORE
	record_tools.set_meta("keep_caption_size",true)
	recorder_plate(Rect2(.11,.008,.88,.117))
	record_sidebar=recorder_plate(Rect2(.015,.14,.19,.575))
	recorder_plate(Rect2(.65,.14,.335,.116))
	recorder_plate(Rect2(.025,.901,.95,.093))
	var type_heading=label(record_tools,"NOTE TYPE",.125,.012,.57,.043,13)
	type_heading.add_theme_color_override("font_color",Color("7fd7e7"))
	label(record_tools,"TAKE CONTROLS",.60,.012,.98,.043,13).add_theme_color_override("font_color",Color("b9b3d4"))
	label(record_tools,"RECORDING AIDS",.03,.148,.19,.18,13).add_theme_color_override("font_color",Color("7fd7e7"))
	var kinds=["auto","tap","hold","slide","flick"]
	for i in kinds.size():
		var kind=kinds[i]
		kind_buttons.append(button(record_tools,kind.to_upper(),.12+i*.094,.047,.205+i*.094,.114,func():
			if arranging:
				if kind=="auto": delete_arrange_note()
				else: change_arrange_note_type(kind)
			else:
				tool=kind; judgement=kind.to_upper()+" TOOL"; flash=1; refresh_arrange_controls(),"tool"))
		kind_buttons[-1].tooltip_text={"auto":"Detect taps, holds, and slides automatically", "tap":"Record individual taps", "hold":"Press and hold in a lane", "slide":"Hold and drag between lanes", "flick":"Swipe to set the flick direction"}[kind]
	arrange_button=button(record_tools,"CORRECT",.60,.047,.735,.114,toggle_arrange)
	arrange_button.tooltip_text="Pause the music to move or correct notes, then resume recording"
	button(record_tools,"UNDO",.745,.047,.835,.114,undo_record_note,"tool")
	button(record_tools,"STOP & REVIEW",.845,.047,.98,.114,stop_take,"record")
	record_info=label(record_tools,"",.67,.148,.97,.228,21); record_info.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	recorder.progress=ProgressBar.new(); rect(recorder.progress,record_tools,.67,.235,.967,.245)
	recorder.progress.show_percentage=false; recorder.progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var track=StyleBoxFlat.new(); track.bg_color=Color("29283f"); track.set_corner_radius_all(4)
	var fill=track.duplicate(); fill.bg_color=Color("ff6489")
	recorder.progress.add_theme_stylebox_override("background",track); recorder.progress.add_theme_stylebox_override("fill",fill)
	note_lines_button=button(record_tools,"",.025,.19,.195,.258,toggle_note_lines,"tool"); update_note_lines_button()
	# Mark where Verse 2 and the Bridge start while the song plays.
	record_mark_buttons["verse2"]=button(record_tools,"",.025,.278,.195,.346,func(): mark_section("verse2",song_time),"tool")
	record_mark_buttons["bridge"]=button(record_tools,"",.025,.366,.195,.434,func(): mark_section("bridge",song_time),"tool")
	dots_button=button(record_tools,"",.025,.454,.195,.522,toggle_dots_mode,"tool")
	ghost_button=button(record_tools,"GHOST ON" if ghost_recording else "GHOST OFF",.025,.454,.195,.522,toggle_ghost_recording,"tool")
	ghost_button.tooltip_text="Show faded existing chart notes approaching the judgment line while recording a new layer."
	record_help=label(record_tools,"AUTO records taps, holds and slides. Choose FLICK for a directed swipe.\nRecord near the glowing line. STOP to edit your take.",.04,.91,.625,.985,17); record_help.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	mr.register_button(button(record_tools,"MR OFF",.64,.913,.79,.984,mr.toggle,"tool"))
	record_speed_button=button(record_tools,str(record_speed)+"× SPEED",.80,.913,.965,.984,cycle_record_speed,"tool")
	record_speed_button.tooltip_text="Recording playback speed: 1×, 0.75×, 0.5×, 0.25×, 1.25×, 1.5×"
	button(record_tools,"TAKE SETUP",.025,.542,.195,.61,recorder.show_setup,"tool")
	recorder_note_speed_button=button(record_tools,"NOTES  "+str(recorder_note_speed)+"×",.025,.63,.195,.698,cycle_recorder_note_speed,"tool")
	recorder_note_speed_button.tooltip_text="Note travel speed only. Music playback speed stays unchanged."

func recorder_plate(bounds: Rect2) -> Panel:
	var panel=Panel.new(); rect(panel,record_tools,bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var plate=StyleBoxFlat.new(); plate.bg_color=Color(.025,.03,.075,.94)
	plate.border_color=Color("303349"); plate.set_border_width_all(1); plate.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel",plate); return panel

func set_mode(value: String) -> void:
	if value!=mode:
		# Menus slide forward and back by depth; entering or leaving the stage dissolves.
		var depth={"menu":0,"guide":1,"library":1,"editor":2,"results":3}
		if value in ["play","record","paused"] or mode in ["play","record","paused"]: UiMotion.transition(self,.24,0)
		else: UiMotion.transition(self,.38,-1 if int(depth.get(value,1))<int(depth.get(mode,1)) else 1)
	if value in ["play","record"] and loading_song_index>0:
		loading_song_index=-1; loading_open_editor=false
	# Moving between menu screens gets a soft whoosh; gameplay screens stay silent.
	if value!=mode and value in ["menu","library","editor","guide"]: UiSound.play(self,"transition")
	mode=value; menu_settings_open=false
	if value in ["menu","library","editor","record"]: run_settings_active=false
	if practice and value in ["menu","editor","library","record"]: practice.active=false
	# Leaving the finish for anything but its results ends it immediately.
	finishing=false
	if finish_overlay and value!="results": finish_overlay.stop()
	if field: field.modulate.a=1.0
	if audio: update_section_volume()
	if mode in ["menu","library","editor"]: start_song_worker()
	studio.visible=mode=="editor"; modal.visible=mode=="paused"
	if mode!="results": results_screen.visible=false
	lobby.visible=mode=="menu"
	chart_library.visible=mode=="library"
	if song_details: song_details.visible=false
	pause_backdrop.visible=mode=="paused"
	actions.visible=false; record_tools.visible=mode=="record"
	hud.visible=mode in ["play","paused"]; score_panel.visible=hud.visible; hud_shadow.visible=hud.visible; hit_label.visible=mode in ["play","record"]; pause_button.visible=mode in ["play","record","paused"]
	hit_art.visible=false
	combo_hud.visible=mode in ["play","paused"] and combo>0
	# The right side of the gameplay screen stays clear of text.
	song_hud.visible=false; song_hud.text=str(song.title)+"\n"+str(chart_bpm())+" BPM / CUSTOM" if song.id!="eclipse" else "Eclipse\nSYNK Originals / EXPERT"
	song_hud.text=str(song.title)+"\n"+album_name(song)
	difficulty_hud.visible=false; difficulty_hud.text="EXPERT   Lv. 12" if song.id=="eclipse" else str(chart_bpm())+" BPM"
	auto_play_hud.visible=auto_play and mode in ["play","paused"]
	# The rank is shown on the results screen, not during play.
	rank_hud.visible=false
	guide_button.visible=false; guide_back.visible=mode=="guide"
	pause_home.visible=mode=="paused"; pause_restart.visible=mode=="paused"
	settings_panel.visible=false; sync_helper.visible=false
	var large_pause=mode=="paused" and paused_mode!="record"
	# Recorder controls retain their compact layout; enlarge only gameplay pause UI.
	pause_button.anchor_right=.095 if mode=="play" or large_pause else .08
	pause_button.anchor_bottom=.125 if mode=="play" or large_pause else .105
	pause_button.caption_size=22 if mode=="play" or large_pause else 17
	modal.anchor_top=(.25 if large_pause else .36) if mode=="paused" else .11
	modal.anchor_bottom=(.75 if large_pause else .64) if mode=="paused" else .89
	modal_title.anchor_top=(.06 if large_pause else .10) if mode=="paused" else .025
	modal_title.anchor_bottom=(.30 if large_pause else .40) if mode=="paused" else .17
	var button_top=(.38 if large_pause else .58) if mode=="paused" else .88
	var button_bottom=(.90 if large_pause else .88) if mode=="paused" else .97
	for action_button in [primary,pause_restart,pause_home]:
		action_button.anchor_top=button_top; action_button.anchor_bottom=button_bottom
		action_button.caption_size=23 if large_pause else (19 if action_button==primary else 17)
	modal_body.anchor_bottom=.65 if mode=="paused" else .43
	primary.anchor_left=.06 if mode=="paused" else .23
	primary.anchor_right=.34 if mode=="paused" else .77
	if mode=="menu":
		lobby.show_gateway()
		lobby.refresh()
		lobby.play_entrance()
	if mode=="library":
		chart_library.refresh()
		UiMotion.screen(chart_library)
	if mode=="editor":
		features.recover()
		refresh_editor()
		UiMotion.screen(studio)
	if mr: mr.sync_mode()

func open_lobby_settings() -> void:
	if mode!="menu": return
	UiMotion.transition(self)
	# Settings is its own page; BACK returns to the lobby.
	menu_settings_open=true
	lobby.visible=false
	settings_panel.refresh(); settings_panel.visible=true
	UiMotion.screen(settings_panel)

func close_lobby_settings() -> void:
	UiMotion.back(self)
	menu_settings_open=false
	settings_panel.visible=false
	if mode=="menu":
		lobby.visible=true
		UiMotion.reveal(lobby)

# The audio sync helper replaces the settings page while it is open; BACK or SAVE return to it.
func open_sync_helper() -> void:
	if not menu_settings_open: return
	UiMotion.transition(self)
	settings_panel.visible=false
	sync_helper.open()
	UiMotion.reveal(sync_helper)

func close_sync_helper() -> void:
	UiMotion.back(self)
	sync_helper.visible=false
	if menu_settings_open:
		settings_panel.visible=true
		UiMotion.reveal(settings_panel)

# Chart Studio slide shaping: smooth into a soft curve, snap onto lanes, or reset to a plain sweep.
func reshape_slide(action: String) -> void:
	var n: Dictionary=document.selection()
	if n.is_empty() or n.kind!="slide": return
	document.checkpoint()
	match action:
		"smooth": n.path=SynkCapture.smooth_path(n)
		"snap": n.path=SynkCapture.snap_path(SynkCapture.sample_path(n),float(n.duration))
		"reset": n.path=[]
	if not n.path.is_empty():
		n.path[0].lane=float(n.lane); n.path[-1].lane=float(roundi(float(n.path[-1].lane)))
		n.end_lane=int(n.path[-1].lane)
	refresh_editor()

func change_note_speed(value: float) -> void:
	note_speed=value
	prefs.set_value("gameplay","note_speed",value); prefs.save("user://preferences.cfg")

func change_highway_angle(value: float) -> void:
	highway_angle=value
	prefs.set_value("gameplay","highway_angle",value); prefs.save("user://preferences.cfg")

func change_highway_look(key: String,value: Variant) -> void:
	match key:
		"style": highway_style = str(value) if str(value) in ["gold","neon"] else "gold"; value = highway_style
		"rail_color": rail_color = str(value); value = rail_color
		"band_color": band_color = str(value); value = band_color
		"opacity": highway_opacity = clampf(float(value),.3,1.6); value = highway_opacity
		"colors": highway_colors = str(value) if str(value) in ["adaptive","theme"] else "adaptive"; value = highway_colors
		_: return
	# Choosing a rail/band swatch replaces that element's color from the Colors tab.
	if key in ["rail_color","band_color"]:
		gameplay_colors.erase("rail" if key=="rail_color" else "band")
		prefs.set_value("highway","element_colors",gameplay_colors)
	prefs.set_value("highway",key,value); prefs.save("user://preferences.cfg")
	if key == "colors": apply_stage_cover()
	field.world.refresh_highway_look()
	if settings_panel: settings_panel.refresh()

func change_gameplay_color(key: String,code: String) -> void:
	if not SynkGameplayColors.valid_key(key) or (code!="" and not Color.html_is_valid(code)): return
	if code=="": gameplay_colors.erase(key)
	else: gameplay_colors[key]=code
	prefs.set_value("highway","element_colors",gameplay_colors); prefs.save("user://preferences.cfg")
	apply_stage_cover()
	if settings_panel: settings_panel.refresh()

func change_rail_glow_opacity(value: float) -> void:
	rail_glow_opacity=clampf(value,0,.3)
	prefs.set_value("highway","rail_glow_opacity",rail_glow_opacity); prefs.save("user://preferences.cfg")
	field.world.refresh_highway_look()

func reset_gameplay_colors() -> void:
	gameplay_colors.clear(); rail_glow_opacity=.12
	prefs.set_value("highway","element_colors",{}); prefs.set_value("highway","rail_glow_opacity",.12); prefs.save("user://preferences.cfg")
	apply_stage_cover()
	if settings_panel: settings_panel.refresh()

func reset_highway_look() -> void:
	for key in ["style","rail_color","band_color","opacity","colors"]: prefs.set_value("highway",key,null)
	highway_style = "gold"; rail_color = ""; band_color = ""; highway_opacity = 1.0; highway_colors = "adaptive"
	prefs.save("user://preferences.cfg")
	apply_stage_cover()
	field.world.refresh_highway_look()
	if settings_panel: settings_panel.refresh()

func change_note_shape(kind: String) -> void:
	note_shape=kind
	prefs.set_value("gameplay","note_shape",kind); prefs.save("user://preferences.cfg")
	field.world.clear_notes()
	settings_panel.refresh()

func change_trail_style(style: String) -> void:
	if style not in ["neon","solid"]: return
	trail_style=style; prefs.set_value("gameplay","trail_style",style); prefs.save("user://preferences.cfg")
	if field and field.world: field.world.clear_notes()
	if settings_panel: settings_panel.refresh()

func change_note_sizing(key: String,value: float) -> void:
	if not is_finite(value): return
	if key=="note_size": note_size=clampf(value,.6,1.25); value=note_size
	elif key=="hold_trail_width": hold_trail_width=clampf(value,.3,1.5); value=hold_trail_width
	else: return
	prefs.set_value("gameplay",key,value); prefs.save("user://preferences.cfg")
	if field and field.world: field.world.clear_notes()

func return_home() -> void:
	if mode!="paused": return
	if paused_mode=="record":
		stop_take(); return
	var return_to_editor=practice.active
	if pause_tween and pause_tween.is_running(): pause_tween.kill()
	if paused_mode=="record" and not capture.notes.is_empty():
		document.checkpoint(); document.notes.append_array(capture.notes.duplicate(true))
		document.dirty=true
	audio.stop(); audio.stream_paused=false; audio.pitch_scale=1
	arranging=false; arrange_touches.clear(); arrange_selection.clear(); arrange_button.text="CORRECT"
	pointers.clear(); capture.gestures.clear(); live.clear()
	countdown=0; resume_countdown=0; song_time=0; flash=0
	set_mode("editor" if return_to_editor else "menu")
	modal.scale=Vector2.ONE; modal.modulate.a=1

func restart_from_pause() -> void:
	if mode!="paused": return
	if pause_tween and pause_tween.is_running(): pause_tween.kill()
	modal.scale=Vector2.ONE; modal.modulate.a=1
	resume_countdown=0
	if practice.active: practice.restart()
	elif paused_mode=="record":
		cursor=start_position
		record_here()
	else:
		start_game(last_play_notes,auto_play,last_section)

func primary_action() -> void:
	if mode=="menu" and menu_settings_open: close_lobby_settings()
	elif mode=="paused": toggle_pause()
	elif mode=="results":
		if practice.active: practice.restart()
		else: start_game(last_play_notes,auto_play,last_section)
	else: start_game(SynkChart.demo() if song.id=="eclipse" else saved_notes)

func start_autoplay() -> void:
	var notes=baseline_notes()
	if notes.is_empty():
		modal_body.text="This song has no chart yet. Record or add notes in Chart Studio, then save it to preview with Auto Play."
		return
	start_game(notes,true)

func baseline_notes() -> Array:
	return saved_notes if features.chart_exists() else (SynkChart.demo() if song.id=="eclipse" and features.current_variant=="original" else [])

func audio_time() -> float:
	return maxf(0,audio.get_playback_position()+(AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency())*audio.pitch_scale)
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

func toggle_note_lines() -> void:
	note_lines=not note_lines; update_note_lines_button()
	prefs.set_value("editor","note_lines",note_lines); prefs.save("user://preferences.cfg")

func update_note_lines_button() -> void:
	note_lines_button.text="LINES: ON" if note_lines else "LINES: OFF"
	note_lines_button.set_selected(note_lines)

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
	var step=maxf(0,delta)*maxf(0,audio.pitch_scale)
	# Detect discontinuities in the audio sample itself, not accumulated phase error.
	# A temporarily stale mixer sample must never pull an approaching note backward.
	var seek_limit=maxf(.25,step*4+.1)
	if not visual_clock_ready or absf(target-visual_clock_target)>seek_limit:
		visual_song_time=target; visual_clock_target=target; visual_clock_ready=true; return
	visual_clock_target=target
	var predicted=visual_song_time+step
	# Notes advance by exactly one frame of music; drift from the audio clock is folded in
	# a little each frame (at most 8% of a step) so motion stays even, never jerky.
	var correction=(target-predicted)*(1.0-exp(-maxf(0,delta)*6.0))
	visual_song_time=maxf(visual_song_time,predicted+clampf(correction,-step*.08,step*.08))
func uses_recorder_colors() -> bool:
	return mode=="record" or (mode=="paused" and paused_mode=="record") or (recorder!=null and recorder.reviewing_audio)

func authoring_lane_gap() -> float:
	return (field.world.NOTE_WIDTH*note_size+.08)/field.world.LANE_WIDTH

func space_authored_notes(incoming: Array,fixed: Array) -> bool:
	var resolved=true
	for note in incoming:
		if not SynkNoteSpacing.place(note,incoming,fixed,authoring_lane_gap()).resolved: resolved=false
	if not resolved: tell("This chord is too crowded to separate. Move a note or reduce its size.")
	return resolved

func note_travel_seconds() -> float: return 2.6 / (recorder_note_speed if uses_recorder_colors() else note_speed)

func cycle_recorder_note_speed() -> void:
	recorder_note_speed=snappedf(recorder_note_speed+.25,.25)
	if recorder_note_speed>3: recorder_note_speed=.5
	recorder_note_speed_button.text="NOTES  "+str(recorder_note_speed)+"×"
	prefs.set_value("editor","note_speed",recorder_note_speed); prefs.save("user://preferences.cfg")
	field.world.clear_notes()
func length() -> float: return audio.stream.get_length()
func accuracy() -> float: return 100.0 if judged==0 else float(earned)/judged*100
# Retire completed notes once; keep long sustains active until their tails finish.
func first_live_index() -> int:
	while live_cursor<live.size() and live[live_cursor].done: live_cursor+=1
	return live_cursor

func total_judgements() -> int:
	if judgement_total_size!=live.size():
		judgement_total_cache=live.size()
		for entry in live:
			if entry.note.kind=="hold": judgement_total_cache+=1
			judgement_total_cache+=entry.note.get("checkpoints",[]).size()
		judgement_total_size=live.size()
	return judgement_total_cache

# Checkpoint dots: when one reaches the bar, the finger must be over the trail's lane.
# Returns false if the hold or slide broke on a missed dot.
func process_checkpoints(entry: Dictionary, finger_lane: float, automated: bool) -> bool:
	var checks: Array=entry.note.get("checkpoints",[])
	while int(entry.get("checks_done",0))<checks.size():
		var index=int(entry.get("checks_done",0))
		var at=float(entry.note.time)+float(checks[index])
		if song_time<at: break
		entry.checks_done=index+1
		var lane=SynkChart.lane_at(entry.note,at)
		if automated or absf(finger_lane-lane)<=CHECKPOINT_LANE_TOLERANCE: pass_checkpoint(entry,lane)
		else: judge(entry,-1); return false
	return true

func pass_checkpoint(entry: Dictionary, lane: float) -> void:
	performance_samples.append({"time":song_time,"weight":1.0,"amount":1})
	field.world.spawn_hit(lane,str(entry.note.kind))
	judged+=1; earned+=1; judgment_counts.PERFECT+=1
	combo+=1; combo_pulse=1.0; max_combo=maxi(combo,max_combo)
	judgement="PERFECT"; flash=1; flash_lane=roundi(lane)
	score=roundi(1000000*earned/maxi(1,total_judgements()))

func forfeit_checkpoints(entry: Dictionary) -> void:
	# A missed or broken note also misses any dots it had not reached.
	var remaining=entry.note.get("checkpoints",[]).size()-int(entry.get("checks_done",0))
	if remaining<=0: return
	entry.checks_done=entry.note.checkpoints.size()
	judged+=remaining; judgment_counts.MISS+=remaining
	for offset in entry.note.checkpoints.slice(entry.note.checkpoints.size()-remaining):
		performance_samples.append({"time":float(entry.note.time)+float(offset),"weight":0.0,"amount":1})
func rank_name() -> String:
	var a=accuracy(); return "SS" if a>=98 else ("S" if a>=95 else ("A" if a>=90 else ("B" if a>=80 else "C")))

# section is a play mode ("full", "verse1", "verse2", "bridge"); empty uses the lobby's choice.
# Draws every word and digit the gameplay HUD can show once, nearly transparent, behind the
# loading card, so the font has the glyphs cached before the first PERFECT or score change.
const HUD_GLYPHS = "PERFECT GREAT GOOD MISS EARLY LATE ON TIME ms 0123456789,.%+-x READY"
func warm_hud_text() -> void:
	var targets = [hit_label, timing_label, hud, auto_play_hud]
	var saved: Array = []
	for label_node in targets:
		if label_node == null: continue
		saved.append([label_node, label_node.text, label_node.visible, label_node.modulate])
		label_node.text = HUD_GLYPHS; label_node.visible = true; label_node.modulate = Color(1, 1, 1, .01)
	for i in 3: await get_tree().process_frame
	for item in saved:
		if not is_instance_valid(item[0]): continue
		# Restore only if gameplay hasn't already replaced the warm-up text.
		if item[0].text == HUD_GLYPHS: item[0].text = item[1]
		item[0].visible = item[2]; item[0].modulate = item[3]

func start_game(notes: Array,automated: bool = false,section: String = "",is_practice: bool=false) -> void:
	# Mirror and other note modifiers apply to real runs; a replay reuses the exact notes it recorded.
	if extras:
		if not extras.replay_pending and not automated: notes=extras.apply_mods(notes)
		extras.begin_run(notes,extras.replay_pending)
	if lobby and not is_practice: lobby.remember_played(str(song.id))
	if mode=="editor" or is_practice: play_settings=document.settings.duplicate(true)
	elif not run_settings_active: play_settings=saved_settings.duplicate(true)
	run_settings_active=true
	practice.active=is_practice; timing_samples.clear(); performance_samples.clear(); timing_label.text=""
	audio.stop(); audio.pitch_scale=1; pointers.clear(); live.clear()
	live_cursor=0; judgement_total_size=-1
	field.world.clear_hit_effects()
	field.world.clear_notes()
	auto_play=automated
	visual_clock_ready=false
	resume_countdown=0
	arranging=false; arrange_touches.clear(); arrange_selection.clear(); arrange_button.text="CORRECT"
	last_section=section if not section.is_empty() else play_mode
	if not section_available(last_section): last_section="full"
	play_range=section_range(last_section)
	var sorted=notes.duplicate(true); sorted.sort_custom(func(a,b): return a.time<b.time)
	sorted=sorted.filter(func(n): return float(n.time)>=play_range.x-.001 and float(n.time)<play_range.y)
	for n in sorted:
		if n.kind=="flick" and int(n.direction)==2: n.direction=0
	last_play_notes=sorted.duplicate(true)
	# A section ends at its boundary, or once its last note (and hold tail) has passed.
	play_finish_time=INF
	if play_range.y<INF:
		var last_end=play_range.x
		for n in sorted: last_end=maxf(last_end,float(n.time)+float(n.duration))
		play_finish_time=minf(length(),maxf(play_range.y,last_end+.6))
	# Sections lead in with up to 5 s of music before their first beat. Notes before the
	# section are already filtered out above, so the lead-in shows an empty highway.
	var lead_in=0.0 if last_section=="full" else minf(SECTION_LEAD_IN,play_range.x)
	section_fade_in_start=-INF; section_fade_in_end=-INF; section_fade_out_start=INF
	if last_section!="full":
		section_fade_in_start=play_range.x-lead_in
		section_fade_in_end=section_fade_in_start+(SECTION_FADE_IN if lead_in>0 else 1.5)
		# The bridge plays out to the song's end; other sections fade after their last note.
		if last_section!="bridge" and play_finish_time<length():
			play_finish_time=minf(length(),play_finish_time+SECTION_FADE_OUT)
			section_fade_out_start=play_finish_time-SECTION_FADE_OUT
	for n in sorted: live.append({"note":n,"started":false,"done":false,"pointer":-999,"error":0.0,"key":"play"+str(live.size())})
	total_judgements()
	score=0; displayed_score=0; combo=0; combo_pulse=0; rank_pulse=0; shown_rank="SS"; hold_pulse_time=0; max_combo=0; earned=0; judged=0; score_panel.energy=.5; score_panel.shown_energy=.5; judgment_counts={"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0}; countdown=3; start_position=play_range.x-lead_in; song_time=start_position-3; judgement="READY"; flash=1
	update_section_volume()
	# A restart only replays the stage entrance; coming from a menu shows the loading card first.
	var restarting=mode in ["play","paused"]
	set_mode("play")
	apply_stage_cover()
	# Build every note of the chart now (behind the loading card); play only shows and hides them.
	field.world.begin_prebuild()
	if stage_intro_enabled:
		# Compile every gameplay shader behind the loading card, not mid-song.
		if not restarting: field.world.prewarm(); warm_hud_text()
		field.world.prefill_hits()
		var tinted=song.id!="eclipse" and not has_custom_cover(str(song.id))
		stage_intro.begin(cover_texture_for_id(str(song.id)),cover_tint_for_id(str(song.id)) if tinted else Color.WHITE,str(song.title),intro_details(),restarting)
		judgement=""
	else: stage_intro.skip()
	for banner in [song_hud,difficulty_hud]:
		banner.modulate.a=0
		banner.scale=Vector2(.96,.96)
		var entrance=create_tween().set_parallel(true)
		entrance.tween_property(banner,"modulate:a",1.0,.35).set_ease(Tween.EASE_OUT)
		entrance.tween_property(banner,"scale",Vector2.ONE,.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func section_gain() -> float:
	if mode not in ["play","paused"] or last_section=="full": return 1.0
	var fade_in=clampf((song_time-section_fade_in_start)/maxf(.01,section_fade_in_end-section_fade_in_start),0,1)
	var fade_out=1.0-clampf((song_time-section_fade_out_start)/SECTION_FADE_OUT,0,1)
	return minf(fade_in,fade_out)

func update_section_volume() -> void:
	audio.volume_db=linear_to_db(maxf(.0001,section_gain()))

func apply_stage_cover() -> void:
	# The song's cover glows behind the highway during play and recording.
	field.world.set_cover(stage_backdrop_for_id(str(song.id)),Color.WHITE)
	var palette=cover_palette_for_id(str(song.id)) if highway_colors=="adaptive" and not uses_recorder_colors() else SynkCoverPalette.fallback()
	palette=palette.duplicate(true)
	palette.notes=palette.notes.duplicate()
	palette.notes.append(palette.notes[1])
	for i in 4: palette.notes[i]=SynkGameplayColors.resolve(self,["tap","hold","flick","slide"][i],palette.notes[i])
	field.world.apply_palette(palette)
	# The combo counter runs through the same colors: tap at the top, sustained, then flick.
	combo_glow.set_shader_parameter("use_gradient",true)
	combo_glow.set_shader_parameter("gradient_top",SynkGameplayColors.resolve(self,"combo",palette.notes[0].lightened(.15)))
	combo_glow.set_shader_parameter("gradient_middle",SynkGameplayColors.resolve(self,"combo",palette.notes[1]))
	combo_glow.set_shader_parameter("gradient_bottom",SynkGameplayColors.resolve(self,"combo",palette.notes[2]))
	combo_glow.set_shader_parameter("glow_color",SynkGameplayColors.resolve(self,"combo",palette.notes[1]))
	hit_label.add_theme_color_override("font_color",SynkGameplayColors.resolve(self,"judgment",Color("eee9ff")))
	hud.add_theme_color_override("font_color",SynkGameplayColors.resolve(self,"score",SynkScoreHud.TEXT_COLOR))
	score_panel.energy_color=SynkGameplayColors.resolve(self,"energy",SynkScoreHud.ENERGY_FILL)
	var hud_color=SynkGameplayColors.resolve(self,"hud",Color("eee9ff"))
	for label in [song_hud,difficulty_hud,practice_hud]: label.add_theme_color_override("font_color",hud_color)
	for child in score_panel.get_children():
		if child is Label and child!=hud: child.add_theme_color_override("font_color",SynkGameplayColors.resolve(self,"hud",SynkScoreHud.TEXT_COLOR))
	rank_hud.add_theme_color_override("font_color",SynkGameplayColors.resolve(self,"hud",Color("b985ff")))
	auto_play_hud.add_theme_color_override("font_color",SynkGameplayColors.resolve(self,"hud",Color("38baff")))

# Gameplay colors come from the song's real cover art; placeholder covers keep the house palette.
func cover_palette_for_id(id: String) -> Dictionary:
	if cover_palettes.has(id): return cover_palettes[id]
	var palette=SynkCoverPalette.fallback()
	if id=="eclipse" or has_custom_cover(id):
		var texture=cover_texture_for_id(id)
		if texture: palette=SynkCoverPalette.from_image(texture.get_image())
	cover_palettes[id]=palette
	return palette

# Scores read with thousands separators: 0, 12,480, 1,000,000.
static func format_score(value: int) -> String:
	var digits=str(absi(value))
	var grouped=""
	for i in digits.length():
		if i>0 and (digits.length()-i)%3==0: grouped+=","
		grouped+=digits[i]
	return ("-" if value<0 else "")+grouped

func countdown_color(number: int) -> Color:
	return SynkGameplayColors.resolve(self,"countdown",[Color("ff7ad9"),Color("a36aff"),Color("38baff")][clampi(number-1,0,2)])

func draw_countdown_ring() -> void:
	var remaining=resume_countdown if resume_countdown>0 else countdown
	var number=ceili(remaining)
	if number<=0: return
	var fraction=remaining-floorf(remaining-.0001) if remaining>0 else 0.0
	var center=countdown_ring.size*.5
	var radius=minf(countdown_ring.size.x,countdown_ring.size.y)*.36
	var color=countdown_color(number)
	countdown_ring.draw_arc(center,radius,0,TAU,64,Color(1,1,1,.10),6.0,true)
	# The ring drains clockwise over the second, with a soft glow under it.
	var sweep=TAU*clampf(fraction,0.0,1.0)
	for layer in [[14.0,.10],[9.0,.18],[5.0,.95]]:
		countdown_ring.draw_arc(center,radius,-PI*.5,-PI*.5+sweep,64,Color(color,layer[1]),layer[0],true)

func intro_details() -> String:
	var difficulty=features.current_variant.to_upper()
	var section="" if last_section=="full" else SECTION_NAMES[last_section]+"   •   "
	return "%s%s   •   %d BPM%s" % [section,difficulty,roundi(float(chart_bpm())),"   •   AUTO PLAY" if auto_play else ""]

# --- song config and sections ---
func eclipse_song() -> Dictionary:
	# The built-in track keeps its edits (title, album, section marks) in preferences.
	var entry={"id":"eclipse","title":"Eclipse","bpm":128.0,"album":"SYNK Originals"}
	entry.merge(prefs.get_value("songs","eclipse",{}),true)
	return entry

func album_name(entry: Dictionary) -> String:
	var album=str(entry.get("album","")).strip_edges()
	if not album.is_empty(): return album
	return "SYNK Originals" if entry.get("id")=="eclipse" else "Imported music"

func save_song_config() -> void:
	if song.id=="eclipse":
		# Keep legacy timing values untouched as migration defaults for older charts.
		var edits=prefs.get_value("songs","eclipse",{}).duplicate(true)
		for key in ["title","album","artist","track"]:
			if song.has(key): edits[key]=song[key]
		prefs.set_value("songs","eclipse",edits); prefs.save("user://preferences.cfg")
	else: library.atomic_write("user://songs/library.json",library.songs)

func chart_config() -> Dictionary:
	if run_settings_active: return play_settings
	if mode in ["menu","library"]: return saved_settings
	return document.settings
func chart_bpm() -> float: return float(chart_config().get("bpm",song.get("bpm",128.0)))
func chart_offset() -> float: return float(chart_config().get("beat_offset",0.0))
func section_mark(name: String) -> float:
	return float(chart_config().get(name,-1.0))

func section_range(section: String) -> Vector2:
	var verse2=section_mark("verse2"); var bridge=section_mark("bridge")
	match section:
		"verse1": return Vector2(0,verse2)
		"verse2": return Vector2(verse2,bridge if bridge>verse2 else INF)
		"bridge": return Vector2(bridge,INF)
	return Vector2(0,INF)

func section_available(section: String) -> bool:
	match section:
		"verse1","verse2": return section_mark("verse2")>0
		"bridge": return section_mark("bridge")>0
	return true

func set_play_mode(section: String) -> void:
	play_mode=section if section_available(section) else "full"

func format_clock(seconds: float) -> String:
	return "%d:%04.1f" % [int(seconds)/60,fmod(seconds,60.0)]

func mark_section(name: String, at: float) -> void:
	# Marking again near the same spot clears the mark.
	at=clampf(at,0,length())
	if absf(section_mark(name)-at)<.25: features.set_chart_value(name,-1.0); tell(SECTION_NAMES[name]+" mark cleared for this chart.")
	else: features.set_chart_value(name,snappedf(at,.01)); tell(SECTION_NAMES[name]+" starts at "+format_clock(at)+" in this chart.")
	features.autosave()
	if not section_available(play_mode): play_mode="full"
	refresh_section_marks()

func refresh_section_marks() -> void:
	for name in ["verse2","bridge"]:
		var at=section_mark(name)
		var text="◆  "+SECTION_NAMES[name]+("  "+format_clock(at) if at>0 else "")
		for buttons in [record_mark_buttons,studio_mark_buttons]:
			if buttons.has(name): buttons[name].text=text; buttons[name].set_selected(at>0)

func start_new_recording() -> void:
	if document.dirty:
		set_mode("editor"); tell("Save or reload your edits before starting a new chart."); return
	document.load_notes([]); document.dirty=true; cursor=0; record_here()

func record_here() -> void:
	audio.stop(); audio.stream_paused=false; audio.pitch_scale=record_speed; capture.notes.clear(); capture.gestures.clear(); pointers.clear(); tool="auto"
	visual_clock_ready=false
	resume_countdown=0
	arranging=false; arrange_touches.clear(); arrange_selection.clear(); arrange_button.text="CORRECT"
	overdub=true; start_position=clampf(cursor,0,maxf(0,length()-.02)); countdown=3; song_time=start_position-3; set_mode("record")
	recorder.begin()
	apply_stage_cover()
	refresh_arrange_controls()
	refresh_section_marks()

func stop_take() -> void:
	if mode!="record" and not (mode=="paused" and paused_mode=="record"): return
	if recorder.setup: recorder.setup.queue_free(); recorder.setup=null
	if recorder.finish(): return
	audio.stop(); audio.stream_paused=false; audio.pitch_scale=1; capture.gestures.clear()
	arranging=false; arrange_touches.clear(); arrange_selection.clear(); arrange_button.text="CORRECT"
	cursor=clampf(song_time,0,length()); set_mode("editor")
	if not recorder.takes.is_empty():
		recorder.apply_take(recorder.takes[recorder.selected_take].notes)
		recorder.show_review()
	tell("Review your take: keep it, retry, compare or undo. SAVE when ready.")

func cycle_record_speed() -> void:
	record_speed=float(RECORD_SPEEDS[(RECORD_SPEEDS.find(record_speed)+1)%RECORD_SPEEDS.size()])
	if mode=="record" or (mode=="paused" and paused_mode=="record"): audio.pitch_scale=record_speed
	record_speed_button.caption_text=str(record_speed)+"× SPEED"
	record_speed_button.text=record_speed_button.caption_text
	record_speed_button.caption.text=record_speed_button.caption_text
	prefs.set_value("editor","record_speed",record_speed); prefs.save("user://preferences.cfg")

func toggle_pause() -> void:
	if finishing: return
	if mode in ["play","record"]:
		resume_countdown=0
		if mode=="record": recorder.seal_gestures()
		paused_mode=mode; pause_had_audio=audio.playing; audio.stream_paused=true; pointers.clear(); capture.gestures.clear()
		for entry in live:
			if entry.started and not entry.done: entry.pointer=-999
		set_mode("paused"); modal_title.text="PAUSED"; modal_body.text=""; primary.text="RESUME"
		if paused_mode=="record": primary.text="RESUME REC"; pause_restart.text="RETRY TAKE"; pause_home.text="REVIEW TAKE"
		if pause_tween and pause_tween.is_running(): pause_tween.kill()
		modal.pivot_offset=modal.size*.5; modal.scale=Vector2(.86,.86); modal.modulate.a=0
		pause_backdrop.modulate.a=0
		pause_tween=create_tween().set_parallel(true)
		pause_tween.tween_property(modal,"scale",Vector2.ONE,.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pause_tween.tween_property(modal,"modulate:a",1.0,.18)
		pause_tween.tween_property(pause_backdrop,"modulate:a",1.0,.22)
	elif mode=="paused":
		if pause_tween and pause_tween.is_running(): pause_tween.kill()
		if paused_mode=="record" and arranging:
			set_mode("record"); modal.scale=Vector2.ONE; modal.modulate.a=1; return
		resume_start_audio=not pause_had_audio
		countdown=0; resume_countdown=3.0; judgement=""; flash=0
		set_mode(paused_mode)
		modal.scale=Vector2.ONE; modal.modulate.a=1

func toggle_arrange() -> void:
	if mode!="record": return
	arranging=not arranging; arrange_touches.clear(); arrange_selection.clear(); capture.gestures.clear()
	arrange_button.text="RECORD" if arranging else "CORRECT"
	refresh_arrange_controls()
	if arranging:
		countdown=0; audio.stream_paused=true
	else:
		var playback_time=clampf(song_time-effective_timing_ms()/1000.0,0,maxf(0,length()-.02))
		if audio.playing: audio.seek(playback_time); audio.stream_paused=false
		else: audio.play(playback_time)

func refresh_arrange_controls() -> void:
	kind_buttons[0].text="DELETE" if arranging else "AUTO"
	var kinds=["auto","tap","hold","slide","flick"]
	for i in kind_buttons.size(): kind_buttons[i].set_selected(not arranging and kinds[i]==tool)
	for kind_button in kind_buttons: kind_button.disabled=arranging and arrange_selection.is_empty()
	if not arranging and recorder.current_pass()!="all": kind_buttons[0].disabled=true
	for i in range(1,kind_buttons.size()):
		if kinds[i] in recorder.locks() or (recorder.current_pass()!="all" and kinds[i]!=recorder.current_pass()): kind_buttons[i].disabled=true
	dots_button.visible=arranging
	ghost_button.visible=not arranging; ghost_button.set_selected(ghost_recording)
	if record_sidebar: record_sidebar.anchor_bottom=.715
	dots_button.text="●  ADD POINTS: ON" if dots_mode else "●  ADD POINTS: OFF"
	dots_button.set_selected(dots_mode)
	if arranging and dots_mode:
		var dots_note: Dictionary=arrange_selection.get("note",{})
		if dots_note.is_empty() or dots_note.kind not in ["hold","slide"]: record_help.text="ADD POINTS: select a hold or slide, then tap along its trail to add points.\nDuring play the finger must be over the trail when each point reaches the bar."
		else: record_help.text="ADD POINTS: tap the trail to add a point, tap a point to remove it (%d on this note).\nSwipe up or down anywhere to scroll along the note; it stays selected." % dots_note.get("checkpoints",[]).size()
	elif arranging:
		if arrange_selection.is_empty(): record_help.text="Tap a note head or any part of its trail to select and drag it.\nType buttons change the note. Scroll beside the highway."
		else:
			var n: Dictionary=arrange_selection.note
			record_help.text="SELECTED  %s  •  LANE %d  •  %.2f s\nDrag to move. Use the type buttons or DELETE above; scroll outside the highway." % [str(n.kind).to_upper(),int(n.lane)+1,float(n.time)]
	else:
		var hints={"auto":"AUTO · Tap, hold, or drag to record. Choose FLICK for swipes.","tap":"TAP · Touch any lane at the glowing line to place a tap.","hold":"HOLD · Press and keep your finger down; release to end.","slide":"SLIDE · Hold and move across lanes to draw the trail.","flick":"FLICK · Swipe in the direction you want the player to flick."}
		record_help.text=str(hints.get(tool,hints.auto))+"\nCORRECT pauses for edits. STOP & REVIEW finishes the take."

func toggle_ghost_recording() -> void:
	ghost_recording=not ghost_recording
	ghost_button.text="GHOST ON" if ghost_recording else "GHOST OFF"
	prefs.set_value("editor","ghost_recording",ghost_recording); prefs.save("user://preferences.cfg")
	refresh_arrange_controls()

func undo_record_note() -> void:
	if not capture.notes.is_empty(): capture.notes.pop_back()
	arrange_selection.clear()
	refresh_arrange_controls()

func delete_arrange_note() -> void:
	if not arranging or arrange_selection.is_empty(): return
	if arrange_selection.note.kind in recorder.locks(): return
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
	if n.kind in recorder.locks() or kind in recorder.locks() or (recorder.current_pass()!="all" and kind!=recorder.current_pass()): return
	if n.kind==kind: return
	if arrange_selection.document:
		document.selected=int(arrange_selection.index)
		document.convert(kind,60.0/float(chart_bpm()),length())
	else:
		n.kind=kind
		if kind in ["tap","flick"]:
			n.duration=0.0; n.path=[]; n.end_lane=n.lane; n.erase("checkpoints")
		else:
			n.duration=maxf(.04,float(n.duration) if float(n.duration)>0 else 60.0/float(chart_bpm()))
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
	var far_right=field.project(SynkChart.MAX_LANE+.5,1)
	var near_right=field.project(SynkChart.MAX_LANE+.5,0)
	if point.y<far_left.y: return true
	var depth=clampf((point.y-far_left.y)/maxf(1,near_left.y-far_left.y),0,1)
	var left_edge=lerpf(far_left.x,near_left.x,depth)
	var right_edge=lerpf(far_right.x,near_right.x,depth)
	return point.x<left_edge-12 or point.x>right_edge+12

func toggle_dots_mode() -> void:
	dots_mode=not dots_mode
	refresh_arrange_controls()

func toggle_checkpoint(n: Dictionary, at: float, in_document: bool) -> bool:
	# Adds a dot at this time on the trail, or removes the dot already there.
	var offset=at-float(n.time)
	if n.kind not in ["hold","slide"] or offset<=.02 or offset>=float(n.duration)-.02: return false
	if in_document: document.checkpoint()
	var checks: Array=n.get("checkpoints",[]).duplicate()
	for i in checks.size():
		if absf(float(checks[i])-offset)<.08:
			checks.remove_at(i)
			if checks.is_empty(): n.erase("checkpoints")
			else: n.checkpoints=checks
			return true
	checks.append(snappedf(offset,.001)); checks.sort()
	n.checkpoints=checks
	return true

func add_point_at(p: Vector2) -> void:
	var selected_note: Dictionary=arrange_selection.note
	var lane=SynkCapture.lane(field.input_position(p).x)
	var at=stage_time_at(p)
	if absf(lane-SynkChart.lane_at(selected_note,at))<=2.0 and toggle_checkpoint(selected_note,at,bool(arrange_selection.document)):
		if arrange_selection.document: document.dirty=true
	refresh_arrange_controls()

func arrange_lane_at(p: Vector2) -> float:
	var world=field.world; var point=p*Vector2(field.viewport.size)
	var hit=Plane(Vector3.UP,world.trail_height()).intersects_ray(world.camera.project_ray_origin(point),world.camera.project_ray_normal(point))
	return hit.x/world.LANE_WIDTH+world.CENTER_LANE if hit!=null else world.CENTER_LANE

func arrange_note_distance(n: Dictionary,p: Vector2) -> float:
	var start=float(n.time); var finish=start+float(n.duration)
	if start>song_time or song_time-finish>note_travel_seconds(): return INF
	var world=field.world; var camera=world.camera; var viewport_size=Vector2(field.viewport.size)
	var origin=Vector3(0,0,(start-song_time)*world.travel_speed())
	var best=INF
	if song_time-start<=note_travel_seconds():
		var head=Vector3(world.lane_x(float(n.lane)),.2,origin.z)
		if not camera.is_position_behind(head): best=p.distance_to(camera.unproject_position(head)/viewport_size)
	if n.kind not in ["hold","slide"] or float(n.duration)<=0: return best
	# Use the renderer's sampled ribbon, including bends and the configured width.
	var centers=world.trail_centers(n,clampi(ceili(float(n.duration)*32),16,256),true)
	var sides=world.trail_sides(centers)
	var half_width=world.TRAIL_HALF*.65*hold_trail_width
	var pointer=p*viewport_size
	for i in centers.size()-1:
		var a: Vector3=centers[i]+origin; var b: Vector3=centers[i+1]+origin
		if maxf(a.z,b.z)<-world.TRACK_LENGTH or minf(a.z,b.z)>world.JUDGMENT_DEPTH: continue
		if camera.is_position_behind(a) or camera.is_position_behind(b): continue
		var screen_a=camera.unproject_position(a); var screen_b=camera.unproject_position(b)
		var polygon=PackedVector2Array([camera.unproject_position(a-sides[i]*half_width),camera.unproject_position(b-sides[i+1]*half_width),camera.unproject_position(b+sides[i+1]*half_width),camera.unproject_position(a+sides[i]*half_width)])
		var distance=pointer.distance_to(Geometry2D.get_closest_point_to_segment(pointer,screen_a,screen_b))
		var inside=Geometry2D.is_point_in_polygon(pointer,polygon)
		var edge_distance=INF
		for edge in 4: edge_distance=minf(edge_distance,pointer.distance_to(Geometry2D.get_closest_point_to_segment(pointer,polygon[edge],polygon[(edge+1)%4])))
		if inside or edge_distance<=12: best=minf(best,minf(.085,distance/viewport_size.length()))
	if trail_style=="solid":
		var hit=Plane(Vector3.UP,world.trail_height()+.015).intersects_ray(camera.project_ray_origin(pointer),camera.project_ray_normal(pointer))
		if hit!=null:
			for offset in world.solid_trail_offsets(n):
				var center=Vector3(world.lane_x(SynkChart.lane_at(n,start+offset)),world.trail_height()+.015,(start+offset-song_time)*world.travel_speed())
				if camera.is_position_behind(center) or center.z < -world.TRACK_LENGTH or center.z>world.JUDGMENT_DEPTH: continue
				if Vector2(hit.x-center.x,hit.z-center.z).length()<=half_width*1.5:
					best=minf(best,minf(.085,p.distance_to(camera.unproject_position(center)/viewport_size)))
	return best

func arrange_pointer_event(id: int,p: Vector2,began: bool,ended: bool,canceled: bool) -> void:
	# Adding points: with a hold or slide selected, a tap on its trail adds or removes a point
	# and a swipe anywhere on the stage scrolls along the note, keeping it selected.
	var points_note: Dictionary=arrange_selection.get("note",{})
	if began and dots_mode and not points_note.is_empty() and points_note.kind in ["hold","slide"]:
		arrange_touches[id]={"kind":"points","start_p":p,"start_y":p.y,"start_time":song_time,"moved":false}
		return
	if arrange_touches.has(id) and arrange_touches[id].kind=="points":
		var points_touch: Dictionary=arrange_touches[id]
		if not points_touch.moved and p.distance_to(points_touch.start_p)>.03: points_touch.moved=true
		if points_touch.moved:
			song_time=clampf(float(points_touch.start_time)+(float(points_touch.start_y)-p.y)*note_travel_seconds()*1.3,0,length())
		if ended and not canceled and not points_touch.moved and not outside_highway(p): add_point_at(p)
		if ended or canceled: arrange_touches.erase(id)
		return
	if began:
		if outside_highway(p):
			# Scrolling from beside the highway keeps the current selection.
			arrange_touches[id]={"kind":"scroll","start_y":p.y,"start_time":song_time}
			return
		var selected: Dictionary={}
		var closest=.09
		var sources=[capture.notes,document.notes]
		for source_index in sources.size():
			var source: Array=sources[source_index]
			for note_index in source.size():
				var n: Dictionary=source[note_index]
				if n.kind in recorder.locks(): continue
				var distance=arrange_note_distance(n,p)
				if distance<closest: closest=distance; selected={"note":n,"document":source_index==1,"index":note_index}
		arrange_selection=selected
		refresh_arrange_controls()
		if selected.is_empty(): arrange_touches[id]={"kind":"empty"}
		else:
			arrange_touches[id]={"kind":"note","note":selected.note,"document":selected.document,"changed":false,"start_time":float(selected.note.time),"start_lane":int(selected.note.lane),"touch_time":stage_time_at(p),"touch_lane":arrange_lane_at(p)}
	if canceled or ended:
		arrange_touches.erase(id); return
	if not arrange_touches.has(id): return
	var touch: Dictionary=arrange_touches[id]
	if touch.kind=="scroll":
		song_time=clampf(float(touch.start_time)+(float(touch.start_y)-p.y)*note_travel_seconds()*1.3,0,length())
	elif touch.kind=="note":
		var n: Dictionary=touch.note
		var target_time=stage_time_at(p)-float(touch.touch_time)+float(touch.start_time)
		var lane_delta=clampi(roundi(arrange_lane_at(p)-float(touch.touch_lane)),-SynkChart.MAX_LANE,SynkChart.MAX_LANE)
		var new_lane=clampi(int(touch.start_lane)+lane_delta,0,SynkChart.MAX_LANE)
		if not touch.changed and (absf(float(n.time)-target_time)>.001 or int(n.lane)!=new_lane):
			if touch.document: document.checkpoint()
			touch.changed=true
		n.time=clampf(target_time,0,minf(song_time,maxf(0,length()-float(n.duration))))
		var change=new_lane-int(n.lane)
		n.lane=new_lane; n.end_lane=clampi(int(n.end_lane)+change,0,SynkChart.MAX_LANE)
		for point in n.path: point.lane=clampf(float(point.lane)+change,0,SynkChart.MAX_LANE)
		if touch.changed: refresh_arrange_controls()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		if features and mode=="editor": features.autosave()
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
	if finishing: advance_finish(delta)
	elif mode in ["play","record"] and not arranging:
		if mode=="play" and (stage_intro.running() or field.world.prebuilding):
			# Hold the countdown until the stage has entered and every note is built.
			visual_song_time=song_time; visual_clock_ready=false
		elif resume_countdown>0:
			resume_countdown=maxf(0,resume_countdown-delta)
			if resume_countdown==0:
				if resume_start_audio: audio.play(start_position)
				UiSound.play(self,"go")
				audio.stream_paused=false; resume_grace=.35
		elif countdown>0:
			countdown=maxf(0,countdown-delta); song_time=start_position-countdown
			visual_song_time=song_time; visual_clock_ready=false
			judgement="READY "+str(ceili(countdown)); flash=1
			if countdown==0:
				audio.stream_paused=false; audio.play(start_position); UiSound.play(self,"go")
				if extras and mode=="play": extras.on_song_start()
		else:
			song_time=maxf(song_time,chart_time())
			smooth_visual_time(song_time,delta)
			update_section_volume()
			if mode=="play":
				if auto_play: update_autoplay()
				else: update_game()
				if song_time>=play_finish_time: audio.stop(); _audio_finished()
	elif mode in ["play","record"] and resume_countdown>0:
		resume_countdown=maxf(0,resume_countdown-delta)
		if resume_countdown==0: resume_grace=.35
	var intro_running=mode in ["play","paused"] and stage_intro.running()
	var counting=mode in ["play","record"] and (countdown>0 or resume_countdown>0)
	practice_hud.visible=practice.active and mode in ["play","paused"]
	practice_hud.text="PRACTICE · %s× · %s%d" % [str(practice.speed),"LOOP " if practice.repeat_enabled else "TAKE ",practice.round_number]
	timing_label.visible=mode=="play" and not auto_play and not counting and flash>0 and not finishing
	timing_label.modulate.a=clampf(flash,0,1)
	if mode=="paused":
		pause_home.text="REVIEW TAKE" if paused_mode=="record" else ("EDITOR" if practice.active else "HOME")
		pause_restart.text="RETRY TAKE" if paused_mode=="record" else "RESTART"
		primary.text="RESUME REC" if paused_mode=="record" else "RESUME"
	var active_hold=mode=="play" and not counting and has_active_hold()
	hold_pulse_time=hold_pulse_time+delta if active_hold else 0.0
	var hold_pulse=(0.5+0.5*sin(hold_pulse_time*TAU*2.0))*.55 if active_hold else 0.0
	var displayed_pulse=maxf(combo_pulse,hold_pulse)
	align_gameplay_hud()
	combo_hud.pivot_offset=combo_hud.size*.5
	combo_hud.scale=Vector2.ONE*(1.0+displayed_pulse*.28)
	combo_hud.modulate=Color.WHITE.lerp(Color("fff0ff"),displayed_pulse)
	combo_glow.set_shader_parameter("boost",displayed_pulse)
	countdown_label.visible=counting and not intro_running
	countdown_ring.visible=countdown_label.visible
	if countdown_label.visible:
		var number=ceili(resume_countdown if resume_countdown>0 else countdown)
		if number!=countdown_shown and number>0: countdown_shown=number; UiSound.play(self,"count")
		countdown_label.add_theme_color_override("font_color",SynkGameplayColors.resolve(self,"countdown",countdown_color(number).lightened(.45)))
		countdown_ring.queue_redraw()
	else: countdown_shown=-1
	# The HUD fades in as the loading card clears the stationary highway.
	var hud_alpha=stage_intro.entrance() if intro_running else 1.0
	for hud_item in [song_hud,difficulty_hud,auto_play_hud]: hud_item.self_modulate.a=hud_alpha
	if finishing: hud_alpha*=1.0-clampf(finish_elapsed/.35,0,1)
	score_panel.modulate.a=hud_alpha; hud_shadow.modulate.a=hud_alpha
	if mode in ["play","paused"]:
		var section_end=minf(play_range.y,length())
		score_panel.progress=clampf((song_time-play_range.x)/maxf(.01,section_end-play_range.x),0.0,1.0)
	if intro_running: pause_button.visible=false
	elif mode in ["play","record","paused"]: pause_button.visible=true
	if counting:
		var remaining=resume_countdown if resume_countdown>0 else countdown
		countdown_label.text=str(ceili(remaining))
		countdown_label.pivot_offset=countdown_label.size*.5
		countdown_label.scale=Vector2.ONE*(1.0+fmod(remaining,1.0)*.2)
	combo_hud.visible=mode in ["play","paused"] and not counting and combo>0 and not finishing
	hit_label.visible=mode in ["play","record"] and not counting
	if mode=="editor" and audio.playing:
		cursor=clampf(chart_time(),0,length())
		if not recorder.reviewing_audio and loop_enabled and loop_b>loop_a+.1 and cursor>=loop_b: audio.play(loop_a); cursor=loop_a
		refresh_editor()
	if mode=="play":
		displayed_score=lerpf(displayed_score,float(score),clampf(delta*11.0,0,1))
		if absf(displayed_score-score)<1.0: displayed_score=score
	hud.text=format_score(roundi(displayed_score))
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
	record_info.text=("PAUSED · CORRECT %.1f s\n%d NOTES" if arranging else "● RECORDING  %.1f s\n%d NOTES / %s") % ([maxf(0,song_time),capture.notes.size()] if arranging else [maxf(0,song_time),capture.notes.size(),tool.to_upper()])
	if mode=="record" and recorder.active:
		if song_time<recorder.region.x and countdown==0: record_info.text="PRE-ROLL · LISTEN\nREC AT %.2f s" % recorder.region.x
		elif recorder.looping(): record_info.text+=" · TAKE %d" % (recorder.takes.size()+1)
	var show_hit_art=false
	hit_art.visible=show_hit_art
	if show_hit_art:
		if hit_art.texture!=JUDGEMENT_ART[judgement]:
			hit_art.texture=JUDGEMENT_ART[judgement]
			hit_glow.set_shader_parameter("reach_scale",glow_reach(hit_art.texture))
		hit_glow.set_shader_parameter("boost",0.0 if active_hold else flash)
		hit_art.modulate.a=.6 if judgement=="MISS" else .85
		hit_art.pivot_offset=hit_art.size*.5
		hit_art.scale=Vector2.ONE*(1.0+(0.0 if active_hold else flash*.04))
	# The finish and the results never show the last judgment.
	var play_judgement=mode=="play" and not finishing and JUDGEMENT_ART.has(judgement)
	hit_label.visible=(mode=="record" or play_judgement) and not counting
	hit_label.text=judgement
	if play_judgement:
		# The last judgment stays readable; each hit gives it a small pop.
		hit_label.modulate.a=.6 if judgement=="MISS" else .92
		hit_label.pivot_offset=hit_label.size*.5
		hit_label.scale=Vector2.ONE*(1.0+(0.0 if active_hold else flash*.06))
	else:
		hit_label.modulate.a=flash; hit_label.scale=Vector2.ONE

func has_active_hold() -> bool:
	for live_index in range(first_live_index(),live.size()):
		var entry: Dictionary=live[live_index]
		if float(entry.note.time)>song_time+.23: break
		if entry.done or not entry.started or entry.note.kind!="hold": continue
		if auto_play or pointers.has(entry.pointer): return true
	return false

func align_gameplay_hud() -> void:
	var screen_center=field.get_global_transform_with_canvas()*field.project(field.world.CENTER_LANE,0)
	var center_x=(ui.get_global_transform_with_canvas().affine_inverse()*screen_center).x
	for element in [combo_hud,hit_art,hit_label]:
		element.position.x=center_x-element.size.x*.5
	var highway_center=field.get_global_transform_with_canvas()*((field.project(field.world.CENTER_LANE,0)+field.project(field.world.CENTER_LANE,1))*.5)
	var countdown_center=ui.get_global_transform_with_canvas().affine_inverse()*highway_center
	for element in [countdown_label,countdown_ring]:
		element.position=countdown_center-element.size*.5

func update_combo_art() -> void:
	combo_art_value=combo; combo_art_size=combo_hud.size
	var digits=str(combo)
	for child in combo_hud.get_children(): child.hide()
	var digit_height=minf(combo_hud.size.y*.96,combo_hud.size.x/maxf(1,digits.length())*.82)
	var digit_width=digit_height*(float(COMBO_ATLAS.get_width())/3.0)/(float(COMBO_ATLAS.get_height())/3.0)
	var spacing=digit_width*.84
	var total_width=digit_width+spacing*(digits.length()-1)
	var left=(combo_hud.size.x-total_width)*.5
	for i in digits.length():
		if i>=combo_hud.get_child_count(): combo_hud.add_child(TextureRect.new())
		var digit=combo_hud.get_child(i)
		digit.show()
		digit.texture=combo_digit_textures[int(digits[i])]
		digit.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		digit.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		digit.mouse_filter=Control.MOUSE_FILTER_IGNORE
		digit.material=combo_glow
		# The glow shader draws the digit inside a padded quad, so grow the rect to keep the digit's size.
		var content=Vector2(digit_width,digit_height)
		var padded=content/(1.0-2.0*HUD_GLOW_PAD)
		digit.position=Vector2(left+i*spacing,(combo_hud.size.y-digit_height)*.5)-(padded-content)*.5
		digit.size=padded

func build_combo_digit_textures() -> void:
	combo_digit_textures.clear()
	var cell_width=float(COMBO_ATLAS.get_width())/3.0
	var cell_height=float(COMBO_ATLAS.get_height())/3.0
	combo_digit_textures.append(COMBO_ZERO)
	# Digits are cut into standalone textures so the glow shader samples only one digit's pixels.
	var atlas_image=COMBO_ATLAS.get_image()
	for value in range(1,10):
		var cell=value-1
		var region=Rect2i(Vector2i(int(cell%3*cell_width),int(floori(float(cell)/3.0)*cell_height)),Vector2i(int(cell_width),int(cell_height)))
		combo_digit_textures.append(ImageTexture.create_from_image(atlas_image.get_region(region)))
	combo_glow=glow_material(Color("b46bff"))
	combo_glow.set_shader_parameter("reach_scale",glow_reach(COMBO_ZERO))

func glow_material(color: Color) -> ShaderMaterial:
	var material=ShaderMaterial.new(); material.shader=HUD_GLOW_SHADER
	material.set_shader_parameter("glow_color",color)
	material.set_shader_parameter("pad",HUD_GLOW_PAD)
	return material

func glow_reach(texture: Texture2D) -> Vector2:
	# Equal glow width on every side, measured in the art's shorter dimension.
	var shortest=float(mini(texture.get_width(),texture.get_height()))
	return Vector2(shortest/texture.get_width(),shortest/texture.get_height())

func _unhandled_input(event: InputEvent) -> void:
	if floating_text_input and floating_text_input.handle_input(event): return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==-1: return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		if recorder.setup:
			recorder.setup.queue_free(); recorder.setup=null; return
		if recorder.review: recorder.keep(); return
		if mode=="menu" and sync_helper.visible: sync_helper.close()
		elif mode=="menu" and menu_settings_open: close_lobby_settings()
		elif mode=="guide": set_mode("menu")
		elif mode=="library" and song_details.visible: close_song_details()
		elif mode=="library": set_mode("menu")
		elif mode=="editor": close_editor()
		else: toggle_pause()
	if mode not in ["play","record"] or finishing or countdown>0 or resume_countdown>0 or (mode=="play" and auto_play): return
	if event is InputEventScreenTouch: pointer_event(event.index,event.position/size,event.pressed,not event.pressed,event.canceled)
	elif event is InputEventScreenDrag: pointer_event(event.index,event.position/size,false,false,false)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT: pointer_event(-1,event.position/size,event.pressed,not event.pressed,false)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): pointer_event(-1,event.position/size,false,false,false)

func pointer_event(id: int,p: Vector2,began: bool,ended: bool,canceled: bool,from_replay: bool=false) -> void:
	if mode=="play" and auto_play: return
	# During a replay, real touches are ignored; the recorded ones arrive with from_replay.
	if mode=="play" and extras and extras.replaying and not from_replay: return
	if extras and not from_replay: extras.record_input(id,p,began,ended,canceled)
	if mode=="record" and arranging:
		arrange_pointer_event(id,p,began,ended,canceled); return
	var touch_world=field.touch_world_position(p)
	p = field.input_position(p)
	if mode=="record":
		if not recorder.can_capture(song_time): return
		if began:
			capture.minimum_lane_gap=authoring_lane_gap()
			capture.onset_bounds=recorder.region
			capture.begin(id,song_time,p,recorder.capture_tool(),recorder.spacing_blockers())
		capture.move(id,song_time,p)
		if ended:
			var n=capture.end(id,song_time,p,canceled)
			if not n.is_empty() and not recorder.writable(n): capture.notes.erase(n); return
			if not n.is_empty():
				judgement=n.kind.to_upper()+" RECORDED"; flash=1; flash_lane=int(n.end_lane)
				if not capture.last_spacing_resolved: tell("This chord is too crowded to separate. Move a note or reduce its size.")
		return
	if began:
		pointers[id]={"start":p,"position":p,"world":touch_world}
		if p.y>=.6 and p.y<=.92:
			var nearest: Dictionary={}; var best=.231
			for live_index in range(first_live_index(),live.size()):
				var entry: Dictionary=live[live_index]
				if float(entry.note.time)>song_time+.23: break
				if entry.done: continue
				var n: Dictionary=entry.note
				if entry.started:
					if entry.pointer==-999 and absf(SynkCapture.lane(p.x)-SynkChart.lane_at(n,song_time))<.85: entry.pointer=id
					continue
				var error=absf(song_time-float(n.time))
				var timing_limit=.23*extras.scale() if n.kind=="slide" else extras.good_window()
				var lane_limit=1.8 if n.kind=="slide" else .85
				if error<=minf(best,timing_limit) and absf(SynkCapture.lane(p.x)-float(n.lane))<lane_limit: best=error; nearest=entry
			if nearest.is_empty() and bool(extras.settings.touch_assist):
				# Touch assist: accept a touch up to 1.6 lanes away when no note sits closer.
				for live_index in range(first_live_index(),live.size()):
					var entry: Dictionary=live[live_index]
					if float(entry.note.time)>song_time+.23: break
					if entry.done or entry.started: continue
					var n: Dictionary=entry.note
					var error=absf(song_time-float(n.time))
					if error<=minf(best,extras.good_window()) and absf(SynkCapture.lane(p.x)-float(n.lane))<1.6: best=error; nearest=entry
			if not nearest.is_empty():
				nearest.started=true; nearest.pointer=id; nearest.error=best; nearest.timing_error=song_time-float(nearest.note.time)
				if nearest.note.kind=="tap": judge(nearest,best)
				elif nearest.note.kind=="hold": judge(nearest,best,false)
				elif nearest.note.kind=="slide": field.world.spawn_hit(SynkChart.lane_at(nearest.note,song_time),"slide",0,nearest,id)
	if pointers.has(id):
		pointers[id].position=p; pointers[id].world=touch_world
	if ended:
		# Process final swipe motion before removing the finger.
		update_game()
		for live_index in range(first_live_index(),live.size()):
			var entry: Dictionary=live[live_index]
			if entry.done or entry.pointer!=id or entry.note.kind!="hold": continue
			var hold_end=float(entry.note.time)+float(entry.note.duration)
			judge(entry,absf(song_time-hold_end) if not canceled and absf(song_time-hold_end)<=extras.good_window() else -1)
		for live_index in range(first_live_index(),live.size()):
			var entry: Dictionary=live[live_index]
			if entry.done or entry.pointer!=id or entry.note.kind!="slide": continue
			var end_time=float(entry.note.time)+float(entry.note.duration)
			var lane_error=absf(SynkCapture.lane(p.x)-SynkChart.lane_at(entry.note,end_time))
			if not canceled and lane_error<=2.75 and p.y>=.5 and song_time>=end_time-.20 and song_time<=end_time+.20:
				judge(entry,float(entry.error))
		pointers.erase(id)
		if canceled:
			for live_index in range(first_live_index(),live.size()):
				var entry: Dictionary=live[live_index]
				if entry.pointer==id and not entry.done: judge(entry,-1)

func update_autoplay() -> void:
	for live_index in range(first_live_index(),live.size()):
		var entry: Dictionary=live[live_index]
		if float(entry.note.time)>song_time: break
		if entry.done: continue
		var n: Dictionary=entry.note
		if not entry.started and song_time>=float(n.time):
			entry.started=true
			if n.kind=="hold": judge(entry,0.0,false)
			elif n.kind=="slide": field.world.spawn_hit(SynkChart.lane_at(n,song_time),"slide",0,entry)
			elif n.kind in ["tap","flick"]: judge(entry,0.0)
		if entry.started and not entry.done: process_checkpoints(entry,0.0,true)
		if entry.started and not entry.done and song_time>=float(n.time)+float(n.duration):
			judge(entry,0.0)

func update_game() -> void:
	for live_index in range(first_live_index(),live.size()):
		var entry: Dictionary=live[live_index]
		if float(entry.note.time)>song_time+.23: break
		if entry.done: continue
		var n: Dictionary=entry.note
		if not entry.started:
			if song_time>float(n.time)+(.23*extras.scale() if n.kind=="slide" else extras.good_window()):
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
			elif song_time>float(n.time)+extras.good_window(): judge(entry,-1)
		elif n.kind in ["hold","slide"] and not process_checkpoints(entry,SynkCapture.lane(p.position.x),false):
			continue
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
	var at=float(entry.note.time)
	if entry.note.kind=="hold" and entry.get("note_hit",false): at=minf(song_time,float(entry.note.time)+float(entry.note.duration))
	performance_samples.append({"time":at,"weight":0.0 if error<0 else (1.0 if error<=extras.perfect_window() else (.8 if error<=extras.great_window() else .5)),"amount":1})
	if error>=0: entry.note_hit=true
	if error<0: timing_label.text=""
	if error>=0 and not auto_play and not entry.get("timing_logged",false):
		entry.timing_logged=true
		var ms=float(entry.get("timing_error",song_time-float(entry.note.time)))*1000
		timing_samples.append({"time":float(entry.note.time),"ms":ms})
		timing_label.text="ON TIME" if absf(ms)<=10 else ("EARLY %d ms" if ms<0 else "LATE %d ms") % roundi(absf(ms))
		timing_label.add_theme_color_override("font_color",Color("65dcff") if ms<0 else Color("ff82d2"))
	if error>=0: field.world.spawn_hit(SynkChart.lane_at(entry.note,song_time),str(entry.note.kind),int(entry.note.direction),entry if entry.note.kind=="hold" and not complete else {},int(entry.get("pointer",-999)))
	else: field.world.shake_on_miss()
	if error<0 and entry.note.kind in ["slide","hold"]:
		entry.missed_at=song_time
		entry.missed_visual_time=field.world.render_time()
	judgement_kind = str(entry.note.kind)
	entry.done=complete; judged+=1; flash=1; flash_lane=roundi(SynkChart.lane_at(entry.note,song_time))
	# Energy is a performance gauge only: hits refill it, misses drain it, the song never fails.
	if error<0: judgement="MISS"; combo=0; combo_pulse=0; forfeit_checkpoints(entry); score_panel.energy=maxf(0,score_panel.energy-.08)
	else:
		combo+=1; combo_pulse=1.0; max_combo=maxi(combo,max_combo)
		score_panel.energy=minf(1,score_panel.energy+(.02 if error<=extras.perfect_window() else (.012 if error<=extras.great_window() else .004)))
		if error<=extras.perfect_window(): judgement="PERFECT"; earned+=1
		elif error<=extras.great_window(): judgement="GREAT"; earned+=.8
		else: judgement="GOOD"; earned+=.5
	judgment_counts[judgement]+=1
	score=roundi(1000000*earned/maxi(1,total_judgements()))
	if extras: extras.on_judged(entry,judgement,combo)

func _audio_finished() -> void:
	if mode=="record": stop_take()
	elif mode=="play":
		if practice.finish_round(): return
		for entry in live:
			if not entry.done:
				judge(entry,-1)
				if entry.note.kind=="hold" and not entry.started: judged+=1
		var chart_key=(str(song.id)+JSON.stringify(live.map(func(e):return e.note))).sha256_text()
		var previous_best=int(prefs.get_value("scores",chart_key,0))
		var best=previous_best
		if not auto_play and not practice.active:
			best=maxi(score,best); prefs.set_value("scores",chart_key,best); prefs.save("user://preferences.cfg")
			if score>=previous_best:
				prefs.set_value("score_ranks",chart_key,rank_name()); prefs.save("user://preferences.cfg")
		var stats: Dictionary={}
		if extras:
			if not auto_play and not practice.active and not extras.replaying: stats=extras.record_result(chart_key,judgment_counts,live.size())
			else: stats=extras.stats_for(chart_key)
			extras.finish_run()
		var tinted=song.id!="eclipse" and not has_custom_cover(str(song.id))
		begin_finish({"stats":stats,"replay":extras and extras.has_replay() and not auto_play,"mods":extras.mods_text() if extras else "","cover":cover_texture_for_id(str(song.id)),"tint":cover_tint_for_id(str(song.id)) if tinted else Color.WHITE,
			"title":str(song.title),"details":intro_details(),"rank":rank_name(),"score":score,"accuracy":accuracy(),"max_combo":max_combo,
			"counts":judgment_counts.duplicate(),"best":best,"previous_best":previous_best,"new_best":not auto_play and not practice.active and score>previous_best,"auto_play":auto_play,"practice":practice.active,"timing":timing_samples.duplicate(true),
			"song_id":str(song.id),"artist":str(song.artist) if str(song.get("artist","")).strip_edges()!="" else album_name(song),"difficulty":features.current_variant.capitalize(),"bpm":chart_bpm(),"notes_total":live.size(),"notes_hit":live.filter(func(e): return bool(e.get("note_hit",false))).size(),
			"performance":performance_samples.duplicate(true),"range_start":play_range.x,"range_end":minf(length(),play_range.y)})
	elif mode=="editor":
		if recorder.reviewing_audio: recorder.stop_preview(); refresh_transport()
		elif loop_enabled and loop_b>loop_a+.1: audio.play(loop_a); cursor=loop_a
		else: cursor=length(); refresh_transport()

# The finish: gameplay stops, the HUD fades, the camera pulls back and the finish overlay
# carries the combo counter to the middle; the results screen then takes over beneath it.
func begin_finish(results: Dictionary) -> void:
	if finishing: return
	pending_results=results
	finishing=true; finish_elapsed=0.0
	audio.stop(); pointers.clear()
	field.world.clear_notes(); field.world.clear_hit_effects()
	var from_global=combo_hud.get_global_rect()
	var to_local=finish_overlay.get_global_transform().affine_inverse()
	var from_rect=Rect2(to_local*from_global.position,from_global.size)
	finish_overlay.begin(from_rect,combo,max_combo,finish_overlay.banner_for(judgment_counts,auto_play),field.world.colors)

func advance_finish(delta: float) -> void:
	finish_elapsed+=delta
	# The highway simply fades away behind the combo.
	var fade=clampf(finish_elapsed/.7,0,1)
	field.modulate.a=1.0-fade*fade*(3.0-2.0*fade)
	if finish_elapsed>=finish_overlay.RESULTS_AT and mode=="play": show_pending_results()

func show_pending_results() -> void:
	set_mode("results")
	results_screen.show_results(pending_results)
	# The new results card owns its typography after the finish transition.
	finish_overlay.stop()


func build_studio() -> void:
	studio=Panel.new(); studio.set_script(load("res://scripts/chart_editor.gd")); studio.game=self
	rect(studio,ui,0,0,1,1)
	picker=FileDialog.new(); add_child(picker); picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE; picker.access=FileDialog.ACCESS_FILESYSTEM; picker.use_native_dialog=true
	picker.filters=PackedStringArray(["*.mp3,*.wav,*.ogg;Audio;audio/mpeg,audio/wav,audio/ogg"]); picker.file_selected.connect(import_audio)
	refresh_library()

func open_editor() -> void:
	stop_audition()
	if not document.dirty and document.notes.is_empty(): document.load_notes(baseline_notes())
	set_mode("library")
	chart_library.set_message("Choose a chart to edit, or import audio to start a new one.")

func delete_chart(id: String) -> void:
	library.delete_chart(id)
	if song_metadata.has(id):
		song_metadata[id].has_chart=false; song_metadata[id].notes=[]; song_metadata[id].note_count=0
	if str(song.id)==id and features.current_variant=="original":
		features.load_variant()
	tell("Chart deleted.")
	chart_library.refresh(); lobby.refresh()

func delete_song(id: String) -> void:
	if id=="eclipse": return
	if str(song.id)==id:
		# Leave the deleted song first; unsaved edits to it go with it.
		document.dirty=false; select_song(0)
	if library.delete_song(id)!=OK: tell("Could not delete this song."); return
	song_metadata.erase(id); song_cover_textures.erase(id)
	tell("Song deleted.")
	chart_library.refresh(); lobby.refresh()

func open_chart(index: int) -> void:
	if select_song(index,true):
		set_mode("editor")
		tell("Tap notes to select. Drag to move. SAVE keeps your chart.")
	elif loading_song_index==index: chart_library.set_message("Loading audio and chart information…")

func close_editor() -> void:
	stop_audition()
	if document.dirty:
		if features.autosave()!=OK: tell("Could not store the draft. SAVE before leaving."); return
		document.dirty=false
	set_mode("library")

func tell(message: String,kind: String="auto") -> void:
	# Keep the last message available to chart operations without duplicate inline UI.
	if status: status.text=message; status.hide()
	if toast_layer: toast_layer.notify(message,kind)

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
	if id=="eclipse" and not has_custom_cover(id): return ECLIPSE_COVER
	if song_cover_textures.has(id): return song_cover_textures[id]
	# A saved cover can be shown before the song's details finish loading.
	if has_custom_cover(id):
		var image=Image.new()
		if image.load(ProjectSettings.globalize_path(cover_path(id)))==OK:
			song_cover_textures[id]=ImageTexture.create_from_image(image)
			return song_cover_textures[id]
	return CUSTOM_COVER

func cover_tint_for_id(id: String) -> Color:
	return Color.from_hsv(float(posmod(id.hash(),360))/360.0,.18,1.0)

# --- song details: album art and gameplay background ---
func has_album_art(id: String) -> bool: return id=="eclipse" or has_custom_cover(id)
func background_path(id: String) -> String: return "user://backgrounds/"+id+".png"
func has_background(id: String) -> bool: return FileAccess.file_exists(background_path(id))

func background_texture_for_id(id: String) -> Texture2D:
	if song_background_textures.has(id): return song_background_textures[id]
	if not has_background(id): return null
	var image=Image.new()
	if image.load(ProjectSettings.globalize_path(background_path(id)))!=OK: return null
	song_background_textures[id]=ImageTexture.create_from_image(image)
	return song_background_textures[id]

# Behind the highway: the song's gameplay background, else its album art, else plain black (null).
func stage_backdrop_for_id(id: String) -> Texture2D:
	if has_background(id): return background_texture_for_id(id)
	if has_album_art(id): return cover_texture_for_id(id)
	return null

# Reads a picked PNG/JPG; returns an Image, or a message explaining why it can't be used.
func load_picked_image(path: String) -> Variant:
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>12*1024*1024: return "Choose a PNG or JPG image under 12 MB."
	var data=file.get_buffer(file.get_length()); file.close()
	var image=Image.new()
	if image.load_png_from_buffer(data)!=OK and image.load_jpg_from_buffer(data)!=OK:
		return "Choose a valid PNG or JPG image."
	if image.get_width()<64 or image.get_height()<64: return "Choose an image at least 64 × 64 pixels."
	image.convert(Image.FORMAT_RGBA8)
	return image

# Album art is stored square (center crop) at 512 px. Returns "" on success.
func save_cover_image(id: String,source: Image) -> String:
	var image=source.duplicate() as Image
	var square=mini(image.get_width(),image.get_height())
	image=image.get_region(Rect2i((image.get_width()-square)/2,(image.get_height()-square)/2,square,square))
	image.resize(512,512,Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute("user://covers")
	if image.save_png(cover_path(id))!=OK: return "Could not save album art on this device."
	song_cover_textures[id]=ImageTexture.create_from_image(image)
	cover_palettes.erase(id)
	return ""

func remove_cover(id: String) -> void:
	if has_custom_cover(id): DirAccess.remove_absolute(ProjectSettings.globalize_path(cover_path(id)))
	song_cover_textures.erase(id); cover_palettes.erase(id)

# Gameplay backgrounds keep their shape, scaled down to at most 1920 px on the long side.
func save_background_image(id: String,source: Image) -> String:
	var image=source.duplicate() as Image
	var longest=maxi(image.get_width(),image.get_height())
	if longest>1920:
		var k=1920.0/longest
		image.resize(maxi(1,roundi(image.get_width()*k)),maxi(1,roundi(image.get_height()*k)),Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute("user://backgrounds")
	if image.save_png(background_path(id))!=OK: return "Could not save the background on this device."
	song_background_textures[id]=ImageTexture.create_from_image(image)
	return ""

func remove_background(id: String) -> void:
	if has_background(id): DirAccess.remove_absolute(ProjectSettings.globalize_path(background_path(id)))
	song_background_textures.erase(id)

func song_details_entry(id: String) -> Dictionary:
	if id=="eclipse": return eclipse_song()
	for entry in library.songs:
		if str(entry.id)==id: return entry
	return {}

# Saves title, artist, album and track number for any song, playing or not.
func update_song_details(id: String,fields: Dictionary) -> void:
	var entry: Dictionary=song.duplicate() if str(song.id)==id else song_details_entry(id)
	if entry.is_empty(): return
	var title_text=str(fields.get("title","")).strip_edges()
	if not title_text.is_empty(): entry.title=title_text
	for key in ["artist","album"]: entry[key]=str(fields.get(key,"")).strip_edges()
	var track=int(fields.get("track",0))
	if track>0: entry.track=track
	else: entry.erase("track")
	if id=="eclipse":
		var edits=prefs.get_value("songs","eclipse",{}).duplicate(true)
		for key in ["title","album","artist"]: edits[key]=entry[key]
		if entry.has("track"): edits.track=entry.track
		else: edits.erase("track")
		prefs.set_value("songs","eclipse",edits); prefs.save("user://preferences.cfg")
	else:
		for i in library.songs.size():
			if str(library.songs[i].id)==id: library.songs[i]=entry
		library.atomic_write("user://songs/library.json",library.songs)
	if str(song.id)==id:
		for key in ["title","artist","album"]: song[key]=entry[key]
		if entry.has("track"): song.track=entry.track
		else: song.erase("track")
		refresh_editor()
	refresh_library(); lobby.refresh()

# Song details open from the Chart Studio song list and return there.
func open_song_details(id: String) -> void:
	if mode!="library" or song_details_entry(id).is_empty(): return
	UiMotion.transition(self)
	chart_library.visible=false
	song_details.open(id); song_details.visible=true
	UiMotion.screen(song_details)

func open_chart_history(id: String,level: String) -> void:
	if mode!="library": return
	var view=load("res://scripts/chart_history.gd").new(); view.game=self; view.song_id=id; view.level=level
	ui.add_child(view); view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func close_song_details() -> void:
	UiMotion.back(self)
	song_details.visible=false
	if mode=="library":
		chart_library.visible=true
		UiMotion.reveal(chart_library)

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
		apply_song(eclipse_song(),demo_stream)
		return true
	if index<1 or index>library.songs.size(): return false
	var entry: Dictionary=library.songs[index-1]
	if str(entry.id)==str(song.id) and audio.stream!=null:
		loading_song_index=-1; loading_open_editor=false; return true
	loading_song_index=index; loading_open_editor=open_studio
	if song_metadata.has(str(entry.id)) and song_metadata[str(entry.id)].has("error"):
		song_metadata.erase(str(entry.id))
	start_song_worker()
	return false

func apply_song(entry: Dictionary,stream: AudioStream, prepared: Dictionary = {}) -> void:
	stop_audition(); song=entry; audio.stream=stream; cursor=0; loop_a=0; loop_b=minf(8,length()); loop_enabled=false
	mr.set_source(stream)
	var metadata=prepared if not prepared.is_empty() else song_metadata.get(str(song.id),{})
	saved_notes=metadata.notes.duplicate(true) if metadata.has("notes") else library.load_chart(song.id)
	document.load_notes(baseline_notes())
	if metadata.has("waveform"): waveform=metadata.waveform
	else: build_waveform()
	if not song_metadata.has(str(song.id)):
		song_metadata[str(song.id)]={"duration":length(),"waveform":waveform,"notes":saved_notes.duplicate(true),"note_count":saved_notes.size(),"has_chart":library.has_chart(str(song.id))}
	if chart_library:
		chart_library.update_selection()
		chart_library.update_card_metadata(str(song.id))
	features.activate_song()
	refresh_editor()
	if metadata.has("chart_error"): tell(str(metadata.chart_error))
	if not library.message.is_empty(): tell(library.message)

func save_editor() -> void:
	stop_audition()
	var sorted=document.notes.duplicate(true); sorted.sort_custom(func(a,b):return a.time<b.time)
	if features.save_chart(sorted)!=OK: tell("Could not save. Your draft is still here; check storage."); return
	saved_notes=sorted; saved_settings=document.settings.duplicate(true); document.dirty=false
	if features.current_variant=="original" and song_metadata.has(str(song.id)):
		song_metadata[str(song.id)].notes=sorted.duplicate(true)
		song_metadata[str(song.id)].note_count=sorted.size()
		song_metadata[str(song.id)].has_chart=true
	refresh_editor(); refresh_library()
	tell("Chart saved. Open LIBRARY to choose another song, or TEST CHART to play it.")

func refresh_editor() -> void:
	title_label.text=preload("res://scripts/lobby.gd").display_title(str(song.title))+("  •  unsaved" if document.dirty else "")
	refresh_section_marks()
	studio.refresh_inspector()
	info.text="%d NOTES    /    %.2f s    /    %d BPM    /    %s" % [document.notes.size(),cursor,roundi(chart_bpm()),editor_tool.to_upper() if editor_tool in ["select","range"] else "PLACE "+editor_tool.to_upper()]
	snap_button.text="SNAP OFF" if snap_division==0 else "SNAP 1/"+str(snap_division*4)
	loop_button.set_selected(loop_enabled)
	loop_button.text="LOOP ON" if loop_enabled else "LOOP OFF"; speed_button.text=str(audition_speed)+"× SPEED"; refresh_transport()
func refresh_transport() -> void:
	updating=true; seek.max_value=length(); seek.set_value_no_signal(cursor); updating=false; play_button.text="PAUSE" if audio.playing else "PLAY"
func seek_to(time: float) -> void:
	cursor=clampf(time,0,maxf(0,length()-.001))
	if timeline and mode=="editor": timeline.reveal_time(cursor)
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
	document.checkpoint(); document.move_note(float(n.time)+direction*(.01 if snap_division==0 else 60.0/chart_bpm()/snap_division),int(n.lane)+lane,length()); refresh_editor()
func resize_note(direction: int) -> void:
	var n=document.selection()
	if not n.is_empty(): document.resize(float(n.duration)+direction*60.0/chart_bpm()/4,length()); refresh_editor()
func duplicate_note() -> void:
	var n=document.selection()
	if n.is_empty(): return
	document.checkpoint(); n=n.duplicate(true); n.time=minf(maxf(0,length()-float(n.duration)),float(n.time)+60.0/chart_bpm()); space_authored_notes([n],document.notes); document.notes.append(n); document.selected=document.notes.size()-1; refresh_editor()

func build_waveform() -> void:
	waveform=SynkLibrary.waveform_for_stream(audio.stream)

func test_editor_here() -> void:
	var from=maxf(0,cursor-2.0*60.0/float(chart_bpm()))
	var notes=document.notes.filter(func(n): return float(n.time)>=from)
	start_game(notes,false,"full")
	start_position=from; song_time=from-countdown
	visual_song_time=song_time; visual_clock_ready=false
