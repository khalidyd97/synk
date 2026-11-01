extends SceneTree
# AudioTags reads song details and cover art from ID3v2.3, ID3v2.4, ID3v1 and OGG comments.
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)

func be32(value: int) -> PackedByteArray:
	return PackedByteArray([value>>24&255,value>>16&255,value>>8&255,value&255])
func syncsafe(value: int) -> PackedByteArray:
	return PackedByteArray([value>>21&127,value>>14&127,value>>7&127,value&127])
func le32(value: int) -> PackedByteArray:
	return PackedByteArray([value&255,value>>8&255,value>>16&255,value>>24&255])
func ascii(text: String) -> PackedByteArray: return text.to_ascii_buffer()

func frame(id: String, data: PackedByteArray, v4: bool) -> PackedByteArray:
	var out=ascii(id); out.append_array(syncsafe(data.size()) if v4 else be32(data.size())); out.append_array(PackedByteArray([0,0])); out.append_array(data)
	return out
func tag(frames: PackedByteArray, v4: bool) -> PackedByteArray:
	var out=ascii("ID3"); out.append_array(PackedByteArray([4 if v4 else 3,0,0])); out.append_array(syncsafe(frames.size()+20))
	out.append_array(frames); out.append_array(PackedByteArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]))  # padding
	return out
func utf16(text: String) -> PackedByteArray:
	var out=PackedByteArray([1,255,254]); out.append_array(text.to_utf16_buffer()); return out
func picture(type: int, image: PackedByteArray, mime: String) -> PackedByteArray:
	var out=PackedByteArray([0]); out.append_array(ascii(mime)); out.append(0); out.append(type); out.append_array(ascii("cover")); out.append(0); out.append_array(image)
	return out
func image_bytes(color: Color, jpg: bool = false) -> PackedByteArray:
	var image=Image.create(96,96,false,Image.FORMAT_RGB8); image.fill(color)
	return image.save_jpg_to_buffer() if jpg else image.save_png_to_buffer()
func write(path: String, data: PackedByteArray) -> String:
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(data); file.close(); return path

func ogg_pages(packets: Array) -> PackedByteArray:
	var out=PackedByteArray()
	var sequence=0
	for packet in packets:
		var lacing=PackedByteArray()
		var left: int=packet.size()
		while true:
			lacing.append(mini(left,255))
			if left<255: break
			left-=255
		var at=0
		while at<lacing.size():
			var segments=lacing.slice(at,mini(at+255,lacing.size()))
			var body_start=0
			for i in at: body_start+=lacing[i]
			var body_size=0
			for value in segments: body_size+=value
			var header=ascii("OggS"); header.append_array(PackedByteArray([0,0 if at==0 else 1,0,0,0,0,0,0,0,0])); header.append_array(le32(77)); header.append_array(le32(sequence)); header.append_array(le32(0)); header.append(segments.size())
			out.append_array(header); out.append_array(segments); out.append_array(packet.slice(body_start,body_start+body_size))
			sequence+=1; at+=segments.size()
	return out

