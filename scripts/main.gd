extends Control

var library = SynkLibrary.new()
var document = SynkChart.new()
var capture = SynkCapture.new()
var audio = AudioStreamPlayer.new()
var demo_stream: AudioStream
var song = {"id":"eclipse", "title":"Eclipse", "bpm":128.0}
var saved_notes: Array = []
var mode = "menu"
var paused_mode = "play"
var song_time = 0.0
var live: Array = []
var pointers: Dictionary = {}
var score = 0
var combo = 0
var max_combo = 0
var earned = 0.0
var judged = 0
var flash = 0.0
var flash_lane = 6
var judgement = ""
var countdown = 0.0
var start_position = 0.0
var timing_ms = 0.0
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
var modal: Panel
var modal_title: Label
var modal_body: Label
var primary: Button
var actions: Control
var hud: Label
var song_hud: Label
var hit_label: Label
var pause_button: Button
var record_tools: Control
var studio: Panel
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
var bpm_input: SpinBox
var updating = false
var last_play_notes: Array = []
var record_info: Label

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	Engine.max_fps = 120
	prefs.load("user://preferences.cfg"); timing_ms = float(prefs.get_value("audio","offset_ms",0))
	add_child(audio); demo_stream = SynkLibrary.synth_demo(); audio.stream = demo_stream
	audio.finished.connect(_audio_finished)
	field = Control.new(); field.set_script(load("res://scripts/highway.gd")); field.game = self; add_child(field); field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui = Control.new(); add_child(ui); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_safe_area(); get_viewport().size_changed.connect(apply_safe_area)
	build_ui(); build_studio(); saved_notes = library.load_chart("eclipse")
	get_window().files_dropped.connect(func(files):
		if files.size()>0 and mode in ["menu","editor"]:
			open_editor(); import_audio(files[0]))
	get_tree().auto_accept_quit = false
	set_mode("menu")
	build_waveform()

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
	result.add_theme_color_override("font_color",Color("e6e0ff")); result.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

func button(parent: Node,text: String,x: float,y: float,right: float,bottom: float,action: Callable) -> Button:
	var result=Button.new(); rect(result,parent,x,y,right,bottom); result.text=text; result.add_theme_font_size_override("font_size",18); result.pressed.connect(action)
	var style=StyleBoxFlat.new(); style.bg_color=Color("281143"); style.border_color=Color("834ac5"); style.set_border_width_all(1); style.set_corner_radius_all(9)
	result.add_theme_stylebox_override("normal",style)
	var hover=style.duplicate(); hover.bg_color=Color("45306f"); result.add_theme_stylebox_override("hover",hover)
	var pressed=style.duplicate(); pressed.bg_color=Color("176477"); result.add_theme_stylebox_override("pressed",pressed)
	return result

func build_ui() -> void:
	song_hud=label(ui,"",.12,.02,.4,.12,25)
	hud=label(ui,"",.64,.02,.97,.14,30); hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	pause_button=button(ui,"II",.02,.025,.08,.105,toggle_pause)
	hit_label=label(ui,"",.3,.8,.7,.9,40); hit_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	modal=Panel.new(); rect(modal,ui,.19,.17,.81,.81)
	var style=StyleBoxFlat.new(); style.bg_color=Color("090b22"); style.border_color=Color("733fb7"); style.set_border_width_all(1); style.set_corner_radius_all(20); modal.add_theme_stylebox_override("panel",style)
	modal_title=label(modal,"S Y N K",.04,.04,.96,.22,48); modal_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	modal_body=label(modal,"",.06,.22,.94,.65,22); modal_body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; modal_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	primary=button(modal,"PLAY",.23,.8,.77,.94,primary_action)
	label(modal,"Timing offset (ms)",.1,.67,.5,.77,18)
	var offset=SpinBox.new(); rect(offset,modal,.58,.68,.86,.77); offset.min_value=-200; offset.max_value=200; offset.value=timing_ms
	offset.value_changed.connect(func(value): timing_ms=value; prefs.set_value("audio","offset_ms",value); prefs.save("user://preferences.cfg"))
	actions=Control.new(); rect(actions,ui,0,0,1,1); actions.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button(actions,"RECORD NEW",.03,.91,.27,.98,start_new_recording)
	button(actions,"PLAY SAVED",.29,.91,.49,.98,func(): start_game(saved_notes))
	button(actions,"CHART STUDIO / IMPORT AUDIO",.51,.91,.97,.98,open_editor)
	record_tools=Control.new(); rect(record_tools,ui,0,0,1,1); record_tools.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var kinds=["auto","tap","hold","slide","flick"]
	for i in kinds.size():
		var kind=kinds[i]
		button(record_tools,kind.to_upper(),.15+i*.12,.025,.26+i*.12,.095,func(): tool=kind; judgement=kind.to_upper()+" TOOL"; flash=1)
	button(record_tools,"UNDO",.77,.025,.87,.095,func(): if not capture.notes.is_empty(): capture.notes.pop_back())
	button(record_tools,"STOP",.89,.025,.98,.095,stop_take)
	record_info=label(record_tools,"",.65,.12,.97,.21,24); record_info.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var help=label(record_tools,"Tap • hold still • drag to slide • quick swipe to flick\nRecord near the glowing line. STOP to edit your take.",.05,.86,.95,.97,21); help.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func set_mode(value: String) -> void:
	mode=value; studio.visible=mode=="editor"; modal.visible=mode in ["menu","paused","results"]
	actions.visible=mode in ["menu","results"]; record_tools.visible=mode=="record"
	hud.visible=mode in ["play","paused"]; hit_label.visible=mode in ["play","record"]; pause_button.visible=mode in ["play","record","paused"]
	song_hud.visible=mode in ["play","paused"]; song_hud.text=str(song.title)+"\n"+str(song.bpm)+" BPM / CUSTOM" if song.id!="eclipse" else "Eclipse\nSYNK Originals / EXPERT"
	if mode=="menu":
		modal_title.text="S Y N K"; modal_body.text=song.title+"  /  "+str(song.bpm)+" BPM\n\n13 lanes. Follow the light.\nTap on arrival. Hold to the end.\nFollow slide ribbons. Flick in the arrow direction.\n\nOpen Chart Studio to import music and edit charts."; primary.text="PLAY ORIGINAL" if song.id=="eclipse" else "PLAY MY CHART"
	if mode=="editor": refresh_editor()

