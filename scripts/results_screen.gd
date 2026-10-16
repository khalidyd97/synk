extends Control
const ScreenStyle = preload("res://scripts/screen_style.gd")

# End-of-song results: cover card, a glowing rank that pops in, a score that counts up,
# accuracy / max combo, and a judgment breakdown with animated bars.
const NAVY = Color(.006,.008,.025)
const RANK_COLORS = {"SS":Color("ffd447"),"S":Color("ff7ad9"),"A":Color("b985ff"),"B":Color("38baff"),"C":Color("8f96b8"),"AUTO":Color("86d9ff")}
const JUDGMENT_COLORS = {"PERFECT":Color("ffd447"),"GREAT":Color("38baff"),"GOOD":Color("a36aff"),"MISS":Color("ff4d6a")}
const SCORE_COUNT_TIME = 1.2
# Rank letters drawn in the same neon glass style as the combo digits (tools/rank_letters).
const RANK_ART = {"S":preload("res://assets/hud/Rank_S.png"),"A":preload("res://assets/hud/Rank_A.png"),"B":preload("res://assets/hud/Rank_B.png"),"C":preload("res://assets/hud/Rank_C.png"),"D":preload("res://assets/hud/Rank_D.png")}
const GLOW_PAD = 0.1

var game: Control
var elapsed = 0.0
var final_score = 0
var counts: Dictionary = {}
var total_judgments = 1
var backdrop_art: TextureRect
var card: Panel
var card_art: TextureRect
var song_title: Label
var song_meta: Label
var rank_label: Label
var rank_art: Control
var combo_slot: Control
var combo_value_label: Label
var score_label: Label
var best_badge: Label
var stats_label: Label
var note_label: Label
var breakdown: Control
var buttons: Array = []
var timing_graph: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop = ColorRect.new(); add_child(backdrop); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = NAVY; backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_art = TextureRect.new(); add_child(backdrop_art); backdrop_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; backdrop_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop_art.mouse_filter = Control.MOUSE_FILTER_IGNORE; backdrop_art.modulate.a = .2
	var shade = ColorRect.new(); add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(NAVY,.45); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ScreenStyle.glass(self,Rect2(.405,.075,.565,.455),Color("b58aff"),3)
	ScreenStyle.glass(self,Rect2(.425,.545,.545,.285),Color("65dfff"),4)
	# Left column: the song.
	card = Panel.new(); place(card,.07,.14,.35,.64); card.clip_contents = true
	var frame = StyleBoxFlat.new(); frame.bg_color = Color("140d30"); frame.set_corner_radius_all(14); frame.shadow_color = Color(Color("a36aff"),.5); frame.shadow_size = 24
	card.add_theme_stylebox_override("panel",frame)
	card_art = TextureRect.new(); card.add_child(card_art); card_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ScreenStyle.round_cover(card_art,18)
	song_title = caption(.05,.66,.37,.74,38,Color("f6efff"),HORIZONTAL_ALIGNMENT_CENTER)
	song_title.clip_text=true; song_title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	song_meta = caption(.05,.735,.37,.79,18,Color("cbbcff"),HORIZONTAL_ALIGNMENT_CENTER)
	# Right column: the result.
	caption(.43,.08,.95,.14,20,Color("86d9ff")).text = "RESULT"
	rank_label = caption(.42,.12,.62,.44,150,Color.WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	rank_label.add_theme_constant_override("outline_size",10)
	rank_art = Control.new(); place(rank_art,.42,.13,.62,.43); rank_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption(.64,.17,.95,.23,18,Color("b8b0d8")).text = "SCORE"
	score_label = caption(.64,.21,.95,.33,64,Color("f6efff"))
	score_label.add_theme_color_override("font_outline_color",Color("5a1fb0")); score_label.add_theme_constant_override("outline_size",5)
	best_badge = caption(.64,.33,.83,.385,18,Color("1a0b33"),HORIZONTAL_ALIGNMENT_CENTER)
	best_badge.text = "★  NEW BEST"
	var badge_style = StyleBoxFlat.new(); badge_style.bg_color = Color("ffd447"); badge_style.set_corner_radius_all(8)
	badge_style.shadow_color = Color(Color("ffd447"),.5); badge_style.shadow_size = 12
	best_badge.add_theme_stylebox_override("normal",badge_style)
	stats_label = caption(.64,.39,.95,.44,22,Color("e6e1ff"))
	caption(.64,.45,.76,.53,22,Color("e6e1ff")).text = "MAX COMBO"
	# The finish animation lands the gameplay combo counter in this slot and leaves it here.
	combo_slot = Control.new(); place(combo_slot,.79,.44,.95,.53); combo_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_value_label = Label.new(); combo_slot.add_child(combo_value_label); combo_value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combo_value_label.add_theme_font_size_override("font_size",40); combo_value_label.add_theme_color_override("font_color",Color("f6efff"))
	combo_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; combo_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	breakdown = Control.new(); place(breakdown,.45,.61,.95,.775); breakdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breakdown.draw.connect(draw_breakdown)
	timing_graph=load("res://scripts/timing_graph.gd").new(); place(timing_graph,.45,.61,.95,.775); timing_graph.visible=false
	note_label = caption(.45,.78,.95,.82,17,Color("9fa3c8"))
	visible = false

func place(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	add_child(node)
	node.anchor_left = left; node.anchor_top = top; node.anchor_right = right; node.anchor_bottom = bottom
	node.offset_left = 0; node.offset_top = 0; node.offset_right = 0; node.offset_bottom = 0

func caption(left: float, top: float, right: float, bottom: float, font_size: int, color: Color, align = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label = Label.new(); place(label,left,top,right,bottom)
	label.horizontal_alignment = align; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0,0,.02,.7)); label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func add_buttons() -> void:
	# Built once the game is attached, using the shared design-system buttons.
	if not buttons.is_empty(): return
	buttons.append(game.button(self,"‹  LOBBY",.45,.84,.68,.965,func(): game.set_mode("menu"),"nav"))
	buttons.append(game.button(self,"RETRY",.70,.84,.95,.965,func():
		if game.practice.active: game.practice.restart()
		else: game.start_game(game.last_play_notes,game.auto_play,game.last_section),"primary"))
	game.button(self,"JUDGMENTS",.45,.55,.68,.60,func(): breakdown.visible=true; timing_graph.visible=false,"tool")
	game.button(self,"TIMING",.70,.55,.95,.60,func(): breakdown.visible=false; timing_graph.visible=true,"tool")
	for result_button in buttons:
		result_button.caption_size = 26

# info: cover, tint, title, details, rank, score, accuracy, max_combo, counts, best, new_best, auto_play
func show_results(info: Dictionary) -> void:
	add_buttons()
	for art in [backdrop_art,card_art]: art.texture = info.cover; art.self_modulate = info.tint
	song_title.text = str(info.title).to_upper(); song_meta.text = info.details
	var rank = "AUTO" if info.auto_play else str(info.rank)
	if info.get("practice",false): rank="PRACTICE"
	rank_label.text = rank
	rank_label.add_theme_font_size_override("font_size",48 if rank=="PRACTICE" else (96 if rank=="AUTO" else 150))
	var rank_color: Color = RANK_COLORS.get(rank,Color.WHITE)
	rank_label.add_theme_color_override("font_color",rank_color.lightened(.25))
	rank_label.add_theme_color_override("font_outline_color",rank_color.darkened(.45))
	final_score = int(info.score)
	counts = info.counts
	total_judgments = maxi(1,int(counts.get("PERFECT",0))+int(counts.get("GREAT",0))+int(counts.get("GOOD",0))+int(counts.get("MISS",0)))
	stats_label.text = "ACCURACY  %.2f%%" % float(info.accuracy)
	combo_value_label.text = str(int(info.max_combo)); combo_value_label.visible = true
	build_rank_art(rank)
	best_badge.visible = bool(info.new_best)
	note_label.text = "Preview only — Auto Play scores are not saved." if info.auto_play else "Personal best  %s" % game.format_score(int(info.best))
	if info.get("practice",false): note_label.text="Practice run · scores are not saved."
	timing_graph.samples=info.get("timing",[]).duplicate(true)
	timing_graph.samples.sort_custom(func(a,b): return float(a.time)<float(b.time)); timing_graph.queue_redraw()
	breakdown.visible=true; timing_graph.visible=false
	elapsed = 0.0; visible = true
	animate()

# Lays out the rank in the glass letter art (SS is two letters), sharing the combo digits'
# gradient material so the rank and the combo read as one set.
func build_rank_art(rank: String) -> void:
	for child in rank_art.get_children():
		rank_art.remove_child(child); child.queue_free()
	var letters: Array = Array(rank.split(""))
	var art_available = letters.all(func(letter): return RANK_ART.has(letter))
	rank_label.visible = not art_available
	rank_art.visible = art_available
	if not art_available: return
	var texture: Texture2D = RANK_ART[letters[0]]
	var height = minf(rank_art.size.y*.95,rank_art.size.x/letters.size()*.95)
	var width = height*float(texture.get_width())/float(texture.get_height())
	var spacing = width*.78
	var total = width+spacing*(letters.size()-1)
	var left = (rank_art.size.x-total)*.5
	for i in letters.size():
		var letter = TextureRect.new(); rank_art.add_child(letter)
		letter.texture = RANK_ART[letters[i]]
		letter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; letter.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if game: letter.material = game.combo_glow
		var content = Vector2(width,height); var padded = content/(1.0-2.0*GLOW_PAD)
		letter.position = Vector2(left+i*spacing,(rank_art.size.y-height)*.5)-(padded-content)*.5
		letter.size = padded

func _process(delta: float) -> void:
	if not visible: return
	elapsed += delta
	animate()

func ease_out(t: float) -> float:
	t = clampf(t,0.0,1.0); return 1.0 - pow(1.0 - t,3.0)

func animate() -> void:
	modulate.a = ease_out(elapsed/.3)
	card.pivot_offset = card.size*.5
	var card_in = ease_out((elapsed-.05)/.5)
	card.position.x = lerpf(-80.0,0.0,card_in) + card.get_parent_area_size().x*card.anchor_left
	card.modulate.a = card_in
	# The rank slams in from large, with a bright flash as it lands.
	var rank_t = clampf((elapsed-.35)/.45,0.0,1.0)
	var overshoot = 1.0 + 2.2*pow(1.0-rank_t,3.0)
	rank_label.pivot_offset = rank_label.size*.5
	rank_label.scale = Vector2.ONE*overshoot
	rank_label.modulate = Color(1,1,1,ease_out(rank_t*2.0)).lerp(Color(1.6,1.6,1.6,1),maxf(0.0,1.0-abs(rank_t-1.0)*4.0) if rank_t>=1.0 else 0.0)
	rank_art.pivot_offset = rank_art.size*.5
	rank_art.scale = rank_label.scale; rank_art.modulate = rank_label.modulate
	var count_t = ease_out((elapsed-.45)/SCORE_COUNT_TIME)
	score_label.text = game.format_score(roundi(final_score*count_t)) if game else str(final_score)
	for label in [score_label,stats_label]: label.modulate.a = ease_out((elapsed-.4)/.4)
	best_badge.modulate.a = ease_out((elapsed-.45-SCORE_COUNT_TIME)/.3)
	best_badge.pivot_offset = best_badge.size*.5
	best_badge.scale = Vector2.ONE*(1.0+.25*(1.0-ease_out((elapsed-.45-SCORE_COUNT_TIME)/.35)))
	note_label.modulate.a = ease_out((elapsed-1.2)/.4)
	for i in buttons.size(): buttons[i].modulate.a = ease_out((elapsed-.9-i*.08)/.35)
	breakdown.queue_redraw()

func draw_breakdown() -> void:
	var font = ThemeDB.fallback_font
	var row_height = breakdown.size.y/4.0
	var names = ["PERFECT","GREAT","GOOD","MISS"]
	for i in names.size():
		var grow = ease_out((elapsed-.7-i*.1)/.6)
		var y = row_height*i + row_height*.5
		var color: Color = JUDGMENT_COLORS[names[i]]
		# Judgment names in the regular font, each in its own colour with a soft glow behind it.
		var name_size = int(clampf(row_height*.5,16,28))
		var baseline = y+name_size*.36
		breakdown.draw_string_outline(font,Vector2(0,baseline),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,name_size,6,Color(color,.25*grow))
		breakdown.draw_string(font,Vector2(0,baseline),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,name_size,Color(color.lightened(.15),grow))
		var bar_left = breakdown.size.x*.29; var bar_width = breakdown.size.x*.56
		breakdown.draw_rect(Rect2(bar_left,y-5,bar_width,10),Color(1,1,1,.07*grow))
		var share = float(counts.get(names[i],0))/float(total_judgments)
		var fill = bar_width*share*grow
		if fill > 0.5:
			breakdown.draw_rect(Rect2(bar_left,y-9,fill,18),Color(color,.18*grow))
			breakdown.draw_rect(Rect2(bar_left,y-5,fill,10),Color(color,.95*grow))
		var shown = roundi(float(counts.get(names[i],0))*grow)
		breakdown.draw_string(font,Vector2(bar_left+bar_width+16,y+8),str(shown),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color(color.lightened(.35),grow))
