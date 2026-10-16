extends Control

# The song's finish: the gameplay combo counter counts up to the max combo, grows to the
# middle of the screen with a light burst and a banner (ALL PERFECT / FULL COMBO / CLEAR),
# then shrinks and flies into the MAX COMBO slot on the results screen, where it stays.
const DURATION = 2.35
# When the results screen takes over underneath (seconds into the finish).
const RESULTS_AT = 1.3
const HUD_GLOW_PAD = 0.1

var game: Control
var elapsed = 0.0
var running = false
var start_combo = 0
var max_combo = 0
var shown_value = -1
var banner_text = ""
var accent = Color("38baff")
var accent_end = Color("a36aff")
var digits_box: Control
var banner: Label
var shade: ColorRect
var start_rect: Rect2
var target_rect: Rect2
var sparks: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade = ColorRect.new(); add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0,0,.03,0); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	digits_box = Control.new(); add_child(digits_box); digits_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = Label.new(); add_child(banner)
	var bold = FontVariation.new(); bold.base_font = ThemeDB.fallback_font; bold.variation_embolden = 1.0
	bold.spacing_glyph = 6
	banner.add_theme_font_override("font",bold); banner.add_theme_font_size_override("font_size",58)
	banner.add_theme_color_override("font_color",Color.WHITE)
	banner.add_theme_constant_override("shadow_offset_x",0); banner.add_theme_constant_override("shadow_offset_y",0)
	banner.add_theme_constant_override("shadow_outline_size",22)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

static func banner_for(counts: Dictionary, automated: bool) -> String:
	if automated: return "AUTO PLAY"
	if int(counts.get("MISS",0))==0 and int(counts.get("GREAT",0))==0 and int(counts.get("GOOD",0))==0 and int(counts.get("PERFECT",0))>0: return "ALL PERFECT"
	if int(counts.get("MISS",0))==0 and int(counts.get("PERFECT",0))+int(counts.get("GREAT",0))+int(counts.get("GOOD",0))>0: return "FULL COMBO"
	return "CLEAR"

# from_rect: where the gameplay combo counter is, in this overlay's coordinates.
func begin(from_rect: Rect2, current_combo: int, best_combo: int, title: String, colors: Array) -> void:
	start_rect = from_rect; start_combo = current_combo; max_combo = best_combo; banner_text = title
	accent = colors[0]; accent_end = colors[1]
	banner.text = banner_text
	banner.add_theme_color_override("font_shadow_color",Color(accent_end,.85))
	digits_box.size = start_rect.size; digits_box.pivot_offset = digits_box.size*.5
	shown_value = -1; elapsed = 0.0; running = true; visible = true
	sparks.clear()
	var random = RandomNumberGenerator.new(); random.seed = best_combo*31+7
	for i in 26:
		var angle = TAU*i/26.0 + random.randf_range(-.12,.12)
		sparks.append({"direction":Vector2(cos(angle),sin(angle)*.62),"speed":random.randf_range(.45,1.0),"size":random.randf_range(2.0,5.0),"color":accent if i%2==0 else accent_end})
	advance(0.0)

func stop() -> void:
	running = false; visible = false

# Where the digits land: the MAX COMBO figure on the results screen.
func set_target(rect: Rect2) -> void:
	target_rect = rect

func ease_out(t: float) -> float:
	t = clampf(t,0,1); return 1.0-pow(1.0-t,3.0)
func ease_in_out(t: float) -> float:
	t = clampf(t,0,1); return t*t*(3.0-2.0*t)

func _process(delta: float) -> void:
	if running: advance(delta)

