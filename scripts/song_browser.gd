extends Control
const ButtonArt=preload("res://scripts/song_browser_button.gd")
const Row=preload("res://scripts/song_list_row.gd")
const Motion=preload("res://scripts/ui_motion.gd")
const PLACEHOLDER=preload("res://assets/brand/song_placeholder.svg")
var lobby: Control
var game: Control
var canvas: Control
var list: GridContainer
var scroll: ScrollContainer
var search: LineEdit
var tabs: Dictionary={}
var count: Label
var empty: Label
var panel: Panel
var cover: TextureRect
var cover_texture: Texture2D
var title_label: Label
var artist_label: Label
var details_label: Label
var metadata: HBoxContainer
var bpm: Label
var duration: Label
var genre: Label
var difficulty: Dictionary={}
var level_scroll: ScrollContainer
var level_row: HBoxContainer
var level_empty: Label
var shown_levels: Array=[]
var sections: OptionButton
var best_label: Label
var best_value: Label
var rank_value: Label
var play: Button
var create: Button
var selected_id=""
var cover_tween: Tween
var ambience_tween: Tween
var background: ColorRect
var art_backdrop: Control
var cover_glow: Panel
var play_tween: Tween

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
    background=ColorRect.new(); add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var mat=preload("res://scripts/background_motion.gd").attach(background,preload("res://scripts/song_browser_background.gdshader"))
    mat.set_shader_parameter("ambience",Color(.12,.08,.28,1))
    # Stage footage behind the list, recoloured blue for this screen.
    art_backdrop=preload("res://scripts/screen_backdrop.gd").video(self,0.25,.5)  # blue stage
    canvas=Control.new(); add_child(canvas); canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var local_theme=Theme.new(); local_theme.default_font=ThemeDB.fallback_font; local_theme.default_font_size=16; canvas.theme=local_theme
    for type in ["Label","Button","LineEdit","OptionButton","PopupMenu"]: local_theme.set_font("font",type,ThemeDB.fallback_font)
    resized.connect(layout); game.safe_area_changed.connect(layout); layout()
    button(canvas,"‹",48,23,76,76,lobby.show_gateway).caption_size=32
    label(canvas,"S E L E C T   A   S O N G",140,28,600,22,12,Color("50daec"))
    var heading=label(canvas,"Choose your track",140,52,700,42,34)
    var bold=FontVariation.new(); bold.base_font=ThemeDB.fallback_font; bold.variation_embolden=.5
    heading.add_theme_font_override("font",bold)
    search=LineEdit.new(); place(search,canvas,1084,23,324,76)
    search.placeholder_text="⌕   Search songs or artists"; search.add_theme_font_size_override("font_size",19)
    var s=box_style(Color("0d0d0d"),Color("302a42"),15); s.content_margin_left=18; s.content_margin_right=14
    search.add_theme_stylebox_override("normal",s)
    var focus=s.duplicate(); focus.border_color=Color("50daec"); search.add_theme_stylebox_override("focus",focus)
    search.text_changed.connect(func(_text): lobby.refresh_tracks())
    var gear=preload("res://scripts/gear_button.gd").new(); gear.accent=Color("bcb2d4")
    place(gear,canvas,996,23,72,76); gear.pressed.connect(func(): game.open_lobby_settings())
    var auto=preload("res://scripts/autoplay_toggle.gd").new(); place(auto,canvas,884,23,96,76)
    auto.toggled.connect(func(enabled): lobby.auto_enabled=enabled)
    lobby.settings_button=gear; lobby.auto_button=auto
    var tab_data=[["all","All songs",48,120],["favorites","Favorites",184,126],["recent","Recently played",326,184],["new","New",526,82],["daily","★ Daily",624,112]]
    for item in tab_data:
        var key: String=item[0]; var n=button(canvas,item[1],item[2],96,item[3],56,func(): lobby.set_filter(key))
        n.tab=true; n.caption_size=21; tabs[key]=n
    var rule=ColorRect.new(); place(rule,canvas,48,154,1360,1); rule.color=Color("232323"); rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
    canvas.move_child(rule,canvas.get_child_count()-tabs.size()-2)
    count=label(canvas,"",1250,106,158,28,13,Color("aaa2bf")); count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    scroll=ScrollContainer.new(); place(scroll,canvas,48,168,794,615)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO; scroll.scroll_deadzone=12
    var rail=StyleBoxFlat.new(); rail.bg_color=Color(0,0,0,0)
    scroll.get_v_scroll_bar().add_theme_stylebox_override("scroll",rail)
    var grabber=StyleBoxFlat.new(); grabber.bg_color=Color(.6,.55,.8,.14); grabber.set_corner_radius_all(3)
    for state in ["grabber","grabber_highlight","grabber_pressed"]: scroll.get_v_scroll_bar().add_theme_stylebox_override(state,grabber)
    scroll.get_v_scroll_bar().custom_minimum_size.x=4
    var drag=preload("res://scripts/song_list_scroll.gd").new(); drag.scroll=scroll; drag.name="DragScroll"; scroll.add_child(drag)
    list=GridContainer.new(); scroll.add_child(list); list.columns=1; list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("v_separation",9)
    empty=label(canvas,"",72,320,746,130,20,Color("aaa2bf")); empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    panel=card(canvas,882,168,526,615,Vector2(1456,819),25)
    var p=Vector2(526,615)
    # Soft glow in the song's accent colour behind the cover.
    cover_glow=Panel.new(); place(cover_glow,panel,35,35,130,130,p); cover_glow.mouse_filter=Control.MOUSE_FILTER_IGNORE
    cover_glow.anchor_right=cover_glow.anchor_left; cover_glow.anchor_bottom=cover_glow.anchor_top
    cover_glow.offset_right=130; cover_glow.offset_bottom=130
    var art_holder=Control.new(); place(art_holder,panel,29,29,142,142,p)
    # Keep album art square when the available panel width changes.
    art_holder.anchor_right=art_holder.anchor_left; art_holder.anchor_bottom=art_holder.anchor_top
    art_holder.offset_right=142; art_holder.offset_bottom=142
    cover=TextureRect.new(); art_holder.add_child(cover); cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    cover.mouse_filter=Control.MOUSE_FILTER_IGNORE; preload("res://scripts/screen_style.gd").round_cover(cover,22)
    label(panel,"N O W   S E L E C T E D",192,35,305,22,11,Color("53d9eb"),p)
    title_label=label(panel,"",192,59,305,43,32,Color("f5f3ff"),p); title_label.add_theme_font_override("font",bold)
    artist_label=label(panel,"",192,102,305,28,16,Color("c4bcd6"),p)
    metadata=HBoxContainer.new(); place(metadata,panel,192,135,305,28,p); metadata.add_theme_constant_override("separation",7)
    bpm=chip(); duration=chip(); genre=chip()
    label(panel,"L E V E L",29,271,146,22,12,Color("bfb5d5"),p)
    sections=OptionButton.new(); place(sections,panel,29,191,468,64,p)
    sections.tooltip_text="Choose the full song, a verse, or the bridge"
    for key in ["full","verse1","verse2","bridge"]: sections.add_item(game.SECTION_NAMES[key])
    sections.add_theme_font_size_override("font_size",21)
    sections.get_popup().add_theme_font_size_override("font_size",21)
    sections.get_popup().add_theme_constant_override("v_separation",16)
    var section_style=box_style(Color("131313"),Color("2b2b2b"),18)
    section_style.content_margin_left=18; section_style.content_margin_right=18
    sections.add_theme_stylebox_override("normal",section_style)
    var section_focus=section_style.duplicate(); section_focus.border_color=Color("50daec")
    for state in ["hover","pressed","focus"]: sections.add_theme_stylebox_override(state,section_focus)
    sections.get_popup().about_to_popup.connect(func():
        var r=sections.get_global_rect(); var k=sections.get_global_transform_with_canvas().get_scale()
        var popup=sections.get_popup()
        popup.position=Vector2i(sections.get_screen_position()+Vector2(0,sections.size.y*k.y+6))
        popup.min_size=Vector2i(roundi(sections.size.x*k.x),0))
    sections.item_selected.connect(func(index): game.set_play_mode(["full","verse1","verse2","bridge"][index]); update_best())
    # One chip per chart level the song has (Lv 1-30), scrolling sideways when there are many.
    level_scroll=ScrollContainer.new(); place(level_scroll,panel,29,300,468,86,p)
    level_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    level_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
    level_row=HBoxContainer.new(); level_scroll.add_child(level_row); level_row.add_theme_constant_override("separation",9)
    level_empty=label(panel,"No charts yet",29,300,468,80,16,Color("8f88a6"),p)
    var best=card(panel,29,394,468,76,p,18)
    best_label=label(best,"",17,11,330,23,12,Color("a9a0bd"),Vector2(468,76))
    best_value=label(best,"0",17,34,330,30,24,Color("f7f3ff"),Vector2(468,76))
    label(best,"Rank",390,12,60,20,12,Color("aaa2bf"),Vector2(468,76)).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    rank_value=label(best,"—",390,34,60,30,24,Color("51d8ec"),Vector2(468,76)); rank_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    details_label=label(panel,"",29,478,468,28,13,Color("a9a0bd"),p)
    play=button(panel,"▶   P L A Y",29,508,468,84,lobby.press_play,p,true)
    create=button(panel,"CREATE CHART",29,508,468,84,func():
        # Opens Chart Studio on this song and asks for the new chart's level (1-30).
        lobby.stop_preview(); game.open_editor()
        game.chart_library.select_entry(str(game.song.id)); game.chart_library.ask_level("editor"),p,true)
    play.caption_size=30; create.caption_size=25
    play.pulse=true; create.pulse=true
    create.visible=false
