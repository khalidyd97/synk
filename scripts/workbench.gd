extends Node
const UiMotion=preload("res://scripts/ui_motion.gd")
# Authoring services; saved charts and recoverable drafts stay separate.
var game: Control
var current_variant="original"
const VARIANTS=["original","easy","normal","expert","hard"]
var autosave_elapsed=0.0
var draft_hash=0
var recovery_checked=""
var overlay: Control
var tabs: TabContainer
var chart_picker: FileDialog
var chart_exporter: FileDialog
const EFFECT_NAMES=["Hit flashes","Particles","Lasers","Background brightness","Flowing edge energy","Soft fading glow"]
const OPTIONAL_STAGE_EFFECTS=["Flowing edge energy","Soft fading glow"]
static func effect_default(key: String) -> float: return 0.0 if key in OPTIONAL_STAGE_EFFECTS else 1.0
var effects: Dictionary={}
var effect_sliders: Dictionary={}
const TOOL_PAGES=["Drafts","Charts","Sharing","Effects","Arrange","Check","Grid","Practice","Analyze","Bookmarks","Song","Authoring","Recording"]
const TOOL_SCOPES={"THIS CHART":["Drafts","Grid","Bookmarks","Arrange","Check","Analyze","Practice","Recording"],"THIS SONG":["Song"],"VERSIONS":["Charts"],"SHARE":["Sharing"]}
var scope_buttons: Dictionary={}
var tools_context: Label
var draft_context: Label
var global_settings=false
var scope_refresh: Dictionary={}

func _ready() -> void:
    DirAccess.make_dir_recursive_absolute("user://drafts")
    for key in EFFECT_NAMES:
        effects[key]=clampf(float(game.prefs.get_value("effects",key,effect_default(key))),0,1)

func set_effect(key: String,value: float) -> void:
    if key not in EFFECT_NAMES or not is_finite(value): return
    effects[key]=clampf(value,0,1)
    game.prefs.set_value("effects",key,effects[key]); game.prefs.save("user://preferences.cfg")

func effect(key: String) -> float: return float(effects.get(key,effect_default(key)))
func chart_path(variant: String="") -> String:
    var name=current_variant if variant.is_empty() else variant
    return "user://charts/"+str(game.song.id)+("" if name=="original" else "_"+name)+".json"
func draft_path() -> String: return "user://drafts/"+str(game.song.id)+"_"+current_variant+".json"
func payload(notes: Array) -> Dictionary:
    return {"version":SynkChart.FORMAT_VERSION,"song_id":str(game.song.id),"chart_name":current_variant,"title":str(game.song.title),"bpm":float(game.document.settings.get("bpm",game.song.get("bpm",128))),"beat_offset":float(game.document.settings.get("beat_offset",0)),"chart_settings":game.document.settings.duplicate(true),"notes":notes}

func settings_from(data: Dictionary) -> Variant:
    var config: Variant=data.get("chart_settings",{})
    if not config is Dictionary: return null
    config=config.duplicate(true)
    for key in config:
        if key not in ["bpm","beat_offset","verse2","bridge","bookmarks"]: return null
    for key in ["bpm","beat_offset","verse2","bridge"]:
        if not config.has(key): config[key]=data.get(key,game.song.get(key,128.0 if key=="bpm" else (0.0 if key=="beat_offset" else -1.0)))
        if not (config[key] is float or config[key] is int) or not is_finite(float(config[key])): return null
    if float(config.bpm)<30 or float(config.bpm)>300 or float(config.beat_offset)<0 or float(config.beat_offset)>game.length()+.001: return null
    for key in ["verse2","bridge"]:
        if float(config[key])< -1 or float(config[key])>game.length()+.001: return null
    if not config.has("bookmarks"): config.bookmarks=game.prefs.get_value("bookmarks",str(game.song.id),[]).duplicate(true)
    if not config.bookmarks is Array or config.bookmarks.size()>64: return null
    for mark in config.bookmarks:
        if not mark is Dictionary or not mark.get("name") is String or str(mark.name).strip_edges().is_empty(): return null
        for key in ["start","end"]:
            if not (mark.get(key) is float or mark.get(key) is int) or not is_finite(float(mark[key])): return null
        if float(mark.start)<0 or float(mark.end)<float(mark.start) or float(mark.end)>game.length()+.001: return null
    return config

