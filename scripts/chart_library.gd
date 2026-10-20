extends Control
const ButtonArt=preload("res://scripts/song_browser_button.gd")
const UiMotion=preload("res://scripts/ui_motion.gd")
const DragScroll=preload("res://scripts/drag_scroll.gd")
var game: Control
var canvas: Control
var search: LineEdit
var grid: GridContainer
var scroll: ScrollContainer
var chart_cards: Array=[]
var count_label: Label
var message_label: Label
var filter_buttons: Dictionary={}
var library_filter="all"
var selected_id=""
var selected_variant=""
var entries: Array=[]
var summaries: Dictionary={}
var cache: Dictionary={}
var panel: Panel
var title_label: Label
var artist_label: Label
var info_label: Label
var cover: TextureRect
var versions: VBoxContainer
var stats_label: Label
var chart_label: Label
var density: Control
var record_button: Button
var edit_button: Button
var new_button: Button
var delete_button: Button
var empty: Label
var level_popup: Control
var level_input: Control
var level_title: Label
var level_hint: Label
var level_action="editor"
var suggest_button: Button
var suggested_level=0
var pending_action=""
var pending_id=""
var pending_variant=""
var confirm: Control
var confirm_title: Label
var confirm_body: Label
var confirm_chart_button: Button
var confirm_song_button: Button
var pending_delete: Dictionary={}
var recent: Dictionary={}
func box_style(fill: Color,edge: Color,radius: int=20) -> StyleBoxFlat:
    var s=StyleBoxFlat.new(); s.bg_color=fill; s.border_color=edge; s.set_corner_radius_all(radius); s.set_border_width_all(1); return s
func place(node: Control,parent: Control,x: float,y: float,w: float,h: float,base: Vector2=Vector2(1456,819)) -> void:
    parent.add_child(node); node.anchor_left=x/base.x; node.anchor_top=y/base.y
    node.anchor_right=(x+w)/base.x; node.anchor_bottom=(y+h)/base.y
func label(parent: Control,value: String,x: float,y: float,w: float,h: float,font_size: int,tint: Color=Color("f3f0ff"),base: Vector2=Vector2(1456,819)) -> Label:
    var n=Label.new(); place(n,parent,x,y,w,h,base); n.text=value; n.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    n.add_theme_font_size_override("font_size",roundi(font_size*1.15)); n.add_theme_color_override("font_color",tint)
    n.mouse_filter=Control.MOUSE_FILTER_IGNORE; n.clip_text=true; n.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; return n
func button(parent: Control,value: String,x: float,y: float,w: float,h: float,callback: Callable,base: Vector2=Vector2(1456,819),primary: bool=false) -> Button:
    var n=ButtonArt.new(); n.menu_motion=true; n.text=value; n.primary=primary; n.caption_size=22; place(n,parent,x,y,w,h,base); n.pressed.connect(callback); return n
