extends Node
# Recorder preferences are global; punch boundaries and takes belong to this session.
const Motion=preload("res://scripts/ui_motion.gd")
const Action=preload("res://scripts/recorder_action.gd")
const Audit=preload("res://scripts/chart_audit.gd")
var progress: ProgressBar
var game: Control
var region=Vector2.ZERO
var use_range=false
var replace=false
var loop_takes=false
var pre_roll=0
# Seconds of play-in before the chart runs out when recording resumes after a pause or CORRECT.
var resume_lead=2
var quantize="free"
var division=4
var pass_kind="all"
var locked: Array=[]
var takes: Array=[]
var baseline: Array=[]
var active=false
var continuing=false
var provisional=false
var bank_key=""
var review: Control
var setup: Control
var take_picker: OptionButton
var compare_label: Label
var warnings_label: Label
var highlights: Dictionary={}
var selected_take=0
var reviewing_audio=false
var review_panel: Control
var review_dim: ColorRect
var replay_return: Button
var auto_round=false
var pending_warnings: Array=[]
var review_notes: Array=[]
var config: Dictionary={}

func _ready() -> void:
    pre_roll=clampi(int(game.prefs.get_value("recorder","pre_roll",0)),0,4)
    resume_lead=clampi(int(game.prefs.get_value("recorder","resume_lead",2)),1,3)
    quantize=str(game.prefs.get_value("recorder","quantize","free"))
    if quantize not in ["free","soft","strict"]: quantize="free"
    division=clampi(int(game.prefs.get_value("recorder","division",4)),1,8)

func key() -> String: return str(game.song.id)+":"+game.features.current_variant
func locks() -> Array: return config.get("locked",locked)
func current_pass() -> String: return str(config.get("pass",pass_kind))
func looping() -> bool: return bool(config.get("loop",loop_takes))
func writable(n: Dictionary) -> bool:
    return n.kind not in locks() and (current_pass()=="all" or n.kind==current_pass())
func can_capture(at: float) -> bool: return active and at>=region.x and at<region.y
func capture_tool() -> String: return game.tool if current_pass()=="all" else current_pass()

func begin() -> void:
    close_review()
    if setup: setup.queue_free(); setup=null
    if not continuing or bank_key!=key():
        config={"locked":locked.duplicate(),"pass":pass_kind,"loop":loop_takes,"replace":replace,"pre_roll":pre_roll,"quantize":quantize,"division":division}
        takes.clear(); highlights.clear(); provisional=false
        baseline=game.document.notes.duplicate(true)
        var start=clampf(game.cursor,0,maxf(0,game.length()-.02))
        region=Vector2(start,game.length())
        if use_range and game.timeline and game.timeline.range_active:
            region=Vector2(game.timeline.range_start,game.timeline.range_end)
        elif use_range and game.loop_b>game.loop_a+.05:
            region=Vector2(game.loop_a,game.loop_b)
        region.x=clampf(region.x,0,maxf(0,game.length()-.02))
        region.y=clampf(region.y,region.x+.01,game.length())
        bank_key=key()
    continuing=false; active=true; auto_round=false
    game.start_position=maxf(0,region.x-int(config.pre_roll)*4*60.0/game.chart_bpm())
    game.song_time=game.start_position-game.countdown
    game.tool="auto" if current_pass()=="all" else current_pass()

func seal_gestures() -> void:
    for id in game.capture.gestures.keys():
        var g: Dictionary=game.capture.gestures[id]
        game.capture.end(id,minf(game.song_time,region.y),g.position)

func snap_time(at: float) -> float:
    var step=60.0/game.chart_bpm()/int(config.get("division",division))
    return game.chart_offset()+roundf((at-game.chart_offset())/step)*step

func spacing_blockers() -> Array:
    var result: Array=[]
    for note in game.document.notes:
        if bool(config.get("replace",replace)) and writable(note) and float(note.time)>=region.x and float(note.time)<region.y: continue
        result.append(note)
    return result