func chip() -> Label:
    var n=Label.new(); metadata.add_child(n); n.add_theme_font_size_override("font_size",14)
    n.add_theme_color_override("font_color",Color("d7d1e5"))
    var style=box_style(Color("1a1a1a"),Color(0,0,0,0),14)
    style.content_margin_left=10; style.content_margin_right=10; style.content_margin_top=5; style.content_margin_bottom=5
    n.add_theme_stylebox_override("normal",style); return n
func layout() -> void:
    if not canvas: return
    var available=game.safe_rect_for(self)
    var k=maxf(.1,minf(available.size.x/1456.0,available.size.y/819.0))
    canvas.position=available.position; canvas.scale=Vector2.ONE*k; canvas.size=available.size/k
func set_rows(entries: Array) -> void:
    var existing: Dictionary={}
    var old_ids: Array=[]
    for row in list.get_children(): existing[str(row.entry.id)]=row; old_ids.append(str(row.entry.id))
    if old_ids!=entries.map(func(e): return str(e.id)): scroll.get_node("DragScroll").stop()
    for i in entries.size():
        var entry: Dictionary=entries[i]; var row=existing.get(str(entry.id))
        if row==null:
            row=Row.new(); row.lobby=lobby; list.add_child(row)
            Motion.reveal(row,minf(.18,i*.035))
            row.pressed.connect(func():
                if not preload("res://scripts/drag_scroll.gd").was_dragged(scroll): lobby.select_track(int(row.entry.index)))
        else: existing.erase(str(entry.id))
        row.update_entry(entry); row.set_selected(str(entry.id)==lobby.selected_track_id()); list.move_child(row,i)
    for row in existing.values(): list.remove_child(row); row.queue_free()
    for key in tabs: tabs[key].set_selected(key==lobby.track_filter)
    count.text="%d song%s" % [entries.size(),"" if entries.size()==1 else "s"]
    empty.visible=entries.is_empty()
    empty.text="No favorites yet. Use the heart beside a song." if lobby.track_filter=="favorites" else ("No songs played yet." if lobby.track_filter=="recent" else "No songs match this filter or search.")
