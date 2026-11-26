extends Control
const ButtonArt=preload("res://scripts/song_browser_button.gd")
const UiMotion=preload("res://scripts/ui_motion.gd")
const DragScroll=preload("res://scripts/drag_scroll.gd")
var cover_backdrop: Control
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
var version_scroll: ScrollContainer
var stats_label: Label
var chart_label: Label
var density: Control
var record_button: Button
var edit_button: Button
var new_button: Button
var delete_button: Button
var empty: Label
var level_popup: Control
var level_buttons: Array=[]
var selected_level=0
var level_title: Label
var level_hint: Label
var level_create_button: Button
var level_action="editor"
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
func label(parent: Control,value: String,x: float,y: float,w: float,h: float,font_size: int,tint: Color=Color("f4f1ea"),base: Vector2=Vector2(1456,819)) -> Label:
    var n=Label.new(); place(n,parent,x,y,w,h,base); n.text=value; n.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    n.add_theme_font_size_override("font_size",roundi(font_size*1.15)); n.add_theme_color_override("font_color",tint)
    n.mouse_filter=Control.MOUSE_FILTER_IGNORE; n.clip_text=true; n.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; return n
func button(parent: Control,value: String,x: float,y: float,w: float,h: float,callback: Callable,base: Vector2=Vector2(1456,819),primary: bool=false) -> Button:
    var n=ButtonArt.new(); n.menu_motion=true; n.text=value; n.primary=primary; n.caption_size=22; place(n,parent,x,y,w,h,base); n.pressed.connect(callback); return n
