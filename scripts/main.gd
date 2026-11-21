extends Control

const UiMotion = preload("res://scripts/ui_motion.gd")
const ScreenStyle = preload("res://scripts/screen_style.gd")
const UiSound = preload("res://scripts/ui_sound.gd")
const StageIntro = preload("res://scripts/stage_intro.gd")
const ResultsScreen = preload("res://scripts/results_screen.gd")
const NeonAction = preload("res://scripts/neon_action.gd")
const ECLIPSE_COVER = preload("res://assets/lobby/eclipse_cover.png")
const CUSTOM_COVER = preload("res://assets/lobby/custom_cover.png")
const SsrgRules = preload("res://scripts/ssrg_input_rules.gd")
const SsrgSustain = preload("res://scripts/ssrg_sustain_rules.gd")
const AudioClock = preload("res://scripts/audio_clock.gd")
var cached_output_latency=-1.0
var ssrg_touch_router=preload("res://scripts/ssrg_touch_router.gd").new()
var ssrg_contact_ids:Dictionary={}
var ssrg_contact_serial=1000000

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
var song_details_return_ssrg=false
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
# Slides completed by an early lift flash at their end puck once it reaches the line: {at, note}.
var pending_end_hits: Array = []
var flash = 0.0
var flash_lane = 6
var judgement = ""
var judgement_kind = "tap"
var countdown = 0.0
var gameplay_start_lead = 0.0
var audio_handoff = 0.0   # seconds after the music starts in which notes ease onto its clock
var resume_countdown = 0.0
var resume_start_audio = false
var ssrg_resume_position=-1.0
var start_position = 0.0
var timing_ms = 0.0
var ssrg_touch_sync_ms = 0.0
var bluetooth_mode = false
var bluetooth_latency_ms = 180.0
var note_speed = 1.0
# "rectangle", "circle" or "puck" (the purple glass puck); chosen in Settings.
var note_shape = "circle"
# Highway slope in degrees (Settings): low is flat and far-reaching, high looks down steeply.
var highway_angle = 35.0
var recorder_angle_slider: HSlider
var recorder_angle_label: Label
var record_overview: Control
var recorder_seek_target=-1.0
# Highway look: "gold" or "neon", optional custom rail/band colors ("" follows the style),
# and how dark the see-through highway surface is (1 = the style's default).
const HIGHWAY_STYLES=["gold","neon","ssrg","aurora","solar"]
var highway_style = "ssrg"  # the SKD stage is the stock look for every song
var ssrg_presentation:Node
var ssrg_screens:Control
var ssrg_playable_run = false
var ssrg_lane_count = 13
# A SYNK song played with SSRG rules. Every SYNK play run uses them, on every highway style;
# the editor and practice keep SYNK's own rules.
var ssrg_forced_run = false
var ssrg_rules_everywhere = true  # tests of SYNK's own rules turn this off
func forces_ssrg_mode() -> bool:
	return ssrg_rules_everywhere
# The SSRG look: imported SSRG runs, and SYNK songs played with the "ssrg" highway style.
# SSRG judging and scoring rules follow ssrg_playable_run, so other styles keep their own look.
func uses_ssrg_gameplay() -> bool:
	return ((ssrg_playable_run and not ssrg_forced_run) or (highway_style=="ssrg" and (mode in ["play","paused"] or highway_preview))) and not uses_recorder_colors()
# The chart recorder always uses SKD's recovered visual stage, while recording and while
# correcting, without enabling SKD scoring, judgment, combo, health, or gameplay input rules.
# (The classic tilted SYNK recorder and its angle slider are retired.)
var recorder_skd_view = true
func uses_skd_recorder_surface() -> bool:
	return uses_recorder_colors() and recorder_skd_view
func toggle_recorder_skd_view() -> void:
	recorder_skd_view = not recorder_skd_view
	prefs.set_value("editor", "recorder_skd_view", recorder_skd_view); prefs.save("user://preferences.cfg")
	update_recorder_skd_button()
	arrange_touches.clear()
	refresh_correct_view(); update_recorder_focus()
	judgement = "SKD VIEW" if recorder_skd_view else "CLASSIC VIEW"; flash = 1
var recorder_skd_button: Button
func update_recorder_skd_button() -> void:
	if recorder_skd_button: recorder_skd_button.text = "SKD view: " + ("on" if recorder_skd_view else "off"); recorder_skd_button.set_selected(recorder_skd_view)
# Correct mode keeps the recording view exactly; the even, tapered spacing is retired.
func uses_even_correct_view() -> bool:
	return false
func uses_skd_stage() -> bool:
	return uses_ssrg_gameplay() or uses_skd_recorder_surface()
func old_ssrg_ui() -> bool:
	return uses_ssrg_gameplay() and bool(prefs.get_value("highway","old_ssrg_ui",false))
func change_old_ssrg_ui(on: bool) -> void:
	prefs.set_value("highway","old_ssrg_ui",on);prefs.save("user://preferences.cfg")
	if field and field.world:
		field.world.refresh_highway_look()
		field.world.ssrg_animation_frame=-1
		field.world.look_signature_frame=-1
	if settings_panel:settings_panel.refresh()
# True while a settings preview shows the live highway outside gameplay. Each visible
# preview registers itself, so switching pages never turns the stage off under another one.
var highway_preview = false
var highway_preview_users: Dictionary = {}
func set_highway_preview(on: bool, user: Object = null) -> void:
	if user:
		if on: highway_preview_users[user.get_instance_id()]=true
		else: highway_preview_users.erase(user.get_instance_id())
		on=not highway_preview_users.is_empty()
	if highway_preview==on: return
	var was_ssrg_look=uses_ssrg_gameplay()
	highway_preview=on
	# A closing preview stops the stage drawing this very frame. Otherwise it was drawn once
	# more in the look it falls back to, preparing shaders nobody was going to see.
	if not on and field and field.viewport and mode in ["menu","guide","library","editor"]:
		field.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if uses_ssrg_gameplay()!=was_ssrg_look and field and field.world: field.world.refresh_highway_look()
func gameplay_lane_count() -> int:
	return ssrg_lane_count if ssrg_playable_run else SynkChart.LANES
# SSRG Playables keeps its own note speed (set on that screen), separate from SYNK's.
func ssrg_speed_setting() -> float:
	return clampf(float(prefs.get_value("ssrg","speed_value",float(prefs.get_value("ssrg","speed",1.0))*3.0)),1.0,10.0)
func ssrg_note_speed() -> float: return ssrg_speed_setting()/3.0
# SKD's own note-size option: GameControl.NoteScaleConst in the APK is {1.0, .9, .8}, chosen by
# NoteScaleIndex (default 0, so 1.0). It multiplies NoteScaleMaximum 212x116 / 132x72. A SPEED 1
# recording measured notes at 0.99 of that full size. SKD runs use only this option, never
# SYNK's free note-size setting.
const SSRG_NOTE_SCALES = [1.0, .9, .8]
func ssrg_note_scale_index() -> int:
	return clampi(int(prefs.get_value("ssrg","note_scale_index",0)),0,SSRG_NOTE_SCALES.size()-1)
func ssrg_note_scale() -> float: return SSRG_NOTE_SCALES[ssrg_note_scale_index()]
func gameplay_note_size() -> float: return ssrg_note_scale() if ssrg_playable_run else note_size

func ssrg_touch_lane(point: Vector3, lane: float) -> bool:
	var ui_point=Vector2(point.x/field.world.SSRG_UNIT,-point.z/field.world.SSRG_UNIT-234.0)
	var channel=lane*12.0/float(SynkChart.MAX_LANE)
	return SsrgRules.contains_lane(ui_point,channel,ssrg_lane_count) or (roundi(channel) in [0,12] and SsrgRules.side_channel(ui_point,ssrg_lane_count)==roundi(channel))

func hit_good_window(kind: String = "tap") -> float:
	return SsrgRules.good_window() if ssrg_playable_run else (.23*extras.scale() if kind=="slide" else extras.good_window())
var ssrg_playable_previous_style = "gold"
var rail_color = ""
var band_color = ""
var highway_opacity = 1.0
# "adaptive" colors notes and highway from the song's artwork; "theme" keeps the style's own colors.
var highway_colors = "adaptive"
var gameplay_colors: Dictionary = {}
var rail_glow_opacity = .12
var note_size=1.0
# Note and trail brightness (Settings > Visuals > Notes); below 1 tones down the neon.
const DEFAULT_NOTE_BRIGHTNESS=.8
var note_brightness=DEFAULT_NOTE_BRIGHTNESS
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
# SSRG Playables judge hold and slide connectors more loosely: a wider reach (in lanes; one
# SSRG position is one lane) and a short grace after the connector passes the line.
const SSRG_CHECKPOINT_LANES = 3.2
const SSRG_CHECKPOINT_GRACE = .15
const SSRG_SLIDE_END_LANES = 4.5
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
var ssrg_playables: Control
# Game-wide private sign-in (on only when local/ssrg_login.json is bundled).
var app_login: CanvasLayer
var chart_library: Control
var menu_settings_open = false
var settings_layer: CanvasLayer
# Whether opening Settings hid the lobby, so closing it brings the lobby back.
var settings_hid_lobby = false
var modal: Panel
var pause_backdrop: ColorRect
var pause_layer: CanvasLayer
var pause_tween: Tween
var modal_title: Label
var modal_body: Label
# Gameplay pause: song line, progress and a note speed control under the tiles.
var pause_info: Label
var pause_progress: Control
var pause_speed: Control
var pause_speed_label: Label
var settings_panel: Control
# The finish animation that carries the combo from the stage into the results screen.
var finish_overlay: Control
var finishing = false
var finish_elapsed = 0.0
var pending_results: Dictionary = {}
var ssrg_failed = false
var slide_tools: Control
var sync_helper: Control
var song_sync: Control
var bluetooth_toggle: Button
var bluetooth_latency_input: Control
var primary: Button
var pause_home: Button
var pause_settings: Button
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
var record_types: Array=["tap","hold","slide"]
var studio_kind_buttons: Dictionary = {}
var arrange_selection: Dictionary = {}
var arranging = false
var arrange_touches: Dictionary = {}

# Fira Sans (SIL Open Font Licence, assets/fonts/OFL.txt) is the game's typeface. Every screen
# builds its fonts from ThemeDB.fallback_font, so it is swapped before any of them is created.
const GAME_FONT = preload("res://assets/fonts/FiraSans-Regular.ttf")
func _enter_tree() -> void:
	ThemeDB.fallback_font=GAME_FONT

# Auto pacing lets VSync follow display refresh without a second software timer.
# A fixed software limit can still be chosen in Settings.
func display_refresh_rate() -> int:
	var rate=DisplayServer.screen_get_refresh_rate()
	return clampi(roundi(rate),30,144) if rate>0 else 60
func frame_rate_setting() -> int:
	return int(prefs.get_value("gameplay","frame_rate",0))  # 0 = match display
func apply_frame_rate() -> void:
	var chosen=frame_rate_setting()
	Engine.max_fps=0 if chosen<=0 else chosen
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
# Hit effect style (Settings > Visual effects > Hit effects).
# SKD's own flash art, or Lumen, SYNK's flash drawn the same way. Old saved Classic and
# Bloom choices open as SKD.
const HIT_STYLES = ["ssrg","lumen"]
var hit_style = "ssrg"
# Hit effect size (0.6-1.6) and an optional colour ("" follows the note colours).
var hit_size = 1.0
var hit_color = ""
func change_hit_look(key: String,value: Variant) -> void:
	if key=="size": hit_size=clampf(float(value),.6,1.6); prefs.set_value("effects","hit_size",hit_size)
	elif key=="color": hit_color=str(value); prefs.set_value("effects","hit_color",hit_color)
	else: return
	prefs.save("user://preferences.cfg")
	if settings_panel: settings_panel.refresh()
func change_hit_style(value: String) -> void:
	hit_style=value if value in HIT_STYLES else "ssrg"
	prefs.set_value("effects","hit_style",hit_style); prefs.save("user://preferences.cfg")
	if settings_panel: settings_panel.refresh()
# Highway render resolution (Settings): the 3D highway is drawn at 100%, 85% or 75% of the
# screen's resolution and scaled up. Lower is softer but much lighter on phone GPUs.
const RENDER_SCALES = [1.0, .85, .75]
func render_scale() -> float:
	var value=float(prefs.get_value("gameplay","render_scale",1.0))
	return value if RENDER_SCALES.has(value) else 1.0
func apply_render_scale() -> void:
	if field and field.viewport: field.viewport.scaling_3d_scale=render_scale()
func change_render_scale(value: float) -> void:
	prefs.set_value("gameplay","render_scale",value); prefs.save("user://preferences.cfg")
	apply_render_scale()
	if settings_panel: settings_panel.refresh()
func change_frame_rate(value: int) -> void:
	prefs.set_value("gameplay","frame_rate",value); prefs.save("user://preferences.cfg")
	apply_frame_rate()