func set_chart_value(key: String,value: Variant) -> bool:
    if key not in ["bpm","beat_offset","verse2","bridge","bookmarks"]: return false
    var candidate=game.document.settings.duplicate(true); candidate[key]=value
    var valid=settings_from({"chart_settings":candidate})
    if valid==null: return false
    if game.document.settings.get(key)==value: return true
    game.document.checkpoint(); game.document.settings=valid
    if game.beat_clock: game.beat_clock.last_time=-1
    game.refresh_editor(); return true
func autosave() -> Error:
    if not game.document.dirty: return OK
    var signature=hash(payload(game.document.notes))
    if signature==draft_hash and FileAccess.file_exists(draft_path()): return OK
    var data=payload(game.document.notes); data["saved_at"]=Time.get_datetime_string_from_system()
    var error=SynkLibrary.atomic_write(draft_path(),data)
    if error==OK: draft_hash=signature
    return error
func recover(force: bool=false) -> bool:
    var key=str(game.song.id)+current_variant
    if recovery_checked==key: return false
    recovery_checked=key
    if game.document.dirty and not force: return false
    if not FileAccess.file_exists(draft_path()): return false
    var data=JSON.parse_string(FileAccess.get_file_as_string(draft_path()))
    var notes=SynkChart.notes_from_file(data)
    if notes==null or str(data.get("song_id",""))!=str(game.song.id): return false
    var config=settings_from(data)
    if config==null: return false
    if force and game.document.dirty:
        game.document.checkpoint(); game.document.notes=notes.duplicate(true); game.document.settings=config; game.document.selected=-1
    else: game.document.load_notes(notes,config)
    game.document.dirty=true; draft_hash=hash(payload(notes))
    game.tell("Recovered your autosaved "+current_variant+" draft.")
    return true
func save_chart(notes: Array) -> Error:
    if settings_from(payload(notes))==null: return ERR_INVALID_DATA
    var song_id=str(game.song.id)
    # The first save of a level with no history keeps what was there before as version 1.
    if SynkChartVersions.list(song_id,current_variant).is_empty():
        var previous=SynkChartVersions.read(chart_path())
        if previous.is_empty() and song_id=="eclipse" and current_variant=="original": previous=payload(SynkChart.demo())
        if not previous.is_empty(): SynkChartVersions.record(song_id,current_variant,SynkChartVersions.strip(previous),"Built-in chart" if song_id=="eclipse" and not chart_exists() else "Before version history")
    var error=SynkLibrary.atomic_write(chart_path(),payload(notes))
    if error==OK:
        SynkChartVersions.record(song_id,current_variant,payload(notes))
        if FileAccess.file_exists(draft_path()): DirAccess.remove_absolute(draft_path())
        draft_hash=0
    return error
func chart_exists() -> bool: return FileAccess.file_exists(chart_path())
func activate_song() -> void:
    current_variant=str(game.prefs.get_value("charts",str(game.song.id),"original"))
    if current_variant not in VARIANTS: current_variant="original"
    load_variant()
    refresh_tools_context()
func load_variant() -> void:
    if game.timeline: game.timeline.clear_range()
    var notes: Array=[]
    var config=settings_from({})
    if chart_exists():
        var data=JSON.parse_string(FileAccess.get_file_as_string(chart_path()))
        var parsed=SynkChart.notes_from_file(data)
        if parsed!=null and str(data.get("song_id",""))==str(game.song.id):
            notes=parsed
            var stored=settings_from(data)
            if stored!=null: config=stored
    elif current_variant=="original" and game.song.id=="eclipse": notes=SynkChart.demo()
    game.saved_notes=notes.duplicate(true); game.saved_settings=config.duplicate(true) if config!=null else {}
    game.document.load_notes(notes,game.saved_settings)
    draft_hash=0; recovery_checked=""
    if game.mode=="editor": recover()
    game.refresh_editor()
    if game.lobby: game.lobby.refresh()
func choose_variant(index: int) -> void:
    if game.document.dirty and autosave()!=OK: game.tell("Could not store this draft. Save it before switching charts."); return
    current_variant=VARIANTS[index]
    game.prefs.set_value("charts",str(game.song.id),current_variant); game.prefs.save("user://preferences.cfg")
    load_variant()
    refresh_tools_context()