func card(parent: Control,x: float,y: float,w: float,h: float,base: Vector2=Vector2(1456,819),radius: int=20) -> Panel:
    var n=Panel.new(); place(n,parent,x,y,w,h,base)
    n.add_theme_stylebox_override("panel",box_style(Color(0.041,0.041,0.041,.88),Color("2b263b"),radius)); return n
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var bg=ColorRect.new(); add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var mat=preload("res://scripts/background_motion.gd").attach(bg,preload("res://scripts/song_browser_background.gdshader"))
    mat.set_shader_parameter("ambience",Color(0.119,0.119,0.119,1))
    # Real studio footage: hands on a DJ mixer, tinted blue.
    preload("res://scripts/screen_backdrop.gd").video(self,0.42,.22,1.0,"res://assets/lobby/ui/studio_background.ogv",2.1)
    canvas=Control.new(); add_child(canvas); canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var local_theme=Theme.new(); local_theme.default_font=ThemeDB.fallback_font; canvas.theme=local_theme
    for type in ["Label","Button","LineEdit","OptionButton","PopupMenu"]: local_theme.set_font("font",type,ThemeDB.fallback_font)
    resized.connect(layout_cards); game.safe_area_changed.connect(layout_cards); layout_cards()
    button(canvas,"‹",30,18,84,84,func(): game.set_mode("menu")).caption_size=34
    label(canvas,"C H A R T   S T U D I O",136,25,580,23,12,Color("50daec"))
    label(canvas,"Chart library",136,48,580,48,36)
    search=LineEdit.new(); place(search,canvas,800,18,350,80)
    search.placeholder_text="Search songs or charts"; search.add_theme_font_size_override("font_size",18)
    var style=box_style(Color("0e0e0e"),Color("34334e"),14); style.content_margin_left=18
    search.add_theme_stylebox_override("normal",style)
    var focused=style.duplicate(); focused.border_color=Color("4bdaed"); search.add_theme_stylebox_override("focus",focused)
    search.text_changed.connect(func(_value): refresh())
    button(canvas,"+  IMPORT SONG",1174,18,252,80,game.choose_audio).accent=Color("50daec")
    var strip=card(canvas,30,105,1396,64)
    var tab_data=[["all","All songs",25,138],["draft","In progress",185,150],["charted","Ready",355,110],["recent","Recent",485,115]]
    for item in tab_data:
        var key: String=item[0]
        var tab=button(strip,item[1],item[2],0,item[3],64,func(): library_filter=key; refresh(),Vector2(1396,64))
        tab.tab=true; filter_buttons[key]=tab
    count_label=label(strip,"",1190,0,180,64,13,Color("aaa8c1"),Vector2(1396,64)); count_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    scroll=ScrollContainer.new(); place(scroll,canvas,30,181,800,598)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.scroll_deadzone=12
    var drag=preload("res://scripts/song_list_scroll.gd").new(); drag.name="DragScroll"; drag.scroll=scroll; scroll.add_child(drag)
    grid=GridContainer.new(); scroll.add_child(grid); grid.columns=1; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("v_separation",10)
    scroll.get_v_scroll_bar().custom_minimum_size.x=4
    var rail=StyleBoxFlat.new(); rail.bg_color=Color(0,0,0,0)
    scroll.get_v_scroll_bar().add_theme_stylebox_override("scroll",rail)
    var grip=StyleBoxFlat.new(); grip.bg_color=Color(.6,.55,.8,.18); grip.set_corner_radius_all(3)
    for state in ["grabber","grabber_highlight","grabber_pressed"]: scroll.get_v_scroll_bar().add_theme_stylebox_override(state,grip)
    empty=label(canvas,"No matching songs. Try another filter or import audio.",55,350,745,100,19,Color("aaa8c1"))
    empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    panel=card(canvas,850,169,576,610)
    var p=Vector2(576,610)
    label(panel,"S E L E C T E D   S O N G",24,17,390,23,11,Color("50daec"),p)
    # Song details (title, artist, album, track, album art, gameplay background) live here only;
    # the Play browser shows the same saved details.
    var details=button(panel,"✎  DETAILS",422,8,130,46,func():
        if not selected_id.is_empty(): game.open_song_details(selected_id),p)
    details.caption_size=15; details.tooltip_text="Edit song details, album art and gameplay background"
    cover=TextureRect.new(); place(cover,panel,24,48,118,118,p)
    cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
    title_label=label(panel,"",164,48,383,44,29,Color("f5f3ff"),p)
    artist_label=label(panel,"",164,92,383,28,16,Color("c1bbd6"),p)
    info_label=label(panel,"",164,127,383,28,14,Color("b5c4df"),p)
    label(panel,"C H A R T   V E R S I O N S",24,188,375,30,12,Color("50daec"),p)
    new_button=button(panel,"+ NEW",433,176,118,64,show_new_version,p); new_button.caption_size=18
    var version_scroll=ScrollContainer.new(); place(version_scroll,panel,24,246,528,140,p)
    version_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    versions=VBoxContainer.new(); version_scroll.add_child(versions); versions.size_flags_horizontal=Control.SIZE_EXPAND_FILL; versions.add_theme_constant_override("separation",8)
    chart_label=label(panel,"",24,402,262,22,11,Color("50daec"),p)
    # Level suggestion from the chart's density and patterns; tap to move the chart to it.
    suggest_button=Button.new(); place(suggest_button,panel,24,424,262,26,p); suggest_button.flat=true
    suggest_button.alignment=HORIZONTAL_ALIGNMENT_LEFT; suggest_button.add_theme_font_size_override("font_size",14)
    suggest_button.add_theme_color_override("font_color",Color("ffd257")); suggest_button.add_theme_color_override("font_hover_color",Color("ffe9a8"))
    suggest_button.pressed.connect(apply_suggested_level)
    # Saved versions of the selected level: browse and switch.
    var history=button(panel,"HISTORY",298,392,122,64,func():
        if not selected_id.is_empty(): game.open_chart_history(selected_id,selected_variant),p); history.caption_size=17
    delete_button=button(panel,"MANAGE",430,392,122,64,func():
        var entry=selected_entry()
        if not entry.is_empty(): ask_delete(entry),p); delete_button.caption_size=17
    stats_label=label(panel,"",24,451,300,43,18,Color("f5f3ff"),p)
    density=preload("res://scripts/chart_library_density.gd").new(); place(density,panel,336,456,216,41,p)
    record_button=button(panel,"●  RECORD",24,504,254,82,func(): open_selected("record"),p,true)
    edit_button=button(panel,"✎  EDIT CHART",294,504,258,82,func(): open_selected("editor"),p,true)
    record_button.caption_size=28; edit_button.caption_size=28
    record_button.material.set_shader_parameter("end_color",Vector3(.35,.1,.95))
    edit_button.material.set_shader_parameter("start_color",Vector3(.50,.22,.96))
    edit_button.material.set_shader_parameter("middle_color",Vector3(.65,.10,.94))
    message_label=label(panel,"Continue your draft or record a new take",24,584,528,20,11,Color("aaa8c1"),p)
    message_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    recent=game.prefs.get_value("chart_library","recent",{})
    build_confirm(); build_level_popup(); refresh()
    visibility_changed.connect(func():
        if not is_visible_in_tree(): pending_action=""
        elif stale: refresh())