# Smallest text size any menu label, field or button may use (1600x900 design units).
# Anything smaller is hard to read on a phone, so new controls are raised to this.
const MIN_TEXT_SIZE = 17
func _floor_text_size(node: Node) -> void:
	if not (node is Label or node is Button or node is LineEdit or node is RichTextLabel): return
	(func():
		if not is_instance_valid(node) or not node is Control: return
		var key = "normal_font_size" if node is RichTextLabel else "font_size"
		if node.has_theme_font_size_override(key) and node.get_theme_font_size(key) < MIN_TEXT_SIZE:
			node.add_theme_font_size_override(key, MIN_TEXT_SIZE)
	).call_deferred()
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	get_tree().node_added.connect(_floor_text_size)
	process_priority=-10
	apply_frame_rate()
	if OS.get_name()=="iOS": NativeFilePicker.defer_system_gestures.call_deferred()
	# Start-up intro (scripts/app_intro.gd) on its own top layer, over the lobby; tap skips it.
	var intro_layer=CanvasLayer.new(); intro_layer.layer=100; add_child.call_deferred(intro_layer)
	var intro=preload("res://scripts/app_intro.gd").new(); intro_layer.add_child(intro)
	intro.finished.connect(func(): intro_layer.queue_free())
	# The lobby animates in as the intro clears, on every launch.
	intro.revealing.connect(func(): if lobby: lobby.play_launch_entrance())
	# Debug builds: a one-shot gameplay stress test, only when its trigger file exists.
	if OS.is_debug_build() and not preload("res://scripts/stress_test.gd").trigger_path().is_empty():
		var stress=preload("res://scripts/stress_test.gd").new(); stress.game=self; add_child.call_deferred(stress)
	if OS.has_feature("android"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	prefs.load("user://preferences.cfg"); timing_ms = float(prefs.get_value("audio","offset_ms",0))
	# Audio OUTPUT latency is auto-compensated by heard_position(); touch INPUT latency
	# is not measurable, so touchscreens register taps late. Start mobile with a sane
	# compensation (positive = treat the tap as earlier) instead of 0; the player can
	# retune it in Settings. Desktop/pointer input stays at 0.
	var touch_sync_default: float = 40.0 if OS.get_name() in ["Android", "iOS"] else 0.0
	ssrg_touch_sync_ms=clampf(float(prefs.get_value("ssrg","touch_sync_ms",touch_sync_default)), -200, 200)
	bluetooth_mode=bool(prefs.get_value("audio","bluetooth_mode",false))
	slide_snap=str(prefs.get_value("editor","slide_snap","free"))
	if slide_snap not in ["free","lanes","beats"]: slide_snap="free"
	bluetooth_latency_ms=clampf(float(prefs.get_value("audio","bluetooth_latency_ms",180)),0,600)
	note_lines=bool(prefs.get_value("editor","note_lines",true))
	ghost_recording=bool(prefs.get_value("editor","ghost_recording",true))
	space_close_chords=bool(prefs.get_value("editor","space_close_chords",true))
	recorder_note_speed=clampf(snappedf(float(prefs.get_value("editor","note_speed",1.0)),.1),.1,5.0)
	record_speed=float(prefs.get_value("editor","record_speed",1.0))
	if record_speed not in RECORD_SPEEDS: record_speed=1.0
	var legacy_speed = clampf(float(prefs.get_value("gameplay","note_speed",1.0)), .5, 3.0)
	note_speed = clampf(snappedf(float(prefs.get_value("gameplay","speed_value",legacy_speed*3.0)),.1),1.0,10.0)/3.0
	hit_style = str(prefs.get_value("effects","hit_style","ssrg"))
	if hit_style not in HIT_STYLES: hit_style="ssrg"
	hit_size = clampf(float(prefs.get_value("effects","hit_size",1.0)),.6,1.6)
	hit_color = str(prefs.get_value("effects","hit_color",""))
	if hit_color!="" and not Color.html_is_valid(hit_color): hit_color=""
	note_shape = str(prefs.get_value("gameplay","note_shape","circle"))
	if note_shape not in ["rectangle","circle","puck"]: note_shape="rectangle"
	highway_angle = clampf(float(prefs.get_value("gameplay","highway_angle",35.0)),18.0,90.0)
	# One-time move to the SKD look; a style picked afterwards is kept.
	if not bool(prefs.get_value("highway","skd_default",false)):
		prefs.set_value("highway","style","ssrg"); prefs.set_value("highway","skd_default",true); prefs.save("user://preferences.cfg")
	highway_style = str(prefs.get_value("highway","style","ssrg"))
	if highway_style not in HIGHWAY_STYLES: highway_style="ssrg"
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
	note_brightness=clampf(float(prefs.get_value("gameplay","note_brightness",DEFAULT_NOTE_BRIGHTNESS)),.4,1.2)
	RenderingServer.global_shader_parameter_set("synk_note_brightness",note_brightness)
	trail_style=str(prefs.get_value("gameplay","trail_style","neon"))
	if trail_style not in ["neon","solid"]: trail_style="neon"
	hold_trail_width=1.0
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
	apply_render_scale()
	ui = Control.new(); ui.theme=preload("res://scripts/game_theme.gd").create(); add_child(ui); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_safe_area(); get_viewport().size_changed.connect(apply_safe_area)
	toast_layer=preload("res://scripts/toast_notifications.gd").new()
	toast_layer.game=self; add_child(toast_layer)
	# Cutout insets may arrive after immersive mode, without a window resize.
	var safe_poll=Timer.new(); safe_poll.name="SafeAreaPoll"; safe_poll.wait_time=.5; safe_poll.autostart=true
	safe_poll.timeout.connect(apply_safe_area); add_child(safe_poll)
	build_combo_digit_textures()
	build_ui()
	lobby=Control.new(); lobby.set_script(load("res://scripts/lobby.gd")); lobby.game=self; lobby.theme=preload("res://scripts/game_theme.gd").arcade()
	ui.add_child(lobby); lobby.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.move_child(lobby,0)
	arrange_preview=preload("res://scripts/arrange_audio_preview.gd").new(); arrange_preview.game=self; add_child(arrange_preview)
	build_studio()
	note_arranger=preload("res://scripts/recorder_note_arranger.gd").new(); note_arranger.game=self
	record_tools.add_child(note_arranger); note_arranger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlap_tools=preload("res://scripts/recorder_overlaps.gd").new(); overlap_tools.game=self
	record_tools.add_child(overlap_tools); overlap_tools.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	correct_bar=preload("res://scripts/recorder_correct_bar.gd").new(); correct_bar.game=self; record_tools.add_child(correct_bar)
	chart_library=Control.new(); chart_library.set_script(load("res://scripts/chart_library.gd")); chart_library.game=self; chart_library.theme=preload("res://scripts/game_theme.gd").arcade()
	ui.add_child(chart_library); chart_library.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.move_child(chart_library,1)
	extras=preload("res://scripts/gameplay_extras.gd").new(); extras.game=self; add_child(extras)
	settings_panel=Control.new(); settings_panel.set_script(load("res://scripts/settings_screen.gd")); settings_panel.game=self; settings_panel.theme=preload("res://scripts/game_theme.gd").arcade()
	# Its own layer, above every screen and the pause card, so it opens from anywhere.
	settings_layer=CanvasLayer.new(); settings_layer.name="SettingsOverlay"; settings_layer.layer=1005; add_child(settings_layer)
	var settings_host=Control.new(); settings_layer.add_child(settings_host); settings_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_host.mouse_filter=Control.MOUSE_FILTER_IGNORE
	settings_host.add_child(settings_panel); settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel.visible=false
	song_details=Control.new(); song_details.set_script(load("res://scripts/song_details.gd")); song_details.game=self; song_details.theme=preload("res://scripts/game_theme.gd").arcade()
	ui.add_child(song_details); song_details.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.move_child(song_details,3); song_details.visible=false
	bluetooth_toggle=settings_panel.bluetooth_toggle; bluetooth_latency_input=settings_panel.bluetooth_latency_input
	sync_helper=Control.new(); sync_helper.set_script(load("res://scripts/sync_helper.gd")); sync_helper.game=self; sync_helper.theme=preload("res://scripts/game_theme.gd").arcade()
	ui.add_child(sync_helper); sync_helper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.move_child(sync_helper,3); sync_helper.visible=false
	song_sync=Control.new(); song_sync.set_script(load("res://scripts/song_sync.gd")); song_sync.game=self; song_sync.theme=preload("res://scripts/game_theme.gd").arcade()
	ui.add_child(song_sync); song_sync.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ssrg_playables=Control.new(); ssrg_playables.set_script(load("res://scripts/ssrg_playables.gd")); ssrg_playables.game=self; ssrg_playables.theme=preload("res://scripts/game_theme.gd").arcade()
	ui.add_child(ssrg_playables); ssrg_playables.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.move_child(ssrg_playables,3); ssrg_playables.visible=false
	saved_notes = library.load_chart("eclipse")
	get_window().files_dropped.connect(func(files):
		if files.size()>0 and mode in ["menu","library","editor"]:
			open_editor(); import_audio(files[0]))
	get_tree().auto_accept_quit = false
	finish_overlay=Control.new(); finish_overlay.set_script(load("res://scripts/finish_overlay.gd")); finish_overlay.game=self
	ui.add_child(finish_overlay)
	var ssrg_judgement=Control.new(); ssrg_judgement.set_script(load("res://scripts/ssrg_judgement.gd")); ssrg_judgement.game=self
	ui.add_child(ssrg_judgement)
	ssrg_presentation=preload("res://scripts/ssrg_presentation.gd").new(); ssrg_presentation.game=self
	add_child(ssrg_presentation)
	ssrg_screens=preload("res://scripts/ssrg_screens.gd").new(); ssrg_screens.game=self
	ui.add_child(ssrg_screens)
	var ssrg_score=preload("res://scripts/ssrg_score_hud.gd").new(); ssrg_score.game=self
	safe_parent("SafeSSRGScoreHud").add_child(ssrg_score)
	ui.move_child(ssrg_screens,-1)
	app_login=preload("res://scripts/app_login.gd").new(); app_login.game=self; add_child(app_login)
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
				set_mode("editor")
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
	var result=load("res://scripts/recorder_action.gd").new() if record_tools!=null and (parent==record_tools or (aids_drawer!=null and parent==aids_drawer)) else NeonAction.new()
	result.text=text; result.caption_size=19 if variant in ["primary","record"] else 17; result.compact=true
	result.variant=variant
	if record_tools!=null and parent==record_tools: result.caption_size=21
	rect(result,parent,x,y,right,bottom)
	result.pressed.connect(action)
	return result

# The Settings gear every screen carries. It opens Settings over that screen.
func settings_gear(parent: Node,x: float,y: float,right: float,bottom: float) -> Button:
	var gear=preload("res://scripts/gear_button.gd").new(); gear.accent=preload("res://scripts/arcade_style.gd").CYAN
	rect(gear,parent,x,y,right,bottom); gear.pressed.connect(open_lobby_settings)
	return gear

func pause_action(parent: Node,text: String,x: float,y: float,right: float,bottom: float,action: Callable,variant: String) -> Button:
	var result=load("res://scripts/pause_action.gd").new()
	result.text=text; result.caption_size=19; result.compact=true; result.variant=variant
	rect(result,parent,x,y,right,bottom); result.pressed.connect(action)
	return result

func build_ui() -> void:
	# Song details sit top right, leaving the left side for energy and score.
	song_hud=label(ui,"",.62,.015,.91,.105,25); song_hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	difficulty_hud=label(ui,"EXPERT   Lv. 12",.62,.105,.91,.15,18); difficulty_hud.add_theme_color_override("font_color",Color(1,1,1,.62)); difficulty_hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	# Under the score, clear of the album cover tile that sits at the top centre of the stage.
	auto_play_hud=label(safe_parent("SafeAutoPlayHud"),"AUTO PLAY  •  PREVIEW",.1,.215,.34,.26,19); auto_play_hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	auto_play_hud.add_theme_color_override("font_color",Color("38baff"))
	# A soft dark shadow keeps the pause button, energy and score readable over any cover.
	hud_shadow=TextureRect.new(); rect(hud_shadow,ui,-.04,-.06,.40,.28); hud_shadow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shadow_texture=GradientTexture2D.new(); shadow_texture.width=256; shadow_texture.height=256
	shadow_texture.fill=GradientTexture2D.FILL_RADIAL; shadow_texture.fill_from=Vector2(.5,.5); shadow_texture.fill_to=Vector2(1,.5)
	var shadow_ramp=Gradient.new(); shadow_ramp.offsets=PackedFloat32Array([0.0,.55,1.0])
	shadow_ramp.colors=PackedColorArray([Color(0.003,0.003,0.003,.72),Color(0.003,0.003,0.003,.45),Color(0.003,0.003,0.003,0)])
	shadow_texture.gradient=shadow_ramp; hud_shadow.texture=shadow_texture
	hud_shadow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; hud_shadow.stretch_mode=TextureRect.STRETCH_SCALE
	ui.move_child(hud_shadow,0)
	# Energy gauge and score stack on the left, next to the pause button.
	score_panel=SynkScoreHud.new(); rect(score_panel,safe_parent("SafeScoreHud"),.1,.025,.34,.205)
	hud=score_panel.score_label
	# The combo sits in the empty space to the right of the highway, clear of the notes.
	combo_hud=Control.new(); rect(combo_hud,ui,.765,.24,.995,.45)
	combo_hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	rank_hud=label(ui,"SS",.925,.015,.99,.12,46); rank_hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	rank_hud.add_theme_color_override("font_color",Color("b985ff")); rank_hud.add_theme_color_override("font_outline_color",Color("5921a8")); rank_hud.add_theme_constant_override("outline_size",5)
	pause_button=button(safe_parent("SafePauseButton"),"II",.02,.025,.08,.105,toggle_pause,"nav")
	# Judgments are plain bold white text for now, so they suit any cover palette.
	hit_label=label(ui,"",.3,.25,.7,.315,40); hit_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	timing_label=label(ui,"",.3,.312,.7,.342,18); timing_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	practice_hud=label(ui,"",.33,.025,.74,.08,18); practice_hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var bold=FontVariation.new(); bold.base_font=ThemeDB.fallback_font; bold.variation_embolden=1.0
	hit_label.add_theme_font_override("font",bold)
	hit_label.add_theme_color_override("font_shadow_color",Color(0.006,0.006,0.006,.6)); hit_label.add_theme_constant_override("shadow_outline_size",8)
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
	# Plain white numbers; a faint dark edge keeps them readable over bright highways.
	countdown_label.add_theme_color_override("font_color",Color.WHITE)
	countdown_label.add_theme_color_override("font_outline_color",Color(0,0,0,.35)); countdown_label.add_theme_constant_override("outline_size",6)
	guide_button=button(safe_parent("SafeGuideButton"),"NOTE GUIDE",.84,.16,.98,.22,func(): set_mode("guide"))
	guide_back=button(safe_parent("SafeGuideBack"),"‹  BACK",.40,.85,.60,.96,func(): set_mode("menu"),"nav")
	# Song intro sits above the HUD and below the pause/results modal.
	stage_intro=StageIntro.new(); stage_intro.game=self; ui.add_child(stage_intro)
	var play_cover=preload("res://scripts/play_cover.gd").new(); play_cover.game=self
	safe_parent("SafePlayCover").add_child(play_cover); stage_intro.play_cover=play_cover
	results_screen=ResultsScreen.new(); results_screen.game=self; results_screen.theme=preload("res://scripts/game_theme.gd").arcade(); ui.add_child(results_screen)
	# Pause uses a solid full-screen background and an opaque card.
	pause_layer=CanvasLayer.new();pause_layer.name="PauseOverlay";pause_layer.layer=1000;add_child(pause_layer)
	var pause_root=Control.new();pause_root.name="PauseRoot";pause_layer.add_child(pause_root)
	pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The pause card uses the menus' look (Inter Tight, sentence case, frosted card), not the gameplay theme.
	pause_root.theme=preload("res://scripts/game_theme.gd").arcade()
	pause_backdrop=ColorRect.new(); rect(pause_backdrop,pause_root,0,0,1,1); pause_backdrop.color=Color("101010")
	pause_backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	modal=Panel.new(); rect(modal,safe_parent("SafeModal",pause_root),.19,.11,.81,.89)
	preload("res://scripts/modal_input.gd").register(modal)
	var pause_panel=StyleBoxFlat.new();pause_panel.bg_color=Color(1,1,1,.055);pause_panel.set_corner_radius_all(28);pause_panel.anti_aliasing=true
	modal.add_theme_stylebox_override("panel",pause_panel)
	modal_title=label(modal,"synk",.04,.025,.96,.17,48); modal_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	modal_title.add_theme_font_override("font",preload("res://scripts/arcade_style.gd").mono_bold()); modal_title.add_theme_color_override("font_color",Color("f4f1ea"))
	modal_body=label(modal,"",.06,.17,.94,.43,22); modal_body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; modal_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	pause_settings=settings_gear(modal,.885,.04,.955,.15)
	primary=pause_action(modal,"PLAY",.23,.88,.77,.97,primary_action,"primary")
	pause_restart=pause_action(modal,"RESTART",.36,.88,.64,.97,restart_from_pause,"secondary")
	pause_home=pause_action(modal,"HOME",.66,.88,.94,.97,return_home,"nav")
	pause_info=label(modal,"",.06,.20,.94,.30,22); pause_info.add_theme_color_override("font_color",Color("bcb7ad"))
	pause_info.clip_text=true
	pause_progress=Control.new(); rect(pause_progress,modal,.06,.31,.94,.335); pause_progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pause_progress.draw.connect(draw_pause_progress)
	pause_speed_label=label(modal,"Note speed",.06,.78,.40,.92,24); pause_speed_label.add_theme_color_override("font_color",Color("f4f1ea"))
	pause_speed=preload("res://scripts/settings_screen.gd").Stepper.new(1,10,.1,3,"",1); rect(pause_speed,modal,.50,.78,.94,.92)
	pause_speed.value_changed.connect(change_pause_speed)
	actions=Control.new(); rect(actions,safe_parent("SafeActions"),0,0,1,1); actions.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button(actions,"●  RECORD NEW",.02,.91,.20,.98,start_new_recording,"record")
	button(actions,"PLAY SAVED",.22,.91,.39,.98,func(): start_game(saved_notes),"primary")
	button(actions,"AUTO PLAY",.41,.91,.58,.98,start_autoplay)
	button(actions,"CHART STUDIO / IMPORT AUDIO",.60,.91,.98,.98,open_editor)
	record_tools = Control.new();record_tools.theme=preload("res://scripts/game_theme.gd").arcade();rect(record_tools, safe_parent("SafeRecorderControls"), 0, 0, 1, 1);record_tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	record_tools.set_meta("keep_caption_size", true)



	record_left_plate = recorder_plate(Rect2(0.012, 0.135, 0.105, 0.5))
	record_right_plate = recorder_plate(Rect2(0.883, 0.135, 0.105, 0.405))
	var kinds = ["all", "tap", "hold", "slide", "flick"]
	for i in kinds.size():
		var kind = kinds[i]
		kind_buttons.append(button(record_tools, kind.to_upper(), 0.02, 0.15 + i * 0.096, 0.11, 0.228 + i * 0.096, func():
			if arranging:
				if kind == "all": delete_arrange_note()
				else: change_arrange_note_type(kind)
			else:
				if kind=="all":select_all_record_types()
				else:toggle_record_type(kind), "tool"))
		kind_buttons[-1].tooltip_text = {"all": "Enable every note type for gesture detection", "tap": "Detect taps", "hold": "Detect holds", "slide": "Detect slides", "flick": "Detect flicks"}[kind]
	button(record_tools, "STOP & REVIEW", 0.84, 0.022, 0.988, 0.105, stop_take, "record")
	# Correct mode: back to recording sits beside Stop & review; the side columns step away.
	resume_record_button = button(record_tools, "RECORD", 0.735, 0.022, 0.83, 0.105, toggle_arrange, "tool")
	resume_record_button.tooltip_text = "Resume recording from here"; resume_record_button.visible = false
	recorder_angle_caption = label(record_tools, "Angle", 0.12, 0.035, 0.19, 0.095, 16);recorder_angle_caption.add_theme_color_override("font_color", Color("bcb7ad"))
	recorder_angle_slider=HSlider.new();rect(recorder_angle_slider,record_tools,0.20,0.047,0.40,0.087)
	recorder_angle_slider.min_value=18;recorder_angle_slider.max_value=90;recorder_angle_slider.step=1
	recorder_angle_slider.value=highway_angle
	recorder_angle_slider.tooltip_text="Recorder camera: 35° is the original view; 90° is flat overhead."
	recorder_angle_slider.value_changed.connect(change_highway_angle)
	recorder_angle_label=label(record_tools,"%d°" % roundi(highway_angle),0.405,0.035,0.465,0.095,16)
	recorder_angle_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var side = func(i: int) -> Array: return [0.89, 0.15 + i * 0.096, 0.98, 0.228 + i * 0.096]
	var b = side.call(0);aids_toggle = button(record_tools, "AIDS  ◂", b[0], b[1], b[2], b[3], toggle_record_aids, "tool")
	b = side.call(1);arrange_button = button(record_tools, "CORRECT", b[0], b[1], b[2], b[3], toggle_arrange)
	arrange_button.tooltip_text = "Pause the music to move or correct notes, then resume recording"
	b = side.call(2);take_undo_button = button(record_tools, "UNDO", b[0], b[1], b[2], b[3], undo_record_note, "tool")
	b = side.call(3);take_redo_button = button(record_tools, "REDO", b[0], b[1], b[2], b[3], redo_record_note, "tool")
	# Correct mode: type letters or numbers and they are inserted as slides drawn in that shape.
	b = side.call(4);text_slides_button = button(record_tools, "TEXT", b[0], b[1], b[2], b[3], open_text_slides, "tool")
	text_slides_button.tooltip_text = "Insert letters or numbers as slides shaped like them"
	text_slides_field = LineEdit.new(); rect(text_slides_field, record_tools, b[0], b[1], b[0] + .001, b[1] + .001)
	text_slides_field.modulate.a = 0.0; text_slides_field.mouse_filter = Control.MOUSE_FILTER_IGNORE; text_slides_field.max_length = 24
	text_slides_field.placeholder_text = "Letters or numbers to draw as slides"
	text_slides_field.text_submitted.connect(func(value: String): insert_text_slides(value); text_slides_field.text = "")

	record_info = label(record_tools, "", 0.55, 0.03, 0.83, 0.1, 17);record_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	record_info.add_theme_font_override("font", preload("res://scripts/arcade_style.gd").semi())
	recorder.progress = ProgressBar.new();rect(recorder.progress, record_tools, 0.12, 0.111, 0.67, 0.116)
	recorder.progress.show_percentage = false;recorder.progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track = StyleBoxFlat.new();track.bg_color = Color(1, 1, 1, 0.08);track.set_corner_radius_all(2)
	var fill = track.duplicate();fill.bg_color = Color("ff8a5b")
	recorder.progress.add_theme_stylebox_override("background", track);recorder.progress.add_theme_stylebox_override("fill", fill)
	record_overview=preload("res://scripts/song_overview.gd").new()
	record_overview.game=self;record_overview.horizontal=true;record_overview.recorder_mode=true
	rect(record_overview,record_tools,0.12,0.126,0.67,0.186)
	record_overview.rebuild()

	record_help = label(record_tools, "", 0.2, 0.925, 0.8, 0.985, 17);record_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record_help.add_theme_color_override("font_color", Color("e6e1d7"))
	record_help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .85)); record_help.add_theme_constant_override("shadow_outline_size", 6)

	# Two columns of large buttons: every recording aid is a full-size touch target.
	record_sidebar = recorder_plate(Rect2(0.5, 0.135, 0.375, 0.695))
	aids_drawer = Control.new();rect(aids_drawer, record_tools, 0, 0, 1, 1);aids_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	record_sidebar.reparent(aids_drawer)
	label(aids_drawer, "Recording aids", 0.515, 0.145, 0.87, 0.18, 16).add_theme_color_override("font_color", Color("bcb7ad"))
	var row = func(i: int) -> Array: return [0.51 + (i % 2) * 0.18, 0.19 + (i / 2) * 0.125, 0.685 + (i % 2) * 0.18, 0.298 + (i / 2) * 0.125]
	var r = row.call(0);note_lines_button = button(aids_drawer, "", r[0], r[1], r[2], r[3], toggle_note_lines);update_note_lines_button()

	r = row.call(1);record_mark_buttons["verse2"] = button(aids_drawer, "", r[0], r[1], r[2], r[3], func(): mark_section("verse2", song_time))
	r = row.call(2);record_mark_buttons["bridge"] = button(aids_drawer, "", r[0], r[1], r[2], r[3], func(): mark_section("bridge", song_time))
	r = row.call(3);dots_button = button(aids_drawer, "", r[0], r[1], r[2], r[3], toggle_dots_mode)
	ghost_button = button(aids_drawer, "GHOST ON" if ghost_recording else "GHOST OFF", r[0], r[1], r[2], r[3], toggle_ghost_recording)
	ghost_button.tooltip_text = "Show faded existing chart notes approaching the judgment line while recording a new layer."
	r = row.call(4);button(aids_drawer, "TAKE SETUP", r[0], r[1], r[2], r[3], recorder.show_setup)
	# Both speeds are steppers: minus and plus either side of the value (tapping the value still cycles).
	var stepper = func(cell: Array, down: Callable, up: Callable) -> Array:
		var minus = button(aids_drawer, "−", cell[0], cell[1], cell[0] + 0.045, cell[3], down)
		var plus = button(aids_drawer, "+", cell[2] - 0.045, cell[1], cell[2], cell[3], up)
		minus.caption_size = 26; plus.caption_size = 26
		return [minus, plus]
	r = row.call(5);recorder_note_speed_button = button(aids_drawer, "NOTES  %.1f×" % recorder_note_speed, r[0] + 0.05, r[1], r[2] - 0.05, r[3], cycle_recorder_note_speed)
	note_speed_steps = stepper.call(r, func(): step_recorder_note_speed(-1), func(): step_recorder_note_speed(1))
	recorder_note_speed_button.tooltip_text = "Note travel speed only. Music playback speed stays unchanged."
	r = row.call(6);record_speed_button = button(aids_drawer, str(record_speed) + "× SPEED", r[0] + 0.05, r[1], r[2] - 0.05, r[3], cycle_record_speed)
	record_speed_steps = stepper.call(r, func(): step_record_speed(-1), func(): step_record_speed(1))
	refresh_speed_steppers()
	record_speed_button.tooltip_text = "Recording playback speed: 1×, 0.75×, 0.5×, 0.25×, 1.25×, 1.5×"
	r = row.call(7);mr.register_button(button(aids_drawer, "MR OFF", r[0], r[1], r[2], r[3], mr.toggle))
	r = row.call(8);record_aids_button = button(aids_drawer, "", r[0], r[1], r[2], r[3], toggle_record_aids_display)
	update_record_aids_button()
	r = row.call(9);space_chords_button = button(aids_drawer, "", r[0], r[1], r[2], r[3], toggle_space_close_chords)
	space_chords_button.tooltip_text = "Notes played together keep at least one empty lane between them: lanes 2 and 3 become 2 and 4."
	update_space_chords_button()
	aids_drawer.visible = false