func _process(delta: float) -> void:
    if game.mode=="editor":
        autosave_elapsed+=delta
        if autosave_elapsed>=2: autosave_elapsed=0; autosave()

func export_chart(path: String) -> Error:
    if not SynkChart.valid(game.document.notes): return ERR_INVALID_DATA
    var file=FileAccess.open(path,FileAccess.WRITE)
    if file==null: return FileAccess.get_open_error()
    file.store_string(JSON.stringify(payload(game.document.notes),"\t")); return OK
func import_chart(path: String) -> Error:
    var file=FileAccess.open(path,FileAccess.READ)
    if file==null or file.get_length()>16*1024*1024: return ERR_FILE_CANT_READ
    var data=JSON.parse_string(file.get_as_text())
    var notes=SynkChart.notes_from_file(data)
    if notes==null or str(data.get("song_id",""))!=str(game.song.id): return ERR_INVALID_DATA
    for n in notes:
        if float(n.time)+float(n.duration)>game.length()+.001: return ERR_INVALID_DATA
    var config=settings_from(data)
    if config==null: return ERR_INVALID_DATA
    game.document.checkpoint(); game.document.notes=notes.duplicate(true); game.document.settings=config; game.document.selected=-1
    game.refresh_editor(); return OK
func ui_text(parent: Node,text: String,size: int=18) -> Label:
    var label=Label.new(); parent.add_child(label); label.text=text
    label.add_theme_font_size_override("font_size",size); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    return label
func ui_button(parent: Node,text: String,callback: Callable,variant: String="tool") -> Button:
    var button=load("res://scripts/neon_action.gd").new(); button.caption_text=text; button.caption_size=18; button.compact=true; button.variant=variant
    button.custom_minimum_size=Vector2(0,48); parent.add_child(button); button.pressed.connect(callback); return button
func ui_field(parent: Node,title: String,low: float,high: float,step: float,value: float) -> SpinBox:
    var row=HBoxContainer.new(); parent.add_child(row); row.add_theme_constant_override("separation",20)
    var label=ui_text(row,title); label.custom_minimum_size.x=300
    var input=SpinBox.new(); row.add_child(input); input.min_value=low; input.max_value=high; input.step=step; input.value=value
    input.custom_minimum_size=Vector2(220,46); input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    return input
func report(message: String) -> void:
    game.tell(message)

