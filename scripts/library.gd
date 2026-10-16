class_name SynkLibrary
extends RefCounted

var songs: Array = []
var message = ""
var root_path = "user://"

func _init(storage_path: String = "user://") -> void:
	root_path=storage_path
	DirAccess.make_dir_recursive_absolute(root_path.path_join("songs"))
	DirAccess.make_dir_recursive_absolute(root_path.path_join("charts"))
	if FileAccess.file_exists(root_path.path_join("songs/library.json")):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join("songs/library.json")))
		if data is Array:
			for s in data:
				if s is Dictionary and s.has("id") and s.has("title") and s.has("file") and str(s.file).get_file() == str(s.file) and str(s.id).length() == 64:
					songs.append(s)

static func decode(path: String) -> AudioStream:
	match path.get_extension().to_lower():
		"mp3": return AudioStreamMP3.load_from_file(path)
		"wav": return AudioStreamWAV.load_from_file(path)
		"ogg": return AudioStreamOggVorbis.load_from_file(path)
	return null

static func waveform_for_stream(stream: AudioStream) -> PackedFloat32Array:
	var playback=stream.instantiate_playback()
	var peaks=PackedFloat32Array(); peaks.resize(512)
	playback.start()
	for i in 512:
		playback.seek(i*stream.get_length()/512)
		var frames=playback.mix_audio(1.0,256)
		var peak=0.0
		for frame in frames: peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
		peaks[i]=peak
	playback.stop()
	return peaks

static func inspect_song(audio_path: String, chart_path: String, song_id: String, cover_file: String, analyze: bool = true) -> Dictionary:
	# Called by the background loader. Only plain data and an unbound stream cross to the UI thread.
	var stream=decode(audio_path)
	if stream==null: return {"error":"Audio is missing or unreadable. Import this song again."}
	var result={"stream":stream,"duration":stream.get_length()}
	if not analyze: return result
	result.waveform=waveform_for_stream(stream)
	result.has_chart=FileAccess.file_exists(chart_path)
	result.notes=[]
	if result.has_chart:
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(chart_path))
		var loaded: Variant=SynkChart.notes_from_file(data)
		if loaded!=null and data.get("song_id")==song_id:
			result.notes=loaded
		else: result.chart_error="Saved chart is invalid; the original file has been kept."
	result.note_count=result.notes.size()
	if FileAccess.file_exists(cover_file):
		var cover=Image.new()
		if cover.load(cover_file)==OK: result.cover=cover
	return result

static func atomic_write(path: String, data: Variant) -> Error:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t")); file.close()
	# Keep the previous successful file until the replacement is ready.
	if FileAccess.file_exists(path):
		var backup_error = DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK: return backup_error
	return DirAccess.rename_absolute(path + ".tmp", path)