func card(parent: Control,x: float,y: float,w: float,h: float,base: Vector2=Vector2(1456,819),radius: int=20) -> Panel:
    var n=Panel.new(); place(n,parent,x,y,w,h,base)
    n.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); n.mouse_filter=Control.MOUSE_FILTER_IGNORE; return n
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var bg=ColorRect.new(); add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var mat=preload("res://scripts/background_motion.gd").attach(bg,preload("res://scripts/song_browser_background.gdshader"))
    mat.set_shader_parameter("ambience",Color(0.119,0.119,0.119,1))
    # The selected song's cover, softly blurred, behind the library.
    cover_backdrop=preload("res://scripts/screen_backdrop.gd").album_art(self,.72)
    canvas=Control.new(); add_child(canvas); canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
    canvas.theme=preload("res://scripts/game_theme.gd").arcade()
    resized.connect(layout_cards); game.safe_area_changed.connect(layout_cards); layout_cards()
    # Same shape as the song list. Left: the song's cover, name and details. Middle: its chart
    # versions and the selected chart's numbers. Right: filters, search and the songs.
    # Bottom right: Record and Edit chart.
    var A=preload("res://scripts/arcade_style.gd")
    panel=card(canvas,40,28,690,770)
    var p=Vector2(690,770)
    button(panel,"‹",4,0,64,64,func(): game.set_mode("menu"),p).caption_size=30
    label(panel,"Chart library",84,0,400,64,24,A.MUTED,p)
    cover=TextureRect.new(); place(cover,panel,12,84,388,388,p)
    cover.anchor_right=cover.anchor_left; cover.anchor_bottom=cover.anchor_top; cover.offset_right=388; cover.offset_bottom=388
    cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
    title_label=label(panel,"",12,486,660,70,50,A.TEXT,p); title_label.add_theme_font_override("font",A.SERIF)
    artist_label=label(panel,"",14,556,420,28,16,A.SUBTLE,p)
    info_label=label(panel,"",14,588,420,28,15,A.MUTED,p)
    # Song details (title, artist, album, track, album art, gameplay background) live here only;
    # the Play browser shows the same saved details.
    var details=button(panel,"✎  DETAILS",12,632,170,56,func():
        if not selected_id.is_empty(): game.open_song_details(selected_id),p)
    details.caption_size=17; details.tooltip_text="Edit song details, album art and gameplay background"
    # Saved versions of the selected level: browse and switch.
    var history=button(panel,"History",192,632,150,56,func():
        if not selected_id.is_empty(): game.open_chart_history(selected_id,selected_variant),p); history.caption_size=17
    delete_button=button(panel,"Manage",352,632,150,56,func():
        var entry=selected_entry()
        if not entry.is_empty(): ask_delete(entry),p); delete_button.caption_size=17
    message_label=label(panel,"Continue your draft or record a new take",14,700,660,26,13,A.MUTED,p)
    label(panel,"Chart versions",440,84,160,26,15,A.MUTED,p)
    new_button=button(panel,"+ New",600,80,90,36,show_new_version,p); new_button.caption_size=15
    version_scroll=ScrollContainer.new(); place(version_scroll,panel,432,124,256,288,p)
    version_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    version_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
    version_scroll.scroll_deadzone=12
    var version_drag=preload("res://scripts/song_list_scroll.gd").new();version_drag.name="DragScroll";version_drag.scroll=version_scroll;version_scroll.add_child(version_drag)
    versions=VBoxContainer.new(); version_scroll.add_child(versions); versions.size_flags_horizontal=Control.SIZE_EXPAND_FILL; versions.add_theme_constant_override("separation",8)
    chart_label=label(panel,"",440,424,240,26,15,A.MUTED,p)
    stats_label=label(panel,"",440,452,250,32,17,A.TEXT,p)
    density=preload("res://scripts/chart_library_density.gd").new(); place(density,panel,440,492,240,46,p)
    # Right side.
    var import_button=button(canvas,"+  Import song",760,28,180,64,game.choose_audio); import_button.caption_size=17
    var gear=preload("res://scripts/gear_button.gd").new(); gear.accent=A.CYAN; place(gear,canvas,950,28,64,64)
    gear.pressed.connect(func(): game.open_lobby_settings())
    search=LineEdit.new(); place(search,canvas,1026,30,390,60)
    search.placeholder_text="Search songs or charts"; search.add_theme_font_size_override("font_size",19)
    var style=StyleBoxFlat.new(); style.bg_color=Color(1,1,1,.07); style.set_corner_radius_all(30); style.content_margin_left=24; style.content_margin_right=16
    search.add_theme_stylebox_override("normal",style)
    var focused=style.duplicate(); focused.bg_color=Color(1,1,1,.12); search.add_theme_stylebox_override("focus",focused)
    search.text_changed.connect(func(_value): refresh())
    var tab_data=[["all","All songs",760,124],["draft","In progress",890,144],["charted","Ready",1040,96],["recent","Recent",1142,104]]
    for item in tab_data:
        var key: String=item[0]
        var tab=button(canvas,item[1],item[2],108,item[3],50,func(): library_filter=key; refresh())
        tab.tab=true; tab.caption_size=19; filter_buttons[key]=tab
    count_label=label(canvas,"",1270,116,146,34,13,A.MUTED); count_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    scroll=ScrollContainer.new(); place(scroll,canvas,752,170,668,520)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.scroll_deadzone=12
    var drag=preload("res://scripts/song_list_scroll.gd").new(); drag.name="DragScroll"; drag.scroll=scroll; scroll.add_child(drag)
    grid=GridContainer.new(); scroll.add_child(grid); grid.columns=1; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("v_separation",2)
    scroll.get_v_scroll_bar().custom_minimum_size.x=4
    var rail=StyleBoxFlat.new(); rail.bg_color=Color(0,0,0,0)
    scroll.get_v_scroll_bar().add_theme_stylebox_override("scroll",rail)
    var grip=StyleBoxFlat.new(); grip.bg_color=Color(1,1,1,.25); grip.set_corner_radius_all(3)
    for state in ["grabber","grabber_highlight","grabber_pressed"]: scroll.get_v_scroll_bar().add_theme_stylebox_override(state,grip)
    empty=label(canvas,"No matching songs. Try another filter or import audio.",772,320,628,100,19,A.MUTED)
    empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    record_button=button(canvas,"●  Record",752,708,326,96,func(): open_selected("record"),Vector2(1456,819),true)
    edit_button=button(canvas,"✎  Edit chart",1094,708,326,96,func(): open_selected("editor"),Vector2(1456,819),true)
    record_button.caption_size=26; edit_button.caption_size=26
    record_button.soft_role="record"
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
    UiMotion.cascade(panel,0.0,.03)
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
    info_label.text="%d BPM  ·  %s" % [roundi(entry.bpm),game.lobby.duration_text(entry.duration)]
    cover.texture=game.lobby.cover_for(selected_id); game.lobby.style_cover(cover,selected_id,10)
    preload("res://scripts/background_motion.gd").set_palette_from(game.lobby.backdrop_for(selected_id))
    cover_backdrop.set_art(game.lobby.backdrop_for(selected_id))
    var found=data.versions.any(func(v): return v.key==selected_variant)
    if not found:
        selected_variant=data.versions[0].key if not data.versions.is_empty() else ""
    # Keep the level buttons that are still wanted. Rebuilding them all on every update made
    # them play their entrance again, which showed as a blink.
    var wanted_keys: Array=data.versions.map(func(v): return str(v.key))
    var kept: Dictionary={}
    for child in versions.get_children():
        var level_key=str(child.get_meta("level","")) if child.get_meta("song","")==selected_id else ""
        if level_key!="" and level_key in wanted_keys and not kept.has(level_key): kept[level_key]=child
        else: versions.remove_child(child); child.queue_free()
    var current: Dictionary={}
    for i in data.versions.size():
        var version: Dictionary=data.versions[i]
        var key: String=version.key
        var n=kept.get(key)
        if n==null:
            n=ButtonArt.new(); n.menu_motion=true; versions.add_child(n); n.custom_minimum_size=Vector2(0,74)
            n.set_meta("level",key); n.set_meta("song",selected_id); n.tab=true; n.caption_size=22
            n.pressed.connect(func(): if not DragScroll.was_dragged(version_scroll): selected_variant=key; update_panel())
        versions.move_child(n,i)
        n.text=Levels.label(key)
        n.subtitle="%d note%s  ·  %s" % [version.notes.size(),"" if version.notes.size()==1 else "s",("Unsaved edits" if version.live else ("Draft" if version.draft else "Saved"))]
        n.set_selected(key==selected_variant)
        if key==selected_variant: current=version
    if data.versions.is_empty():
        var hint=Label.new(); versions.add_child(hint); hint.text="No charts yet. Record or edit to begin, and choose its level."; hint.add_theme_font_size_override("font_size",16)
        hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; hint.custom_minimum_size.x=240; hint.add_theme_color_override("font_color",Color("bcb7ad"))
    var notes: Array=current.get("notes",[])
    chart_label.text=Levels.label(selected_variant)+" chart" if not current.is_empty() else "New chart"
    var holds=notes.filter(func(n): return n.kind in ["hold","slide"]).size()
    var flicks=notes.filter(func(n): return n.kind=="flick").size()
    stats_label.text="%d note%s  ·  %d hold%s  ·  %d flick%s" % [notes.size(),"" if notes.size()==1 else "s",holds,"" if holds==1 else "s",flicks,"" if flicks==1 else "s"]
    density.notes=notes; density.duration=maxf(1,entry.duration); density.queue_redraw()
    var busy=not pending_action.is_empty()
    record_button.disabled=busy; edit_button.disabled=busy; new_button.disabled=busy
    delete_button.disabled=busy
    if not busy: message_label.text="Continue your draft or record a new take"
