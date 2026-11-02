extends RefCounted
const PARSER=preload("res://scripts/ssrg_import.gd")
const TX=preload("res://scripts/ssrg_import_transaction.gd")
const ARCHIVE=preload("res://scripts/ssrg_import_archive.gd")
const CSV=preload("res://scripts/ssrg_import_csv.gd")
var root="user://"
var target_game=""
var metadata_csv=""
var task=-1
var mutex=Mutex.new()
var canceled=false
var revision=0
var state={"phase":"idle","message":"Choose a folder, ZIP, or song files.","done":0,"total":0}
var plan:Array=[]
var reports:Array=[]
var scan_messages:Array=[]
var caches:Array=[]
var prepared:Dictionary={}
var queue:Array=[]
var current=-1
var importing=false
var selection_count=0

func update(values:Dictionary) -> void:
	mutex.lock();state.merge(values,true);revision+=1;mutex.unlock()
func cancel() -> void:
	mutex.lock();canceled=true;mutex.unlock()
func is_canceled() -> bool:
	mutex.lock();var value=canceled;mutex.unlock();return value
func busy() -> bool:return task>=0 or importing
func poll(previous:int=-1) -> Dictionary:
	if task>=0 and WorkerThreadPool.is_task_completed(task):
		WorkerThreadPool.wait_for_task_completion(task);task=-1
		previous=-1
	mutex.lock()
	var value={} if previous==revision else state.duplicate(true)
	if not value.is_empty():value.revision=revision
	mutex.unlock();return value
func shutdown() -> void:
	cancel()
	if task>=0:WorkerThreadPool.wait_for_task_completion(task);task=-1
func phase() -> String:
	mutex.lock();var value=str(state.phase);mutex.unlock();return value
func publish(phase_name:String,message:String) -> void:
	var public=[]
	for item in plan:
		var row=item.duplicate(false);row.erase("audio_files");row.erase("image_files");public.append(row)
	update({"phase":phase_name,"message":message,"items":public,"reports":reports.duplicate(true),"scan_messages":scan_messages.duplicate()})

func scan(paths:PackedStringArray,songs:Array) -> void:
	if busy():return
	clear_cache();plan.clear();reports.clear();scan_messages.clear();canceled=false
	update({"phase":"scanning","message":"Reading selected files…","done":0,"total":0,"items":[],"reports":[]})
	task=WorkerThreadPool.add_task(_scan.bind(paths,songs.duplicate(true)))

func clear_cache() -> void:
	for folder in caches:
		if str(folder).get_file().begins_with("cache-") and str(folder).get_base_dir().get_file()==".ssrg_import":
			TX._remove_children(folder);DirAccess.remove_absolute(folder)
	caches.clear()

func collect(folder:String,files:PackedStringArray,depth:int=0) -> void:
	if depth>8:
		if "Some folders exceed eight levels. Select a deeper subfolder to include them." not in scan_messages:scan_messages.append("Some folders exceed eight levels. Select a deeper subfolder to include them.")
		return
	if files.size()>=10000 or is_canceled():return
	for name in DirAccess.get_files_at(folder):
		if files.size()>=10000:return
		if not name.begins_with("."):files.append(folder.path_join(name))
	for child in DirAccess.get_directories_at(folder):
		if not child.begins_with("."):collect(folder.path_join(child),files,depth+1)

func file_size(path:String) -> int:
	var f=FileAccess.open(path,FileAccess.READ);return f.get_length() if f!=null else -1

