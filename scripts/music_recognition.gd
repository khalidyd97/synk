extends Node
# Fingerprints stay local until an explicit lookup. Metadata remains a draft until SAVE.
signal completed(details:Dictionary,error:String)
signal progress(message:String)
const ENDPOINT="https://api.acoustid.org/v2/lookup"
const SECONDS=120.0
static var next_lookup_ms=0
var endpoint=ENDPOINT
var fallback_endpoint="https://api.audd.io/"
var fallback_token=""
var audio_path=""
var provider="AcoustID"
var request:HTTPRequest
var worker=Thread.new()
var preparing=false
var busy=false
var result:Dictionary={}
var fetching_art=false
func _ready():
 if not ClassDB.class_exists("SynkChromaprint") and OS.get_name() in ["Windows","Android"]:
  GDExtensionManager.load_extension("res://assets/native/chromaprint/chromaprint.gdextension")
 request=HTTPRequest.new();request.timeout=30;request.body_size_limit=4*1024*1024;request.max_redirects=2;request.use_threads=true
 add_child(request);request.request_completed.connect(received)
func recognize(path:String,token:String,audd_token:String="") -> String:
 if busy or preparing:return "Recognition is already running."
 if token.strip_edges().is_empty():return "Add your AcoustID application key first."
 if not ClassDB.class_exists("SynkChromaprint"):return "Chromaprint is unavailable on this platform."
 if Time.get_ticks_msec()<next_lookup_ms:return "Wait a moment before recognizing another song."
 if not FileAccess.file_exists(path):return "The song audio is unavailable."
 busy=true;preparing=true;result={};fetching_art=false
 provider="AcoustID";audio_path=path;fallback_token=audd_token.strip_edges()
 next_lookup_ms=Time.get_ticks_msec()+1000
 var error=worker.start(prepare.bind(path,token.strip_edges(),int(AudioServer.get_mix_rate())))
 if error!=OK:busy=false;preparing=false;return "Could not prepare the audio."
 return ""
static func prepare(path:String,token:String,rate:int) -> Dictionary:
 var stream=SynkLibrary.decode(path)
 if stream==null:return {"error":"This audio format cannot be recognized."}
 var duration=minf(SECONDS,stream.get_length())
 if duration<5:return {"error":"The audio is too short to recognize."}
 var playback=stream.instantiate_playback();playback.start(0)
 var pcm=PackedByteArray();var frames=int(duration*rate);pcm.resize(frames*2)
 var offset=0
 while offset<frames:
  var samples=playback.mix_audio(1.0,mini(4096,frames-offset))
  if samples.is_empty():break
  for sample in samples:
   var mono=clampf((sample.x+sample.y)*.5,-1,1)
   pcm.encode_s16(offset*2,roundi(mono*32767));offset+=1
 playback.stop();pcm.resize(offset*2)
 if pcm.is_empty():return {"error":"Could not read an audio sample."}
 var native=ClassDB.instantiate("SynkChromaprint")
 var fingerprint=str(native.fingerprint(pcm,rate))
 if fingerprint.length()<8:return {"error":"Could not fingerprint this audio."}
 var fields={"client":token,"duration":str(roundi(stream.get_length())),"fingerprint":fingerprint,"meta":"recordings releasegroups releases tracks","format":"json"}
 var parts=PackedStringArray()
 for key in fields:parts.append(str(key).uri_encode()+"="+str(fields[key]).uri_encode())
 return {"body":"&".join(parts).to_utf8_buffer(),"type":"Content-Type: application/x-www-form-urlencoded"}

func _process(_delta):
 if not preparing or worker.is_alive():return
 var prepared:Dictionary=worker.wait_to_finish();preparing=false
 if not busy:return
 if prepared.has("error"):finish({},prepared.error);return
 var target=endpoint if provider=="AcoustID" else fallback_endpoint
 var error=request.request_raw(target,PackedStringArray([prepared.type]),HTTPClient.METHOD_POST,prepared.body)
 if error!=OK:finish({},"Could not connect to the recognition service. Check your connection.")
