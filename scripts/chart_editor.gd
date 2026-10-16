extends Panel
const UiMotion=preload("res://scripts/ui_motion.gd")
const ScreenStyle=preload("res://scripts/screen_style.gd")
var game: Control
var inspector: Control
var song_panel: Control
var help_label: Label
var note_title: Label
var type_input: OptionButton
var time_input: SpinBox
var lane_input: SpinBox
var duration_input: SpinBox
var end_lane_input: SpinBox
var duration_group: Control
var end_lane_group: Control
var direction_group: Control
var selected_actions: Control
var updating=false
var details_open=false
var tool_buttons: Dictionary={}
var direction_buttons: Dictionary={}
var details_button: Button
var range_panel: Control
var range_info: Label
var inspected_song_id=""
var range_clipboard: Array=[]
var clipboard_span=0.0
var paste_button: Button
var range_paste_button: Button
var record_button: Button
var overview: Control
var group_move_button: Button

func place(node: Control,parent: Node,l: float,t: float,r: float,b: float) -> void: game.rect(node,parent,l,t,r,b)
func caption(parent: Node,value: String,l: float,t: float,r: float,b: float,fs: int=17) -> Label: return game.label(parent,value,l,t,r,b,fs)
func action(parent: Node,value: String,l: float,t: float,r: float,b: float,callback: Callable,variant: String="tool") -> Button: return game.button(parent,value,l,t,r,b,callback,variant)
func spin(parent: Control,title: String,y: float,maximum: float,step: float,callback: Callable) -> SpinBox:
    caption(parent,title,.06,y,.94,y+.07,14).add_theme_color_override("font_color",Color("af9ccd"))
    var input=SpinBox.new(); place(input,parent,.06,y+.075,.94,y+.16)
    input.min_value=0; input.max_value=maximum; input.step=step
    input.get_line_edit().add_theme_font_size_override("font_size",18)
    input.value_changed.connect(callback)
    return input
