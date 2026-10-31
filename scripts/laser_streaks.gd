extends Node3D
# Laser streaks (the "Lasers" stage effect), moving the way SSRG's background lasers do: they
# start beside the far end of the highway and fly outward toward the player, fanning away from
# the vanishing point. On the SSRG highway its own background lasers (ssrg_background.gd) are
# shown instead, so these stay hidden there.
var world: Node3D
var streaks: Array[CPUParticles3D] = []

func build(target: Node3D) -> void:
	world = target; name = "LaserStreaks"
	# Pale, nearly white streaks like SSRG's; the Colors tab's laser colour tints them.
	var palette = Gradient.new(); palette.set_color(0,Color("dfe4ff")); palette.set_color(1,Color("ffffff"))
	palette.add_point(.5,Color("c9d6ff"))
	# Hidden while still near the far end (over the highway), brightest mid-flight, gone before the camera.
	var life = Gradient.new(); life.set_color(0,Color(1,1,1,0)); life.set_color(1,Color(1,1,1,0))
	life.add_point(.2,Color(1,1,1,0)); life.add_point(.38,Color(1,1,1,.75)); life.add_point(.75,Color(1,1,1,.5))
	for side in [-1,1]:
		var emitter = CPUParticles3D.new(); add_child(emitter)
		var mesh = BoxMesh.new(); mesh.material = streak_material(); emitter.mesh = mesh
		# The long axis is Y, turned along each streak's own flight direction.
		mesh.size = Vector3(.06,4.5,.06); emitter.particle_flag_align_y = true
		emitter.amount = 26
		# Every streak leaves from the far centre of the highway, so on screen each one runs
		# along a ray from its vanishing point, fanning out wider than the rails.
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
		emitter.position = Vector3(0,.6,-world.TRACK_LENGTH)
		emitter.direction = Vector3(side*.62,.05,1).normalized(); emitter.spread = 13
		emitter.gravity = Vector3.ZERO
		emitter.initial_velocity_min = 55; emitter.initial_velocity_max = 85
		emitter.lifetime = 1.3; emitter.preprocess = 1.3
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

func update() -> void:
	var game = world.game
	var lasers = game.features.effect("Lasers")
	var stage = game.mode=="play" or (game.mode=="paused" and game.paused_mode=="play") or game.highway_preview
	var show = stage and lasers>0 and not game.uses_recorder_colors() and not game.uses_ssrg_gameplay()
	var running = game.mode=="play" or game.highway_preview
	for emitter in streaks:
		emitter.visible = show
		emitter.speed_scale = game.note_speed if running else 0.0
		emitter.color = Color(world.element_color("lasers",Color.WHITE),lasers)
