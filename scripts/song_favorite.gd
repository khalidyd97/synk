extends Button
var active=false
var amount=0.0
var press=0.0
var engagement=0.0
func _ready() -> void:
    text=""; mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    button_down.connect(func(): if not disabled: press=1.0)
func _process(delta: float) -> void:
    if not is_visible_in_tree(): return
    amount=lerpf(amount,1.0 if active else 0.0,1-exp(-delta*16)); queue_redraw()
    press=move_toward(press,0,delta*4)
    engagement=lerpf(engagement,1.0 if not disabled and (is_hovered() or has_focus()) else 0.0,1-exp(-delta*14))
func _draw() -> void:
    var points=PackedVector2Array()
    var center=size*.5
    var pop=1+sin(press*PI)*.18+engagement*.06
    draw_set_transform(center*(1-pop),0,Vector2.ONE*pop)
    for i in 48:
        var t=TAU*i/48.0
        points.append(center+Vector2(16*pow(sin(t),3),-(13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t)))*minf(size.x,size.y)/60.0)
    if amount>.001: draw_colored_polygon(points,Color("f53cce",amount))
    points.append(points[0]); draw_polyline(points,Color("6b637e").lerp(Color("f53cce"),amount) if not is_hovered() else Color("e991e3"),1.4,true)
    draw_set_transform(Vector2.ZERO)