func prepare(source: Array) -> Array:
    var result: Array=[]
    for original in source:
        if not writable(original) or float(original.time)<region.x or float(original.time)>=region.y: continue
        var n: Dictionary=original.duplicate(true)
        var old_duration=float(n.duration)
        var old_end=float(n.time)+old_duration
        var timing=str(config.get("quantize",quantize))
        var strength=0.0 if timing=="free" else (.5 if timing=="soft" else 1.0)
        n.time=clampf(lerpf(float(n.time),snap_time(float(n.time)),strength),region.x,region.y-.001)
        if n.kind in ["hold","slide"]:
            var new_end=clampf(lerpf(old_end,snap_time(old_end),strength),float(n.time)+.001,region.y)
            n.duration=new_end-float(n.time)
            if n.duration<.04: continue
            var ratio=float(n.duration)/maxf(.001,old_duration)
            for point in n.path: point.offset=float(point.offset)*ratio
            if n.has("checkpoints"):
                for i in n.checkpoints.size(): n.checkpoints[i]=float(n.checkpoints[i])*ratio
        result.append(n)
    result.sort_custom(func(a,b): return float(a.time)<float(b.time))
    game.space_authored_notes(result,spacing_blockers())
    return result

func merged(notes: Array) -> Array:
    var result: Array=[]
    for n in baseline:
        if not notes.is_empty() and bool(config.get("replace",replace)) and writable(n) and float(n.time)>=region.x and float(n.time)<region.y: continue
        result.append(n.duplicate(true))
    result.append_array(notes.duplicate(true))
    result.sort_custom(func(a,b): return float(a.time)<float(b.time))
    return result

func finish() -> bool:
    if not active: return false
    seal_gestures(); active=false
    var notes=prepare(game.capture.notes)
    takes.append({"notes":notes,"raw":game.capture.notes.duplicate(true)})
    selected_take=takes.size()-1
    if looping() and auto_round and takes.size()<32:
        continuing=true
        game.record_here()
        return true
    # A manual correction to an existing unlocked note must survive take review.
    baseline=game.document.notes.duplicate(true)
    return false

func apply_take(notes: Array) -> void:
    review_notes=notes.duplicate(true)
    if notes.is_empty() and not provisional:
        pending_warnings=quality(game.document.notes); return
    if not provisional:
        game.document.checkpoint(); provisional=true
    game.document.notes=merged(notes); game.document.selected=-1; game.document.dirty=true
    highlights.clear()
    for n in notes: highlights[JSON.stringify(n)]=true
    pending_warnings=quality(game.document.notes)
    game.features.autosave(); game.refresh_editor()

func quality(notes: Array) -> Array:
    var result=Audit.inspect(notes,game.length())
    var ordered=notes.duplicate(); ordered.sort_custom(func(a,b): return float(a.time)<float(b.time))
    for i in ordered.size():
        var n: Dictionary=ordered[i]
        if n.kind in ["hold","slide"] and float(n.duration)<.12:
            result.append({"time":n.time,"message":"Very short sustained note; check for an accidental hold"})
        for j in range(i+1,mini(i+12,ordered.size())):
            var other: Dictionary=ordered[j]
            if float(other.time)-float(n.time)>.075: break
            if n.lane==other.lane:
                result.append({"time":other.time,"message":"Possible accidental double tap in lane %d" % (int(n.lane)+1)}); break
        if result.size()>=250: break
    return result

func comparison(before: Array,after: Array) -> Dictionary:
    var used: Dictionary={}; var added=0; var shifted=0; var total=0.0
    for n in after:
        var best=-1; var distance=.251
        for i in before.size():
            var previous: Dictionary=before[i]
            if used.has(i) or n.lane!=previous.lane or n.kind!=previous.kind: continue
            var delta=absf(float(n.time)-float(previous.time))
            if delta<distance: best=i; distance=delta
        if best<0: added+=1
        else:
            used[best]=true
            if distance>.002: shifted+=1; total+=distance
    return {"added":added,"removed":before.size()-used.size(),"shifted":shifted,"ms":total*1000/maxi(1,shifted)}

func select_take(index: int) -> void:
    selected_take=index
    apply_take(takes[index].notes)
    update_review()

