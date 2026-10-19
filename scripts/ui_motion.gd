extends RefCounted

const UiSound = preload("res://scripts/ui_sound.gd")

static func bind_button(target: BaseButton) -> void:
	if target.has_meta("ui_motion_bound"): return
	target.set_meta("ui_motion_bound", true)
	target.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	target.resized.connect(func(): target.pivot_offset=target.size*.5)
	target.pivot_offset=target.size*.5
	target.mouse_entered.connect(func():
		if not target.disabled: _scale(target,1.035,.16))
	target.mouse_exited.connect(func(): _scale(target,1.0,.16))
	target.button_down.connect(func(): _scale(target,.94,.085); _flash(target); UiSound.play(target,UiSound.sound_for(target)))
	target.button_up.connect(func(): _scale(target,1.035 if target.get_global_rect().has_point(target.get_global_mouse_position()) else 1.0,.20))
	target.focus_entered.connect(func(): _scale(target,1.035,.16))
	target.focus_exited.connect(func(): _scale(target,1.0,.16))
	target.visibility_changed.connect(func():
		if not target.is_visible_in_tree():
			var running: Variant=target.get_meta("motion_tween") if target.has_meta("motion_tween") else null
			if running is Tween: running.kill()
			target.scale=Vector2.ONE)

static func style_button(target: Button, accent: Color = Color("a765ff"), strong: bool = false) -> void:
	var normal=StyleBoxFlat.new()
	normal.bg_color=Color(0.053,0.053,0.053,.94) if strong else Color(0.027,0.027,0.027,.88)
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
	disabled.bg_color=Color(0.022,0.022,0.022,.66)
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

# Screen-to-screen motion. The outgoing frame is captured once and animated on top while the
# live destination slides in underneath (the viewport's canvas is offset, so no screen needs
# its own animation code). direction 1 = forward: the old screen drifts left and recedes, the
# new one arrives from the right. -1 = back: the reverse. 0 = a plain dissolve (gameplay).
# Navigation stays synchronous: audio, focus and game clocks are never delayed.
const SLIDE = .16
static func transition(source: Node, duration: float = .30, direction: int = 1) -> void:
	if not source.is_inside_tree() or Engine.get_frames_drawn()<2: return
	var viewport=source.get_viewport()
	var existing=viewport.get_node_or_null("ScreenTransition")
	if existing: return
	if DisplayServer.get_name()=="headless": return
	var frame=viewport.get_texture().get_image()
	if frame==null or frame.is_empty(): return
	if frame.get_width()>1280:
		frame.resize(1280,int(frame.get_height()*1280.0/frame.get_width()),Image.INTERPOLATE_BILINEAR)
	var layer=CanvasLayer.new(); layer.name="ScreenTransition"; layer.layer=100
	viewport.add_child(layer)
	var picture=TextureRect.new(); layer.add_child(picture)
	picture.texture=ImageTexture.create_from_image(frame)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var tween=layer.create_tween().set_parallel(true)
	if direction==0:
		tween.tween_property(picture,"modulate:a",0.0,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		duration=maxf(duration,.38)
		var width=viewport.get_visible_rect().size.x
		picture.pivot_offset=viewport.get_visible_rect().size*.5
		# Outgoing: slides a little, shrinks slightly and fades; a soft shade sells the depth.
		tween.tween_property(picture,"position:x",-direction*width*SLIDE*.6,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(picture,"scale",Vector2.ONE*.94,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(picture,"modulate",Color(.55,.55,.62,0.0),duration*.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# Incoming: the live screen glides in from the side.
		var start=viewport.canvas_transform
		var from=start; from.origin.x+=direction*width*SLIDE
		viewport.canvas_transform=from
		tween.tween_method(_shift_canvas.bind(viewport),from.origin.x,start.origin.x,duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(layer.queue_free)

static func _shift_canvas(x: float, viewport: Viewport) -> void:
	if not is_instance_valid(viewport): return
	var t=viewport.canvas_transform; t.origin.x=x; viewport.canvas_transform=t

static func forward(source: Node, duration: float = .38) -> void: transition(source,duration,1)
static func back(source: Node, duration: float = .38) -> void: transition(source,duration,-1)

# Animate the visual transform, leaving Container layout and hit geometry intact.
static func pop(target: Control, delay: float = 0.0) -> void:
	var previous: Variant=target.get_meta("pop_tween") if target.has_meta("pop_tween") else null
	if previous is Tween: previous.kill()
	target.pivot_offset=target.size*.5
	target.scale=Vector2.ONE*.975
	reveal(target,delay)
	var tween=target.create_tween()
	if delay>0: tween.tween_interval(delay)
	tween.tween_property(target,"scale",Vector2.ONE,.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	target.set_meta("pop_tween",tween)

static func page(tabs: TabContainer) -> void:
	transition(tabs,.20)
	var content=tabs.get_current_tab_control()
	if content: reveal(content)

static func screen(target: Control) -> void:
	reveal(target)
	var index=0
	for child in target.get_children():
		if child is Panel and child.visible:
			pop(child,minf(index*.045,.18))
			index+=1
