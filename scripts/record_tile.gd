extends Button

const ROUNDED = preload("res://scripts/rounded_image.gdshader")
var cover_rect: TextureRect
var title_label: Label
var detail_label: Label
var badge_label: Label
var selected = false:
    set(value):
        if selected==value: return
        selected=value
        queue_redraw()
var compact = false

func _init(title_value: String = "", badge: String = "", art: Texture2D = null, tint: Color = Color.WHITE) -> void:
    for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
    focus_mode=Control.FOCUS_NONE
    mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    cover_rect=TextureRect.new(); add_child(cover_rect)
    cover_rect.texture=art; cover_rect.self_modulate=tint
    cover_rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    cover_rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
    var mat=ShaderMaterial.new(); mat.shader=ROUNDED; cover_rect.material=mat
    cover_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
    title_label=Label.new(); add_child(title_label); title_label.text=title_value
    title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    title_label.clip_text=true; title_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    title_label.add_theme_font_size_override("font_size",20)
    detail_label=Label.new(); add_child(detail_label)
    detail_label.mouse_filter=Control.MOUSE_FILTER_IGNORE; detail_label.visible=false
    badge_label=Label.new(); add_child(badge_label); badge_label.text=badge
    badge_label.add_theme_font_size_override("font_size",12)
    badge_label.add_theme_color_override("font_color",Color("e5dbff"))
    var badge_style=StyleBoxFlat.new(); badge_style.bg_color=Color(0.035,0.035,0.035,.88)
    badge_style.set_corner_radius_all(7); badge_style.content_margin_left=9; badge_style.content_margin_right=9
    badge_label.add_theme_stylebox_override("normal",badge_style)
    badge_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    resized.connect(layout)

func _ready() -> void: layout()
func set_selected(value: bool) -> void: selected=value
func layout() -> void:
    var side=minf(size.x-12,size.y-(36 if compact else 10))
    cover_rect.position=Vector2((size.x-side)*.5,5); cover_rect.size=Vector2(side,side)
    cover_rect.material.set_shader_parameter("rect_size",cover_rect.size)
    cover_rect.material.set_shader_parameter("radius",16.0)
    title_label.position=Vector2(0,side+11); title_label.size=Vector2(size.x,26)
    title_label.visible=compact
    badge_label.position=cover_rect.position+Vector2(10,10)
    badge_label.size=Vector2(0,24)
    queue_redraw()
func _draw() -> void:
    if cover_rect==null: return
    var rect=Rect2(cover_rect.position,cover_rect.size).grow(3)
    var border=StyleBoxFlat.new(); border.bg_color=Color(0.035,0.035,0.035,.8)
    border.border_color=Color("77dfff") if selected else Color(.7,.6,1,.28)
    border.set_border_width_all(2 if selected else 1); border.set_corner_radius_all(18)
    border.shadow_color=Color(.35,.15,1,.35 if selected else .12); border.shadow_size=22 if selected else 8
    draw_style_box(border,rect)
