extends Control

const UiMotion = preload("res://scripts/ui_motion.gd")
const NeonPlay = preload("res://scripts/neon_play.gd")
const NeonAction = preload("res://scripts/neon_action.gd")
const BACKGROUND = preload("res://assets/lobby/city_background.png")
const COVER = preload("res://assets/lobby/eclipse_cover.png")
const PURPLE = Color("b35cff")
const BLUE = Color("49c8ff")

var game: Control
var track_filter = "all"
var search: LineEdit
var track_list: VBoxContainer
var title_label: Label
var source_label: Label
var detail_label: Label
var play_button: Button
var create_chart_button: Button
var guide_button: Button
var all_tab: Button
var originals_tab: Button
var imported_tab: Button

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

func action(parent: Node, value: String, left: float, top: float, right: float, bottom: float, callback: Callable, accent: Color = PURPLE, strong: bool = false) -> Button:
	var result=NeonAction.new()
	result.caption_text=value; result.caption_size=24 if strong else 19
	result.accent_color=accent; result.selected=strong
	place(result,parent,left,top,right,bottom)
	result.pressed.connect(callback)
	return result

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_PASS
	var background=TextureRect.new(); place(background,self,0,0,1,1)
	background.texture=BACKGROUND; background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shade=ColorRect.new(); place(shade,self,0,0,1,1)
	shade.color=Color(.005,.008,.035,.27); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var header=pane(self,0,0,1,.115,Color(.009,.012,.045,.91),Color(.30,.16,.49,.9),0)
	var logo=text(header,"S Y N K",.035,.1,.24,.9,48,Color("f6edff"))
	logo.add_theme_color_override("font_outline_color",Color("7c2dff"))
	logo.add_theme_constant_override("outline_size",5)
	text(header,"RHYTHM  /  13 LANES",.27,.18,.56,.82,19,Color("aeb6e3"))
	guide_button=action(header,"NOTE GUIDE",.70,.2,.83,.8,func(): game.set_mode("guide"),BLUE)
	action(header,"SETTINGS",.85,.2,.975,.8,func(): game.open_lobby_settings())
	var cover=pane(self,.025,.19,.318,.735,Color(.025,.012,.09,.92),Color("b969ff"),13)
	cover.clip_contents=true
	var cover_art=TextureRect.new(); place(cover_art,cover,.012,.009,.988,.991)
	cover_art.texture=COVER; cover_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	cover_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var hero=pane(self,.335,.19,.615,.735,Color(.008,.014,.06,.76),Color(.36,.22,.59,.75))
	source_label=text(hero,"SYNK ORIGINALS",.07,.105,.95,.19,21,Color("c5b1ff"))
	title_label=text(hero,"ECLIPSE",.07,.20,.96,.37,49)
	text(hero,"SELECTED TRACK",.07,.04,.94,.11,16,Color("86d9ff"))
	var rule=ColorRect.new(); place(rule,hero,.07,.385,.91,.389)
	rule.color=Color("8859c2"); rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
	detail_label=text(hero,"",.07,.42,.94,.70,23,Color("ddd8ff"))
	detail_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text(hero,"Choose a track, then play or make a chart.",.07,.76,.94,.93,18,Color("b5b6d4")).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var browser=pane(self,.635,.15,.982,.77,Color(.006,.010,.041,.91),Color(.48,.28,.76,.9))
	text(browser,"TRACKS",.045,.03,.44,.12,29)
	search=LineEdit.new(); place(search,browser,.48,.035,.955,.115)
	search.placeholder_text="Search songs"; search.add_theme_font_size_override("font_size",18)
	search.text_changed.connect(func(_value): refresh_tracks())
	all_tab=action(browser,"ALL",.045,.145,.32,.225,func(): set_filter("all"))
	originals_tab=action(browser,"ORIGINALS",.335,.145,.66,.225,func(): set_filter("originals"))
	imported_tab=action(browser,"IMPORTED",.675,.145,.955,.225,func(): set_filter("imported"),BLUE)
	var scroll=ScrollContainer.new(); place(scroll,browser,.045,.255,.955,.965)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	track_list=VBoxContainer.new(); scroll.add_child(track_list)
	track_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	track_list.add_theme_constant_override("separation",8)
	var dock=pane(self,.025,.805,.982,.955,Color(.006,.008,.037,.90),Color(.40,.23,.68,.9))
	action(dock,"CHART STUDIO\nIMPORT AUDIO",.025,.13,.245,.87,func(): game.open_editor(),BLUE)
	action(dock,"RECORD NOTES",.265,.13,.48,.87,func(): game.start_new_recording())
	action(dock,"AUTO PLAY",.50,.13,.695,.87,press_auto,BLUE)
	play_button=NeonPlay.new(); place(play_button,dock,.69,.11,.99,.89)
	play_button.pressed.connect(press_play)
	create_chart_button=action(dock,"CREATE CHART  »",.69,.11,.99,.89,press_play,PURPLE,true)
	refresh()

