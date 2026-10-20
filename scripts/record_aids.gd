extends Node3D
# Recorder aids drawn on the highway while recording (highway_3d.gd adds one):
#  - beat grid: lines across the track on every beat, brighter on each bar
#  - waveform lane: the song's loudness scrolling just outside the left rail
# The detailed waveform (40 samples per second) is built a little each frame, so starting a
# take never stalls.
const SAMPLE_RATE = 40.0
const BUILD_PER_FRAME = 120
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

func _ready() -> void:
	var length = world.TRACK_LENGTH
	var grid_mesh = PlaneMesh.new(); grid_mesh.size = Vector2(world.HIGHWAY_HALF_WIDTH * 2.0, length)
	grid_material = ShaderMaterial.new(); grid_material.shader = preload("res://scripts/record_beat_grid.gdshader"); grid_material.render_priority = -2
	grid = world.mesh_node(grid_mesh, self, grid_material); grid.position = Vector3(0, .03, -length * .5)
	var lane_mesh = PlaneMesh.new(); lane_mesh.size = Vector2(2.2, length)
	lane_material = ShaderMaterial.new(); lane_material.shader = preload("res://scripts/record_waveform.gdshader")
	lane = world.mesh_node(lane_mesh, self, lane_material)
	# Right of the highway: the recorder's aid buttons cover the left side.
	lane.position = Vector3(world.FRAME_HALF_WIDTH + world.RAIL_WIDTH + 1.4, .03, -length * .5)
	lane_material.set_shader_parameter("sample_rate", SAMPLE_RATE)
	visible = false

func recording() -> bool:
	var game = world.game
	return game.mode == "record" or (game.mode == "paused" and game.paused_mode == "record")

# Restart the detailed waveform when the song changes.
func prepare(song_stream: AudioStream) -> void:
	if song_stream == stream: return
	stream = song_stream; built = 0; peaks = PackedFloat32Array()
	if stream == null: return
	peaks.resize(maxi(1, ceili(stream.get_length() * SAMPLE_RATE)))
	playback = stream.instantiate_playback(); playback.start()
	# Plain 8-bit grid, at most 1024 wide: phones cap texture width (often 4096) and many lack
	# filterable float textures, so a long single-row float strip could fail to load.
	var rows = maxi(1, ceili(peaks.size() / float(ROW)))
	peaks_image = Image.create(ROW, rows, false, Image.FORMAT_L8)
	peaks_texture = ImageTexture.create_from_image(peaks_image)
	lane_material.set_shader_parameter("peaks", peaks_texture)
	lane_material.set_shader_parameter("sample_count", float(peaks.size()))

func build_some() -> void:
	if playback == null or built >= peaks.size(): return
	var stop = mini(peaks.size(), built + BUILD_PER_FRAME)
	var window = int(44100.0 / SAMPLE_RATE)
	for i in range(built, stop):
		playback.seek(i / SAMPLE_RATE)
		var peak = 0.0
		for frame in playback.mix_audio(1.0, mini(window, 512)): peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		peaks[i] = peak
	# Fixed curve (not relative to the loudest part) so early and late parts read the same.
	for i in range(built, stop):
		var v = clampf(sqrt(peaks[i]) * 1.15, 0.0, 1.0)
		peaks_image.set_pixel(i % ROW, i / ROW, Color(v, v, v))
	built = stop
	peaks_texture.update(peaks_image)
	if built >= peaks.size(): playback.stop()

func _process(_delta: float) -> void:
	var game = world.game
	visible = recording()
	if not visible: return
	prepare(game.audio.stream)
	build_some()
	var now = world.render_time(); var speed = world.travel_speed()
	for m in [grid_material, lane_material]:
		m.set_shader_parameter("now", now); m.set_shader_parameter("speed", speed)
	grid_material.set_shader_parameter("bpm", maxf(1.0, float(game.chart_bpm())))
	grid_material.set_shader_parameter("offset", float(game.chart_offset()))
