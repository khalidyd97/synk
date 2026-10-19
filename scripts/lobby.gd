extends Control
const UiMotion=preload("res://scripts/ui_motion.gd")
const LobbyWordmark=preload("res://scripts/lobby_wordmark.gd")
const LobbyCard=preload("res://scripts/lobby_card.gd")
const SongBrowser=preload("res://scripts/song_browser.gd")
const HOME_BACKGROUND=preload("res://assets/lobby/ui/reference_background.png")
const HOME_VIDEO="res://assets/lobby/ui/lobby_background_v2.ogv"
var game: Control
var gateway: Control
var browser: Control
var browser_visibility: Array=[]
var gateway_entrance_items: Array=[]
var home_video: VideoStreamPlayer
var background_video: VideoStreamPlayer
var title_label: Label
var source_label: Label
var detail_label: Label
var play_button: Button
var create_chart_button: Button
var settings_button: Button
var auto_button: Button
var auto_enabled=false
var search: LineEdit
var track_list: GridContainer
var track_scroll: ScrollContainer
var track_count_label: Label
var filtered_entries: Array=[]
var track_filter="all"
var favorites: Array=[]
var recent: Dictionary={}
var ratings: Dictionary={}
var preview_player: AudioStreamPlayer
var preview_delay=-1.0
var preview_remaining=0.0
var preview_song_id=""
var preview_enabled=true
var preview_start=0.0
func place(node: Control,parent: Node,left: float,top: float,right: float,bottom: float) -> void:
    parent.add_child(node); node.anchor_left=left; node.anchor_top=top; node.anchor_right=right; node.anchor_bottom=bottom
func text(parent: Node,value: String,left: float,top: float,right: float,bottom: float,font_size: int,color: Color=Color("f3edff")) -> Label:
    var n=Label.new(); place(n,parent,left,top,right,bottom); n.text=value
    n.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; n.add_theme_font_size_override("font_size",font_size)
    n.add_theme_color_override("font_color",color); n.mouse_filter=Control.MOUSE_FILTER_IGNORE; return n
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_PASS
    preview_enabled=bool(game.prefs.get_value("audio","song_preview",true))
    var stored=game.prefs.get_value("lobby","favorites",[])
    favorites=stored if stored is Array else []
    var history=game.prefs.get_value("lobby","recent",{})
    recent=history if history is Dictionary else {}
    preview_player=AudioStreamPlayer.new(); add_child(preview_player); preview_player.volume_db=-14
    browser=SongBrowser.new(); browser.lobby=self; browser.game=game; add_child(browser)
    browser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    search=browser.search; track_list=browser.list; track_scroll=browser.scroll
    title_label=browser.title_label; source_label=browser.artist_label; detail_label=browser.details_label
    play_button=browser.play; create_chart_button=browser.create; track_count_label=browser.count
    visibility_changed.connect(func():
        if not is_visible_in_tree(): stop_preview()
        elif title_label: schedule_preview())
    refresh(); build_gateway(); show_gateway()
func _process(delta: float) -> void:
    if not is_visible_in_tree() or (gateway and gateway.visible): return
    if preview_delay>=0:
        preview_delay-=delta
        if preview_delay<0: begin_preview()
    if preview_player.playing:
        preview_remaining-=delta
        if preview_remaining<=0: stop_preview()
func play_entrance() -> void:
    UiMotion.reveal(browser)
func refresh() -> void:
    if browser and title_label: refresh_tracks()
static func display_title(raw: String) -> String:
    var cleaned=raw.replace("_"," ")
    var tag=RegEx.create_from_string(r"(?i)\s*[\(\[](mp3|m4a|wav|ogg|flac)[^\)\]]*[\)\]]\s*$")
    cleaned=tag.sub(cleaned,"")
    while cleaned.contains("  "): cleaned=cleaned.replace("  "," ")
    return cleaned.strip_edges()
func selected_track_id() -> String:
    if game.loading_song_index>0 and game.loading_song_index<=game.library.songs.size(): return str(game.library.songs[game.loading_song_index-1].id)
    return str(game.song.id)
static func duration_text(seconds: float) -> String:
    if seconds<=0: return "—:—"
    var total=roundi(seconds); return "%d:%02d" % [total/60,total%60]
func cover_for(id: String) -> Texture2D:
    if id=="eclipse" or game.has_custom_cover(id): return game.cover_texture_for_id(id)
    return SongBrowser.PLACEHOLDER
