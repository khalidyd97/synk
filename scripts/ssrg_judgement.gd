extends Control
# SSRG Playables judgement display, laid out like SSRG footage: the judgement word in the middle
# of the highway (about 40% down) with a large combo count under it, both popping on each hit and
# coloured by the grade. Replaces SYNK's judgement text and side combo during SSRG runs only.
const GRADE_COLORS = {"PERFECT": Color("ff7ad9"), "GREAT": Color("63d8ff"), "GOOD": Color("8cf28a"), "MISS": Color("9a9aaa")}
const POP_TIME = .14
var game: Control
var word: Label
var count: Label
var seen_judged = -1
var pop = 0.0
var since_hit = 99.0
var seen_combo = -1
var perfect_art: Texture2D = preload("res://assets/ssrg/imported/Text_perpect_super.png")
var digit_art: Array[Texture2D] = []

func _draw() -> void:
	if not visible: return
	var unit = minf(size.x / 1280.0, size.y / 720.0)
	if word.text == "PERFECT":
		var height = 44.0 * unit * (1.0 + pop * .12)
		var dimensions = Vector2(height * perfect_art.get_width() / float(perfect_art.get_height()), height)
		draw_texture_rect(perfect_art, Rect2(Vector2(size.x * .5, size.y * .40) - dimensions * .5, dimensions), false, Color(1,1,1,word.modulate.a))
	if game.combo <= 0: return
	var digits = str(game.combo)
	var height = 76.0 * unit * (1.0 + pop * .10)
	var total = 0.0
	for character in digits:
		var texture = digit_art[int(character)]
		total += height * texture.get_width() / float(texture.get_height())
	var x = (size.x - total) * .5
	for character in digits:
		var texture = digit_art[int(character)]
		var width = height * texture.get_width() / float(texture.get_height())
		draw_texture_rect(texture, Rect2(x, size.y * .48, width, height), false)
		x += width

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	word = make_label(.36, .44, 44)
	count = make_label(.44, .6, 72)
	visible = false
	for index in range(10): digit_art.append(load("res://assets/ssrg/imported/s%d.png" % index))

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
		return
	if game.judged != seen_judged or game.combo != seen_combo:
		seen_combo = game.combo
		seen_judged = game.judged; pop = 1.0; since_hit = 0.0
		var grade = str(game.judgement)
		var color: Color = Color.WHITE
		word.text = grade
		word.add_theme_color_override("font_color", color)
		count.add_theme_color_override("font_color", Color.WHITE.lerp(color, .25))
	if game.mode == "play":
		pop = maxf(0.0, pop - delta / POP_TIME); since_hit += delta
	count.text = str(game.combo) if game.combo > 0 else ""
	count.visible = false
	word.visible = word.text != "PERFECT"
	for label in [word, count]: label.pivot_offset = label.size * .5
	word.scale = Vector2.ONE * (1.0 + pop * .22)
	count.scale = Vector2.ONE * (1.0 + pop * .16)
	# The word fades after a moment without hits; the combo count stays.
	word.modulate.a = clampf(1.6 - since_hit, 0.0, 1.0) * (.75 if word.text == "MISS" else 1.0)
	queue_redraw()
