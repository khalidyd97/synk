extends Control
const ButtonArt=preload("res://scripts/song_browser_button.gd")
const JUDGMENT_COLORS={"PERFECT":Color("2ed9ed"),"GREAT":Color("9061ff"),"GOOD":Color("f532c8"),"MISS":Color("77708f")}
var game: Control
var canvas: Control
var elapsed=0.0
var final_score=0
var final_accuracy=0.0
var counts: Dictionary={}
var total_judgments=1
var info: Dictionary={}
var card: Control
var card_art: TextureRect
var song_title: Label
var song_meta: Label
var difficulty_label: Label
var bpm_label: Label
var completion_label: Label
var rank_label: Label
var rank_art: Control
var ring: Control
var ring_accuracy: Label
var rank_glow: GradientTexture2D
var score_label: Label
var best_badge: Label
var note_label: Label
var stats_label: Label
var combo_slot: Control
var combo_value_label: Label
var combo_context: Label
var hit_value: Label
var breakdown: Control
var timing_graph: Control
var accuracy_graph: Control
var graph_title: Label
var graph_time: Label
var timing_button: Button
var detail_panel: Panel
var buttons: Array=[]
var next_button: Button
var replay_button: Button
var practice_button: Button
var pending_next_id=""
var pending_next_variant="original"

func style(fill: Color,edge: Color,radius: int=24) -> StyleBoxFlat:
    var s=StyleBoxFlat.new(); s.bg_color=fill; s.border_color=edge; s.set_corner_radius_all(radius); s.set_border_width_all(1); return s
func place(node: Control,parent: Control,x: float,y: float,w: float,h: float,base: Vector2=Vector2(2048,1152)) -> void:
    parent.add_child(node); node.anchor_left=x/base.x; node.anchor_top=y/base.y
    node.anchor_right=(x+w)/base.x; node.anchor_bottom=(y+h)/base.y
func label(parent: Control,value: String,x: float,y: float,w: float,h: float,font_size: int,tint: Color=Color("f4f2ff"),base: Vector2=Vector2(2048,1152),bold: bool=false) -> Label:
    var n=Label.new(); place(n,parent,x,y,w,h,base); n.text=value; n.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    n.add_theme_font_size_override("font_size",roundi(font_size*1.15) if font_size<=30 else font_size); n.add_theme_color_override("font_color",tint)
    n.mouse_filter=Control.MOUSE_FILTER_IGNORE; n.clip_text=true; n.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    if bold:
        var f=FontVariation.new(); f.base_font=ThemeDB.fallback_font; f.variation_embolden=.6; n.add_theme_font_override("font",f)
    return n
func panel(parent: Control,x: float,y: float,w: float,h: float,base: Vector2=Vector2(2048,1152)) -> Panel:
    var n=Panel.new(); place(n,parent,x,y,w,h,base)
    n.add_theme_stylebox_override("panel",style(Color(.035,.028,.080,.90),Color("2c273d"),30)); return n
