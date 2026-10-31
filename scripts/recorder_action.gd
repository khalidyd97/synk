extends "res://scripts/neon_action.gd"

# Recorder-only plates: clear states and stable, generous touch targets.
var engagement=0.0
var touch=0.0
var selection=0.0
func _ready() -> void:
    super._ready()
    backdrop.visible=false
    caption.add_theme_constant_override("outline_size",0)
    focus_mode=Control.FOCUS_ALL
func _process(delta: float) -> void:
    super._process(delta)
    if not is_visible_in_tree(): return
    engagement=lerpf(engagement,1.0 if not disabled and (is_hovered() or has_focus()) else 0.0,1-exp(-delta*14))
    touch=lerpf(touch,1.0 if is_pressed() and not disabled else 0.0,1-exp(-delta*24))
    selection=lerpf(selection,1.0 if selected else 0.0,1-exp(-delta*16))
    queue_redraw()
func soft_role() -> String:
    return "danger" if text=="DELETE" else Soft.role_for(variant)
func _draw() -> void:
    Soft.draw_plate(self,size,soft_role(),engagement,touch,selection,disabled,12.0)
    if has_focus():
        var focus=StyleBoxFlat.new(); focus.bg_color=Color.TRANSPARENT; focus.set_corner_radius_all(14)
        focus.set_border_width_all(2); focus.border_color=Color(Soft.CREAM,.55)
        draw_style_box(focus,Rect2(Vector2.ONE*3,size-Vector2.ONE*6))