func update_card_metadata(_id: String) -> void:
    if grid: refresh()
func set_message(value: String) -> void:
    game.tell(value)
# Creating a chart shows every level and disables the song's existing charts.
func show_new_version() -> void: ask_level("editor")
func ask_level(action: String) -> void:
    if selected_entry().is_empty(): return
    level_action=action
    show_available_levels(occupied_levels())
    level_title.text=str(selected_entry().title)
    update_level_hint(); level_popup.visible=true
func show_available_levels(taken:Array)->void:
    var suggestion=1
    while suggestion<Levels.MAX_LEVEL and Levels.key(suggestion) in taken: suggestion+=1
    for level in range(1,Levels.MAX_LEVEL+1):
        level_buttons[level-1].disabled=Levels.key(level) in taken
        level_buttons[level-1].set_selected(false)
    selected_level=0
    if Levels.key(suggestion) not in taken: select_level(suggestion)
    update_level_hint()
# The five intensity bands a level falls in (six levels each), as the song list's dots show them.
const LEVEL_BANDS=[
    {"name":"Easy","color":Color("7fe3b0"),"about":"Relaxed. Mostly single taps, with room to breathe."},
    {"name":"Normal","color":Color("6cc7ff"),"about":"Steady. Holds and simple slides join in."},
    {"name":"Hard","color":Color("ffd166"),"about":"Busy. Faster runs, chords and flicks."},
    {"name":"Expert","color":Color("ff8a5c"),"about":"Demanding. Dense patterns and quick slides."},
    {"name":"Master","color":Color("ff6f91"),"about":"Everything at once, for players who know the song by heart."}]
func update_level_hint() -> void:
    var full=selected_level==0
    if level_create_button:
        level_create_button.disabled=full
        level_create_button.text="NO LEVEL LEFT" if full else "CREATE LEVEL %d CHART" % selected_level
    if level_number==null: return
    level_hint.text="Every level of this song already has a chart." if full else "Dimmed levels already have a chart."
    level_number.text="—" if full else "Lv %d" % selected_level
    var band: Dictionary=LEVEL_BANDS[clampi(floori(float(maxi(selected_level,1)-1)/6.0),0,4)]
    var index=LEVEL_BANDS.find(band)
    level_band.text="" if full else str(band.name)
    level_band.add_theme_color_override("font_color",band.color)
    level_dots.text="" if full else "●".repeat(index+1)+"○".repeat(4-index)
    level_dots.add_theme_color_override("font_color",band.color)
    level_about.text="" if full else str(band.about)
func select_level(level: int) -> void:
    if level<1 or level>Levels.MAX_LEVEL or level_buttons[level-1].disabled:return
    selected_level=level
    for i in level_buttons.size():level_buttons[i].set_selected(i+1==level)
    update_level_hint()
func occupied_levels() -> Array:
    var taken=Levels.existing(selected_id)
    for version in summary(selected_id).versions:
        if Levels.is_level(str(version.key)) and not taken.has(version.key):taken.append(version.key)
    return taken
