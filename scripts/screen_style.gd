extends RefCounted
static func chassis(panel: Panel,accent: Color=Color("7acfff")) -> void:
    panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
    var art=load("res://scripts/game_panel.gd").new(); art.accent=accent
    panel.add_child(art); art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.move_child(art,0)
# Shared chrome for utility screens; never consumes pointer events.
static func glass(parent: Control, bounds: Rect2, accent: Color=Color("9274df"), index: int=0) -> Panel:
    var panel=Panel.new(); parent.add_child(panel)
    panel.anchor_left=bounds.position.x; panel.anchor_top=bounds.position.y
    panel.anchor_right=bounds.end.x; panel.anchor_bottom=bounds.end.y
    panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var style=StyleBoxFlat.new(); style.bg_color=Color(.025,.028,.075,.91)
    style.border_color=Color(accent,.25); style.set_border_width_all(1); style.set_corner_radius_all(18)
    style.shadow_color=Color(0,0,.015,.28); style.shadow_size=16
    panel.add_theme_stylebox_override("panel",style)
    chassis(panel,accent)
    parent.move_child(panel,index)
    return panel
static func rule(parent: Control, left: float, right: float, top: float, tint: Color=Color("6ccfff")) -> void:
    var line=ColorRect.new(); parent.add_child(line)
    line.anchor_left=left; line.anchor_right=right; line.anchor_top=top; line.anchor_bottom=top
    line.offset_bottom=2; line.color=Color(tint,.55); line.mouse_filter=Control.MOUSE_FILTER_IGNORE
static func round_cover(cover: TextureRect, radius: float=16.0) -> void:
    var mat=ShaderMaterial.new(); mat.shader=load("res://scripts/rounded_image.gdshader")
    cover.material=mat
    cover.resized.connect(func(): mat.set_shader_parameter("rect_size",cover.size); mat.set_shader_parameter("radius",radius))
    mat.set_shader_parameter("rect_size",cover.size); mat.set_shader_parameter("radius",radius)