func primary_action() -> void:
	if mode=="paused": toggle_pause()
	elif mode=="results": start_game(last_play_notes)
	else: start_game(SynkChart.demo() if song.id=="eclipse" else saved_notes)

func baseline_notes() -> Array:
	return saved_notes if library.has_chart(song.id) else (SynkChart.demo() if song.id=="eclipse" else [])

func audio_time() -> float:
	return maxf(0,audio.get_playback_position()+AudioServer.get_time_since_last_mix()*audio.pitch_scale-AudioServer.get_output_latency())
func chart_time() -> float: return maxf(0,audio_time()+timing_ms/1000.0)
func length() -> float: return audio.stream.get_length()
func accuracy() -> float: return 100.0 if judged==0 else earned/judged*100
func rank_name() -> String:
	var a=accuracy(); return "SS" if a>=98 else ("S" if a>=95 else ("A" if a>=90 else ("B" if a>=80 else "C")))

func start_game(notes: Array) -> void:
	audio.stop(); audio.pitch_scale=1; pointers.clear(); live.clear()
	var sorted=notes.duplicate(true); sorted.sort_custom(func(a,b): return a.time<b.time)
	last_play_notes=sorted.duplicate(true)
	for n in sorted: live.append({"note":n,"started":false,"done":false,"pointer":-999,"error":0.0})
	score=0; combo=0; max_combo=0; earned=0; judged=0; countdown=2; start_position=0; song_time=-2; judgement="READY"; flash=1
	set_mode("play")

func start_new_recording() -> void:
	open_editor()
	if document.dirty: tell("Save or reload your edits before starting a new chart."); return
	document.load_notes([]); document.dirty=true; cursor=0; record_here()

func record_here() -> void:
	audio.stop(); audio.pitch_scale=1; capture.notes.clear(); capture.gestures.clear(); pointers.clear(); tool="auto"
	overdub=true; start_position=clampf(cursor,0,maxf(0,length()-.02)); countdown=3; song_time=start_position-3; set_mode("record")

func stop_take() -> void:
	audio.stop(); capture.gestures.clear()
	if not capture.notes.is_empty(): document.checkpoint(); document.notes.append_array(capture.notes.duplicate(true))
	cursor=clampf(song_time,0,length()); set_mode("editor"); tell("Take added. Previous notes kept. Undo removes this take. Save when ready.")

func toggle_pause() -> void:
	if mode in ["play","record"]:
		paused_mode=mode; audio.stream_paused=true; pointers.clear(); capture.gestures.clear()
		for entry in live:
			if entry.started and not entry.done: entry.pointer=-999
		set_mode("paused"); modal_title.text="PAUSED"; modal_body.text="Take a breath.\n\nTouch active ribbons after resuming.\nUnfinished recording gestures are discarded."; primary.text="RESUME"
	elif mode=="paused": audio.stream_paused=false; resume_grace=.3; set_mode(paused_mode)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		if mode in ["play","record"]: toggle_pause()
		elif mode=="editor" and audio!=null: stop_audition()
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if document.dirty: open_editor(); tell("Save your draft or RELOAD to discard edits before closing.")
		else: get_tree().quit()

