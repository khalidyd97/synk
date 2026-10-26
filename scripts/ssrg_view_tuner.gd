extends Control
# In-game view controls for SSRG Playables (top right, only during an SSRG run): ANGLE tilts the
# camera, LENS widens or narrows it. The judgement line and rails stay put, so the highway's
# depth and slope can be tried live while the song plays. Values are kept for later runs.
const TEXT = Color("eef0ff")
var game: Control
var panel: Panel
var angle_label: Label
var lens_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = Panel.new(); add_child(panel)
	panel.anchor_left = .76; panel.anchor_right = .985; panel.anchor_top = .03; panel.anchor_bottom = .21
	var style = StyleBoxFlat.new(); style.bg_color = Color(0,0,0,.55); style.set_corner_radius_all(14)
	style.border_color = Color(1,1,1,.15); style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel",style)
	angle_label = row(0.0,"ANGLE",func(): game.change_ssrg_view(-2,0),func(): game.change_ssrg_view(2,0))
	lens_label = row(.5,"LENS",func(): game.change_ssrg_view(0,-5),func(): game.change_ssrg_view(0,5))
	visible = false

func row(top: float, caption: String, less: Callable, more: Callable) -> Label:
	var name_label = label(caption,.04,top,.36,top+.5,15)
	name_label.add_theme_color_override("font_color",Color(TEXT,.7))
	button("−",.38,top+.06,.56,top+.44,less)
	var value = label("",.56,top,.8,top+.5,18); value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button("+",.8,top+.06,.97,top+.44,more)
	return value

func label(text: String, left: float, top: float, right: float, bottom: float, size: int) -> Label:
	var result = Label.new(); panel.add_child(result); result.text = text
	result.anchor_left = left; result.anchor_right = right; result.anchor_top = top; result.anchor_bottom = bottom
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size",size); result.add_theme_color_override("font_color",TEXT)
	return result

func button(text: String, left: float, top: float, right: float, bottom: float, action: Callable) -> void:
	var result = Button.new(); panel.add_child(result); result.text = text; result.focus_mode = Control.FOCUS_NONE
	result.anchor_left = left; result.anchor_right = right; result.anchor_top = top; result.anchor_bottom = bottom
	result.add_theme_font_size_override("font_size",20)
	for state in ["normal","hover","pressed"]:
		var box = StyleBoxFlat.new(); box.bg_color = Color(1,1,1,.08 if state=="normal" else .2); box.set_corner_radius_all(10)
		result.add_theme_stylebox_override(state,box)
	result.pressed.connect(action)

func _process(_delta: float) -> void:
	visible = game.ssrg_playable_run and game.mode in ["play","paused"]
	if visible:
		angle_label.text = "%d°" % roundi(game.ssrg_tilt)
		lens_label.text = "%d°" % roundi(game.ssrg_fov)
