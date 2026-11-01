extends SceneTree
var failures=0
func check(ok:bool,label:String) -> void:
 if not ok:failures+=1;push_error(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var folder="res://.tools/ssrg-presentation-import-%d" % Time.get_ticks_usec()
 DirAccess.make_dir_recursive_absolute(folder)
 var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=8000
 var samples=PackedByteArray();samples.resize(16000);wav.data=samples
 var audio_path=folder.path_join("fixture.wav");check(wav.save_to_wav(audio_path)==OK,"Fixture audio created inside workspace")
 var portrait=Image.create(96,128,false,Image.FORMAT_RGBA8);portrait.fill(Color.CYAN)
 var portrait_path=folder.path_join("card.png");portrait.save_png(portrait_path)
 var chart_path=folder.path_join("fixture.seq");FileAccess.open(chart_path,FileAccess.WRITE).store_string("fixture")
 var sidecar=folder.path_join("presentation.json")
 var metadata={"cards":[{"portrait":portrait_path,"tier":"R"}],"mission_score":3000,"events":[{"order":0,"type":2}]}
 FileAccess.open(sidecar,FileAccess.WRITE).store_string(JSON.stringify(metadata))
 var entry={"charts":{13:chart_path},"audio":audio_path,"background":""}
 var signature=preload("res://scripts/ssrg_import.gd").signature(entry)
 metadata.mission_score=4000;FileAccess.open(sidecar,FileAccess.WRITE).store_string(JSON.stringify(metadata))
 check(preload("res://scripts/ssrg_import.gd").signature(entry)!=signature,"Sidecar content changes invalidate scanned signature even within one timestamp tick")
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame;await process_frame
 game.library=SynkLibrary.new(folder)
 var note=SynkChart.note(.2,4);note.ssrg_order=0
 var chart={"notes":[note],"bpm":120.0,"beat_offset":0.0}
 var result=game.ssrg_playables.store_song(audio_path,{13:chart},{"title":"Presentation fixture","presentation":metadata})
 check(not result.has("error") and result.get("saved",0)==1,"Presentation metadata imports with valid chart/audio")
 if not result.has("error"):
  var restored=SynkLibrary.new(folder)
  check(restored.songs.size()==1,"Isolated library persisted one fixture song")
  var config:Dictionary=restored.songs[0].ssrg_presentation
  check(int(config.mission_score)==4000 and config.events.size()==1,"Mission and explicit event schedule survive library reload")
  var copied=str(config.cards[0].portrait)
  check(copied.begins_with(folder) and copied!=portrait_path and FileAccess.file_exists(copied),"Card artwork is copied into the song's own storage")
  var saved_image=Image.load_from_file(ProjectSettings.globalize_path(copied))
  check(saved_image!=null and saved_image.get_size()==Vector2i(96,128),"Stored card artwork preserves source dimensions")
  check(not note.has("ssrg_special"),"Import never changes the source chart dictionary")
 game.queue_free();await process_frame
 print("SSRG presentation import/persistence failures: ",failures);quit(failures)