func button(value: String,x: float,y: float,w: float,h: float,callback: Callable,primary: bool=false) -> Button:
    var n=ButtonArt.new(); n.menu_motion=true; n.text=value; n.primary=primary; n.caption_size=32
    place(n,canvas,x,y,w,h); n.pressed.connect(callback); return n
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP
    var background=ColorRect.new(); add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var mat=preload("res://scripts/background_motion.gd").attach(background,preload("res://scripts/song_browser_background.gdshader"))
    preload("res://scripts/screen_backdrop.gd").video(self,-0.11,.55)  # gold stage
    canvas=Control.new(); add_child(canvas); canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var theme_local=Theme.new(); theme_local.default_font=ThemeDB.fallback_font; theme_local.default_font_size=20
    for type in ["Label","Button"]: theme_local.set_font("font",type,ThemeDB.fallback_font)
    canvas.theme=theme_local; resized.connect(layout); game.safe_area_changed.connect(layout); layout()
    card=Control.new(); place(card,canvas,68,51,137,137)
    card.anchor_right=card.anchor_left; card.anchor_bottom=card.anchor_top; card.offset_right=137; card.offset_bottom=137
    card_art=TextureRect.new(); card.add_child(card_art); card_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    card_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; card_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    card_art.mouse_filter=Control.MOUSE_FILTER_IGNORE; preload("res://scripts/screen_style.gd").round_cover(card_art,27)
    completion_label=label(canvas,"S O N G   C O M P L E T E",236,51,1050,31,18,Color("27dcef"))
    song_title=label(canvas,"",236,80,1500,68,52,Color("f3f0ff"),Vector2(2048,1152),true)
    song_meta=label(canvas,"",236,149,390,36,23,Color("bcb4d2"))
    difficulty_label=label(canvas,"",644,149,110,42,20,Color("e8f8ff"))
    var pill=style(Color("092737"),Color("2bd8ef"),18); pill.content_margin_left=13; pill.content_margin_right=13
    difficulty_label.add_theme_stylebox_override("normal",pill); difficulty_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    bpm_label=label(canvas,"",768,149,132,42,20,Color("c1b9d6"))
    var bpm_style=style(Color("171426"),Color(0,0,0,0),18); bpm_style.content_margin_left=12; bpm_style.content_margin_right=12
    bpm_label.add_theme_stylebox_override("normal",bpm_style); bpm_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    ring=Control.new(); place(ring,canvas,265,295,400,400); ring.mouse_filter=Control.MOUSE_FILTER_IGNORE; ring.draw.connect(draw_ring)
    rank_label=label(ring,"A",40,52,320,250,202,Color.WHITE,Vector2(400,400),true)
    rank_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    rank_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0))
    rank_label.add_theme_constant_override("shadow_outline_size",0)
    var glow_gradient=Gradient.new(); glow_gradient.offsets=PackedFloat32Array([0,.5,1])
    glow_gradient.colors=PackedColorArray([Color(.1,.7,1,.25),Color(.1,.55,1,.08),Color(.1,.4,.8,0)])
    rank_glow=GradientTexture2D.new(); rank_glow.width=256; rank_glow.height=256; rank_glow.gradient=glow_gradient
    rank_glow.fill=GradientTexture2D.FILL_RADIAL; rank_glow.fill_from=Vector2(.5,.5); rank_glow.fill_to=Vector2(1,.5)
    rank_art=Control.new(); rank_art.visible=false; canvas.add_child(rank_art)
    ring_accuracy=label(ring,"",70,276,260,55,30,Color("d4cced"),Vector2(400,400),true)
    ring_accuracy.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    best_badge=label(canvas,"NEW BEST!",552,280,168,48,20,Color.WHITE)
    var badge=style(Color("d73ad4"),Color(0,0,0,0),24)
    best_badge.add_theme_stylebox_override("normal",badge); best_badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; best_badge.rotation=.12
    label(canvas,"S C O R E",275,733,380,36,20,Color("a8a0c2")).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    score_label=label(canvas,"0",170,776,590,98,86,Color("fbfaff"),Vector2(2048,1152),true)
    score_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    note_label=label(canvas,"",150,891,630,47,22,Color("1ce1b3")); note_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    detail_panel=panel(canvas,922,225,1058,753)
    var p=Vector2(1058,753)
    var combo=panel(detail_panel,44,41,311,150,p)
    var accuracy=panel(detail_panel,372,41,311,150,p)
    var hits=panel(detail_panel,700,41,314,150,p)
    for n in [combo,accuracy,hits]: n.add_theme_stylebox_override("panel",style(Color("101022"),Color("292539"),23))
    label(combo,"Max combo",26,21,260,31,20,Color("aaa1c4"),Vector2(311,150))
    combo_slot=Control.new(); place(combo_slot,combo,26,54,260,48,Vector2(311,150))
    combo_value_label=label(combo_slot,"0",0,0,260,48,38,Color.WHITE,Vector2(260,48),true)
    combo_context=label(combo,"",26,104,260,32,17,Color("8d85a9"),Vector2(311,150))
    label(accuracy,"Accuracy",26,21,260,31,20,Color("aaa1c4"),Vector2(311,150))
    stats_label=label(accuracy,"",26,54,260,48,38,Color.WHITE,Vector2(311,150),true)
    label(hits,"Notes hit",26,21,260,31,20,Color("aaa1c4"),Vector2(314,150))
    hit_value=label(hits,"",26,54,262,48,38,Color.WHITE,Vector2(314,150),true)
    breakdown=Control.new(); place(breakdown,detail_panel,44,223,970,344,p)
    breakdown.mouse_filter=Control.MOUSE_FILTER_IGNORE; breakdown.draw.connect(draw_breakdown)
    graph_title=label(detail_panel,"ACCURACY OVER THE SONG",44,575,600,32,19,Color("b6accf"),p)
    graph_time=label(detail_panel,"",830,575,184,32,19,Color("a69bbf"),p); graph_time.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    timing_button=ButtonArt.new(); timing_button.menu_motion=true; timing_button.text="TIMING"; timing_button.caption_size=21
    place(timing_button,detail_panel,650,547,156,80,p); timing_button.pressed.connect(toggle_graph)
    accuracy_graph=preload("res://scripts/result_accuracy_graph.gd").new(); place(accuracy_graph,detail_panel,44,635,970,102,p)
    timing_graph=preload("res://scripts/timing_graph.gd").new(); place(timing_graph,detail_panel,44,635,970,102,p); timing_graph.visible=false
    buttons.append(button("☷  S O N G  L I S T",68,994,350,128,open_song_list))
    buttons.append(button("↶  R E T R Y",440,994,290,128,retry))
    next_button=button("N E X T   S O N G   →",1460,994,520,128,next_song,true); buttons.append(next_button)
    replay_button=button("▶  R E P L A Y",752,994,300,128,func(): game.extras.start_replay()); buttons.append(replay_button)
    practice_button=button("⟲  P R A C T I C E  M I S S",1074,994,364,128,practice_first_miss); buttons.append(practice_button)
    visible=false