func open_tools(selected_tab: String="Drafts") -> void:
    game.stop_audition()
    if overlay: overlay.queue_free()
    overlay=Control.new(); game.ui.add_child(overlay); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var dim=ColorRect.new(); overlay.add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.color=Color(0,0,.02,.88)
    var safe_content=game.safe_parent("SafeDialogControls",overlay)
    var panel=Panel.new(); game.rect(panel,safe_content,.055,.06,.945,.94)
    var style=StyleBoxFlat.new(); style.bg_color=Color("10142c"); style.set_corner_radius_all(20); style.border_color=Color("7b60af"); style.set_border_width_all(1)
    panel.add_theme_stylebox_override("panel",style)
    preload("res://scripts/screen_style.gd").chassis(panel)

    preload("res://scripts/interface_life.gd").mount(panel)
    UiMotion.reveal(dim)
    UiMotion.pop(panel)
    global_settings=selected_tab in ["Effects","Authoring"]
    game.label(panel,("VISUAL EFFECTS" if selected_tab=="Effects" else "EDITOR PREFERENCES") if global_settings else "CHART TOOLS",.025,.01,.75,.08,28)
    tools_context=game.label(panel,"",.025,.075,.79,.125,17)
    tools_context.clip_text=true; tools_context.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    game.button(panel,"CLOSE",.82,.02,.975,.085,close_tools,"nav")
    scope_buttons={}
    scope_refresh={}
    if not global_settings:
        var index=0
        for scope in TOOL_SCOPES:
            var button=game.button(panel,scope,.025+index*.24,.15,.25+index*.24,.225,func(): show_scope(scope),"tool")
            button.caption_size=16; scope_buttons[scope]=button; index+=1
    tabs=TabContainer.new(); game.rect(tabs,panel,.025,.15 if global_settings else .255,.975,.88)
    tabs.get_tab_bar().add_theme_font_size_override("font_size",19)
    for state in ["tab_selected","tab_unselected","tab_hovered"]:
        var tab_style=preload("res://scripts/game_theme.gd").plate(Color("26335b") if state=="tab_selected" else Color("0c142b"),Color("65dcff") if state=="tab_selected" else Color("334465"),4 if state=="tab_selected" else 1)
        tab_style.content_margin_left=22; tab_style.content_margin_right=22
        tab_style.content_margin_top=12; tab_style.content_margin_bottom=12
        tabs.get_tab_bar().add_theme_stylebox_override(state,tab_style)
    var pages: Dictionary={}
    for name in TOOL_PAGES:
        var scroll=ScrollContainer.new(); tabs.add_child(scroll); scroll.name=name
        var box=VBoxContainer.new(); scroll.add_child(box); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation",12)
        pages[name]=box
    ui_text(pages.Recording,"Record a section, repeat takes, set pre-roll, quantize timing and lock completed passes.",22)
    ui_text(pages.Recording,"Section bounds and pass locks apply to this recording session. Pre-roll, snapping and guide audio are your global recorder preferences.")
    ui_button(pages.Recording,"RECORDING SETUP",func(): close_tools(); game.recorder.show_setup())
    ui_text(pages.Drafts,"Drafts autosave every 2 seconds and recover when you reopen this chart.",21)
    draft_context=ui_text(pages.Drafts,"Current version: "+current_variant.to_upper()+" · "+str(game.song.title))
    ui_button(pages.Drafts,"SAVE DRAFT NOW",func(): report("Draft stored." if autosave()==OK else "Draft could not be stored."))
    ui_button(pages.Drafts,"RECOVER DRAFT",func(): recovery_checked=""; var recovered=recover(true); game.refresh_editor(); report("Draft recovered. UNDO restores your previous edits." if recovered else "No recoverable draft for this version."))
    ui_text(pages.Charts,"One song, multiple charts. Switching versions stores your current draft first.",21)
    var variant=OptionButton.new(); pages.Charts.add_child(variant); variant.custom_minimum_size.y=48
    for name in VARIANTS: variant.add_item(name.to_upper())
    variant.select(VARIANTS.find(current_variant)); variant.item_selected.connect(choose_variant)
    ui_button(pages.Charts,"COPY ORIGINAL INTO THIS VERSION",func():
        if current_variant=="original": report("Select EASY, NORMAL or EXPERT to create another version."); return
        var original=game.library.load_chart(str(game.song.id))
        if original.is_empty() and game.song.id=="eclipse": original=SynkChart.demo()
        game.document.checkpoint(); game.document.notes=original.duplicate(true); game.refresh_editor(); report("Copied original notes into the current version. SAVE to publish this version."))
    ui_text(pages.Sharing,"Export a chart file to share. Audio is not included; importing requires the matching song.",21)
    ui_button(pages.Sharing,"EXPORT CHART FILE",choose_export)
    ui_button(pages.Sharing,"IMPORT CHART FILE",choose_import)
    ui_text(pages.Effects,"EFFECT INTENSITY",24)
    ui_text(pages.Effects,"Changes save immediately. 0% turns an effect off. Notes and the judgment line stay visible.")
    ui_text(pages.Effects,"NOTE APPEARANCE",22)
    ui_text(pages.Effects,"Visual size only. Timing, lanes and hit detection stay the same. Hold and slide trails share one width, independent of note size.")
    var preview=preload("res://scripts/note_appearance_preview.gd").new(); preview.game=game; pages.Effects.add_child(preview)
    var sizing_sliders: Dictionary={}
    for key in ["note_size","hold_trail_width"]:
        var title="Note size" if key=="note_size" else "Hold & slide trail width"
        var value=game.note_size if key=="note_size" else game.hold_trail_width
        var label=ui_text(pages.Effects,title+" · %d%%" % roundi(value*100),19)
        var slider=HSlider.new(); pages.Effects.add_child(slider); slider.name=key.to_pascal_case()
        slider.min_value=.6 if key=="note_size" else .3; slider.max_value=1.25 if key=="note_size" else 1.5
        slider.step=.05; slider.value=value; slider.custom_minimum_size=Vector2(0,44)
        slider.tooltip_text=title; sizing_sliders[key]=slider
        slider.value_changed.connect(func(v): game.change_note_sizing(key,v); label.text=title+" · %d%%" % roundi(v*100))
    ui_button(pages.Effects,"RESET NOTE SIZES",func():
        for slider in sizing_sliders.values(): slider.value=1.0)
    ui_text(pages.Effects,"HIT & STAGE EFFECTS",22)
    effect_sliders={}
    for key in EFFECT_NAMES:
        var label=ui_text(pages.Effects,key+" · %d%%" % roundi(effect(key)*100),19)
        var slider=HSlider.new(); pages.Effects.add_child(slider)
        slider.min_value=0; slider.max_value=1; slider.step=.05; slider.value=effect(key)
        slider.custom_minimum_size=Vector2(0,44)
        slider.tooltip_text=key+" intensity"
        effect_sliders[key]=slider
        slider.value_changed.connect(func(value): set_effect(key,value); label.text=key+" · %d%%" % roundi(value*100))
    ui_button(pages.Effects,"RESTORE DEFAULT EFFECTS",func():
        for key in EFFECT_NAMES: effect_sliders[key].value=effect_default(key))
    ui_text(pages.Arrange,"TRANSFORM SELECTED RANGE",24)
    ui_text(pages.Arrange,"Select a passage with RANGE first. Each transform is one undo step; notes outside the selection stay in place.")
    ui_button(pages.Arrange,"MIRROR LANES & FLICKS",func(): game.studio.transform_range("mirror"); report(game.status.text))
    var shift=ui_field(pages.Arrange,"Shift timing · seconds",-120,120,.01,0)
    ui_button(pages.Arrange,"APPLY TIMING SHIFT",func(): game.studio.transform_range("time",shift.value); report(game.status.text))
    var lanes=ui_field(pages.Arrange,"Shift lanes",-9,9,1,0)
    ui_button(pages.Arrange,"APPLY LANE SHIFT",func(): game.studio.transform_range("lane",lanes.value); report(game.status.text))
    var repeats=ui_field(pages.Arrange,"Additional repeats",1,16,1,2)
    ui_button(pages.Arrange,"REPEAT PASSAGE",func(): game.studio.transform_range("repeat",repeats.value); report(game.status.text))
    ui_text(pages.Check,"CHART CHECK",24)
    ui_text(pages.Check,"Warnings are suggestions. These checks never move or delete notes. Tap an issue to inspect it in the editor.")
    var findings=VBoxContainer.new()
    ui_button(pages.Check,"RUN CHECK",func(): populate_checks(findings))
    pages.Check.add_child(findings); populate_checks(findings)
    scope_refresh["Check"]=func(): populate_checks(findings)
    ui_text(pages.Grid,"CHART TIMING & SECTIONS",24)
    ui_text(pages.Grid,"BPM, grid offset and section markers belong only to this chart version. SAVE publishes them; autosave protects drafts. Changes are undoable and never move notes.")
    var bpm=ui_field(pages.Grid,"Chart BPM",30,300,.01,game.chart_bpm())
    bpm.value_changed.connect(func(value): set_chart_value("bpm",value))
    var offset=ui_field(pages.Grid,"First beat · seconds",0,game.length(),.001,game.chart_offset())
    offset.value_changed.connect(game.beat_clock.set_offset)
    scope_refresh["Grid"]=func():
        bpm.set_value_no_signal(float(game.document.settings.get("bpm",game.song.get("bpm",128))))
        offset.set_value_no_signal(float(game.document.settings.get("beat_offset",0)))
    ui_button(pages.Grid,"FIRST BEAT = PLAYHEAD",func(): offset.value=game.cursor)
    for name in ["verse2","bridge"]:
        ui_button(pages.Grid,("VERSE 2" if name=="verse2" else "BRIDGE")+" = PLAYHEAD / CLEAR",func(): game.mark_section(name,game.cursor); report(game.status.text))
    ui_text(pages.Practice,"PRACTICE A PASSAGE",24)
    ui_text(pages.Practice,"Repeat a section at a slower speed. Long-note tails are included. Practice results never replace your personal best. Pause → EDITOR returns to your chart.")
    var a=ui_field(pages.Practice,"Start · seconds",0,game.length(),.01,game.timeline.range_start if game.timeline.range_active else game.cursor)
    var b=ui_field(pages.Practice,"End · seconds",0,game.length(),.01,game.timeline.range_end if game.timeline.range_active else minf(game.length(),game.cursor+8))
    var speed_row=HBoxContainer.new(); pages.Practice.add_child(speed_row)
    ui_text(speed_row,"Playback speed").custom_minimum_size.x=300
    var rate=OptionButton.new(); speed_row.add_child(rate)
    rate.custom_minimum_size=Vector2(220,46); rate.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var rates=[.25,.5,.75,1.0]
    for value in rates:
        rate.add_item(str(value)+"×"); rate.set_item_metadata(rate.item_count-1,value)
    rate.select(maxi(0,rates.find(game.practice.speed)))
    var loop=ui_button(pages.Practice,"REPEAT ON",func(): pass); loop.set_selected(true)
    loop.pressed.connect(func(): loop.set_selected(not loop.selected); loop.text="REPEAT ON" if loop.selected else "REPEAT OFF")
    ui_button(pages.Practice,"PRACTICE THIS RANGE",func():
        var notes=game.document.notes if game.mode=="editor" else game.baseline_notes()
        if game.practice.launch(notes,a.value,b.value,float(rate.get_item_metadata(rate.selected)),loop.selected): close_tools()
        else: report(game.status.text))
    pages.Practice.set_meta("chart_key",str(game.song.id)+current_variant)
    scope_refresh["Practice"]=func():
        var key=str(game.song.id)+current_variant
        if pages.Practice.get_meta("chart_key")==key: return
        a.set_value_no_signal(game.timeline.range_start if game.timeline.range_active else game.cursor)
        b.set_value_no_signal(game.timeline.range_end if game.timeline.range_active else minf(game.length(),game.cursor+8))
        pages.Practice.set_meta("chart_key",key)
    ui_text(pages.Analyze,"ESTIMATED CHART DIFFICULTY",24)
    ui_text(pages.Analyze,"A guide for comparing charts, not an official rating. Based on active-section density, peak bursts, chords, flicks and slide movement.")
    var analysis=VBoxContainer.new(); pages.Analyze.add_child(analysis)
    ui_button(pages.Analyze,"ANALYZE CURRENT DRAFT",func(): populate_analysis(analysis))
    populate_analysis(analysis)
    scope_refresh["Analyze"]=func(): populate_analysis(analysis)
    ui_text(pages.Bookmarks,"SECTION BOOKMARKS",24)
    ui_text(pages.Bookmarks,"Name a moment or selected passage in this chart version. Bookmarks save, recover and export with the chart. Tap one to jump; a bookmarked range can go into Practice.")
    var bookmark_name=LineEdit.new(); pages.Bookmarks.add_child(bookmark_name)
    bookmark_name.placeholder_text="Name · e.g. Chorus / Hard flicks"; bookmark_name.max_length=40; bookmark_name.custom_minimum_size.y=48
    var bookmark_list=VBoxContainer.new()
    ui_button(pages.Bookmarks,"BOOKMARK PLAYHEAD",func():
        report("Bookmark saved." if save_bookmark(bookmark_name.text,game.cursor,game.cursor) else "Enter a name and valid song position. Up to 64 bookmarks per song.")
        populate_bookmarks(bookmark_list))
    ui_button(pages.Bookmarks,"BOOKMARK SELECTED RANGE",func():
        if not game.timeline.range_active: report("Select a passage with RANGE first."); return
        report("Range bookmark saved." if save_bookmark(bookmark_name.text,game.timeline.range_start,game.timeline.range_end) else "Enter a name and valid range. Up to 64 bookmarks per song.")
        populate_bookmarks(bookmark_list))
    pages.Bookmarks.add_child(bookmark_list); populate_bookmarks(bookmark_list)
    scope_refresh["Bookmarks"]=func(): populate_bookmarks(bookmark_list)
    ui_text(pages.Song,"SONG DETAILS",24)
    ui_text(pages.Song,str(game.song.title)+" · "+game.album_name(game.song),24)
    ui_text(pages.Song,"Title, artist, album, track number, album art and gameplay background are shared by this song's chart versions. Edit them with DETAILS in the Chart Studio song list. Chart timing, sections and bookmarks are under THIS CHART.")
    ui_text(pages.Authoring,"PERSONAL EDITING PREFERENCES",24)
    ui_text(pages.Authoring,"These preferences apply across charts. They affect your editing/playback experience and are not written into shared chart files. Recorder controls are quick shortcuts to these same preferences.")
    ui_button(pages.Authoring,"RECORDER PREFERENCES",func(): close_tools(); game.recorder.show_setup(true))
    var mr_button=ui_button(pages.Authoring,"MR ON" if game.mr.enabled else "MR OFF",game.mr.toggle)
    mr_button.pressed.connect(func(): mr_button.text="MR ON" if game.mr.enabled else "MR OFF")
    var ghost=ui_button(pages.Authoring,"GHOST GUIDES ON" if game.ghost_recording else "GHOST GUIDES OFF",game.toggle_ghost_recording)
    ghost.pressed.connect(func(): ghost.text="GHOST GUIDES ON" if game.ghost_recording else "GHOST GUIDES OFF")
    var guides=ui_button(pages.Authoring,"ALIGNMENT LINES ON" if game.note_lines else "ALIGNMENT LINES OFF",game.toggle_note_lines)
    guides.pressed.connect(func(): guides.text="ALIGNMENT LINES ON" if game.note_lines else "ALIGNMENT LINES OFF")
    var speed=ui_button(pages.Authoring,"RECORD SPEED · "+str(game.record_speed)+"×",game.cycle_record_speed)
    speed.pressed.connect(func(): speed.text="RECORD SPEED · "+str(game.record_speed)+"×")
    var titles={"Drafts":"Draft","Arrange":"Transform","Check":"Validate","Analyze":"Difficulty","Grid":"Timing","Charts":"Chart versions","Sharing":"Chart files","Bookmarks":"Bookmarks","Practice":"Practice","Song":"Song details"}
    for name in titles: tabs.set_tab_title(TOOL_PAGES.find(name),titles[name])
    tabs.tab_changed.connect(func(_index): refresh_tools_context(); UiMotion.page(tabs))
    if global_settings:
        tabs.tabs_visible=false; tabs.current_tab=TOOL_PAGES.find(selected_tab)
        for i in TOOL_PAGES.size(): tabs.set_tab_hidden(i,TOOL_PAGES[i]!=selected_tab)
        refresh_tools_context()
    else:
        for scope in TOOL_SCOPES:
            if selected_tab in TOOL_SCOPES[scope]: show_scope(scope,selected_tab); break

