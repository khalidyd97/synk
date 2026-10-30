extends RefCounted
const LIMIT_FILE=150*1024*1024
const LIMIT_TOTAL=1024*1024*1024
const EXTENSIONS=["seq","bytes","ogg","mp3","wav","png","jpg","jpeg","webp","json"]
const TX=preload("res://scripts/ssrg_import_transaction.gd")

static func inspect(path:String) -> Dictionary:
	var result={"entries":[],"error":""};var f=FileAccess.open(path,FileAccess.READ)
	if f==null:result.error="ZIP could not be read.";return result
	var size=f.get_length()
	if size<22:result.error="ZIP is truncated.";return result
	var length=mini(size,65557);f.seek(size-length);var tail=f.get_buffer(length);var end=-1
	for i in range(length-22,-1,-1):
		if tail.decode_u32(i)==0x06054b50 and i+22+tail.decode_u16(i+20)==length:end=i;break
	if end<0:result.error="ZIP directory is missing.";return result
	var count=int(tail.decode_u16(end+10));var offset=int(tail.decode_u32(end+16));var directory_size=int(tail.decode_u32(end+12))
	if tail.decode_u16(end+4)!=0 or tail.decode_u16(end+6)!=0 or count>=65535 or offset==0xffffffff or directory_size==0xffffffff:
		result.error="Split and ZIP64 archives are not supported. Use smaller standard ZIPs.";return result
	if count>10000 or offset+directory_size>size-length+end:result.error="ZIP directory exceeds supported limits.";return result
	f.seek(offset);var total=0;var names={}
	for i in count:
		var h=f.get_buffer(46)
		if h.size()!=46 or h.decode_u32(0)!=0x02014b50:result.error="ZIP directory is invalid.";return result
		var name_length=int(h.decode_u16(28));var extra=int(h.decode_u16(30));var comment=int(h.decode_u16(32));var bytes=int(h.decode_u32(24))
		var name=f.get_buffer(name_length).get_string_from_utf8()
		f.seek(f.get_position()+extra+comment)
		var normalized=name.replace("\\","/").trim_suffix("/")
		while normalized.begins_with("./"):normalized=normalized.substr(2)
		if not TX.safe_relative(normalized) or ((h.decode_u32(38)>>16)&0xf000)==0xa000:
			result.error="ZIP contains an unsafe path or symbolic link.";return result
		if h.decode_u16(8)&1:result.error="Encrypted ZIPs are not supported.";return result
		if h.decode_u16(34)!=0 or bytes==0xffffffff:result.error="Split and ZIP64 entries are not supported.";return result
		if name.ends_with("/"):continue
		if names.has(normalized.to_lower()):result.error="ZIP contains conflicting duplicate file names.";return result
		names[normalized.to_lower()]=true
		total+=bytes
		if bytes>LIMIT_FILE or total>LIMIT_TOTAL:result.error="ZIP exceeds the 150 MB per file or 1 GB extracted limit.";return result
		if normalized.begins_with("__MACOSX/") or normalized.get_file().begins_with(".") or normalized.get_extension().to_lower() not in EXTENSIONS:continue
		result.entries.append({"archive_name":name,"name":normalized,"bytes":bytes})
	return result

static func extract(path:String,cache:String,cancel:Callable,progress:Callable=Callable()) -> Dictionary:
	var index=inspect(path)
	if not str(index.error).is_empty():return {"error":index.error,"files":[]}
	var reader=ZIPReader.new()
	if reader.open(path)!=OK:return {"error":"ZIP could not be opened.","files":[]}
	var files=PackedStringArray();var done=0
	for entry in index.entries:
		if cancel.is_valid() and cancel.call():reader.close();return {"error":"Canceled","files":files}
		var data=reader.read_file(entry.archive_name)
		if data.size()!=int(entry.bytes):reader.close();return {"error":"ZIP entry is corrupt: "+str(entry.name),"files":files}
		var target=cache.path_join(entry.name)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var output=FileAccess.open(target,FileAccess.WRITE)
		if output==null:reader.close();return {"error":"Not enough writable storage to extract ZIP.","files":files}
		output.store_buffer(data)
		if output.get_error()!=OK:output.close();reader.close();return {"error":"Could not finish extracting ZIP. Check storage.","files":files}
		output.close();files.append(target);done+=1
		if progress.is_valid():progress.call(done,index.entries.size())
	reader.close();return {"error":"","files":files}