func _scan(paths:PackedStringArray,songs:Array) -> void:
	var metadata=CSV.read(metadata_csv) if not metadata_csv.is_empty() else {"songs":{},"warnings":[],"error":""}
	if not str(metadata.error).is_empty():scan_messages.append(str(metadata.error))
	scan_messages.append_array(metadata.warnings)
	var files=PackedStringArray()
	for path in paths:
		if DirAccess.dir_exists_absolute(path):collect(path,files)
		else:files.append(path)
	var expanded=PackedStringArray();var unique={}
	for path in files:
		if is_canceled():break
		if unique.has(path):continue
		unique[path]=true
		if path.get_extension().to_lower()=="zip":
			var cache=root.path_join(".ssrg_import/cache-%d-%d" % [Time.get_ticks_usec(),randi()]);caches.append(cache)
			var extracted=ARCHIVE.extract(path,cache,is_canceled,func(done,total):update({"message":"Opening "+path.get_file(),"done":done,"total":total}))
			if not str(extracted.error).is_empty():scan_messages.append(path.get_file()+": "+str(extracted.error))
			else:expanded.append_array(extracted.files)
		else:expanded.append(path)
	if files.size()>=10000:scan_messages.append("Scan reached its 10,000-file limit. Select a smaller folder to review the rest.")
	var chart_files=PackedStringArray();var audio_files=PackedStringArray();var images=PackedStringArray()
	for path in expanded:
		if is_canceled():break
		var ext=path.get_extension().to_lower()
		if ext in PARSER.IMAGE_EXTENSIONS:images.append(path)
		elif ext in PARSER.AUDIO_EXTENSIONS+PARSER.CHART_EXTENSIONS:
			if not TX.audio_format(path).is_empty():audio_files.append(path)
			elif ext in PARSER.CHART_EXTENSIONS:chart_files.append(path)
	var groups={}
	for path in chart_files:
		var base=path.get_base_dir()
		if base.get_file().to_lower() in ["seq","seqs","chart","charts"]:base=base.get_base_dir()
		var song_id=PARSER.song_key(path)
		var key=base+"/"+song_id
		if not groups.has(key):groups[key]={"source_key":key,"base":base,"song_id":song_id,"game":base.get_file(),"chart_files":[],"key_overrides":{},"audio":"","audio_manual":false,"background":"","background_manual":false,"policy":"add_missing","include":true}
		groups[key].chart_files.append(path)
	var entries=groups.values();entries.sort_custom(func(a,b):return str(a.source_key)<str(b.source_key))
	for i in entries.size():
		if is_canceled():break
		update({"message":"Checking song %d of %d" % [i+1,entries.size()],"done":i,"total":entries.size()})
		var item:Dictionary=entries[i]
		item.csv_details=metadata.songs
		item.audio_files=audio_files;item.image_files=images
		plan.append(inspect_item(item,songs))
	var same_audio={}
	for i in plan.size():
		var hash=str(plan[i].get("audio_hash",""))
		if hash.is_empty():continue
		if same_audio.has(hash):
			var warning="Another selected source has identical audio. Difficulties merge into one song using the selected update policy."
			plan[i].warnings.append(warning)
			if warning not in plan[int(same_audio[hash])].warnings:plan[int(same_audio[hash])].warnings.append(warning)
		else:same_audio[hash]=i
	update({"done":plan.size(),"total":entries.size()})
	publish("review","Scan canceled. Review the songs already checked." if is_canceled() else ("Review matches and warnings before importing." if not plan.is_empty() else "No SSRG chart files found. Choose a folder, ZIP, or .seq/.bytes charts."))

static func candidates(files:PackedStringArray,stems:Array,base:String,primary_id:String="") -> Array:
	var values=[]
	for path in files:
		var score=PARSER.match_score(path,stems,primary_id)
		if score<=0:continue
		if path.begins_with(base+"/"):score+=50
		values.append({"path":path,"score":score})
	values.sort_custom(func(a,b):return a.score>b.score if a.score!=b.score else str(a.path)<str(b.path))
	return values

