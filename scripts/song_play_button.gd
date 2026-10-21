extends "res://scripts/song_browser_button.gd"
# The lobby Play note's polished layers, fitted to the song action's rectangle.
const BOLD = preload("res://assets/fonts/FiraSans-Bold.ttf")
var time = 0.0

func _ready() -> void:
    primary=false
    super._ready()
    primary=true

func _process(delta: float) -> void:
    super._process(delta)
    time+=delta

func plate(rect: Rect2, edge: Color, light: Color, radius: float) -> void:
    for i in 17:
        var t=float(i)/16.0
        var box=StyleBoxFlat.new()
        box.bg_color=edge.lerp(light,t)
        box.set_corner_radius_all(roundi(maxf(2,radius-t*3)))
        var inset=Vector2(2,3)*t
        draw_style_box(box,Rect2(rect.position+inset,rect.size-inset*2))

func _draw() -> void:
    var beat=pow(.5+.5*sin(time*3.4),3)
    var bounds=Rect2(Vector2(0,3),size-Vector2(0,6))
    var lift=Vector2(0,-2*(1-press_amount))
    var face=Rect2(bounds.position+lift,bounds.size-Vector2(0,3))
    var glow=StyleBoxFlat.new()
    glow.bg_color=Color(0,0,0,0); glow.set_corner_radius_all(16)
    glow.shadow_color=Color(1,.08,.25,.18+beat*.12+hover_amount*.1)
    glow.shadow_size=12+roundi(beat*5)
    draw_style_box(glow,bounds)
    plate(bounds,Color("480a20"),Color("ac1636"),16)
    plate(face,Color("a80d30"),Color("ff5868").lightened(hover_amount*.08+beat*.07),16)
    plate(face.grow(-5),Color("b65c73"),Color("fff5f2"),12)
    plate(face.grow(-9),Color("790c2a"),Color("f43b58"),9)
    plate(face.grow(-15),Color("d26b87"),Color("ffe9e7"),6)
    var ink=Color("b0102c") if not disabled else Color("895c67")
    var caption=text.replace("▶", "").strip_edges()
    var pixels=caption_size
    while BOLD.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>size.x-110 and pixels>16: pixels-=1
    var width=BOLD.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
    var left=(size.x-width-60)*.5
    var center=Vector2(left+20,size.y*.5)+lift
    for i in 9:
        var h=(5+12*abs(sin(time*5+i*.9)))*(1-absf(float(i)/8-.5))
        var x=center.x-24+i*2.5
        draw_line(Vector2(x,center.y-h*.5),Vector2(x,center.y+h*.5),Color(ink,.7),2,true)
    var arrow=center+Vector2(9+sin(time*3)*1.5,0)
    draw_colored_polygon(PackedVector2Array([arrow+Vector2(-5,-10),arrow+Vector2(10,0),arrow+Vector2(-5,10)]),ink)
    var baseline=Vector2(left+60,(size.y+BOLD.get_ascent(pixels)-BOLD.get_descent(pixels))*.5)+lift
    draw_set_transform_matrix(Transform2D(Vector2(1,0),Vector2(-.16,1),baseline))
    draw_string(BOLD,Vector2.ZERO,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,ink)
    draw_set_transform(Vector2.ZERO)