func advance(delta: float) -> void:
	elapsed = minf(elapsed + delta, DURATION)
	# Once landed, the combo stays on the results screen until the player leaves it.
	if elapsed >= DURATION: running = false
	# Count up from the combo on screen to the best combo of the run.
	var value = roundi(lerpf(start_combo,max_combo,ease_out(elapsed/.6))) if max_combo>start_combo else max_combo
	if value != shown_value: shown_value = value; layout_digits(value)
	var center_rect = Rect2(size*Vector2(.5,.4)-start_rect.size*.5,start_rect.size)
	var rise = ease_out(elapsed/.55)
	var position_value = start_rect.position.lerp(center_rect.position,rise)
	var scale_value = lerpf(1.0,1.45,rise)
	# Then shrink and fly into the results screen's MAX COMBO figure.
	var fly = ease_in_out((elapsed-RESULTS_AT-.05)/.6)
	if fly > 0 and target_rect.size.y > 0:
		var target_scale = target_rect.size.y/maxf(1.0,start_rect.size.y)
		var target_position = target_rect.get_center()-start_rect.size*.5
		position_value = position_value.lerp(target_position,fly)
		scale_value = lerpf(scale_value,target_scale,fly)
	digits_box.position = position_value
	digits_box.scale = Vector2.ONE*scale_value*(1.0+.08*sin(clampf(elapsed/.5,0,1)*PI))
	if game and game.combo_glow: game.combo_glow.set_shader_parameter("boost",maxf(0.0,1.0-elapsed/.9))
	# Banner: slams in above the digits, then drifts up and fades as the results arrive.
	var banner_in = clampf((elapsed-.25)/.35,0,1)
	banner.size = Vector2(size.x,size.y*.12)
	banner.position = Vector2(0,size.y*.2-banner.size.y*.5-ease_out((elapsed-RESULTS_AT)/.5)*size.y*.05)
	banner.pivot_offset = banner.size*.5
	banner.scale = Vector2.ONE*(1.0+1.4*pow(1.0-banner_in,3.0))
	banner.modulate.a = ease_out(banner_in*1.5)*(1.0-ease_out((elapsed-RESULTS_AT)/.4))
	# The stage dims behind the finish, then clears for the results.
	shade.color.a = .5*ease_out(elapsed/.4)*(1.0-ease_out((elapsed-RESULTS_AT)/.35))
	queue_redraw()

func layout_digits(value: int) -> void:
	for child in digits_box.get_children():
		digits_box.remove_child(child); child.queue_free()
	if game == null: return
	var digits = str(value)
	var atlas: Texture2D = game.COMBO_ATLAS
	var digit_height = minf(digits_box.size.y*.96,digits_box.size.x/maxf(1,digits.length())*.82)
	var digit_width = digit_height*(float(atlas.get_width())/3.0)/(float(atlas.get_height())/3.0)
	var spacing = digit_width*.84
	var total_width = digit_width+spacing*(digits.length()-1)
	var left = (digits_box.size.x-total_width)*.5
	for i in digits.length():
		var digit = TextureRect.new(); digits_box.add_child(digit)
		digit.texture = game.combo_digit_textures[int(digits[i])]
		digit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		digit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		digit.material = game.combo_glow
		var content = Vector2(digit_width,digit_height)
		var padded = content/(1.0-2.0*HUD_GLOW_PAD)
		digit.position = Vector2(left+i*spacing,(digits_box.size.y-digit_height)*.5)-(padded-content)*.5
		digit.size = padded

func _draw() -> void:
	if not running: return
	var center = size*Vector2(.5,.4)
	# Two expanding light rings and a burst of sparks as the combo lands in the middle.
	for k in 2:
		var t = clampf((elapsed-.35-k*.14)/.75,0,1)
		if t <= 0 or t >= 1: continue
		var radius = lerpf(size.y*.06,size.y*.62,ease_out(t))
		var color: Color = accent if k==0 else accent_end
		draw_set_transform(center,0,Vector2(1,.62))
		draw_arc(Vector2.ZERO,radius,0,TAU,96,Color(color,(1.0-t)*.85),lerpf(14.0,2.0,t),true)
		draw_arc(Vector2.ZERO,radius,0,TAU,96,Color(1,1,1,(1.0-t)*.5),lerpf(4.0,1.0,t),true)
		draw_set_transform(Vector2.ZERO)
	var burst = clampf((elapsed-.35)/1.0,0,1)
	if burst > 0 and burst < 1:
		for spark in sparks:
			var distance = size.y*.55*float(spark.speed)*ease_out(burst)
			var point = center+Vector2(spark.direction)*distance
			draw_circle(point,float(spark.size)*(1.0-burst*.6),Color(spark.color,(1.0-burst)))