static func parse(body:PackedByteArray) -> Dictionary:
 var parser=JSON.new()
 if parser.parse(body.get_string_from_utf8())!=OK:return {"error":"The recognition service returned an invalid response."}
 var data=parser.data
 if not data is Dictionary:return {"error":"The recognition service returned an invalid response."}
 if data.get("status")!="ok":
  var error=data.get("error",{})
  var code=int(error.get("code",0)) if error is Dictionary else 0
  return {"error":"AcoustID rejected the application key." if code==4 else ("AcoustID is busy. Wait a moment and try again." if code in [13,14] else "AcoustID could not process this fingerprint.")}
 if not data.get("results") is Array:return {"error":"The recognition service returned an invalid response."}
 var candidates=[]
 for candidate in data.results:
  if candidate is Dictionary and (candidate.get("score") is float or candidate.get("score") is int):candidates.append(candidate)
 candidates.sort_custom(func(a,b):return float(a.score)>float(b.score))
 for candidate in candidates:
  if float(candidate.score)<.6:continue
  if not candidate.get("recordings") is Array:continue
  for recording in candidate.recordings:
   if not recording is Dictionary or not recording.get("title") is String or recording.title.strip_edges().is_empty():continue
   var details={"title":recording.title.strip_edges().left(500)}
   var names=PackedStringArray()
   if recording.get("artists") is Array:
    for artist in recording.artists:
     if artist is Dictionary and artist.get("name") is String:names.append(artist.name)
   if not names.is_empty():details.artist=", ".join(names).left(500)
   var release={}
   var group={}
   if recording.get("releasegroups") is Array:
    for item in recording.releasegroups:
     if item is Dictionary:
      if group.is_empty():group=item
      if item.get("type")=="Album":group=item;break
   if not group.is_empty() and group.get("title") is String:details.album=group.title.left(500)
   var releases=recording.get("releases",group.get("releases",[]))
   if releases is Array:
    for item in releases:
     if item is Dictionary:release=item;break
   if not release.is_empty():
    if release.get("title") is String:details.album=release.title.left(500)
    if release.get("mediums") is Array:
     for medium in release.mediums:
      if not medium is Dictionary or not medium.get("tracks") is Array:continue
      for track in medium.tracks:
       if not track is Dictionary:continue
       # Never borrow another recording's track number from the release.
       if str(track.get("recording_id",""))==str(recording.get("id","missing")) and track_number(track.get("position"))>0:details.track=track_number(track.position)
   var id=str(release.get("id",group.get("id","")))
   var valid_id=id.length()==36
   for character in id:
    if not character in "0123456789abcdef-":valid_id=false
   if valid_id:details.artwork_url="https://coverartarchive.org/"+("release/" if not release.is_empty() else "release-group/")+id+"/front-500"
   return {"details":details}
 return {"no_match":true,"error":"No confident match found. Your existing details are unchanged."}

func received(status:int,code:int,_headers:PackedStringArray,body:PackedByteArray):
 if not busy:return
 if fetching_art:
  if status==HTTPRequest.RESULT_SUCCESS and code==200:
   var image=Image.new();var error=image.load_jpg_from_buffer(body)
   if error!=OK:error=image.load_png_from_buffer(body)
   if error!=OK:error=image.load_webp_from_buffer(body)
   if error==OK:result.cover=image
  finish(result,"");return
 if status!=HTTPRequest.RESULT_SUCCESS:finish({},"Recognition failed. Check your connection.");return
 if code!=200:
  var failure=parse(body) if provider=="AcoustID" else parse_audd(body)
  finish({},str(failure.get("error","AcoustID lookup failed. Try again later.")));return
 var parsed=parse(body) if provider=="AcoustID" else parse_audd(body)
 if parsed.has("error"):
  if provider=="AcoustID" and parsed.get("no_match",false) and not fallback_token.is_empty():start_fallback();return
  finish({},parsed.error);return
 result=parsed.details
 var url=str(result.get("artwork_url",""));result.erase("artwork_url")
 if url.begins_with("https://"):
  fetching_art=true
  if request.request(url)==OK:return
 finish(result,"")
func finish(details:Dictionary,error:String):
 busy=false;fetching_art=false;fallback_token="";audio_path=""
 if not details.is_empty():details.provider=provider
 completed.emit(details,error)
func cancel():
 busy=false;request.cancel_request();result={};fetching_art=false;fallback_token="";audio_path=""
func _exit_tree():
 if worker.is_started():worker.wait_to_finish()