func set_details(entry: Dictionary,loading: bool,has_chart: bool) -> void:
    var changed=selected_id!=str(entry.id); selected_id=str(entry.id)
    title_label.text=entry.title; artist_label.text=entry.artist
    bpm.text="%d BPM" % roundi(float(entry.bpm)); duration.text=lobby.duration_text(float(entry.duration))
    genre.text=entry.genre if not str(entry.genre).is_empty() else ("SYNK" if entry.id=="eclipse" else "Custom")
    genre.visible=not genre.text.is_empty(); metadata.visible=true
    details_label.text="Loading song…" if loading else ("" if has_chart else "No chart for this level yet. Create one in Chart Studio.")
    play.visible=has_chart; play.disabled=loading
    create.visible=not has_chart; create.disabled=loading
    panel.modulate.a=1
    var texture=lobby.cover_for(entry.id)
    if art_backdrop: art_backdrop.set_art(texture)
    tint_play_button(entry)
    var glow=box_style(Color(entry.accent,.35),Color(0,0,0,0),24); glow.shadow_color=Color(entry.accent,.45); glow.shadow_size=26
    cover_glow.add_theme_stylebox_override("panel",glow)
    if cover_texture!=texture or changed:
        if cover_tween: cover_tween.kill()
        # Crossfade the actual cover only; leave titles and list interaction responsive.
        for old in cover.get_parent().get_children():
            if old!=cover: old.queue_free()
        var outgoing=TextureRect.new(); outgoing.texture=cover.texture
        cover.get_parent().add_child(outgoing); outgoing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        outgoing.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; outgoing.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
        outgoing.mouse_filter=Control.MOUSE_FILTER_IGNORE
        outgoing.material=cover.material.duplicate() if cover.material else null
        cover.texture=texture; cover_texture=texture
        lobby.style_cover(cover,entry.id,22)
        cover_tween=create_tween(); cover_tween.tween_property(outgoing,"modulate:a",0,.24); cover_tween.tween_callback(outgoing.queue_free)
    if changed:
        if ambience_tween: ambience_tween.kill()
        ambience_tween=create_tween()
        var old_tint=background.material.get_shader_parameter("ambience")
        ambience_tween.tween_method(func(tint: Color): background.material.set_shader_parameter("ambience",tint),old_tint if old_tint is Color else Color(.12,.08,.28,1),entry.accent,.45)
    refresh_difficulties(loading); update_best()
