extends RefCounted
# Signal Arcade: SYNK's menu look. Dark ink, a cyan and a magenta signal, slanted
# note-shaped plates, a perspective lane grid and scanlines. Gameplay and the
# loading screen keep their own look; everything else draws through here.

const INK = Color("07070f")
const NIGHT = Color("0b0b1a")
const PANEL = Color("0d1630")
const PANEL_LOW = Color("0f1530")
const PANEL_HIGH = Color("141c3a")
const LINE = Color("2a3260")
const CYAN = Color("3ff2ff")
const MAGENTA = Color("ff3d9a")
const MAGENTA_DEEP = Color("b0156a")
const VIOLET = Color("2b0f47")
const TEXT = Color("e9ecff")
const SUBTLE = Color("c7cdf2")
const MUTED = Color("9aa3d8")
const DIM = Color("5c6494")
const DANGER = Color("ff5f6d")
const GOLD = Color("ffd36a")

# Slant of every plate: x shift per pixel of height (about 14 degrees).
const SLANT = .25
const MAX_SHIFT = 22.0

const HEAD = preload("res://assets/fonts/ChakraPetch-Bold.ttf")
const HEAD_SEMI = preload("res://assets/fonts/ChakraPetch-SemiBold.ttf")
const MONO_FILE = preload("res://assets/fonts/JetBrainsMono-Variable.ttf")

static var _mono: FontVariation
static var _mono_bold: FontVariation
static func mono() -> Font:
	if _mono == null:
		_mono = FontVariation.new(); _mono.base_font = MONO_FILE
		_mono.variation_opentype = {"wght": 500}
	return _mono
static func mono_bold() -> Font:
	if _mono_bold == null:
		_mono_bold = FontVariation.new(); _mono_bold.base_font = MONO_FILE
		_mono_bold.variation_opentype = {"wght": 700}
	return _mono_bold

# Horizontal shift between the top and bottom edge of a slanted plate.
static func shift_for(height: float) -> float:
	return minf(height * SLANT, MAX_SHIFT)

# A parallelogram leaning right, fitted inside rect.
static func slant_points(rect: Rect2, shift: float = -1.0) -> PackedVector2Array:
	var s = shift if shift >= 0.0 else shift_for(rect.size.y)
	s = minf(s, rect.size.x * .4)
	return PackedVector2Array([
		rect.position + Vector2(s, 0), rect.position + Vector2(rect.size.x, 0),
		rect.position + Vector2(rect.size.x - s, rect.size.y), rect.position + Vector2(0, rect.size.y)])

static func draw_slant(canvas: CanvasItem, rect: Rect2, fill: Color, edge: Color = Color(0, 0, 0, 0), edge_width: float = 2.0, shift: float = -1.0) -> void:
	if rect.size.x <= 1 or rect.size.y <= 1: return
	var points = slant_points(rect, shift)
	if fill.a > 0.0: canvas.draw_colored_polygon(points, fill)
	if edge.a > 0.0 and edge_width > 0.0:
		var loop = points.duplicate(); loop.append(points[0])
		canvas.draw_polyline(loop, edge, edge_width, true)

# Vertical two-colour fill inside the slant.
static func draw_slant_gradient(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color, shift: float = -1.0) -> void:
	if rect.size.x <= 1 or rect.size.y <= 1: return
	var points = slant_points(rect, shift)
	canvas.draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))

# Soft neon halo around a slanted plate.
static func draw_glow(canvas: CanvasItem, rect: Rect2, color: Color, strength: float = 1.0, shift: float = -1.0) -> void:
	if strength <= 0.0: return
	for i in 4:
		var grow = 3.0 + i * 4.0
		var c = Color(color, .12 * strength * (1.0 - i * .22))
		draw_slant(canvas, rect.grow(grow), Color(0, 0, 0, 0), c, 4.0, shift)

# Chromatic split title: magenta and cyan ghosts behind white type.
static func draw_split_text(canvas: CanvasItem, font: Font, pos: Vector2, text: String, size: int, color: Color = TEXT, split: float = 3.0, align := HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	canvas.draw_string(font, pos + Vector2(split, 0), text, align, width, size, Color(MAGENTA, .9))
	canvas.draw_string(font, pos - Vector2(split, 0), text, align, width, size, Color(CYAN, .9))
	canvas.draw_string(font, pos, text, align, width, size, color)

# Small all-caps label with letter spacing, in the mono face.
static func spaced(text: String) -> String:
	var out = ""
	for i in text.length():
		out += text[i]
		if i < text.length() - 1 and text[i] != " ": out += " "
	return out

static func label_settings(size: int, color: Color = TEXT, heading: bool = true) -> LabelSettings:
	var s = LabelSettings.new(); s.font = HEAD if heading else mono(); s.font_size = size; s.font_color = color
	return s

# Flat slanted StyleBox for Godot controls (LineEdit, popups): a StyleBoxFlat with
# skew so built-in controls match the drawn plates.
static func slant_box(fill: Color, edge: Color, edge_width: int = 2, margin: float = 14.0) -> StyleBoxFlat:
	var s = StyleBoxFlat.new(); s.bg_color = fill; s.border_color = edge; s.set_border_width_all(edge_width)
	s.skew = Vector2(-SLANT * .6, 0); s.anti_aliasing = true
	s.content_margin_left = margin + 6; s.content_margin_right = margin + 6
	s.content_margin_top = 8; s.content_margin_bottom = 8
	return s
