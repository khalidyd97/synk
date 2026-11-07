extends RefCounted
# Signal Arcade theme for menu screens (lobby, songs, settings, results, studio...).
# Gameplay keeps create(); menu roots get arcade() so their controls match the
# slanted plates drawn by soft_button.gd.
static var _arcade: Theme
static func arcade() -> Theme:
	if _arcade: return _arcade
	var A = preload("res://scripts/arcade_style.gd")
	var t = Theme.new()
	t.default_font = A.HEAD_SEMI; t.default_font_size = 18
	t.set_color("font_color", "Label", A.TEXT)
	for type in ["Button", "OptionButton", "LineEdit", "PopupMenu", "TabContainer", "TabBar", "SpinBox", "CheckBox", "CheckButton", "TextEdit", "ItemList"]:
		t.set_color("font_color", type, A.TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_selected_color", type, A.INK)
		t.set_color("font_pressed_color", type, A.INK)
		t.set_color("font_focus_color", type, Color.WHITE)
	for type in ["Button", "OptionButton", "SpinBox"]:
		t.set_stylebox("normal", type, A.slant_box(A.PANEL, Color(A.CYAN, .55)))
		t.set_stylebox("hover", type, A.slant_box(A.PANEL_HIGH, A.CYAN))
		t.set_stylebox("pressed", type, A.slant_box(A.CYAN, A.CYAN))
		t.set_stylebox("focus", type, A.slant_box(Color(0, 0, 0, 0), A.MAGENTA))
		t.set_stylebox("disabled", type, A.slant_box(Color(A.PANEL_LOW, .6), Color(1, 1, 1, .08), 1))
	for type in ["LineEdit", "TextEdit"]:
		var field = A.slant_box(Color(A.INK, .85), Color(A.CYAN, .5))
		field.border_width_left = 0; field.border_width_right = 0; field.border_width_top = 0; field.border_width_bottom = 2
		t.set_stylebox("normal", type, field)
		var focus = field.duplicate(); focus.border_color = A.MAGENTA; focus.bg_color = Color(A.INK, 0)
		t.set_stylebox("focus", type, focus)
		var ro = field.duplicate(); ro.border_color = Color(1, 1, 1, .12)
		t.set_stylebox("read_only", type, ro)
		t.set_color("caret_color", type, A.MAGENTA)
		t.set_color("selection_color", type, Color(A.MAGENTA, .35))
		t.set_color("font_placeholder_color", type, A.DIM)
		t.set_font("font", type, A.mono())
	var menu = StyleBoxFlat.new(); menu.bg_color = Color(A.NIGHT, .98); menu.border_color = Color(A.CYAN, .6); menu.set_border_width_all(2)
	menu.content_margin_left = 10; menu.content_margin_right = 10; menu.content_margin_top = 10; menu.content_margin_bottom = 10
	menu.shadow_color = Color(A.MAGENTA, .18); menu.shadow_size = 22
	t.set_stylebox("panel", "PopupMenu", menu)
	t.set_stylebox("hover", "PopupMenu", A.slant_box(Color(A.CYAN, .2), A.CYAN, 1, 6))
	t.set_constant("v_separation", "PopupMenu", 14); t.set_constant("h_separation", "PopupMenu", 12)
	t.set_font_size("font_size", "PopupMenu", 20)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", Color(1, 1, 1, .35))
	t.set_color("font_separator_color", "PopupMenu", A.MAGENTA)
	var tab_panel = StyleBoxFlat.new(); tab_panel.bg_color = Color(A.PANEL_LOW, .7); tab_panel.border_color = Color(A.CYAN, .25); tab_panel.border_width_top = 2
	t.set_stylebox("panel", "TabContainer", tab_panel)
	for type in ["TabBar", "TabContainer"]:
		t.set_stylebox("tab_selected", type, A.slant_box(A.CYAN, A.CYAN, 2, 10))
		t.set_stylebox("tab_unselected", type, A.slant_box(A.PANEL_HIGH, Color(0, 0, 0, 0), 0, 10))
		t.set_stylebox("tab_hovered", type, A.slant_box(A.PANEL, Color(A.CYAN, .6), 2, 10))
		t.set_stylebox("tab_focus", type, A.slant_box(Color(0, 0, 0, 0), A.MAGENTA, 2, 10))
	for type in ["HSlider", "VSlider"]:
		var rail = StyleBoxFlat.new(); rail.bg_color = A.LINE; rail.content_margin_top = 3; rail.content_margin_bottom = 3
		t.set_stylebox("slider", type, rail)
		var fill = StyleBoxFlat.new(); fill.bg_color = A.CYAN
		t.set_stylebox("grabber_area", type, fill)
		var fill_hi = StyleBoxFlat.new(); fill_hi.bg_color = A.MAGENTA
		t.set_stylebox("grabber_area_highlight", type, fill_hi)
		var image = Image.create(22, 30, false, Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
		for y in range(2, 28):
			var lean = int((28 - y) * .25)
			for x in range(4 + lean, 14 + lean): image.set_pixel(x, y, Color.WHITE if y in [2, 27] or x in [4 + lean, 13 + lean] else A.MAGENTA)
		var texture = ImageTexture.create_from_image(image)
		t.set_icon("grabber", type, texture); t.set_icon("grabber_highlight", type, texture)
	for type in ["VScrollBar", "HScrollBar"]:
		var track = StyleBoxFlat.new(); track.bg_color = Color(A.LINE, .35); track.content_margin_left = 3; track.content_margin_right = 3
		t.set_stylebox("scroll", type, track)
		var grab = StyleBoxFlat.new(); grab.bg_color = Color(A.CYAN, .6)
		t.set_stylebox("grabber", type, grab)
		var grab_hi = StyleBoxFlat.new(); grab_hi.bg_color = A.CYAN
		t.set_stylebox("grabber_highlight", type, grab_hi); t.set_stylebox("grabber_pressed", type, grab_hi)
	var panel = StyleBoxFlat.new(); panel.bg_color = Color(A.NIGHT, .9); panel.border_color = Color(A.CYAN, .22); panel.set_border_width_all(1)
	t.set_stylebox("panel", "Panel", panel); t.set_stylebox("panel", "PanelContainer", panel)
	var tip = StyleBoxFlat.new(); tip.bg_color = A.INK; tip.border_color = A.CYAN; tip.set_border_width_all(1)
	tip.content_margin_left = 10; tip.content_margin_right = 10; tip.content_margin_top = 6; tip.content_margin_bottom = 6
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_font("font", "TooltipLabel", A.mono()); t.set_color("font_color", "TooltipLabel", A.TEXT)
	_arcade = t
	return t
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
	t.set_color("font_separator_color","PopupMenu",Color("ff7a59"))
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
