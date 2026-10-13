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
	if file == null: message = "Could not read this file."; return {}
	if file.get_length() > 150 * 1024 * 1024: message = "Choose an audio file smaller than 150 MB."; return {}
	var stream = decode(path)
	if stream == null: message = "Choose a standard MP3, WAV or OGG file."; return {}
	if stream.get_length() < .2 or stream.get_length() > 1200: message = "Choose a track between 0.2 seconds and 20 minutes."; return {}
	var hash_context = HashingContext.new(); hash_context.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length(): hash_context.update(file.get_buffer(65536))
	var id = hash_context.finish().hex_encode()
	for song in songs:
		if song.id == id: return {"song": song, "stream": stream}
	var song = {"id": id, "title": path.get_file().get_basename(), "file": id + "." + path.get_extension().to_lower(), "bpm": 128.0}
	var error = DirAccess.copy_absolute(path, root_path.path_join("songs/" + str(song.file)))
	if error != OK: message = "Could not keep audio on this device. Check storage."; return {}
	songs.append(song)
	if atomic_write(root_path.path_join("songs/library.json"), songs) != OK:
		songs.pop_back(); message = "Could not save the song library."; return {}
	return {"song": song, "stream": stream}

func save_chart(id: String, notes: Array) -> Error:
	return atomic_write(root_path.path_join("charts/" + id + ".json"), {"version": 1, "song_id": id, "notes": notes})

func has_chart(id: String) -> bool:
	return FileAccess.file_exists(root_path.path_join("charts/"+id+".json"))

func load_chart(id: String) -> Array:
	var path = root_path.path_join("charts/" + id + ".json")
	if not FileAccess.file_exists(path): return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and data.get("version") == 1 and data.get("song_id") == id and SynkChart.valid(data.get("notes")):
		return data.notes
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