func layout_cards() -> void:
    if not canvas: return
    var available=game.safe_rect_for(self)
    var k=maxf(.1,minf(available.size.x/1456.0,available.size.y/819.0)); canvas.position=available.position; canvas.scale=Vector2.ONE*k; canvas.size=available.size/k

const Levels=preload("res://scripts/chart_levels.gd")
func chart_file(id: String,variant: String) -> String:
    return Levels.chart_path(id,variant)
func draft_file(id: String,variant: String) -> String:
    return "user://drafts/"+id+"_"+variant+".json"
func read_chart(path: String,id: String) -> Dictionary:
    if not FileAccess.file_exists(path): cache.erase(path); return {}
    var file=FileAccess.open(path,FileAccess.READ)
    if file==null or file.get_length()>16*1024*1024: return {}
    var stamp=str(FileAccess.get_modified_time(path))+":"+str(file.get_length())
    if cache.has(path) and cache[path].stamp==stamp: return cache[path].data
    var raw=JSON.parse_string(FileAccess.get_file_as_string(path)); var data: Dictionary={}
    if raw is Dictionary and str(raw.get("song_id",""))==id:
        var notes=SynkChart.notes_from_file(raw)
        if notes is Array: data={"notes":notes,"time":FileAccess.get_modified_time(path)}
    cache[path]={"stamp":stamp,"data":data}; return data
func summary(id: String) -> Dictionary:
    var result={"versions":[],"draft":false,"charted":false,"modified":0}
    for variant in Levels.all_keys():
        var saved=read_chart(chart_file(id,variant),id); var draft=read_chart(draft_file(id,variant),id)
        var live=str(game.song.id)==id and game.features.current_variant==variant and game.document.dirty
        if saved.is_empty() and draft.is_empty() and not live: continue
        var notes: Array=game.document.notes if live else draft.get("notes",saved.get("notes",[]))
        var modified=maxi(int(saved.get("time",0)),int(draft.get("time",0)))
        result.versions.append({"key":variant,"notes":notes,"draft":live or not draft.is_empty(),"live":live,"saved":not saved.is_empty(),"modified":modified})
        result.draft=result.draft or live or not draft.is_empty(); result.charted=result.charted or not saved.is_empty(); result.modified=maxi(result.modified,modified)
    return result
