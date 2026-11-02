extends RefCounted
const PARSER=preload("res://scripts/ssrg_import.gd")

static func column(value:String) -> String:
	return value.strip_edges().trim_prefix("\ufeff").to_lower().replace(" ","").replace("_","").replace("-","")

static func field(row:PackedStringArray,headers:Dictionary,names:Array) -> String:
	for name in names:
		if headers.has(name) and int(headers[name])<row.size():return row[int(headers[name])].strip_edges()
	return ""

static func read(path:String) -> Dictionary:
	var result={"songs":{},"warnings":[],"error":""}
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>8*1024*1024:
		result.error="CSV is unreadable or exceeds 8 MB.";return result
	var first=file.get_csv_line()
	var delimiter=","
	if first.size()==1 and first[0].contains(";"):
		file.seek(0);delimiter=";";first=file.get_csv_line(delimiter)
	var headers={}
	for i in first.size():headers[column(first[i])]=i
	if not ["id","songid","musicid","audioid"].any(func(key):return headers.has(key)):
		result.error="CSV needs an ID or Song ID column.";return result
	var line=1
	while not file.eof_reached():
		var row=file.get_csv_line(delimiter);line+=1
		if row.size()==1 and row[0].strip_edges().is_empty():continue
		var raw_id=field(row,headers,["id","songid","musicid","audioid"])
		var id=PARSER.leading_id(raw_id)
		if id.is_empty() or id!=raw_id and not raw_id.begins_with(id):
			result.warnings.append("CSV row %d has no leading numeric song ID." % line);continue
		if result.songs.has(id):
			result.warnings.append("CSV song ID %s appears more than once; first row kept." % id);continue
		var details={}
		for key in ["title","artist","album","track"]:
			var aliases=[key]
			if key=="title":aliases=["title","songtitle","name","songname"]
			elif key=="artist":aliases=["artist","artistname","performer"]
			elif key=="album":aliases=["album","albumname"]
			else:aliases=["track","tracknumber","trackno"]
			var value=field(row,headers,aliases)
			if value.is_empty():continue
			if key=="track":
				if value.is_valid_int() and int(value)>0 and int(value)<=9999:details.track=int(value)
				else:result.warnings.append("CSV row %d has an invalid track number." % line)
			else:details[key]=value
		result.songs[id]=details
	return result