func _ready() -> void:
    set_meta("keep_caption_size",true)
    var style=StyleBoxFlat.new(); style.bg_color=Color("080c20"); add_theme_stylebox_override("panel",style)
    ScreenStyle.glass(self,Rect2(.115,.095,.87,.08),Color("9274df"),0)
    ScreenStyle.glass(self,Rect2(.015,.18,.095,.74),Color("65dfff"),0)
    game.title_label=caption(self,"CHART STUDIO",.025,.018,.32,.075,25)
    action(self,"CHART TOOLS",.325,.02,.45,.075,func(): game.features.open_tools(),"nav")
    game.title_label.clip_text=true; game.title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    record_button=action(self,"● RECORD",.46,.02,.56,.075,game.record_here,"record")
    record_button.glare=true; record_button.art_material.set_shader_parameter("glare",1.0)
    action(self,"SETUP",.565,.02,.635,.075,game.recorder.show_setup,"tool")
    details_button=action(self,"SONG DETAILS",.645,.02,.735,.075,toggle_details,"nav")
    action(self,"SAVE",.75,.02,.85,.075,game.save_editor,"primary")
    action(self,"‹ LIBRARY",.87,.02,.98,.075,game.close_editor,"nav")
    game.play_button=action(self,"PLAY",.12,.103,.205,.16,game.toggle_audition,"secondary")
    action(self,"− BEAT",.215,.103,.285,.16,func(): game.seek_to(game.cursor-60.0/game.chart_bpm()))
    action(self,"+ BEAT",.295,.103,.365,.16,func(): game.seek_to(game.cursor+60.0/game.chart_bpm()))
    action(self,"− ZOOM",.375,.103,.45,.16,func(): game.timeline.zoom_by(1.25))
    action(self,"+ ZOOM",.46,.103,.535,.16,func(): game.timeline.zoom_by(.8))
    game.speed_button=action(self,"1×",.545,.103,.605,.16,func(): game.audition_speed=.75 if game.audition_speed==1 else (.5 if game.audition_speed==.75 else 1.0); game.audio.pitch_scale=game.audition_speed; game.refresh_editor())
    game.snap_button=action(self,"SNAP 1/16",.615,.103,.725,.16,func(): game.snap_division=2 if game.snap_division==4 else (1 if game.snap_division==2 else (0 if game.snap_division==1 else 4)); game.refresh_editor())
    game.loop_button=action(self,"LOOP OFF",.735,.103,.83,.16,func(): game.loop_enabled=not game.loop_enabled; game.refresh_editor())
    action(self,"SET A",.84,.103,.905,.16,func(): game.loop_a=game.cursor; game.loop_b=maxf(game.loop_b,minf(game.length(),game.loop_a+4)); game.refresh_editor())
    action(self,"SET B",.915,.103,.98,.16,func(): if game.cursor>game.loop_a+.1: game.loop_b=game.cursor; game.refresh_editor())
    var rail=Control.new(); place(rail,self,.02,.19,.105,.91)
    caption(rail,"TOOLS",0,0,1,.055,13).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    var names=[["select","SELECT"],["range","RANGE"],["tap","TAP"],["hold","HOLD"],["slide","SLIDE"],["flick","FLICK"]]
    for i in names.size():
        var kind: String=names[i][0]
        var b=action(rail,names[i][1],0,.075+i*.087,1,.145+i*.087,func(): set_tool(kind))
        tool_buttons[kind]=b
    action(rail,"UNDO",0,.64,1,.72,func(): game.document.undo(); game.refresh_editor())
    action(rail,"REDO",0,.74,1,.82,func(): game.document.redo(); game.refresh_editor())
    action(rail,"DELETE",0,.90,1,.98,delete_selection,"danger")
    game.timeline=Control.new(); game.timeline.set_script(load("res://scripts/timeline.gd")); game.timeline.game=game
    place(game.timeline,self,.16,.19,.765,.91)
    overview=load("res://scripts/song_overview.gd").new(); overview.game=game
    place(overview,self,.12,.19,.155,.91)
    game.seek=HSlider.new(); place(game.seek,self,.12,.925,.765,.95); game.seek.step=.001
    game.seek.value_changed.connect(func(value): if not game.updating: game.seek_to(value))
    game.info=caption(self,"",.12,.955,.48,.99,14)
    paste_button=action(self,"PASTE",.61,.955,.765,.995,paste_range)
    var panel=Panel.new(); place(panel,self,.785,.19,.98,.91)
    var glass=StyleBoxFlat.new(); glass.bg_color=Color("10142c"); glass.set_corner_radius_all(16)
    glass.border_color=Color("342449"); glass.set_border_width_all(1); panel.add_theme_stylebox_override("panel",glass)
    inspector=Control.new(); place(inspector,panel,0,0,1,1)
    note_title=caption(inspector,"NOTE INSPECTOR",.06,.025,.94,.085,20)
    help_label=caption(inspector,"",.06,.105,.94,.27,16); help_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    type_input=OptionButton.new(); place(type_input,inspector,.06,.105,.94,.17)
    for kind in SynkChart.TYPES: type_input.add_item(str(kind).to_upper())
    type_input.item_selected.connect(func(index):
        if not updating: game.document.convert(SynkChart.TYPES[index],60.0/game.chart_bpm(),game.length()); game.refresh_editor())
    selected_actions=Control.new(); place(selected_actions,inspector,0,.19,1,.91)
    time_input=spin(selected_actions,"TIME · SECONDS",0,9999,.001,func(value): change_note("time",value))
    lane_input=spin(selected_actions,"LANE",.19,SynkChart.LANES,1,func(value): change_note("lane",value-1)); lane_input.min_value=1
    duration_group=Control.new(); place(duration_group,selected_actions,0,.38,1,.58)
    duration_input=spin(duration_group,"DURATION · SECONDS",0,9999,.001,func(value): change_note("duration",value))
    # Groups occupy their full reserved row; field coordinates need a full-height parent.
    duration_input.anchor_top=.35; duration_input.anchor_bottom=.82
    duration_group.get_child(0).anchor_bottom=.3
    end_lane_group=Control.new(); place(end_lane_group,selected_actions,0,.59,1,.79)
    end_lane_input=spin(end_lane_group,"END LANE",0,SynkChart.LANES,1,func(value): change_note("end_lane",value-1)); end_lane_input.min_value=1
    end_lane_input.anchor_top=.35; end_lane_input.anchor_bottom=.82
    end_lane_group.get_child(0).anchor_bottom=.3
    direction_group=Control.new(); place(direction_group,selected_actions,.06,.40,.94,.58)
    caption(direction_group,"FLICK DIRECTION",0,0,1,.3,14)
    for i in 3:
        var direction=[3,0,1][i]
        var b=action(direction_group,["←","↑","→"][i],i*.34,.4,i*.34+.31,1,func(): change_note("direction",direction))
        direction_buttons[direction]=b
    game.slide_tools=Control.new(); place(game.slide_tools,selected_actions,.06,.82,.94,.92)
    action(game.slide_tools,"SMOOTH",0,0,.47,1,func(): game.reshape_slide("smooth"))
    action(game.slide_tools,"RESET",.53,0,1,1,func(): game.reshape_slide("reset"))
    action(selected_actions,"DUPLICATE",.06,.94,.94,1.05,game.duplicate_note)
    range_panel=Control.new(); place(range_panel,inspector,0,.11,1,.88)
    range_info=caption(range_panel,"",.06,0,.94,.19,17)
    range_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    action(range_panel,"COPY RANGE",.06,.21,.94,.29,copy_range,"primary")
    action(range_panel,"DUPLICATE AFTER",.06,.32,.94,.40,func(): duplicate_range(false))
    range_paste_button=action(range_panel,"PASTE AT PLAYHEAD",.06,.43,.94,.51,paste_range)
    action(range_panel,"TRANSFORM",.06,.54,.94,.62,func(): game.features.open_tools("Arrange"))
    group_move_button=action(range_panel,"MOVE GROUP",.06,.65,.94,.73,func(): game.timeline.toggle_group_move())
    action(range_panel,"CLEAR SELECTION",.06,.75,.94,.84,func(): game.timeline.clear_range(); set_tool("select"))
    var range_help=caption(range_panel,"Copy, move the playhead, then use PASTE below the timeline. Copies keep timing, paths and directions.",.06,.86,.94,1.04,13)
    range_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    game.status=caption(self,"",.025,.078,.80,.10,12)
    game.mr.register_button(action(self,"MR OFF",.49,.955,.60,.995,game.mr.toggle))
    action(self,"TEST FROM HERE",.785,.935,.98,.985,game.test_editor_here,"primary")
    build_song_panel(panel)
    set_tool("select")