func selected_entry() -> Dictionary:
    for entry in entries:
        if str(entry.id)==selected_id: return entry
    return {}
func matches(entry: Dictionary) -> bool:
    var data: Dictionary=summaries[entry.id]
    if library_filter=="draft" and not data.draft: return false
    if library_filter=="charted" and not data.charted: return false
    if library_filter=="recent" and not recent.has(entry.id): return false
    if library_filter=="new" and not data.versions.is_empty(): return false
    var query=search.text.strip_edges().to_lower()
    return query.is_empty() or (str(entry.title)+" "+str(entry.artist)+" "+" ".join(data.versions.map(func(v): return str(v.key)))).to_lower().contains(query)
# While this screen is hidden (e.g. switching songs in the song list), refreshes are
# postponed and done once when it opens, so they never stall another screen.
var stale=false
func refresh() -> void:
    if not grid or not game.lobby: return
    if not is_visible_in_tree() and is_inside_tree() and grid.get_child_count()>0: stale=true; return
    stale=false
    cache.clear()
    entries=game.lobby.all_entries(); summaries.clear()
    for entry in entries: summaries[entry.id]=summary(entry.id)
    var filtered=entries.filter(matches)
    if library_filter=="recent": filtered.sort_custom(func(a,b): return float(recent.get(a.id,0))>float(recent.get(b.id,0)))
    var existing: Dictionary={}
    for row in chart_cards: existing[row.entry.id]=row
    chart_cards.clear()
    for i in filtered.size():
        var entry: Dictionary=filtered[i]; var row=existing.get(entry.id)
        if row==null:
            row=preload("res://scripts/chart_library_row.gd").new(); row.library=self; grid.add_child(row)
            UiMotion.reveal(row,minf(.18,i*.035))
            row.pressed.connect(func(): if not DragScroll.was_dragged(scroll): select_entry(row.entry.id))
        else: existing.erase(entry.id)
        row.update_entry(entry,summaries[entry.id]); grid.move_child(row,i); chart_cards.append(row)
    for row in existing.values(): grid.remove_child(row); row.queue_free()
    for key in filter_buttons: filter_buttons[key].set_selected(key==library_filter)
    count_label.text="%d song%s" % [filtered.size(),"" if filtered.size()==1 else "s"]; empty.visible=filtered.is_empty()
    if selected_id.is_empty():
        selected_id=str(game.song.id); selected_variant=game.features.current_variant
    if not filtered.any(func(e): return str(e.id)==selected_id): selected_id=str(filtered[0].id) if not filtered.is_empty() else ""
    update_selection()
func select_entry(id: String) -> void:
    pending_action=""; selected_id=id
    selected_variant=str(game.prefs.get_value("charts",id,""))
    update_selection()
    UiMotion.reveal(panel)
func update_selection() -> void:
    if stale or (not is_visible_in_tree() and is_inside_tree() and grid and grid.get_child_count()>0): stale=true; return
    for row in chart_cards: row.set_selected(row.entry.id==selected_id)
    update_panel()
