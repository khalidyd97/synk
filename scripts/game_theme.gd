extends RefCounted
static func plate(fill: Color,edge: Color,bottom: int=2) -> StyleBoxFlat:
	var s=StyleBoxFlat.new(); s.bg_color=fill; s.border_color=edge
	s.border_width_bottom=bottom; s.border_width_left=2
	s.corner_radius_top_left=8; s.corner_radius_bottom_right=8
	s.content_margin_left=16; s.content_margin_right=16; s.content_margin_top=10; s.content_margin_bottom=10
	return s
static func glass(fill: Color,edge: Color,radius: int=14) -> StyleBoxFlat:
	var s=StyleBoxFlat.new(); s.bg_color=fill; s.border_color=edge; s.set_border_width_all(1); s.set_corner_radius_all(radius)
	s.content_margin_left=16; s.content_margin_right=16; s.content_margin_top=10; s.content_margin_bottom=10
	return s
static func create() -> Theme:
	var t=Theme.new()
	var cyan=Color("65dcff"); var muted=Color("536080")
	var bold=FontVariation.new(); bold.base_font=preload("res://assets/fonts/FiraSans-Bold.ttf")
	t.default_font=bold; t.default_font_size=18
	for type in ["Button","OptionButton","LineEdit","PopupMenu","TabContainer","TabBar","SpinBox"]:
		t.set_color("font_color",type,Color("edf5ff"))
		t.set_color("font_hover_color",type,Color.WHITE)
		t.set_color("font_selected_color",type,Color.WHITE)
	# Rounded black glass, matching the cards used across the app; cyan marks focus.
	for type in ["Button","OptionButton","LineEdit","SpinBox"]:
		t.set_stylebox("normal",type,glass(Color(.06,.06,.06,.82),Color(1,1,1,.12)))
		t.set_stylebox("hover",type,glass(Color(.1,.1,.1,.88),Color(cyan,.7)))
		t.set_stylebox("pressed",type,glass(Color(.13,.13,.13,.92),cyan))
		t.set_stylebox("focus",type,glass(Color(0,0,0,0),cyan))
		t.set_stylebox("disabled",type,glass(Color(.05,.05,.05,.6),Color(1,1,1,.06)))
	t.set_stylebox("read_only","LineEdit",glass(Color(.05,.05,.05,.6),Color(1,1,1,.08)))
	var menu=glass(Color(.05,.05,.05,.97),Color(1,1,1,.14),16)
	menu.content_margin_left=8; menu.content_margin_right=8; menu.content_margin_top=8; menu.content_margin_bottom=8
	menu.shadow_color=Color(0,0,0,.5); menu.shadow_size=18
	t.set_stylebox("panel","PopupMenu",menu)
	t.set_stylebox("hover","PopupMenu",glass(Color(cyan,.16),Color(cyan,.55),10))
	t.set_constant("v_separation","PopupMenu",14); t.set_constant("h_separation","PopupMenu",12)
	t.set_font_size("font_size","PopupMenu",20)
	t.set_color("font_disabled_color","PopupMenu",Color(1,1,1,.35))
	t.set_color("font_separator_color","PopupMenu",Color("50daec"))
	t.set_stylebox("panel","TabContainer",glass(Color(.04,.04,.04,.6),Color(1,1,1,.08),16))
	for type in ["TabBar","TabContainer"]:
		t.set_stylebox("tab_selected",type,glass(Color(cyan,.14),Color(cyan,.75),12))
		t.set_stylebox("tab_unselected",type,glass(Color(.06,.06,.06,.8),Color(1,1,1,.1),12))
		t.set_stylebox("tab_hovered",type,glass(Color(.1,.1,.1,.88),Color(cyan,.5),12))
		t.set_stylebox("tab_focus",type,glass(Color(0,0,0,0),Color(cyan,.6),12))
	for type in ["HSlider","VSlider"]:
		var rail=plate(Color("222222"),Color("344b6b"),1)
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