func inspect_item(original:Dictionary,songs:Array) -> Dictionary:
	var item=original.duplicate(true)
	if not target_game.is_empty():item.target_game=target_game;item.game=target_game;item.game_edited=true
	item.errors=[];item.warnings=[];item.chart_reports=[];item.charts={};item.chart_hashes={};item.valid_keys=[]
	var audio_name=""
	for path in item.chart_files:
		if is_canceled():break
		var hint=int(item.key_overrides.get(path,0))
		if hint==0:
			hint=PARSER.level_hint(path)
		var report:Dictionary
		if file_size(path)>16*1024*1024 or file_size(path)<0:report={"chart":{},"errors":["Chart is unreadable or exceeds 16 MB."],"warnings":[]}
		else:
			var raw=FileAccess.get_file_as_bytes(path);report=PARSER.report(raw,hint)
			if audio_name.is_empty():audio_name=PARSER.audio_name(raw)
		var chart:Dictionary=report.chart
		var keys=int(chart.get("keys",hint))
		var summary={"path":path,"keys":keys,"notes":chart.get("notes",[]).size(),"bpm":chart.get("bpm",0),"end":0.0,"errors":report.errors,"warnings":report.warnings,"inferred":hint==0}
		if hint==0 and not chart.is_empty():summary.warnings.append("Key count inferred from used lanes; verify it.")
		for note in chart.get("notes",[]):summary.end=maxf(float(summary.end),float(note.time)+float(note.duration))
		if not chart.is_empty() and keys in [4,7,13]:
			# Only the extra file is left out, so the song still imports the levels it has.
			if item.charts.has(keys):summary.errors.append("Another file is already the %d-key level; change its key count to include it." % keys)
			else:item.charts[keys]=path;item.chart_hashes[str(keys)]=FileAccess.get_sha256(path)
		item.chart_reports.append(summary)
	var names=PARSER.artist_and_title(audio_name) if not audio_name.is_empty() else ["",str(item.song_id)]
	if not item.has("title"):item.title=names[1]
	if not item.has("artist"):item.artist=names[0]
	var matches=candidates(item.audio_files,[audio_name,item.song_id],str(item.base),str(item.song_id));item.audio_matches=matches
	if not item.get("audio_manual",false):
		item.audio=str(matches[0].path) if not matches.is_empty() and (matches.size()==1 or matches[0].score>matches[1].score) else ""
	var audio_id=PARSER.leading_id(str(item.audio))
	var csv_details:Dictionary=item.get("csv_details",{}).get(audio_id,{}) if not audio_id.is_empty() else {}
	for key in csv_details:
		item[key]=csv_details[key]
		if key in ["title","artist"]:item[key+"_edited"]=true
	if not item.get("background_manual",false):
		var art=candidates(item.image_files,[item.song_id,audio_name],str(item.base),str(item.song_id))
		item.background=str(art[0].path) if not art.is_empty() and (art.size()==1 or art[0].score>art[1].score) else ""
	item.audio_hash="";item.duration=0.0;item.existing=false
	if str(item.audio).is_empty():item.errors.append("Choose the matching audio file." if matches.size()<2 else "Audio match is ambiguous. Choose the correct file.")
	elif file_size(item.audio)<=0 or file_size(item.audio)>150*1024*1024:item.errors.append("Audio is unreadable, empty, or exceeds 150 MB.")
	else:
		item.audio_hash=FileAccess.get_sha256(item.audio)
		if str(item.audio_hash).length()!=64:item.errors.append("Audio could not be verified. Choose a downloaded local file.")
		var format=TX.audio_format(item.audio);var probe=str(item.audio)
		if format.is_empty():item.errors.append("Audio format is unsupported.")
		else:
			var readable=true
			if probe.get_extension().to_lower()!=format:
				var cache=root.path_join(".ssrg_import/cache-%d" % Time.get_ticks_usec());caches.append(cache);DirAccess.make_dir_recursive_absolute(cache)
				probe=cache.path_join("probe."+format)
				var error=TX.copy_audio(item.audio,probe,is_canceled,Callable())
				if not error.is_empty():item.errors.append(error);readable=false
			var stream=SynkLibrary.decode(probe) if readable else null
			if stream==null:item.errors.append("Audio could not be decoded.")
			else:
				item.duration=stream.get_length()
				if not is_finite(float(item.duration)) or item.duration<.2 or item.duration>1200:item.errors.append("Audio must be between 0.2 seconds and 20 minutes.")
			if probe!=str(item.audio):DirAccess.remove_absolute(probe)
	var existing_id=TX.song_id(item,songs)
	for song in songs:
		if str(song.id)!=existing_id:continue
		item.existing=true
		if not original.get("title_edited",false):item.title=str(song.title)
		if not original.get("artist_edited",false):item.artist=str(song.get("artist",item.artist))
		if not original.get("game_edited",false):item.game=str(song.get("ssrg_game",song.get("album",item.game)))
		item.existing_charts=[]
		for keys in [4,7,13]:
			var target=root.path_join("charts/"+str(song.id)+"_lv%d.json" % keys)
			if FileAccess.file_exists(target):item.existing_charts.append({"keys":keys,"replaceable":TX.replacement_allowed(root,song,keys)})
		break
	for chart in item.chart_reports:
		if item.duration>0 and float(chart.end)>float(item.duration)+.001:chart.errors.append("Notes extend past the audio; choose the correct audio. No notes will be trimmed.")
		if chart.errors.is_empty() and int(chart.keys) in [4,7,13]:item.valid_keys.append(int(chart.keys))
		elif not chart.errors.is_empty():item.warnings.append("%d keys excluded: %s" % [int(chart.keys)," ".join(chart.errors)])
		item.warnings.append_array(chart.warnings)
	if item.valid_keys.is_empty():item.errors.append("No supported, valid difficulty is selected.")
	if not item.has("selected_keys"):item.selected_keys=item.valid_keys.duplicate()
	else:item.selected_keys=item.selected_keys.filter(func(key):return int(key) in item.valid_keys)
	var sidecar=""
	for folder in [str(item.chart_files[0]).get_base_dir(),str(item.base)]:
		if FileAccess.file_exists(folder.path_join("presentation.json")):sidecar=folder.path_join("presentation.json");break
	if not sidecar.is_empty():
		var config=TX.read_json(sidecar,{}) if file_size(sidecar)<=256*1024 else {}
		if config is Dictionary and not config.is_empty():
			if config.get("tempo_map",[]) is Array and config.get("tempo_map",[]).size()>1:item.errors.append("Variable-tempo metadata is unsupported; source timing is retained for a future importer.")
			var cards=[]
			for value in config.get("cards",[]):
				if not value is Dictionary:continue
				var card=value.duplicate(true);var path=str(card.get("portrait",""))
				if not path.is_empty():
					if not path.is_absolute_path():path=sidecar.get_base_dir().path_join(path).simplify_path()
					if not path.begins_with(str(item.base)+"/") or not FileAccess.file_exists(path):item.warnings.append("A card portrait is outside the selected song folder or missing.");continue
					card.portrait=path
				cards.append(card)
			config.cards=cards;item.presentation=config
		else:item.warnings.append("presentation.json is invalid or too large; metadata excluded.")
	if not str(item.background).is_empty():
		if file_size(item.background)>12*1024*1024 or Image.load_from_file(ProjectSettings.globalize_path(item.background))==null:item.errors.append("Background is unreadable or exceeds 12 MB. Choose another image or remove it.")
	item.ready=item.errors.is_empty() and not item.selected_keys.is_empty()
	if item.existing and not original.get("include_edited",false):
		item.include=item.valid_keys.any(func(keys):return not FileAccess.file_exists(root.path_join("charts/"+TX.song_id(item,songs)+"_lv%d.json" % int(keys))))
	return item

