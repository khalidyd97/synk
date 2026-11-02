extends SceneTree
const CLIENT=preload("res://scripts/music_recognition.gd")
var failures=0
func check(ok:bool,label:String):
 if not ok:failures+=1;push_error(label)
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1564,720);AudioServer.set_bus_mute(0,true)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame;await process_frame
 game.set_process(false);game.app_login.hide()
 for child in game.get_children():
  if child is CanvasLayer and child.layer>=90:child.hide()
 var audio=AudioStreamWAV.new();audio.format=AudioStreamWAV.FORMAT_16_BITS;audio.mix_rate=22050
 var samples=PackedByteArray();samples.resize(22050*16*2)
 for i in 22050*16:samples.encode_s16(i*2,roundi(sin(i*TAU*440/22050)*12000))
 audio.data=samples;audio.save_to_wav("user://songs/recognition-test.wav")
 var path="user://songs/recognition-test.wav"
 check(ClassDB.class_exists("SynkChromaprint"),"Native Chromaprint loads")
 var native=ClassDB.instantiate("SynkChromaprint")
 check(native.fingerprint(PackedByteArray([0]),44100).is_empty(),"Malformed PCM is rejected")
 var official="res://.tools/acoustid/chromaprint-1.6.2/tests/data/test_mono_11025.raw"
 var known=FileAccess.get_file_as_bytes(official)
 check(not native.fingerprint(known,11025).is_empty(),"Real reference audio creates a fingerprint")
 var fixture=CLIENT.prepare("res://.tools/acoustid/chromaprint-1.6.2/tests/data/test.mp3","test-key",44100)
 FileAccess.open("res://.tools/acoustid/fixture-request.txt",FileAccess.WRITE).store_buffer(fixture.body)
 var checks={"status":"ok","results":[{"score":.2,"recordings":[{"title":"Uncertain"}]}]}
 check(CLIENT.parse(JSON.stringify(checks).to_utf8_buffer()).has("error"),"Weak matches do not overwrite metadata")
 checks.results[0].score=.95;checks.results[0].recordings[0].artists=[{"name":"Artist"}]
 checks.results[0].recordings[0].releasegroups=[{"id":"ddaa2d4d-314e-3e7c-b1d0-f6d207f5aa2f","title":"Album","type":"Album"}]
 var parsed=CLIENT.parse(JSON.stringify(checks).to_utf8_buffer()).details
 check(parsed.album=="Album" and parsed.artist=="Artist" and parsed.artwork_url.ends_with("/front-500"),"MusicBrainz album and Cover Art Archive metadata are parsed")
 var prepared=CLIENT.prepare(path,"test-key",44100)
 check(not prepared.has("error"),"Audio excerpt prepares")
 if not prepared.has("error"):
  check(prepared.body.size()<20000 and "fingerprint=" in prepared.body.get_string_from_utf8() and "duration=16" in prepared.body.get_string_from_utf8(),"Request contains only the fingerprint and full duration, with no audio")
  check(not "RIFF" in prepared.body.get_string_from_utf8(),"Raw audio is never uploaded")
 check(CLIENT.parse('{"status":"ok","results":[]}'.to_utf8_buffer()).has("error"),"No match is handled")
 check(CLIENT.parse('{"status":"error"}'.to_utf8_buffer()).has("error"),"Service errors are handled")
 check("application key" in CLIENT.parse('{"status":"error","error":{"code":4}}'.to_utf8_buffer()).error,"Invalid application keys have a clear error")
 check("busy" in CLIENT.parse('{"status":"error","error":{"code":14}}'.to_utf8_buffer()).error,"Rate limits are reported correctly")
 check(CLIENT.parse('not-json'.to_utf8_buffer()).has("error"),"Invalid response is handled")
 var id="recognition-test".sha256_text()
 game.library.songs.append({"id":id,"title":"Original title","artist":"Original artist","file":"recognition-test.wav","ssrg":{},"ssrg_charts":[{"keys":7,"variant":"7k","notes":1,"density":1,"length":16}]})
 game.prefs.set_value("ssrg","preview",false);game.open_ssrg_playables();game.open_song_details(id)
 var view=game.song_details
 check(view.visible and not game.ssrg_playables.visible,"Song Details opens from SSRG")
 view.recognition.endpoint="http://127.0.0.1:18793/";view.recognition_token.text="test-key"
 view.start_recognition()
 for i in 600:
  if not view.recognition.busy:break
  await process_frame
 check(view.fields.title.text=="Recognized track" and view.fields.artist.text=="Recognized artist","Fingerprint lookup fills editable details")
 check(game.song_details_entry(id).title=="Original title","Recognition never saves automatically")
 view.cancel();check(game.ssrg_playables.visible and not view.visible,"Cancel returns to SSRG")
 check(game.song_details_entry(id).title=="Original title","Cancel preserves existing details")
 game.open_song_details(id);view.recognition_completed({"title":"Saved recognition","artist":"Matched artist","album":"Matched album","track":3},"")
 view.save();check(game.song_details_entry(id).title=="Saved recognition","Save applies reviewed recognition")
 game.open_song_details(id);CLIENT.next_lookup_ms=0;view.start_recognition();view.cancel()
 for i in 40:await process_frame
 check(not view.recognition.busy and not view.visible,"Closing cancels recognition and ignores late results")
 game.queue_free();await process_frame
 print("Music recognition regression failures: ",failures);quit(failures)