func style_cover(rect: TextureRect,id: String,radius: float) -> void:
    if id=="eclipse" or game.has_custom_cover(id):
        if rect.material and rect.material.shader==preload("res://scripts/song_placeholder.gdshader"):
            preload("res://scripts/screen_style.gd").round_cover(rect,radius)
        return
    var shader=preload("res://scripts/song_placeholder.gdshader")
    if rect.material==null or rect.material.shader!=shader:
        var mat=ShaderMaterial.new(); mat.shader=shader; rect.material=mat
        rect.resized.connect(func(): mat.set_shader_parameter("rect_size",rect.size))
    var hue=float(posmod(id.hash(),360))/360.0
    rect.material.set_shader_parameter("tint",Color.from_hsv(hue,.65,.95))
    rect.material.set_shader_parameter("secondary",Color.from_hsv(fmod(hue+.22,1),.8,.95))
    rect.material.set_shader_parameter("rect_size",rect.size); rect.material.set_shader_parameter("radius",radius)
func has_variant(id: String,variant: String) -> bool:
    if id=="eclipse" and variant=="original": return true
    return FileAccess.file_exists("user://charts/"+id+("" if variant=="original" else "_"+variant)+".json")
func playable_variant(id: String,variant: String) -> bool:
    if id=="eclipse" and variant=="original": return true
    var path="user://charts/"+id+("" if variant=="original" else "_"+variant)+".json"
    if not FileAccess.file_exists(path): return false
    var data=JSON.parse_string(FileAccess.get_file_as_string(path))
    if not data is Dictionary or str(data.get("song_id",""))!=id: return false
    var notes=SynkChart.notes_from_file(data)
    return notes is Array and not notes.is_empty()
func entry_for(source: Dictionary,index: int) -> Dictionary:
    var id=str(source.id); var meta: Dictionary=game.song_metadata.get(id,{})
    var duration=float(meta.get("duration",game.length() if id==str(game.song.id) else 0.0))
    if id=="eclipse" and game.demo_stream: duration=game.demo_stream.get_length()
    var notes: Array=meta.get("notes",[])
    if id=="eclipse": notes=SynkChart.demo()
    var signature=hash(notes)
    if not ratings.has(id) or ratings[id].signature!=signature:
        var level=int(preload("res://scripts/difficulty_analysis.gd").analyze(notes,maxf(duration,1)).level)
        ratings[id]={"signature":signature,"rating":clampi(ceili(level/6.0),0,5)}
    var accent=game.cover_palette_for_id(id).notes[0] if id=="eclipse" or game.has_custom_cover(id) else Color.from_hsv(float(posmod(id.hash(),360))/360.0,.65,.95)
    return {"index":index,"id":id,"title":display_title(str(source.title)),"artist":artist_line(source),"genre":str(source.get("genre","")),"duration":duration,"bpm":float(source.get("bpm",128)),"rating":ratings[id].rating,"accent":accent}
# "Artist · Album" when the song has details; otherwise the album or library name.
func artist_line(source: Dictionary) -> String:
    var artist=str(source.get("artist","")).strip_edges()
    var album=str(source.get("album","")).strip_edges()
    if artist.is_empty(): return game.album_name(source)
    return artist+("  ·  "+album if not album.is_empty() and album.to_lower()!=artist.to_lower() else "")
func all_entries() -> Array:
    var entries: Array=[entry_for(game.eclipse_song(),0)]
    for i in game.library.songs.size(): entries.append(entry_for(game.library.songs[i],i+1))
    return entries
func set_filter(value: String) -> void:
    if value not in ["all","favorites","recent","new","daily"]: return
    track_filter=value
    # The daily challenge sets today's modifier as it opens.
    if value=="daily" and game.extras: game.extras.start_daily()
    refresh_tracks()
func refresh_tracks() -> void:
    if not browser: return
    var was_empty=filtered_entries.is_empty()
    var query=search.text.strip_edges().to_lower()
    filtered_entries=[]
    for entry in all_entries():
        if track_filter=="favorites" and entry.id not in favorites: continue
        if track_filter=="recent" and not recent.has(entry.id): continue
        if track_filter=="new" and (entry.id=="eclipse" or recent.has(entry.id)): continue
        if track_filter=="daily" and (game.extras==null or entry.id!=str(game.extras.daily().get("id",""))): continue
        if not query.is_empty() and not (entry.title+" "+entry.artist+" "+entry.genre).to_lower().contains(query): continue
        filtered_entries.append(entry)
    if track_filter=="recent": filtered_entries.sort_custom(func(a,b): return float(recent.get(a.id,0))>float(recent.get(b.id,0)))
    if track_filter=="new": filtered_entries.reverse()
    browser.set_rows(filtered_entries)
    if filtered_entries.is_empty():
        stop_preview(); browser.show_empty(); return
    var found=filtered_entries.any(func(e): return str(e.id)==selected_track_id())
    if not found: select_track(int(filtered_entries[0].index))
    refresh_song_details()
    if was_empty: schedule_preview()