func combine(first: int,second: int,split: float) -> Array:
    var result: Array=[]
    for n in takes[first].notes:
        if float(n.time)<split: result.append(n.duplicate(true))
    for n in takes[second].notes:
        if float(n.time)>=split: result.append(n.duplicate(true))
    # Trim a sustained note from the first take at the splice boundary.
    for n in result:
        if float(n.time)<split and float(n.time)+float(n.duration)>split:
            n.duration=split-float(n.time)
            if n.kind=="slide":
                var end=SynkChart.lane_at(n,split)
                n.path=n.path.filter(func(p): return float(p.offset)<float(n.duration))
                n.end_lane=clampi(roundi(end),0,SynkChart.MAX_LANE)
                n.path.append({"offset":float(n.duration),"lane":float(n.end_lane)})
            if n.has("checkpoints"): n.checkpoints=n.checkpoints.filter(func(t): return float(t)<float(n.duration))
    return result

func undo_take() -> void:
    if provisional and bank_key==key():
        game.document.undo(); provisional=false; game.features.draft_hash=0; game.features.autosave(); game.refresh_editor()
    highlights.clear()

func retry() -> void:
    undo_take(); close_review()
    continuing=true; game.cursor=region.x; game.record_here()

func close_review() -> void:
    if reviewing_audio: game.stop_audition(); reviewing_audio=false
    if review: review.queue_free(); review=null
    review_panel=null; review_dim=null; replay_return=null

func keep() -> void:
    close_review(); provisional=false; highlights.clear(); game.refresh_editor()
    game.tell("Take kept in your draft. SAVE publishes the chart.")

func preview() -> void:
    if reviewing_audio: stop_preview(); return
    game.stop_audition(); game.cursor=maxf(0,region.x-.3)
    game.audio.pitch_scale=game.audition_speed; game.audio.play(game.cursor)
    reviewing_audio=true
    if review_panel: review_panel.visible=false
    if review_dim: review_dim.color.a=0
    if replay_return: replay_return.visible=true

func stop_preview() -> void:
    game.stop_audition(); reviewing_audio=false
    if review_panel: review_panel.visible=true
    if review_dim: review_dim.color.a=.55
    if replay_return: replay_return.visible=false

func _process(_delta: float) -> void:
    if progress and game.mode=="record":
        progress.value=clampf((game.song_time-region.x)/maxf(.001,region.y-region.x)*100,0,100)
    if active and game.mode=="record" and not game.arranging and game.countdown==0 and game.resume_countdown==0 and game.song_time>=region.y:
        auto_round=true; game.stop_take()
    if reviewing_audio and (game.mode!="editor" or game.chart_time()>=region.y or not game.audio.playing):
        stop_preview()

func text(parent: Node,value: String,font_size: int=18) -> Label:
    var label=Label.new(); parent.add_child(label); label.text=value
    label.add_theme_font_size_override("font_size",font_size)
    label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    return label
func button(parent: Node,title: String,callback: Callable,role: String="tool") -> Button:
    var b=Action.new(); b.text=title; b.variant=role; b.caption_size=21; b.custom_minimum_size=Vector2(0,60)
    parent.add_child(b); b.pressed.connect(callback); return b
func choice(parent: Node,title: String,items: Array,current: int,callback: Callable) -> OptionButton:
    text(parent,title,16)
    var picker=OptionButton.new(); parent.add_child(picker); picker.custom_minimum_size.y=56
    picker.add_theme_font_size_override("font_size",20)
    picker.get_popup().add_theme_font_size_override("font_size",20)
    picker.get_popup().add_theme_constant_override("v_separation",16)
    for item in items: picker.add_item(str(item))
    picker.select(clampi(current,0,items.size()-1)); picker.item_selected.connect(callback); return picker
func number(parent: Node,title: String,value: float,low: float,high: float,step: float,callback: Callable) -> SpinBox:
    text(parent,title,16)
    var spinner=SpinBox.new(); parent.add_child(spinner); spinner.min_value=low; spinner.max_value=high; spinner.step=step; spinner.value=value; spinner.custom_minimum_size.y=56
    spinner.add_theme_font_size_override("font_size",20)
    spinner.value_changed.connect(callback); return spinner