func show_scope(scope: String,preferred: String="") -> void:
    if not TOOL_SCOPES.has(scope): return
    var available: Array=TOOL_SCOPES[scope]
    for i in TOOL_PAGES.size(): tabs.set_tab_hidden(i,TOOL_PAGES[i] not in available)
    tabs.current_tab=TOOL_PAGES.find(preferred if preferred in available else available[0])
    for key in scope_buttons: scope_buttons[key].set_selected(key==scope)
    refresh_tools_context()

func refresh_tools_context() -> void:
    if not is_instance_valid(tools_context) or not is_instance_valid(tabs): return
    if global_settings: tools_context.text="GAME SETTINGS · Applies to every song and chart"; return
    var page=TOOL_PAGES[tabs.current_tab]
    var song_scope=page in ["Song","Charts"]
    tools_context.text=("SONG · "+str(game.song.title)+" · Shared by all chart versions") if song_scope else ("CHART · "+str(game.song.title)+" / "+current_variant.to_upper()+" · Current draft")
    if is_instance_valid(draft_context): draft_context.text="Current version: "+current_variant.to_upper()+" · "+str(game.song.title)
    if scope_refresh.has(page): scope_refresh[page].call()
func populate_analysis(parent: VBoxContainer) -> void:
    for child in parent.get_children(): parent.remove_child(child); child.queue_free()
    var stats=preload("res://scripts/difficulty_analysis.gd").analyze(game.document.notes,game.length())
    ui_text(parent,"%s · ESTIMATED Lv. %d / 30" % [stats.tier,stats.level],32)
    ui_text(parent,"%d notes · %.2f notes/sec in active passage · Peak %.1f notes/sec over 2 seconds" % [stats.notes,stats.average,stats.peak],21)
    ui_text(parent,"%d chord groups · %d taps · %d holds · %d slides · %d flicks" % [stats.chords,stats.types.tap,stats.types.hold,stats.types.slide,stats.types.flick],21)
    ui_text(parent,"%.1f total lanes of slide movement" % stats.movement)
