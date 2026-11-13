extends Node3D





const SAMPLE_RATE = 40.0
const ROW = 1024
var world: Node3D
var grid: MeshInstance3D
var grid_material: ShaderMaterial
var lane: MeshInstance3D
var lane_material: ShaderMaterial
var peaks: PackedFloat32Array = []
var built = 0
var playback: AudioStreamPlayback
var stream: AudioStream
var peaks_image: Image
var peaks_texture: ImageTexture

func _ready() -> void :
	var length = world.TRACK_LENGTH
	var grid_mesh = PlaneMesh.new();grid_mesh.size = Vector2(world.HIGHWAY_HALF_WIDTH * 2.0, length)
	grid_material = ShaderMaterial.new();grid_material.shader = preload("res://scripts/record_beat_grid.gdshader");grid_material.render_priority = -2
	grid = world.mesh_node(grid_mesh, self, grid_material);grid.position = Vector3(0, 0.03, - length * 0.5)
	var lane_mesh = PlaneMesh.new();lane_mesh.size = Vector2(2.2, length)
	lane_material = ShaderMaterial.new();lane_material.shader = preload("res://scripts/record_waveform.gdshader")
	lane = world.mesh_node(lane_mesh, self, lane_material)

	lane.position = Vector3(world.FRAME_HALF_WIDTH + world.RAIL_WIDTH + 1.4, 0.03, - length * 0.5)
	lane_material.set_shader_parameter("sample_rate", SAMPLE_RATE)
	visible = false

# The SKD highway bends depth (p^6), so the grid and waveform need many rows to follow it.
# The grid spans the 13 lanes; the waveform is a thin strip just outside the right lane.
var laid_out_skd = false
func layout(skd: bool) -> void:
	laid_out_skd = skd
	var length = world.TRACK_LENGTH
	var grid_mesh: PlaneMesh = grid.mesh; var lane_mesh: PlaneMesh = lane.mesh
	grid_mesh.subdivide_depth = 240 if skd else 0; lane_mesh.subdivide_depth = 240 if skd else 0
	if skd:
		var step = absf(world.note_x(1.0) - world.note_x(0.0))
		var edge = absf(world.note_x(float(SynkChart.MAX_LANE))) + step * .5
		grid_mesh.size = Vector2(edge * 2.0, length)
		lane_mesh.size = Vector2(step * .6, length)
		lane.position.x = edge + step * .7
	else:
		grid_mesh.size = Vector2(world.HIGHWAY_HALF_WIDTH * 2.0, length)
		lane_mesh.size = Vector2(2.2, length)
		lane.position.x = world.FRAME_HALF_WIDTH + world.RAIL_WIDTH + 1.4
	# The SKD stage floor draws over priority -2; keep the grid above it, under the notes (3).
	grid_material.render_priority = 1 if skd else -2
	# Calm theme colours on SKD: cream beats, soft coral bars, a quiet grey-cream waveform.
	grid_material.set_shader_parameter("beat_color", Color(.957,.945,.918,.28) if skd else Color(0.62,0.78,1.0,0.22))
	grid_material.set_shader_parameter("bar_color", Color(1.0,.541,.357,.6) if skd else Color(1.0,0.85,0.45,0.55))
	lane_material.set_shader_parameter("tint", Color(.5,.49,.47) if skd else Color(0.42,0.85,1.0))
	lane_material.render_priority = 1 if skd else 0
	for node in [grid, lane]: node.extra_cull_margin = world.TRACK_LENGTH + world.SSRG_STAGE_DISTANCE if skd else 0.0

func recording() -> bool:
	var game = world.game
	return game.mode == "record" or (game.mode == "paused" and game.paused_mode == "record")


func prepare(song_stream: AudioStream) -> void :
	if song_stream == stream: return
	stream = song_stream;built = 0;peaks = PackedFloat32Array()
	if stream == null: return
	peaks.resize(maxi(1, ceili(stream.get_length() * SAMPLE_RATE)))
	playback = stream.instantiate_playback();playback.start()


	var rows = maxi(1, ceili(peaks.size() / float(ROW)))
	peaks_image = Image.create(ROW, rows, false, Image.FORMAT_L8)
	peaks_texture = ImageTexture.create_from_image(peaks_image)
	lane_material.set_shader_parameter("peaks", peaks_texture)
	lane_material.set_shader_parameter("sample_count", float(peaks.size()))

func build_some() -> void :
	if playback == null or built >= peaks.size(): return


	var window = maxi(1, int(AudioServer.get_mix_rate() / SAMPLE_RATE))
	var deadline = Time.get_ticks_usec() + 2000
	var stop = built
	while stop < peaks.size() and Time.get_ticks_usec() < deadline:
		var peak = 0.0
		for frame in playback.mix_audio(1.0, window): peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		peaks[stop] = peak
		stop += 1
	if stop == built: return

	for i in range(built, stop):
		var v = clampf(sqrt(peaks[i]) * 1.15, 0.0, 1.0)
		peaks_image.set_pixel(i % ROW, i / ROW, Color(v, v, v))
	built = stop
	peaks_texture.update(peaks_image)
	if built >= peaks.size(): playback.stop()

func _process(_delta: float) -> void :
	var game = world.game

	visible = recording() and bool(game.get("record_aids_enabled"))
	if not visible: return
	prepare(game.audio.stream)
	build_some()
	var skd = world.uses_projected_highway()
	if skd != laid_out_skd: layout(skd)
	var now = world.render_time(); var speed = world.travel_speed()
	for m in [grid_material, lane_material]:
		m.set_shader_parameter("now", now);m.set_shader_parameter("speed", speed)
		m.set_shader_parameter("flow_up", skd)
	grid_material.set_shader_parameter("bpm", maxf(1.0, float(game.chart_bpm())))
	grid_material.set_shader_parameter("offset", float(game.chart_offset()))
