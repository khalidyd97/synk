extends RefCounted
# Album Takeover: SYNK's menu look. The current song's cover colours the whole screen;
# type does the work (a big serif for names, a tight sans for everything else);
# controls are soft rounded shapes on dark glass, with no outlines, grids or neon.
# Gameplay and the loading screen keep their own look; every other screen draws through here.
# (Names below are kept from the previous look so every screen keeps compiling.)

const INK = Color("0c0d0f")
const NIGHT = Color("111215")
const PANEL = Color(1, 1, 1, .06)
const PANEL_LOW = Color(1, 1, 1, .045)
const PANEL_HIGH = Color(1, 1, 1, .10)
const LINE = Color(1, 1, 1, .14)
const CYAN = Color("f4f1ea")          # the highlight: warm paper white
const MAGENTA = Color("ff8a5b")       # the accent: a warm coral, used sparingly
const MAGENTA_DEEP = Color("d9643a")
const VIOLET = Color("1a1410")
const TEXT = Color("f4f1ea")
const SUBTLE = Color("d9d4ca")
const MUTED = Color("bcb7ad")
const DIM = Color("8e897f")
const DANGER = Color("ff6b5e")
const GOLD = Color("ffd36a")

# Kept for callers that still pass a slant; shapes are no longer slanted.
const SLANT = 0.0
const MAX_SHIFT = 0.0
# Corner radius: pills for anything button-sized, softer cards above that.
const CARD_RADIUS = 18.0

const SERIF = preload("res://assets/fonts/InstrumentSerif-Regular.ttf")
const SERIF_ITALIC = preload("res://assets/fonts/InstrumentSerif-Italic.ttf")
const SANS_FILE = preload("res://assets/fonts/InterTight-Variable.ttf")
const HEAD = SERIF
const MONO_FILE = SANS_FILE

static var _sans: FontVariation
static var _sans_semi: FontVariation
static var _sans_bold: FontVariation
static var _head_semi: FontVariation
# One font per weight, shared: controls that draw text every frame ask for it each time.
static var _sans_cache: Dictionary = {}
static func sans(weight: int = 500) -> Font:
	if _sans_cache.has(weight): return _sans_cache[weight]
	# Godot only applies a variable-font axis keyed by its OpenType tag number; a "wght"
	# string key is ignored and every weight falls back to the thin default.
	var f = FontVariation.new(); f.base_font = SANS_FILE
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_sans_cache[weight] = f
	return f
static func mono() -> Font:
	if _sans == null: _sans = sans(500)
	return _sans
static func mono_bold() -> Font:
	if _sans_bold == null: _sans_bold = sans(700)
	return _sans_bold
static func semi() -> Font:
	if _sans_semi == null: _sans_semi = sans(600)
	return _sans_semi

static func shift_for(_height: float) -> float:
	return 0.0

static func radius_for(rect: Rect2) -> float:
	return rect.size.y * .5 if rect.size.y <= 72.0 else minf(CARD_RADIUS, rect.size.y * .5)

static func _box(fill: Color, edge: Color, edge_width: float, radius: float) -> StyleBoxFlat:
	var s = StyleBoxFlat.new(); s.bg_color = fill; s.anti_aliasing = true
	s.set_corner_radius_all(roundi(radius)); s.corner_detail = 10
	if edge.a > 0.0 and edge_width > 0.0:
		s.border_color = edge; s.set_border_width_all(maxi(1, roundi(edge_width)))
	return s

# Kept name: a rounded shape (pill for small heights) fitted to rect.
static func slant_points(rect: Rect2, _shift: float = -1.0) -> PackedVector2Array:
	return PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])

static func draw_slant(canvas: CanvasItem, rect: Rect2, fill: Color, edge: Color = Color(0, 0, 0, 0), edge_width: float = 2.0, _shift: float = -1.0) -> void:
	if rect.size.x <= 1 or rect.size.y <= 1: return
	if fill.a <= 0.0 and (edge.a <= 0.0 or edge_width <= 0.0): return
	canvas.draw_style_box(_box(fill, edge, edge_width, radius_for(rect)), rect)

# Top-to-bottom two-colour fill: drawn as the bottom colour with a soft lit upper half.
static func draw_slant_gradient(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color, _shift: float = -1.0) -> void:
	if rect.size.x <= 1 or rect.size.y <= 1: return
	var r = radius_for(rect)
	canvas.draw_style_box(_box(bottom, Color(0, 0, 0, 0), 0, r), rect)
	var lift = Color(top, top.a * .55)
	if top != bottom:
		var upper = _box(lift, Color(0, 0, 0, 0), 0, r)
		upper.corner_radius_bottom_left = 0; upper.corner_radius_bottom_right = 0
		canvas.draw_style_box(upper, Rect2(rect.position, Vector2(rect.size.x, rect.size.y * .5)))

# A soft coloured shadow under a shape (no neon rings).
static func draw_glow(canvas: CanvasItem, rect: Rect2, color: Color, strength: float = 1.0, _shift: float = -1.0) -> void:
	if strength <= 0.0: return
	var s = _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, radius_for(rect))
	s.shadow_color = Color(color, .32 * strength); s.shadow_size = roundi(18 * strength); s.shadow_offset = Vector2(0, 6)
	canvas.draw_style_box(s, rect)

# Kept name: titles are now plain type, no chromatic ghosts.
static func draw_split_text(canvas: CanvasItem, font: Font, pos: Vector2, text: String, size: int, color: Color = TEXT, _split: float = 3.0, align := HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	canvas.draw_string(font, pos, text, align, width, size, color)

# Kept name: small labels are sentence case now, so this no longer letter-spaces.
static func spaced(text: String) -> String:
	return text

static func label_settings(size: int, color: Color = TEXT, heading: bool = true) -> LabelSettings:
	var s = LabelSettings.new(); s.font = HEAD if heading else mono(); s.font_size = size; s.font_color = color
	return s

# Rounded StyleBox for Godot's own controls (fields, popups).
static func slant_box(fill: Color, edge: Color, edge_width: int = 2, margin: float = 14.0) -> StyleBoxFlat:
	var s = _box(fill, edge, edge_width, 14)
	s.content_margin_left = margin + 4; s.content_margin_right = margin + 4
	s.content_margin_top = 8; s.content_margin_bottom = 8
	return s
