extends Control

const UiMotion = preload("res://scripts/ui_motion.gd")
const NeonAction = preload("res://scripts/neon_action.gd")
const BACKGROUND = preload("res://assets/lobby/city_background.png")

var game: Control
var grid: GridContainer
var count_label: Label
var message_label: Label
var chart_cards: Array = []

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

func button(parent: Node, value: String, left: float, top: float, right: float, bottom: float, callback: Callable, strong: bool = false) -> Button:
	var result=NeonAction.new()
	result.text=value; result.caption_size=20 if strong else 18; result.compact=true
	result.accent_color=Color("bc55ff"); result.selected=strong
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
	button(self,"IMPORT AUDIO  +",.67,.045,.84,.12,func(): game.choose_audio(),true)
	button(self,"BACK TO LOBBY",.85,.045,.97,.12,func(): game.set_mode("menu"))
	var line=ColorRect.new(); place(line,self,.05,.182,.95,.185)
	line.color=Color("8150bd"); line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var scroll=ScrollContainer.new(); place(scroll,self,.055,.215,.95,.875)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	grid=GridContainer.new(); scroll.add_child(grid)
	grid.columns=4; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",26)
	grid.add_theme_constant_override("v_separation",22)
	message_label=label(self,"Select a cover to edit its chart. Import audio to start a new one.",.055,.89,.95,.955,21,Color("c1b5dc"))
	refresh()

func set_message(value: String) -> void:
	if message_label: message_label.text=value

func refresh() -> void:
	if grid==null or game==null: return
	for child in grid.get_children():
		grid.remove_child(child); child.queue_free()
	chart_cards.clear()
	count_label.text="%d imported song%s  •  Eclipse original" % [game.library.songs.size(),"" if game.library.songs.size()==1 else "s"]
	add_chart_card(0,{"id":"eclipse","title":"Eclipse"})
	for i in game.library.songs.size(): add_chart_card(i+1,game.library.songs[i])
	add_import_card()

func add_chart_card(index: int, entry: Dictionary) -> void:
	var card=Button.new(); grid.add_child(card)
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
	card.pressed.connect(game.open_chart.bind(index))
	UiMotion.bind_button(card)
	var cover=TextureRect.new(); place(cover,card,.025,.025,.975,.735)
	cover.texture=game.cover_texture_for_id(str(entry.id))
	cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if not game.has_custom_cover(str(entry.id)) and str(entry.id)!="eclipse":
		cover.modulate=game.cover_tint_for_id(str(entry.id))
	var name=label(card,str(entry.title),.06,.755,.94,.85,24)
	name.clip_text=true
	var subtitle=subtitle_for_entry(entry)
	label(card,subtitle,.06,.865,.94,.96,17,Color("a9b9e7"))
	chart_cards.append(card)
	UiMotion.reveal(card,minf(.28,float(chart_cards.size()-1)*.045))

func subtitle_for_entry(entry: Dictionary) -> String:
	if str(entry.id)=="eclipse": return "ORIGINAL  •  EXPERT"
	var metadata: Dictionary=game.song_metadata.get(str(entry.id),{})
	if metadata.has("error"): return "AUDIO UNAVAILABLE"
	if metadata.is_empty(): return "LOADING SONG INFO…"
	return "%d NOTES  •  %d SEC" % [int(metadata.note_count),roundi(float(metadata.duration))] if metadata.has_chart else "NEW CHART  •  %d SEC" % roundi(float(metadata.duration))

func update_card_metadata(id: String) -> void:
	for i in range(1,chart_cards.size()):
		if i>game.library.songs.size(): return
		if str(game.library.songs[i-1].id)!=id: continue
		var card: Button=chart_cards[i]
		var cover=card.get_child(0) as TextureRect
		cover.texture=game.cover_texture_for_id(id)
		cover.modulate=Color.WHITE if game.has_custom_cover(id) else game.cover_tint_for_id(id)
		(card.get_child(2) as Label).text=subtitle_for_entry(game.library.songs[i-1])
		return

func update_selection() -> void:
	for i in chart_cards.size():
		if i>game.library.songs.size(): return
		var card: Button=chart_cards[i]
		var id="eclipse" if i==0 else str(game.library.songs[i-1].id)
		var style=card.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		style.border_color=Color("c061ff") if id==str(game.song.id) else Color("5b4d94")
		style.set_border_width_all(2 if id==str(game.song.id) else 1)
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
	card.pressed.connect(func(): game.choose_audio())
	UiMotion.bind_button(card)
	var plus=label(card,"+",.04,.10,.96,.65,110,Color("c978ff"))
	plus.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var title=label(card,"IMPORT AUDIO",.04,.68,.96,.82,24)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var subtitle=label(card,"Start a new chart",.04,.82,.96,.94,17,Color("a9b9e7"))
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	UiMotion.reveal(card,minf(.28,float(chart_cards.size())*.045))