func toggle(parent: Node,title: String,value: bool,callback: Callable) -> void:
    var b=button(parent,title+(" · ON" if value else " · OFF"),func(): pass)
    b.toggle_mode=true; b.button_pressed=value; b.set_selected(value)
    b.toggled.connect(func(on): b.text=title+(" · ON" if on else " · OFF"); b.set_selected(on); callback.call(on))
func shell(title: String,narrow: bool=false) -> Dictionary:
    var root=Control.new(); game.ui.add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var dim=ColorRect.new(); root.add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.color=Color(0.007,0.007,0.007,.55)
    var safe_content=game.safe_parent("SafeDialogControls",root)
    var panel=Panel.new(); game.rect(panel,safe_content,.55 if narrow else .14,.05,.98 if narrow else .86,.95)
    var style=StyleBoxFlat.new(); style.bg_color=Color(.035,.035,.035,.96); style.border_color=Color(1,1,1,.1); style.set_border_width_all(1)
    style.set_corner_radius_all(26); style.shadow_color=Color(0,0,0,.5); style.shadow_size=24; panel.add_theme_stylebox_override("panel",style)
    panel.set_meta("keep_caption_size",true)
    var plate=StyleBoxFlat.new(); plate.bg_color=Color("121212"); plate.border_color=Color("3e4663")
    plate.set_border_width_all(1); plate.set_corner_radius_all(20)
    panel.add_theme_stylebox_override("panel",plate)
    game.label(panel,title,.04,.02,.76,.105,26)
    var done=Action.new(); done.text="KEEP" if narrow else "DONE"; done.variant="primary"; done.caption_size=21
    game.rect(done,panel,.79,.025,.96,.10)
    done.pressed.connect(func():
        if narrow: keep()
        elif setup: setup.queue_free(); setup=null)
    var scroll=ScrollContainer.new(); game.rect(scroll,panel,.04,.13,.96,.97)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    var box=VBoxContainer.new(); scroll.add_child(box); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation",12)
    preload("res://scripts/interface_life.gd").mount(panel)
    Motion.pop(panel); return {"root":root,"box":box,"panel":panel,"dim":dim}
func persist(name: String,value: Variant) -> void:
    game.prefs.set_value("recorder",name,value); game.prefs.save("user://preferences.cfg")

func setup_group(parent: Node,title: String) -> VBoxContainer:
    var card=PanelContainer.new(); parent.add_child(card)
    var plate=StyleBoxFlat.new(); plate.bg_color=Color("171717"); plate.border_color=Color("2e354d")
    plate.set_corner_radius_all(16); plate.set_border_width_all(1)
    for edge in ["left","right","top","bottom"]: plate.set("content_margin_"+edge,18)
    card.add_theme_stylebox_override("panel",plate)
    var contents=VBoxContainer.new(); card.add_child(contents); contents.add_theme_constant_override("separation",12)
    var heading=text(contents,title,15); heading.add_theme_color_override("font_color",Color("7fd7e7"))
    return contents

