extends RefCounted
# SYNK's button look (Signal Arcade): slanted, note-shaped plates on dark ink.
# - primary: magenta plate with a neon halo, the one main step on a screen.
# - record:  hot red plate, starts or ends recording.
# - surface: deep navy plate with a cyan edge, every other action.
# - quiet:   flat navy chip for tools and tabs; turns solid cyan when selected.
# - danger:  navy plate with a red edge and red text.
# - ghost:   edge only, for moving between screens.
# Plates sink 2 px when pressed and brighten their edge on hover.
const Arcade = preload("res://scripts/arcade_style.gd")
const BOLD = preload("res://assets/fonts/ChakraPetch-Bold.ttf")
# Kept names: other scripts read these for text on and around plates.
const CREAM = Color("3ff2ff")       # the "selected" fill (now cyan)
const CREAM_EDGE = Color("9ff8ff")
const INK = Color("07070f")
const TOMATO = Color("ff3d5a")
const GRAPHITE = Color("0d1630")
const GRAPHITE_LOW = Color("0f1530")
const CORAL = Color("ff5f6d")
const TEXT = Color("e9ecff")
const MUTED = Color("5c6494")

# Maps the older button roles onto this look.
static func role_for(variant: String, primary: bool = false) -> String:
	if primary: return "primary"
	match variant:
		"primary": return "primary"
		"record": return "record"
		"danger": return "danger"
		"nav": return "ghost"
		"tool", "track": return "quiet"
	return "surface"

# Kept for callers that size icons from it; plates are slanted, not rounded.
static func radius_for(size: Vector2) -> float:
	return 0.0

# Text colour on top of the plate drawn by draw_plate with the same arguments.
static func text_color(role: String, selected: float = 0.0, disabled: bool = false, node: Node = null) -> Color:
	if not is_arcade(node): return classic_text_color(role, selected, disabled)
	if disabled: return MUTED
	var base = TEXT
	match role:
		"primary", "record": base = Color.WHITE
		"danger": base = CORAL
		"ghost": base = Arcade.CYAN
	return base.lerp(INK, selected) if role in ["quiet", "surface", "ghost"] else base

static func draw_plate(canvas: CanvasItem, size: Vector2, role: String, hover: float = 0.0, press: float = 0.0, selected: float = 0.0, disabled: bool = false, radius: float = -1.0) -> void:
	_last_arcade = is_arcade(canvas)
	if not _last_arcade:
		draw_plate_classic(canvas, size, role, hover, press, selected, disabled, radius); return
	if size.x <= 2 or size.y <= 2: return
	var sink = 2.0 * press
	var rect = Rect2(Vector2(3, 3 + sink), size - Vector2(6, 8))
	var shift = Arcade.shift_for(rect.size.y) * (.55 if rect.size.y > 90.0 else 1.0)
	var top = GRAPHITE; var bottom = GRAPHITE_LOW
	var edge = Color(Arcade.CYAN, .55); var edge_width = 2.0; var glow = 0.0; var glow_color = Arcade.CYAN
	match role:
		"primary":
			top = Arcade.MAGENTA; bottom = Arcade.MAGENTA_DEEP; edge = Color(1, .75, .9, .9); glow = .9; glow_color = Arcade.MAGENTA
		"record":
			top = TOMATO; bottom = Color("a3102c"); edge = Color(1, .7, .75, .85); glow = .7; glow_color = TOMATO
		"quiet":
			top = Arcade.PANEL_HIGH; bottom = Arcade.PANEL_HIGH; edge = Color(Arcade.CYAN, .0); edge_width = 0.0
		"danger":
			edge = Color(CORAL, .75)
		"ghost":
			top = Color(Arcade.INK, .55); bottom = Color(Arcade.INK, .55); edge = Color(Arcade.CYAN, .7)
	if selected > 0.0 and role in ["quiet", "surface", "ghost"]:
		top = top.lerp(Arcade.CYAN, selected); bottom = bottom.lerp(Color("19b8c8"), selected)
		edge = edge.lerp(CREAM_EDGE, selected); edge_width = maxf(edge_width, 2.0); glow = maxf(glow, .5 * selected)
	if disabled:
		top = Color(GRAPHITE_LOW, .7); bottom = top; edge = Color(1, 1, 1, .08); edge_width = 1.0; glow = 0.0
	elif hover > 0.0:
		top = top.lightened(.08 * hover); edge = edge.lerp(Color.WHITE, .35 * hover)
		glow = maxf(glow, .35 * hover); edge_width = maxf(edge_width, 2.0 * hover)
	if glow > 0.0: Arcade.draw_glow(canvas, rect, glow_color, glow * (1.0 - .4 * press), shift)
	# A dark slab offset below gives the plate weight; it shrinks while pressed.
	if not disabled and role != "ghost":
		Arcade.draw_slant(canvas, Rect2(rect.position + Vector2(0, lerpf(4.0, 1.5, press)), rect.size), Color(0, 0, 0, .45), Color(0, 0, 0, 0), 0.0, shift)
	Arcade.draw_slant_gradient(canvas, rect, top, bottom, shift)
	# Light catches the top edge.
	if not disabled and role in ["primary", "record", "surface", "danger"]:
		canvas.draw_line(rect.position + Vector2(shift + 2, 1), rect.position + Vector2(rect.size.x - 2, 1), Color(1, 1, 1, .28), 1.0, true)
	if edge_width > 0.0: Arcade.draw_slant(canvas, rect, Color(0, 0, 0, 0), edge, edge_width, shift)

