extends Control
const UiMotion = preload("res://scripts/ui_motion.gd")
const NeonPlay = preload("res://scripts/neon_play.gd")
const NeonAction = preload("res://scripts/neon_action.gd")
const GearButton = preload("res://scripts/gear_button.gd")
const DragScroll = preload("res://scripts/drag_scroll.gd")
const SongCard = preload("res://scripts/record_tile.gd")
const Carousel = preload("res://scripts/song_carousel.gd")
const AnimatedLogo = preload("res://scripts/animated_logo.gd")
const AutoplayToggle = preload("res://scripts/autoplay_toggle.gd")
const STUDIO_ICON = preload("res://assets/brand/chart_studio.svg")
const BACKGROUND = preload("res://assets/lobby/concert_background.png")
const BACKGROUND_VIDEO = "res://assets/lobby/lobby_loop.ogv"
const VIDEO_SIZE = Vector2(1280,720)
const COVER = preload("res://assets/lobby/eclipse_cover.png")
const PURPLE = Color("b35cff")
const BLUE = Color("49c8ff")
var gateway: Control
var browser_visibility: Array=[]
var game: Control
var background_video: VideoStreamPlayer
var hero_art: TextureRect
var background_stack: Control
var atmosphere_tween: Tween
var entrance_items: Array=[]
var entrance_rows_delay=0.0
var track_filter="all"
var search: LineEdit
var track_list: GridContainer
var title_label: Label
var source_label: Label
var detail_label: Label
var play_button: Button
var create_chart_button: Button
var settings_button: Button
var auto_button: Button
var auto_enabled=false
var all_tab: Button
var originals_tab: Button
var mode_buttons: Dictionary={}
var track_scroll: ScrollContainer
var track_count_label: Label
var imported_tab: Button
var favorites_tab: Button
var favorite_button: Button
var grid_button: Button
var carousel: Control
var grid_mode = false
var filtered_entries: Array = []
var favorites: Array = []
var preview_player: AudioStreamPlayer
var preview_delay = -1.0
var preview_remaining = 0.0
var preview_song_id = ""
var preview_enabled = true
var preview_start = 0.0
var atmosphere: ColorRect
var position_label: Label
var empty_label: Label
var previous_button: Button
var next_button: Button

func place(node: Control, parent: Node, left: float, top: float, right: float, bottom: float) -> void:
	parent.add_child(node)
	node.anchor_left=left; node.anchor_top=top; node.anchor_right=right; node.anchor_bottom=bottom
	node.offset_left=0; node.offset_top=0; node.offset_right=0; node.offset_bottom=0

func pane(parent: Node, left: float, top: float, right: float, bottom: float, fill: Color, edge: Color, radius: int = 12) -> Panel:
	var result=Panel.new(); place(result,parent,left,top,right,bottom)
	var style=StyleBoxFlat.new(); style.bg_color=fill; style.border_color=edge
	style.set_border_width_all(1); style.set_corner_radius_all(radius)
	result.add_theme_stylebox_override("panel",style)
	return result

func text(parent: Node, value: String, left: float, top: float, right: float, bottom: float, font_size: int, color: Color = Color("f3edff")) -> Label:
	var result=Label.new(); place(result,parent,left,top,right,bottom)
	result.text=value; result.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

func action(parent: Node, value: String, left: float, top: float, right: float, bottom: float, callback: Callable, variant: String = "secondary") -> Button:
	var result=NeonAction.new()
	result.caption_text=value; result.caption_size=24 if variant=="primary" else 19
	result.variant=variant
	place(result,parent,left,top,right,bottom)
	result.pressed.connect(callback)
	return result

