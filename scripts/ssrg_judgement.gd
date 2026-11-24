extends Control
# SSRG Playables judgement display, laid out like SSRG footage: the judgement word in the middle
# of the highway (about 40% down) with a large combo count under it, both popping on each hit and
# coloured by the grade. Replaces SYNK's judgement text and side combo during SSRG runs only.
const GRADE_COLORS = {"PERFECT": Color("ff7ad9"), "GREAT": Color("63d8ff"), "GOOD": Color("8cf28a"), "MISS": Color("9a9aaa")}
const POP_TIME = .14
const SOURCE_CURVES = preload("res://scripts/ssrg_runtime_curves.gd")
const SOURCE_HUD = preload("res://scripts/ssrg_hud_source_data.gd")
var combo_back:Control
var game: Control
var word: Label
var count: Label
var seen_judged = -1
var pop = 0.0
var since_hit = 99.0
var displayed_grade = ""
var seen_combo = -1
var perfect_art: Texture2D = preload("res://assets/ssrg/imported/hud/Text_perpect_super.png")
var ordinary_art: Texture2D = preload("res://assets/ssrg/imported/Text_perpect.png")
var good_art: Texture2D = preload("res://assets/ssrg/imported/Text_good.png")
var miss_art: Texture2D = preload("res://assets/ssrg/imported/Text_miss.png")
var digit_art: Array[Texture2D] = []

# SYNK mode's judgment and combo, drawn with the game's font in place of the SSRG art:
# the grade in wide-spaced capitals, a large glowing combo count under it, and a thin
# meter that fills toward every 50th combo.
# Each grade: its word, its text colour and its glow colour.
const SYNK_GRADES = {
	"PERFECT": ["PERFECT+", Color("fff6e6"), Color("ff9a3c")],
	"GREAT": ["PERFECT", Color("ffdca8"), Color("ff9a3c")],
	"GOOD": ["GOOD", Color("bff0ff"), Color("3cd8ff")],
	"MISS": ["MISS", Color("c9c2cf"), Color("ff3c5a")],
}
const SYNK_MILESTONE = 50
func spaced_width(font: Font, text: String, px: int, gap: float) -> float:
	var width = 0.0
	for i in text.length(): width += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + gap
	return width - gap
# Wide-spaced text centred on `centre`, with a soft glow behind the letters.
func spaced_glow(font: Font, centre: Vector2, text: String, px: int, gap: float, fill: Color, glow: Color) -> float:
	var width = spaced_width(font, text, px, gap)
	for layer in 2:
		var x = centre.x - width * .5
		for i in text.length():
			var at = Vector2(x, centre.y + px * .36)
			if layer == 0: draw_string_outline(font, at, text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(2, roundi(px * .28)), Color(glow, glow.a * .3))
			else: draw_string(font, at, text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, fill)
			x += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + gap
	return width

func draw_synk() -> void:
	var unit = minf(size.x / 1280.0, size.y / 720.0)
	var font: Font = game.GAME_FONT
	var centre = Vector2(size.x * .5, size.y * .34)
	var grade = SYNK_GRADES.get(displayed_grade, null)
	if grade != null:
		# The word punches in, holds, then fades.
		var shown = clampf(1.0 - (since_hit - .5) / .3, 0.0, 1.0)
		var px = roundi(30 * unit * (1.0 + .2 * pop))
		spaced_glow(font, centre, grade[0], px, 9 * unit, Color(grade[1], shown), Color(grade[2], shown))
	if game.combo < 2: return
	# The combo count.
	var number = str(game.combo)
	var count_px = roundi(104 * unit * (1.0 + .14 * pop))
	var count_width = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, count_px).x
	var count_at = Vector2(size.x * .5 - count_width * .5, centre.y + 118 * unit)
	var milestone = game.combo % SYNK_MILESTONE == 0
	var glow_color: Color = Color("ff9a3c") if not milestone else Color("ffe2b0")
	draw_string_outline(font, count_at, number, HORIZONTAL_ALIGNMENT_LEFT, -1, count_px, maxi(4, roundi(26 * unit)), Color(glow_color, .10 + .12 * pop))
	draw_string_outline(font, count_at, number, HORIZONTAL_ALIGNMENT_LEFT, -1, count_px, maxi(2, roundi(10 * unit)), Color(glow_color, .22 + .2 * pop))
	draw_string(font, count_at, number, HORIZONTAL_ALIGNMENT_LEFT, -1, count_px, Color(1, .98, .94))
	# COMBO, and the meter toward the next milestone.
	var label_at = Vector2(size.x * .5, centre.y + 142 * unit)
	spaced_glow(font, label_at, "COMBO", maxi(10, roundi(14 * unit)), 8 * unit, Color("ffb46a"), Color(0, 0, 0, 0))
	var half = 86 * unit
	var meter_y = label_at.y + 20 * unit
	var filled = 1.0 if milestone else float(game.combo % SYNK_MILESTONE) / SYNK_MILESTONE
	draw_line(Vector2(size.x * .5 - half, meter_y), Vector2(size.x * .5 + half, meter_y), Color(1, 1, 1, .14), maxf(1.0, 2.0 * unit), true)
	var meter_color = Color("fff6e6") if milestone else Color("ff9a3c")
	draw_line(Vector2(size.x * .5 - half * filled, meter_y), Vector2(size.x * .5 + half * filled, meter_y), meter_color, maxf(1.0, 2.4 * unit), true)

