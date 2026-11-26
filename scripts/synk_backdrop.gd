extends Node
# SYNK mode's stage: the Aura backdrop (synk_stage_aura.gdshader), drawn on the
# screen-filling quad behind the highway in place of the song artwork and SSRG's stage
# effects. Silk ribbons of amber light and an amber glow in the bottom corners, on black;
# they move with the music and grow brighter the longer the combo.
const SHADER = preload("res://scripts/synk_stage_aura.gdshader")
var world: Node3D
var material: ShaderMaterial
var energy = 0.0

func update(on: bool, delta: float) -> void:
	var backdrop: MeshInstance3D = world.cover_backdrop
	if backdrop == null: return
	if not on:
		if material != null and backdrop.material_override == material: backdrop.material_override = world.cover_material
		return
	var game = world.game
	if material == null:
		material = ShaderMaterial.new(); material.shader = SHADER; material.render_priority = -20
	if backdrop.material_override != material: backdrop.material_override = material
	backdrop.visible = true
	var view: Vector2 = world.get_viewport().get_visible_rect().size
	if view.y <= 0: return
	# The highway's far end on screen: the stage is built around it.
	var vanish: Vector2 = world.camera.unproject_position(Vector3(0, 0, -492.0 * world.SSRG_UNIT)) / view
	var beats = (world.render_time() - game.chart_offset()) * game.chart_bpm() / 60.0
	# Energy: SYNK mode has no rave, so the stage builds with the combo and drops on a miss.
	var target = clampf(float(game.combo) / 120.0, 0.0, 1.0)
	energy = lerpf(energy, target, 1.0 - exp(-delta * 3.0))
	material.set_shader_parameter("vanish", vanish)
	# The rails' lines on screen, so the stage never draws under the highway between them.
	for side in [-1, 1]:
		var far: Vector2 = world.camera.unproject_position(Vector3(side * 27.0 * world.SSRG_UNIT, 0, -492.0 * world.SSRG_UNIT)) / view
		var near: Vector2 = world.camera.unproject_position(Vector3(side * 607.5 * world.SSRG_UNIT, 0, 86.0 * world.SSRG_UNIT)) / view
		material.set_shader_parameter("road_left" if side < 0 else "road_right", Vector4(far.x, far.y, near.x, near.y))
	material.set_shader_parameter("aspect", view.x / view.y)
	material.set_shader_parameter("beat", fposmod(beats, 1.0))
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("tone", world.synk_tone("stage"))
	material.set_shader_parameter("bass", world.loudness)
	material.set_shader_parameter("mids", world.loudness_mids)
	material.set_shader_parameter("brightness", game.features.effect("Background brightness"))