func update_panel() -> void:
    if not panel: return
    var entry=selected_entry(); panel.visible=not entry.is_empty()
    if entry.is_empty(): return
    var data=summary(selected_id); summaries[selected_id]=data
    title_label.text=entry.title; artist_label.text=entry.artist
    info_label.text="%d BPM    ·    %s" % [roundi(entry.bpm),game.lobby.duration_text(entry.duration)]
    cover.texture=game.lobby.cover_for(selected_id); game.lobby.style_cover(cover,selected_id,18)
    var found=data.versions.any(func(v): return v.key==selected_variant)
    if not found:
        selected_variant=data.versions[0].key if not data.versions.is_empty() else ""
    for child in versions.get_children(): versions.remove_child(child); child.queue_free()
    var current: Dictionary={}
    for version in data.versions:
        var key: String=version.key
        var n=ButtonArt.new(); n.menu_motion=true; versions.add_child(n); n.custom_minimum_size=Vector2(0,76)
        n.text=Levels.label(key)+"   ·   %d notes   ·   " % version.notes.size()+("Unsaved edits" if version.live else ("Draft saved" if version.draft else "Saved"))
        n.caption_size=19; n.set_selected(key==selected_variant)
        n.pressed.connect(func(): selected_variant=key; update_panel())
        if key==selected_variant: current=version
    if data.versions.is_empty():
        var hint=Label.new(); versions.add_child(hint); hint.text="No charts yet. Record or edit to begin, and choose its level."; hint.add_theme_font_size_override("font_size",16)
    var notes: Array=current.get("notes",[])
    chart_label.text=Levels.label(selected_variant).to_upper()+" CHART" if not current.is_empty() else "NEW CHART"
    suggested_level=0
    if not notes.is_empty():
        suggested_level=int(preload("res://scripts/difficulty_analysis.gd").analyze(notes,maxf(1,entry.duration)).level)
    var differs=suggested_level>0 and Levels.key(suggested_level)!=selected_variant
    suggest_button.visible=suggested_level>0
    suggest_button.text=("Suggested Lv %d  ·  tap to use" % suggested_level) if differs else ("Suggested Lv %d  ✓" % suggested_level)
    suggest_button.disabled=not differs
    var holds=notes.filter(func(n): return n.kind in ["hold","slide"]).size()
    var flicks=notes.filter(func(n): return n.kind=="flick").size()
    stats_label.text="%d Notes   ·   %d Holds   ·   %d Flicks" % [notes.size(),holds,flicks]
    stats_label.add_theme_font_size_override("font_size",18)
    density.notes=notes; density.duration=maxf(1,entry.duration); density.queue_redraw()
    var busy=not pending_action.is_empty()
    record_button.disabled=busy; edit_button.disabled=busy; new_button.disabled=busy
    delete_button.disabled=busy
    if not busy: message_label.text="Continue your draft or record a new take"
# Moves the selected chart (its file, draft and version history) to the suggested level.
func apply_suggested_level() -> void:
    if suggested_level<=0 or selected_id.is_empty() or not Levels.is_level(selected_variant): return
    var target=Levels.key(suggested_level)
    if target==selected_variant: return
    if FileAccess.file_exists(chart_file(selected_id,target)) or FileAccess.file_exists(draft_file(selected_id,target)):
        game.tell("Lv %d already has a chart for this song. Delete or move it first." % suggested_level); return
    if str(game.song.id)==selected_id and game.features.current_variant==selected_variant and game.document.dirty:
        game.tell("Save this chart first, then apply the suggested level."); return
    for pair in [[chart_file(selected_id,selected_variant),chart_file(selected_id,target)],[draft_file(selected_id,selected_variant),draft_file(selected_id,target)],
            [SynkChartVersions.folder(selected_id,selected_variant),SynkChartVersions.folder(selected_id,target)]]:
        for suffix in (["", ".bak"] if str(pair[0]).ends_with(".json") else [""]):
            var from=ProjectSettings.globalize_path(str(pair[0])+suffix)
            if FileAccess.file_exists(str(pair[0])+suffix) or DirAccess.dir_exists_absolute(from):
                DirAccess.rename_absolute(from,ProjectSettings.globalize_path(str(pair[1])+suffix))
    var old=Levels.label(selected_variant)
    if str(game.song.id)==selected_id and game.features.current_variant==selected_variant:
        game.features.current_variant=target
        game.prefs.set_value("charts",selected_id,target); game.prefs.save("user://preferences.cfg")
    selected_variant=target; cache.clear(); refresh(); game.lobby.refresh()
    game.tell("Moved %s chart to Lv %d." % [old,suggested_level])
func update_card_metadata(_id: String) -> void:
    if grid: refresh()
func set_message(value: String) -> void:
    game.tell(value)
