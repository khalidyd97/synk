extends CanvasLayer
# One keyboard-aware editor handles existing and dynamically created text fields.
var game: Control
var overlay: Control
var panel: PanelContainer
var caption: Label
var single: LineEdit
var multiple: TextEdit
var source: Control
var original_text=""
var opening_window=Vector2.ZERO
var syncing=false

func _ready() -> void:
    layer=100
    overlay=Control.new(); overlay.name="FloatingTextEntry"; add_child(overlay)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.theme=game.ui.theme
    var dim=ColorRect.new(); overlay.add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.color=Color(0.006,0.006,0.006,.25)
    dim.mouse_filter=Control.MOUSE_FILTER_STOP
    panel=PanelContainer.new(); overlay.add_child(panel)
    var style=StyleBoxFlat.new(); style.bg_color=Color("161616"); style.border_color=Color("55d9e8")
    style.set_corner_radius_all(20); style.set_border_width_all(2)
    style.shadow_color=Color(0,0,0,.55); style.shadow_size=20
    style.content_margin_left=18; style.content_margin_right=18
    style.content_margin_top=16; style.content_margin_bottom=16
    panel.add_theme_stylebox_override("panel",style)
    var column=VBoxContainer.new(); panel.add_child(column); column.add_theme_constant_override("separation",12)
    var row=HBoxContainer.new(); column.add_child(row); row.add_theme_constant_override("separation",12)
    caption=Label.new(); row.add_child(caption); caption.text="Enter text"
    caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; caption.add_theme_font_size_override("font_size",22)
    for label in ["CANCEL","DONE"]:
        var button=preload("res://scripts/settings_action.gd").new(); row.add_child(button)
        button.text=label; button.primary=label=="DONE"; button.caption_size=20
        button.custom_minimum_size=Vector2(140,54)
        button.pressed.connect(finish.bind(label=="DONE"))
    single=LineEdit.new(); column.add_child(single); single.custom_minimum_size.y=58
    single.add_theme_font_size_override("font_size",24); single.size_flags_vertical=Control.SIZE_EXPAND_FILL
    single.text_changed.connect(write_text); single.text_submitted.connect(func(_value): finish(true))
    multiple=TextEdit.new(); column.add_child(multiple); multiple.custom_minimum_size.y=140
    multiple.add_theme_font_size_override("font_size",24); multiple.size_flags_vertical=Control.SIZE_EXPAND_FILL
    multiple.text_changed.connect(func(): write_text(multiple.text))
    get_viewport().gui_focus_changed.connect(on_focus_changed)
    overlay.hide(); set_process(false)

func on_focus_changed(control: Control) -> void:
    if syncing or control==null or overlay.is_ancestor_of(control): return
    if control is LineEdit or control is TextEdit:
        if control.editable and control.is_visible_in_tree(): open_focused.call_deferred(control)

func open_focused(control: Control) -> void:
    if is_instance_valid(control) and get_viewport().gui_get_focus_owner()==control:
        open_for(control)

func _input(event: InputEvent) -> void:
    if overlay.visible and event.is_action_pressed("ui_cancel"): handle_input(event)

func open_for(control: Control) -> void:
    if not (control is LineEdit or control is TextEdit) or not control.editable: return
    if source==control and overlay.visible: return
    if overlay.visible: finish(true)
    syncing=true; source=control; original_text=control.text
    opening_window=Vector2(DisplayServer.window_get_size())
    caption.text=control.placeholder_text if not control.placeholder_text.is_empty() else "Enter text"
    if control.get_parent() is SpinBox: caption.text="Enter value"
    single.visible=control is LineEdit; multiple.visible=control is TextEdit
    if control is LineEdit:
        single.max_length=control.max_length; single.secret=control.secret
        single.virtual_keyboard_type=control.virtual_keyboard_type
        single.placeholder_text=control.placeholder_text; single.text=control.text
        single.caret_column=control.caret_column
        if control.get_parent() is SpinBox: single.select_all()
    else:
        multiple.placeholder_text=control.placeholder_text; multiple.text=control.text
        multiple.set_caret_line(control.get_caret_line()); multiple.set_caret_column(control.get_caret_column())
    overlay.show(); set_process(true); layout_for_keyboard(keyboard_height())
    if control is LineEdit: single.grab_focus()
    else: multiple.grab_focus()
    syncing=false

func write_text(value: String) -> void:
    if syncing or not is_instance_valid(source): return
    syncing=true
    source.text=value
    if source is LineEdit: source.text_changed.emit(value)
    else: source.text_changed.emit()
    syncing=false

func finish(commit: bool) -> void:
    if not overlay.visible: return
    if not commit: write_text(original_text)
    var target=source
    syncing=true; overlay.hide(); set_process(false); source=null
    single.release_focus(); multiple.release_focus()
    if is_instance_valid(target) and target is LineEdit:
        if commit: target.text_submitted.emit(target.text)
        if is_instance_valid(target) and target.get_parent() is SpinBox: target.get_parent().apply()
    if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
    syncing=false

func handle_input(event: InputEvent) -> bool:
    if not overlay.visible: return false
    if event.is_action_pressed("ui_cancel"):
        finish(true); get_viewport().set_input_as_handled()
    return true

func keyboard_height() -> float:
    return DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0.0

func layout_for_keyboard(keyboard_pixels: float) -> void:
    var window=Vector2(DisplayServer.window_get_size())
    var safe=game.safe_area_rect if game.safe_area_rect.has_area() else Rect2(Vector2.ZERO,game.size)
    # If Android already resized the window for the IME, do not subtract it twice.
    var resized=maxf(0,opening_window.y-window.y)
    var covered=maxf(0,keyboard_pixels-resized)/maxf(1,window.y)*game.size.y
    var bottom=minf(safe.end.y,game.size.y-covered)-16
    var width=minf(1100,safe.size.x-32)
    var height=minf(300 if multiple.visible else 184,maxf(160,bottom-safe.position.y-16))
    panel.size=Vector2(width,height)
    panel.position=Vector2(safe.position.x+(safe.size.x-width)*.5,maxf(safe.position.y+8,bottom-height))

func _process(_delta: float) -> void:
    if not is_instance_valid(source) or not source.is_inside_tree() or not source.is_visible_in_tree():
        finish(true); return
    layout_for_keyboard(keyboard_height())