func recheck(index:int,changes:Dictionary,songs:Array) -> void:
	if busy() or index<0 or index>=plan.size():return
	plan[index].merge(changes,true);plan[index].erase("selected_keys");canceled=false
	update({"phase":"scanning","message":"Rechecking selected song…"})
	var snapshot=songs.duplicate(true)
	task=WorkerThreadPool.add_task(func():
		plan[index]=inspect_item(plan[index],snapshot);publish("review","Song checked. Review the updated matches."))

func begin_import() -> void:
	if busy():return
	queue.clear();reports.clear();canceled=false;selection_count=0
	for i in plan.size():
		if plan[i].get("include",true) and plan[i].get("ready",false):queue.append(i)
	selection_count=queue.size();importing=true
	update({"phase":"importing","message":"Preparing selected songs…","done":0,"total":selection_count,"reports":[]})

func advance(songs:Array) -> void:
	if not importing or task>=0 or not prepared.is_empty():return
	if is_canceled() or queue.is_empty():
		if is_canceled():
			for i in queue:reports.append({"index":i,"title":plan[i].title,"outcome":"canceled","message":"Not imported after cancellation."})
		queue.clear();importing=false
		publish("done","Import canceled; completed songs are kept." if is_canceled() else "Import finished. Review the results below.")
		return
	current=int(queue.pop_front());var item=plan[current].duplicate(true);var snapshot=songs.duplicate(true)
	update({"phase":"importing","message":"Preparing "+str(item.title),"done":reports.size(),"total":selection_count,"bytes_done":0,"bytes_total":0})
	task=WorkerThreadPool.add_task(func():
		prepared=TX.prepare(root,item,snapshot,is_canceled,func(done,total):update({"message":"Copying "+str(item.title),"bytes_done":done,"bytes_total":total}))
		update({"phase":"prepared","message":"Saving "+str(item.title)}))

func commit_prepared(songs:Array) -> Dictionary:
	if task>=0 or prepared.is_empty():return {}
	var result:Dictionary
	if is_canceled() and prepared.has("folder"):
		TX.remove_private_tree(prepared.folder);result={"error":"Canceled"}
	else:result=TX.commit(root,prepared,songs)
	var outcome=str(result.get("outcome","failed" if result.has("error") else "skipped"))
	if result.get("error","")=="Canceled":outcome="canceled"
	reports.append({"index":current,"title":plan[current].title,"outcome":outcome,"message":str(result.get("error",result.get("reason",""))),"warnings":result.get("warnings",[]),"keys":result.get("keys",[])})
	prepared={};update({"phase":"importing","done":reports.size(),"reports":reports.duplicate(true)})
	return result

func retry_failed() -> void:
	if busy():return
	for item in plan:item.include=false
	for report in reports:
		if report.outcome in ["failed","canceled"]:plan[int(report.index)].include=true
	publish("review","Failed and canceled songs selected. Correct any matches, then import again.")