func show_setup(global_only: bool=false) -> void:
    if setup: return
    if game.mode=="record": game.toggle_pause()
    if reviewing_audio: game.stop_audition(); reviewing_audio=false
    var s=shell("RECORDING SETUP"); setup=s.root; var box: VBoxContainer=s.box
    text(box,"Global recorder preferences" if global_only else "Applies to your next new session. For punch-in, select a range in the editor or set A / B. Types and locks remain fixed across loop takes.")
    if not global_only:
        var session=setup_group(box,"SESSION RANGE")
        toggle(session,"PUNCH IN · USE SELECTED RANGE / A–B",use_range,func(on): use_range=on)
        choice(session,"Existing notes in the section",["LAYER · keep existing notes","REPLACE · overwrite unlocked pass types"],1 if replace else 0,func(i): replace=i==1)
        toggle(session,"LOOP TAKES · stop to review up to 32 attempts",loop_takes,func(on): loop_takes=on)
    var timing=setup_group(box,"TIMING & GRID")
    choice(timing,"Audible pre-roll · bars of 4 beats",["OFF","1 BAR","2 BARS","3 BARS","4 BARS"],pre_roll,func(i): pre_roll=i; persist("pre_roll",i))
    choice(timing,"Resume lead-in · play-in before the chart runs out",["1 SECOND","2 SECONDS","3 SECONDS"],resume_lead-1,func(i): resume_lead=i+1; persist("resume_lead",i+1))
    choice(timing,"Recording timing",["FREE · preserve your timing","SOFT SNAP · 50% toward grid","STRICT SNAP · align to grid"],["free","soft","strict"].find(quantize),func(i): quantize=["free","soft","strict"][i]; persist("quantize",quantize))
    choice(timing,"Grid subdivision per beat",["1 · quarter notes","2 · eighth notes","4 · sixteenth notes","8 · thirty-second notes"],[1,2,4,8].find(division),func(i): division=[1,2,4,8][i]; persist("division",division))
    if not global_only:
        var types=setup_group(box,"NOTE TYPES & PROTECTION")
        choice(types,"Recording pass",["ALL TYPES","TAPS ONLY","HOLDS ONLY","SLIDES ONLY","FLICKS ONLY"],["all","tap","hold","slide","flick"].find(pass_kind),func(i): pass_kind=["all","tap","hold","slide","flick"][i])
        text(types,"Lock completed types · protects them from replacement and correction",16)
        for kind in SynkChart.TYPES:
            toggle(types,"LOCK "+str(kind).to_upper(),kind in locked,func(on):
                if on and kind not in locked: locked.append(kind)
                elif not on: locked.erase(kind))
    var guide=setup_group(box,"RHYTHM GUIDE")
    toggle(guide,"RHYTHM GUIDE · accented downbeat",game.beat_clock.enabled,func(on):
        game.beat_clock.enabled=on; game.beat_clock.last_time=-1; game.prefs.set_value("editor","metronome",on); game.prefs.save("user://preferences.cfg"))
    choice(guide,"Guide subdivisions",["BEATS","EIGHTHS","SIXTEENTHS"],[1,2,4].find(game.beat_clock.subdivision),func(i): game.beat_clock.subdivision=[1,2,4][i]; persist("guide_subdivision",game.beat_clock.subdivision))
    number(guide,"Guide volume · dB",game.beat_clock.guide_db,-30,0,1,func(v): game.beat_clock.guide_db=v; persist("guide_db",v))
    button(box,"DONE",func(): setup.queue_free(); setup=null,"primary")

