extends Control
var game: Control
func _ready() -> void:
    custom_minimum_size=Vector2(0,150)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
    if is_visible_in_tree(): queue_redraw()
func _draw() -> void:
    var plate=StyleBoxFlat.new(); plate.bg_color=Color("101124"); plate.border_color=Color("292c43")
    plate.set_corner_radius_all(18); plate.set_border_width_all(1)
    draw_style_box(plate,Rect2(Vector2.ZERO,size))
    var baseline=size.y*.72
    var note_positions=[size.x*.125,size.x*.375,size.x*.625,size.x*.875]
    for x in note_positions: draw_line(Vector2(x,15),Vector2(x,size.y-28),Color(.3,.5,.8,.20),1,true)
    draw_line(Vector2(20,baseline),Vector2(size.x-20,baseline),Color("6d7dba"),1,true)
    var trail=14.0*game.hold_trail_width
    draw_rect(Rect2(Vector2(note_positions[1]-trail*.5,24),Vector2(trail,baseline-24)),Color(.65,.4,1,.45))
    for side in ([] if game.trail_style=="solid" else [-1,1]): draw_line(Vector2(note_positions[1]+side*trail*.5,24),Vector2(note_positions[1]+side*trail*.5,baseline),Color("c7a3ff"),1.5,true)
    var slide_points=PackedVector2Array([Vector2(note_positions[2]+30,24),Vector2(note_positions[2]-18,62),Vector2(note_positions[2],baseline)])
    draw_polyline(slide_points,Color(.65,.4,1,.8 if game.trail_style=="solid" else .45),trail,true)
    if game.trail_style=="solid":
        for point in [Vector2(note_positions[1],24),slide_points[0],slide_points[1]]:
            draw_circle(point,trail*.85,Color("b58aff")); draw_circle(point,trail*.45,Color("f4eaff"))
    for i in 4:
        var center=Vector2(note_positions[i],baseline)
        var tint=[Color("52dfff"),Color("b58aff"),Color("b58aff"),Color("ff6ddd")][i]
        var k=game.note_size
        if game.note_shape=="circle":
            var dimensions=Vector2(64,64*797.0/1388.0)*k
            draw_texture_rect(preload("res://assets/neon/Circle_Note_Reference.png"),Rect2(center-dimensions*.5,dimensions),false)
        else:
            draw_rect(Rect2(center-Vector2(36,8)*k,Vector2(72,16)*k),tint.darkened(.4))
            draw_rect(Rect2(center-Vector2(36,8)*k,Vector2(72,16)*k),tint,false,2,true)
        var font=ThemeDB.fallback_font; var caption=["TAP","HOLD","SLIDE","FLICK"][i]
        var width=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
        draw_string(font,Vector2(center.x-width*.5,size.y-8),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c6d6ef"))