func set_filter(value: String) -> void:
	track_filter=value
	refresh_tracks()

func refresh() -> void:
	if game==null or title_label==null: return
	refresh_song_details()
	refresh_tracks()

func refresh_song_details() -> void:
	var selected: Dictionary=game.song
	title_label.text=str(selected.title).to_upper()
	source_label.text="SYNK ORIGINALS" if selected.id=="eclipse" else "IMPORTED MUSIC"
	var has_chart=not game.baseline_notes().is_empty()
	var difficulty="EXPERT  /  Lv. 12" if selected.id=="eclipse" else ("CUSTOM CHART" if has_chart else "NO CHART YET")
	detail_label.text="%s\n%d BPM   •   %d SEC\n%s" % [difficulty,roundi(float(selected.bpm)),roundi(game.length()),"READY TO PLAY" if has_chart else "CREATE A CHART IN STUDIO"]
	play_button.visible=has_chart
	create_chart_button.visible=not has_chart
	play_button.disabled=false; create_chart_button.disabled=false

func update_selected_track() -> void:
	refresh_song_details()
	for row in track_list.get_children():
		if not row is Button: continue
		var selected=str(row.get_meta("song_id",""))==str(game.song.id)
		row.set_selected(selected)

func refresh_tracks() -> void:
	if track_list==null: return
	for child in track_list.get_children():
		track_list.remove_child(child); child.queue_free()
	all_tab.modulate=Color.WHITE if track_filter=="all" else Color(.65,.65,.8)
	originals_tab.modulate=Color.WHITE if track_filter=="originals" else Color(.65,.65,.8)
	imported_tab.modulate=Color.WHITE if track_filter=="imported" else Color(.65,.65,.8)
	var entries: Array=[]
	if track_filter!="imported": entries.append({"index":0,"title":"Eclipse","subtitle":"SYNK Originals  •  Expert"})
	if track_filter!="originals":
		for i in game.library.songs.size():
			var song: Dictionary=game.library.songs[i]
			entries.append({"index":i+1,"title":str(song.title),"subtitle":"Imported  •  %d BPM" % roundi(float(song.bpm))})
	var visible_count=0
	for entry in entries:
		if not search.text.is_empty() and not str(entry.title).to_lower().contains(search.text.to_lower()): continue
		visible_count+=1
		var selected=str(game.song.id)==("eclipse" if int(entry.index)==0 else str(game.library.songs[int(entry.index)-1].id))
		var row=NeonAction.new()
		row.caption_text="%s\n%s" % [str(entry.title).to_upper(),str(entry.subtitle)]
		row.caption_size=18; row.left_aligned=true; row.accent_color=PURPLE; row.selected=selected
		track_list.add_child(row)
		row.set_meta("song_id","eclipse" if int(entry.index)==0 else str(game.library.songs[int(entry.index)-1].id))
		row.custom_minimum_size=Vector2(0,91); row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.pressed.connect(select_track.bind(int(entry.index)))
	if visible_count==0:
		var empty=Label.new(); track_list.add_child(empty)
		empty.text="No songs here yet.\nImport music in Chart Studio." if search.text.is_empty() else "No matching songs."
		empty.add_theme_font_size_override("font_size",19)
		empty.add_theme_color_override("font_color",Color("bbb3d6"))

func select_track(index: int) -> void:
	var ready=game.select_song(index)
	if ready: update_selected_track()
	if not ready and game.loading_song_index==index:
		detail_label.text="LOADING SONG…\nAudio and chart details are being prepared"
		play_button.disabled=true; create_chart_button.disabled=true

func press_play() -> void:
	var notes: Array=game.baseline_notes()
	if notes.is_empty(): game.open_editor()
	else: game.start_game(notes)

func press_auto() -> void:
	if game.baseline_notes().is_empty(): game.open_editor()
	else: game.start_autoplay()
