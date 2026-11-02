extends RefCounted
# Workers prepare private files. Only the main thread commits to the live library.
const PARSER=preload("res://scripts/ssrg_import.gd")
const LEVELS=preload("res://scripts/chart_levels.gd")
const ALLOWED=["songs/","charts/","backgrounds/","ssrg_sources/"]

static func fingerprint(value:Variant) -> String:
	return JSON.stringify(value).sha256_text()

static func safe_relative(path:String) -> bool:
	return not path.is_empty() and not path.is_absolute_path() and not ":" in path and not "\\" in path and not ".." in path.split("/") and path==path.simplify_path()

static func target_ok(path:String) -> bool:
	if not safe_relative(path):return false
	for prefix in ALLOWED:
		if path.begins_with(prefix):return true
	return false

static func json_file(path:String,value:Variant) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f=FileAccess.open(path,FileAccess.WRITE)
	if f==null:return FileAccess.get_open_error()
	f.store_string(JSON.stringify(value,"\t"));f.flush()
	var error=f.get_error();f.close();return error

static func read_json(path:String,fallback:Variant) -> Variant:
	var value=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return fallback if value==null else value

static func hash_file(path:String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

static func remove_private_tree(folder:String) -> void:
	# This helper accepts only our minted transaction directories.
	if not folder.get_file().begins_with("tx-") or folder.get_base_dir().get_file()!=".ssrg_import":return
	_remove_children(folder)
	DirAccess.remove_absolute(folder)

static func _remove_children(folder:String) -> void:
	for file in DirAccess.get_files_at(folder):DirAccess.remove_absolute(folder.path_join(file))
	for child in DirAccess.get_directories_at(folder):
		_remove_children(folder.path_join(child));DirAccess.remove_absolute(folder.path_join(child))

static func fail(folder:String,message:String) -> Dictionary:
	remove_private_tree(folder);return {"error":message}

static func audio_format(path:String) -> String:
	var f=FileAccess.open(path,FileAccess.READ)
	if f==null:return ""
	var h=f.get_buffer(16);f.close()
	if h.size()>=4 and h.slice(0,4).get_string_from_ascii()=="OggS":return "ogg"
	if h.size()>=12 and h.slice(0,4).get_string_from_ascii()=="RIFF" and h.slice(8,12).get_string_from_ascii()=="WAVE":return "wav"
	if (h.size()>=3 and h.slice(0,3).get_string_from_ascii()=="ID3") or (h.size()>=2 and h[0]==255 and h[1]&224==224):return "mp3"
	return ""

static func copy_audio(source:String,destination:String,cancel:Callable,progress:Callable) -> String:
	var input=FileAccess.open(source,FileAccess.READ)
	if input==null:return "Audio could not be read. Choose a downloaded local file."
	if input.get_length()>150*1024*1024:return "Audio exceeds the 150 MB limit."
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var output=FileAccess.open(destination,FileAccess.WRITE)
	if output==null:return "Not enough writable storage for the audio."
	var size=input.get_length();var copied=0
	while input.get_position()<size:
		if cancel.is_valid() and cancel.call():return "Canceled"
		var chunk=input.get_buffer(mini(65536,size-copied))
		if chunk.is_empty():return "Audio could not be read completely."
		output.store_buffer(chunk);copied+=chunk.size()
		if output.get_error()!=OK:return "Could not write the audio. Check storage."
		if progress.is_valid():progress.call(copied,size)
	output.flush();output.close();input.close();return ""

static func add_operation(root:String,tx:Dictionary,target:String,staged:String,protect_draft:bool=false) -> bool:
	if not target_ok(target):return false
	var old_hash=hash_file(root.path_join(target));var backup="backup/"+target
	if not old_hash.is_empty():
		DirAccess.make_dir_recursive_absolute(tx.folder.path_join(backup).get_base_dir())
		if DirAccess.copy_absolute(root.path_join(target),tx.folder.path_join(backup))!=OK:return false
	tx.ops.append({"target":target,"staged":staged,"backup":backup,"old_hash":old_hash,"new_hash":hash_file(tx.folder.path_join(staged)),"protect_draft":protect_draft})
	return true

static func has_draft(root:String,id:String,keys:int) -> bool:
	var name=id+"_"+LEVELS.key(keys)+".json"
	return FileAccess.file_exists(root.path_join("drafts/"+name)) or FileAccess.file_exists(root.path_join("drafts/"+name+".bak"))

static func replacement_allowed(root:String,song:Dictionary,keys:int) -> bool:
	if song.is_empty() or not song.has("id"):return false
	if has_draft(root,str(song.id),keys):return false
	var relative="charts/"+str(song.id)+"_"+LEVELS.key(keys)+".json"
	var baseline=song.get("ssrg_import",{}).get("charts",{}).get(str(keys),{})
	return baseline is Dictionary and not str(baseline.get("sha256","")).is_empty() and hash_file(root.path_join(relative))==str(baseline.sha256)

static func song_id(item:Dictionary,songs:Array) -> String:
	var hash=str(item.get("audio_hash",""));var target=str(item.get("target_game",""))
	if target.is_empty():return hash
	var catalog=preload("res://scripts/ssrg_game_catalog.gd")
	target=catalog.normalize(target)
	for song in songs:
		if song.has("ssrg") and catalog.category(song)==target and (str(song.id)==hash or str(song.get("ssrg_import",{}).get("audio_sha256",""))==hash):return str(song.id)
	return (hash+"|ssrg_game|"+target).sha256_text()

static func prepare(root:String,item:Dictionary,songs:Array,cancel:Callable=Callable(),progress:Callable=Callable()) -> Dictionary:
	if item.get("policy","add_missing")=="skip":return {"skipped":true,"reason":"Skipped by selection."}
	var id=song_id(item,songs)
	if str(item.get("audio_hash","")).length()!=64 or id.length()!=64:return {"error":"Audio has not been validated. Review this song first."}
	var old_song:Dictionary={}
	for saved_song in songs:
		if str(saved_song.id)==id:old_song=saved_song;break
	var eligible=false;var kept=[]
	for key in item.get("selected_keys",item.charts.keys()):
		var count=int(key);var target=root.path_join("charts/"+id+"_"+LEVELS.key(count)+".json")
		if not FileAccess.file_exists(target):eligible=true
		elif item.get("policy","add_missing")=="replace_imported" and replacement_allowed(root,old_song,count):eligible=true
		else:kept.append("%d keys: saved chart kept." % count)
	if not eligible:return {"skipped":true,"reason":"No missing or safely replaceable difficulties.","warnings":kept}
	var folder=root.path_join(".ssrg_import/tx-%d-%d" % [Time.get_ticks_usec(),randi()])
	DirAccess.make_dir_recursive_absolute(folder)
	var tx={"folder":folder,"ops":[],"state":"prepared","library_fingerprint":fingerprint(songs),"id":id,"warnings":[],"saved_keys":[]}
	var existing:Dictionary={}
	for value in songs:
		if str(value.id)==id:existing=value.duplicate(true);break
	var song=existing.duplicate(true)
	if song.is_empty():song={"id":id,"added":Time.get_unix_time_from_system()}
	var baselines=song.get("ssrg_import",{}).get("charts",{}).duplicate(true)
	var audio=str(item.audio);var format=audio_format(audio)
	if format.is_empty():return fail(folder,"Choose a supported OGG, MP3 or WAV audio file.")
	var staged_audio="new/audio."+format
	var error=copy_audio(audio,folder.path_join(staged_audio),cancel,progress)
	if not error.is_empty():return fail(folder,error)
	if hash_file(folder.path_join(staged_audio))!=str(item.audio_hash):return fail(folder,"Audio changed since review. Scan this song again.")
	var stream=SynkLibrary.decode(folder.path_join(staged_audio))
	if stream==null:return fail(folder,"Audio could not be decoded.")
	var duration=stream.get_length()
	if not is_finite(duration) or duration<.2 or duration>1200:return fail(folder,"Audio must be between 0.2 seconds and 20 minutes.")
	var keys:Array=song.get("ssrg",[]).duplicate()
	var parsed_charts:Dictionary=item.get("parsed_charts",{})
	for key in item.get("selected_keys",item.charts.keys()):
		if cancel.is_valid() and cancel.call():return fail(folder,"Canceled")
		var count=int(key)
		if count not in [4,7,13]:return fail(folder,"Unsupported key count.")
		var target="charts/"+id+"_"+LEVELS.key(count)+".json"
		if FileAccess.file_exists(root.path_join(target)):
			if item.get("policy","add_missing")!="replace_imported":continue
			if not replacement_allowed(root,song,count):
				tx.warnings.append("%d keys: edited, draft, or legacy chart kept." % count);continue
		var source_path=str(item.charts.get(count,item.charts.get(str(count),"")))
		var raw=PackedByteArray();var chart:Dictionary={}
		if parsed_charts.has(count):chart=parsed_charts[count].duplicate(true)
		else:
			raw=FileAccess.get_file_as_bytes(source_path)
			var report=PARSER.report(raw,count)
			if not report.errors.is_empty():return fail(folder,"%d keys: %s" % [count," ".join(report.errors)])
			chart=report.chart
			var expected=str(item.get("chart_hashes",{}).get(str(count),""))
			if not expected.is_empty() and hash_file(source_path)!=expected:return fail(folder,"Chart changed since review. Scan this song again.")
		if chart.get("notes",[]).is_empty() or not SynkChart.valid(chart.notes):return fail(folder,"%d-key chart is invalid or empty." % count)
		for note in chart.notes:
			if float(note.time)+float(note.duration)>duration+.001:return fail(folder,"%d-key chart extends beyond the audio. Choose the correct audio; no notes were discarded." % count)
		var offset=float(chart.get("beat_offset",0))
		var data={"version":SynkChart.FORMAT_VERSION,"song_id":id,"chart_name":LEVELS.key(count),"title":str(item.get("title","Imported song")),"bpm":float(chart.bpm),"beat_offset":offset,"chart_settings":{"bpm":float(chart.bpm),"beat_offset":offset,"verse2":-1.0,"bridge":-1.0},"notes":chart.notes,"ssrg_source":chart.get("source",{}).duplicate(true)}
		if not raw.is_empty():
			var raw_hash=hash_file(source_path);var raw_target="ssrg_sources/"+id+"/%d-%s.seq" % [count,raw_hash]
			DirAccess.make_dir_recursive_absolute(folder.path_join("new/"+raw_target).get_base_dir())
			var f=FileAccess.open(folder.path_join("new/"+raw_target),FileAccess.WRITE)
			if f==null:return fail(folder,"Could not retain the original chart.")
			f.store_buffer(raw);f.close()
			data.ssrg_source.merge({"sha256":raw_hash,"original_file":raw_target,"filename":source_path.get_file()},true)
			if not add_operation(root,tx,raw_target,"new/"+raw_target):return fail(folder,"Could not prepare original chart storage.")
		if json_file(folder.path_join("new/"+target),data)!=OK or not add_operation(root,tx,target,"new/"+target,true):return fail(folder,"Could not prepare chart storage.")
		baselines[str(count)]={"sha256":hash_file(folder.path_join("new/"+target)),"source_sha256":str(data.ssrg_source.get("sha256",""))}
		if count not in keys:keys.append(count)
		tx.saved_keys.append(count)
		song.bpm=float(chart.bpm)
	if tx.saved_keys.is_empty():
		remove_private_tree(folder);return {"skipped":true,"reason":"No missing or safely replaceable difficulties.","warnings":tx.warnings}
	var audio_target="songs/"+id+"."+format
	if not FileAccess.file_exists(root.path_join(audio_target)):
		if not add_operation(root,tx,audio_target,staged_audio):return fail(folder,"Could not prepare audio storage.")
	song.file=id+"."+format;song.title=str(item.get("title",song.get("title","Imported song")));song.artist=str(item.get("artist",song.get("artist","")))
	if item.has("album") and not str(item.album).is_empty():song.album=str(item.album)
	if item.has("track"):song.track=int(item.track)
	song.ssrg_game=preload("res://scripts/ssrg_game_catalog.gd").normalize(str(item.get("target_game",item.get("game","IMPORTED"))))
	song.album=str(song.get("album",item.get("game","SSRG")));song.length=duration;keys.sort();song.ssrg=keys
	song.erase("ssrg_charts")
	var art=str(item.get("background",""))
	var art_hash=str(song.get("ssrg_import",{}).get("background_sha256",""))
	if not art.is_empty():
		var target="backgrounds/"+id+".png"
		if FileAccess.file_exists(root.path_join(target)) and hash_file(root.path_join(target))!=art_hash:
			tx.warnings.append("Custom background kept.")
		else:
			var image=Image.load_from_file(ProjectSettings.globalize_path(art))
			if image==null or image.get_width()<16 or image.get_height()<16:return fail(folder,"Background image is invalid.")
			DirAccess.make_dir_recursive_absolute(folder.path_join("new/backgrounds"))
			if image.save_png(folder.path_join("new/"+target))!=OK or not add_operation(root,tx,target,"new/"+target):return fail(folder,"Could not prepare background storage.")
			art_hash=hash_file(folder.path_join("new/"+target))
	if item.get("presentation") is Dictionary:
		var config:Dictionary=item.presentation.duplicate(true);var cards=[]
		for card in config.get("cards",[]):
			if not card is Dictionary:continue
			var copied=card.duplicate(true);var portrait=str(copied.get("portrait",""))
			if not portrait.is_empty():
				var image=Image.load_from_file(ProjectSettings.globalize_path(portrait))
				if image==null:return fail(folder,"Card artwork could not be read.")
				var target="songs/"+id+"-cards/%d-%s.png" % [cards.size(),hash_file(portrait).substr(0,16)]
				DirAccess.make_dir_recursive_absolute(folder.path_join("new/"+target).get_base_dir())
				if image.save_png(folder.path_join("new/"+target))!=OK or not add_operation(root,tx,target,"new/"+target):return fail(folder,"Could not prepare card artwork.")
				copied.portrait=root.path_join(target)
			cards.append(copied)
		config.cards=cards;song.ssrg_presentation=config
	song.ssrg_import={"version":4,"audio_sha256":str(item.audio_hash),"charts":baselines,"background_sha256":art_hash,"source_key":str(item.get("source_key",""))}
	tx.song=song;tx.outcome="imported" if existing.is_empty() else "updated"
	if SynkLibrary.atomic_write(folder.path_join("journal.json"),tx)!=OK:return fail(folder,"Could not prepare recovery journal.")
	return tx

static func rollback(root:String,tx:Dictionary) -> bool:
	var ok=true
	if not tx.get("ops",null) is Array:return false
	for op in tx.ops:
		if not op is Dictionary or not op.get("old_hash",null) is String:return false
		if not target_ok(str(op.get("target",""))) or not safe_relative(str(op.get("backup",""))):return false
		var target=root.path_join(op.target)
		var current_hash=hash_file(target)
		if not current_hash.is_empty() and current_hash not in [str(op.old_hash),str(op.get("new_hash",""))]:
			ok=false;continue
		if str(op.old_hash).is_empty():
			if FileAccess.file_exists(target) and DirAccess.remove_absolute(target)!=OK:ok=false
		elif hash_file(tx.folder.path_join(op.backup))==str(op.old_hash):
			if DirAccess.copy_absolute(tx.folder.path_join(op.backup),target)!=OK:ok=false
		else:ok=false
	if ok:
		tx.state="rolled_back";SynkLibrary.atomic_write(tx.folder.path_join("journal.json"),tx)
	return ok

static func commit(root:String,tx:Dictionary,songs:Array) -> Dictionary:
	if tx.has("error") or tx.has("skipped"):return tx
	for name in DirAccess.get_directories_at(root.path_join(".ssrg_import")):
		var other=root.path_join(".ssrg_import/"+name)
		if not name.begins_with("tx-") or other==str(tx.folder) or FileAccess.file_exists(other.path_join("done")):continue
		if not FileAccess.file_exists(other.path_join("journal.json")):continue
		var journal=read_json(other.path_join("journal.json"),{})
		if not journal is Dictionary or journal.get("state","") not in ["prepared","committed","rolled_back"]:return fail(tx.folder,"Recovery needs attention before another song can be saved. Reopen Import.")
	if fingerprint(songs)!=str(tx.library_fingerprint):return fail(tx.folder,"Library changed while preparing this song. Retry it.")
	for op in tx.ops:
		if not target_ok(op.target) or not safe_relative(op.staged) or hash_file(root.path_join(op.target))!=str(op.old_hash) or hash_file(tx.folder.path_join(op.staged))!=str(op.new_hash):return fail(tx.folder,"A saved or prepared file changed during import. It was kept; retry this song.")
		if op.protect_draft:
			var key=int(str(op.target).get_file().get_basename().get_slice("_lv",1))
			if has_draft(root,str(tx.id),key):return fail(tx.folder,"A draft was created during import. It was kept.")
	var merged=songs.duplicate(true);var index=-1
	for i in merged.size():
		if str(merged[i].id)==str(tx.id):index=i;break
	if index<0:merged.append(tx.song)
	else:merged[index]=tx.song
	if json_file(tx.folder.path_join("new/library.json"),merged)!=OK or not add_operation(root,tx,"songs/library.json","new/library.json"):return fail(tx.folder,"Could not prepare the library index.")
	tx.state="committing"
	if SynkLibrary.atomic_write(tx.folder.path_join("journal.json"),tx)!=OK:return fail(tx.folder,"Could not save the recovery journal.")
	for op in tx.ops:
		DirAccess.make_dir_recursive_absolute(root.path_join(op.target).get_base_dir())
		if DirAccess.rename_absolute(tx.folder.path_join(op.staged),root.path_join(op.target))!=OK:
			var restored=rollback(root,tx)
			return {"error":"Could not save this song. Previous files restored." if restored else "Storage error: recovery is pending. Free storage and reopen Import."}
	tx.state="committed"
	if SynkLibrary.atomic_write(tx.folder.path_join("journal.json"),tx)!=OK:
		rollback(root,tx);return {"error":"Could not finalize this song; previous files restored."}
	# Moved live files and backups remain; unused staged audio is disposable.
	if DirAccess.dir_exists_absolute(tx.folder.path_join("new")):
		_remove_children(tx.folder.path_join("new"));DirAccess.remove_absolute(tx.folder.path_join("new"))
	json_file(tx.folder.path_join("done"),{"committed":true})
	return {"id":tx.id,"title":tx.song.title,"saved":tx.saved_keys.size(),"keys":tx.saved_keys,"songs":merged,"outcome":tx.outcome,"warnings":tx.warnings}

static func recover(root:String) -> Array:
	var messages=[];var base=root.path_join(".ssrg_import")
	if not DirAccess.dir_exists_absolute(base):return messages
	for name in DirAccess.get_directories_at(base):
		if not name.begins_with("tx-"):continue
		var folder=base.path_join(name)
		if FileAccess.file_exists(folder.path_join("done")):continue
		var tx=read_json(folder.path_join("journal.json"),{})
		if not tx is Dictionary or tx.is_empty():tx=read_json(folder.path_join("journal.json.bak"),{})
		if not tx is Dictionary or tx.is_empty():
			if FileAccess.file_exists(folder.path_join("journal.json")) or FileAccess.file_exists(folder.path_join("journal.json.bak")):
				messages.append("Recovery needs attention: damaged journal kept; no saved files changed.")
			else:remove_private_tree(folder)
			continue
		if tx.get("state","") in ["committed","rolled_back"]:continue
		if tx.get("state","")=="prepared":remove_private_tree(folder);continue
		if tx.get("state","")!="committing":
			messages.append("Recovery needs attention: unrecognized journal kept; no saved files changed.");continue
		tx.folder=folder
		messages.append("Interrupted import restored." if rollback(root,tx) else "Recovery needs attention: changed files or storage errors prevented a full restore. Existing files were kept.")
	return messages