func _initialize() -> void:
	var dir=OS.get_user_data_dir().path_join("audio_tags_test"); DirAccess.make_dir_recursive_absolute(dir)
	# ID3v2.3: UTF-16 title, Latin-1 artist, "3/12" track, BPM, and a back cover before the front cover.
	var frames=PackedByteArray()
	frames.append_array(frame("TSSE",PackedByteArray([0])+ascii("Lavf58"),false))
	frames.append_array(frame("TIT2",utf16("Ünïcode Sóng"),false))
	frames.append_array(frame("TPE1",PackedByteArray([0])+ascii("The Band"),false))
	frames.append_array(frame("TALB",PackedByteArray([0])+ascii("First Album"),false))
	frames.append_array(frame("TRCK",PackedByteArray([0])+ascii("3/12"),false))
	frames.append_array(frame("TBPM",PackedByteArray([0])+ascii("140"),false))
	frames.append_array(frame("APIC",picture(4,image_bytes(Color.BLUE),"image/png"),false))
	frames.append_array(frame("APIC",picture(3,image_bytes(Color.RED),"image/png"),false))
	var v3=AudioTags.read(write(dir.path_join("v3.mp3"),tag(frames,false)+PackedByteArray([255,251,144,0])))
	check(v3.get("title")=="Ünïcode Sóng","ID3v2.3 UTF-16 title")
	check(v3.get("artist")=="The Band" and v3.get("album")=="First Album","ID3v2.3 artist and album")
	check(v3.get("track")==3 and is_equal_approx(float(v3.get("bpm",0)),140),"Track number and BPM")
	check(v3.get("cover") is Image and v3.cover.get_pixel(48,48).r>.9,"Front cover preferred over other pictures")
	# ID3v2.4: syncsafe frame sizes, UTF-8 text and a JPEG cover.
	frames=PackedByteArray()
	frames.append_array(frame("TIT2",PackedByteArray([3])+"Café ☕".to_utf8_buffer(),true))
	frames.append_array(frame("TPE1",PackedByteArray([3])+"アーティスト".to_utf8_buffer(),true))
	frames.append_array(frame("APIC",picture(3,image_bytes(Color.GREEN,true),"image/jpeg"),true))
	var v4=AudioTags.read(write(dir.path_join("v4.mp3"),tag(frames,true)+PackedByteArray([255,251,144,0])))
	check(v4.get("title")=="Café ☕" and v4.get("artist")=="アーティスト","ID3v2.4 UTF-8 text")
	check(v4.get("cover") is Image and v4.cover.get_width()==96,"ID3v2.4 JPEG cover")
	# ID3v1 only, at the end of the file.
	var v1=PackedByteArray([255,251,144,0]); v1.resize(200)
	var block=ascii("TAG"); for text in ["Old Song","Old Artist","Old Album"]: var field=ascii(text); field.resize(30); block.append_array(field)
	block.resize(125); block.append_array(PackedByteArray([0,7,255]))
	var old=AudioTags.read(write(dir.path_join("v1.mp3"),v1+block))
	check(old.get("title")=="Old Song" and old.get("artist")=="Old Artist" and old.get("track")==7,"ID3v1 fallback")
	# OGG Vorbis comments with a METADATA_BLOCK_PICTURE spanning several pages.
	var flac=be32(3)+be32(9)+ascii("image/png")+be32(0)+be32(96)+be32(96)+be32(24)+be32(0)
	var noise=Image.create(96,96,false,Image.FORMAT_RGB8)
	for i in 96*96: noise.set_pixel(i%96,i/96,Color(randf(),randf(),randf()))
	var png=noise.save_png_to_buffer(); flac.append_array(be32(png.size())); flac.append_array(png)
	var comments=["TITLE=Ogg Song","ARTIST=Ogg Artist","TRACKNUMBER=5","METADATA_BLOCK_PICTURE="+Marshalls.raw_to_base64(flac)]
	var packet=PackedByteArray([3])+ascii("vorbis")+le32(6)+ascii("Vendor")+le32(comments.size())
	for comment in comments: var bytes=comment.to_utf8_buffer(); packet.append_array(le32(bytes.size())); packet.append_array(bytes)
	var identification=PackedByteArray([1])+ascii("vorbis"); identification.resize(30)
	var ogg=AudioTags.read(write(dir.path_join("tags.ogg"),ogg_pages([identification,packet])))
	check(ogg.get("title")=="Ogg Song" and ogg.get("artist")=="Ogg Artist" and ogg.get("track")==5,"OGG Vorbis comments")
	check(ogg.get("cover") is Image and ogg.cover.get_width()==96,"OGG embedded picture across pages")
	# Untagged audio gives nothing.
	check(AudioTags.read(write(dir.path_join("plain.mp3"),PackedByteArray([255,251,144,0,0,0,0,0]))).is_empty(),"Untagged audio returns no tags")
	if failures==0: print("Audio tags: PASS")
	quit(failures)
