extends RefCounted
# SYNK's button look: soft, tactile plates instead of glowing outlines.
# - primary: warm cream plate with dark text, the one main step on a screen.
# - record:  solid tomato plate, starts or ends recording.
# - surface: raised graphite plate, every other action.
# - quiet:   flat graphite chip for tools and tabs; turns cream when selected.
# - danger:  graphite plate with coral text and edge.
# - ghost:   outline only, for moving between screens.
# Every plate has a soft drop shadow and a thin top highlight, and sinks 2 px when pressed.
const BOLD = preload("res://assets/fonts/FiraSans-Bold.ttf")
const CREAM = Color("f3ece1")
const CREAM_EDGE = Color("d9cdbb")
const INK = Color("1a1720")
const TOMATO = Color("e2543f")
const GRAPHITE = Color("2a2830")
const GRAPHITE_LOW = Color("1d1c22")
const CORAL = Color("ff8b7b")
const TEXT = Color("f2efe9")
const MUTED = Color("6d6a73")

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

static func radius_for(size: Vector2) -> float:
	# Short buttons are pills; tall tiles keep a generous rounded corner.
	return size.y * .5 if size.y <= 64.0 else minf(26.0, minf(size.x, size.y) * .22)

# Text colour on top of the plate drawn by draw_plate with the same arguments.
static func text_color(role: String, selected: float = 0.0, disabled: bool = false) -> Color:
	if disabled: return MUTED
	var base = TEXT
	match role:
		"primary": base = INK
		"danger": base = CORAL
		"ghost": base = Color("e6e1d8")
	return base.lerp(INK, selected) if role in ["quiet", "surface", "ghost"] else base

static func draw_plate(canvas: CanvasItem, size: Vector2, role: String, hover: float = 0.0, press: float = 0.0, selected: float = 0.0, disabled: bool = false, radius: float = -1.0) -> void:
	if size.x <= 2 or size.y <= 2: return
	var r = radius if radius >= 0 else radius_for(size)
	var sink = 2.0 * press
	var rect = Rect2(Vector2(2, 1 + sink), size - Vector2(4, 5))
	var body = GRAPHITE; var edge = Color(1, 1, 1, .06); var shine = .09; var lift = 1.0
	match role:
		"primary": body = CREAM; edge = CREAM_EDGE; shine = .55
		"record": body = TOMATO; edge = TOMATO.darkened(.25); shine = .28
		"quiet": body = GRAPHITE_LOW; lift = .45
		"danger": edge = Color(CORAL, .35)
		"ghost": body = Color(0, 0, 0, 0); edge = Color(1, 1, 1, .16); lift = 0.0; shine = 0.0
	if selected > 0.0 and role in ["quiet", "surface", "ghost"]:
		body = body.lerp(CREAM, selected); edge = edge.lerp(CREAM_EDGE, selected); shine = lerpf(shine, .55, selected); lift = maxf(lift, selected)
	if disabled:
		body = GRAPHITE_LOW if role != "ghost" else body; edge = Color(1, 1, 1, .05); shine = 0.0; lift = 0.0
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