func _draw() -> void:
	if not visible: return
	if game.synk_mode():
		draw_synk(); return
	var unit = minf(size.x / 1280.0, size.y / 720.0)
	var source_scale=SOURCE_CURVES.judgement_scale(since_hit,word.text=="MISS")
	var source_offset=SOURCE_CURVES.judgement_offset(since_hit,word.text=="MISS")*unit
	var art: Texture2D=grade_art(displayed_grade)
	if art and displayed_grade=="PERFECT":
		var rect=super_word_rect()
		# Keep the complete word readable; never overlay the differently shaped
		# effects-atlas PERFECT or darken it with the reconstructed colour loop.
		var shadow=rect;shadow.position.y+=maxf(1.0,rect.size.y/27.0)
		draw_texture_rect(art,shadow,false,Color(0,0,0,word.modulate.a*.65))
		draw_texture_rect(art,rect,false,Color(1,1,1,word.modulate.a))
	elif art:
		var source_dimensions=Vector2(192,70) if displayed_grade=="MISS" else Vector2(art.get_width(),54)
		var dimensions = source_dimensions*(44.0/54.0)*unit*source_scale
		# Keep the user's accepted central layout; use source relative miss placement.
		var center=Vector2(size.x*.5,size.y*.40)
		if displayed_grade=="MISS": center.y+=65.0*(44.0/54.0)*unit
		var top_left=center+source_offset-dimensions*.5
		draw_texture_rect(art, Rect2(top_left, dimensions), false, Color(1,1,1,word.modulate.a))
	if not SOURCE_CURVES.combo_visible(since_hit,game.combo): return
	draw_source_combo(self,false)

func super_word_rect() -> Rect2:
	var unit=game.size.y/game.field.world.ssrg_canvas_height()
	var sampled:Vector3=SOURCE_CURVES.sample("JudgementGood05","scale","trans","",since_hit,Vector3.ONE)
	var scale_now=Vector2(sampled.x,sampled.y)
	var dimensions=Vector2(272,54)*unit*scale_now
	return Rect2(Vector2(size.x*.5,size.y*.5-60*unit)-dimensions*.5,dimensions)

func combo_rects() -> Array[Rect2]:
	var result:Array[Rect2]=[]
	var digits=str(game.combo)
	var unit=game.size.y/game.field.world.ssrg_canvas_height()
	var sampled:Vector3=SOURCE_CURVES.sample("JudgementGood05" if displayed_grade=="PERFECT" else "JudgementGood","scale","trans","",since_hit,Vector3.ONE)
	var scale_now=Vector2(sampled.x,sampled.y)*unit
	var step=172.0/3.0 if displayed_grade=="GOOD" else 176.0/3.0
	var center=Vector2(size.x*.5,size.y*.5+SOURCE_HUD.COMBO_Y*unit)
	for i in digits.length():
		var dimensions=Vector2(60 if displayed_grade=="GOOD" and i==digits.length()-1 else 56,90)*scale_now
		var offset=Vector2((i-(digits.length()-1)*.5)*step,0)*scale_now
		result.append(Rect2(center+offset-dimensions*.5,dimensions))
	return result

