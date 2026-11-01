class_name AudioTags
# Reads song details and embedded cover art from imported audio: ID3v2.2/2.3/2.4 (with an ID3v1
# fallback) for MP3, and Vorbis/Opus comments for OGG. Returns any of title, artist, album,
# track (int), bpm (float) and cover (Image); missing or broken tags are simply left out.
const MAX_TAG_BYTES = 16*1024*1024

static func read(path: String) -> Dictionary:
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null: return {}
	var head=file.get_buffer(4)
	var tags={}
	if starts(head,0,"ID3"): tags=read_id3v2(file)
	elif starts(head,0,"OggS"): tags=read_ogg(file)
	if not tags.has("title") and file.get_length()>=128:
		file.seek(file.get_length()-128)
		var v1=read_id3v1(file.get_buffer(128))
		for key in v1: if not tags.has(key): tags[key]=v1[key]
	file.close()
	return clean(tags)

# Compares raw bytes with ASCII text, without decoding binary data as a string.
static func starts(data: PackedByteArray, at: int, text: String) -> bool:
	var expected=text.to_ascii_buffer()
	return at+expected.size()<=data.size() and data.slice(at,at+expected.size())==expected

static func clean(tags: Dictionary) -> Dictionary:
	var result={}
	for key in ["title","artist","album"]:
		var text=str(tags.get(key,"")).strip_edges()
		if not text.is_empty(): result[key]=text.substr(0,200)
	# "3/12" style track numbers keep only the track itself.
	var track=str(tags.get("track","")).get_slice("/",0).strip_edges()
	if track.is_valid_int() and int(track)>0: result.track=int(track)
	var bpm=str(tags.get("bpm","")).strip_edges()
	if bpm.is_valid_float() and float(bpm)>=40 and float(bpm)<=300: result.bpm=float(bpm)
	if tags.get("cover") is Image: result.cover=tags.cover
	return result

# --- MP3: ID3v2 -------------------------------------------------------------------------
const ID3_FIELDS = {"TIT2":"title","TT2":"title","TPE1":"artist","TP1":"artist","TALB":"album","TAL":"album","TRCK":"track","TRK":"track","TBPM":"bpm","TBP":"bpm"}

static func syncsafe(b: PackedByteArray, at: int) -> int:
	return (b[at]&127)<<21|(b[at+1]&127)<<14|(b[at+2]&127)<<7|(b[at+3]&127)

static func big_endian(b: PackedByteArray, at: int, count: int) -> int:
	var value=0
	for i in count: value=value<<8|b[at+i]
	return value

# Unsynchronisation inserts a 0x00 after every 0xFF; remove those again.
static func unsync(data: PackedByteArray) -> PackedByteArray:
	var out=PackedByteArray()
	var i=0
	while i<data.size():
		out.append(data[i])
		if data[i]==255 and i+1<data.size() and data[i+1]==0: i+=1
		i+=1
	return out

static func read_id3v2(file: FileAccess) -> Dictionary:
	file.seek(0)
	var header=file.get_buffer(10)
	if header.size()<10: return {}
	var version=header[3]
	var flags=header[5]
	var size=syncsafe(header,6)
	if version<2 or version>4 or size<=0 or size>MAX_TAG_BYTES: return {}
	var body=file.get_buffer(size)
	if version<4 and flags&128: body=unsync(body)
	var at=0
	if flags&64 and version>=3:
		# Extended header: v2.4 counts its own size, v2.3 does not.
		if body.size()<4: return {}
		at=syncsafe(body,0) if version==4 else big_endian(body,0,4)+4
	var tags={}
	var covers=[]
	var id_size=3 if version==2 else 4
	var header_size=6 if version==2 else 10
	while at+header_size<=body.size():
		if body[at]==0: break  # padding
		var id=latin1(body.slice(at,at+id_size))
		var frame_size=big_endian(body,at+3,3) if version==2 else (syncsafe(body,at+4) if version==4 else big_endian(body,at+4,4))
		var frame_flags=0 if version==2 else body[at+9]
		at+=header_size
		if frame_size<=0 or at+frame_size>body.size(): break
		var data=body.slice(at,at+frame_size)
		at+=frame_size
		if version==4:
			if frame_flags&2: data=unsync(data)
			# A data length indicator precedes the frame data.
			if frame_flags&1 and data.size()>=4: data=data.slice(4)
			if frame_flags&12: continue  # compressed or encrypted
		elif version==3 and frame_flags&192: continue
		if ID3_FIELDS.has(id) and not tags.has(ID3_FIELDS[id]) and data.size()>1:
			tags[ID3_FIELDS[id]]=decode_text(data.slice(1),data[0])
		elif id=="APIC" or id=="PIC":
			var picture=read_apic(data,id=="PIC")
			if not picture.is_empty(): covers.append(picture)
	# Prefer the front cover (picture type 3), else the first picture that decodes.
	covers.sort_custom(func(a,b): return int(a.type==3)>int(b.type==3))
	for picture in covers:
		var image=decode_image(picture.data)
		if image: tags.cover=image; break
	return tags

static func read_apic(data: PackedByteArray, legacy: bool) -> Dictionary:
	if data.size()<4: return {}
	var encoding=data[0]
	var at=1
	if legacy: at=4  # v2.2 PIC: a 3-letter image format instead of a MIME type
	else:
		while at<data.size() and data[at]!=0: at+=1
		at+=1
	if at>=data.size(): return {}
	var type=data[at]; at+=1
	at=skip_text(data,at,encoding)
	if at>=data.size(): return {}
	return {"type":type,"data":data.slice(at)}

