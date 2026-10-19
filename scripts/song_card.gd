extends Button

# A song in the lobby list: a large rounded cover, the title, its details and a status chip.
# The selected song gets a bright violet plate with a glowing edge and a play marker.
# Pressing a card does not shrink or bounce it; it only plays a click.
const UiSound = preload("res://scripts/ui_sound.gd")
const ROUNDED_IMAGE = preload("res://scripts/rounded_image.gdshader")
const ACCENT = Color("8f4dff")
const ACCENT_END = Color("ff4fd8")
const CHIP_COLORS = {"EXPERT":Color("ffd447"),"CHARTED":Color("3ee6b0"),"NO CHART":Color("8f93b8")}

# Kept for the lobby and tests, which identify rows by their design-system role.
var variant = "track"
var selected = false:
	set(value): selected = value; refresh_style(); queue_redraw()
var hovered = false
var cover_rect: TextureRect
var cover_material: ShaderMaterial
var title_label: Label
var detail_label: Label
var chip_label: Label
var chip_style: StyleBoxFlat
var chip_text = ""

func _init(title: String, details: String, chip: String, art: Texture2D, tint: Color) -> void:
	chip_text = chip
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus","hover_pressed"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	cover_rect = TextureRect.new(); add_child(cover_rect)
	cover_rect.texture = art; cover_rect.self_modulate = tint
	cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_material = ShaderMaterial.new(); cover_material.shader = ROUNDED_IMAGE; cover_rect.material = cover_material
	var semibold = FontVariation.new(); semibold.base_font = ThemeDB.fallback_font; semibold.variation_embolden = .55
	title_label = make_label(title,27)
	title_label.add_theme_font_override("font",semibold)
	detail_label = make_label(details,17)
	chip_label = make_label(chip,13)
	chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_label.clip_text = false
	chip_style = StyleBoxFlat.new(); chip_style.set_corner_radius_all(10)
	chip_style.content_margin_left = 10; chip_style.content_margin_right = 10
	chip_label.add_theme_stylebox_override("normal",chip_style)
	chip_label.add_theme_font_override("font",semibold)
	button_down.connect(func(): UiSound.play(self,"click"))
	mouse_entered.connect(func(): hovered = true; queue_redraw())
	mouse_exited.connect(func(): hovered = false; queue_redraw())
	resized.connect(layout)

func set_selected(value: bool) -> void:
	selected = value

func make_label(text_value: String, font_size: int) -> Label:
	var result = Label.new(); add_child(result)
	result.text = text_value
	result.add_theme_font_size_override("font_size",font_size)
	result.clip_text = true; result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _ready() -> void:
	layout(); refresh_style()

func layout() -> void:
	var pad = size.y*.12
	var thumb = size.y-pad*2
	cover_rect.position = Vector2(pad,pad); cover_rect.size = Vector2(thumb,thumb)
	cover_material.set_shader_parameter("rect_size",cover_rect.size)
	cover_material.set_shader_parameter("radius",thumb*.16)
	var left = pad+thumb+size.y*.2
	var marker_space = size.y*.55
	var chip_width = maxf(size.y*.95,chip_label.get_minimum_size().x)
	chip_label.size = Vector2(chip_width,size.y*.24)
	chip_label.position = Vector2(size.x-marker_space-chip_width,size.y*.16)
	title_label.position = Vector2(left,size.y*.13)
	title_label.size = Vector2(maxf(0,chip_label.position.x-left-size.y*.12),size.y*.38)
	detail_label.position = Vector2(left,size.y*.53); detail_label.size = Vector2(maxf(0,size.x-marker_space-left),size.y*.3)

func refresh_style() -> void:
	if title_label == null: return
	title_label.add_theme_color_override("font_color",Color.WHITE if selected else Color("eae5ff"))
	detail_label.add_theme_color_override("font_color",Color(1,1,1,.86) if selected else Color(.8,.78,.94,.72))
	var chip_color: Color = CHIP_COLORS.get(chip_text,Color("8f93b8"))
	chip_style.bg_color = Color(chip_color,.22 if not selected else .3)
	chip_style.border_color = Color(chip_color,.7); chip_style.set_border_width_all(1)
	chip_label.add_theme_color_override("font_color",chip_color.lightened(.25))

func _draw() -> void:
	var plate = Rect2(Vector2.ZERO,size)
	var radius = int(size.y*.2)
	var style = StyleBoxFlat.new(); style.set_corner_radius_all(radius)
	if selected:
		style.bg_color = ACCENT.darkened(.3)
		style.border_color = ACCENT_END; style.set_border_width_all(2)
		style.shadow_color = Color(ACCENT_END,.38); style.shadow_size = 18
	else:
		style.bg_color = Color(0.088,0.088,0.088,.86) if not hovered else Color(0.116,0.116,0.116,.9)
		style.border_color = Color(1,1,1,.12); style.set_border_width_all(1)
	draw_style_box(style,plate)
	if selected:
		# A lighter band along the top edge reads as glass catching the light.
		var sheen = StyleBoxFlat.new(); sheen.set_corner_radius_all(radius)
		sheen.corner_radius_bottom_left = 0; sheen.corner_radius_bottom_right = 0
		sheen.bg_color = Color(1,1,1,.07)
		draw_style_box(sheen,Rect2(2,2,size.x-4,size.y*.42))
		# Play marker on the right edge.
		var center = Vector2(size.x-size.y*.3,size.y*.5); var r = size.y*.17
		draw_circle(center,r,Color(1,1,1,.16))
		draw_arc(center,r,0,TAU,40,Color(1,1,1,.75),2.0,true)
		var tri = PackedVector2Array([center+Vector2(-r*.32,-r*.45),center+Vector2(-r*.32,r*.45),center+Vector2(r*.5,0)])
		draw_colored_polygon(tri,Color.WHITE)
