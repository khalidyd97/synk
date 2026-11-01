extends SceneTree
const F=preload("res://godot_tests/ssrg_import_fixtures.gd")
const TX=preload("res://scripts/ssrg_import_transaction.gd")
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func _initialize():
	var folder=F.folder("ssrg-import-transactions");var source=F.source(folder.path_join("input"));var root=folder.path_join("library")
	var library=SynkLibrary.new(root);var id=FileAccess.get_sha256(source.audio)
	var item={"audio":source.audio,"audio_hash":id,"charts":{4:source.chart},"selected_keys":[4],"title":"Transaction fixture","artist":"Artist","game":"Fixture","policy":"add_missing"}
	var prepared=TX.prepare(root,item,library.songs)
	check(not prepared.has("error"),"Valid song prepares privately")
	check(library.songs.is_empty() and not FileAccess.file_exists(root.path_join("songs/library.json")),"Preparation never publishes a partial song")
	var result=TX.commit(root,prepared,library.songs)
	check(not result.has("error") and result.saved==1,"Song, source chart, and index commit together")
	if result.has("error"):print(result);quit(1);return
	library.songs=result.songs
	var path=root.path_join("charts/"+id+"_lv4.json");var old_hash=FileAccess.get_sha256(path)
	var saved=TX.read_json(path,{})
	check(FileAccess.get_file_as_bytes(root.path_join(saved.ssrg_source.original_file))==FileAccess.get_file_as_bytes(source.chart),"Exact original SEQ remains recoverable")
	check(TX.replacement_allowed(root,library.songs[0],4),"New import baseline identifies unchanged chart")
	check(TX.prepare(root,item,library.songs).get("skipped",false),"Add missing skips existing difficulty without rewriting it")
	item.policy="replace_imported"
	F.write(source.chart,F.raw([[64,0,0,0],[192,4,0,0]]))
	prepared=TX.prepare(root,item,library.songs)
	check(not prepared.has("error") and not prepared.has("skipped"),"Unchanged imported chart can be replaced explicitly")
	var journal=prepared.duplicate(true);journal.state="committing"
	TX.json_file(journal.folder.path_join("new/library.json"),[{"id":id,"title":"Interrupted"}])
	TX.add_operation(root,journal,"songs/library.json","new/library.json")
	SynkLibrary.atomic_write(journal.folder.path_join("journal.json"),journal)
	for i in mini(2,journal.ops.size()):
		var op=journal.ops[i];DirAccess.make_dir_recursive_absolute(root.path_join(op.target).get_base_dir());assert(DirAccess.rename_absolute(journal.folder.path_join(op.staged),root.path_join(op.target))==OK)
	check(FileAccess.get_sha256(path)!=old_hash,"Fixture simulates interruption after chart replacement")
	check(not TX.recover(root).is_empty() and FileAccess.get_sha256(path)==old_hash,"Crash recovery restores the previous chart")
	check(TX.read_json(root.path_join("songs/library.json"),[])[0].title=="Transaction fixture","Crash recovery preserves previous library index")
	var edited=TX.read_json(path,{});edited.notes[0].lane=1;TX.json_file(path,edited)
	var edited_hash=FileAccess.get_sha256(path)
	check(TX.prepare(root,item,library.songs).get("skipped",false),"Edited chart is protected from replacement")
	check(FileAccess.get_sha256(path)==edited_hash,"Edited chart bytes remain untouched")
	TX.json_file(path,saved);DirAccess.make_dir_recursive_absolute(root.path_join("drafts"));TX.json_file(root.path_join("drafts/"+id+"_lv4.json"),{"notes":[]})
	check(TX.prepare(root,item,library.songs).get("skipped",false),"A draft protects even an otherwise unchanged imported chart")
	var new_source=F.source(folder.path_join("second"),7);var new_item=item.duplicate(true);new_item.charts={7:new_source.chart};new_item.selected_keys=[7]
	new_item.audio=new_source.audio
	prepared=TX.prepare(root,new_item,library.songs,func():return true)
	check(prepared.get("error","")=="Canceled","Cancellation during preparation leaves no partial song")
	new_item.parsed_charts={7:{"bpm":120,"notes":[SynkChart.note(3.0,0)]}}
	prepared=TX.prepare(root,new_item,library.songs)
	check(prepared.get("error","").contains("beyond the audio"),"Out-of-audio notes cause a visible failure, never truncation")
	check(not FileAccess.file_exists(root.path_join("charts/"+id+"_lv7.json")),"Failed difficulty never appears in live storage")
	print("SSRG import transaction failures: ",failures);quit(failures)