func readable(value: Label) -> Label:
	value.add_theme_color_override("font_shadow_color",Color(0,0,.02,.8))
	value.add_theme_constant_override("shadow_offset_y",2)
	value.add_theme_constant_override("shadow_outline_size",8)
	return value

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_PASS
	var background=TextureRect.new(); place(background,self,0,0,1,1)
	background.texture=BACKGROUND; background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_background_video()
	var shade=ColorRect.new(); place(shade,self,0,0,1,1)
	shade.color=Color(.005,.008,.035,.27); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var header=Control.new(); place(header,self,0,0,1,.115); header.mouse_filter=Control.MOUSE_FILTER_IGNORE
	settings_button=GearButton.new(); place(settings_button,header,.935,.14,.975,.86)
	settings_button.pressed.connect(func(): game.open_lobby_settings())
	auto_button=AutoplayToggle.new(); place(auto_button,header,.845,.10,.925,.98)
	auto_button.toggled.connect(func(enabled): auto_enabled=enabled)
	# A selected cover gently colors the concert backdrop.
	background_stack=Control.new(); place(background_stack,self,0,0,1,1); background_stack.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hero_art=TextureRect.new(); place(hero_art,background_stack,0,0,1,1)
	hero_art.texture=COVER; hero_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	hero_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_art.modulate.a=.14; hero_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	atmosphere=ColorRect.new(); place(atmosphere,self,0,0,1,1)
	atmosphere.color=Color(.08,.025,.18,.30); atmosphere.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# The gateway owns the logo; this screen gives its space to the music.
	var prefs=game.prefs
	preview_enabled=bool(prefs.get_value("audio","song_preview",true))
	favorites=prefs.get_value("lobby","favorites",[])
	preview_player=AudioStreamPlayer.new(); add_child(preview_player); preview_player.volume_db=-14
	visibility_changed.connect(func():
		if not is_visible_in_tree(): stop_preview()
		elif title_label: schedule_preview())
	var tools=Control.new(); place(tools,self,.035,.12,.935,.18); tools.mouse_filter=Control.MOUSE_FILTER_IGNORE
	all_tab=action(tools,"ALL",0,0,.12,1,func(): set_filter("all"),"tool")
	originals_tab=action(tools,"ORIGINALS",.13,0,.29,1,func(): set_filter("originals"),"tool")
	imported_tab=action(tools,"IMPORTED",.30,0,.46,1,func(): set_filter("imported"),"tool")
	favorites_tab=action(tools,"FAVORITES",.47,0,.64,1,func(): set_filter("favorites"),"tool")
	for tab in [all_tab,originals_tab,imported_tab,favorites_tab]:
		tab.compact=true; tab.caption_size=15
	search=LineEdit.new(); place(search,tools,.68,0,.91,1)
	search.placeholder_text="Search songs"; search.add_theme_font_size_override("font_size",18)
	var search_style=StyleBoxFlat.new(); search_style.bg_color=Color(.025,.02,.08,.7)
	search_style.border_color=Color("9271cd"); search_style.border_width_bottom=2
	search_style.set_corner_radius_all(8); search_style.content_margin_left=12
	for state in ["normal","focus"]: search.add_theme_stylebox_override(state,search_style)
	search.text_changed.connect(func(_value): refresh_tracks())
	grid_button=action(tools,"GRID",.93,0,1.03,1,toggle_grid,"tool")
	grid_button.compact=true; grid_button.caption_size=14
	grid_button.set_content_icon(load("res://assets/brand/grid.svg"))
	carousel=Carousel.new(); place(carousel,self,.10,.34,.90,.975)
	carousel.song_selected.connect(select_track)
	previous_button=action(self,"‹",.035,.60,.085,.69,func(): carousel.step(-1),"nav")
	next_button=action(self,"›",.915,.60,.965,.69,func(): carousel.step(1),"nav")
	track_scroll=ScrollContainer.new(); place(track_scroll,self,.10,.35,.90,.84)
	track_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	track_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	DragScroll.attach(track_scroll)
	track_list=GridContainer.new(); track_scroll.add_child(track_list)
	track_list.columns=6; track_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	track_list.add_theme_constant_override("h_separation",16); track_list.add_theme_constant_override("v_separation",18)
	track_scroll.visible=false
	empty_label=text(self,"",.2,.48,.8,.66,24,Color("c6b9df"))
	empty_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	track_count_label=text(self,"",.035,.185,.25,.22,13,Color("b6a3d5"))
	position_label=text(self,"",.80,.185,.965,.22,13,Color("b6a3d5")); position_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	source_label=readable(text(self,"",.22,.075,.77,.11,14,Color("bca9e6")))
	source_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title_label=readable(text(self,"",.22,.015,.77,.075,32))
	title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title_label.clip_text=true; title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label=readable(text(self,"",.035,.225,.48,.265,16,Color("d5c7ed")))
	detail_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	favorite_button=action(self,"☆",.78,.025,.825,.085,toggle_favorite,"tool")
	var modes=[["full","FULL"],["verse1","VERSE 1"],["verse2","VERSE 2"],["bridge","BRIDGE"]]
	for i in modes.size():
		var mode_name: String=modes[i][0]
		var chip=action(self,modes[i][1],.52+i*.11,.245,.622+i*.11,.31,func(): game.set_play_mode(mode_name); refresh_modes(),"tool")
		chip.compact=true; chip.caption_size=12; mode_buttons[mode_name]=chip
	var dock=Control.new(); place(dock,self,0,.875,1,.995); dock.mouse_filter=Control.MOUSE_FILTER_IGNORE
	action(header,"‹ MAIN LOBBY",.025,.18,.205,.80,show_gateway,"nav")
	play_button=NeonPlay.new(); place(play_button,dock,.765,0,.975,1); play_button.pressed.connect(press_play)
	create_chart_button=action(dock,"NO CHART YET",.765,.08,.975,.92,func(): pass,"tool")
	text(self,"SWIPE TO EXPLORE",.40,.32,.60,.35,12,Color("aa98c4")).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for item in [tools,carousel,source_label,title_label,detail_label,dock]:
		entrance_items.append({"node":item,"delay":.18,"offset":Vector2(0,18)})
	move_child(header,get_child_count()-1)
	refresh()
	build_gateway()
	show_gateway()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or (gateway and gateway.visible): return
	update_wheel()
	if preview_delay>=0:
		preview_delay-=delta
		if preview_delay<0: begin_preview()
	if preview_player.playing:
		preview_remaining-=delta
		if preview_remaining<=0: stop_preview()

