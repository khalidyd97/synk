extends SceneTree
# Songs that have only some of the 4/7/13-key levels still import with what they have.
const F=preload("res://godot_tests/ssrg_import_fixtures.gd")
const JOB=preload("res://scripts/ssrg_import_job.gd")
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func song(folder:String,keys:Array) -> void:
	DirAccess.make_dir_recursive_absolute(folder);F.audio(folder.path_join("artist_song.wav"))
	for count in keys:F.write(folder.path_join("artist_song_%d.seq" % count),F.raw([[64,0,0,0],[128,4,0,11],[192,8,0,12]]))
func _initialize():
	var folder=F.folder("ssrg-partial-levels")
	var cases={"only7":[7],"only13":[13],"four_and_thirteen":[4,13],"all":[4,7,13]}
	for name in cases:song(folder.path_join(name),cases[name])
	var job=JOB.new();job.root=folder.path_join("library")
	job._scan(PackedStringArray([folder]),[])
	check(job.plan.size()==cases.size(),"Every song is found (%d)" % job.plan.size())
	for item in job.plan:
		var wanted:Array=cases[str(item.base).get_file()]
		var have:Array=item.selected_keys.duplicate();have.sort()
		check(item.ready,"%s is ready: %s" % [str(item.base).get_file(),str(item.errors)])
		check(have==wanted,"%s imports the levels it has: %s" % [str(item.base).get_file(),str(have)])
	# Two files that are both the 7-key level: the song still imports, with one of them.
	var twice=folder.path_join("twice");song(twice,[7]);F.write(twice.path_join("artist_song_7b.seq"),F.raw([[64,0,0,0],[128,4,0,11],[192,8,0,12]]))
	var item=job.inspect_item({"source_key":twice,"base":twice,"song_id":"artist_song","game":"twice","chart_files":[twice.path_join("artist_song_7.seq"),twice.path_join("artist_song_7b.seq")],"key_overrides":{twice.path_join("artist_song_7b.seq"):7},"audio":"","audio_manual":false,"background":"","background_manual":false,"policy":"add_missing","include":true,"audio_files":PackedStringArray([twice.path_join("artist_song.wav")]),"image_files":PackedStringArray()},[])
	check(item.ready and item.selected_keys==[7],"A duplicate level file does not block the song: %s" % str(item.errors))
	job.shutdown()
	print("SSRG partial levels failures: ",failures);quit(failures)
