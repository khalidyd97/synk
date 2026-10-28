extends RefCounted
## Source TrackInfo/ContainsTrack routing for imported SSRG playables.
const Rules=preload("res://scripts/ssrg_input_rules.gd")
const State=preload("res://scripts/ssrg_sustain_rules.gd").TrackState
const GLOBAL_AREA=Rect2(-610.6000366,-319.0400085,1221.2000732,444.7200012)
var tracks: Dictionary={}
var consumed: Dictionary={}
var frame_token: Variant=null

func reset() -> void:
	tracks.clear();consumed.clear();frame_token=null

func begin_frame(token: Variant) -> void:
	if frame_token==token:return
	frame_token=token;consumed.clear()
	for track in tracks.values():
		if track.state in [State.LOST,State.ENDED]:track.state=State.IDLE;track.pointer=-999

static func raw_channel(point:Vector2,keys:int) -> int:
	for slot in keys:
		var channel=slot*(12/(keys-1))
		if Rules.contains_lane(point,channel,keys):return channel
	return Rules.side_channel(point,keys)

static func node_geometry(channel:int,at:float,now:float,travel:float,sustain:bool=true) -> Dictionary:
	var q=pow(maxf(0,1.0+(now-at)/maxf(.001,travel)),6.0)
	var center=Vector2(Rules.channel_center(channel)*q,280.0-514.0*q)
	var size=Vector2(212*1.1,116*(2.5 if sustain else 2.0))*q
	return {"center":center,"rect":Rect2(center-size*.5,size),"q":q}

func track(channel:int) -> Dictionary:
	if not tracks.has(channel):tracks[channel]={"state":State.IDLE,"pointer":-999}
	return tracks[channel]

func parse(id:int,touch:Dictionary,channel:int,phase:int) -> void:
	var old=int(touch.get("ssrg_channel",-1))
	var current=track(channel) if channel>=0 else {}
	var previous=track(old) if old>=0 else {}
	if phase==0:
		if channel>=0:current.state=State.BEGAN;current.pointer=id
	elif phase in [1,2]:
		if channel>=0 and (current.state==State.HELD or (old>=0 and previous.state in [State.BEGAN,State.MOVED,State.HELD])):
			current.state=State.HELD if channel==old else State.MOVED;current.pointer=id
	elif phase in [3,4]:
		if channel>=0:current.state=State.IDLE if phase==4 else State.ENDED;current.pointer=-999
		if old>=0 and old!=channel:previous.state=State.IDLE if phase==4 else State.ENDED;previous.pointer=-999
		touch.ssrg_channel=channel
		return
	# Keep a crossing finger from clearing a channel another touch has just
	# acquired in this batch. This identity guard is a SYNK safety adaptation.
	if old>=0 and old!=channel and previous.pointer==id:
		if previous.state!=State.ENDED:previous.state=State.LOST
		previous.pointer=-999
	touch.ssrg_channel=channel

func route(pointers:Dictionary,candidates:Array,keys:int,token:Variant) -> void:
	begin_frame(token)
	# Dictionary insertion order matches the source active touch pool's order.
	for id in pointers:
		var touch:Dictionary=pointers[id]
		var point:Vector2=touch.ssrg_ui
		var phase=int(touch.get("ssrg_phase",2))
		var raw=raw_channel(point,keys)
		if not GLOBAL_AREA.has_point(point):
			touch.ssrg_aim={};touch.ssrg_origin=-1
			parse(int(id),touch,-1,phase)
			continue
		var aim:Dictionary=touch.get("ssrg_aim",{})
		if not aim.is_empty():
			var still_pending=false
			for candidate in candidates:
				if candidate.token==aim.token:
					aim=candidate;still_pending=true;break
			aim.pending=still_pending
		var best=point.distance_to(aim.center) if not aim.is_empty() else INF
		var found=false
		if phase in [0,1,2]:
			for candidate in candidates:
				if not candidate.rect.has_point(point):continue
				if phase!=0 and (not candidate.sustain or candidate.owner!=id or not candidate.eligible):continue
				if phase==0 and candidate.sustain:continue
				if not aim.is_empty() and candidate.token==aim.token:
					found=true;continue
				var distance=point.distance_to(candidate.center)
				if distance<best or (not aim.is_empty() and not aim.get("pending",true)) or (phase==0 and not aim.is_empty() and candidate.q>aim.q):
					best=distance;aim=candidate
					found=true
		if raw!=int(touch.get("ssrg_origin",-1)) and not found:
			aim={}
		touch.ssrg_origin=raw;touch.ssrg_aim=aim
		var channel=int(aim.channel) if not aim.is_empty() else raw
		parse(int(id),touch,channel,phase)

func consume(channel:int) -> bool:
	if consumed.has(channel):return false
	consumed[channel]=true;return true