func update_wheel() -> void:
	if track_list==null: return
	var side=maxf(120,(track_scroll.size.x-5*16-20)/6.0)
	for row in track_list.get_children():
		if row is Button: row.custom_minimum_size=Vector2(side,side+36)

func add_background_video() -> void:
	var stream=load(BACKGROUND_VIDEO)
	if stream==null: return
	var frame=Control.new(); place(frame,self,0,0,1,1)
	frame.clip_contents=true; frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	background_video=VideoStreamPlayer.new(); frame.add_child(background_video)
	background_video.stream=stream; background_video.loop=true; background_video.expand=true
	background_video.volume_db=-80; background_video.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.resized.connect(func(): cover_background_video(frame.size))
	visibility_changed.connect(update_background_video)
	background_video.play(); cover_background_video(frame.size)
func cover_background_video(area: Vector2) -> void:
	var factor=maxf(area.x/VIDEO_SIZE.x,area.y/VIDEO_SIZE.y)
	background_video.size=VIDEO_SIZE*factor; background_video.position=(area-background_video.size)*.5
func update_background_video() -> void:
	if background_video: background_video.paused=not is_visible_in_tree() or (gateway!=null and gateway.visible)
func set_filter(value: String) -> void:
	track_filter=value; refresh_tracks()
func refresh() -> void:
	if game==null or title_label==null: return
	refresh_tracks()
func play_entrance() -> void:
	for item in entrance_items:
		UiMotion.reveal(item.node,item.delay)

