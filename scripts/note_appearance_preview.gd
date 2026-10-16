extends Control
var game: Control
func _ready() -> void:
    custom_minimum_size=Vector2(0,150)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
    draw_style_box(preload("res://scripts/game_theme.gd").plate(Color("0b142b"),Color("344768"),1),Rect2(Vector2.ZERO,size))
    var baseline=size.y*.72
    var note_positions=[size.x*.20,size.x*.50,size.x*.80]
    for x in note_positions: draw_line(Vector2(x,15),Vector2(x,size.y-28),Color(.3,.5,.8,.20),1,true)
    draw_line(Vector2(20,baseline),Vector2(size.x-20,baseline),Color("6d7dba"),1,true)
    var trail=14.0*game.hold_trail_width
    draw_rect(Rect2(Vector2(note_positions[1]-trail*.5,24),Vector2(trail,baseline-24)),Color(.65,.4,1,.45))
    for side in [-1,1]: draw_line(Vector2(note_positions[1]+side*trail*.5,24),Vector2(note_positions[1]+side*trail*.5,baseline),Color("c7a3ff"),1.5,true)
    for i in 3:
        var center=Vector2(note_positions[i],baseline)
        var tint=[Color("52dfff"),Color("b58aff"),Color("ff6ddd")][i]
        var k=game.note_size
        if game.note_shape=="circle":
            draw_set_transform(center,0,Vector2(1,.45))
            draw_circle(Vector2.ZERO,23*k,tint.darkened(.55))
            draw_arc(Vector2.ZERO,23*k,0,TAU,48,tint,3,true)
            draw_arc(Vector2.ZERO,20*k,0,TAU,48,Color.WHITE,1,true)
            draw_set_transform(Vector2.ZERO)
        else:
            draw_rect(Rect2(center-Vector2(36,8)*k,Vector2(72,16)*k),tint.darkened(.4))
            draw_rect(Rect2(center-Vector2(36,8)*k,Vector2(72,16)*k),tint,2,true)
        var font=ThemeDB.fallback_font; var caption=["TAP","HOLD","FLICK"][i]
        var width=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
        draw_string(font,Vector2(center.x-width*.5,size.y-8),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c6d6ef"))