func bookmarks() -> Array:
    var saved=game.document.settings.get("bookmarks",[])
    return saved.duplicate(true) if saved is Array else []
func save_bookmark(title: String,a: float,b: float) -> bool:
    title=title.strip_edges().left(40)
    if title.is_empty() or not is_finite(a) or not is_finite(b) or a<0 or b<a or b>game.length()+.001: return false
    var items=bookmarks(); var index=-1
    for i in items.size():
        if str(items[i].name).to_lower()==title.to_lower(): index=i; break
    var entry={"name":title,"start":a,"end":b}
    if index>=0: items[index]=entry
    elif items.size()<64: items.append(entry)
    else: return false
    items.sort_custom(func(x,y): return float(x.start)<float(y.start))
    return set_chart_value("bookmarks",items) and autosave()==OK
func remove_bookmark(title: String) -> void:
    var items=bookmarks().filter(func(item): return str(item.name)!=title)
    if set_chart_value("bookmarks",items): autosave()
func jump_bookmark(entry: Dictionary) -> void:
    close_tools(); game.set_mode("editor"); game.timeline.clear_range()
    game.seek_to(float(entry.start))
    if float(entry.end)>float(entry.start)+.001:
        game.studio.set_tool("range"); game.timeline.range_active=true
        game.timeline.range_start=float(entry.start); game.timeline.range_end=float(entry.end); game.timeline.update_range()
