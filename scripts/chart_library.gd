extends Control

const UiMotion = preload("res://scripts/ui_motion.gd")
const NeonAction = preload("res://scripts/neon_action.gd")
const DragScroll = preload("res://scripts/drag_scroll.gd")
const BACKGROUND = preload("res://assets/lobby/city_background.png")
const ScreenStyle = preload("res://scripts/screen_style.gd")
var search: LineEdit
var library_filter="all"
var filter_buttons: Dictionary={}

var game: Control
var grid: GridContainer
var count_label: Label
var message_label: Label
var chart_cards: Array = []
var scroll: ScrollContainer
var confirm: Control
var confirm_title: Label
var confirm_body: Label
var confirm_chart_button: Button
var confirm_song_button: Button
var pending_delete: Dictionary = {}

func place(node: Control, parent: Node, left: float, top: float, right: float, bottom: float) -> void:
	parent.add_child(node)
	node.anchor_left=left; node.anchor_top=top; node.anchor_right=right; node.anchor_bottom=bottom
	node.offset_left=0; node.offset_top=0; node.offset_right=0; node.offset_bottom=0

func label(parent: Node, value: String, left: float, top: float, right: float, bottom: float, size: int, tint: Color = Color("f5edff")) -> Label:
	var result=Label.new(); place(result,parent,left,top,right,bottom)
	result.text=value; result.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",tint)
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

func button(parent: Node, value: String, left: float, top: float, right: float, bottom: float, callback: Callable, variant: String = "secondary") -> Button:
	var result=NeonAction.new()
	result.text=value; result.caption_size=20 if variant=="primary" else 18; result.compact=true
	result.variant=variant
	place(result,parent,left,top,right,bottom)
	result.pressed.connect(callback)
	return result

func _ready() -> void:
	var backdrop=TextureRect.new(); place(backdrop,self,0,0,1,1)
	backdrop.texture=BACKGROUND; backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shade=ColorRect.new(); place(shade,self,0,0,1,1)
	shade.color=Color(.006,.008,.035,.74); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label(self,"CHART LIBRARY",.05,.035,.48,.115,48)
	count_label=label(self,"",.05,.11,.66,.17,22,Color("cbb9f7"))
	button(self,"IMPORT AUDIO  +",.67,.045,.84,.12,func(): game.choose_audio(),"primary")
	button(self,"‹  LOBBY",.85,.045,.97,.12,func(): game.set_mode("menu"),"nav")
	var line=ColorRect.new(); place(line,self,.05,.182,.95,.185)
	line.color=Color("8150bd"); line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	search=LineEdit.new(); place(search,self,.055,.205,.45,.27)
	search.placeholder_text="Find a song or chart…"; search.add_theme_font_size_override("font_size",19)
	search.text_changed.connect(func(_value): refresh())
	for i in 3:
		var key=["all","charted","new"][i]
		filter_buttons[key]=button(self,["ALL","CHARTED","NEW CHART"][i],.49+i*.155,.205,.63+i*.155,.27,func(): library_filter=key; refresh(),"tool")
	scroll=ScrollContainer.new(); place(scroll,self,.055,.30,.95,.875)
	DragScroll.attach(scroll)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	grid=GridContainer.new(); scroll.add_child(grid)
	grid.columns=4; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",26)
	grid.add_theme_constant_override("v_separation",22)
	message_label=label(self,"Select a cover to edit its chart. Import audio to start a new one.",.055,.89,.95,.955,21,Color("c1b5dc"))
	build_confirm()
	resized.connect(layout_cards)
	refresh()

