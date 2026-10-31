extends "res://scripts/song_browser_button.gd"
var engagement=0.0
var touch=0.0
static func was_dragged(node: Node) -> bool:
    var parent=node.get_parent()
    while parent:
        if parent is ScrollContainer:
            return preload("res://scripts/drag_scroll.gd").was_dragged(parent)
        parent=parent.get_parent()
    return false
func _ready() -> void:
    super._ready()
    button_down.connect(func(): if not disabled: touch=1.0)
func _process(delta: float) -> void:
    if not is_visible_in_tree(): return
    super._process(delta)
    engagement=lerpf(engagement,1.0 if not disabled and (is_hovered() or has_focus()) else 0.0,1-exp(-delta*16))
    touch=move_toward(touch,0,delta*5)
func _draw() -> void:
    var Soft=preload("res://scripts/soft_button.gd")
    var role="primary" if primary else "surface"
    var pressing=1.0 if is_pressed() and not disabled else touch*.6
    Soft.draw_plate(self,size,role,engagement,pressing,amount,disabled)
    var font=Soft.BOLD; var pixels=caption_size
    var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
    var y=(size.y+font.get_ascent(pixels)-font.get_descent(pixels))*.5-1+2*pressing
    draw_string(font,Vector2((size.x-width)*.5,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,Soft.text_color(role,amount,disabled))
func outline(alpha: float) -> StyleBoxFlat:
    var box=StyleBoxFlat.new(); box.set_corner_radius_all(18); box.set_border_width_all(2)
    box.bg_color=Color(0,0,0,0); box.border_color=Color(accent,alpha*.5); return box