func draw_source_combo(target:CanvasItem,back:bool) -> void:
	if game.synk_mode():return
	if not visible or not SOURCE_CURVES.combo_visible(since_hit,game.combo):return
	if back and displayed_grade!="PERFECT":return
	var fonts=SOURCE_HUD.SUPER_BACK if back else (SOURCE_HUD.SUPER if displayed_grade=="PERFECT" else (SOURCE_HUD.GOOD if displayed_grade=="GOOD" else SOURCE_HUD.PERFECT))
	var tint=SOURCE_HUD.SUPER_BACK_TINT if back else (SOURCE_HUD.SUPER_TINT if displayed_grade=="PERFECT" else Color.WHITE)
	if displayed_grade!="PERFECT":tint.a*=SOURCE_CURVES.word_alpha(since_hit)
	var value=str(game.combo)
	var rects=combo_rects()
	for i in value.length():target.draw_texture_rect(fonts[int(value[i])],rects[i],false,tint)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	word = make_label(.36, .44, 44)
	count = make_label(.44, .6, 72)
	visible = false
	for texture in SOURCE_HUD.SUPER:digit_art.append(texture)
	combo_back=Control.new();add_child(combo_back);combo_back.mouse_filter=Control.MOUSE_FILTER_IGNORE
	combo_back.show_behind_parent=true
	var additive=CanvasItemMaterial.new();additive.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;combo_back.material=additive
	combo_back.draw.connect(func():draw_source_combo(combo_back,true))

func grade_art(grade: String) -> Texture2D:
	match grade:
		"PERFECT": return perfect_art
		"GREAT": return ordinary_art
		"GOOD": return good_art
		"MISS": return miss_art
	return null

static func grade_text(grade:String) -> String:
	return "S.PERFECT" if grade=="PERFECT" else ("PERFECT" if grade=="GREAT" else grade)

func make_label(top: float, bottom: float, size: int) -> Label:
	var label = Label.new(); add_child(label)
	label.anchor_left = .25; label.anchor_right = .75; label.anchor_top = top; label.anchor_bottom = bottom
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font = game.hit_label.get_theme_font("font") if game.hit_label else null
	if font: label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, .55)); label.add_theme_constant_override("outline_size", 10)
	return label

func _process(delta: float) -> void:
	var playing = game.uses_ssrg_gameplay() and game.mode in ["play", "paused"] and game.countdown <= 0 and not game.finishing
	visible = playing
	if not playing:
		seen_judged = game.judged
		seen_combo = game.combo
		since_hit = 99.0
		displayed_grade = ""
		return
	if game.judged != seen_judged or game.combo != seen_combo:
		seen_combo = game.combo
		seen_judged = game.judged; pop = 1.0; since_hit = 0.0
		var grade = str(game.judgement)
		displayed_grade=grade
		var color: Color = Color.WHITE
		# SYNK's internal GREAT is the source game's ordinary PERFECT grade.
		word.text = grade_text(grade)
		word.add_theme_color_override("font_color", color)
		count.add_theme_color_override("font_color", Color.WHITE.lerp(color, .25))
	if game.mode == "play":
		pop = maxf(0.0, pop - delta / POP_TIME); since_hit += delta
	count.text = str(game.combo) if game.combo > 0 else ""
	count.visible = false
	word.visible = grade_art(displayed_grade)==null
	for label in [word, count]: label.pivot_offset = label.size * .5
	word.scale = SOURCE_CURVES.judgement_scale(since_hit,word.text=="MISS")
	var source_offset=SOURCE_CURVES.judgement_offset(since_hit,word.text=="MISS")*minf(size.x/1280.0,size.y/720.0)
	word.offset_top=source_offset.y; word.offset_bottom=source_offset.y
	count.scale = SOURCE_CURVES.judgement_scale(since_hit)
	# Native EndRender auto-hides the word and its combo after the source clip.
	word.modulate.a = (1.0 if since_hit<SOURCE_CURVES.SUCCESS_LIFETIME_SECONDS else 0.0) if displayed_grade=="PERFECT" else SOURCE_CURVES.word_alpha(since_hit,displayed_grade=="MISS")
	combo_back.queue_redraw()
	queue_redraw()