# The Play button's gradient takes three colours from the song's album art (or shades of its
# accent when it has no cover), kept bright and saturated so the white caption stays readable.
func play_colors(entry: Dictionary) -> Array:
    var id=str(entry.id); var raw: Array=[]
    if id=="eclipse" or game.has_custom_cover(id):
        var palette: Dictionary=game.cover_palette_for_id(id)
        if bool(palette.get("from_cover",false)): raw=palette.notes.slice(0,3)
    if raw.size()<3:
        var a: Color=entry.accent
        raw=[Color.from_hsv(fposmod(a.h-.08,1.0),a.s,a.v),a,Color.from_hsv(fposmod(a.h+.09,1.0),a.s,a.v)]
    var out: Array=[]
    for c in raw: out.append(Color.from_hsv(c.h,clampf(c.s,.55,.95),clampf(c.v,.72,.95)))
    return out
func tint_play_button(entry: Dictionary) -> void:
    var target=play_colors(entry)
    var keys=["start_color","middle_color","end_color"]
    for button in [play,create]:
        var mat: ShaderMaterial=button.material
        if mat==null: continue
        var from: Array=[]
        for k in keys:
            var v=mat.get_shader_parameter(k)
            from.append(Color(v.x,v.y,v.z) if v is Vector3 else (v if v is Color else Color.WHITE))
        if play_tween and play_tween.is_running(): play_tween.kill()
        play_tween=create_tween()
        play_tween.tween_method(func(t: float):
            for i in 3:
                var c: Color=from[i].lerp(target[i],t)
                for b in [play,create]:
                    if b.material: b.material.set_shader_parameter(keys[i],Vector3(c.r,c.g,c.b)),0.0,1.0,.45)
        break
func refresh_difficulties(loading: bool=false) -> void:
    var Levels=preload("res://scripts/chart_levels.gd")
    var levels: Array=lobby.levels_for(selected_id)
    if levels!=shown_levels:
        shown_levels=levels.duplicate()
        for child in level_row.get_children(): child.queue_free()
        difficulty.clear()
        for variant in levels:
            var key: String=variant
            var chip=ButtonArt.new(); chip.menu_motion=true; chip.text=Levels.label(key); chip.caption_size=22
            chip.custom_minimum_size=Vector2(104,80); level_row.add_child(chip)
            chip.pressed.connect(func(): lobby.choose_difficulty(key)); difficulty[key]=chip
    level_empty.visible=levels.is_empty()
    for key in difficulty:
        difficulty[key].disabled=loading
        difficulty[key].set_selected(game.features.current_variant==key and not loading)
    # The play button names the level it will start.
    play.text="▶   P L A Y   ·   "+" ".join(Levels.label(game.features.current_variant).to_upper().split(""))
    play.caption_size=26
    for i in 4: sections.get_popup().set_item_disabled(i,not game.section_available(["full","verse1","verse2","bridge"][i]) or loading)
    sections.select(["full","verse1","verse2","bridge"].find(game.play_mode))
func update_best() -> void:
    var variant=game.features.current_variant
    best_label.text="Your best on "+preload("res://scripts/chart_levels.gd").label(variant) if lobby.has_variant(str(game.song.id),variant) else "Your best"
    var notes=game.baseline_notes().duplicate(true)
    notes.sort_custom(func(a,b): return float(a.time)<float(b.time))
    var region=game.section_range(game.play_mode)
    notes=notes.filter(func(n): return float(n.time)>=region.x-.001 and float(n.time)<region.y)
    var key=(str(game.song.id)+JSON.stringify(notes)).sha256_text()
    best_value.text=str(int(game.prefs.get_value("scores",key,0)))
    rank_value.text=str(game.prefs.get_value("score_ranks",key,"—"))
    # Full combo / all perfect badges, play count and any active modifiers.
    if game.extras:
        var stats: Dictionary=game.extras.stats_for(key)
        var badges: Array=[]
        if bool(stats.get("all_perfect",false)): badges.append("ALL PERFECT")
        elif bool(stats.get("full_combo",false)): badges.append("FULL COMBO")
        if int(stats.get("plays",0))>0: badges.append("%d play%s" % [int(stats.plays),"" if int(stats.plays)==1 else "s"])
        var mods: String=game.extras.mods_text()
        if not mods.is_empty(): badges.append(mods)
        if not badges.is_empty(): best_label.text+="  ·  "+"  ·  ".join(badges)
func show_empty() -> void:
    title_label.text="Choose a track"; artist_label.text="Try another filter or search."
    metadata.visible=false; play.visible=true; play.disabled=true; create.visible=false; details_label.text=""
    for n in difficulty.values(): n.disabled=true; n.set_selected(false)
    level_empty.visible=true; sections.disabled=true; best_value.text="0"; rank_value.text="—"; best_label.text="Your best"
