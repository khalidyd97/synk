extends Control

# Animated stage lights for the home screen: laser beams fanning in from the top corners
# (cyan on the left, magenta on the right) and sparkles drifting up through the beams.
const CYAN = Color("38e8ff")
const MAGENTA = Color("ff3ce0")
const SPARKS = 70

var time = 0.0
var sparks: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive = CanvasItemMaterial.new(); additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	var random = RandomNumberGenerator.new(); random.seed = 11
	for i in SPARKS:
		var left = i % 2 == 0
		sparks.append({"x":random.randf_range(0.0,.42) if left else random.randf_range(.58,1.0),"y":random.randf(),
			"speed":random.randf_range(.015,.05),"size":random.randf_range(1.2,3.6),"phase":random.randf()*TAU,
			"color":CYAN if left else MAGENTA})

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta
	for spark in sparks:
		spark.y -= spark.speed*delta
		if spark.y < -.05: spark.y = 1.05
	queue_redraw()

func beam(origin: Vector2, angle: float, length: float, color: Color, width: float) -> void:
	# A tapered streak that is brightest where it enters the screen and fades out before reaching
	# the middle, so it frames the buttons instead of crossing them.
	var direction = Vector2(cos(angle),sin(angle)); var side = direction.orthogonal()
	var tip = origin+direction*length
	for layer in [[width*8.0,.07],[width*3.0,.18],[width,.8],[width*.35,.6]]:
		var half = float(layer[0])*.5; var strength = float(layer[1])
		var core = Color(1,1,1,strength) if layer[0] == width*.35 else Color(color,strength)
		draw_polygon(PackedVector2Array([origin-side*half,origin+side*half,tip+side*half*.3,tip-side*half*.3]),
			PackedColorArray([core,core,Color(core,0),Color(core,0)]))

func _draw() -> void:
	var length = size.length()
	# Beams fan in from the left and right edges, each sweeping slowly on its own rhythm.
	var reach = size.x*.36
	for i in 4:
		var sway = sin(time*(.35+i*.11)+i*1.7)*.05
		var y = size.y*(.1+i*.17)
		var tilt = -.32+i*.2+sway
		beam(Vector2(-size.x*.01,y),tilt,reach*(1.0-i*.12),CYAN,2.6-i*.4)
		beam(Vector2(size.x*1.01,y),PI-tilt,reach*(1.0-i*.12),MAGENTA,2.6-i*.4)
	# Bright flares where the beams enter the screen.
	for side in [0.0,1.0]:
		var flare = Vector2(size.x*side,size.y*.12)
		var color = CYAN if side == 0.0 else MAGENTA
		for k in 4: draw_circle(flare,size.y*(.09-k*.02),Color(color,.05+k*.04))
	for spark in sparks:
		var twinkle = .45+.55*sin(time*3.0+spark.phase)
		var point = Vector2(spark.x*size.x,spark.y*size.y)
		draw_circle(point,spark.size*2.2,Color(spark.color,.12*twinkle))
		draw_circle(point,spark.size,Color(spark.color.lightened(.4),.8*twinkle))
