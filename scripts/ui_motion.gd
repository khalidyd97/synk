extends RefCounted

static func bind_button(target: BaseButton) -> void:
	if target.has_meta("ui_motion_bound"): return
	target.set_meta("ui_motion_bound", true)
	target.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	target.resized.connect(func(): target.pivot_offset=target.size*.5)
	target.pivot_offset=target.size*.5
	target.mouse_entered.connect(func(): _scale(target,1.035,.16))
	target.mouse_exited.connect(func(): _scale(target,1.0,.16))
	target.button_down.connect(func(): _scale(target,.94,.085); _flash(target))
	target.button_up.connect(func(): _scale(target,1.035 if target.get_global_rect().has_point(target.get_global_mouse_position()) else 1.0,.20))

static func style_button(target: Button, accent: Color = Color("a765ff"), strong: bool = false) -> void:
	var normal=StyleBoxFlat.new()
	normal.bg_color=Color(.045,.022,.12,.94) if strong else Color(.012,.018,.065,.88)
	normal.border_color=Color(accent,.93 if strong else .68)
	normal.set_border_width_all(2 if strong else 1)
	normal.set_corner_radius_all(6)
	normal.shadow_color=Color(accent,.30 if strong else .17)
	normal.shadow_size=10 if strong else 6
	target.add_theme_stylebox_override("normal",normal)
	var hover=normal.duplicate() as StyleBoxFlat
	hover.bg_color=Color(.13,.045,.27,.98)
	hover.border_color=accent.lightened(.2)
	hover.set_border_width_all(2)
	hover.shadow_color=Color(accent,.50)
	hover.shadow_size=15
	target.add_theme_stylebox_override("hover",hover)
	var pressed=normal.duplicate() as StyleBoxFlat
	pressed.bg_color=Color(.22,.075,.39,.98)
	pressed.border_color=Color("eac8ff")
	pressed.shadow_size=4
	target.add_theme_stylebox_override("pressed",pressed)
	var disabled=normal.duplicate() as StyleBoxFlat
	disabled.bg_color=Color(.018,.018,.04,.66)
	disabled.border_color=Color(.30,.28,.40,.6)
	disabled.shadow_size=0
	target.add_theme_stylebox_override("disabled",disabled)
	target.add_theme_color_override("font_color",Color("f7edff"))
	target.add_theme_color_override("font_hover_color",Color.WHITE)
	target.add_theme_color_override("font_pressed_color",Color.WHITE)
	target.add_theme_color_override("font_outline_color",Color(accent,.52))
	target.add_theme_constant_override("outline_size",3 if strong else 2)

static func _flash(target: Control) -> void:
	var previous: Variant=target.get_meta("flash_tween") if target.has_meta("flash_tween") else null
	if previous is Tween and previous.is_running(): previous.kill()
	target.self_modulate=Color("e8d4ff")
	var tween=target.create_tween()
	tween.tween_property(target,"self_modulate",Color.WHITE,.22)
	target.set_meta("flash_tween",tween)

static func _scale(target: Control, value: float, duration: float) -> void:
	if not is_instance_valid(target): return
	var previous: Variant=target.get_meta("motion_tween") if target.has_meta("motion_tween") else null
	if previous is Tween and previous.is_running(): previous.kill()
	var tween=target.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target,"scale",Vector2.ONE*value,duration)
	target.set_meta("motion_tween",tween)

static func reveal(target: CanvasItem, delay: float = 0.0) -> void:
	var previous: Variant=target.get_meta("reveal_tween") if target.has_meta("reveal_tween") else null
	if previous is Tween and previous.is_running(): previous.kill()
	target.modulate.a=0.0
	var tween=target.create_tween()
	if delay>0: tween.tween_interval(delay)
	tween.tween_property(target,"modulate:a",1.0,.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	target.set_meta("reveal_tween",tween)
