extends RefCounted
# Signal Arcade theme for menu screens (lobby, songs, settings, results, studio...).
# Gameplay keeps create(); menu roots get arcade() so their controls match the
# slanted plates drawn by soft_button.gd.
static var _arcade: Theme
static func arcade() -> Theme:
	if _arcade: return _arcade
	# Album Takeover: soft dark glass, rounded controls, paper-white highlight.
	var A = preload("res://scripts/arcade_style.gd")
	var t = Theme.new()
	t.default_font = A.semi(); t.default_font_size = 18
	t.set_color("font_color", "Label", A.TEXT)
	for type in ["Button", "OptionButton", "LineEdit", "PopupMenu", "TabContainer", "TabBar", "SpinBox", "CheckBox", "CheckButton", "TextEdit", "ItemList"]:
		t.set_color("font_color", type, A.TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_selected_color", type, A.INK)
		t.set_color("font_pressed_color", type, A.INK)
		t.set_color("font_focus_color", type, Color.WHITE)
	for type in ["Button", "OptionButton", "SpinBox"]:
		t.set_stylebox("normal", type, A.slant_box(Color(1, 1, 1, .08), Color(0, 0, 0, 0), 0))
		t.set_stylebox("hover", type, A.slant_box(Color(1, 1, 1, .14), Color(0, 0, 0, 0), 0))
		t.set_stylebox("pressed", type, A.slant_box(A.CYAN, Color(0, 0, 0, 0), 0))
		t.set_stylebox("focus", type, A.slant_box(Color(0, 0, 0, 0), Color(A.CYAN, .7), 2))
		t.set_stylebox("disabled", type, A.slant_box(Color(1, 1, 1, .04), Color(0, 0, 0, 0), 0))
	for type in ["LineEdit", "TextEdit"]:
		var field = A.slant_box(Color(1, 1, 1, .07), Color(0, 0, 0, 0), 0)
		t.set_stylebox("normal", type, field)
		var focus = A.slant_box(Color(1, 1, 1, .11), Color(A.CYAN, .55), 2)
		t.set_stylebox("focus", type, focus)
		t.set_stylebox("read_only", type, A.slant_box(Color(1, 1, 1, .03), Color(0, 0, 0, 0), 0))
		t.set_color("caret_color", type, A.MAGENTA)
		t.set_color("selection_color", type, Color(A.MAGENTA, .35))
		t.set_color("font_placeholder_color", type, A.DIM)
		t.set_font("font", type, A.mono())
	var menu = A.slant_box(Color("1a1b1f"), Color(1, 1, 1, .08), 1, 10)
	menu.set_corner_radius_all(16); menu.content_margin_top = 10; menu.content_margin_bottom = 10
	menu.shadow_color = Color(0, 0, 0, .55); menu.shadow_size = 24; menu.shadow_offset = Vector2(0, 8)
	t.set_stylebox("panel", "PopupMenu", menu)
	t.set_stylebox("hover", "PopupMenu", A.slant_box(Color(1, 1, 1, .10), Color(0, 0, 0, 0), 0, 6))
	t.set_constant("v_separation", "PopupMenu", 14); t.set_constant("h_separation", "PopupMenu", 12)
	t.set_font_size("font_size", "PopupMenu", 20)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", Color(1, 1, 1, .35))
	t.set_color("font_separator_color", "PopupMenu", A.MUTED)
	var tab_panel = StyleBoxFlat.new(); tab_panel.bg_color = Color(1, 1, 1, .03); tab_panel.set_corner_radius_all(18)
	t.set_stylebox("panel", "TabContainer", tab_panel)
	for type in ["TabBar", "TabContainer"]:
		t.set_stylebox("tab_selected", type, A.slant_box(A.CYAN, Color(0, 0, 0, 0), 0, 10))
		t.set_stylebox("tab_unselected", type, A.slant_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 10))
		t.set_stylebox("tab_hovered", type, A.slant_box(Color(1, 1, 1, .08), Color(0, 0, 0, 0), 0, 10))
		t.set_stylebox("tab_focus", type, A.slant_box(Color(0, 0, 0, 0), Color(A.CYAN, .6), 2, 10))
	for type in ["HSlider", "VSlider"]:
		var rail = StyleBoxFlat.new(); rail.bg_color = Color(1, 1, 1, .14); rail.set_corner_radius_all(3)
		rail.content_margin_top = 3; rail.content_margin_bottom = 3
		t.set_stylebox("slider", type, rail)
		var fill = StyleBoxFlat.new(); fill.bg_color = A.CYAN; fill.set_corner_radius_all(3)
		t.set_stylebox("grabber_area", type, fill)
		t.set_stylebox("grabber_area_highlight", type, fill)
		var image = Image.create(28, 28, false, Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
		for y in 28:
			for x in 28:
				var d = Vector2(x - 13.5, y - 13.5).length()
				if d < 12.5: image.set_pixel(x, y, Color(A.CYAN, clampf(12.5 - d, 0, 1)))
		var texture = ImageTexture.create_from_image(image)
		t.set_icon("grabber", type, texture); t.set_icon("grabber_highlight", type, texture)
	for type in ["VScrollBar", "HScrollBar"]:
		var track = StyleBoxFlat.new(); track.bg_color = Color(0, 0, 0, 0); track.content_margin_left = 3; track.content_margin_right = 3
		t.set_stylebox("scroll", type, track)
		var grab = StyleBoxFlat.new(); grab.bg_color = Color(1, 1, 1, .22); grab.set_corner_radius_all(4)
		t.set_stylebox("grabber", type, grab)
		var grab_hi = StyleBoxFlat.new(); grab_hi.bg_color = Color(1, 1, 1, .45); grab_hi.set_corner_radius_all(4)
		t.set_stylebox("grabber_highlight", type, grab_hi); t.set_stylebox("grabber_pressed", type, grab_hi)
	var panel = StyleBoxFlat.new(); panel.bg_color = Color(1, 1, 1, .045); panel.set_corner_radius_all(20)
	t.set_stylebox("panel", "Panel", panel); t.set_stylebox("panel", "PanelContainer", panel)
	var tip = StyleBoxFlat.new(); tip.bg_color = Color("1a1b1f"); tip.set_corner_radius_all(10)
	tip.content_margin_left = 12; tip.content_margin_right = 12; tip.content_margin_top = 7; tip.content_margin_bottom = 7
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
