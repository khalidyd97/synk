extends Control
var lobby: Control
var elapsed=0.0
func _ready() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
    if not is_visible_in_tree(): return
    if lobby.preview_player.playing: elapsed+=delta
    queue_redraw()
func _draw() -> void:
    var active=lobby.preview_player.playing
    for i in 30:
        var wave=.35+.27*sin(i*.82+elapsed*3)+.17*sin(i*1.7-elapsed*4.2)
        var h=maxf(5,wave*size.y) if active else 4.0
        var tint=Color("35d9ee").lerp(Color("9266f8"),smoothstep(.35,.7,i/29.0))
        if not active: tint.a=.3
        var style=StyleBoxFlat.new(); style.bg_color=tint; style.set_corner_radius_all(2)
        if active: style.shadow_color=Color(tint,.17); style.shadow_size=4
        draw_style_box(style,Rect2(i*size.x/30.0,size.y-h,maxf(3,size.x/30.0-3),h))