func layout() -> void:
    if not canvas: return
    var available=game.safe_rect_for(self)
    var k=maxf(.1,minf(available.size.x/2048.0,available.size.y/1152.0)); canvas.position=available.position; canvas.scale=Vector2.ONE*k; canvas.size=available.size/k
func build_rank_art(rank: String) -> void:
    # The reference uses a clean white rank, not the old glass-letter atlas.
    rank_label.text=rank; rank_label.visible=true; rank_art.visible=false
func time_text(seconds: float) -> String:
    var n=maxi(0,roundi(seconds)); return "%d:%02d" % [n/60,n%60]
func show_results(data: Dictionary) -> void:
    pending_next_id=""; info=data.duplicate(true); elapsed=0; final_score=int(info.get("score",0)); final_accuracy=clampf(float(info.get("accuracy",0)),0,100)
    counts=info.get("counts",{}).duplicate(true); total_judgments=0
    for key in JUDGMENT_COLORS: total_judgments+=maxi(0,int(counts.get(key,0)))
    card_art.texture=info.get("cover",game.ECLIPSE_COVER); card_art.self_modulate=info.get("tint",Color.WHITE)
    if info.has("song_id"):
        card_art.texture=game.lobby.cover_for(str(info.song_id)); card_art.self_modulate=Color.WHITE
        game.lobby.style_cover(card_art,str(info.song_id),27)
    song_title.text=str(info.get("title",game.song.title))
    song_meta.text=str(info.get("artist",game.song.get("artist",game.album_name(game.song))))
    var variant=str(info.get("difficulty",game.features.current_variant.capitalize()))
    difficulty_label.text=variant; bpm_label.text="%d BPM" % roundi(float(info.get("bpm",game.chart_bpm())))
    # Header badges follow the artist instead of reserving a large fixed gap.
    var artist_width=minf(390,song_meta.get_theme_font("font").get_string_size(song_meta.text,HORIZONTAL_ALIGNMENT_LEFT,-1,song_meta.get_theme_font_size("font_size")).x+20)
    var difficulty_width=maxf(90,difficulty_label.get_theme_font("font").get_string_size(variant,HORIZONTAL_ALIGNMENT_LEFT,-1,difficulty_label.get_theme_font_size("font_size")).x+28)
    song_meta.anchor_right=song_meta.anchor_left; song_meta.offset_right=artist_width
    difficulty_label.anchor_left=236/2048.0; difficulty_label.anchor_right=difficulty_label.anchor_left
    difficulty_label.offset_left=artist_width+14; difficulty_label.offset_right=artist_width+14+difficulty_width
    bpm_label.anchor_left=difficulty_label.anchor_left; bpm_label.anchor_right=bpm_label.anchor_left
    bpm_label.offset_left=artist_width+28+difficulty_width; bpm_label.offset_right=bpm_label.offset_left+132
    var automated=bool(info.get("auto_play",false)); var practice=bool(info.get("practice",false))
    completion_label.text="AUTO PLAY PREVIEW" if automated else ("PRACTICE COMPLETE" if practice else "S O N G   C O M P L E T E")
    var rank="AUTO" if automated else ("PRACTICE" if practice else str(info.get("rank","—")))
    build_rank_art(rank)
    rank_label.add_theme_font_size_override("font_size",52 if practice else (78 if automated else (132 if rank.length()>1 else 202)))
    stats_label.text="%.1f%%" % final_accuracy
    var total_notes=int(info.get("notes_total",total_judgments))
    var hit_notes=int(info.get("notes_hit",total_notes-int(counts.get("MISS",0))))
    hit_value.text="%d/%d" % [maxi(0,hit_notes),maxi(0,total_notes)]
    combo_value_label.text=str(int(info.get("max_combo",0))); combo_value_label.visible=true
    combo_context.text="of %d judgments" % total_judgments
    best_badge.visible=bool(info.get("new_best",false)) and not automated and not practice
    var previous=int(info.get("previous_best",info.get("best",0)))
    if automated: note_label.text="Preview only · scores are not saved"
    elif practice: note_label.text="Practice run · scores are not saved"
    elif best_badge.visible and final_score>previous: note_label.text="↑  +%s over your previous best" % game.format_score(final_score-previous)
    else: note_label.text="Personal best  "+game.format_score(int(info.get("best",final_score)))
    var begin=float(info.get("range_start",0)); var end=float(info.get("range_end",game.length()))
    graph_time.text=time_text(begin)+" — "+time_text(end)
    accuracy_graph.start=begin; accuracy_graph.finish=maxf(begin+.001,end)
    accuracy_graph.samples=info.get("performance",[]).duplicate(true); accuracy_graph.rebuild()
    timing_graph.samples=info.get("timing",[]).duplicate(true); timing_graph.samples.sort_custom(func(a,b): return float(a.time)<float(b.time))
    timing_graph.queue_redraw(); accuracy_graph.visible=true; timing_graph.visible=false; timing_button.text="TIMING"
    graph_title.text="ACCURACY OVER THE SONG"; breakdown.visible=true
    next_button.disabled=practice or next_candidate().is_empty()
    replay_button.disabled=not bool(info.get("replay",false))
    replay_button.tooltip_text="Watch your last run" if not replay_button.disabled else "No replay for this run"
    practice_button.disabled=automated or not info.get("performance",[]).any(func(s): return float(s.get("weight",1.0))<=0.0)
    var stats: Dictionary=info.get("stats",{})
    var extra: Array=[]
    if not automated and not practice:
        if int(counts.get("MISS",0))==0 and total_judgments>0: extra.append("ALL PERFECT" if int(counts.get("GREAT",0))+int(counts.get("GOOD",0))==0 else "FULL COMBO")
        if int(stats.get("plays",0))>0: extra.append("Play %d" % int(stats.plays))
    if not str(info.get("mods","")).is_empty(): extra.append(str(info.mods))
    if game.extras and game.extras.replaying: extra.append("Replay")
    if not extra.is_empty(): note_label.text+="   ·   "+"  ·  ".join(extra)
    next_button.tooltip_text="Play the next available chart in this song list" if not next_button.disabled else "No other playable song in this list"
    visible=true; animate()