func build_confirm() -> void:
	# Deleting is permanent, so it always asks first.
	confirm=Control.new(); place(confirm,self,0,0,1,1); confirm.mouse_filter=Control.MOUSE_FILTER_STOP
	var dim=ColorRect.new(); place(dim,confirm,0,0,1,1); dim.color=Color(0,0,.02,.72); dim.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var panel=Panel.new(); place(panel,confirm,.27,.28,.73,.72)
	var style=StyleBoxFlat.new(); style.bg_color=Color("0b0a22"); style.border_color=Color("ff4d6a")
	style.set_border_width_all(2); style.set_corner_radius_all(16); style.shadow_color=Color(Color("ff4d6a"),.25); style.shadow_size=20
	panel.add_theme_stylebox_override("panel",style)
	confirm_title=label(panel,"",.06,.06,.94,.24,30); confirm_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	confirm_body=label(panel,"",.08,.24,.92,.58,18,Color("cfc6ea")); confirm_body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	confirm_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	confirm_chart_button=button(panel,"DELETE CHART",.06,.64,.36,.8,func(): finish_delete(false),"danger")
	confirm_song_button=button(panel,"DELETE SONG",.38,.64,.68,.8,func(): finish_delete(true),"danger")
	button(panel,"CANCEL",.70,.64,.94,.8,func(): confirm.visible=false,"nav")
	confirm.visible=false

func ask_delete(entry: Dictionary) -> void:
	if DragScroll.was_dragged(scroll): return
	pending_delete=entry
	var built_in=str(entry.id)=="eclipse"
	var has_chart=game.library.has_chart(str(entry.id))
	confirm_title.text="Delete \u201c%s\u201d?" % str(entry.title)
	if built_in: confirm_body.text="Delete chart removes your saved notes and restores Eclipse's original chart. This can't be undone."
	else: confirm_body.text="Delete chart removes the saved notes and keeps the song. Delete song also removes its audio, cover and section marks. This can't be undone."
	confirm_chart_button.disabled=not has_chart
	confirm_song_button.visible=not built_in
	confirm.visible=true

func finish_delete(whole_song: bool) -> void:
	confirm.visible=false
	if pending_delete.is_empty(): return
	if whole_song: game.delete_song(str(pending_delete.id))
	else: game.delete_chart(str(pending_delete.id))
	pending_delete={}

func set_message(value: String) -> void:
	if message_label: message_label.text=value

func refresh() -> void:
	if grid==null or game==null: return
	for child in grid.get_children():
		grid.remove_child(child); child.queue_free()
	chart_cards.clear()
	count_label.text="%d imported song%s  •  Eclipse original" % [game.library.songs.size(),"" if game.library.songs.size()==1 else "s"]
	if matches(game.eclipse_song()): add_chart_card(0,game.eclipse_song())
	for i in game.library.songs.size():
		if matches(game.library.songs[i]): add_chart_card(i+1,game.library.songs[i])
	for key in filter_buttons: filter_buttons[key].set_selected(key==library_filter)
	add_import_card()
	layout_cards()
	if chart_cards.is_empty(): message_label.text="No matching charts. Try another filter, or import a song."
	else: message_label.text="%d chart%s shown · Tap a cover to edit · Changes stay in your draft until saved." % [chart_cards.size(),"" if chart_cards.size()==1 else "s"]

func matches(entry: Dictionary) -> bool:
	var charted=str(entry.id)=="eclipse" or game.library.has_chart(str(entry.id))
	if library_filter=="charted" and not charted: return false
	if library_filter=="new" and charted: return false
	return search.text.strip_edges().is_empty() or str(entry.title).to_lower().contains(search.text.strip_edges().to_lower())

func layout_cards() -> void:
	if grid==null: return
	grid.columns=4 if scroll.size.x>=1050 else (3 if scroll.size.x>=740 else 2)
	var width=maxf(130,(scroll.size.x-(grid.columns-1)*26-18)/grid.columns)
	for card in grid.get_children(): card.custom_minimum_size=Vector2(width,width*1.18)