func populate_bookmarks(parent: VBoxContainer) -> void:
    for child in parent.get_children(): parent.remove_child(child); child.queue_free()
    var items=bookmarks()
    if items.is_empty(): ui_text(parent,"No bookmarks yet.")
    for item in items:
        var row=HBoxContainer.new(); parent.add_child(row)
        var label="%s · %.2f s" % [item.name,item.start]
        if float(item.end)>float(item.start): label+=" → %.2f s" % item.end
        var jump=ui_button(row,label,func(): jump_bookmark(item)); jump.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        var remove=ui_button(row,"DELETE",func(): remove_bookmark(str(item.name)); populate_bookmarks(parent),"danger")
        remove.custom_minimum_size.x=120
func populate_checks(parent: VBoxContainer) -> void:
    for child in parent.get_children(): parent.remove_child(child); child.queue_free()
    var issues=preload("res://scripts/chart_audit.gd").inspect(game.document.notes,game.length())
    ui_text(parent,"No issues found." if issues.is_empty() else "%d issues found (up to 250 shown)." % issues.size(),22)
    for issue in issues:
        ui_button(parent,"%s · %.2fs · %s" % [issue.severity,float(issue.time),issue.message],func():
            close_tools(); game.set_mode("editor"); game.document.selected=int(issue.index)
            game.seek_to(float(issue.time)); game.refresh_editor())
