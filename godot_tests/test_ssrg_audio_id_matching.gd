extends SceneTree
const P=preload("res://scripts/ssrg_import.gd")
const JOB=preload("res://scripts/ssrg_import_job.gd")
const F=preload("res://godot_tests/ssrg_import_fixtures.gd")
var failures=0
func check(ok:bool,label:String):
 if not ok:failures+=1;push_error(label)
func _initialize():run.call_deferred()
func run():
 for name in ["1004_13.seq","1004.seq","1004_1.seq","1004_7.seq.bytes","1004.a.bytes.ogg"]:check(P.song_key(name)=="1004","Leading ID is stable: "+name)
 check(P.level_hint("1004_13.seq")==13 and P.level_hint("1004.seq")==0,"Level suffix is optional and separate from song ID")
 check(P.song_key("artist_song_7.seq")=="artist_song","Named imports remain supported")
 var matches=JOB.candidates(PackedStringArray(["/local/10040.ogg","/local/wrong_title.ogg","/other/1004.a.bytes.ogg"]),["wrong_title.ogg","1004"],"/local","1004")
 check(matches[0].path=="/other/1004.a.bytes.ogg" and matches.all(func(value):return value.path!="/local/10040.ogg"),"Exact ID outranks header and folder, without prefix collisions")
 matches=JOB.candidates(PackedStringArray(["/same/1004.a.ogg","/same/1004.b.ogg"]),["1004"],"/same","1004")
 check(matches.size()==2 and matches[0].score==matches[1].score,"Multiple audio variants remain ambiguous")
 check(P.find_file(PackedStringArray(["/10040.ogg","/1004.a.bytes.ogg"]),["1004"],[],"1004")=="/1004.a.bytes.ogg","Legacy folder scanner uses the same safe ID matching")
 check(P.match_score("99.a.bytes.ogg",["99"],"99")>0,"Short numeric IDs work")
 var folder=F.folder("id-matching");var source=F.source(folder)
 var audio=folder.path_join("1004.a.bytes.wav");DirAccess.copy_absolute(source.audio,audio)
 for suffix in ["_13",""]:
  var chart=folder.path_join("1004"+suffix+".seq");F.write(chart,F.raw([[64,0,0,0],[128,1,0,0],[192,12,0,0]]))
  var job=JOB.new();job.root=folder.path_join("library");job.target_game="TEST";job.scan(PackedStringArray([audio,chart]),[])
  for i in 600:
   job.poll()
   if not job.busy():break
   await process_frame
  check(job.plan.size()==1 and job.plan[0].audio==audio and job.plan[0].song_id=="1004","Scanner maps audio by ID with suffix '"+suffix+"'")
  check(job.plan[0].charts.has(13),"13-key level is read with or without a suffix")
  job.shutdown()
 print("SSRG audio ID matching failures: ",failures);quit(failures)
