extends SceneTree
const CSV=preload("res://scripts/ssrg_import_csv.gd")
var failures=0
func check(ok:bool,message:String)->void:
	if not ok:failures+=1;push_error(message)
func _initialize()->void:run.call_deferred()
func run()->void:
	var path="user://song-details-test.csv"
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string("Song ID,Song Title,Artist,Album,Track Number\n1004,\"Very Nice, Live\",Seventeen,Love & Letter,3\n10040,Other,Other Artist,Other Album,4\n")
	file.close()
	var result=CSV.read(path)
	check(str(result.error).is_empty(),"CSV accepts common song detail headings")
	check(result.songs.has("1004") and result.songs.has("10040"),"IDs remain distinct")
	check(result.songs.get("1004",{}).get("title","")=="Very Nice, Live","Quoted commas stay in titles")
	check(result.songs.get("1004",{}).get("artist","")=="Seventeen","Artist is mapped")
	check(result.songs.get("1004",{}).get("album","")=="Love & Letter","Album is mapped")
	check(result.songs.get("1004",{}).get("track",0)==3,"Track number is mapped")
	print("SSRG CSV metadata failures: ",failures)
	quit(0 if failures==0 else 1)
