extends SceneTree
const LOOKUP=preload("res://scripts/ssrg_cover_lookup.gd")
var failures=0
func check(ok:bool,message:String)->void:
	if not ok:failures+=1;push_error(message)
func _initialize()->void:run.call_deferred()
func run()->void:
	var entry={"id":"12345678-1234-1234-1234-123456789abc","title":"Love & Letter","artist-credit":[{"name":"Seventeen"}]}
	check(LOOKUP.unique_group({"release-groups":[entry]},"Love & Letter","SEVENTEEN")==entry.id,"Exact album and artist resolves")
	check(LOOKUP.unique_group({"release-groups":[entry]},"Other Album","Seventeen").is_empty(),"Different album is rejected")
	check(LOOKUP.unique_group({"release-groups":[entry,entry.merged({"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"},true)]},"Love & Letter","Seventeen").is_empty(),"Ambiguous editions require manual selection")
	print("SSRG cover lookup failures: ",failures);quit(0 if failures==0 else 1)