func add_chart_card(index: int, entry: Dictionary) -> void:
	var card=Button.new(); grid.add_child(card)
	card.set_meta("song_id",str(entry.id))
	card.custom_minimum_size=Vector2(276,330)
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	card.focus_mode=Control.FOCUS_NONE
	var style=StyleBoxFlat.new(); style.bg_color=Color(.012,.018,.07,.93)
	style.border_color=Color("c061ff") if str(entry.id)==str(game.song.id) else Color("5b4d94")
	style.set_border_width_all(2 if str(entry.id)==str(game.song.id) else 1)
	style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("normal",style)
	var hover=style.duplicate(); hover.bg_color=Color(.1,.045,.21,.97); hover.border_color=Color("cc82ff")
	card.add_theme_stylebox_override("hover",hover)
	card.pressed.connect(func(): if not DragScroll.was_dragged(scroll): game.open_chart(index))
	card.mouse_filter=Control.MOUSE_FILTER_PASS
	UiMotion.bind_button(card)
	var cover=TextureRect.new(); place(cover,card,.025,.025,.975,.735)
	cover.texture=game.cover_texture_for_id(str(entry.id))
	cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ScreenStyle.round_cover(cover,14)
	if not game.has_custom_cover(str(entry.id)) and str(entry.id)!="eclipse":
		cover.modulate=game.cover_tint_for_id(str(entry.id))
	var name=label(card,str(entry.title),.06,.755,.94,.85,24)
	name.clip_text=true
	name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var subtitle=subtitle_for_entry(entry)
	label(card,subtitle,.06,.865,.94,.96,17,Color("a9b9e7"))
	var delete_chip=button(card,"DELETE",.62,.035,.955,.12,func(): ask_delete(entry),"danger")
	delete_chip.caption_size=13
	chart_cards.append(card)
	UiMotion.reveal(card,minf(.28,float(chart_cards.size()-1)*.045))

func subtitle_for_entry(entry: Dictionary) -> String:
	if str(entry.id)=="eclipse": return "ORIGINAL  •  EXPERT"
	var metadata: Dictionary=game.song_metadata.get(str(entry.id),{})
	if metadata.has("error"): return "AUDIO UNAVAILABLE"
	if metadata.is_empty(): return "LOADING SONG INFO…"
	return "%d NOTES  •  %d SEC" % [int(metadata.note_count),roundi(float(metadata.duration))] if metadata.has_chart else "NEW CHART  •  %d SEC" % roundi(float(metadata.duration))

func update_card_metadata(id: String) -> void:
	var entry=game.song_entry_for_id(id)
	if entry.is_empty(): return
	for card in chart_cards:
		if str(card.get_meta("song_id",""))!=id: continue
		var cover=card.get_child(0) as TextureRect
		cover.texture=game.cover_texture_for_id(id)
		cover.modulate=Color.WHITE if game.has_custom_cover(id) else game.cover_tint_for_id(id)
		(card.get_child(2) as Label).text=subtitle_for_entry(entry)
func update_selection() -> void:
	for card in chart_cards:
		var selected=str(card.get_meta("song_id",""))==str(game.song.id)
		var style=card.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		style.border_color=Color("6ce5ff") if selected else Color("5b4d94")
		style.set_border_width_all(2 if selected else 1)
		card.add_theme_stylebox_override("normal",style)

func add_import_card() -> void:
	var card=Button.new(); grid.add_child(card)
	card.custom_minimum_size=Vector2(276,330)
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	card.focus_mode=Control.FOCUS_NONE
	var style=StyleBoxFlat.new(); style.bg_color=Color(.035,.018,.10,.86)
	style.border_color=Color("7262ac"); style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("normal",style)
	var hover=style.duplicate(); hover.bg_color=Color(.12,.045,.22,.97)
	card.add_theme_stylebox_override("hover",hover)
	card.pressed.connect(func(): if not DragScroll.was_dragged(scroll): game.choose_audio())
	card.mouse_filter=Control.MOUSE_FILTER_PASS
	UiMotion.bind_button(card)
	var plus=label(card,"+",.04,.10,.96,.65,110,Color("c978ff"))
	plus.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var title=label(card,"IMPORT AUDIO",.04,.68,.96,.82,24)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var subtitle=label(card,"Start a new chart",.04,.82,.96,.94,17,Color("a9b9e7"))
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	UiMotion.reveal(card,minf(.28,float(chart_cards.size())*.045))