func build_song_panel(parent: Control) -> void:
    song_panel=Control.new(); place(song_panel,parent,0,0,1,1); song_panel.visible=false
    caption(song_panel,"SONG DETAILS",.06,.025,.94,.085,20)
    game.studio_cover=TextureRect.new(); place(game.studio_cover,song_panel,.12,.105,.88,.33)
    game.studio_cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; game.studio_cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    ScreenStyle.round_cover(game.studio_cover,14)
    caption(song_panel,"TITLE",.06,.35,.94,.39,13)
    game.song_title_input=LineEdit.new(); place(game.song_title_input,song_panel,.06,.4,.94,.47)
    caption(song_panel,"ALBUM",.06,.49,.94,.53,13)
    game.song_album_input=LineEdit.new(); place(game.song_album_input,song_panel,.06,.54,.94,.61)
    for input in [game.song_title_input,game.song_album_input]:
        input.add_theme_font_size_override("font_size",17)
        input.text_submitted.connect(func(_text): game.apply_song_info())
        input.focus_exited.connect(game.apply_song_info)
    caption(song_panel,"Shared by every chart version",.06,.64,.94,.70,13)
    game.studio_cover_button=action(song_panel,"SET COVER",.06,.72,.94,.79,game.choose_cover)
    action(song_panel,"IMPORT AUDIO",.06,.81,.94,.88,game.choose_audio,"secondary")
    action(song_panel,"CHART TIMING",.06,.91,.94,.98,func(): game.features.open_tools("Grid"))
func set_tool(kind: String) -> void:
    game.editor_tool=kind
    if game.timeline and kind!="range": game.timeline.clear_range()
    elif game.timeline: game.timeline.group_mode=false
    for key in tool_buttons: tool_buttons[key].set_selected(key==kind)
    refresh_inspector()
func toggle_details() -> void:
    UiMotion.transition(self,.22)
    details_open=not details_open
    song_panel.visible=details_open; inspector.visible=not details_open
    details_button.set_selected(details_open)