# Creating a chart asks for its level (intensity 1-30) in a small popup.
func show_new_version() -> void: ask_level("editor")
func ask_level(action: String) -> void:
    if selected_entry().is_empty(): return
    level_action=action
    var taken=Levels.existing(selected_id)
    var suggestion=1
    while suggestion<Levels.MAX_LEVEL and Levels.key(suggestion) in taken: suggestion+=1
    level_input.value=suggestion
    level_title.text="Chart level for “%s”" % str(selected_entry().title)
    update_level_hint(); level_popup.visible=true
func update_level_hint() -> void:
    var variant=Levels.key(roundi(level_input.value))
    var exists=Levels.existing(selected_id).has(variant)
    if exists: level_hint.text="Lv %d already has a chart. CREATE opens it." % roundi(level_input.value)
    else: level_hint.text="1 is the gentlest, %d the most intense." % Levels.MAX_LEVEL
func confirm_level() -> void:
    level_popup.visible=false
    selected_variant=Levels.key(roundi(level_input.value)); open_selected(level_action)
func build_level_popup() -> void:
    level_popup=Control.new(); fraction_place(level_popup,canvas,0,0,1,1); level_popup.mouse_filter=Control.MOUSE_FILTER_STOP
    var dim=ColorRect.new(); fraction_place(dim,level_popup,0,0,1,1); dim.color=Color(0.006,0.006,0.006,.72); dim.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var card=Panel.new(); fraction_place(card,level_popup,.3,.24,.7,.76)
    var style=StyleBoxFlat.new(); style.bg_color=Color(.04,.04,.04,.97); style.border_color=Color(1,1,1,.12)
    style.set_border_width_all(1); style.set_corner_radius_all(24); style.shadow_color=Color(0,0,0,.55); style.shadow_size=24
    card.add_theme_stylebox_override("panel",style)
    fraction_label(card," ".join("CHART LEVEL".split("")),.08,.06,.92,.16,14,Color("50daec")).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    level_title=fraction_label(card,"",.06,.16,.94,.30,22); level_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    level_input=preload("res://scripts/settings_screen.gd").Stepper.new(1,Levels.MAX_LEVEL,1,1,"",0)
    fraction_place(level_input,card,.18,.34,.82,.56)
    level_input.readout.add_theme_font_size_override("font_size",40)
    level_input.value_changed.connect(func(_v): update_level_hint())
    level_hint=fraction_label(card,"",.06,.58,.94,.70,16,Color("a7aac6")); level_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    fraction_button(card,"CREATE",.08,.76,.58,.93,confirm_level,"primary")
    fraction_button(card,"CANCEL",.62,.76,.92,.93,func(): level_popup.visible=false,"nav")
    level_popup.visible=false
func open_selected(action: String) -> void:
    if selected_entry().is_empty() or not pending_action.is_empty(): return
    # A song with no chart picked yet asks for the new chart's level first.
    if not Levels.is_level(selected_variant): ask_level(action); return
    pending_id=selected_id; pending_variant=selected_variant
    var index=int(selected_entry().index)
    if str(game.song.id)==pending_id and game.loading_song_index<0:
        complete_open(action); return
    var ready=game.select_song(index)
    if ready: complete_open(action)
    elif game.loading_song_index==index:
        pending_action=action; update_panel(); set_message("Loading audio and chart…")
func complete_open(action: String) -> void:
    pending_action=""
    if game.mode!="library" or str(game.song.id)!=pending_id: return
    var index=game.features.VARIANTS.find(pending_variant)
    if game.features.current_variant!=pending_variant:
        game.features.choose_variant(index)
        if game.features.current_variant!=pending_variant: update_panel(); return
    recent[pending_id]=Time.get_unix_time_from_system()
    game.prefs.set_value("chart_library","recent",recent); game.prefs.save("user://preferences.cfg")
    game.set_mode("editor")
    if action=="record": game.record_here()
func _process(_delta: float) -> void:
    if pending_action.is_empty(): return
    if game.mode!="library" or selected_id!=pending_id: pending_action=""; return
    if game.loading_song_index>0: return
    var action=pending_action; pending_action=""
    if str(game.song.id)==pending_id: complete_open(action)
    else: update_panel(); set_message("Audio could not be loaded. Select another song or try again.")

