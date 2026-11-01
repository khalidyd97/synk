extends RefCounted
static func folder(label:String) -> String:
	var path="res://.tools/%s-%d" % [label,Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(path);return path
static func raw(records:Array,start_tick:int=0,ticks:int=256) -> PackedByteArray:
	var points=[[start_tick,13,1,0]]+records
	var data=PackedByteArray();data.resize(0x100+24*points.size())
	data.encode_double(8,2.0);data.encode_u32(0x10,ticks);data.encode_u32(0x2c,points.size());data.encode_double(0x50,120.0)
	var name="artist_song.ogg".to_utf8_buffer()
	for i in name.size():data[0x80+i]=name[i]
	for i in points.size():
		var at=0x100+i*24;var p=points[i]
		data.encode_s64(at,int(p[0]));data.encode_u32(at+8,int(p[1]));data.encode_u32(at+12,int(p[2]));data.encode_u32(at+16,int(p[3]));data.encode_u32(at+20,42)
	return data
static func write(path:String,data:PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir());var f=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(data);f.close()
static func audio(path:String) -> void:
	var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=8000
	var samples=PackedByteArray();samples.resize(32000);wav.data=samples;assert(wav.save_to_wav(path)==OK)
static func source(root:String,keys:int=4) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(root)
	var audio_path=root.path_join("artist_song.wav");audio(audio_path)
	var path=root.path_join("artist_song_%d.seq" % keys);write(path,raw([[64,0,0,0],[128,4,0,11],[192,8,0,12]]))
	return {"audio":audio_path,"chart":path}