func confirm_level() -> void:
    if selected_level==0 or occupied_levels().has(Levels.key(selected_level)):update_level_hint();return
    level_popup.visible=false
    selected_variant=Levels.key(selected_level); open_selected(level_action)
var level_number: Label
var level_band: Label
var level_dots: Label
var level_about: Label
# New chart: the chosen level, large, with what that intensity means on the left; all thirty
# levels on the right, one row per intensity band.
func build_level_popup() -> void:
    level_popup=Control.new(); fraction_place(level_popup,canvas,0,0,1,1); level_popup.mouse_filter=Control.MOUSE_FILTER_STOP
    preload("res://scripts/modal_input.gd").register(level_popup)
    var dim=ColorRect.new(); fraction_place(dim,level_popup,0,0,1,1); dim.color=Color(0.006,0.006,0.006,.78); dim.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var card=Panel.new(); fraction_place(card,level_popup,.06,.07,.94,.93)
    var style=StyleBoxFlat.new(); style.bg_color=Color("17181b"); style.border_color=Color(1,1,1,.08)
    style.set_border_width_all(1); style.set_corner_radius_all(26); style.shadow_color=Color(0,0,0,.55); style.shadow_size=24
    card.add_theme_stylebox_override("panel",style)
    # Left: what is being made.
    var side=Panel.new(); fraction_place(side,card,.03,.05,.33,.95)
    var side_style=StyleBoxFlat.new(); side_style.bg_color=Color("212226"); side_style.set_corner_radius_all(20)
    side.add_theme_stylebox_override("panel",side_style); side.mouse_filter=Control.MOUSE_FILTER_IGNORE
    fraction_label(side,"New chart",.1,.06,.9,.13,16,Color("bcb7ad"))
    level_title=fraction_label(side,"",.1,.13,.9,.27,22); level_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    level_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; level_title.max_lines_visible=2
    level_number=fraction_label(side,"",.1,.32,.9,.56,84); level_number.add_theme_font_override("font",preload("res://scripts/arcade_style.gd").SERIF)
    level_band=fraction_label(side,"",.1,.58,.6,.66,24)
    level_dots=fraction_label(side,"",.6,.58,.9,.66,20); level_dots.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    level_about=fraction_label(side,"",.1,.68,.9,.92,17,Color("bcb7ad")); level_about.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    level_about.vertical_alignment=VERTICAL_ALIGNMENT_TOP
    # Right: the thirty levels, six to a band.
    fraction_label(card,"Pick a level",.37,.05,.97,.12,22)
    var choices=Control.new();fraction_place(choices,card,.37,.14,.97,.74)
    var name_width=.16; var gap=.012
    for row_index in LEVEL_BANDS.size():
        var band: Dictionary=LEVEL_BANDS[row_index]
        var height=(1.0-gap*4.0)/5.0; var top=row_index*(height+gap)
        var caption=fraction_label(choices,str(band.name),0,top,name_width-.02,top+height,17,band.color)
        caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
        for column in 6:
            var level=row_index*6+column+1
            var width=(1.0-name_width-gap*5.0)/6.0
            var left=name_width+column*(width+gap)
            var choice=ButtonArt.new();choice.text=str(level);choice.caption_size=22;choice.menu_motion=true
            fraction_place(choice,choices,left,top,left+width,top+height)
            choice.pressed.connect(Callable(self,"select_level").bind(level))
            level_buttons.append(choice)
    level_hint=fraction_label(card,"",.37,.75,.97,.81,15,Color("9a968d"))
    fraction_button(card,"CANCEL",.37,.845,.55,.95,func(): level_popup.visible=false,"nav")
    level_create_button=button(card,"CREATE CHART",.57*1456,.845*819,.40*1456,.105*819,confirm_level,Vector2(1456,819),true)
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
func fraction_label(parent: Control,value: String,l: float,t: float,r: float,b: float,font_size: int,tint: Color=Color("f4f1ea")) -> Label:
    return label(parent,value,l*1456,t*819,(r-l)*1456,(b-t)*819,font_size,tint)
func fraction_button(parent: Control,value: String,l: float,t: float,r: float,b: float,callback: Callable,_variant: String="") -> Button:
    var n=button(parent,value,l*1456,t*819,(r-l)*1456,(b-t)*819,callback)
    if _variant=="danger": n.accent=Color("ff5f7e"); n.add_theme_color_override("font_color",Color("ff9db0"))
    return n
func build_confirm() -> void:
    # Deleting is permanent, so it always asks first.
    confirm=Control.new(); fraction_place(confirm,canvas,0,0,1,1); confirm.mouse_filter=Control.MOUSE_FILTER_STOP
    preload("res://scripts/modal_input.gd").register(confirm)
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
