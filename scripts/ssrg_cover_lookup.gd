extends RefCounted

static func normalized(value:String) -> String:
	var out=""
	for ch in value.to_lower():
		if ch.is_valid_identifier() or ch.is_valid_int():out+=ch
	return out

static func unique_group(payload:Variant,album:String,artist:String) -> String:
	if not payload is Dictionary:return ""
	var wanted_album=normalized(album);var wanted_artist=normalized(artist)
	if wanted_album.is_empty() or wanted_artist.is_empty():return ""
	var found=[]
	for entry in payload.get("release-groups",[]):
		if not entry is Dictionary or normalized(str(entry.get("title","")))!=wanted_album:continue
		var credit=""
		for part in entry.get("artist-credit",[]):
			if part is Dictionary:credit+=str(part.get("name",part.get("artist",{}).get("name","")))
			elif part is String:credit+=part
		if normalized(credit)!=wanted_artist:continue
		var id=str(entry.get("id",""))
		if id.length()==36 and id not in found:found.append(id)
	return str(found[0]) if found.size()==1 else ""