var aids_drawer: Control
var text_slides_button: Button
var text_slides_field: LineEdit
func open_text_slides() -> void:
	if not arranging: return
	# With a hold or slide selected the button shapes that note; otherwise it inserts typed text.
	if shapeable_selection():
		open_shape_picker(); return
	text_slides_field.text = ""
	floating_text_input.open_for(text_slides_field)

# A recorded hold (or slide) can be turned into a letter or number drawn by at most two slides.
func shapeable_selection() -> bool:
	return arranging and not arrange_selection.is_empty() and str(arrange_selection.note.kind) in ["hold", "slide"]

var shape_picker: Control
func open_shape_picker() -> void:
	if not shapeable_selection(): return
	if "slide" in recorder.locks():
		judgement = "SLIDES LOCKED"; flash = 1; return
	if shape_picker == null: build_shape_picker()
	shape_picker.visible = true
	UiMotion.screen(shape_picker)

func close_shape_picker() -> void:
	if shape_picker: shape_picker.visible = false

func build_shape_picker() -> void:
	var A = preload("res://scripts/arcade_style.gd")
	var Glyphs = preload("res://scripts/slide_glyphs.gd")
	shape_picker = Control.new(); rect(shape_picker, record_tools, 0, 0, 1, 1)
	shape_picker.mouse_filter = Control.MOUSE_FILTER_STOP; shape_picker.visible = false
	var dim = ColorRect.new(); dim.color = Color(A.INK, .72); rect(dim, shape_picker, 0, 0, 1, 1)
	dim.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed: close_shape_picker())
	var card = Panel.new(); rect(card, shape_picker, .12, .2, .88, .8)
	var box = StyleBoxFlat.new(); box.bg_color = Color(A.NIGHT, .96); box.set_corner_radius_all(roundi(A.CARD_RADIUS))
	box.shadow_color = Color(0, 0, 0, .5); box.shadow_size = 24
	card.add_theme_stylebox_override("panel", box)
	var heading = label(card, "Turn into a letter or number", .04, .05, .7, .2, 30)
	heading.add_theme_font_override("font", A.SERIF)
	var hint = label(card, "Pick a letter or number. The hold becomes up to two slides drawn in that shape; a short hold is lengthened so the shape stays playable.", .04, .19, .96, .28, 16)
	hint.add_theme_color_override("font_color", A.MUTED)
	button(card, "Cancel", .8, .06, .96, .18, close_shape_picker, "tool")
	var characters = Glyphs.SHAPE_ORDER
	var columns = 11
	for i in characters.length():
		var character = characters[i]
		var col = i % columns; var row_index = i / columns
		var x = .04 + col * (.92 / columns); var y = .34 + row_index * .2
		var key = button(card, character, x + .004, y, x + .92 / columns - .004, y + .17, func(): shape_selected_note(character))
		key.caption_size = 26

# Replaces the selected hold or slide with the character's slides over the same time and lane.
func shape_selected_note(character: String) -> int:
	close_shape_picker()
	if not shapeable_selection() or "slide" in recorder.locks(): return 0
	var n: Dictionary = arrange_selection.note
	if n.kind in recorder.locks() or recorder.current_pass() not in ["all", "slide"]: return 0
	var notes = preload("res://scripts/slide_glyphs.gd").shape_notes(character, float(n.time), float(n.duration), float(n.lane))
	if notes.is_empty(): return 0
	var index = int(arrange_selection.index)
	if arrange_selection.document:
		document.checkpoint()
		if index >= 0 and index < document.notes.size(): document.notes.remove_at(index)
		document.notes.append_array(notes); document.selected = -1
	else:
		if index >= 0 and index < capture.notes.size(): capture.notes.remove_at(index)
		capture.notes.append_array(notes)
	arrange_selection.clear(); arrange_touches.clear()
	commit_take_history(); refresh_arrange_controls()
	judgement = "SHAPE %s · %d SLIDE%s" % [character, notes.size(), "" if notes.size() == 1 else "S"]; flash = 1
	return notes.size()

# Inserts the text as letter/number shaped slides into the take, ending just before the
# current position so the new slides are on screen. Each character is three beats tall and
# eight lanes wide, with a beat between characters.
func insert_text_slides(text: String) -> int:
	var Glyphs = preload("res://scripts/slide_glyphs.gd")
	var cleaned = Glyphs.clean(text)
	if cleaned.is_empty() or not arranging: return 0
	if "slide" in recorder.locks():
		judgement = "SLIDES LOCKED"; flash = 1; return 0
	var beat = 60.0 / maxf(30.0, float(chart_bpm()))
	var notes = Glyphs.build(cleaned, 0.0, beat * 3.0, 6.0, 8.0, beat)
	if notes.is_empty(): return 0
	var span = 0.0
	for n in notes: span = maxf(span, float(n.time) + float(n.duration))
	var start = maxf(0.0, song_time - span - .15)
	if recorder.use_range and recorder.region.y > recorder.region.x:
		start = clampf(start, recorder.region.x, maxf(recorder.region.x, recorder.region.y - span))
	start = minf(start, maxf(0.0, length() - span - .02))
	for n in notes: n.time = float(n.time) + start
	capture.notes.append_array(notes)
	arrange_selection.clear()
	commit_take_history(); refresh_arrange_controls()
	judgement = "TEXT · %d SLIDES" % notes.size(); flash = 1
	return notes.size()
var record_right_plate: Panel
var record_left_plate: Panel
var resume_record_button: Button
var correct_bar: Control
var recorder_angle_caption: Label
# While a take is running (not correcting, aids closed) the recorder shows only what you need
# to play: note types, Correct, Stop & review, status and the lanes. Setup-only controls
# (angle, seek strip, empty Undo/Redo) come back when you correct or open the aids.
func update_recorder_focus() -> void:
	if record_tools == null or aids_drawer == null: return
	var focus = mode == "record" and not arranging and not aids_drawer.visible
	# SKD's recovered camera is fixed, so the angle slider belongs to the classic view only.
	for node in [recorder_angle_caption, recorder_angle_slider, recorder_angle_label]:
		if node:node.visible=not focus and not recorder_skd_view
	# The take overview stays up during an active take too, not only while correcting.
	if record_overview:record_overview.visible=true
	var history = not take_undo.is_empty() or not take_redo.is_empty()
	var show_history = not focus or history
	take_undo_button.visible = show_history;take_redo_button.visible = show_history
	# Correct mode keeps every tool on its one bottom toolbar (recorder_correct_bar.gd):
	# the type column, the side column and their plates step away.
	var correcting = mode == "record" and arranging
	for node in kind_buttons: node.visible = not correcting
	record_left_plate.visible = not correcting
	for node in [record_right_plate, aids_toggle, arrange_button]: node.visible = not correcting
	if correcting: take_undo_button.visible = false; take_redo_button.visible = false
	resume_record_button.visible = correcting
	text_slides_button.visible = false; text_slides_field.visible = true
	var info_right = 0.725 if correcting else 0.83
	if not is_equal_approx(record_info.anchor_right, info_right): record_info.anchor_right = info_right; record_info.anchor_left = info_right - 0.28
	var plate_bottom = 0.135 + (0.405 if show_history else 0.213)
	if not is_equal_approx(record_right_plate.anchor_bottom, plate_bottom): record_right_plate.anchor_bottom = plate_bottom
	# Guidance until the first note lands; after that the lanes speak for themselves.
	record_help.visible = not focus or capture.notes.is_empty()

var record_aids_enabled = false
var record_aids_button: Button
func toggle_record_aids_display() -> void :
	record_aids_enabled = not record_aids_enabled
	prefs.set_value("editor", "record_aids", record_aids_enabled);prefs.save("user://preferences.cfg")
	update_record_aids_button()
func update_record_aids_button() -> void :
	if record_aids_button: record_aids_button.text = "GRID & WAVE: " + ("ON" if record_aids_enabled else "OFF");record_aids_button.set_selected(record_aids_enabled)
var aids_toggle: Button
func toggle_record_aids() -> void :
	aids_drawer.visible = not aids_drawer.visible
	aids_toggle.text = "AIDS  ▸" if aids_drawer.visible else "AIDS  ◂"
	aids_toggle.set_selected(aids_drawer.visible)