func toggle_graph() -> void:
    timing_graph.visible=not timing_graph.visible; accuracy_graph.visible=not timing_graph.visible
    graph_title.text="HIT TIMING OVER THE SONG" if timing_graph.visible else "ACCURACY OVER THE SONG"
    timing_button.text="ACCURACY" if timing_graph.visible else "TIMING"
# Loops the stretch around the first miss at 0.75x so the hard part can be learned.
func practice_first_miss() -> void:
    var first=-1.0
    for sample in info.get("performance",[]):
        if float(sample.get("weight",1.0))<=0.0: first=float(sample.time); break
    if first<0: return
    var a=maxf(0.0,first-3.0); var b=minf(game.length(),first+6.0)
    pending_next_id=""
    game.practice.active=true
    if not game.practice.launch(game.last_play_notes,a,b,.75,true): game.practice.active=false
func open_song_list() -> void:
    pending_next_id=""; game.set_mode("menu"); game.lobby.show_play_browser()
func retry() -> void:
    pending_next_id=""
    if game.practice.active: game.practice.restart()
    else: game.start_game(game.last_play_notes,game.auto_play,game.last_section)
func next_candidate() -> Dictionary:
    var entries=game.lobby.filtered_entries
    if entries.is_empty(): return {}
    var current=-1
    for i in entries.size():
        if str(entries[i].id)==str(game.song.id): current=i; break
    var count=entries.size()-1 if current>=0 else entries.size()
    for step in range(1,count+1):
        var candidate: Dictionary=entries[posmod(current+step,entries.size())]
        var preferred=str(game.prefs.get_value("charts",str(candidate.id),"original"))
        for variant in [preferred,"original","easy","normal","hard","expert"]:
            if game.lobby.playable_variant(str(candidate.id),variant): return {"id":str(candidate.id),"index":int(candidate.index),"variant":variant}
    return {}
