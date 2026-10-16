extends RefCounted
static func plate(fill: Color,edge: Color,bottom: int=2) -> StyleBoxFlat:
	var s=StyleBoxFlat.new(); s.bg_color=fill; s.border_color=edge
	s.border_width_bottom=bottom; s.border_width_left=2
	s.corner_radius_top_left=8; s.corner_radius_bottom_right=8
	s.content_margin_left=16; s.content_margin_right=16; s.content_margin_top=10; s.content_margin_bottom=10
	return s
static func create() -> Theme:
	var t=Theme.new()
	var cyan=Color("65dcff"); var muted=Color("536080")
	var bold=FontVariation.new(); bold.base_font=ThemeDB.fallback_font; bold.variation_embolden=.6
	t.default_font=bold; t.default_font_size=18
	for type in ["Button","OptionButton","LineEdit","PopupMenu","TabContainer","TabBar","SpinBox"]:
		t.set_color("font_color",type,Color("edf5ff"))
		t.set_color("font_hover_color",type,Color.WHITE)
		t.set_color("font_selected_color",type,Color.WHITE)
	for type in ["Button","OptionButton","LineEdit"]:
		t.set_stylebox("normal",type,plate(Color("0b142c"),muted))
		t.set_stylebox("hover",type,plate(Color("172a48"),cyan))
		t.set_stylebox("pressed",type,plate(Color("283265"),Color("d899ff"),4))
		t.set_stylebox("focus",type,plate(Color(0,0,0,0),cyan))
		t.set_stylebox("disabled",type,plate(Color("0a1020"),Color("303849")))
	t.set_stylebox("panel","PopupMenu",plate(Color("0b142c"),cyan))
	t.set_stylebox("hover","PopupMenu",plate(Color("273862"),cyan))
	t.set_stylebox("panel","TabContainer",plate(Color("090f25"),Color("38466b")))
	for type in ["TabBar","TabContainer"]:
		t.set_stylebox("tab_selected",type,plate(Color("26335b"),cyan,4))
		t.set_stylebox("tab_unselected",type,plate(Color("0c142b"),Color("334465")))
		t.set_stylebox("tab_hovered",type,plate(Color("1a2949"),Color("b395ff")))
	for type in ["HSlider","VSlider"]:
		var rail=plate(Color("17233d"),Color("344b6b"),1)
		rail.content_margin_top=3; rail.content_margin_bottom=3
		t.set_stylebox("slider",type,rail)
		t.set_stylebox("grabber_area",type,plate(Color("347aaa"),cyan,1))
		t.set_stylebox("grabber_area_highlight",type,plate(Color("569dc9"),Color.WHITE,1))
		var image=Image.create(20,28,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
		for x in range(4,16):
			for y in range(3,25): image.set_pixel(x,y,Color.WHITE if x in [4,15] or y in [3,24] else cyan)
		var texture=ImageTexture.create_from_image(image)
		t.set_icon("grabber",type,texture); t.set_icon("grabber_highlight",type,texture)
	return t
