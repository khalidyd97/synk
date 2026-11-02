extends Button
# Lobby home cards are restrained concert-poster plates. Both actions intentionally share a
# calm charcoal finish; their small warm / plum accents distinguish the destinations.
const Soft = preload("res://scripts/soft_button.gd")
const Icons = preload("res://scripts/ui_icons.gd")
const ALBUM_SPRITE = preload("res://assets/lobby/ui/album_sleeve_sprite.png")
const PLAY_SPRITE = preload("res://assets/lobby/ui/play_card_sprite.png")
const CREATE_SPRITE = preload("res://assets/lobby/ui/create_card_sprite.png")
var kind = "play"
var title = "Play"
var subtitle = ""
var covers: Array = []   # up to three Texture2D, front cover first
var hover = 0.0
var press = 0.0

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button_down.connect(func(): press = 1.0; preload("res://scripts/ui_sound.gd").play(self,"play" if kind=="play" else "click"))

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	hover = lerpf(hover,1.0 if is_hovered() or has_focus() else 0.0,1-exp(-delta*14))
	press = move_toward(press,1.0 if is_pressed() else 0.0,delta*8)
	queue_redraw()

func _draw() -> void:
	var sprite: Texture2D = PLAY_SPRITE if kind=="play" else CREATE_SPRITE
	var source = Rect2(80,90,1720,670) if kind=="play" else Rect2(75,110,1730,630)
	var factor = minf(size.x/source.size.x,size.y/source.size.y)
	var fitted = source.size*factor
	var destination = Rect2((size-fitted)*.5,fitted)
	draw_texture_rect_region(sprite,destination,source,Color(1.1,1.07,1.02) if hover>.5 else Color.WHITE)
	return
	var unit = minf(size.y/290.0,size.x/740.0)
	# Lifts a little on hover or focus, sinks when pressed.
	var sink = Vector2(0,6*unit*press-5*unit*hover*(1-press))
	var rect = Rect2(Vector2.ZERO+sink,size)
	var radius = roundi(28*unit)
	var shadow = StyleBoxFlat.new(); shadow.bg_color = Color(0,0,0,0); shadow.set_corner_radius_all(radius)
	shadow.shadow_color = Color(0,0,0,.5*(1-.4*press)); shadow.shadow_size = roundi(lerpf(34,16,press)*unit); shadow.shadow_offset = Vector2(0,lerpf(18,8,press)*unit)
	draw_style_box(shadow,rect)
	var play = kind=="play"
	var accent = Color("d7a66f") if play else Color("ae718d")
	var plate = StyleBoxFlat.new(); plate.set_corner_radius_all(radius); plate.set_border_width_all(1)
	plate.bg_color = Color("17181d").lightened(.045*hover)
	plate.border_color = Color(accent,.72)
	draw_style_box(plate,rect)
	var shine = StyleBoxFlat.new(); shine.bg_color = Color(1,1,1,.045)
	shine.corner_radius_top_left = radius; shine.corner_radius_top_right = radius
	draw_style_box(shine,Rect2(rect.position+Vector2(1,1),Vector2(rect.size.x-2,rect.size.y*.45)))
	var pad = 30*unit
	var art_side = minf(rect.size.y-pad*2,rect.size.x*.27)
	var art = Rect2(rect.position+Vector2(pad,pad),Vector2(art_side,art_side))
	if play: draw_covers(art,unit)
	else: draw_mixer(art,unit,accent)
	var ink = Color("f4eadf")
	var bold = Soft.BOLD; var regular = ThemeDB.fallback_font
	var text_x = art.end.x+30*unit
	var title_size = roundi((54 if play else 45)*unit)
	var title_y = rect.position.y+rect.size.y*.43+bold.get_ascent(title_size)*.35
	draw_string(bold,Vector2(text_x,title_y),title,HORIZONTAL_ALIGNMENT_LEFT,rect.end.x-text_x-pad,title_size,ink)
	draw_line(Vector2(text_x,title_y+19*unit),Vector2(rect.end.x-pad,title_y+19*unit),Color(1,1,1,.13),1.0*unit)
	draw_string(regular,Vector2(text_x,title_y+52*unit),subtitle,HORIZONTAL_ALIGNMENT_LEFT,rect.end.x-text_x-pad,roundi(19*unit),Color("c7bdb2"))
	# A small forward affordance, without the former neon action bubble.
	draw_string(bold,Vector2(rect.end.x-pad-32*unit,rect.end.y-pad),"››",HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(30*unit),accent)

func draw_covers(area: Rect2,unit: float) -> void:
	var side = minf(area.size.y*.86,area.size.x*.6)
	var center = area.get_center()+Vector2(0,area.size.y*.02)
	var fan = [[Vector2(-side*.32,side*.04),-.14],[Vector2(side*.32,-side*.02),.11],[Vector2.ZERO,0.0]]
	var shown = covers.slice(0,3)
	var tints = [Color("706056"),Color("716975")]
	for i in 3:
		var offset: Vector2 = fan[i][0]; var angle: float = fan[i][1]
		var texture: Texture2D = null
		if i==2 and shown.size()>0: texture = shown[0]
		elif i<2 and shown.size()>i+1: texture = shown[i+1]
		draw_set_transform(center+offset,angle,Vector2.ONE)
		var r = Rect2(-Vector2.ONE*side*.5,Vector2.ONE*side)
		var drop = StyleBoxFlat.new(); drop.bg_color = Color(0,0,0,0); drop.set_corner_radius_all(roundi(22*unit))
		drop.shadow_color = Color(0,0,0,.28); drop.shadow_size = roundi(16*unit); drop.shadow_offset = Vector2(0,8*unit)
		draw_style_box(drop,r)
		var back = StyleBoxFlat.new(); back.set_corner_radius_all(roundi(22*unit))
		back.bg_color = tints[i] if i<2 else Color("2a2830")
		draw_style_box(back,r)
		if texture: draw_texture_rect(texture,r.grow(-2*unit),false)
		elif i==2: draw_texture_rect(ALBUM_SPRITE,r.grow(-2*unit),false)
	draw_set_transform(Vector2.ZERO)

func draw_mixer(area: Rect2,unit: float,accent: Color) -> void:
	var housing = StyleBoxFlat.new(); housing.bg_color = Color("24242a"); housing.set_corner_radius_all(roundi(18*unit)); housing.border_color=Color(1,1,1,.08); housing.set_border_width_all(1)
	draw_style_box(housing,area)
	for i in 3:
		var x = area.position.x+area.size.x*(.27+i*.23)
		var top = area.position.y+area.size.y*.22; var bottom=area.end.y-area.size.y*.2
		draw_line(Vector2(x,top),Vector2(x,bottom),Color("a99e95"),2.0*unit)
		var y = lerpf(top,bottom,[.28,.58,.42][i])
		draw_circle(Vector2(x,y),11*unit,accent if i!=1 else Color("6f9eb2"))