func refresh_song_details() -> void:
    if not browser or filtered_entries.is_empty(): return
    var loading=game.loading_song_index>0
    var source: Dictionary=game.library.songs[game.loading_song_index-1] if loading else game.song
    var entry=entry_for(source,game.loading_song_index if loading else 0)
    if not loading: entry.bpm=game.chart_bpm()
    var available=not game.baseline_notes().is_empty() if not loading else has_variant(str(source.id),game.features.current_variant)
    browser.sections.disabled=loading
    if not game.section_available(game.play_mode): game.set_play_mode("full")
    browser.set_details(entry,loading,available)
    for row in track_list.get_children(): row.set_selected(str(row.entry.id)==selected_track_id())
    if not loading and preview_song_id!=str(source.id): schedule_preview()
func update_selected_track() -> void: refresh_song_details()
func update_track_card(id: String) -> void:
    # Metadata updates reuse existing rows and retain scrolling position.
    for row in track_list.get_children():
        if str(row.entry.id)==id:
            for entry in all_entries():
                if str(entry.id)==id: row.update_entry(entry); break
    if id==selected_track_id(): refresh_song_details()
func select_track(index: int) -> void:
    stop_preview()
    var ready=game.select_song(index)
    if ready or game.loading_song_index==index: refresh_song_details()
func toggle_favorite_id(id: String) -> void:
    if id in favorites: favorites.erase(id)
    else: favorites.append(id)
    game.prefs.set_value("lobby","favorites",favorites); game.prefs.save("user://preferences.cfg")
    refresh_tracks()
func toggle_favorite() -> void: toggle_favorite_id(selected_track_id())
func choose_difficulty(variant: String) -> void:
    if game.loading_song_index>0 or not has_variant(str(game.song.id),variant): return
    var index=game.features.VARIANTS.find(variant)
    if index>=0: game.features.choose_variant(index)
func remember_played(id: String) -> void:
    recent[id]=Time.get_unix_time_from_system()
    game.prefs.set_value("lobby","recent",recent); game.prefs.save("user://preferences.cfg")
func press_play() -> void:
    if game.loading_song_index>0 or filtered_entries.is_empty(): return
    var notes: Array=game.baseline_notes()
    if notes.is_empty(): return
    stop_preview(); game.start_game(notes,auto_enabled)
func set_preview_enabled(enabled: bool) -> void:
    preview_enabled=enabled; game.prefs.set_value("audio","song_preview",enabled); game.prefs.save("user://preferences.cfg")
    if enabled: schedule_preview()
    else: stop_preview()
func stop_preview() -> void:
    preview_delay=-1; preview_remaining=0
    if preview_player: preview_player.stop()
func schedule_preview() -> void:
    stop_preview(); preview_song_id=str(game.song.id)
    if preview_enabled and is_visible_in_tree() and not (gateway and gateway.visible) and not filtered_entries.is_empty(): preview_delay=.5
func begin_preview() -> void:
    if game.loading_song_index>0 or not preview_enabled or not is_visible_in_tree() or (gateway and gateway.visible) or filtered_entries.is_empty() or game.mode!="menu" or game.audio.stream==null: return
    var drag=track_scroll.get_node("DragScroll")
    if drag.pressing: preview_delay=.2; return
    preview_player.stream=game.audio.stream
    preview_start=minf(20,maxf(0,game.length()*.25)); preview_remaining=minf(10,game.length()-preview_start)
    preview_player.play(preview_start)

# Home screen, built from the SYNK UI elements (tools/lobby_ui renders them to assets/lobby/ui).
# Positions follow the 1920 x 900 design of the full mockup.
func design_rect(node: Control, parent: Control, x: float, y: float, w: float, h: float) -> void:
    place(node,parent,x/1920.0,y/900.0,(x+w)/1920.0,(y+h)/900.0)

func art(parent: Control, texture: Texture2D, x: float, y: float, w: float, h: float) -> TextureRect:
    var result=TextureRect.new(); design_rect(result,parent,x,y,w,h)
    result.texture=texture; result.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    result.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; result.mouse_filter=Control.MOUSE_FILTER_IGNORE
    return result