func recorder_plate(bounds: Rect2) -> Panel:
	var panel=Panel.new(); rect(panel,record_tools,bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var plate=StyleBoxFlat.new(); plate.bg_color=Color(0.05,0.05,0.06,.82)
	plate.border_color=Color(1,1,1,.07); plate.set_border_width_all(1); plate.set_corner_radius_all(24)
	panel.add_theme_stylebox_override("panel",plate); return panel

func set_mode(value: String,animate_transition:bool=true) -> void:
	var was_ssrg_look=uses_ssrg_gameplay()
	if ssrg_playable_run and value not in ["play","paused"]:
		ssrg_playable_run=false; ssrg_forced_run=false
		highway_style=ssrg_playable_previous_style if ssrg_playable_previous_style in HIGHWAY_STYLES else "gold"
		if field and field.world: field.world.refresh_highway_look()
	if value!=mode and animate_transition:
		# Menus slide forward and back by depth; entering or leaving the stage dissolves.
		var depth={"menu":0,"guide":1,"library":1,"editor":2,"results":3}
		if value in ["play","record","paused"] or mode in ["play","record","paused"]: UiMotion.transition(self,.24,0)
		else: UiMotion.transition(self,.38,-1 if int(depth.get(value,1))<int(depth.get(mode,1)) else 1)
	if value in ["play","record"] and loading_song_index>0:
		loading_song_index=-1; loading_open_editor=false
	# Moving between menu screens gets a soft whoosh; gameplay screens stay silent.
	if value!=mode and value in ["menu","library","editor","guide"]: UiSound.play(self,"transition")
	if value!="record" and arrange_preview: arrange_preview.stop()
	mode=value; menu_settings_open=false
	if settings_panel and settings_panel.visible: settings_panel.visible=false
	# The "ssrg" highway style only applies in gameplay, so entering or leaving it swaps the stage.
	if uses_ssrg_gameplay()!=was_ssrg_look and field and field.world: field.world.refresh_highway_look()
	if field and field.world:
		field.world.apply_camera()
		field.world.refresh_highway_look()
		field.world.face_ssrg_billboards()
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
	if ssrg_playables: ssrg_playables.visible=false
	chart_library.visible=mode=="library"
	if song_details: song_details.visible=false
	pause_backdrop.visible=mode=="paused"
	pause_layer.visible=mode=="paused"
	actions.visible=false; record_tools.visible=mode=="record"
	hud.visible=mode in ["play","paused"]; score_panel.visible=hud.visible and not uses_ssrg_gameplay(); hud_shadow.visible=score_panel.visible; hit_label.visible=mode in ["play","record"]; pause_button.visible=mode in ["play","record","paused"]
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
	var record_pause=mode=="paused" and paused_mode=="record"
	# Recorder controls retain their compact layout; the recorder pause card matches the gameplay one minus note speed.
	pause_button.anchor_right=.095 if mode=="play" or large_pause else .08
	pause_button.anchor_bottom=.125 if mode=="play" or large_pause else .105
	pause_button.caption_size=22 if mode=="play" or large_pause else 17
	modal.anchor_top=(.14 if large_pause else .22) if mode=="paused" else .11
	modal.anchor_bottom=(.86 if large_pause else .78) if mode=="paused" else .89
	modal_title.anchor_top=(.05 if large_pause else .07) if mode=="paused" else .025
	modal_title.anchor_bottom=(.20 if large_pause else .25) if mode=="paused" else .17
	modal_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT if mode=="paused" else HORIZONTAL_ALIGNMENT_CENTER
	modal_title.anchor_left=.06 if mode=="paused" else .04
	for part in [pause_speed,pause_speed_label]: part.visible=large_pause
	for part in [pause_info,pause_progress]: part.visible=mode=="paused"
	pause_info.anchor_top=.20 if large_pause else .26; pause_info.anchor_bottom=.30 if large_pause else .38
	pause_progress.anchor_top=.31 if large_pause else .40; pause_progress.anchor_bottom=.335 if large_pause else .432
	if record_pause: pause_info.text=str(song.get("title",""))+"   ·   Recording"
	if large_pause:
		pause_info.text=str(song.get("title",""))+"   ·   "+preload("res://scripts/chart_levels.gd").label(features.current_variant)
		pause_speed.sync_value(pause_speed_setting())
	var button_top=(.40 if large_pause else .50) if mode=="paused" else .88
	var button_bottom=(.72 if large_pause else .90) if mode=="paused" else .97
	for action_button in [primary,pause_restart,pause_home]:
		action_button.anchor_top=button_top; action_button.anchor_bottom=button_bottom
		action_button.caption_size=23 if mode=="paused" else (19 if action_button==primary else 17)
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

# Settings opens from every screen and covers it; BACK returns to that screen.
func open_lobby_settings() -> void:
	if settings_panel.visible: return
	if mode in ["play","record"]: return  # running gameplay pauses first, then Settings opens from the pause card
	UiMotion.transition(self)
	menu_settings_open=true
	settings_hid_lobby=mode=="menu" and lobby.visible
	if settings_hid_lobby: lobby.visible=false
	settings_panel.refresh(); settings_panel.visible=true
	UiMotion.screen(settings_panel)

func close_lobby_settings() -> void:
	UiMotion.back(self)
	menu_settings_open=false
	settings_panel.visible=false
	if mode=="paused": pause_speed.sync_value(pause_speed_setting())
	if mode=="menu" and settings_hid_lobby and not ssrg_playables.visible and not sync_helper.visible:
		lobby.visible=true
		UiMotion.reveal(lobby)

# SSRG Playables replaces the lobby while it is open; BACK returns to it.
func open_ssrg_playables() -> void:
	if mode!="menu": return
	UiMotion.transition(self)
	lobby.visible=false
	# Hidden lobby videos would keep decoding behind the screen; pause them while it is open.
	for video in [lobby.home_video,lobby.background_video]:
		if video: video.paused=true
	ssrg_playables.open()
	UiMotion.screen(ssrg_playables)

func close_ssrg_playables() -> void:
	UiMotion.back(self)
	ssrg_playables.visible=false
	if mode=="menu":
		lobby.visible=true
		var video=lobby.home_video if lobby.gateway and lobby.gateway.visible else lobby.background_video
		if video: video.paused=false
		UiMotion.reveal(lobby)

# The audio sync helper replaces the settings page while it is open; BACK or SAVE return to it.
func open_sync_helper() -> void:
	if not menu_settings_open: return
	UiMotion.transition(self)
	settings_panel.visible=false
	sync_helper.open()
	UiMotion.reveal(sync_helper)

# Song sync: tune the headset delay while Eclipse plays on the real highway (song_sync.gd).
func open_song_sync() -> void:
	if mode!="menu": return
	if document.dirty: tell("Save or RELOAD your chart before syncing."); return
	sync_helper.player.stop(); sync_helper.visible=false
	settings_panel.visible=false; menu_settings_open=false
	ui.move_child(song_sync,ui.get_child_count()-1)
	song_sync.begin()

func end_song_sync(previous_song: Dictionary,previous_stream: AudioStream) -> void:
	audio.stop(); audio.stream_paused=false; pointers.clear(); live.clear()
	countdown=0; resume_countdown=0; song_time=0; flash=0
	field.world.clear_notes(); field.world.clear_hit_effects()
	if previous_stream: apply_song(previous_song,previous_stream)
	else: apply_song(eclipse_song(),demo_stream)
	set_mode("menu")
	open_lobby_settings()

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

# SYNK note speed on SSRG Playables' scale: 1.0-10.0 in 0.1 steps, where 3.0 is the
# standard speed (note_speed 1x). note_speed stays the multiplier the highway reads.
func synk_speed_setting() -> float: return clampf(snappedf(note_speed*3.0,.1),1.0,10.0)
func change_synk_speed(value: float) -> void:
	var speed=clampf(snappedf(value,.1),1.0,10.0)
	note_speed=speed/3.0
	prefs.set_value("gameplay","speed_value",speed); prefs.set_value("gameplay","note_speed",note_speed)
	prefs.save("user://preferences.cfg")
# The speed the pause menu changes: SSRG rules use SSRG Playables' speed, everything else SYNK's.
func pause_speed_setting() -> float: return ssrg_speed_setting() if ssrg_playable_run else synk_speed_setting()
func change_pause_speed(value: float) -> void:
	if ssrg_playable_run: ssrg_playables.change_speed(snappedf(value,.1)-ssrg_speed_setting())
	else: change_synk_speed(value)

func change_highway_angle(value: float) -> void:
	highway_angle=clampf(value,18.0,90.0)
	prefs.set_value("gameplay","highway_angle",highway_angle); prefs.save("user://preferences.cfg")
	if recorder_angle_slider: recorder_angle_slider.set_value_no_signal(highway_angle)
	if recorder_angle_label: recorder_angle_label.text="%d°" % roundi(highway_angle)
	if field and field.world: field.world.apply_camera()

func change_highway_look(key: String,value: Variant) -> void:
	match key:
		"style": highway_style = str(value) if str(value) in HIGHWAY_STYLES else "gold"; value = highway_style
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
	if key in ["colors","style"]: apply_stage_cover()
	field.world.refresh_highway_look()
	if settings_panel: settings_panel.refresh()

# While the colour picker is open: show a colour without saving it.
func preview_gameplay_color(key: String,code: String) -> void:
	if not SynkGameplayColors.valid_key(key) or (code!="" and not Color.html_is_valid(code)): return
	if code=="": gameplay_colors.erase(key)
	else: gameplay_colors[key]=code
	apply_stage_cover()
	if field and field.world: field.world.refresh_highway_look()
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
	highway_style = "ssrg"; rail_color = ""; band_color = ""; highway_opacity = 1.0; highway_colors = "adaptive"
	prefs.save("user://preferences.cfg")
	apply_stage_cover()
	field.world.refresh_highway_look()
	if settings_panel: settings_panel.refresh()

# Circle and puck are both round artwork notes; they share sizes and placement.
func round_notes() -> bool: return note_shape in ["circle","puck"]
func change_note_brightness(value: float) -> void:
	note_brightness=clampf(value,.4,1.2)
	RenderingServer.global_shader_parameter_set("synk_note_brightness",note_brightness)
	prefs.set_value("gameplay","note_brightness",note_brightness)
	prefs.save("user://preferences.cfg")

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
	else: return
	prefs.set_value("gameplay",key,value); prefs.save("user://preferences.cfg")
	if field and field.world: field.world.clear_notes()

func return_home() -> void:
	if mode!="paused": return
	if paused_mode=="record":
		stop_take(); return
	var return_to_editor=practice.active
	# SSRG Playables go back to their own song list.
	var imported_ssrg=ssrg_playable_run and not ssrg_forced_run
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
	if imported_ssrg and not return_to_editor: open_ssrg_playables()

# Thin song progress bar with elapsed and total time.
func draw_pause_progress() -> void:
	var total=maxf(1.0,length()); var at=clampf(song_time/total,0.0,1.0)
	var track=StyleBoxFlat.new(); track.bg_color=Color(1,1,1,.1); track.set_corner_radius_all(3)
	pause_progress.draw_style_box(track,Rect2(0,0,pause_progress.size.x,pause_progress.size.y))
	if at>0:
		var fill=StyleBoxFlat.new(); fill.bg_color=Color("f3ece1"); fill.set_corner_radius_all(3)
		pause_progress.draw_style_box(fill,Rect2(0,0,maxf(pause_progress.size.y,pause_progress.size.x*at),pause_progress.size.y))

func restart_from_pause() -> void:
	if mode!="paused": return
	if pause_tween and pause_tween.is_running(): pause_tween.kill()
	modal.scale=Vector2.ONE; modal.modulate.a=1
	resume_countdown=0
	ssrg_resume_position=-1.0
	if practice.active: practice.restart()
	elif paused_mode=="record":
		cursor=start_position
		record_here()
	else:
		ssrg_failed=false
		start_game(last_play_notes,auto_play,last_section)

func primary_action() -> void:
	if menu_settings_open and settings_panel.visible: close_lobby_settings()
	elif mode=="paused":
		if ssrg_failed:restart_from_pause()
		else:toggle_pause()
	elif mode=="results":
		if practice.active: practice.restart()
		else: start_game(last_play_notes,auto_play,last_section)
	else: start_game(saved_notes)

func start_autoplay() -> void:
	var notes=baseline_notes()
	if notes.is_empty():
		modal_body.text="This song has no chart yet. Record or add notes in Chart Studio, then save it to preview with Auto Play."
		return
	start_game(notes,true)

func baseline_notes() -> Array:
	return saved_notes if features.chart_exists() else []

func audio_time() -> float:
	if audio.stream_paused:return maxf(0,audio.get_playback_position())
	return AudioClock.heard_position(audio.get_playback_position(),AudioServer.get_time_since_last_mix(),output_latency(),audio.pitch_scale)
func refresh_output_latency() -> void:
	cached_output_latency=maxf(0,AudioServer.get_output_latency())
func output_latency() -> float:
	if cached_output_latency<0:refresh_output_latency()
	return cached_output_latency
func effective_timing_ms() -> float: return timing_ms-(bluetooth_latency_ms if bluetooth_mode else 0.0)
func chart_time() -> float: return maxf(0,audio_time()+effective_timing_ms()/1000.0)
func ssrg_touch_time(sampled_clock:float) -> float:
	# SKD keeps device/user touch calibration separate from chart/audio sync.
	# Positive values compensate late touch delivery by moving its judgment
	# timestamp earlier; judgment windows themselves never change.
	return sampled_clock-ssrg_touch_sync_ms/1000.0
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

func change_ssrg_touch_sync(value:float) -> void:
	ssrg_touch_sync_ms=clampf(snappedf(value,5.0),-200,200)
	prefs.set_value("ssrg","touch_sync_ms",ssrg_touch_sync_ms);prefs.save("user://preferences.cfg")

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
	visual_song_time=AudioClock.visual_step(visual_song_time,target,delta,audio.pitch_scale)
func uses_recorder_colors() -> bool:
	return mode=="record" or (mode=="paused" and paused_mode=="record") or (recorder!=null and recorder.reviewing_audio)

func authoring_lane_gap() -> float:
	# The outer part of the sprite is a soft glow. Separate the visible bodies,
	# keeping near-simultaneous notes close without forcing their centers together.
	# Measured on the surface the notes are drawn on (SKD sprites and spacing in the recorder).
	var world=field.world
	var width=world.SSRG_NOTE_SIZE.x if uses_skd_stage() else world.NOTE_WIDTH
	var step=absf(world.lane_world_x(1.0)-world.lane_world_x(0.0)) if uses_skd_stage() else world.lane_step()
	return (width*note_size*.55+.08)/step

# Space close chords (recording aids): notes played together keep at least one empty
# lane between them, so a chord in lanes 2 and 3 records as 2 and 4 (2, 3, 4 as 2, 4, 6).
# The note that just landed is the one that moves, unless an edge forces the other.
const CLOSE_CHORD_GAP = 2.0
var space_close_chords = true
var space_chords_button: Button
func chord_lane_gap() -> float:
	return maxf(authoring_lane_gap(), CLOSE_CHORD_GAP) if space_close_chords else authoring_lane_gap()
func toggle_space_close_chords() -> void:
	space_close_chords = not space_close_chords
	prefs.set_value("editor", "space_close_chords", space_close_chords); prefs.save("user://preferences.cfg")
	update_space_chords_button()
func update_space_chords_button() -> void:
	if space_chords_button: space_chords_button.text = "Space close chords: " + ("on" if space_close_chords else "off"); space_chords_button.set_selected(space_close_chords)

func space_authored_notes(incoming: Array,fixed: Array) -> bool:
	var resolved=true
	for note in incoming:
		if not SynkNoteSpacing.place(note,incoming,fixed,authoring_lane_gap()).resolved: resolved=false
	if not resolved: tell("This chord is too crowded to separate. Move a note or reduce its size.")
	return resolved

func note_travel_seconds() -> float:
	# APK default basicTime=3.5; normalized 1x corresponds to original UI speed 3.
	if ssrg_playable_run: return 3.5/ssrg_note_speed()
	if uses_recorder_colors(): return (3.5 if recorder_skd_view else 2.6)/recorder_note_speed
	return 3.5/note_speed

func cycle_recorder_note_speed() -> void:
	recorder_note_speed=snappedf(recorder_note_speed+.1,.1)
	if recorder_note_speed>5.0: recorder_note_speed=.1
	apply_recorder_note_speed()
# The minus and plus buttons beside each speed: one step at a time, stopping at the ends.
var note_speed_steps: Array = []
var record_speed_steps: Array = []
func step_recorder_note_speed(direction: int) -> void:
	recorder_note_speed=clampf(snappedf(recorder_note_speed+.1*direction,.1),.1,5.0)
	apply_recorder_note_speed()
func apply_recorder_note_speed() -> void:
	recorder_note_speed_button.text="NOTES  %.1f×" % recorder_note_speed
	prefs.set_value("editor","note_speed",recorder_note_speed); prefs.save("user://preferences.cfg")
	field.world.clear_notes()
	refresh_speed_steppers()
func step_record_speed(direction: int) -> void:
	var ordered=RECORD_SPEEDS.duplicate(); ordered.sort()
	record_speed=float(ordered[clampi(ordered.find(record_speed)+direction,0,ordered.size()-1)])
	apply_record_speed()
func refresh_speed_steppers() -> void:
	if note_speed_steps.size()==2:
		note_speed_steps[0].disabled=recorder_note_speed<=.1+.001; note_speed_steps[1].disabled=recorder_note_speed>=5.0-.001
	if record_speed_steps.size()==2:
		record_speed_steps[0].disabled=record_speed<=RECORD_SPEEDS.min()+.001; record_speed_steps[1].disabled=record_speed>=RECORD_SPEEDS.max()-.001
func length() -> float: return audio.stream.get_length()
# Score: fixed points per judgement, not divided by the chart's note count, times a combo
# multiplier that rises 0.1x for every full 100 combo (x1.1 at 100, x1.2 at 200, ...),
# capped at x2.0. A miss resets the combo and so the multiplier. SSRG runs have no combo
# multiplier: every 100 combo earns nothing extra there.
const NOTE_POINTS = {"PERFECT": 1000, "GREAT": 800, "GOOD": 500}
func combo_multiplier() -> float:
	if ssrg_playable_run: return 1.0
	return minf(2.0, 1.0 + .1 * floori(combo / 100.0))
func add_points(grade: String) -> void:
	if ssrg_playable_run and ssrg_presentation and ssrg_presentation.active:
		score=ssrg_presentation.score_rules.add(grade,ssrg_presentation.state)
		return
	score += roundi(NOTE_POINTS.get(grade, 0) * combo_multiplier())
func accuracy() -> float: return 100.0 if judged==0 else float(earned)/judged*100
# Retire completed notes once; keep long sustains active until their tails finish.
func first_live_index() -> int:
	while live_cursor<live.size() and live[live_cursor].done: live_cursor+=1
	return live_cursor

func total_judgements() -> int:
	if judgement_total_size!=live.size():
		judgement_total_cache=live.size()
		for entry in live:
			if entry.note.kind=="hold" or (ssrg_playable_run and entry.note.kind=="slide"): judgement_total_cache+=1
			judgement_total_cache+=entry.note.get("checkpoints",[]).size()
		judgement_total_size=live.size()
	return judgement_total_cache

# Checkpoint dots: when one reaches the bar, the finger must be over the trail's lane.
# Returns false if the hold or slide broke on a missed dot.
func process_checkpoints(entry: Dictionary, finger_lane: float, automated: bool) -> bool:
	if ssrg_playable_run and not automated:
		update_ssrg_sustain(entry)
		return not entry.done or not entry.has("missed_at")
	var checks: Array=entry.note.get("checkpoints",[])
	while int(entry.get("checks_done",0))<checks.size():
		var index=int(entry.get("checks_done",0))
		var at=float(entry.note.time)+float(checks[index])
		if song_time<at: break
		var lane=SynkChart.lane_at(entry.note,at)
		if ssrg_playable_run and not automated:
			if song_time>=at+SsrgRules.good_window(true):
				judge(entry,-1);return false
			if pointers.has(entry.pointer) and ssrg_touch_lane(pointers[entry.pointer].world,lane):
				entry.checks_done=index+1;pass_checkpoint(entry,lane,absf(song_time-at));continue
			if song_time<at+SsrgRules.good_window(true): break
			judge(entry,-1);return false
		var tolerance=SSRG_CHECKPOINT_LANES if ssrg_playable_run else CHECKPOINT_LANE_TOLERANCE
		if automated or absf(finger_lane-lane)<=tolerance:
			entry.checks_done=index+1; pass_checkpoint(entry,lane)
		# SSRG Playables: a finger still on its way gets a moment to reach the connector.
		elif ssrg_playable_run and song_time<at+SSRG_CHECKPOINT_GRACE: break
		else: entry.checks_done=index+1; judge(entry,-1); return false
	return true

func pass_checkpoint(entry: Dictionary, lane: float, error: float = 0.0, source_grade: String = "") -> void:
	var grade=source_grade if not source_grade.is_empty() else (SsrgSustain.node_grade(error,false,str(entry.get("sustain_grade","GOOD"))) if ssrg_playable_run else "PERFECT")
	if ssrg_playable_run:entry.sustain_grade=grade
	var weight=1.0 if grade=="PERFECT" else (.8 if grade=="GREAT" else .5)
	performance_samples.append({"time":song_time,"weight":weight,"amount":1})
	if ssrg_playable_run:field.world.ssrg_theme.resume_sustain(entry)
	else:field.world.spawn_hit(lane,str(entry.note.kind))
	judged+=1; earned+=weight; judgment_counts[grade]+=1
	combo+=1; combo_pulse=1.0; max_combo=maxi(combo,max_combo)
	judgement=grade; flash=1; flash_lane=roundi(lane)
	add_points(grade)
	if ssrg_playable_run and ssrg_presentation:ssrg_presentation.judged(grade,entry.note)

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
	# SSRG mode: the SYNK song is judged, scored and sped like an imported SSRG run.
	if (not ssrg_playable_run or ssrg_forced_run) and forces_ssrg_mode() and mode!="editor" and not is_practice:
		ssrg_playable_run=true; ssrg_forced_run=true; ssrg_lane_count=13; ssrg_playable_previous_style=highway_style
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
	refresh_output_latency()
	ssrg_touch_router.reset()
	ssrg_contact_ids.clear();ssrg_contact_serial=1000000
	live_cursor=0; judgement_total_size=-1
	field.world.clear_hit_effects()
	field.world.clear_notes()
	auto_play=automated
	visual_clock_ready=false
	resume_countdown=0
	ssrg_resume_position=-1.0
	arranging=false; arrange_touches.clear(); arrange_selection.clear(); arrange_button.text="CORRECT"
	last_section=section if not section.is_empty() else play_mode
	if not section_available(last_section): last_section="full"
	play_range=section_range(last_section)
	pending_end_hits.clear()
	var sorted=notes.duplicate(true); sorted.sort_custom(func(a,b): return a.time<b.time)
	sorted=sorted.filter(func(n): return float(n.time)>=play_range.x-.001 and float(n.time)<play_range.y)
	# Flicks are up-only: normalize every flick's direction here so both the swipe
	# judgement (which reads note.direction) and the drawn arrow agree.
	for n in sorted:
		if n.kind=="flick": n.direction=0
	if ssrg_playable_run:
		preload("res://scripts/ssrg_presentation.gd").apply_events(sorted,song.get("ssrg_presentation",{}))
		for n in sorted:
			if n.kind=="slide": n.ssrg_path=true
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
	# Keep chart/audio timestamps intact. After the hidden countdown, advance
	# through a silent approach so even a note at time zero travels in fully.
	start_position=play_range.x-lead_in
	var first_note_time=float(sorted[0].time) if not sorted.is_empty() else start_position
	score=0; displayed_score=0; combo=0; combo_pulse=0; rank_pulse=0; shown_rank="SS"; hold_pulse_time=0; max_combo=0; earned=0; judged=0; ssrg_failed=false; score_panel.energy=.5; score_panel.shown_energy=.5; judgment_counts={"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0}; countdown=3; start_position=play_range.x-lead_in; song_time=start_position-3; judgement="READY"; flash=1
	update_section_volume()
	# A restart only replays the stage entrance; coming from a menu shows the loading card first.
	var restarting=mode in ["play","paused"]
	set_mode("play")
	if ssrg_playable_run and ssrg_presentation:ssrg_presentation.reset(total_judgements(),song.get("ssrg_presentation",{}))
	gameplay_start_lead=maxf(2.0,note_travel_seconds()-(first_note_time-start_position))
	audio_handoff=0.0
	song_time=start_position-gameplay_start_lead-countdown
	apply_stage_cover()
	# Build every note of the chart now (behind the loading card); play only shows and hides them.
	field.world.begin_prebuild()
	var cover_id := str(song.id)
	var cover := cover_texture_for_id(cover_id)
	var tint := Color.WHITE if cover_id=="eclipse" or has_custom_cover(cover_id) else cover_tint_for_id(cover_id)
	if stage_intro_enabled:
		# Compile every gameplay shader behind the loading card, not mid-song.
		if not restarting: field.world.prewarm(); warm_hud_text()
		field.world.prefill_hits()
		stage_intro.begin(cover,tint,str(song.title),intro_details(),restarting)
		# Behind the loading card, prepare the stage's shaders a frame at a time.
		if not restarting: field.world.begin_warmup()
		judgement=""
	else:
		stage_intro.show_gameplay_cover(cover,tint)
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
	var id=str(song.id)
	field.world.set_cover(stage_backdrop_for_id(id),Color.WHITE,not has_background(id) and has_album_art(id))
	var palette=cover_palette_for_id(str(song.id)) if highway_colors=="adaptive" and not uses_recorder_colors() else SynkCoverPalette.fallback()
	if highway_style in preload("res://scripts/concept_highway.gd").STYLES and not uses_recorder_colors() and not ssrg_playable_run and not palette.from_cover:
		palette=preload("res://scripts/concept_highway.gd").palette(highway_style)
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
	var difficulty=preload("res://scripts/chart_levels.gd").label(features.current_variant).to_upper()
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

func record_here() -> void :
	audio.stop();audio.stream_paused = false;audio.pitch_scale = record_speed;capture.notes.clear();capture.gestures.clear();pointers.clear();tool = "auto"
	recorder_seek_target=-1.0
	visual_clock_ready = false
	resume_countdown = 0
	arranging = false;arrange_touches.clear();arrange_selection.clear();arrange_button.text = "CORRECT"
	overdub = true;start_position = clampf(cursor, 0, maxf(0, length() - 0.02));countdown = 3;song_time = start_position - 3;set_mode("record")
	recorder.begin()
	ready_point = chart_empty_point()
	reset_take_history()
	apply_stage_cover()
	refresh_arrange_controls()
	refresh_section_marks()
	if record_overview:record_overview.rebuild()

func seek_recording_to(value: float) -> void:
	if mode!="record":return
	var first=recorder.region.x if recorder.active else 0.0
	var last=recorder.region.y if recorder.active else length()
	var target=clampf(value,first,maxf(first,last-.001))
	if not arranging:
		recorder.seal_gestures()
		commit_take_history()
		toggle_arrange()
	song_time=target;visual_song_time=target;visual_clock_ready=false;cursor=target
	recorder_seek_target=target
	if record_overview:record_overview.queue_redraw()

func stop_take() -> void :
	if mode != "record" and not (mode == "paused" and paused_mode == "record"): return
	if recorder.setup: recorder.setup.queue_free();recorder.setup = null
	if recorder.finish(): return
	audio.stop();audio.stream_paused = false;audio.pitch_scale = 1;capture.gestures.clear()
	arranging = false;arrange_touches.clear();arrange_selection.clear();arrange_button.text = "CORRECT"
	cursor = clampf(song_time, 0, length());set_mode("editor")
	if not recorder.takes.is_empty():
		recorder.apply_take(recorder.takes[recorder.selected_take].notes)
		recorder.show_review()

func cycle_record_speed() -> void:
	record_speed=float(RECORD_SPEEDS[(RECORD_SPEEDS.find(record_speed)+1)%RECORD_SPEEDS.size()])
	apply_record_speed()
func apply_record_speed() -> void:
	if mode=="record" or (mode=="paused" and paused_mode=="record"): audio.pitch_scale=record_speed
	record_speed_button.caption_text=str(record_speed)+"× SPEED"
	record_speed_button.text=record_speed_button.caption_text
	record_speed_button.caption.text=record_speed_button.caption_text
	prefs.set_value("editor","record_speed",record_speed); prefs.save("user://preferences.cfg")
	refresh_speed_steppers()

func toggle_pause(animate_transition:bool=true) -> void:
	if finishing: return
	if mode=="paused" and ssrg_failed:return
	# Song sync has no pause menu: BACK leaves it without saving.
	if song_sync and song_sync.active and mode=="play": song_sync.finish(false); return
	if mode in ["play","record"]:
		resume_countdown=0
		if ssrg_playable_run and mode=="play" and song_time>=0 and countdown<=0 and gameplay_start_lead<=0:
			ssrg_resume_position=clampf(song_time-effective_timing_ms()/1000.0,0,maxf(0,length()-.02))
		if mode=="record": recorder.seal_gestures(); commit_take_history()
		paused_mode=mode; pause_had_audio=audio.playing; audio.stream_paused=true; pointers.clear(); capture.gestures.clear()
		ssrg_touch_router.reset()
		ssrg_contact_ids.clear()
		for entry in live:
			if entry.started and not entry.done: entry.pointer=-999
		set_mode("paused",animate_transition); modal_title.text="Paused"; modal_body.text=""; primary.text="RESUME"
		if paused_mode=="record": primary.text="RESUME REC"; pause_restart.text="RETRY TAKE"; pause_home.text="REVIEW TAKE"
		if pause_tween and pause_tween.is_running(): pause_tween.kill()
		modal.pivot_offset=modal.size*.5; modal.scale=Vector2(.86,.86); modal.modulate.a=0
		pause_backdrop.modulate.a=1
		pause_tween=create_tween().set_parallel(true)
		pause_tween.tween_property(modal,"scale",Vector2.ONE,.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pause_tween.tween_property(modal,"modulate:a",1.0,.18)
	elif mode=="paused":
		refresh_output_latency()
		if pause_tween and pause_tween.is_running(): pause_tween.kill()
		if paused_mode=="record" and arranging:
			set_mode("record"); modal.scale=Vector2.ONE; modal.modulate.a=1; return
		if paused_mode=="record":
			begin_resume_lead()
			start_position=clampf(song_time-effective_timing_ms()/1000.0,0,maxf(0,length()-.02))
			audio.stop()
		resume_start_audio=not pause_had_audio
		if paused_mode=="record": resume_start_audio=true
		countdown=0; resume_countdown=3.0; judgement=""; flash=0
		set_mode(paused_mode)
		modal.scale=Vector2.ONE; modal.modulate.a=1

func toggle_arrange() -> void :
	if mode != "record": return
	arrange_preview.stop();recorder_beam_touches.clear()
	arranging = not arranging;arrange_touches.clear();arrange_selection.clear();capture.gestures.clear()
	arrange_button.text = "RECORD" if arranging else "CORRECT"
	refresh_correct_view()
	refresh_arrange_controls()
	if arranging:
		countdown = 0;audio.stream_paused = true
	else:
		# Pick up where the corrections left off, not at the end of the recorded notes.
		recorder_seek_target = maxf(0.0, song_time)
		begin_resume_lead()
		var playback_time = clampf(song_time - effective_timing_ms() / 1000.0, 0, maxf(0, length() - 0.02))
		if audio.playing: audio.seek(playback_time);audio.stream_paused = false
		else: audio.play(playback_time)

# Swaps between the SKD recording surface and the even Correct-mode view.
func refresh_correct_view() -> void:
	if field == null or field.world == null: return
	field.sync_projection_style(); field.world.apply_camera(); field.world.refresh_highway_look()

func refresh_arrange_controls() -> void :
	kind_buttons[0].text = "DELETE" if arranging else "ALL"
	var kinds = ["all", "tap", "hold", "slide", "flick"]
	for i in kind_buttons.size(): kind_buttons[i].set_selected( not arranging and (record_types.size()==4 if i==0 else kinds[i] in record_types))
	for kind_button in kind_buttons: kind_button.disabled = arranging and arrange_selection.is_empty()
	if not arranging and recorder.current_pass() != "all": kind_buttons[0].disabled = true
	for i in range(1, kind_buttons.size()):
		if kinds[i] in recorder.locks() or (recorder.current_pass() != "all" and kinds[i] != recorder.current_pass()): kind_buttons[i].disabled = true
	dots_button.visible = arranging
	if text_slides_button: text_slides_button.text = "SHAPE" if shapeable_selection() else "TEXT"
	if shape_picker and not shapeable_selection(): close_shape_picker()
	ghost_button.visible = not arranging;ghost_button.set_selected(ghost_recording)
	dots_button.text = "●  CONNECTOR: ON" if dots_mode else "●  CONNECTOR: OFF"
	dots_button.set_selected(dots_mode)
	# One short line for what you can do right now.
	if arranging and note_arranger and note_arranger.edit_mode == "draw" and not arrange_selection.is_empty():
		record_help.text = "Trace the slide with one finger, then lift to apply."
	elif arranging and dots_mode:
		var dots_note: Dictionary = arrange_selection.get("note", {})
		if dots_note.is_empty() or dots_note.kind not in ["hold", "slide"]: record_help.text = "Select a hold or slide, then tap its trail to add a connector."
		else: record_help.text = "Tap the trail to add or remove a connector (%d now)." % dots_note.get("checkpoints", []).size()
	elif arranging and correct_bar and correct_bar.copy_help() != "":
		record_help.text = correct_bar.copy_help()
	elif arranging:
		if arrange_selection.is_empty():
			var copied = correct_bar.clipboard.size() if correct_bar else 0
			record_help.text = "%d note%s copied. Scroll to a new place and tap Paste here." % [copied, "" if copied == 1 else "s"] if copied > 0 else "Tap a note to select it. Drag empty space to scroll."
		else:
			var n: Dictionary = arrange_selection.note
			if n.kind in ["hold", "slide"]:
				var how = "Drag to move it." if note_arranger and note_arranger.edit_mode == "move" else "Drag the trail to bend or stretch it."
				record_help.text = "%s, %.2f–%.2f s. %s" % [str(n.kind).capitalize(), float(n.time), float(n.time) + float(n.duration), how]
			else: record_help.text = "%s, lane %d, %.2f s. Drag to move it." % [str(n.kind).capitalize(), int(n.lane) + 1, float(n.time)]
	else:
		record_help.text = "Detecting %s · tap or swipe on the 13 lanes; each gesture becomes the matching note." % ", ".join(record_types.map(func(kind):return str(kind)))

func select_all_record_types() -> void:
	record_types=["tap","hold","slide","flick"].filter(func(kind):return kind not in recorder.locks())
	if record_types.is_empty():return
	tool=recorder.capture_tool();judgement="ALL TYPES";flash=1;refresh_arrange_controls()
func toggle_record_type(kind:String) -> void:
	if kind in recorder.locks():return
	if kind in record_types:
		if record_types.size()<=1:return
		record_types.erase(kind)
	else:record_types.append(kind)
	tool=recorder.capture_tool();judgement="DETECT %s" % ", ".join(record_types.map(func(value):return str(value).to_upper()))
	flash=1;refresh_arrange_controls()

func toggle_ghost_recording() -> void :
	ghost_recording = not ghost_recording
	ghost_button.text = "GHOST ON" if ghost_recording else "GHOST OFF"
	prefs.set_value("editor", "ghost_recording", ghost_recording);prefs.save("user://preferences.cfg")
	refresh_arrange_controls()

func undo_record_note() -> void :
	commit_take_history()
	if take_undo.is_empty(): return
	take_redo.append(take_state);restore_take(take_undo.pop_back())
	judgement = "UNDO";flash = 1

func delete_arrange_note() -> void :
	if not arranging or arrange_selection.is_empty(): return
	if arrange_selection.note.kind in recorder.locks(): return
	var index = int(arrange_selection.index)
	if arrange_selection.document:
		document.selected = index
		document.delete()
	elif index >= 0 and index < capture.notes.size(): capture.notes.remove_at(index)
	arrange_selection.clear();arrange_touches.clear()
	refresh_arrange_controls();commit_take_history()

func change_arrange_note_type(kind: String) -> void :
	if not arranging or arrange_selection.is_empty() or kind not in SynkChart.TYPES: return
	var n: Dictionary = arrange_selection.note
	if n.kind in recorder.locks() or kind in recorder.locks() or (recorder.current_pass() != "all" and kind != recorder.current_pass()): return
	if n.kind == kind: return
	if arrange_selection.document:
		document.selected = int(arrange_selection.index)
		document.convert(kind, 60.0 / float(chart_bpm()), length())
	else:
		n.kind = kind
		if kind in ["tap", "flick"]:
			n.duration = 0.0;n.path = [];n.end_lane = n.lane;n.erase("checkpoints")
		else:
			n.duration = maxf(0.04, float(n.duration) if float(n.duration) > 0 else 60.0 / float(chart_bpm()))
			if kind == "hold": n.path = [];n.end_lane = n.lane
		n.time = clampf(float(n.time), 0, maxf(0, length() - float(n.duration)))
		if kind == "flick" and int(n.direction) == 2: n.direction = 0
	refresh_arrange_controls();commit_take_history()

func stage_time_at(p: Vector2) -> float:
	var point=p*Vector2(field.viewport.size)
	var origin=field.world.camera.project_ray_origin(point)
	var direction=field.world.camera.project_ray_normal(point)
	var hit=Plane(Vector3.UP,0).intersects_ray(origin,direction)
	if hit!=null: hit=field.world.unwarp_point(hit)
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

func toggle_dots_mode() -> void :
	dots_mode = not dots_mode
	refresh_arrange_controls()

func toggle_checkpoint(n: Dictionary, at: float, in_document: bool) -> bool:
	# Adds a dot at this time on the trail, or removes the dot already there.
	var offset=at-float(n.time)
	if n.kind not in ["hold","slide"] or offset<=.02 or offset>=float(n.duration)-.02: return false
	if in_document: document.checkpoint()
	var checks: Array=n.get("checkpoints",[]).duplicate()
	for i in checks.size():
		# Only a tap right on an existing connector removes it; anywhere else adds one.
		if absf(float(checks[i])-offset)<.03:
			var removed_offset=float(checks[i])
			checks.remove_at(i)
			if checks.is_empty(): n.erase("checkpoints")
			else: n.checkpoints=checks
			if n.kind=="slide":
				for point_index in range(1,n.path.size()-1):
					if absf(float(n.path[point_index].offset)-removed_offset)>.01: continue
					var before:Dictionary=n.path[point_index-1];var point:Dictionary=n.path[point_index];var after:Dictionary=n.path[point_index+1]
					var fraction=(float(point.offset)-float(before.offset))/maxf(.001,float(after.offset)-float(before.offset))
					if absf(float(point.lane)-lerpf(float(before.lane),float(after.lane),fraction))<.02:
						n.path.remove_at(point_index)
					break
			return true
	checks.append(snappedf(offset,.001)); checks.sort()
	n.checkpoints=checks
	if n.kind=="slide" and n.path.size()>=2:
		var exists=false
		for point in n.path:
			if absf(float(point.offset)-offset)<.01: exists=true;break
		if not exists:
			var index=n.path.size()
			for i in n.path.size():
				if float(n.path[i].offset)>offset:index=i;break
			n.path.insert(index,{"offset":snappedf(offset,.001),"lane":SynkChart.lane_at(n,at)})
	return true

func add_point_at(p: Vector2) -> void :
	var selected_note: Dictionary = arrange_selection.note
	# Measure the tap where it lands on the trail itself (any depth on the highway),
	# not projected onto the lane pad, so far parts of a slide accept connectors too.
	var lane = arrange_lane_at(p)
	var at = stage_time_at(p)
	var snapped = snap_slide_time(at)
	var offset = snapped - float(selected_note.time)
	if offset > .02 and offset < float(selected_note.duration) - .02: at = snapped
	if absf(lane - SynkChart.lane_at(selected_note, at)) <= 2.0 and toggle_checkpoint(selected_note, at, bool(arrange_selection.document)):
		if arrange_selection.document: document.dirty = true
	refresh_arrange_controls();commit_take_history()

func arrange_lane_at(p: Vector2) -> float:
	var world=field.world; var point=p*Vector2(field.viewport.size)
	var hit=Plane(Vector3.UP,world.trail_height()).intersects_ray(world.camera.project_ray_origin(point),world.camera.project_ray_normal(point))
	# Undo the SKD projection, then use the surface's own lane spacing.
	return world.world_lane(world.unwarp_point(hit).x) if hit!=null else world.CENTER_LANE

# Distance between two normalised screen points, in screen heights. Plain normalised
# distance undercounts sideways gaps on a wide screen, so a neighbour in the next lane
# could win over the note under the finger.
func arrange_screen_gap(a: Vector2, b: Vector2) -> float:
	var size = Vector2(field.viewport.size)
	return ((a - b) * Vector2(size.x / maxf(1.0, size.y), 1.0)).length()

# Seconds to scroll for a drag of dy (normalised screen height), so notes follow the finger.
func arrange_scroll_seconds(dy: float) -> float:
	var world = field.world; var height = maxf(1.0, float(field.viewport.size.y))
	var near = world.camera.unproject_position(world.warp_point(Vector3.ZERO)).y
	var far = world.camera.unproject_position(world.warp_point(Vector3(0, 0, -world.TRACK_LENGTH))).y
	var span = absf(near - far) / height
	return dy * note_travel_seconds() / span if span > .05 else dy * note_travel_seconds() * 1.3

func arrange_note_distance(n: Dictionary, p: Vector2) -> float:
	var start = float(n.time); var finish = start + float(n.duration)
	if start > song_time or song_time - finish > note_travel_seconds(): return INF
	var world = field.world; var camera = world.camera; var viewport_size = Vector2(field.viewport.size)
	var origin = Vector3(0, 0, (start - song_time) * world.travel_speed())
	var best = INF
	if song_time - start <= note_travel_seconds():
		var head = Vector3(world.note_x(float(n.lane)), 0.2, origin.z)
		if world.depth_visible(head.z) and not camera.is_position_behind(head): best = arrange_screen_gap(p, camera.unproject_position(world.warp_point(head)) / viewport_size)
	if n.kind not in ["hold", "slide"] or float(n.duration) <= 0: return best

	var centers = world.trail_centers(n, clampi(ceili(float(n.duration) * 32), 16, 256), true)
	var sides = world.trail_sides(centers)
	var half_width = world.TRAIL_HALF * 0.65
	var pointer = p * viewport_size
	for i in centers.size() - 1:
		var a: Vector3 = centers[i] + origin; var b: Vector3 = centers[i + 1] + origin
		if not world.depth_visible(maxf(a.z, b.z)) or minf(a.z, b.z) > world.JUDGMENT_DEPTH: continue
		if camera.is_position_behind(a) or camera.is_position_behind(b): continue
		# Measure on screen where the SKD projection actually draws the ribbon.
		var screen_a = camera.unproject_position(world.warp_point(a)); var screen_b = camera.unproject_position(world.warp_point(b))
		var polygon = PackedVector2Array([camera.unproject_position(world.warp_point(a - sides[i] * half_width)), camera.unproject_position(world.warp_point(b - sides[i + 1] * half_width)), camera.unproject_position(world.warp_point(b + sides[i + 1] * half_width)), camera.unproject_position(world.warp_point(a + sides[i] * half_width))])
		var distance = pointer.distance_to(Geometry2D.get_closest_point_to_segment(pointer, screen_a, screen_b))
		var inside = Geometry2D.is_point_in_polygon(pointer, polygon)
		var edge_distance = INF
		for edge in 4: edge_distance = minf(edge_distance, pointer.distance_to(Geometry2D.get_closest_point_to_segment(pointer, polygon[edge], polygon[(edge + 1) % 4])))
		if inside or edge_distance <= 12: best = minf(best, minf(0.085, distance / viewport_size.y))
	if trail_style == "solid":
		var hit = Plane(Vector3.UP, world.trail_height() + 0.015).intersects_ray(camera.project_ray_origin(pointer), camera.project_ray_normal(pointer))
		if hit != null:
			hit = world.unwarp_point(hit)
			for offset in world.solid_trail_offsets(n):
				var center = Vector3(world.note_x(SynkChart.lane_at(n, start + offset)), world.trail_height() + 0.015, (start + offset - song_time) * world.travel_speed())
				if camera.is_position_behind(center) or not world.depth_visible(center.z) or center.z > world.JUDGMENT_DEPTH: continue
				if Vector2(hit.x - center.x, hit.z - center.z).length() <= half_width * 1.5:
					best = minf(best, minf(0.085, arrange_screen_gap(p, camera.unproject_position(world.warp_point(center)) / viewport_size)))
	return best

func arrange_pointer_event(id: int, p: Vector2, began: bool, ended: bool, canceled: bool) -> void :
	if note_arranger and note_arranger.handle_event(id, p, began, ended, canceled): return


	var points_note: Dictionary = arrange_selection.get("note", {})
	if began and dots_mode and not points_note.is_empty() and points_note.kind in ["hold", "slide"]:
		arrange_touches[id] = {"kind": "points", "start_p": p, "start_y": p.y, "start_time": song_time, "moved": false}
		return
	if arrange_touches.has(id) and arrange_touches[id].kind == "points":
		var points_touch: Dictionary = arrange_touches[id]
		if not points_touch.moved and p.distance_to(points_touch.start_p) > 0.03: points_touch.moved = true
		if points_touch.moved:
			song_time = clampf(float(points_touch.start_time) + arrange_scroll_seconds(float(points_touch.start_y) - p.y), 0, length())
		if ended and not canceled and not points_touch.moved and not outside_highway(p): add_point_at(p)
		if ended or canceled: arrange_touches.erase(id)
		return
	if began:
		if outside_highway(p):

			arrange_touches[id] = {"kind": "scroll", "start_y": p.y, "start_time": song_time}
			return
		var selected: Dictionary = {}
		var closest = 0.09
		var sources = [capture.notes, document.notes]
		for source_index in sources.size():
			var source: Array = sources[source_index]
			for note_index in source.size():
				var n: Dictionary = source[note_index]
				if n.kind in recorder.locks(): continue
				var distance = arrange_note_distance(n, p)
				if distance < closest: closest = distance;selected = {"note": n, "document": source_index == 1, "index": note_index}
		# Dragging empty highway scrolls the take and keeps the selection, so a long slide
		# can be followed while it is edited; a plain tap on empty highway deselects.
		if selected.is_empty(): arrange_touches[id] = {"kind": "scroll", "start_y": p.y, "start_time": song_time, "start_p": p, "tap_clears": true}
		else:
			arrange_selection = selected
			refresh_arrange_controls()
			arrange_touches[id] = {"kind": "note", "note": selected.note, "document": selected.document, "changed": false, "start_time": float(selected.note.time), "start_lane": int(selected.note.lane), "touch_time": stage_time_at(p), "touch_lane": arrange_lane_at(p), "start_p": p, "gesture": ""}
	if canceled or ended:
		var finished: Dictionary = arrange_touches.get(id, {})
		if ended and not canceled and finished.get("tap_clears", false) and p.distance_to(finished.start_p) < 0.012 and not arrange_selection.is_empty():
			arrange_selection.clear();refresh_arrange_controls()
		arrange_touches.erase(id);commit_take_history();return
	if not arrange_touches.has(id): return
	var touch: Dictionary = arrange_touches[id]
	if touch.kind == "scroll":
		song_time = clampf(float(touch.start_time) + arrange_scroll_seconds(float(touch.start_y) - p.y), 0, length())
	elif touch.kind == "note":
		var n: Dictionary = touch.note


		if touch.gesture == "":
			var delta: Vector2 = p - touch.start_p
			if delta.length() < 0.012: return
			var offset = float(touch.touch_time) - float(n.time)
			var on_trail = n.kind in ["hold", "slide"] and offset > 0.06 and offset < float(n.duration) - 0.06
			var bend_allowed = (n.kind == "slide" or ("slide" not in recorder.locks() and recorder.current_pass() in ["all", "slide"])) and (note_arranger == null or note_arranger.edit_mode != "move")
			touch.gesture = "bend" if on_trail and bend_allowed else "move"
			if touch.gesture == "bend": begin_trail_bend(touch, n, minf(offset, float(n.duration)))
		if touch.gesture == "bend":
			var lane = clampf(float(touch.bend_lane) + arrange_lane_at(p) - float(touch.touch_lane), 0, SynkChart.MAX_LANE)
			var point: Dictionary = n.path[int(touch.bend_index)]
			point.lane = snap_slide_lane(lane)
			var old_offset=float(point.offset)
			var bend_index=int(touch.bend_index)
			var raw_offset=float(touch.bend_offset)+stage_time_at(p)-float(touch.touch_time)
			raw_offset=snap_slide_time(float(n.time)+raw_offset)-float(n.time)
			point.offset=clampf(raw_offset,float(n.path[bend_index-1].offset)+.005,float(n.path[bend_index+1].offset)-.005)
			SynkChart.sync_connectors(n)
			refresh_arrange_controls();return
		var target_time = stage_time_at(p) - float(touch.touch_time) + float(touch.start_time)

		if absf(target_time - float(touch.start_time)) > 0.001:
			target_time = snap_recorder_move(target_time, minf(song_time, maxf(0, length() - float(n.duration))), n)
		var lane_delta = clampi(roundi(arrange_lane_at(p) - float(touch.touch_lane)), - SynkChart.MAX_LANE, SynkChart.MAX_LANE)
		var new_lane = clampi(int(touch.start_lane) + lane_delta, 0, SynkChart.MAX_LANE)
		if not touch.changed and (absf(float(n.time) - target_time) > 0.001 or int(n.lane) != new_lane):
			if touch.document: document.checkpoint()
			touch.changed = true
		# A take note dragged out of the punch range would be dropped when the take is stopped.
		var earliest = recorder.region.x if recorder.active and not touch.document else 0.0
		n.time = clampf(target_time, earliest, maxf(earliest, minf(song_time, maxf(0, length() - float(n.duration)))))
		var change = new_lane - int(n.lane)
		n.lane = new_lane;n.end_lane = clampi(int(n.end_lane) + change, 0, SynkChart.MAX_LANE)
		for point in n.path: point.lane = clampf(float(point.lane) + change, 0, SynkChart.MAX_LANE)
		if touch.changed: refresh_arrange_controls()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_RESUMED and OS.get_name()=="iOS": NativeFilePicker.defer_system_gestures()
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		if features and mode=="editor": features.autosave()
		if mode in ["play","record"]: toggle_pause(false)
		elif mode=="editor" and audio!=null: stop_audition()
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if document.dirty: set_mode("editor"); tell("Save your draft or RELOAD to discard edits before closing.")
		else: get_tree().quit()

func _process(delta: float) -> void:
	if mode=="record" and not arranging and ready_point>=0 and countdown<=0 and resume_countdown<=0:
		var remaining=ready_point-song_time
		if remaining>0: judgement="CHART ENDS IN %.1f s" % remaining; flash=1
		else: ready_point=-1; judgement="EMPTY CHART · RECORD"; flash=1
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
				if ssrg_playable_run and ssrg_resume_position>=0:
					audio.play(ssrg_resume_position);ssrg_resume_position=-1.0
					visual_clock_ready=false
				elif resume_start_audio and not (mode=="play" and gameplay_start_lead>0): audio.play(start_position)
				UiSound.play(self,"go")
				audio.stream_paused=false; resume_grace=.35
		elif countdown>0:
			countdown=maxf(0,countdown-delta); song_time=start_position-countdown-(gameplay_start_lead if mode=="play" else 0.0)
			visual_song_time=song_time; visual_clock_ready=false
			judgement="READY "+str(ceili(countdown)); flash=1
			if countdown==0:
				audio.stream_paused=false
				if mode!="play" or gameplay_start_lead<=0:audio.play(start_position)
				UiSound.play(self,"go")
				if extras and mode=="play": extras.on_song_start()
		elif mode=="play" and gameplay_start_lead>0:
			gameplay_start_lead=maxf(0,gameplay_start_lead-delta)
			song_time=start_position-gameplay_start_lead
			# Start the music early by the device's output delay, from the matching point, so
			# the first heard sample lands exactly as the silent approach ends. Starting it at
			# the end instead leaves the audio clock behind the notes, and they would stop
			# for that delay (about 0.15 s on iPhone) before moving on with the music.
			var head=output_latency()
			if not audio.playing and head>0 and gameplay_start_lead<=head:
				audio.stream_paused=false;audio.play(maxf(0,start_position+head-gameplay_start_lead))
			smooth_visual_time(song_time,delta)
			if auto_play:update_autoplay()
			else:update_game()
			if gameplay_start_lead==0:
				if not audio.playing:audio.stream_paused=false;audio.play(start_position)
				audio_handoff=1.0
		else:
			var heard=chart_time()
			if mode=="play" and audio_handoff>0 and heard<song_time:
				# The music has started but still reports a slightly earlier spot (device output
				# delay). Keep the notes moving, a little slower, until it catches up, instead
				# of freezing them in place.
				audio_handoff=maxf(0,audio_handoff-delta)
				song_time+=maxf(0,delta)*maxf(0,audio.pitch_scale)*.6
			else:
				audio_handoff=0.0
				song_time=maxf(song_time,heard)
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
	if mode=="paused" and ssrg_failed:
		# A failed run cannot be resumed: only Retry and Song list, side by side.
		primary.visible=false
		pause_restart.text="RETRY"; pause_home.text="SONG LIST"
		pause_restart.anchor_left=.06; pause_restart.anchor_right=.49
		pause_home.anchor_left=.51; pause_home.anchor_right=.94
	elif mode=="paused":
		primary.visible=true
		pause_restart.anchor_left=.36; pause_restart.anchor_right=.64
		pause_home.anchor_left=.66; pause_home.anchor_right=.94
		pause_home.text="REVIEW TAKE" if paused_mode=="record" else ("EDITOR" if practice.active else "HOME")
		pause_restart.text="RETRY TAKE" if paused_mode=="record" else "RESTART"
		primary.text="RESUME REC" if paused_mode=="record" else "RESUME"
	var active_hold=mode=="play" and not counting and has_active_hold()
	hold_pulse_time=hold_pulse_time+delta if active_hold else 0.0
	var hold_pulse=(0.5+0.5*sin(hold_pulse_time*TAU*2.0))*.55 if active_hold else 0.0
	var displayed_pulse=maxf(combo_pulse,hold_pulse)
	align_gameplay_hud()
	combo_hud.pivot_offset=combo_hud.size*.5
	combo_hud.scale=Vector2.ONE
	combo_hud.modulate=Color.WHITE.lerp(Color("fff0ff"),displayed_pulse)
	combo_glow.set_shader_parameter("boost",displayed_pulse)
	countdown_label.visible=counting and not intro_running
	countdown_ring.visible=false  # no ring around the countdown
	if countdown_label.visible:
		var number=ceili(resume_countdown if resume_countdown>0 else countdown)
		if number!=countdown_shown and number>0: countdown_shown=number; UiSound.play(self,"count")
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
	# SSRG Playables show their own centre judgement and combo (ssrg_judgement.gd).
	combo_hud.visible=mode in ["play","paused"] and not counting and combo>0 and not finishing and not uses_ssrg_gameplay()
	hit_label.visible=mode in ["play","record"] and not counting and not uses_ssrg_gameplay()
	if mode=="editor" and audio.playing:
		cursor=clampf(chart_time(),0,length())
		if not recorder.reviewing_audio and loop_enabled and loop_b>loop_a+.1 and cursor>=loop_b: audio.play(loop_a); cursor=loop_a
		refresh_editor()
	if mode=="play":
		displayed_score=lerpf(displayed_score,float(score),clampf(delta*11.0,0,1))
		if absf(displayed_score-score)<1.0: displayed_score=score
	hud.text=format_score(roundi(displayed_score))
	# The score counter glows gold while a combo multiplier is active, brighter as it climbs.
	var boost=clampf((combo_multiplier()-1.0)/1.0,0.0,1.0) if mode in ["play","paused"] else 0.0
	var score_color=Color.WHITE.lerp(Color("ffd257"),.35+.65*boost) if boost>0 else Color.WHITE
	if hud.get_theme_color("font_color")!=score_color:hud.add_theme_color_override("font_color",score_color)
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
	var note_word="note" if capture.notes.size()==1 else "notes"
	record_info.text=("Paused · correcting  %.1f s\n%d %s" if arranging else "●  Recording  %.1f s\n%d %s · %s") % ([maxf(0,song_time),capture.notes.size(),note_word] if arranging else [maxf(0,song_time),capture.notes.size(),note_word,tool.capitalize()])
	update_recorder_focus()
	if mode=="record" and recorder.active:
		if song_time<recorder.region.x and countdown==0: record_info.text="Pre-roll · listen\nRecording starts at %.2f s" % recorder.region.x
		elif recorder.looping(): record_info.text+=" · Take %d" % (recorder.takes.size()+1)
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
	hit_label.visible=(mode=="record" or play_judgement) and not counting and not uses_ssrg_gameplay()
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
		if ssrg_failed:break
		var entry: Dictionary=live[live_index]
		if float(entry.note.time)>song_time+.23: break
		if entry.done or not entry.started or entry.note.kind!="hold": continue
		if auto_play or pointers.has(entry.pointer): return true
	return false

func align_gameplay_hud() -> void:
	var screen_center=field.get_global_transform_with_canvas()*field.project(field.world.CENTER_LANE,0)
	var center_x=(ui.get_global_transform_with_canvas().affine_inverse()*screen_center).x
	for element in [hit_art,hit_label]:
		element.position.x=center_x-element.size.x*.5
	var highway_center=field.get_global_transform_with_canvas()*((field.project(field.world.CENTER_LANE,0)+field.project(field.world.CENTER_LANE,1))*.5)
	var countdown_center=ui.get_global_transform_with_canvas().affine_inverse()*highway_center
	for element in [countdown_label,countdown_ring]:
		element.position=countdown_center-element.size*.5

# The live combo display (scripts/combo_view.gd): punches on every hit, glows in its tier
# colour, and fills a bar toward the next milestone.
var combo_view: Control
var multiplier_step=0
func update_combo_art() -> void:
	# Each new score multiplier step (every 100 combo, up to x2.0) also lights up the highway.
	var step=0 if ssrg_playable_run else mini(10,floori(combo/100.0))
	if step>multiplier_step and mode=="play":
		field.world.multiplier_wave(); UiSound.play(self,"bonus")
	multiplier_step=step
	combo_art_value=combo; combo_art_size=combo_hud.size
	if combo_view==null:
		for child in combo_hud.get_children(): child.queue_free()
		combo_view=preload("res://scripts/combo_view.gd").new(); combo_view.name="ComboView"
		combo_hud.add_child(combo_view); combo_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combo_view.multiplier_enabled=not ssrg_playable_run
	combo_view.set_combo(combo)

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
		if menu_settings_open and settings_panel.visible: close_lobby_settings()
		elif mode=="menu" and ssrg_playables.visible:ssrg_playables.back()
		elif mode=="menu" and sync_helper.visible: sync_helper.close()
		elif mode=="menu" and menu_settings_open: close_lobby_settings()
		elif mode=="guide": set_mode("menu")
		elif song_details.visible: close_song_details()
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
	var input_time=chart_time() if mode=="play" and audio.playing and not audio.stream_paused and not from_replay else song_time
	if ssrg_playable_run:input_time=ssrg_touch_time(input_time)
	if extras and not from_replay: extras.record_input(id,p,began,ended,canceled,input_time if ssrg_playable_run else song_time)
	if mode=="record" and arranging:
		arrange_pointer_event(id,p,began,ended,canceled)
		if ended or canceled:
			if arrange_touches.is_empty(): arrange_preview.stop()
		elif arrange_touches.has(id):
			var touch: Dictionary=arrange_touches[id]
			if touch.kind!="handle":
				var preview_at=song_time
				if touch.kind=="note": preview_at=float(touch.note.time)+clampf(float(touch.touch_time)-float(touch.start_time),0,float(touch.note.duration))
				arrange_preview.request(preview_at)
		return
	var touch_world=field.touch_world_position(p)
	p = field.input_position(p)
	if mode=="record":
		if not recorder.can_capture(song_time): return
		if began:
			capture.minimum_lane_gap=chord_lane_gap()
			capture.onset_bounds=recorder.region
			capture.begin(id,song_time,p,recorder.capture_tool(),recorder.spacing_blockers(),recorder.allowed_types())
		capture.move(id,song_time,p)
		if ended:
			var n=capture.end(id,song_time,p,canceled)
			if not n.is_empty() and not recorder.writable(n): capture.notes.erase(n); return
			if not n.is_empty():
				commit_take_history()
				judgement=n.kind.to_upper()+" RECORDED"; flash=1; flash_lane=int(n.end_lane)
				if not capture.last_spacing_resolved: tell("This chord is too crowded to separate. Move a note or reduce its size.")
		return
	if ssrg_playable_run:
		var physical_id=id
		if began:
			var previous=int(ssrg_contact_ids.get(physical_id,physical_id))
			if pointers.has(previous) and not pointers[previous].get("ssrg_ended",false):
				pointers[previous].ssrg_phase=4;pointers[previous].ssrg_ended=true;pointers[previous].ssrg_canceled=true
			# Keep a queued release alive when Android reuses its finger index
			# for another press before the next gameplay update.
			if pointers.has(id):
				ssrg_contact_serial+=1;id=ssrg_contact_serial
				while pointers.has(id):ssrg_contact_serial+=1;id=ssrg_contact_serial
			ssrg_contact_ids[physical_id]=id
		else:id=int(ssrg_contact_ids.get(physical_id,physical_id))
		if began:
			ssrg_contact_serial+=1
			pointers[id]={"start":p,"position":p,"world":touch_world,"ssrg_pending_begin":true,"ssrg_press_time":input_time,"ssrg_begin_world":touch_world,"ssrg_identity":ssrg_contact_serial}
		if pointers.has(id):
			pointers[id].position=p;pointers[id].world=touch_world
			pointers[id].ssrg_event_time=input_time
			pointers[id].ssrg_phase=4 if canceled else (0 if pointers[id].get("ssrg_pending_begin",false) else (3 if ended else 1))
			pointers[id].ssrg_ended=ended or canceled
			pointers[id].ssrg_canceled=canceled
		if ended or canceled:ssrg_contact_ids.erase(physical_id)
		# Judge the complete touch batch in the gameplay update, not halfway
		# through two crossing fingers' movement events.
		return
	if began:
		pointers[id]={"start":p,"position":p,"world":touch_world}
		# Taps anywhere on the lower highway count; the grade comes only from timing at the judgement bar.
		if ssrg_playable_run or p.y>=.35:
			var nearest: Dictionary={}; var best=(SsrgRules.good_window()+.001 if ssrg_playable_run else .231); var best_gap=INF
			# Where the finger is across the judgement bar, in world units: notes are hit by touching
			# the note itself (its drawn width), whatever lane it is in.
			var world=field.world; var touch_x=world.lane_world_x(SynkCapture.lane(p.x)); var reach=world.note_reach()
			for live_index in range(first_live_index(),live.size()):
				var entry: Dictionary=live[live_index]
				if float(entry.note.time)>song_time+(SsrgRules.good_window() if ssrg_playable_run else .23): break
				if entry.done: continue
				var n: Dictionary=entry.note
				if entry.started:
					if not ssrg_playable_run and entry.pointer==-999 and absf(touch_x-world.note_x(SynkChart.lane_at(n,song_time)))<=reach: entry.pointer=id
					continue
				var error=absf(song_time-float(n.time))
				var timing_limit=hit_good_window(str(n.kind))
				var gap=absf(touch_x-world.note_x(float(n.lane)))
				var touching=ssrg_touch_lane(touch_world,float(n.lane)) if ssrg_playable_run else gap<=reach*(1.4 if n.kind=="slide" else 1.0)
				if not touching or error>timing_limit: continue
				# Best timing wins; between notes timed alike (a chord), the one under the finger.
				if error<best-.001 or (absf(error-best)<=.001 and gap<best_gap): best=error; best_gap=gap; nearest=entry
			if nearest.is_empty() and not ssrg_playable_run and bool(extras.settings.touch_assist):
				# Touch assist: accept a touch a little beyond the note's edge when nothing else is hit.
				for live_index in range(first_live_index(),live.size()):
					var entry: Dictionary=live[live_index]
					if float(entry.note.time)>song_time+.23: break
					if entry.done or entry.started: continue
					var n: Dictionary=entry.note
					var error=absf(song_time-float(n.time))
					if error<=minf(best,extras.good_window()) and absf(touch_x-world.note_x(float(n.lane)))<=reach*1.6: best=error; nearest=entry
			if not nearest.is_empty():
				nearest.started=true; nearest.pointer=id; nearest.error=best; nearest.timing_error=song_time-float(nearest.note.time)
				if nearest.note.kind=="tap": judge(nearest,best)
				elif nearest.note.kind=="hold": judge(nearest,best,false)
				elif nearest.note.kind=="slide":
					if ssrg_playable_run: judge(nearest,best,false)
					else: field.world.spawn_hit(SynkChart.lane_at(nearest.note,song_time),"slide",0,nearest,id)
	if pointers.has(id):
		pointers[id].position=p; pointers[id].world=touch_world
	if ended:
		# Process final swipe motion before removing the finger.
		update_game()
		for live_index in range(first_live_index(),live.size()):
			var entry: Dictionary=live[live_index]
			if entry.done or entry.pointer!=id or entry.note.kind!="hold": continue
			var hold_end=float(entry.note.time)+float(entry.note.duration)
			# Letting go a little early still completes the hold; the score keeps the head's accuracy.
			var correct_lane=not ssrg_playable_run or ssrg_touch_lane(touch_world,SynkChart.lane_at(entry.note,hold_end))
			judge(entry,tail_error(entry) if not canceled and correct_lane and song_time>=hold_end-tail_grace(entry) else -1)
		for live_index in range(first_live_index(),live.size()):
			var entry: Dictionary=live[live_index]
			if entry.done or entry.pointer!=id or entry.note.kind!="slide": continue
			var end_time=float(entry.note.time)+float(entry.note.duration)
			var lane_error=absf(SynkCapture.lane(p.x)-SynkChart.lane_at(entry.note,end_time))
			var end_lanes=SSRG_SLIDE_END_LANES if ssrg_playable_run else SLIDE_END_LANES
			var end_touch=ssrg_touch_lane(touch_world,SynkChart.lane_at(entry.note,end_time)) if ssrg_playable_run else lane_error<=end_lanes and p.y>=(.25 if uses_ssrg_gameplay() else .4)
			if not canceled and end_touch and song_time>=end_time-tail_grace(entry) and song_time<=end_time+.30:
				judge(entry,absf(song_time-end_time) if ssrg_playable_run else float(entry.error))
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
			elif n.kind=="slide":
				if ssrg_playable_run: judge(entry,0.0,false)
				else: field.world.spawn_hit(SynkChart.lane_at(n,song_time),"slide",0,entry)
			elif n.kind in ["tap","flick"]: judge(entry,0.0)
		if entry.started and not entry.done:
			if ssrg_playable_run and n.kind in ["hold","slide"]:update_ssrg_held_ticks(entry)
			process_checkpoints(entry,0.0,true)
		if entry.started and not entry.done and song_time>=float(n.time)+float(n.duration):
			judge(entry,0.0)

# Hold and slide ends: a release this early still completes the note (20% of its length,
# between 0.2 and 0.45 s), and the end is scored by how well the head was hit, never worse
# than GREAT, so a clean start isn't lost to a slightly early lift.
const SLIDE_END_LANES = 3.5
func tail_grace(entry: Dictionary) -> float:
	if ssrg_playable_run: return SsrgRules.early_release_window()
	return clampf(float(entry.note.duration)*.2,.2,.45)*extras.scale()
func tail_error(entry: Dictionary) -> float:
	if ssrg_playable_run: return absf(song_time-float(entry.note.time)-float(entry.note.duration))
	return minf(float(entry.get("error",0.0)),extras.great_window())

func count_unstarted_tail(entry: Dictionary) -> void:
	if entry.note.kind=="hold" or (ssrg_playable_run and entry.note.kind=="slide"):
		judged+=1
		if ssrg_playable_run:
			judgment_counts.MISS+=1
			performance_samples.append({"time":float(entry.note.time)+float(entry.note.duration),"weight":0.0,"amount":1})

func prepare_ssrg_input() -> void:
	var candidates:Array=[]
	var travel=note_travel_seconds()
	for touch in pointers.values():touch.ssrg_sustain_active=false
	for i in range(first_live_index(),live.size()):
		var entry:Dictionary=live[i]
		if float(entry.note.time)>song_time+SsrgRules.HEAD_WINDOW:break
		if entry.done:continue
		var sustain=bool(entry.started) and entry.note.kind in ["hold","slide"]
		var contact_owner=ssrg_sustain_owner(entry) if sustain else int(entry.pointer)
		if sustain and pointers.has(contact_owner):pointers[contact_owner].ssrg_sustain_active=true
		var next=SsrgSustain.next_node(entry.note,int(entry.get("checks_done",0))) if sustain else {"time":float(entry.note.time),"is_end":false}
		if not sustain and absf(song_time-float(next.time))>SsrgRules.HEAD_WINDOW:
			var pending_press=false
			for touch in pointers.values():
				if touch.get("ssrg_pending_begin",false) and absf(float(touch.ssrg_press_time)-float(next.time))<=SsrgRules.HEAD_WINDOW:pending_press=true;break
			if not pending_press:continue
		var channel=roundi(SynkChart.lane_at(entry.note,float(next.time))*12.0/float(SynkChart.MAX_LANE))
		var geometry=ssrg_touch_router.node_geometry(channel,float(next.time),song_time,travel,sustain)
		geometry.merge({"channel":channel,"at":float(next.time),"travel":travel,"token":str(entry.key)+":"+(str(entry.get("checks_done",0)) if sustain else "head"),"sustain":sustain,"owner":contact_owner,"eligible":absf(song_time-float(next.time))<SsrgRules.MIDDLE_WINDOW})
		candidates.append(geometry)
	for touch in pointers.values():
		var point:Vector3=touch.ssrg_begin_world if touch.get("ssrg_pending_begin",false) and not touch.get("ssrg_canceled",false) else touch.world
		touch.ssrg_ui=Vector2(point.x/field.world.SSRG_UNIT,-point.z/field.world.SSRG_UNIT-234.0)
	ssrg_touch_router.route(pointers,candidates,ssrg_lane_count,Vector2i(Engine.get_process_frames(),roundi(song_time*1000000)))

func ssrg_sustain_owner(entry:Dictionary) -> int:
	var owner=int(entry.get("pointer",-999))
	if pointers.has(owner):return owner
	owner=int(entry.get("sustain_last_pointer",-999))
	if pointers.has(owner) and int(pointers[owner].get("ssrg_identity",0))==int(entry.get("sustain_last_identity",-1)) and not pointers[owner].get("ssrg_ended",false):return owner
	return -999

func remember_ssrg_contact(entry:Dictionary,id:int) -> void:
	if not pointers.has(id):return
	entry.sustain_last_pointer=id
	entry.sustain_last_identity=int(pointers[id].get("ssrg_identity",0))
	entry.ssrg_effect_x=float(pointers[id].world.x)

func update_ssrg_sustain(entry: Dictionary) -> void:
	# The last successful finger controls moving autoaim. The shared channel
	# winner judges nodes, at most once per channel per gameplay frame.
	var next=SsrgSustain.next_node(entry.note,int(entry.get("checks_done",0)))
	var lane=SynkChart.lane_at(entry.note,float(next.time))
	var channel=roundi(lane*12.0/float(SynkChart.MAX_LANE))
	var track=ssrg_touch_router.track(channel)
	var chosen=int(track.pointer)
	var state=int(track.state)
	var owner=int(entry.pointer)
	# Lost deliberately clears the shared track's current owner, as in SSRG.
	# Retain contact identity separately for our existing owned-tail-release path.
	if pointers.has(owner):remember_ssrg_contact(entry,owner)
	var release_owner=owner if pointers.has(owner) else int(entry.get("sustain_last_pointer",-999))
	if pointers.has(release_owner) and int(pointers[release_owner].get("ssrg_identity",0))!=int(entry.get("sustain_last_identity",0)):release_owner=-999
	var own_release=false
	if next.is_end and pointers.has(release_owner):
		var contact:Dictionary=pointers[release_owner]
		if contact.get("ssrg_ended",false):
			entry.ssrg_release_at=float(contact.get("ssrg_event_time",song_time))
			entry.ssrg_release_lane=SynkCapture.lane(contact.position.x)
			entry.ssrg_release_canceled=bool(contact.get("ssrg_canceled",false))
		var aim:Dictionary=contact.get("ssrg_aim",{})
		var aimed_here=int(contact.get("ssrg_channel",-1))==channel and bool(aim.get("sustain",false)) and int(aim.get("owner",-999))==release_owner and str(aim.get("token","")).begins_with(str(entry.key)+":")
		# ContainsTrack already resolved this owned finger through the long-note
		# rectangle. Do not reject that same aim with a narrower raw lane recheck.
		own_release=contact.get("ssrg_ended",false) and not contact.get("ssrg_canceled",false) and (ssrg_touch_lane(contact.world,lane) or aimed_here)
		if own_release:state=SsrgSustain.TrackState.ENDED;chosen=release_owner
	var was_contact=bool(entry.get("ssrg_contact",true))
	entry.ssrg_contact=pointers.has(owner) and not pointers[owner].get("ssrg_ended",false) and (int(pointers[owner].get("ssrg_channel",-1))==channel or ssrg_touch_lane(pointers[owner].world,SynkChart.lane_at(entry.note,song_time)))
	if entry.ssrg_contact and not was_contact:field.world.ssrg_theme.resume_sustain(entry)
	var judged_at=float(pointers[release_owner].ssrg_event_time) if own_release else (float(track.get("event_time",song_time)) if state==SsrgSustain.TrackState.ENDED else song_time)
	var action=SsrgSustain.action(judged_at,float(next.time),bool(next.is_end),state,false,note_travel_seconds(),bool(entry.get("sustain_released",false)),own_release)
	if action=="miss":judge(entry,-1);return
	var gate=str(channel)+":release:"+str(release_owner) if own_release else channel
	if action!="hit" or not ssrg_touch_router.consume(gate):return
	var released=state==SsrgSustain.TrackState.ENDED
	var history=bool(entry.get("sustain_penalty",false))
	var grade=SsrgSustain.node_grade(absf(judged_at-float(next.time)),bool(next.is_end),str(entry.get("sustain_grade","GOOD")),released,history)
	entry.sustain_rate=SsrgSustain.node_rate(float(entry.get("sustain_rate",.1)),released,history)
	if released:entry.sustain_released=true
	entry.pointer=-999 if state==SsrgSustain.TrackState.LOST else chosen
	if pointers.has(chosen):remember_ssrg_contact(entry,chosen)
	if next.is_end:
		judge(entry,absf(judged_at-float(next.time)),true,grade)
		return
	entry.checks_done=int(entry.get("checks_done",0))+1
	pass_checkpoint(entry,lane,absf(song_time-float(next.time)),grade)

func advance_ssrg_sustain(entry:Dictionary) -> void:
	update_ssrg_held_ticks(entry)
	# Source UpdateViewNotes sweeps linked Note objects. A newly eligible next
	# channel can judge in this update; a consumed channel still stops the sweep.
	var remaining=entry.note.get("checkpoints",[]).size()-int(entry.get("checks_done",0))+1
	for step in maxi(1,remaining):
		var previous=int(entry.get("checks_done",0))
		update_ssrg_sustain(entry)
		if entry.done or int(entry.get("checks_done",0))==previous:break
		# Source UpdateViewNotes immediately exposes the next linked node after
		# a successful crossing. Re-route the same physical contacts without
		# clearing this frame's consumed-channel gates.
		prepare_ssrg_input()

func update_ssrg_held_ticks(entry:Dictionary) -> void:
	if entry.note.has("ssrg_special"):return
	var previous=float(entry.get("ssrg_tick_at",song_time))
	entry.ssrg_tick_at=song_time
	var owner=ssrg_sustain_owner(entry)
	if not auto_play:
		if not pointers.has(owner) or pointers[owner].get("ssrg_ended",false):return
		var channel=int(pointers[owner].get("ssrg_channel",-1))
		if channel<0 or ssrg_touch_router.track(channel).state not in [SsrgSustain.TrackState.BEGAN,SsrgSustain.TrackState.MOVED,SsrgSustain.TrackState.HELD]:return
	# Native ComboDivision is seconds-per-beat / 6. Keep fractional credit
	# per chain; these sustain ticks add combo/score, not new judgment grades.
	var division=60.0/maxf(1,chart_bpm())/6.0
	var credit=float(entry.get("ssrg_tick_credit",0.0))+maxf(0,song_time-previous)/division
	if credit<=1.0:entry.ssrg_tick_credit=credit;return
	var count=floori(credit);entry.ssrg_tick_credit=credit-count
	combo+=count;max_combo=maxi(combo,max_combo);combo_pulse=1.0
	for i in count:add_points(str(entry.get("sustain_grade","GOOD")))

func process_ssrg_press_events() -> void:
	var presses:Array=[]
	for id in pointers:
		var touch:Dictionary=pointers[id]
		if touch.get("ssrg_pending_begin",false) and not touch.get("ssrg_canceled",false) and not touch.get("ssrg_head_consumed",false):
			presses.append({"id":id,"at":float(touch.ssrg_press_time),"order":presses.size()})
	presses.sort_custom(func(a,b):return a.at<b.at if a.at!=b.at else a.order<b.order)
	for press in presses:
		var touch:Dictionary=pointers[press.id]
		touch.ssrg_head_consumed=true
		var channel=int(touch.get("ssrg_channel",-1))
		if channel<0:continue
		var best:Dictionary={};var best_error=INF
		for i in range(first_live_index(),live.size()):
			var entry:Dictionary=live[i]
			if float(entry.note.time)>float(press.at)+SsrgRules.HEAD_WINDOW:break
			if entry.done or entry.started or roundi(float(entry.note.lane)*12.0/float(SynkChart.MAX_LANE))!=channel:continue
			var error=absf(float(press.at)-float(entry.note.time))
			if error<=SsrgRules.good_window() and error<best_error:best_error=error;best=entry
		if best.is_empty():continue
		best.started=true;best.pointer=int(press.id);best.error=best_error;best.timing_error=float(press.at)-float(best.note.time)
		ssrg_touch_router.consume(channel)
		# A flick is judged once the finger swipes the arrow's way (update_game), not on the press.
		if best.note.kind=="flick": continue
		judge(best,best_error,best.note.kind not in ["hold","slide"])

func update_game() -> void:
	if ssrg_playable_run:
		prepare_ssrg_input()
		process_ssrg_press_events()
	var head_targets:Dictionary={}
	if ssrg_playable_run:
		# Prefer the note nearest the recorded press, not an older note whose
		# wide late window happens to precede it in a dense section.
		for i in range(first_live_index(),live.size()):
			var candidate:Dictionary=live[i]
			if float(candidate.note.time)>song_time+SsrgRules.HEAD_WINDOW:break
			if candidate.done or candidate.started:continue
			var channel=roundi(float(candidate.note.lane)*12.0/float(SynkChart.MAX_LANE))
			var track=ssrg_touch_router.track(channel)
			var eligible=candidate.note.kind in ["hold","slide"] and track.state==SsrgSustain.TrackState.MOVED
			if not eligible:continue
			var at=float(track.get("event_time",song_time)) if track.state==SsrgSustain.TrackState.BEGAN else song_time
			var error=absf(at-float(candidate.note.time))
			if error>SsrgRules.good_window():continue
			if not head_targets.has(channel) or error<float(head_targets[channel].error):head_targets[channel]={"key":candidate.key,"error":error}
	for i in range(pending_end_hits.size()-1,-1,-1):
		var pending: Dictionary=pending_end_hits[i]
		if song_time<float(pending.at): continue
		field.world.spawn_hit(SynkChart.lane_at(pending.note,float(pending.at)),"slide")
		pending_end_hits.remove_at(i)
	for live_index in range(first_live_index(),live.size()):
		var entry: Dictionary=live[live_index]
		if float(entry.note.time)>song_time+(SsrgRules.good_window() if ssrg_playable_run else .23): break
		if entry.done: continue
		var n: Dictionary=entry.note
		if not entry.started:
			if ssrg_playable_run:
				var channel=roundi(float(n.lane)*12.0/float(SynkChart.MAX_LANE))
				var track=ssrg_touch_router.track(channel)
				var eligible=n.kind in ["hold","slide"] and track.state==SsrgSustain.TrackState.MOVED
				var judged_at=float(track.get("event_time",song_time)) if track.state==SsrgSustain.TrackState.BEGAN else song_time
				var error=absf(judged_at-float(n.time))
				if eligible and error<=SsrgRules.good_window() and head_targets.get(channel,{}).get("key","")==entry.key and ssrg_touch_router.consume(channel):
					entry.started=true;entry.pointer=int(track.pointer);entry.error=error;entry.timing_error=judged_at-float(n.time)
					judge(entry,error,n.kind not in ["hold","slide"])
					continue
			# Android can deliver an on-time touch after the gameplay frame has crossed
			# the note. Keep SKD's grade thresholds, but do not retire an unresolved tap
			# or flick before its complete judgment window has elapsed.
			var auto_miss_delay=SsrgRules.good_window() if ssrg_playable_run and n.kind in ["tap","flick"] else hit_good_window(str(n.kind))
			# Positive touch sync stamps a delayed event earlier. Give the input queue the
			# same allowance so a valid calibrated press cannot lose a race to auto-miss.
			if ssrg_playable_run: auto_miss_delay+=maxf(ssrg_touch_sync_ms,0.0)/1000.0
			if song_time>=float(n.time)+auto_miss_delay:
				judge(entry,-1)
				count_unstarted_tail(entry)
			continue
		if entry.pointer==-999 and resume_grace>0: continue
		if ssrg_playable_run and n.kind in ["hold","slide"]:
			advance_ssrg_sustain(entry);continue
		if not pointers.has(entry.pointer): judge(entry,-1); continue
		var p: Dictionary=pointers[entry.pointer]
		if n.kind=="flick":
			var displacement: Vector2=p.position-p.start
			# Flicks are up-only and must be a hard upward flick: a clear upward move that
			# clearly dominates any sideways motion. A left/right (or shallow diagonal) swipe
			# does not register.
			var up: float = -displacement.y
			if up>.05 and up>absf(displacement.x)*1.8: judge(entry,float(entry.error))
			elif song_time>float(n.time)+(hit_good_window("flick") if ssrg_playable_run else extras.good_window()) or (ssrg_playable_run and p.get("ssrg_ended",false)): judge(entry,-1)
		elif n.kind in ["hold","slide"] and not process_checkpoints(entry,SynkCapture.lane(p.position.x),false):
			continue
		elif n.kind=="slide":
			var end_time=float(n.time)+float(n.duration)
			if song_time>=end_time-(0.0 if ssrg_playable_run else .045):
				var lane_error=absf(SynkCapture.lane(p.position.x)-SynkChart.lane_at(n,end_time))
				var end_lanes=SSRG_SLIDE_END_LANES if ssrg_playable_run else SLIDE_END_LANES
				var end_touch=ssrg_touch_lane(p.world,SynkChart.lane_at(n,end_time)) if ssrg_playable_run else lane_error<=end_lanes and p.position.y>=(.25 if uses_ssrg_gameplay() else .4)
				if end_touch: judge(entry,tail_error(entry))
				elif song_time>end_time+.30: judge(entry,-1)
		elif n.kind=="hold":
			var hold_end=float(n.time)+float(n.duration)
			if song_time>=hold_end-(0.0 if ssrg_playable_run else .045):
				if not ssrg_playable_run or ssrg_touch_lane(p.world,SynkChart.lane_at(n,hold_end)): judge(entry,tail_error(entry))
				elif song_time>hold_end+SsrgRules.good_window():judge(entry,-1)

	if ssrg_playable_run:
		for id in pointers.keys():
			var touch:Dictionary=pointers[id]
			if touch.get("ssrg_ended",false):
				if touch.get("ssrg_pending_begin",false):ssrg_touch_router.parse(int(id),touch,int(touch.get("ssrg_channel",-1)),4 if touch.get("ssrg_canceled",false) else 3)
				for entry in live:
					if not entry.done and entry.get("pointer",-999)==id:entry.pointer=-999;entry.ssrg_contact=false
				pointers.erase(id)
			else:touch.ssrg_phase=2;touch.ssrg_pending_begin=false

func judge(entry: Dictionary,error: float,complete: bool = true,source_grade: String = "",effects:bool = true) -> void:
	var grade=source_grade if not source_grade.is_empty() else (SsrgRules.grade(error) if ssrg_playable_run else ("MISS" if error<0 else ("PERFECT" if error<=extras.perfect_window() else ("GREAT" if error<=extras.great_window() else "GOOD"))))
	if grade=="MISS": error=-1
	if OS.is_debug_build() and ssrg_playable_run and error<0 and entry.note.kind=="slide":
		var next=SsrgSustain.next_node(entry.note,int(entry.get("checks_done",0)))
		print("SSRG_SLIDE_MISS ",JSON.stringify({"time":song_time,"head":entry.note.time,"started":entry.started,"next":next.time,"end":next.is_end,"checks_done":entry.get("checks_done",0),"owner":entry.pointer,"last_owner":entry.get("sustain_last_pointer",-999),"release_at":entry.get("ssrg_release_at",-1),"release_lane":entry.get("ssrg_release_lane",-1),"release_canceled":entry.get("ssrg_release_canceled",false),"contacts":pointers.size()}))
	var at=float(entry.note.time)
	if (entry.note.kind=="hold" or (ssrg_playable_run and entry.note.kind=="slide")) and entry.get("note_hit",false): at=minf(song_time,float(entry.note.time)+float(entry.note.duration))
	performance_samples.append({"time":at,"weight":0.0 if error<0 else (1.0 if grade=="PERFECT" else (.8 if grade=="GREAT" else .5)),"amount":1})
	if error>=0:
		entry.note_hit=true
		if ssrg_playable_run and entry.note.kind in ["hold","slide"]:remember_ssrg_contact(entry,int(entry.pointer))
		if not complete and field.world.notes.has(str(entry.key)): field.world.notes[str(entry.key)].head_hit=true
	if error<0: timing_label.text=""
	if error>=0 and not auto_play and not entry.get("timing_logged",false):
		entry.timing_logged=true
		var ms=float(entry.get("timing_error",song_time-float(entry.note.time)))*1000
		timing_samples.append({"time":float(entry.note.time),"ms":ms})
		timing_label.text="ON TIME" if absf(ms)<=10 else ("EARLY %d ms" if ms<0 else "LATE %d ms") % roundi(absf(ms))
		timing_label.add_theme_color_override("font_color",Color("65dcff") if ms<0 else Color("ff82d2"))
	var end_at=float(entry.note.time)+float(entry.note.duration)
	if ssrg_playable_run and error>=0 and complete and entry.note.kind in ["hold","slide"]:
		entry.ssrg_effect_until=end_at
	# An early lift completes a slide before its end reaches the line; flashing then would land
	# on the head's flash, so the end flashes on its own puck when it gets there.
	if effects and ssrg_playable_run and error>=0 and complete and entry.note.kind in ["hold","slide"] and not entry.note.has("ssrg_special"):
		field.world.ssrg_theme.resume_sustain(entry)
	elif effects and error>=0 and complete and entry.note.kind=="slide" and song_time<end_at: pending_end_hits.append({"at":end_at,"note":entry.note})
	elif effects and error>=0: field.world.spawn_hit(SynkChart.lane_at(entry.note,song_time),("special" if ssrg_playable_run and entry.note.has("ssrg_special") else str(entry.note.kind)),int(entry.note.direction),entry if entry.note.kind in ["hold","slide"] and not complete else {},int(entry.get("pointer",-999)))
	elif effects: field.world.shake_on_miss()
	if error<0 and entry.note.kind in ["slide","hold"]:
		entry.missed_at=song_time
		entry.missed_visual_time=field.world.render_time()
	judgement_kind = str(entry.note.kind)
	entry.done=complete; judged+=1; flash=1; flash_lane=roundi(SynkChart.lane_at(entry.note,song_time))
	# Energy is a performance gauge only: hits refill it, misses drain it, the song never fails.
	if error<0: judgement="MISS"; combo=0; combo_pulse=0; forfeit_checkpoints(entry); score_panel.energy=maxf(0,score_panel.energy-.08)
	else:
		combo+=1; combo_pulse=1.0; max_combo=maxi(combo,max_combo)
		score_panel.energy=minf(1,score_panel.energy+(.02 if grade=="PERFECT" else (.012 if grade=="GREAT" else .004)))
		if grade=="PERFECT": judgement="PERFECT"; earned+=1
		elif grade=="GREAT": judgement="GREAT"; earned+=.8
		else: judgement="GOOD"; earned+=.5
	judgment_counts[judgement]+=1
	if ssrg_playable_run and error>=0 and not complete:
		entry.sustain_grade=judgement;entry.sustain_rate=SsrgRules.rate(error);entry.ssrg_contact=true;entry.ssrg_tick_at=song_time
	if error>=0:
		add_points(judgement)
		if stage_intro and stage_intro.play_cover:stage_intro.play_cover.on_note_hit(judgement)
	if ssrg_playable_run and ssrg_presentation and (effects or judgement!="MISS"):ssrg_presentation.judged(judgement,entry.note)
	if effects and extras: extras.on_judged(entry,judgement,combo)
	if effects and ssrg_playable_run and ssrg_presentation and judgement=="MISS" and ssrg_presentation.life<=0 and not practice.active:ssrg_game_over()

func ssrg_game_over() -> void:
	if ssrg_failed or finishing or mode!="play":return
	ssrg_failed=true;audio.stream_paused=true;pointers.clear();ssrg_touch_router.reset();ssrg_contact_ids.clear()
	paused_mode="play";set_mode("paused",false)
	# The reason sits on the line under the title, clear of the buttons.
	modal_title.text="Failed";modal_body.text=""
	pause_restart.text="RETRY";pause_home.text="SONG LIST"
	pause_info.text=str(song.get("title",""))+"   ·   Life reached zero"

func _audio_finished() -> void:
	if mode=="record": stop_take()
	elif mode=="play":
		if song_sync and song_sync.active: song_sync.restart(); return
		if practice.finish_round(): return
		# Resolve an eligible final hold/slide tail at terminal chart time before
		# unresolved notes are converted to misses and the result is frozen.
		if ssrg_playable_run and not ssrg_failed:update_game()
		for entry in live:
			if not entry.done:
				judge(entry,-1)
				if not entry.started: count_unstarted_tail(entry)
		var ssrg_result:Dictionary={};var final_rave_delay=0.0
		if ssrg_playable_run and ssrg_presentation:
			if ssrg_presentation.score_rules.current_pending_bonus()>0:final_rave_delay=3.0
			score=ssrg_presentation.score_rules.settle()
			ssrg_result=ssrg_presentation.score_rules.result_snapshot()
		var chart_key=(str(song.id)+JSON.stringify(live.map(func(e):return e.note))).sha256_text()
		if ssrg_playable_run:chart_key+="|ssrg-score-v2"
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
			"song_id":str(song.id),"artist":str(song.artist) if str(song.get("artist","")).strip_edges()!="" else album_name(song),"difficulty":preload("res://scripts/chart_levels.gd").label(features.current_variant),"bpm":chart_bpm(),"notes_total":live.size(),"notes_hit":live.filter(func(e): return bool(e.get("note_hit",false))).size(),
			"performance":performance_samples.duplicate(true),"range_start":play_range.x,"range_end":minf(length(),play_range.y),
			"plain_score":int(ssrg_result.get("plain_score",score)),"rave_bonus":int(ssrg_result.get("rave_bonus",0)),"final_life":float(ssrg_presentation.life) if ssrg_playable_run and ssrg_presentation else 100.0,"final_fever":int(ssrg_presentation.state) if ssrg_playable_run and ssrg_presentation else 0,"final_rave_delay":final_rave_delay})
	elif mode=="editor":
		if recorder.reviewing_audio: recorder.stop_preview(); refresh_transport()
		elif loop_enabled and loop_b>loop_a+.1: audio.play(loop_a); cursor=loop_a
		else: cursor=length(); refresh_transport()

# The finish: gameplay stops, the HUD fades, the camera pulls back and the finish overlay
# carries the combo counter to the middle; the results screen then takes over beneath it.
func begin_finish(results: Dictionary) -> void:
	if finishing: return
	# SSRG mode keeps SYNK's own results screen; its retry starts the SYNK song again.
	results["ssrg"]=ssrg_playable_run and not ssrg_forced_run
	results["ssrg_lane_count"]=ssrg_lane_count
	results["ssrg_style"]=ssrg_playable_previous_style
	pending_results=results
	finishing=true; finish_elapsed=-float(results.get("final_rave_delay",0.0))
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
	# The album art flies from its gameplay spot onto the results cover (measured before play ends).
	preload("res://scripts/cover_flight.gd").fly(self,ssrg_screens.result_cover if pending_results.get("ssrg",false) else results_screen.card)
	set_mode("results")
	if pending_results.get("ssrg",false):ssrg_screens.show_results(pending_results)
	else:results_screen.show_results(pending_results)
	# The new results card owns its typography after the finish transition.
	finish_overlay.stop()


func build_studio() -> void:
	studio=Panel.new(); studio.set_script(load("res://scripts/chart_editor.gd")); studio.game=self; studio.theme=preload("res://scripts/game_theme.gd").arcade()
	rect(studio,ui,0,0,1,1)
	picker=FileDialog.new(); add_child(picker); picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE; picker.access=FileDialog.ACCESS_FILESYSTEM; picker.use_native_dialog=true
	picker.filters=PackedStringArray(["*.mp3,*.wav,*.ogg;Audio;audio/mpeg,audio/wav,audio/ogg"]); picker.file_selected.connect(import_audio)
	refresh_library()

func open_editor() -> void:
	stop_audition()
	if not document.dirty and document.notes.is_empty(): document.load_notes(baseline_notes())
	set_mode("library")

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
	if NativeFilePicker.open(false,func(paths): import_audio(paths[0])): return
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
	if (mode!="library" and not (mode=="menu" and ssrg_playables.visible)) or song_details_entry(id).is_empty(): return
	song_details_return_ssrg=ssrg_playables.visible
	if song_details_return_ssrg:ssrg_playables.stop_preview();ssrg_playables.hide()
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
	if song_details_return_ssrg and mode=="menu":
		ssrg_playables.show();ssrg_playables.refresh_songs();UiMotion.reveal(ssrg_playables)
	song_details_return_ssrg=false
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
	if result.get("cover") is Image and not has_custom_cover(str(result.song.id)): save_cover_image(str(result.song.id),result.cover)
	apply_song(result.song,result.stream); refresh_library(); set_mode("editor")
	tell("Audio imported.")

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
	if song_metadata.has(str(song.id)):
		song_metadata[str(song.id)].notes=sorted.duplicate(true)
		song_metadata[str(song.id)].note_count=sorted.size()
		song_metadata[str(song.id)].has_chart=true
	refresh_editor(); refresh_library()
	tell("Chart saved.")

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
	start_position=from
	if ssrg_playable_run and ssrg_presentation:ssrg_presentation.reset(total_judgements(),song.get("ssrg_presentation",{}))
	gameplay_start_lead=maxf(2.0,note_travel_seconds()-(float(notes[0].time)-from)) if not notes.is_empty() else 2.0
	song_time=from-gameplay_start_lead-countdown
	visual_song_time=song_time; visual_clock_ready=false

func chart_empty_point() -> float:
	var last = -1.0
	for source in [document.notes, capture.notes]:
		for n in source:
			var end_time = float(n.time) + float(n.get("duration", 0.0))
			last = maxf(last, end_time)
	return last if last >= 0.0 else song_time


func snap_recorder_move(at: float, latest: float, moving: Dictionary = {}) -> float:
	var result = clampf(at, 0, maxf(0, latest))
	var closest = 0.1

	for source in [document.notes, capture.notes]:
		for other in source:
			if is_same(other, moving): continue
			var rows = [float(other.time)]
			if other.kind in ["hold", "slide"]: rows.append(float(other.time) + float(other.duration))
			for row in rows:
				if row < 0 or row > latest: continue
				var distance = absf(at - row)
				if distance < closest:
					closest = distance;result = row
	return result


func begin_resume_lead() -> float:
	# Resuming from a scrub (the Correct-mode line) starts exactly at that position; the
	# run-up lead only applies when continuing on from the end of the recorded notes.
	var from_scrub = recorder_seek_target >= 0
	ready_point = recorder_seek_target if from_scrub else (chart_empty_point() if capture.notes.size() + document.notes.size() > 0 else song_time)
	recorder_seek_target=-1.0
	var lead = 0.0 if from_scrub else float(recorder.resume_lead)
	var target = maxf(maxf(0.0, recorder.region.x if recorder.active else 0.0), ready_point - lead)
	song_time = target;visual_song_time = target;visual_clock_ready = false
	return target


func take_snapshot_notes(source: Array, previous: Array) -> Array:


	var result: Array = []
	for i in source.size():
		if i < previous.size() and source[i] == previous[i]: result.append(previous[i])
		else: result.append(source[i].duplicate(true))
	return result


func take_snapshot() -> Dictionary:
	return {"capture": take_snapshot_notes(capture.notes, take_state.get("capture", [])), "document": take_snapshot_notes(document.notes, take_state.get("document", []))}


func reset_take_history() -> void :
	take_undo.clear();take_redo.clear();take_state = take_snapshot();refresh_take_history_buttons()


func commit_take_history() -> void :
	var now = take_snapshot()
	if take_state.is_empty() or now == take_state: take_state = now;return
	take_undo.append(take_state);take_redo.clear();take_state = now
	if take_undo.size() > 200: take_undo.pop_front()
	refresh_take_history_buttons()


func restore_take(state: Dictionary) -> void :
	capture.notes = state.capture.duplicate(true)
	if JSON.stringify(state.document) != JSON.stringify(document.notes):
		document.notes = state.document.duplicate(true);document.selected = -1;document.dirty = true
	take_state = state.duplicate(true)
	arrange_selection.clear();arrange_touches.clear()
	refresh_arrange_controls();refresh_take_history_buttons()


func redo_record_note() -> void :
	if take_redo.is_empty(): return
	take_undo.append(take_state);restore_take(take_redo.pop_back())
	judgement = "REDO";flash = 1


func refresh_take_history_buttons() -> void :
	if take_undo_button: take_undo_button.disabled = take_undo.is_empty()
	if take_redo_button: take_redo_button.disabled = take_redo.is_empty()


var note_arranger: Control
var overlap_tools: Control

var arrange_preview: Node

var recorder_beam_touches: Dictionary = {}

var take_undo: Array = []

var take_redo: Array = []

var take_state: Dictionary = {}

var take_undo_button: Button

var take_redo_button: Button

var ready_point = -1.0

# Slide design snapping: "free" (0.05-lane steps), "lanes" (whole lanes) or "beats"
# (whole lanes and sixteenth-note timing). Remembered between sessions.
var slide_snap = "free"
func cycle_slide_snap() -> void:
	var order = ["free", "lanes", "beats"]
	slide_snap = order[(order.find(slide_snap) + 1) % order.size()]
	prefs.set_value("editor", "slide_snap", slide_snap);prefs.save("user://preferences.cfg")
	refresh_arrange_controls()
func snap_slide_lane(lane: float) -> float:
	return clampf(roundf(lane) if slide_snap != "free" else snappedf(lane, 0.05), 0, SynkChart.MAX_LANE)
func snap_slide_time(at: float) -> float:
	if slide_snap != "beats": return at
	var step = 60.0 / maxf(1.0, chart_bpm()) / 4.0
	return chart_offset() + snappedf(at - chart_offset(), step)
func begin_trail_bend(touch: Dictionary, n: Dictionary, offset: float) -> void :
	if touch.document: document.checkpoint()
	if n.kind == "hold": n.kind = "slide";n.path = [];n.end_lane = n.lane
	n.ssrg_path=true
	if n.path.size() < 2:
		n.path = [{"offset": 0.0, "lane": float(n.lane)}, {"offset": float(n.duration), "lane": float(n.end_lane)}]
	var index = -1
	for i in range(1, n.path.size()-1):
		if absf(float(n.path[i].offset) - offset) <= 0.08: index = i;break
	if index < 0:
		var lane = SynkChart.lane_at(n, float(n.time) + offset)
		index = n.path.size()
		for i in n.path.size():
			if float(n.path[i].offset) > offset: index = i;break
		n.path.insert(index, {"offset": snappedf(offset, 0.001), "lane": lane})
	SynkChart.sync_connectors(n)
	touch.bend_index = index;touch.bend_lane = float(n.path[index].lane);touch.bend_offset = float(n.path[index].offset);touch.changed = true