func refresh_inspector() -> void:
    if overview: overview.rebuild()
    if selected_actions==null: return
    if paste_button:
        paste_button.disabled=range_clipboard.is_empty()
        paste_button.text="PASTE (%d)" % range_clipboard.size() if not range_clipboard.is_empty() else "PASTE"
        paste_button.tooltip_text="Paste copied notes at the playhead"
    if range_paste_button: range_paste_button.disabled=range_clipboard.is_empty()
    if inspected_song_id!=str(game.song.id):
        inspected_song_id=str(game.song.id)
        game.timeline.clear_range(); game.timeline.view_start=0
    var n: Dictionary=game.document.selection()
    var is_range=game.timeline and game.timeline.range_active
    updating=true
    selected_actions.visible=not n.is_empty() and not is_range; help_label.visible=n.is_empty() and not is_range
    type_input.visible=not n.is_empty() and not is_range
    range_panel.visible=is_range
    if is_range:
        game.timeline.collect_range()
        note_title.text="RANGE SELECTION"
        range_info.text="%d NOTES\n%.3f → %.3f s\n%s" % [game.timeline.range_indices.size(),game.timeline.range_start,game.timeline.range_end,"DRAG: X lanes / Y time" if game.timeline.group_mode else "Select MOVE GROUP to drag"]
        group_move_button.set_selected(game.timeline.group_mode)
        group_move_button.disabled=game.timeline.range_indices.is_empty()
        updating=false; return
    if n.is_empty():
        note_title.text="NOTE INSPECTOR"
        help_label.text=("Drag from the beginning to the end of a passage to select notes across every lane." if game.editor_tool=="range" else ("Tap a note to edit it.\n\n"+("Drag empty space to scroll. Tap to move the playhead." if game.editor_tool=="select" else "Tap a lane to place a %s note. Drag to extend holds and slides." % game.editor_tool)))+"\n\nPinch to zoom.\nTwo fingers to pan."
    else:
        note_title.text=str(n.kind).to_upper()+" NOTE"
        type_input.select(SynkChart.TYPES.find(str(n.kind)))
        time_input.max_value=game.length(); time_input.set_value_no_signal(float(n.time))
        lane_input.set_value_no_signal(float(n.lane)+1)
        duration_input.max_value=maxf(.05,game.length()-float(n.time)); duration_input.set_value_no_signal(float(n.duration))
        end_lane_input.set_value_no_signal(float(n.end_lane)+1)
        duration_group.visible=n.kind in ["hold","slide"]
        end_lane_group.visible=n.kind=="slide"
        direction_group.visible=n.kind=="flick"
        game.slide_tools.visible=n.kind=="slide"
        for key in direction_buttons: direction_buttons[key].set_selected(int(n.direction)==key)
    updating=false
func change_note(field: String,value: float) -> void:
    if updating: return
    var n: Dictionary=game.document.selection()
    if n.is_empty(): return
    game.stop_audition()
    if field!="duration": game.document.checkpoint()
    match field:
        "time": game.document.move_note(value,int(n.lane),game.length())
        "lane": game.document.move_note(float(n.time),int(value),game.length())
        "duration": game.document.resize(maxf(.05,value),game.length())
        "end_lane":
            n.end_lane=clampi(int(value),0,SynkChart.MAX_LANE)
            if n.path.size()>=2: n.path[-1].lane=float(n.end_lane)
        "direction": n.direction=int(value)
    game.refresh_editor()

func duplicate_range(at_playhead: bool = false) -> void:
    var timeline=game.timeline
    if not timeline.range_active or timeline.range_indices.is_empty(): game.tell("Select a range containing notes first."); return
    var span=float(timeline.range_end)-float(timeline.range_start)
    if span<=.001: return
    var destination=SynkChart.snap(game.cursor,game.chart_bpm(),game.snap_division,game.chart_offset()) if at_playhead else float(timeline.range_end)
    var offset=destination-float(timeline.range_start)
    var copies: Array=[]
    for i in timeline.range_indices:
        var n: Dictionary=game.document.notes[i].duplicate(true)
        n.time=float(n.time)+offset
        if n.time<0 or float(n.time)+float(n.duration)>game.length()+.001:
            game.tell("This passage does not fit before the end of the song."); return
        copies.append(n)
    game.stop_audition(); game.document.checkpoint()
    game.document.notes.append_array(copies)
    game.document.selected=-1
    timeline.range_start=destination; timeline.range_end=destination+span
    timeline.reveal_time(destination); timeline.update_range()
    game.tell("Duplicated %d notes. UNDO reverses the whole copy." % copies.size())