func next_song() -> void:
    var candidate=next_candidate()
    if candidate.is_empty(): return
    open_song_list(); pending_next_id=candidate.id; pending_next_variant=candidate.variant
    game.lobby.select_track(candidate.index)
func _process(delta: float) -> void:
    if not pending_next_id.is_empty():
        if game.mode!="menu" or game.lobby.gateway.visible or game.lobby.selected_track_id()!=pending_next_id:
            pending_next_id=""
        elif game.loading_song_index<0:
            if str(game.song.id)==pending_next_id:
                var id=pending_next_id; pending_next_id=""; game.lobby.choose_difficulty(pending_next_variant)
                if str(game.song.id)==id and not game.baseline_notes().is_empty(): game.start_game(game.baseline_notes(),game.lobby.auto_enabled)
            elif game.worker_song_id.is_empty(): pending_next_id=""
    if not visible: return
    elapsed+=delta; animate()
func ease_out(t: float) -> float: return 1-pow(1-clampf(t,0,1),3)
func animate() -> void:
    modulate.a=ease_out(elapsed/.3)
    var progress=ease_out((elapsed-.15)/1.1)
    ring_accuracy.text="%.1f%%" % (final_accuracy*progress)
    ring.queue_redraw()
    rank_label.pivot_offset=rank_label.size*.5; rank_label.scale=Vector2.ONE*(1+(1-ease_out((elapsed-.2)/.5))*.12)
    rank_label.modulate.a=ease_out((elapsed-.15)/.4)
    score_label.text=game.format_score(roundi(final_score*ease_out((elapsed-.25)/1.2)))
    best_badge.modulate.a=ease_out((elapsed-1.1)/.3)
    detail_panel.modulate.a=ease_out((elapsed-.1)/.45)
    note_label.modulate.a=ease_out((elapsed-1.25)/.35)
    accuracy_graph.progress=ease_out((elapsed-.5)/.8); accuracy_graph.queue_redraw()
    for i in buttons.size(): buttons[i].modulate.a=ease_out((elapsed-.5-i*.06)/.35)
    breakdown.queue_redraw()
func draw_ring() -> void:
    var center=ring.size*.5; var radius=minf(ring.size.x,ring.size.y)*.42
    ring.draw_texture_rect(rank_glow,Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2),false)
    ring.draw_arc(center,radius,-PI*.5,TAU-PI*.5,128,Color("242039"),19,true)
    var progress=final_accuracy/100*ease_out((elapsed-.15)/1.1)
    for i in 120:
        var part=float(i)/120
        if part>=progress: break
        var end=minf(progress,float(i+1)/120)
        var tint=Color("30d8eb").lerp(Color("ae5dff"),part).lerp(Color("ee2ccb"),smoothstep(.55,1,part))
        var a=-PI*.5+TAU*part; var b=-PI*.5+TAU*end
        for layer in [[38.0,.025],[28.0,.07],[19.0,1.0]]: ring.draw_arc(center,radius,a,b,3,Color(tint,layer[1]),layer[0],true)
    var top=center+Vector2(cos(-PI*.5+TAU*progress),sin(-PI*.5+TAU*progress))*radius
    if progress>0: ring.draw_circle(top,9.5,Color("b66afd"))
func draw_breakdown() -> void:
    var font=breakdown.get_theme_font("font"); var row=breakdown.size.y/4.0
    var names=["PERFECT","GREAT","GOOD","MISS"]
    for i in 4:
        var grow=ease_out((elapsed-.35-i*.08)/.7); var y=i*row
        var color: Color=JUDGMENT_COLORS[names[i]]; var count=maxi(0,int(counts.get(names[i],0)))
        var share=float(count)/maxi(1,total_judgments)
        breakdown.draw_string(font,Vector2(0,y+29),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,24,color)
        var percent="%.1f%%" % (share*100)
        var percent_width=font.get_string_size(percent,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
        breakdown.draw_string(font,Vector2(breakdown.size.x-percent_width,y+29),percent,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("c2b9d8"))
        var number=str(roundi(count*grow)); var number_width=font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,30).x
        breakdown.draw_string(font,Vector2(breakdown.size.x-percent_width-number_width-18,y+29),number,HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color.WHITE)
        var rail=style(Color("1d192e"),Color(0,0,0,0),6)
        breakdown.draw_style_box(rail,Rect2(0,y+49,breakdown.size.x,11))
        var width=breakdown.size.x*share*grow
        if width>0:
            var fill=style(color,Color(0,0,0,0),6); breakdown.draw_style_box(fill,Rect2(0,y+49,maxf(1,width),11))
