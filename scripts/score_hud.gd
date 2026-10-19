class_name SynkScoreHud
extends Control

# Top-left gameplay readout: a heart + ENERGY gauge above a slanted SCORE caption and a large score.
const ENERGY_FILL = Color("4ff07c")
const ENERGY_TRACK = Color(1,1,1,.16)
const TEXT_COLOR = Color("f4f6ff")

var energy_color=ENERGY_FILL
var score_label: Label
var energy = 0.5
var shown_energy = 0.5
var progress = 0.0
var italic: FontVariation
var light_italic: FontVariation

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	italic = slanted(0.0)
	light_italic = slanted(-.35)
	caption("ENERGY",.075,0,.6,.2,21)
	caption("SCORE",0,.4,.6,.6,21)
	score_label = Label.new(); add_child(score_label)
	place(score_label,0,.52,1,1)
	score_label.add_theme_font_override("font",light_italic)
	score_label.add_theme_font_size_override("font_size",48)
	score_label.add_theme_color_override("font_color",TEXT_COLOR)
	score_label.add_theme_color_override("font_shadow_color",Color(0,0,.02,.6))
	score_label.add_theme_constant_override("shadow_offset_x",0); score_label.add_theme_constant_override("shadow_offset_y",2)
	score_label.add_theme_constant_override("shadow_outline_size",8)
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func slanted(weight: float) -> FontVariation:
	var font = FontVariation.new(); font.base_font = ThemeDB.fallback_font
	font.variation_transform = Transform2D(Vector2(1,0),Vector2(-.2,1),Vector2.ZERO)
	font.variation_embolden = weight
	return font

func place(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.anchor_left = left; node.anchor_top = top; node.anchor_right = right; node.anchor_bottom = bottom
	node.offset_left = 0; node.offset_top = 0; node.offset_right = 0; node.offset_bottom = 0

func caption(text: String, left: float, top: float, right: float, bottom: float, font_size: int) -> Label:
	var result = Label.new(); add_child(result); place(result,left,top,right,bottom)
	result.text = text
	result.add_theme_font_override("font",italic)
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",TEXT_COLOR)
	result.add_theme_color_override("font_shadow_color",Color(0,0,.02,.55))
	result.add_theme_constant_override("shadow_outline_size",6)
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func set_score(text: String) -> void:
	score_label.text = text

func _process(delta: float) -> void:
	# The gauge eases toward its target so hits and misses read as motion, not jumps.
	shown_energy = lerpf(shown_energy,energy,1.0-exp(-delta*10.0))
	queue_redraw()

func _draw() -> void:
	var h = size.y
	# Heart badge in front of the ENERGY caption.
	var badge = Vector2(h*.055,h*.1); var r = h*.055
	draw_circle(badge,r,TEXT_COLOR)
	var s = r*.55
	var heart = PackedVector2Array()
	for i in 32:
		var t = TAU*i/32.0
		heart.append(badge+Vector2(16*pow(sin(t),3),-(13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t)))*s/16.0+Vector2(0,s*.1))
	draw_colored_polygon(heart,Color("1a1830"))
	# Energy gauge.
	var bar = Rect2(0,h*.235,size.x,h*.1)
	draw_rect(bar,ENERGY_TRACK)
	var fill = Rect2(bar.position,Vector2(bar.size.x*clampf(shown_energy,0,1),bar.size.y))
	draw_rect(fill,energy_color)
	draw_rect(Rect2(fill.position,Vector2(fill.size.x,fill.size.y*.35)),Color(1,1,1,.22))
	if fill.size.x > 2:
		# A bright tip glow where the gauge ends.
		var tip = Vector2(fill.end.x,bar.get_center().y)
		for i in 4: draw_circle(tip,bar.size.y*(1.6-i*.35),Color(energy_color.lightened(.4),.08+i*.06))
	# Slim song progress along the bottom of the block.
	draw_rect(Rect2(0,h*.985,size.x,h*.015),Color(1,1,1,.1))
	draw_rect(Rect2(0,h*.985,size.x*clampf(progress,0,1),h*.015),Color(1,1,1,.45))