func show_review() -> void:
    if takes.is_empty(): return
    close_review()
    game.seek_to(region.x)
    if game.timeline: game.timeline.reveal_time(region.x)
    review=Control.new(); game.ui.add_child(review); review.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    review_dim=ColorRect.new(); review.add_child(review_dim); review_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    review_dim.color=Color(0.007,0.007,0.007,.72)
    var safe=game.safe_parent("SafeTakeReview",review)
    review_panel=Panel.new(); game.rect(review_panel,safe,.10,.07,.90,.95); review_panel.set_meta("keep_caption_size",true)
    var plate=StyleBoxFlat.new(); plate.bg_color=Color("121212"); plate.border_color=Color("3e4663")
    plate.set_border_width_all(1); plate.set_corner_radius_all(22); review_panel.add_theme_stylebox_override("panel",plate)
    game.label(review_panel,"TAKE REVIEW",.035,.025,.80,.10,30)
    game.label(review_panel,"%.2f–%.2f s · %s · %s" % [region.x,region.y,"REPLACE" if bool(config.get("replace",replace)) else "LAYER",current_pass().to_upper()],.035,.105,.965,.16,17)
    var left=review_column(review_panel,Rect2(.035,.20,.445,.58),"TAKE SUMMARY")
    var right=review_column(review_panel,Rect2(.51,.20,.455,.58),"TAKE SELECTION")
    compare_label=text(left,"",20)
    warnings_label=text(left,"",17)
    var titles: Array=[]
    for i in takes.size(): titles.append("TAKE %d · %d notes" % [i+1,takes[i].notes.size()])
    take_picker=choice(right,"Choose the attempt to keep",titles,selected_take,select_take)
    take_picker.disabled=takes.size()<2
    if takes.size()>1:
        text(right,"COMBINE TWO TAKES",17)
        var first=choice(right,"First half",titles,0,func(_i): pass)
        var second=choice(right,"Second half",titles,selected_take,func(_i): pass)
        var split=number(right,"Splice at song time · seconds",(region.x+region.y)*.5,region.x,region.y,.001,func(_v): pass)
        button(right,"APPLY COMBINED TAKE",func():
            var combined=combine(first.selected,second.selected,split.value)
            apply_take(combined); update_review(); compare_label.text="COMBINED · %d notes\n" % combined.size()+compare_label.text)
    else:
        text(right,"Replay to check your timing. Retry to record another attempt in the same section.",18)
        text(right,"Keep Take returns to the editor. Save there when you are ready to publish your chart.",18)
    game.label(review_panel,"Your take stays in the draft until you SAVE the chart.",.035,.795,.965,.835,16)
    review_action("UNDO TAKE",.035,.255,func(): undo_take(); close_review(); game.tell("Take undone. Earlier chart notes restored."),"danger")
    review_action("RETRY SECTION",.275,.495,retry,"record")
    review_action("REPLAY TAKE",.515,.735,preview,"secondary")
    review_action("KEEP TAKE",.755,.965,keep,"primary")
    replay_return=Action.new(); replay_return.text="BACK TO TAKE REVIEW"; replay_return.variant="secondary"; replay_return.caption_size=21
    game.rect(replay_return,safe,.33,.015,.67,.09); replay_return.pressed.connect(stop_preview); replay_return.visible=false
    preload("res://scripts/interface_life.gd").mount(review_panel)
    Motion.pop(review_panel)
    update_review()

func review_action(title: String,left: float,right: float,callback: Callable,role: String) -> void:
    var action=Action.new(); action.text=title; action.variant=role; action.caption_size=21
    game.rect(action,review_panel,left,.86,right,.965); action.pressed.connect(callback)

func review_column(parent: Control,bounds: Rect2,title: String) -> VBoxContainer:
    var panel=Panel.new(); game.rect(panel,parent,bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y)
    var plate=StyleBoxFlat.new(); plate.bg_color=Color("171717"); plate.border_color=Color("2e354d")
    plate.set_border_width_all(1); plate.set_corner_radius_all(16); panel.add_theme_stylebox_override("panel",plate)
    var scroll=ScrollContainer.new(); game.rect(scroll,panel,.045,.04,.955,.96); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    var drag=preload("res://scripts/song_list_scroll.gd").new(); drag.scroll=scroll; scroll.add_child(drag)
    var box=VBoxContainer.new(); scroll.add_child(box); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation",16)
    var heading=text(box,title,15); heading.add_theme_color_override("font_color",Color("7fd7e7"))
    return box

func update_review() -> void:
    if not review: return
    var selected: Array=review_notes
    var prior: Array=takes[selected_take-1].notes if selected_take>0 else baseline.filter(func(n): return float(n.time)>=region.x and float(n.time)<region.y)
    var diff=comparison(prior,selected)
    compare_label.text="Compared with %s\n+%d added · −%d removed\n%d moved · %.1f ms average shift" % ["previous take" if selected_take>0 else "existing section",diff.added,diff.removed,diff.shifted,diff.ms]
    if selected.is_empty(): compare_label.text="EMPTY TAKE · Existing chart kept unchanged."
    var lines=PackedStringArray()
    for issue in pending_warnings.slice(0,8): lines.append("%.2f s · %s" % [float(issue.time),str(issue.message)])
    warnings_label.text="QUALITY CHECK · "+("No issues found" if pending_warnings.is_empty() else "%d flags\n" % pending_warnings.size()+"\n".join(lines))
    if pending_warnings.size()>8: warnings_label.text+="\nMore flags available in Chart Tools → Validate."