func start_fallback() -> void:
 provider="AudD";preparing=true
 progress.emit("No AcoustID match. Trying AudD with a 12-second excerpt…")
 var error=worker.start(prepare_audd.bind(audio_path,fallback_token,int(AudioServer.get_mix_rate())))
 if error!=OK:preparing=false;finish({},"Could not prepare the AudD fallback.")

static func prepare_audd(path:String,token:String,rate:int) -> Dictionary:
 var stream=SynkLibrary.decode(path)
 if stream==null:return {"error":"This audio format cannot be recognized."}
 var duration=minf(12,stream.get_length())
 if duration<1:return {"error":"The audio is too short to recognize."}
 var playback=stream.instantiate_playback();playback.start(minf(24,maxf(0,(stream.get_length()-duration)*.5)))
 var pcm=PackedByteArray();var frames=int(duration*rate);pcm.resize(frames*2);var offset=0
 while offset<frames:
  var samples=playback.mix_audio(1.0,mini(4096,frames-offset))
  if samples.is_empty():break
  for sample in samples:
   pcm.encode_s16(offset*2,roundi(clampf((sample.x+sample.y)*.5,-1,1)*32767));offset+=1
 playback.stop();pcm.resize(offset*2)
 if pcm.is_empty():return {"error":"Could not read an audio sample."}
 var wav=PackedByteArray();wav.resize(44)
 wav.encode_u32(0,0x46464952);wav.encode_u32(4,36+pcm.size());wav.encode_u32(8,0x45564157)
 wav.encode_u32(12,0x20746d66);wav.encode_u32(16,16);wav.encode_u16(20,1);wav.encode_u16(22,1)
 wav.encode_u32(24,rate);wav.encode_u32(28,rate*2);wav.encode_u16(32,2);wav.encode_u16(34,16)
 wav.encode_u32(36,0x61746164);wav.encode_u32(40,pcm.size());wav.append_array(pcm)
 var boundary="SynkFallback"+str(Time.get_ticks_usec())
 var body=("--%s\r\nContent-Disposition: form-data; name=\"api_token\"\r\n\r\n%s\r\n--%s\r\nContent-Disposition: form-data; name=\"return\"\r\n\r\napple_music,spotify\r\n--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"excerpt.wav\"\r\nContent-Type: audio/wav\r\n\r\n" % [boundary,token,boundary,boundary]).to_utf8_buffer()
 body.append_array(wav);body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
 return {"body":body,"type":"Content-Type: multipart/form-data; boundary="+boundary}

static func parse_audd(body:PackedByteArray) -> Dictionary:
 var parser=JSON.new()
 if parser.parse(body.get_string_from_utf8())!=OK or not parser.data is Dictionary:return {"error":"AudD returned an invalid response."}
 var data:Dictionary=parser.data
 if data.get("status")!="success":return {"error":"AudD fallback failed. Check its token and account allowance."}
 var match_data=data.get("result")
 if not match_data is Dictionary or not match_data.get("title") is String or match_data.title.strip_edges().is_empty():return {"error":"Neither service found a match. Your existing details are unchanged."}
 var details={}
 for key in ["title","artist","album"]:
  if match_data.get(key) is String and not match_data[key].strip_edges().is_empty():details[key]=match_data[key].strip_edges().left(500)
 var apple=match_data.get("apple_music",{})
 if apple is Dictionary:
  if track_number(apple.get("trackNumber"))>0:details.track=track_number(apple.trackNumber)
  var art=apple.get("artwork",{})
  if art is Dictionary and art.get("url") is String:details.artwork_url=art.url.replace("{w}","600").replace("{h}","600")
 var spotify=match_data.get("spotify",{})
 if spotify is Dictionary:
  if not details.has("track") and track_number(spotify.get("track_number"))>0:details.track=track_number(spotify.track_number)
  var album=spotify.get("album",{})
  if not details.has("artwork_url") and album is Dictionary and album.get("images") is Array:
   for image in album.images:
    if image is Dictionary and image.get("url") is String:details.artwork_url=image.url;break
 return {"details":details}

static func track_number(value:Variant) -> int:
 if value is float or value is int:
  return int(value) if value>0 and value<10000 and value==floor(value) else 0
 if value is String and value.is_valid_int():return clampi(int(value),0,9999)
 return 0