func import_song(path: String) -> Dictionary:
	message = ""
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null: message = "Could not read this audio. Try choosing a local file in Downloads or Music."; return {}
	var header = file.get_buffer(16)
	var format = ""
	if header.size() >= 12 and header.slice(0, 4).get_string_from_ascii() == "RIFF" and header.slice(8, 12).get_string_from_ascii() == "WAVE": format = "wav"
	elif header.size() >= 4 and header.slice(0, 4).get_string_from_ascii() == "OggS": format = "ogg"
	elif header.size() >= 3 and header.slice(0, 3).get_string_from_ascii() == "ID3": format = "mp3"
	elif header.size() >= 2 and header[0] == 255 and (header[1] & 224) == 224: format = "mp3"
	if format.is_empty(): message = "Choose a standard MP3, WAV or OGG file."; return {}
	file.seek(0)
	var temporary = root_path.path_join("songs/importing_" + str(Time.get_ticks_usec()) + "." + format)
	var output = FileAccess.open(temporary, FileAccess.WRITE)
	if output == null: message = "Could not save audio on this device. Check storage."; return {}
	var hash_context = HashingContext.new(); hash_context.start(HashingContext.HASH_SHA256)
	var size = 0
	while not file.eof_reached():
		var chunk = file.get_buffer(65536)
		if chunk.is_empty(): break
		size += chunk.size()
		if size > 150 * 1024 * 1024:
			output.close(); DirAccess.remove_absolute(temporary)
			message = "Choose an audio file smaller than 150 MB."; return {}
		hash_context.update(chunk); output.store_buffer(chunk)
	output.close(); file.close()
	if size == 0: DirAccess.remove_absolute(temporary); message = "This audio file is empty."; return {}
	var stream = decode(temporary)
	if stream == null:
		DirAccess.remove_absolute(temporary); message = "Choose a standard MP3, WAV or OGG file."; return {}
	if stream.get_length() < .2 or stream.get_length() > 1200:
		DirAccess.remove_absolute(temporary); message = "Choose a track between 0.2 seconds and 20 minutes."; return {}
	var id = hash_context.finish().hex_encode()
	for song in songs:
		if song.id == id:
			DirAccess.remove_absolute(temporary)
			return {"song": song, "stream": stream}
	var source_name = path.uri_decode().get_file()
	var title = source_name.get_basename()
	if title.is_empty() or (path.begins_with("content://") and source_name.get_extension().to_lower() not in ["mp3", "wav", "ogg"]):
		title = "Imported Audio " + id.substr(0, 6)
	var song = {"id": id, "title": title, "file": id + "." + format, "bpm": 128.0}
	var error = DirAccess.rename_absolute(temporary, root_path.path_join("songs/" + str(song.file)))
	if error != OK: message = "Could not keep audio on this device. Check storage."; return {}
	songs.append(song)
	if atomic_write(root_path.path_join("songs/library.json"), songs) != OK:
		songs.pop_back(); message = "Could not save the song library."; return {}
	return {"song": song, "stream": stream}

func save_chart(id: String, notes: Array) -> Error:
	return atomic_write(root_path.path_join("charts/" + id + ".json"), {"version": SynkChart.FORMAT_VERSION, "song_id": id, "notes": notes})

func delete_chart(id: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var path = root_path.path_join("charts/" + id + ".json" + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func delete_song(id: String) -> Error:
	# Removes the song's audio, chart, cover and library entry.
	var index = -1
	for i in songs.size():
		if str(songs[i].id) == id: index = i
	if index < 0: return ERR_DOES_NOT_EXIST
	var entry: Dictionary = songs[index]
	delete_chart(id)
	for path in [root_path.path_join("songs/" + str(entry.file)), root_path.path_join("covers/" + id + ".png")]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	songs.remove_at(index)
	return atomic_write(root_path.path_join("songs/library.json"), songs)

func has_chart(id: String) -> bool:
	return FileAccess.file_exists(root_path.path_join("charts/"+id+".json"))

func load_chart(id: String) -> Array:
	var path = root_path.path_join("charts/" + id + ".json")
	if not FileAccess.file_exists(path): return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var loaded: Variant = SynkChart.notes_from_file(data)
	if loaded != null and data.get("song_id") == id:
		return loaded
	message = "Saved chart is invalid; the original file has been kept."
	return []

static func synth_demo() -> AudioStreamWAV:
	var rate = 16000; var seconds = 96
	var bytes = PackedByteArray(); bytes.resize(rate * seconds * 2)
	var melody = [64, 67, 71, 74, 71, 67, 62, 66, 69, 73, 69, 66, 60, 64, 67, 71]
	var beat = 60.0 / 128
	for i in rate * seconds:
		var t = float(i) / rate; var local = fmod(t, beat)
		var step = int(t / (beat / 2)); var frequency = 440 * pow(2, (float(melody[step % 16]) - 69) / 12)
		var kick = sin(TAU * (48 * local + 6 * (1 - exp(-local * 35)))) * exp(-local * 18)
		var arp = sin(TAU * frequency * t) * exp(-fmod(t, beat / 2) * 13)
		var sample = int((kick * .32 + arp * .16) * minf(1, t) * minf(1, seconds - t) * 32767)
		bytes.encode_s16(i * 2, sample)
	var stream = AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = rate; stream.data = bytes
	return stream