func _process(delta: float) -> void:
	flash=maxf(0,flash-delta*2.5); resume_grace=maxf(0,resume_grace-delta)
	if mode in ["play","record"]:
		if countdown>0:
			countdown=maxf(0,countdown-delta); song_time=start_position-countdown
			judgement="READY "+str(ceili(countdown)); flash=1
			if countdown==0: audio.stream_paused=false; audio.play(start_position)
		else:
			song_time=chart_time()
			if mode=="play": update_game()
	if mode=="editor" and audio.playing:
		cursor=clampf(chart_time(),0,length())
		if loop_enabled and loop_b>loop_a+.1 and cursor>=loop_b: audio.play(loop_a); cursor=loop_a
		refresh_editor()
	hud.text="%s   %s\nCOMBO %d   /   %.2f%%" % [str(score).pad_zeros(7),rank_name(),combo,accuracy()]
	record_info.text="● RECORDING  %.1f s\n%d NOTES / %s" % [maxf(0,song_time),capture.notes.size(),tool.to_upper()]
	hit_label.text=judgement; hit_label.modulate.a=flash

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==-1: return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		if mode=="editor": close_editor()
		else: toggle_pause()
	if mode not in ["play","record"] or countdown>0: return
	if event is InputEventScreenTouch: pointer_event(event.index,event.position/size,event.pressed,not event.pressed,event.canceled)
	elif event is InputEventScreenDrag: pointer_event(event.index,event.position/size,false,false,false)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT: pointer_event(-1,event.position/size,event.pressed,not event.pressed,false)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): pointer_event(-1,event.position/size,false,false,false)

func pointer_event(id: int,p: Vector2,began: bool,ended: bool,canceled: bool) -> void:
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
			var nearest: Dictionary={}; var best=.161
			for entry in live:
				if entry.done: continue
				var n: Dictionary=entry.note
				if entry.started:
					if entry.pointer==-999 and absf(SynkCapture.lane(p.x)-SynkChart.lane_at(n,song_time))<.85: entry.pointer=id
					continue
				var error=absf(song_time-float(n.time))
				if error<=best and absf(SynkCapture.lane(p.x)-float(n.lane))<.85: best=error; nearest=entry
			if not nearest.is_empty():
				nearest.started=true; nearest.pointer=id; nearest.error=best
				if nearest.note.kind=="tap": judge(nearest,best)
	if pointers.has(id): pointers[id].position=p
	if ended:
		# Process final swipe motion before removing the finger.
		update_game()
		pointers.erase(id)
		if canceled:
			for entry in live:
				if entry.pointer==id and not entry.done: judge(entry,-1)

func update_game() -> void:
	for entry in live:
		if entry.done: continue
		var n: Dictionary=entry.note
		if not entry.started:
			if song_time>float(n.time)+.16: judge(entry,-1)
			continue
		if entry.pointer==-999 and resume_grace>0: continue
		if not pointers.has(entry.pointer): judge(entry,-1); continue
		var p: Dictionary=pointers[entry.pointer]
		if n.kind=="flick":
			var displacement: Vector2=p.position-p.start
			var direction: Vector2=[Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][int(n.direction)]
			if displacement.dot(direction)>.035 and displacement.dot(direction)>absf(displacement.dot(direction.orthogonal())): judge(entry,float(entry.error))
			elif song_time>float(n.time)+.16: judge(entry,-1)
		elif absf(SynkCapture.lane(p.position.x)-SynkChart.lane_at(n,song_time))>1.2 or p.position.y<.6: judge(entry,-1)
		elif song_time>=float(n.time)+float(n.duration)-.045: judge(entry,float(entry.error))

func judge(entry: Dictionary,error: float) -> void:
	entry.done=true; judged+=1; flash=1; flash_lane=roundi(SynkChart.lane_at(entry.note,song_time))
	if error<0: judgement="MISS"; combo=0
	else:
		combo+=1; max_combo=maxi(combo,max_combo)
		if error<=.045: judgement="PERFECT"; earned+=1
		elif error<=.09: judgement="GREAT"; earned+=.8
		else: judgement="GOOD"; earned+=.5
	score=roundi(1000000*earned/maxi(1,live.size()))

