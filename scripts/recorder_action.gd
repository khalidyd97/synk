extends "res://scripts/neon_action.gd"

# Recorder-only plates: clear states and stable, generous touch targets.
var engagement=0.0
var touch=0.0
var selection=0.0
func _ready() -> void:
    super._ready()
    backdrop.visible=false
    caption.add_theme_constant_override("outline_size",0)
    caption.add_theme_color_override("font_color",Color("f1f3ff"))
    focus_mode=Control.FOCUS_ALL
func _process(delta: float) -> void:
    super._process(delta)
    if not is_visible_in_tree(): return
    engagement=lerpf(engagement,1.0 if not disabled and (is_hovered() or has_focus()) else 0.0,1-exp(-delta*14))
    touch=lerpf(touch,1.0 if is_pressed() and not disabled else 0.0,1-exp(-delta*24))
    selection=lerpf(selection,1.0 if selected else 0.0,1-exp(-delta*16))
    caption.modulate.a=.4 if disabled else 1.0
    queue_redraw()
func _draw() -> void:
    var strong=variant in ["record","primary"]
    var destructive=variant=="danger" or text=="DELETE"
    var tint=Color("ff6489") if variant=="record" else (Color("4cdeed") if variant=="primary" else Color("a99bfa"))
    if destructive: tint=Color("ff6489")
    var plate=StyleBoxFlat.new(); plate.set_corner_radius_all(12); plate.set_border_width_all(1)
    plate.bg_color=Color("111429").lerp(tint.darkened(.75),selection*.8+engagement*.25+touch*.2)
    if strong: plate.bg_color=tint.darkened(.65).lightened(engagement*.08+touch*.04)
    plate.border_color=Color("36394e").lerp(tint,maxf(selection,maxf(engagement,.7 if strong else 0.0)))
    if destructive:
        plate.bg_color=Color("241424").lightened(engagement*.06)
        plate.border_color=Color(tint,.65)
    if disabled: plate.bg_color=Color("0d1020"); plate.border_color=Color("25283b")
    draw_style_box(plate,Rect2(Vector2.ONE,size-Vector2.ONE*2))
    if selection>.01:
        var marker=StyleBoxFlat.new(); marker.set_corner_radius_all(2); marker.bg_color=Color(tint,selection)
        draw_style_box(marker,Rect2(12,size.y-6,maxf(0,size.x-24),3))
    if has_focus():
        var focus=StyleBoxFlat.new(); focus.bg_color=Color.TRANSPARENT; focus.set_corner_radius_all(14)
        focus.set_border_width_all(2); focus.border_color=Color(tint,.65)
        draw_style_box(focus,Rect2(Vector2.ONE*3,size-Vector2.ONE*6))