func lobby_card(parent: Control,x: float,y: float,w: float,h: float,icon: String,eyebrow: String,title: String,description: String,accent: Color,colors: Array,sound: String) -> Button:
    var card=LobbyCard.new(); card.icon_kind=icon; card.eyebrow=eyebrow; card.title=title
    card.description=description; card.accent=accent; card.colors=colors; card.sound=sound
    design_rect(card,parent,x,y,w,h)
    return card

func build_gateway() -> void:
    gateway=Control.new(); place(gateway,self,0,0,1,1)
    var backdrop=TextureRect.new(); place(backdrop,gateway,0,0,1,1)
    backdrop.texture=HOME_BACKGROUND; backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    # Keep both edge flares visible across landscape aspect ratios.
    backdrop.stretch_mode=TextureRect.STRETCH_SCALE; backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
    # The animated plate shares the still's framing; the still stays as the fallback.
    var home_stream=load(HOME_VIDEO)
    if home_stream:
        home_video=VideoStreamPlayer.new(); place(home_video,gateway,0,0,1,1)
        home_video.stream=home_stream; home_video.loop=true; home_video.expand=true
        home_video.volume_db=-80; home_video.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var atmosphere=ColorRect.new(); place(atmosphere,gateway,0,0,1,1)
    atmosphere.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var atmosphere_material=preload("res://scripts/background_motion.gd").attach(atmosphere,preload("res://scripts/image_atmosphere.gdshader"))
    atmosphere_material.set_shader_parameter("overlay_only",true)
    var dim=ColorRect.new(); place(dim,gateway,0,0,1,1)
    dim.name="LobbyBackgroundDim"; dim.color=Color(0,0,0,.42)
    dim.mouse_filter=Control.MOUSE_FILTER_IGNORE
    # The reference plate already supplies the concert lights; extra procedural beams
    # would replace its appearance with the old flat geometric wash.
    # Same visual language as the song list, settings and Chart Studio: a type-set wordmark,
    # dark rounded cards with gradient icon tiles, and a plain rounded settings button.
    var logo=LobbyWordmark.new(); design_rect(logo,gateway,460,40,1000,250)
    logo.name="LobbyWordmark"
    var safe_buttons=game.safe_parent("SafeLobbyButtons",gateway)
    var play=lobby_card(safe_buttons,560,330,360,420,"play","01 · PLAY","Play","Find your track and chase your best score.",Color("50daec"),[Color("38baff"),Color("753cf0")],"play")
    play.name="PlayCard"; play.tooltip_text="Choose a song and play"
    play.pressed.connect(show_play_browser)
    var create=lobby_card(safe_buttons,1000,330,360,420,"create","02 · CREATE","Create charts","Build the rhythm. Import music, record and edit charts.",Color("d77cff"),[Color("8a4dff"),Color("e04fb0")],"confirm")
    create.name="CreateCard"; create.tooltip_text="Edit charts, import music, and record notes"
    create.pressed.connect(func(): game.open_editor())
    var settings=preload("res://scripts/gear_button.gd").new(); design_rect(settings,safe_buttons,1756,32,120,120)
    settings.name="SettingsButton"; settings.accent=Color("bcb2d4")
    settings.pressed.connect(func(): game.open_lobby_settings())
    var footer=text(gateway,"Play your charts. Create your sound.",.2,.885,.8,.94,22,Color("b4b6d2"))
    footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    gateway_entrance_items=[{"node":logo,"delay":.02},{"node":play,"delay":.10},{"node":create,"delay":.16},{"node":footer,"delay":.24}]
    gateway.visible=false

func show_gateway() -> void:
    if not gateway or gateway.visible: return
    if is_visible_in_tree(): UiMotion.back(self)
    stop_preview()
    browser_visibility=[]
    for node in get_children():
        if node is Control and node!=gateway:
            browser_visibility.append({"node":node,"visible":node.visible})
            node.visible=false
    gateway.visible=true
    if background_video: background_video.paused=true
    if home_video:
        if home_video.is_playing(): home_video.paused=false
        else: home_video.play()
    UiMotion.reveal(gateway)
    for item in gateway_entrance_items: UiMotion.reveal(item.node,item.delay)

func show_play_browser() -> void:
    UiMotion.transition(self,.36)
    if gateway: gateway.visible=false
    if background_video: background_video.paused=false
    if home_video: home_video.paused=true
    for item in browser_visibility:
        if is_instance_valid(item.node): item.node.visible=item.visible
    refresh()
    schedule_preview()
    play_entrance()