func _audio_finished() -> void:
	if mode=="record": stop_take()
	elif mode=="play":
		for entry in live:
			if not entry.done: judge(entry,-1)
		var chart_key=(str(song.id)+JSON.stringify(live.map(func(e):return e.note))).sha256_text()
		var best=maxi(score,int(prefs.get_value("scores",chart_key,0))); prefs.set_value("scores",chart_key,best); prefs.save("user://preferences.cfg")
		set_mode("results"); modal_title.text=rank_name()+"  /  "+str(score); modal_body.text="TRACK COMPLETE\n\n%.2f%% accuracy   •   %d max combo\n\nPersonal best %d\n\nOpen Chart Studio to keep editing." % [accuracy(),max_combo,best]; primary.text="PLAY AGAIN"
	elif mode=="editor":
		if loop_enabled and loop_b>loop_a+.1: audio.play(loop_a); cursor=loop_a
		else: cursor=length(); refresh_transport()

func build_studio() -> void:
	studio=Panel.new(); rect(studio,ui,0,0,1,1)
	var style=StyleBoxFlat.new(); style.bg_color=Color("07091a"); studio.add_theme_stylebox_override("panel",style)
	title_label=label(studio,"SYNK STUDIO",.02,.015,.7,.085,28)
	button(studio,"SAVE",.73,.02,.84,.08,save_editor); button(studio,"CLOSE",.86,.02,.98,.08,close_editor)
	button(studio,"IMPORT AUDIO",.02,.12,.23,.19,choose_audio)
	song_list=ItemList.new(); rect(song_list,studio,.02,.21,.23,.78); song_list.add_theme_font_size_override("font_size",21); song_list.item_selected.connect(select_song)
	status=label(studio,"",.02,.8,.23,.98,18); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
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
	button(studio,"DIRECTION",.69,.79,.83,.845,func(): var n=document.selection(); if not n.is_empty(): document.checkpoint(); n.direction=(int(n.direction)+1)%4; refresh_editor())
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
	refresh_library()

func open_editor() -> void:
	stop_audition()
	if not document.dirty and document.notes.is_empty(): document.load_notes(baseline_notes())
	set_mode("editor"); tell("Tap a note to select; drag to move. Touch empty timeline to seek. SAVE keeps your chart. RELOAD discards edits.")

func close_editor() -> void:
	stop_audition()
	if document.dirty: tell("Save your draft or RELOAD before closing."); return
	set_mode("menu")

func tell(message: String) -> void: status.text=message
func refresh_library() -> void:
	song_list.clear(); song_list.add_item("Eclipse / Demo")
	for s in library.songs: song_list.add_item(s.title)

func choose_audio() -> void:
	if document.dirty: tell("Save or RELOAD before changing songs."); return
	stop_audition()
	if OS.get_name()=="iOS":
		picker.access=FileDialog.ACCESS_USERDATA; picker.current_dir="user://"
		tell("In the Files app, copy music into On My iPhone → SYNK, then choose it here.")
	picker.popup_centered_ratio(.8)

func import_audio(path: String) -> void:
	if document.dirty: tell("Save or RELOAD before importing audio."); return
	stop_audition(); tell("Importing audio…")
	var result=library.import_song(path)
	if result.is_empty(): tell(library.message); return
	apply_song(result.song,result.stream); tell("Audio kept on this device. Record from the playhead or add notes manually.")

func select_song(index: int) -> void:
	if document.dirty: tell("Save or RELOAD before changing songs."); return
	if index==0: apply_song({"id":"eclipse","title":"Eclipse","bpm":128.0},demo_stream)
	else:
		var s: Dictionary=library.songs[index-1]; var stream=SynkLibrary.decode("user://songs/"+str(s.file))
		if stream==null: tell("Audio is missing. Import this song again."); return
		apply_song(s,stream)

func apply_song(entry: Dictionary,stream: AudioStream) -> void:
	stop_audition(); song=entry; audio.stream=stream; cursor=0; loop_a=0; loop_b=minf(8,length()); loop_enabled=false
	saved_notes=library.load_chart(song.id); document.load_notes(baseline_notes())
	bpm_input.set_value_no_signal(song.bpm); waveform=[]; refresh_library(); refresh_editor(); build_waveform()
	if not library.message.is_empty(): tell(library.message)

func save_editor() -> void:
	stop_audition()
	var sorted=document.notes.duplicate(true); sorted.sort_custom(func(a,b):return a.time<b.time)
	if library.save_chart(song.id,sorted)!=OK: tell("Could not save. Your draft is still here; check storage."); return
	saved_notes=sorted; document.dirty=false; refresh_editor(); tell("Chart saved with its song. Close Studio and choose PLAY SAVED.")

func refresh_editor() -> void:
	title_label.text="SYNK STUDIO / "+song.title+("  *" if document.dirty else "")
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
	var playback=audio.stream.instantiate_playback()
	var peaks=PackedFloat32Array(); peaks.resize(512)
	playback.start()
	for i in 512:
		playback.seek(i*length()/512)
		var frames=playback.mix_audio(1.0,256)
		var peak=0.0
		for frame in frames: peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
		peaks[i]=peak
	playback.stop(); waveform=peaks
