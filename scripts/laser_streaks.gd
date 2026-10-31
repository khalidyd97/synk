extends Node3D
# Laser streaks: light streaks that shoot away along both sides of the highway (the "Lasers"
# stage effect). On the SYNK highway they run beside the rails; on the SSRG highway's flat
# canvas they run parallel to its slanted rails, toward the far end.
var world: Node3D
var streaks: Array[CPUParticles3D] = []
var ssrg_layout = -1

func build(target: Node3D) -> void:
	world = target; name = "LaserStreaks"
	var palette = Gradient.new(); palette.set_color(0,Color("a36aff")); palette.set_color(1,Color("38baff"))
	palette.add_point(.5,Color("ff7ad9"))
	var life = Gradient.new(); life.set_color(0,Color(1,1,1,0)); life.set_color(1,Color(1,1,1,0))
	life.add_point(.3,Color(1,1,1,.7)); life.add_point(.7,Color(1,1,1,.7))
	for side in [-1,1]:
		var emitter = CPUParticles3D.new(); add_child(emitter)
		var material = streak_material()
		var mesh = BoxMesh.new(); mesh.material = material; emitter.mesh = mesh
		emitter.amount = 22
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		emitter.direction = Vector3(0,0,-1); emitter.spread = 0
		# Streaks live in the emitter's space, so on the SSRG canvas they lie along its slanted rails.
		emitter.local_coords = true
		emitter.gravity = Vector3.ZERO
		emitter.color_initial_ramp = palette; emitter.color_ramp = life
		emitter.visible = false
		streaks.append(emitter)

# Additive, unshaded and coloured per particle; drawn before the highway so the track stays on top.
func streak_material() -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.vertex_color_use_as_albedo = true
	result.disable_receive_shadows = true; result.disable_fog = true
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.render_priority = -15
	return result

# Places the emitters for the current camera: beside the SYNK track, or along the SSRG rails.
func lay_out(ssrg: bool) -> void:
	ssrg_layout = 1 if ssrg else 0
	for i in 2:
		var side = -1 if i==0 else 1
		var emitter = streaks[i]
		if ssrg:
			# The SSRG rail runs from x 607.5 at the line (z 86) to x 27 at the far end (z -492).
			var unit = world.SSRG_UNIT
			var near = Vector2(side*607.5,86.0)*unit; var far = Vector2(side*27.0,-492.0)*unit
			var along = (far-near).normalized()
			var outward = Vector2(-along.y,along.x)*(1 if Vector2(-along.y,along.x).x*side>0 else -1)
			var center = (near+far)*.5+outward*2.2
			emitter.transform = Transform3D(Basis.looking_at(Vector3(along.x,0,along.y)),Vector3(center.x,1.2,center.y))
			(emitter.mesh as BoxMesh).size = Vector3(.05,.05,1.4)
			emitter.emission_box_extents = Vector3(1.6,.1,8.0)
			emitter.initial_velocity_min = 11; emitter.initial_velocity_max = 17
			emitter.lifetime = 1.4
		else:
			emitter.transform = Transform3D(Basis.IDENTITY,Vector3(side*17,1.2,8))
			(emitter.mesh as BoxMesh).size = Vector3(.07,.07,5.0)
			emitter.emission_box_extents = Vector3(5,2.2,30)
			emitter.initial_velocity_min = 32; emitter.initial_velocity_max = 51
			emitter.lifetime = 1.8
		emitter.preprocess = emitter.lifetime
		emitter.restart()

func update() -> void:
	var game = world.game
	var lasers = game.features.effect("Lasers")
	var stage = game.mode=="play" or (game.mode=="paused" and game.paused_mode=="play") or game.highway_preview
	var show = stage and lasers>0 and not game.uses_recorder_colors()
	if show and ssrg_layout != (1 if game.uses_ssrg_gameplay() else 0): lay_out(game.uses_ssrg_gameplay())
	var running = game.mode=="play" or game.highway_preview
	var speed = game.ssrg_note_speed() if game.ssrg_playable_run else game.note_speed
	for emitter in streaks:
		emitter.visible = show
		emitter.speed_scale = speed if running else 0.0
		emitter.color = Color(world.element_color("lasers",Color.WHITE),lasers)
