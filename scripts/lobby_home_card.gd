extends Button
# Lobby home card: "play" is the cream card with the latest song covers fanned out;
# "create" is the graphite card with a small drawn highway. Both sink slightly when pressed.
const Soft = preload("res://scripts/soft_button.gd")
const Icons = preload("res://scripts/ui_icons.gd")
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
	var unit = size.y/640.0
	# Lifts a little on hover or focus, sinks when pressed.
	var sink = Vector2(0,6*unit*press-5*unit*hover*(1-press))
	var rect = Rect2(Vector2.ZERO+sink,size)
	var radius = roundi(36*unit)
	var shadow = StyleBoxFlat.new(); shadow.bg_color = Color(0,0,0,0); shadow.set_corner_radius_all(radius)
	shadow.shadow_color = Color(0,0,0,.5*(1-.4*press)); shadow.shadow_size = roundi(lerpf(34,16,press)*unit); shadow.shadow_offset = Vector2(0,lerpf(18,8,press)*unit)
	draw_style_box(shadow,rect)
	var play = kind=="play"
	var plate = StyleBoxFlat.new(); plate.set_corner_radius_all(radius); plate.set_border_width_all(1)
	plate.bg_color = (Soft.CREAM if play else Color("27252c")).lightened(.03*hover)
	plate.border_color = Soft.CREAM_EDGE if play else Color(1,1,1,.07)
	draw_style_box(plate,rect)
	var shine = StyleBoxFlat.new(); shine.bg_color = Color(1,1,1,.16 if play else .035)
	shine.corner_radius_top_left = radius; shine.corner_radius_top_right = radius
	draw_style_box(shine,Rect2(rect.position+Vector2(1,1),Vector2(rect.size.x-2,rect.size.y*.45)))
	var pad = 34*unit
	var art = Rect2(rect.position+Vector2(pad,pad),Vector2(rect.size.x-pad*2,rect.size.y*.5))
	if play: draw_covers(art,unit)
	else: draw_highway(art,unit)
	var ink = Soft.INK if play else Soft.TEXT
	var bold = Soft.BOLD; var regular = ThemeDB.fallback_font
	var title_size = roundi((64 if play else 54)*unit)
	var title_y = art.end.y+pad*.9+bold.get_ascent(title_size)
	draw_string(bold,Vector2(rect.position.x+pad,title_y),title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size,ink)
	draw_string(regular,Vector2(rect.position.x+pad,title_y+34*unit),subtitle,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-pad*2,roundi(22*unit),Color("6b6258") if play else Color("9b97a0"))
	# Round action mark in the corner.
	var mark_r = (48 if play else 42)*unit
	var mark = rect.end-Vector2(pad+mark_r,pad+mark_r)
	draw_circle(mark+Vector2(0,4*unit),mark_r,Color(0,0,0,.18))
	draw_circle(mark,mark_r,Soft.INK if play else Color("3a3840"))
	Icons.draw(self,"play" if play else "edit",mark+(Vector2(3*unit,0) if play else Vector2.ZERO),mark_r*.9,Soft.CREAM)

func draw_covers(area: Rect2,unit: float) -> void:
	var side = minf(area.size.y*.86,area.size.x*.6)
	var center = area.get_center()+Vector2(0,area.size.y*.02)
	var fan = [[Vector2(-side*.32,side*.04),-.14],[Vector2(side*.32,-side*.02),.11],[Vector2.ZERO,0.0]]
	var shown = covers.slice(0,3)
	var tints = [Color("ff9a6b"),Color("6c8cff")]
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
	draw_set_transform(Vector2.ZERO)

func draw_highway(area: Rect2,unit: float) -> void:
	var top = area.position.y+8*unit; var bottom = area.end.y
	var mid = area.get_center().x
	var a = Vector2(mid-area.size.x*.12,top); var b = Vector2(mid+area.size.x*.12,top)
	var c = Vector2(area.end.x-6*unit,bottom); var d = Vector2(area.position.x+6*unit,bottom)
	draw_colored_polygon(PackedVector2Array([a,b,c,d]),Color("17161b"))
	draw_line(a,d,Soft.CREAM,4*unit,true); draw_line(b,c,Soft.CREAM,4*unit,true)
	var band_y = lerpf(top,bottom,.82)
	var t = (band_y-top)/(bottom-top)
	var left = a.lerp(d,t); var right = b.lerp(c,t)
	var band = StyleBoxFlat.new(); band.bg_color = Color("ff7a59"); band.set_corner_radius_all(roundi(5*unit))
	draw_style_box(band,Rect2(left+Vector2(8*unit,0),Vector2(right.x-left.x-16*unit,16*unit)))
	for note in [[.32,-.05,.7],[.55,.12,1.0],[.68,-.22,.8]]:
		var y = lerpf(top,bottom,note[0]); var k = (y-top)/(bottom-top)
		var w = lerpf(area.size.x*.08,area.size.x*.22,k)
		var x = mid+note[1]*lerpf(area.size.x*.2,area.size.x*.8,k)
		var plate = StyleBoxFlat.new(); plate.bg_color = Color(Soft.CREAM,note[2]); plate.set_corner_radius_all(roundi(4*unit))
		draw_style_box(plate,Rect2(Vector2(x-w*.5,y),Vector2(w,maxf(6,11*unit*k+4*unit))))