func fraction_place(node: Control,parent: Control,l: float,t: float,r: float,b: float) -> void:
    parent.add_child(node); node.anchor_left=l; node.anchor_top=t; node.anchor_right=r; node.anchor_bottom=b
func fraction_label(parent: Control,value: String,l: float,t: float,r: float,b: float,font_size: int,tint: Color=Color("f5edff")) -> Label:
    return label(parent,value,l*1456,t*819,(r-l)*1456,(b-t)*819,font_size,tint)
func fraction_button(parent: Control,value: String,l: float,t: float,r: float,b: float,callback: Callable,_variant: String="") -> Button:
    var n=button(parent,value,l*1456,t*819,(r-l)*1456,(b-t)*819,callback)
    if _variant=="danger": n.accent=Color("ff5f7e"); n.add_theme_color_override("font_color",Color("ff9db0"))
    return n
func build_confirm() -> void:
    # Deleting is permanent, so it always asks first.
    confirm=Control.new(); fraction_place(confirm,canvas,0,0,1,1); confirm.mouse_filter=Control.MOUSE_FILTER_STOP
    var dim=ColorRect.new(); fraction_place(dim,confirm,0,0,1,1); dim.color=Color(0.006,0.006,0.006,.72); dim.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var panel=Panel.new(); fraction_place(panel,confirm,.27,.28,.73,.72)
    var style=StyleBoxFlat.new(); style.bg_color=Color(.04,.04,.04,.97); style.border_color=Color(1,1,1,.12)
    style.set_border_width_all(1); style.set_corner_radius_all(24); style.shadow_color=Color(0,0,0,.55); style.shadow_size=24
    panel.add_theme_stylebox_override("panel",style)
    confirm_title=fraction_label(panel,"",.06,.06,.94,.24,30); confirm_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    confirm_body=fraction_label(panel,"",.08,.24,.92,.58,18,Color("cfc6ea")); confirm_body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    confirm_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    confirm_chart_button=fraction_button(panel,"DELETE CHART",.06,.60,.36,.84,func(): finish_delete(false),"danger")
    confirm_song_button=fraction_button(panel,"DELETE SONG",.38,.60,.68,.84,func(): finish_delete(true),"danger")
    fraction_button(panel,"CANCEL",.70,.60,.94,.84,func(): confirm.visible=false,"nav")
    confirm.visible=false

func ask_delete(entry: Dictionary) -> void:
    if DragScroll.was_dragged(scroll): return
    pending_delete=entry.duplicate(); pending_delete["variant"]=selected_variant
    var built_in=str(entry.id)=="eclipse"
    var has_chart=FileAccess.file_exists(chart_file(str(entry.id),selected_variant)) or FileAccess.file_exists(draft_file(str(entry.id),selected_variant))
    confirm_title.text="Delete \u201c%s\u201d?" % str(entry.title)
    if built_in: confirm_body.text="Delete chart removes this level's chart and its draft. This can't be undone."
    else: confirm_body.text="Delete chart removes only this version and its draft. Delete song removes the audio and all its chart versions. This can't be undone."
    confirm_chart_button.disabled=not has_chart
    confirm_song_button.visible=not built_in
    confirm.visible=true

func finish_delete(whole_song: bool) -> void:
    confirm.visible=false
    if pending_delete.is_empty(): return
    if whole_song: game.delete_song(str(pending_delete.id))
    else:
        var id=str(pending_delete.id); var variant=str(pending_delete.variant)
        for base in [chart_file(id,variant),draft_file(id,variant)]:
            for suffix in ["", ".bak", ".tmp"]:
                if FileAccess.file_exists(base+suffix): DirAccess.remove_absolute(base+suffix)
        if str(game.song.id)==id and game.features.current_variant==variant:
            game.document.dirty=false; game.features.load_variant()
        if Levels.existing(id).is_empty() and game.song_metadata.has(id):
            game.song_metadata[id].has_chart=false; game.song_metadata[id].notes=[]; game.song_metadata[id].note_count=0
        game.tell("Chart version deleted.")
    cache.clear(); refresh(); game.lobby.refresh()
    pending_delete={}
