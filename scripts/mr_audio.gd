extends Node
# Local center-channel reduction. This is not AI stem separation.
const RATE=22050
var game: Control
var enabled=false
var original: AudioStream
var reduced: AudioStreamWAV
var worker=Thread.new()
var worker_source: AudioStream
var buttons: Array=[]
var unavailable=""
var cancel_mutex=Mutex.new()
var cancel_requested=false
var progress=0.0

func _ready() -> void:
	enabled=bool(game.prefs.get_value("editor","mr",false))
func set_source(stream: AudioStream) -> void:
	original=stream; reduced=null; unavailable=""
	if original is AudioStreamWAV and not original.stereo: unavailable="Mono audio cannot use stereo vocal reduction."
	if worker.is_started():
		cancel_mutex.lock(); cancel_requested=true; cancel_mutex.unlock()
	if enabled and not worker.is_started(): prepare()
	refresh_buttons()
func register_button(button: Button) -> void:
	buttons.append(button); refresh_buttons()
func authoring() -> bool:
	return game.mode in ["editor","record"] or (game.mode=="paused" and game.paused_mode=="record")
func toggle() -> void:
	enabled=not enabled
	game.prefs.set_value("editor","mr",enabled); game.prefs.save("user://preferences.cfg")
	if authoring() and enabled and reduced==null and unavailable.is_empty(): prepare()
	sync_mode(); refresh_buttons()
	if enabled: game.tell("MR reduces centered vocals and keeps low bass. Stereo songs work best; some vocals and instruments may remain or change.")
func suspend_background_render() -> void:
	if worker.is_started():
		cancel_mutex.lock(); cancel_requested=true; cancel_mutex.unlock()
func prepare() -> void:
	if not authoring(): return
	if original==null or worker.is_started(): return
	if original is AudioStreamWAV and not original.stereo:
		unavailable="Mono audio cannot use stereo vocal reduction."; refresh_buttons(); return
	worker_source=original; progress=0
	cancel_mutex.lock(); cancel_requested=false; cancel_mutex.unlock()
	var error=worker.start(render.bind(worker_source,float(AudioServer.get_mix_rate())))
	if error!=OK: unavailable="MR could not start on this device."; worker_source=null
func cancelled() -> bool:
	cancel_mutex.lock(); var result=cancel_requested; cancel_mutex.unlock(); return result
func render(source: AudioStream,mix_rate: float) -> Dictionary:
	var count=ceili(source.get_length()*RATE)
	if count<=0 or count>RATE*1200: return {"error":"This track is too long for MR."}
	var playback=source.instantiate_playback(); playback.start()
	var bytes=PackedByteArray(); bytes.resize(count*2)
	# Retain the centered low end so kick and bass remain useful for charting.
	var coefficient=1.0-exp(-TAU*160.0/RATE)
	var bass=0.0; var mid_energy=0.0; var side_energy=0.0; var written=0
	while written<count:
		if cancelled(): playback.stop(); return {"cancelled":true}
		var frames=playback.mix_audio(mix_rate/RATE,mini(2048,count-written))
		if frames.is_empty():
			# Decoder/resampler tails may finish a handful of frames early.
			if count-written<=256: break
			playback.stop(); return {"error":"MR could not decode this audio."}
		for frame in frames:
			var mid=(frame.x+frame.y)*.5; var side=(frame.x-frame.y)*.5
			bass+=coefficient*(mid-bass)
			mid_energy+=mid*mid; side_energy+=side*side
			var sample=clampf(side+bass,-1,1)
			bytes.encode_s16(written*2,roundi(sample*32767)); written+=1
		progress=float(written)/count
	playback.stop()
	if side_energy<maxf(.00001,mid_energy*.0001): return {"error":"This audio has no useful stereo separation. MR is unavailable."}
	return {"data":bytes}
func _process(_delta: float) -> void:
	if worker.is_started() and not worker.is_alive():
		var result: Dictionary=worker.wait_to_finish()
		if worker_source==original and not result.has("cancelled"):
			if result.has("error"): unavailable=result.error
			else:
				reduced=AudioStreamWAV.new(); reduced.format=AudioStreamWAV.FORMAT_16_BITS
				reduced.mix_rate=RATE; reduced.stereo=false; reduced.data=result.data
		worker_source=null
		if authoring() and enabled and reduced==null and unavailable.is_empty(): prepare()
		if not unavailable.is_empty() and authoring(): game.tell(unavailable+" Original audio is playing.")
	if authoring() and enabled and reduced==null and unavailable.is_empty() and not worker.is_started(): prepare()
	if authoring() and game.capture.gestures.is_empty(): sync_mode()
	refresh_buttons()
func sync_mode() -> void:
	if original==null: return
	var target: AudioStream=reduced if enabled and reduced!=null and authoring() else original
	if game.audio.stream==target: return
	var playing=game.audio.playing; var paused=game.audio.stream_paused
	var position=game.audio.get_playback_position(); var speed=game.audio.pitch_scale
	game.audio.stream=target; game.audio.pitch_scale=speed
	if playing: game.audio.play(position)
	game.audio.stream_paused=paused; game.visual_clock_ready=false
func refresh_buttons() -> void:
	var caption="MR OFF"
	if enabled:
		caption="MR ON" if reduced!=null else ("MR N/A" if not unavailable.is_empty() else "MR %d%%" % roundi(progress*100))
	for button in buttons:
		if not is_instance_valid(button): continue
		button.text=caption; button.set_selected(enabled and reduced!=null)
		button.tooltip_text=unavailable if not unavailable.is_empty() else "MR: reduce centered vocals for charting. Tap to toggle original audio."
func _exit_tree() -> void:
	if worker.is_started():
		cancel_mutex.lock(); cancel_requested=true; cancel_mutex.unlock()
		worker.wait_to_finish()