# Skips a null-terminated string in the given ID3 text encoding.
static func skip_text(data: PackedByteArray, at: int, encoding: int) -> int:
	if encoding==1 or encoding==2:
		while at+1<data.size() and not (data[at]==0 and data[at+1]==0): at+=2
		return at+2
	while at<data.size() and data[at]!=0: at+=1
	return at+1

# Decodes ID3 text up to its first terminator (ID3v2.4 can list several values; keep the first).
static func decode_text(data: PackedByteArray, encoding: int) -> String:
	if encoding!=1 and encoding!=2:
		var end=data.find(0)
		if end>=0: data=data.slice(0,end)
	match encoding:
		0: return latin1(data)
		1, 2:
			var bytes=data
			var little=encoding==1
			if bytes.size()>=2 and bytes[0]==255 and bytes[1]==254: little=true; bytes=bytes.slice(2)
			elif bytes.size()>=2 and bytes[0]==254 and bytes[1]==255: little=false; bytes=bytes.slice(2)
			if not little:
				bytes=bytes.duplicate()
				for i in range(0,bytes.size()-1,2):
					var swap=bytes[i]; bytes[i]=bytes[i+1]; bytes[i+1]=swap
			if bytes.size()%2: bytes=bytes.slice(0,bytes.size()-1)
			for i in range(0,bytes.size()-1,2):
				if bytes[i]==0 and bytes[i+1]==0: bytes=bytes.slice(0,i); break
			return bytes.get_string_from_utf16()
		_: return data.get_string_from_utf8()

static func latin1(data: PackedByteArray) -> String:
	var text=""
	for byte in data:
		if byte==0: break
		text+=char(byte)
	return text

static func read_id3v1(block: PackedByteArray) -> Dictionary:
	if block.size()<128 or not starts(block,0,"TAG"): return {}
	var tags={"title":latin1(block.slice(3,33)),"artist":latin1(block.slice(33,63)),"album":latin1(block.slice(63,93))}
	# ID3v1.1 keeps the track number in the comment's last byte.
	if block[125]==0 and block[126]>0: tags.track=str(block[126])
	return tags

# --- OGG: Vorbis and Opus comments ---------------------------------------------------------
static func read_ogg(file: FileAccess) -> Dictionary:
	file.seek(0)
	var packets: Array=[]
	var packet=PackedByteArray()
	var stream=-1
	# Reassemble the first packets of the first logical stream; the comments are packet 2.
	while packets.size()<2 and not file.eof_reached():
		var header=file.get_buffer(27)
		if header.size()<27 or not starts(header,0,"OggS"): break
		var serial=header.decode_u32(14)
		var segments=file.get_buffer(header[26])
		var body=file.get_buffer(Array(segments).reduce(func(sum,lacing): return sum+lacing,0))
		if stream<0: stream=serial
		if serial!=stream: continue
		var at=0
		for lacing in segments:
			packet.append_array(body.slice(at,at+lacing)); at+=lacing
			if lacing<255: packets.append(packet); packet=PackedByteArray()
			if packets.size()>=2: break
		if packet.size()>MAX_TAG_BYTES: return {}
	if packets.size()<2: return {}
	var comments: PackedByteArray=packets[1]
	var at=-1
	if comments.size()>7 and comments[0]==3 and starts(comments,1,"vorbis"): at=7
	elif starts(comments,0,"OpusTags"): at=8
	if at<0: return {}
	return read_comments(comments,at)

static func read_comments(data: PackedByteArray, at: int) -> Dictionary:
	if at+4>data.size(): return {}
	at+=4+data.decode_u32(at)  # vendor string
	if at+4>data.size(): return {}
	var count=data.decode_u32(at); at+=4
	var tags={}
	var fields={"TITLE":"title","ARTIST":"artist","ALBUM":"album","TRACKNUMBER":"track","BPM":"bpm"}
	for i in mini(count,1000):
		if at+4>data.size(): break
		var length=data.decode_u32(at); at+=4
		if at+length>data.size(): break
		var entry=data.slice(at,at+length); at+=length
		var split=entry.find(61)  # '='
		if split<=0: continue
		var name=latin1(entry.slice(0,split)).to_upper()
		var value=entry.slice(split+1)
		if fields.has(name) and not tags.has(fields[name]): tags[fields[name]]=value.get_string_from_utf8()
		elif name=="METADATA_BLOCK_PICTURE" and not tags.has("cover"):
			var image=read_flac_picture(Marshalls.base64_to_raw(value.get_string_from_ascii()))
			if image: tags.cover=image
	return tags

# A FLAC picture block: type, MIME, description, size and colour fields, then the image.
static func read_flac_picture(block: PackedByteArray) -> Image:
	var at=4
	for text in 2:
		if at+4>block.size(): return null
		at+=4+big_endian(block,at,4)
	at+=16
	if at+4>block.size(): return null
	var length=big_endian(block,at,4); at+=4
	if at+length>block.size(): return null
	return decode_image(block.slice(at,at+length))

static func decode_image(data: PackedByteArray) -> Image:
	if data.size()<12: return null
	var image=Image.new()
	var error=ERR_FILE_UNRECOGNIZED
	if data[0]==255 and data[1]==216: error=image.load_jpg_from_buffer(data)
	elif data[0]==137 and starts(data,1,"PNG"): error=image.load_png_from_buffer(data)
	elif starts(data,0,"RIFF") and starts(data,8,"WEBP"): error=image.load_webp_from_buffer(data)
	if error!=OK: return null
	if image.get_width()<64 or image.get_height()<64: return null
	image.convert(Image.FORMAT_RGBA8)
	return image