# --- Classic look, kept for gameplay (HUD, pause) outside the Signal Arcade screens ---
const C_BOLD = preload("res://assets/fonts/FiraSans-Bold.ttf")
const C_CREAM = Color("f3ece1")
const C_CREAM_EDGE = Color("d9cdbb")
const C_INK = Color("1a1720")
const C_TOMATO = Color("e2543f")
const C_GRAPHITE = Color("2a2830")
const C_GRAPHITE_LOW = Color("1d1c22")
const C_CORAL = Color("ff8b7b")
const C_TEXT = Color("f2efe9")
const C_MUTED = Color("6d6a73")
static var _last_arcade = true

# True when node sits inside a screen that uses the Signal Arcade theme.
static func is_arcade(node: Node) -> bool:
	if node == null: return _last_arcade
	if node.has_meta("arcade_ui"): return bool(node.get_meta("arcade_ui"))
	if not node.is_inside_tree(): return true
	var arcade_theme = preload("res://scripts/game_theme.gd").arcade()
	var n = node; var found = false
	while n:
		if n is Control and n.theme == arcade_theme:
			found = true; break
		n = n.get_parent()
	node.set_meta("arcade_ui", found)
	return found

static func font_for(node: Node) -> Font:
	return BOLD if is_arcade(node) else C_BOLD

static func classic_radius(size: Vector2) -> float:
	return size.y * .5 if size.y <= 64.0 else minf(26.0, minf(size.x, size.y) * .22)

static func classic_text_color(role: String, selected: float = 0.0, disabled: bool = false) -> Color:
	if disabled: return C_MUTED
	var base = C_TEXT
	match role:
		"primary": base = C_INK
		"danger": base = C_CORAL
		"ghost": base = Color("e6e1d8")
	return base.lerp(C_INK, selected) if role in ["quiet", "surface", "ghost"] else base

static func draw_plate_classic(canvas: CanvasItem, size: Vector2, role: String, hover: float = 0.0, press: float = 0.0, selected: float = 0.0, disabled: bool = false, radius: float = -1.0) -> void:
	if size.x <= 2 or size.y <= 2: return
	var r = radius if radius >= 0 else classic_radius(size)
	var sink = 2.0 * press
	var rect = Rect2(Vector2(2, 1 + sink), size - Vector2(4, 5))
	var body = C_GRAPHITE; var edge = Color(1, 1, 1, .06); var shine = .09; var lift = 1.0
	match role:
		"primary": body = C_CREAM; edge = C_CREAM_EDGE; shine = .55
		"record": body = C_TOMATO; edge = C_TOMATO.darkened(.25); shine = .28
		"quiet": body = C_GRAPHITE_LOW; lift = .45
		"danger": edge = Color(C_CORAL, .35)
		"ghost": body = Color(0, 0, 0, 0); edge = Color(1, 1, 1, .16); lift = 0.0; shine = 0.0
	if selected > 0.0 and role in ["quiet", "surface", "ghost"]:
		body = body.lerp(C_CREAM, selected); edge = edge.lerp(C_CREAM_EDGE, selected); shine = lerpf(shine, .55, selected); lift = maxf(lift, selected)
	if disabled:
		body = C_GRAPHITE_LOW if role != "ghost" else body; edge = Color(1, 1, 1, .05); shine = 0.0; lift = 0.0
	elif hover > 0.0:
		body = body.lightened(.06 * hover) if role != "ghost" else Color(1, 1, 1, .05 * hover)
	# Soft shadow under the plate, smaller while pressed.
	if lift > 0.0:
		var shadow = StyleBoxFlat.new(); shadow.set_corner_radius_all(roundi(r)); shadow.bg_color = Color(0, 0, 0, 0)
		shadow.shadow_color = Color(0, 0, 0, .38 * lift * (1.0 - .5 * press)); shadow.shadow_size = roundi(lerpf(10.0, 4.0, press))
		shadow.shadow_offset = Vector2(0, lerpf(5.0, 2.0, press))
		canvas.draw_style_box(shadow, rect)
	var plate = StyleBoxFlat.new(); plate.set_corner_radius_all(roundi(r)); plate.bg_color = body
	plate.set_border_width_all(1); plate.border_color = edge; plate.anti_aliasing = true
	canvas.draw_style_box(plate, rect)
	if shine > 0.0:
		# Light falls from above: a faint lit upper half and a crisp top edge.
		var upper = StyleBoxFlat.new(); upper.bg_color = Color(1, 1, 1, shine * .12)
		upper.corner_radius_top_left = roundi(r); upper.corner_radius_top_right = roundi(r)
		canvas.draw_style_box(upper, Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, rect.size.y * .5)))
		var rim = StyleBoxFlat.new(); rim.set_corner_radius_all(roundi(r)); rim.bg_color = Color(0, 0, 0, 0)
		rim.border_width_top = 1; rim.border_color = Color(1, 1, 1, shine * .5)
		canvas.draw_style_box(rim, rect.grow(-1))