func close_tools() -> void:
    if overlay:
        UiMotion.transition(game,.20)
        overlay.queue_free(); overlay=null
    tools_context=null; draft_context=null
func choose_export() -> void:
    if not chart_exporter:
        chart_exporter=FileDialog.new(); add_child(chart_exporter); chart_exporter.file_mode=FileDialog.FILE_MODE_SAVE_FILE; chart_exporter.access=FileDialog.ACCESS_FILESYSTEM; chart_exporter.use_native_dialog=true
        chart_exporter.filters=PackedStringArray(["*.json;SYNK chart"])
        chart_exporter.file_selected.connect(func(path): report("Chart exported." if export_chart(path)==OK else "Could not export chart."))
    chart_exporter.current_file=str(game.song.title).validate_filename()+"_"+current_variant+".synk.json"
    chart_exporter.popup_centered_ratio(.8)
func choose_import() -> void:
    if not chart_picker:
        chart_picker=FileDialog.new(); add_child(chart_picker); chart_picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE; chart_picker.access=FileDialog.ACCESS_FILESYSTEM; chart_picker.use_native_dialog=true
        chart_picker.filters=PackedStringArray(["*.json;SYNK chart"])
        chart_picker.file_selected.connect(func(path): report("Chart imported into your draft." if import_chart(path)==OK else "Invalid chart, wrong song, or notes beyond song length."))
    chart_picker.popup_centered_ratio(.8)