func transform_range(operation: String,amount: float=0) -> bool:
    var timeline=game.timeline; timeline.collect_range()
    if not timeline.range_active or timeline.range_indices.is_empty(): game.tell("Select a range containing notes first."); return false
    var span=float(timeline.range_end)-float(timeline.range_start)
    var changes: Array=[]
    var repeats=roundi(amount) if operation=="repeat" else 1
    if operation not in ["mirror","time","lane","repeat"] or repeats<1 or repeats>16: return false
    if operation in ["time","lane"] and is_zero_approx(amount): return false
    for repeat in repeats:
        for index in timeline.range_indices:
            var n: Dictionary=game.document.notes[index].duplicate(true)
            if operation=="mirror":
                n.lane=SynkChart.MAX_LANE-int(n.lane); n.end_lane=SynkChart.MAX_LANE-int(n.end_lane)
                for p in n.path: p.lane=SynkChart.MAX_LANE-float(p.lane)
                if n.kind=="flick" and int(n.direction) in [1,3]: n.direction=4-int(n.direction)
            elif operation=="lane":
                n.lane+=roundi(amount); n.end_lane+=roundi(amount)
                for p in n.path: p.lane+=roundi(amount)
            elif operation=="time": n.time+=amount
            else: n.time+=span*(repeat+1)
            if float(n.time)<0 or float(n.time)+float(n.duration)>game.length()+.001 or int(n.lane)<0 or int(n.lane)>SynkChart.MAX_LANE or int(n.end_lane)<0 or int(n.end_lane)>SynkChart.MAX_LANE:
                game.tell("Transform would move notes outside the song or lanes. Nothing changed."); return false
            for p in n.path:
                if float(p.lane)<0 or float(p.lane)>SynkChart.MAX_LANE: game.tell("Slide path would leave the highway. Nothing changed."); return false
            changes.append(n)
    game.stop_audition(); game.document.checkpoint()
    if operation=="repeat": game.document.notes.append_array(changes)
    else:
        for i in timeline.range_indices.size(): game.document.notes[timeline.range_indices[i]]=changes[i]
    if operation=="time": timeline.range_start+=amount; timeline.range_end+=amount
    timeline.update_range(); game.refresh_editor()
    game.tell("Range transformed. One UNDO restores the entire operation."); return true

func delete_selection() -> void:
    if game.timeline.range_active:
        game.timeline.collect_range()
        if game.timeline.range_indices.is_empty(): return
        game.document.checkpoint()
        for i in range(game.timeline.range_indices.size()-1,-1,-1):
            game.document.notes.remove_at(game.timeline.range_indices[i])
        game.timeline.update_range()
    else:
        game.document.delete(); game.refresh_editor()

func copy_range() -> void:
    var timeline=game.timeline
    timeline.collect_range()
    if not timeline.range_active or timeline.range_indices.is_empty():
        game.tell("Select a range containing notes first."); return
    range_clipboard=[]
    clipboard_span=float(timeline.range_end)-float(timeline.range_start)
    for i in timeline.range_indices:
        var note: Dictionary=game.document.notes[i].duplicate(true)
        note.time=float(note.time)-float(timeline.range_start)
        range_clipboard.append(note)
    set_tool("select")
    game.refresh_editor()
    game.tell("Copied %d notes. Move the playhead, then tap PASTE." % range_clipboard.size())

func paste_range() -> void:
    if range_clipboard.is_empty(): game.tell("Copy a range first."); return
    var destination=SynkChart.snap(game.cursor,game.chart_bpm(),game.snap_division,game.chart_offset())
    var copies: Array=[]
    for source in range_clipboard:
        var note: Dictionary=source.duplicate(true)
        note.time=float(note.time)+destination
        if float(note.time)<0 or float(note.time)+float(note.duration)>game.length()+.001:
            game.tell("Copied notes do not fit before the end of the song."); return
        copies.append(note)
    game.stop_audition(); game.document.checkpoint()
    game.document.notes.append_array(copies); game.document.selected=-1
    game.timeline.range_active=true
    game.timeline.range_start=destination; game.timeline.range_end=destination+clipboard_span
    game.timeline.reveal_time(destination)
    set_tool("range"); game.timeline.update_range()
    game.tell("Pasted %d notes. UNDO reverses the whole paste." % copies.size())
