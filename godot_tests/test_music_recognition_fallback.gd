extends SceneTree
const CLIENT=preload("res://scripts/music_recognition.gd")
var failures=0
var outcome={}
var events=[]
func check(ok:bool,label:String):
 if not ok:failures+=1;push_error(label)
func _initialize():run.call_deferred()
func lookup(client:Node,route:String,token:String):
 outcome={};events.clear();CLIENT.next_lookup_ms=0;client.endpoint="http://127.0.0.1:18793/"+route
 var error=client.recognize("user://fallback.wav","test-key",token)
 check(error.is_empty(),"Recognition starts")
 for i in 1200:
  if not client.busy:break
  await process_frame
 check(not client.busy,"Recognition finishes")
func run():
 var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=44100
 var pcm=PackedByteArray();pcm.resize(44100*16*2)
 for i in 44100*16:pcm.encode_s16(i*2,roundi(sin(i*TAU*440/44100)*12000))
 wav.data=pcm;wav.save_to_wav("user://fallback.wav")
 var client=CLIENT.new();root.add_child(client);client.fallback_endpoint="http://127.0.0.1:18793/audd"
 client.completed.connect(func(details,error):outcome={"details":details,"error":error})
 client.progress.connect(func(message):events.append(message))
 await lookup(client,"match","fallback-key")
 check(outcome.details.title=="Primary track" and events.is_empty(),"Confident primary match never invokes AudD")
 await lookup(client,"nomatch","fallback-key")
 check(outcome.details.title=="Fallback track" and outcome.details.provider=="AudD" and outcome.details.track==4,"No-match invokes AudD and parses its metadata")
 check(events.size()==1,"Fallback is attempted once")
 await lookup(client,"weak","fallback-key")
 check(outcome.details.title=="Fallback track","Weak matches use fallback")
 await lookup(client,"nomatch","")
 check(not outcome.error.is_empty() and events.is_empty(),"Blank fallback token prevents audio upload")
 await lookup(client,"error","fallback-key")
 check("application key" in outcome.error and events.is_empty(),"Primary service errors never trigger paid fallback")
 var cancel_callback=func(_message):client.cancel()
 client.progress.connect(cancel_callback)
 await lookup(client,"nomatch","fallback-key")
 for i in 60:await process_frame
 check(outcome.is_empty() and not client.busy,"Closing during fallback preparation suppresses requests and late results")
 client.queue_free();await process_frame
 print("AudD fallback regression failures: ",failures);quit(failures)