func refresh_song_details() -> void:
	var selected: Dictionary=game.song
	var loading=game.loading_song_index>0 and game.loading_song_index<=game.library.songs.size()
	if loading: selected=game.library.songs[game.loading_song_index-1]
	title_label.text=display_title(str(selected.title))
	var tinted=selected.id!="eclipse" and not game.has_custom_cover(str(selected.id))
	transition_cover(game.cover_texture_for_id(str(selected.id)),game.cover_tint_for_id(str(selected.id)) if tinted else Color.WHITE)
	source_label.text=game.album_name(selected).to_upper()
	refresh_modes()
	var has_chart=not game.baseline_notes().is_empty()
	if loading: has_chart=game.library.has_chart(str(selected.id))
	var difficulty="EXPERT · Lv. 12" if selected.id=="eclipse" else ("CUSTOM CHART" if has_chart else "NO CHART YET")
	var duration=roundi(game.length())
	detail_label.text="%s     /     %d BPM     /     %d:%02d" % [difficulty,roundi(float(selected.bpm) if loading else game.chart_bpm()),duration/60,duration%60]
	if loading: detail_label.text="LOADING SONG…"
	play_button.visible=has_chart and not filtered_entries.is_empty()
	create_chart_button.visible=not has_chart and not filtered_entries.is_empty()
	play_button.disabled=loading; create_chart_button.disabled=true
	favorite_button.caption_text="★" if favorites.has(str(selected.id)) else "☆"
	favorite_button.tooltip_text="Remove favorite" if favorites.has(str(selected.id)) else "Favorite song"
	if favorite_button.caption: favorite_button.caption.text=favorite_button.caption_text
	var tint: Color=game.cover_palette_for_id(str(selected.id)).notes[0]
	var shade=Color(tint.r*.15,tint.g*.10,tint.b*.18,.26)
	if atmosphere_tween and atmosphere_tween.is_running(): atmosphere_tween.kill()
	atmosphere_tween=create_tween(); atmosphere_tween.tween_property(atmosphere,"color",shade,.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not loading and preview_song_id!=str(selected.id): schedule_preview()
	update_position()

func selected_track_id() -> String:
	if game.loading_song_index>0 and game.loading_song_index<=game.library.songs.size(): return str(game.library.songs[game.loading_song_index-1].id)
	return str(game.song.id)

func transition_cover(texture_value: Texture2D,tint: Color) -> void:
	if hero_art.texture==texture_value and hero_art.self_modulate==tint: return
	for layer in background_stack.get_children():
		var old_tween=layer.get_meta("cover_tween") if layer.has_meta("cover_tween") else null
		if old_tween is Tween and old_tween.is_running(): old_tween.kill()
		var fade=create_tween()
		fade.tween_property(layer,"modulate:a",0.0,.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade.tween_callback(layer.queue_free); layer.set_meta("cover_tween",fade)
	hero_art=TextureRect.new(); place(hero_art,background_stack,0,0,1,1)
	hero_art.texture=texture_value; hero_art.self_modulate=tint
	hero_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; hero_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_art.mouse_filter=Control.MOUSE_FILTER_IGNORE; hero_art.modulate.a=0
	var fade=create_tween()
	fade.tween_property(hero_art,"modulate:a",.14,.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hero_art.set_meta("cover_tween",fade)

func update_selected_track() -> void:
	refresh_song_details()
	carousel.select_id(selected_track_id())
	for row in track_list.get_children():
		if row is Button: row.set_selected(str(row.get_meta("song_id",""))==selected_track_id())

static func display_title(raw: String) -> String:
	var cleaned=raw.replace("_"," ")
	var tag=RegEx.create_from_string(r"(?i)\s*[\(\[](mp3|m4a|wav|ogg|flac)[^\)\]]*[\)\]]\s*$")
	cleaned=tag.sub(cleaned,"")
	while cleaned.contains("  "): cleaned=cleaned.replace("  "," ")
	return cleaned.strip_edges()

func update_track_card(id: String) -> void:
	var tinted=id!="eclipse" and not game.has_custom_cover(id)
	var rows=track_list.get_children()+carousel.cards
	for row in rows:
		if str(row.get_meta("song_id",""))==id:
			row.cover_rect.texture=game.cover_texture_for_id(id)
			row.cover_rect.self_modulate=game.cover_tint_for_id(id) if tinted else Color.WHITE

func refresh_tracks() -> void:
	if track_list==null: return
	for tab in [[all_tab,"all"],[originals_tab,"originals"],[imported_tab,"imported"],[favorites_tab,"favorites"]]:
		tab[0].set_selected(track_filter==tab[1])
	var entries: Array=[]
	var eclipse: Dictionary=game.eclipse_song()
	entries.append({"index":0,"id":"eclipse","title":display_title(str(eclipse.title)),"badge":"EXPERT"})
	for i in game.library.songs.size():
		var song=game.library.songs[i]
		entries.append({"index":i+1,"id":str(song.id),"title":display_title(str(song.title)),"badge":"CHARTED" if game.library.has_chart(str(song.id)) else "NO CHART"})
	filtered_entries=[]
	for entry in entries:
		if track_filter=="originals" and entry.id!="eclipse": continue
		if track_filter=="imported" and entry.id=="eclipse": continue
		if track_filter=="favorites" and not favorites.has(str(entry.id)): continue
		if not search.text.strip_edges().is_empty() and not str(entry.title).to_lower().contains(search.text.strip_edges().to_lower()): continue
		filtered_entries.append(entry)
	sync_grid()
	carousel.set_songs(filtered_entries,selected_track_id(),game)
	track_count_label.text="%d TRACK%s" % [filtered_entries.size(),"" if filtered_entries.size()==1 else "S"]
	empty_label.text="No favorites yet. Tap ☆ beside a song." if track_filter=="favorites" else ("No matching songs." if not search.text.is_empty() else "Your next track starts here.
Import music in Chart Studio.")
	empty_label.visible=filtered_entries.is_empty()
	previous_button.disabled=filtered_entries.size()<2; next_button.disabled=filtered_entries.size()<2
	update_wheel()
	if not filtered_entries.is_empty():
		var found=false
		for entry in filtered_entries:
			if str(entry.id)==selected_track_id(): found=true
		if not found: select_track(int(filtered_entries[0].index))
	refresh_song_details()
	var has_songs=not filtered_entries.is_empty()
	for element in [title_label,source_label,detail_label,favorite_button]: element.visible=has_songs
	if not has_songs: stop_preview()

func sync_grid() -> void:
	var existing: Dictionary={}
	for row in track_list.get_children(): existing[str(row.get_meta("song_id"))]=row
	for i in filtered_entries.size():
		var entry=filtered_entries[i]; var id=str(entry.id)
		var row=existing.get(id)
		var tinted=id!="eclipse" and not game.has_custom_cover(id)
		if row==null:
			row=SongCard.new(str(entry.title),str(entry.badge),game.cover_texture_for_id(id),game.cover_tint_for_id(id) if tinted else Color.WHITE)
			row.compact=true; track_list.add_child(row); row.set_meta("song_id",id)
			row.pressed.connect(func(): select_grid_track(int(row.get_meta("song_index")))); row.mouse_filter=Control.MOUSE_FILTER_PASS
		else:
			existing.erase(id); row.title_label.text=entry.title; row.badge_label.text=entry.badge
		row.set_meta("song_index",int(entry.index))
		track_list.move_child(row,i); row.set_selected(id==selected_track_id())
	for row in existing.values(): track_list.remove_child(row); row.queue_free()

func update_position() -> void:
	var position=0
	for i in filtered_entries.size():
		if str(filtered_entries[i].id)==selected_track_id(): position=i+1
	position_label.text="%02d / %02d" % [position,filtered_entries.size()]

func toggle_grid() -> void:
	grid_mode=not grid_mode
	track_scroll.visible=grid_mode; carousel.visible=not grid_mode
	previous_button.visible=not grid_mode; next_button.visible=not grid_mode
	grid_button.caption_text="COVERS" if grid_mode else "GRID"
	grid_button.caption.text=grid_button.caption_text
	grid_button.set_selected(grid_mode)

func toggle_favorite() -> void:
	var id=selected_track_id()
	if favorites.has(id): favorites.erase(id)
	else: favorites.append(id)
	game.prefs.set_value("lobby","favorites",favorites); game.prefs.save("user://preferences.cfg")
	refresh_tracks()

func set_preview_enabled(enabled: bool) -> void:
	preview_enabled=enabled
	game.prefs.set_value("audio","song_preview",enabled); game.prefs.save("user://preferences.cfg")
	if enabled: schedule_preview()
	else: stop_preview()

func stop_preview() -> void:
	preview_delay=-1.0; preview_remaining=0.0
	if preview_player: preview_player.stop()

func schedule_preview() -> void:
	stop_preview()
	preview_song_id=str(game.song.id)
	if preview_enabled and is_visible_in_tree() and not (gateway and gateway.visible): preview_delay=.5

func begin_preview() -> void:
	if game.loading_song_index>0 or carousel.dragging or (gateway and gateway.visible) or not preview_enabled or not is_visible_in_tree() or game.mode!="menu" or game.audio.stream==null: return
	preview_player.stream=game.audio.stream
	preview_start=minf(20.0,maxf(0.0,game.length()*.25))
	preview_remaining=minf(10.0,game.length()-preview_start)
	preview_player.play(preview_start)

func refresh_modes() -> void:
	if not game.section_available(game.play_mode): game.set_play_mode("full")
	for mode_name in mode_buttons:
		mode_buttons[mode_name].disabled=not game.section_available(mode_name)
		mode_buttons[mode_name].set_selected(game.play_mode==mode_name)
func section_ready() -> bool: return game.section_available(game.play_mode)
func select_track(index: int) -> void:
	if grid_mode and DragScroll.was_dragged(track_scroll): return
	stop_preview()
	var ready=game.select_song(index)
	if ready: update_selected_track(); schedule_preview()
	elif game.loading_song_index==index:
		update_selected_track()
	else: carousel.select_id(str(game.song.id))
func press_play() -> void:
	if game.loading_song_index>0: return
	stop_preview()
	var notes: Array=game.baseline_notes()
	if notes.is_empty(): detail_label.text="Create a chart for this song in CREATE CHARTS."
	else: game.start_game(notes,auto_enabled)
func press_auto() -> void:
	auto_button.button_pressed=not auto_button.button_pressed

func select_grid_track(index: int) -> void:
	if DragScroll.was_dragged(track_scroll): return
	select_track(index)
	if grid_mode: toggle_grid()

func build_gateway() -> void:
	gateway=Control.new(); place(gateway,self,0,0,1,1)
	var backdrop=TextureRect.new(); place(backdrop,gateway,0,0,1,1)
	backdrop.texture=BACKGROUND; backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shade=ColorRect.new(); place(shade,gateway,0,0,1,1)
	shade.color=Color(.012,.01,.045,.78); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var logo=AnimatedLogo.new(); place(logo,gateway,.25,.025,.75,.30)
	var title=text(gateway,"CHOOSE YOUR RHYTHM",.25,.30,.75,.37,20,Color("cbb9ec"))
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var play=load("res://scripts/mode_portal.gd").new(); play.kind="play"
	place(play,gateway,.12,.41,.485,.83); play.pressed.connect(show_play_browser)
	var create=load("res://scripts/mode_portal.gd").new(); create.kind="create"; create.accent=Color("d78aff")
	place(create,gateway,.515,.41,.88,.83); create.pressed.connect(func(): game.open_editor())
	var settings=GearButton.new(); place(settings,gateway,.92,.045,.97,.135)
	settings.pressed.connect(func(): game.open_lobby_settings())
	var footer=text(gateway,"PLAY YOUR CHARTS. CREATE YOUR SOUND.",.2,.88,.8,.94,14,Color("9383b2"))
	footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	gateway.visible=false

func show_gateway() -> void:
	if not gateway or gateway.visible: return
	if is_visible_in_tree(): UiMotion.transition(self)
	stop_preview()
	browser_visibility=[]
	for node in get_children():
		if node is Control and node!=gateway:
			browser_visibility.append({"node":node,"visible":node.visible})
			node.visible=false
	gateway.visible=true
	if background_video: background_video.paused=true
	UiMotion.reveal(gateway)

func show_play_browser() -> void:
	UiMotion.transition(self,.36)
	if gateway: gateway.visible=false
	if background_video: background_video.paused=false
	for item in browser_visibility:
		if is_instance_valid(item.node): item.node.visible=item.visible
	refresh()
	schedule_preview()
	play_entrance()
