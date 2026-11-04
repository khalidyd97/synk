extends Node
# Offline presentation model. Packaged fever thresholds/grade points; no server rewards.
const DATA=preload("res://scripts/ssrg_presentation_data.gd")
var game:Control
var state=0
var gauge=0.0
var remaining=0
var note_count=1
var weights=[0.0,0.0,0.0,0.0]
var phase_weights=[1.0,0.0,0.0,0.0,0.0,0.0]
var visual_state=0
var transition_from=[1.0,0.0,0.0,0.0,0.0,0.0]
var transition_age=1.0
var shown_gauge=1.0
var beam_color=Color.WHITE
var metadata:Dictionary={}
var collected=0
var triggered_specials:Dictionary={}
var event_age=99.0
var event_kind=-1
var event_item=-1
var best_score=0
var cards:Array=[]
var card_index=0
var active=false
var life=100.0
var difficulty_index=2
var score_rules=preload("res://scripts/ssrg_score_rules.gd").new()
const LIFE_RECOVERY=[1.0,.5,.33340001106262207]
const LIFE_PENALTY=[10.0,20.0,30.0]
func _ready() -> void:
	# Compile/load variants behind the loading screen, not during a chain.
	for type in 5:
		for item in 6:special_art(type,item,0.0)
func reset(count:int,config:Dictionary={},start_state:int=5) -> void:
	note_count=maxi(1,count);metadata=config.duplicate(true)
	state=0;gauge=0;remaining=maxi(1,ceili(note_count/10.0))
	life=100.0
	difficulty_index=0 if game.ssrg_lane_count==4 else (1 if game.ssrg_lane_count==7 else 2)
	score_rules.reset(note_count,game.ssrg_lane_count,metadata)
	# Every run opens in Ultra Rave (the top fever tier); misses still drop it as usual.
	select_state(start_state)
	phase_weights=[0.0,0.0,0.0,0.0,0.0,0.0];phase_weights[state]=1.0
	weights=[float(phase_weights[2]),float(phase_weights[3]),float(phase_weights[4]),float(phase_weights[5])]
	visual_state=state;transition_from=phase_weights.duplicate();transition_age=1.0;shown_gauge=1.0
	beam_color=profile_color(state);collected=0;triggered_specials.clear();event_age=99;event_kind=-1;event_item=-1
	cards=metadata.get("cards",[]).duplicate(true) if metadata.get("cards",[]) is Array else [];card_index=0
	best_score=0
	if game.ssrg_playables and not game.ssrg_playables.running.is_empty():
		var run=game.ssrg_playables.running
		best_score=int(game.ssrg_playables.best(str(run.id),str(run.variant)).get("score",0))
	active=true
func profile_color(index:int) -> Color:
	var c=DATA.PROFILES[clampi(index,0,5)].beam
	return Color(c[0],c[1],c[2],c[3])
func select_state(value:int) -> void:
	state=clampi(value,0,5);gauge=0.0;remaining=maxi(1,ceili(note_count/10.0))
func judged(grade:String,note:Dictionary={}) -> void:
	if not game.ssrg_playable_run or not active:return
	if grade=="MISS":
		game.score=score_rules.settle()
		life=maxf(0.0,life-LIFE_PENALTY[difficulty_index])
		select_state(1 if life>=100.0 else 0)
		return
	var event_key=str(note.get("ssrg_order",hash(note)))
	if note.has("ssrg_special") and not triggered_specials.has(event_key):
		triggered_specials[event_key]=true
		event_kind=clampi(int(note.ssrg_special),0,4);event_item=clampi(int(note.get("ssrg_item",0)),0,5);event_age=0
		if event_kind==0:collected+=1
	if state==0:
		# Packaged JudgementLifeRate is GOOD=0, Perfect/SuperPerfect=1.
		if grade in ["PERFECT","GREAT"]:life=minf(100.0,life+LIFE_RECOVERY[difficulty_index])
		if life>=100.0:select_state(1)
		return
	remaining-=1
	# Native CalcLifeAndFeverState adds ScoreData's default grade points only
	# for PERFECT/S-PERFECT. GOOD consumes the fever entry budget without filling it.
	if grade in ["PERFECT","GREAT"]:gauge+=2.0 if grade=="PERFECT" else 1.0
	if gauge>=threshold():select_state(mini(5,state+1))
	elif remaining<=0:select_state(maxi(1,state-1))
func threshold() -> float:
	return maxf(.001,DATA.FEVER_THRESHOLDS[state]*note_count/100.0)
func gauge_fraction() -> float:
	return clampf(life/100.0,0,1) if state==0 else clampf(gauge/threshold(),0,1)
func _process(delta:float) -> void:
	if not game.uses_ssrg_gameplay():
		active=false;return
	if not active or game.mode!="play" or game.countdown>0 or game.resume_countdown>0 or game.finishing:return
	event_age+=delta
	if cards.size()>1:
		var beats=maxf(1.0,float(metadata.get("card_beats",4.0)))
		var elapsed_beats=maxf(0.0,game.field.world.render_time()-game.chart_offset())*game.chart_bpm()/60.0
		card_index=posmod(floori(elapsed_beats/beats),cards.size())
	if visual_state!=state:
		transition_from=phase_weights.duplicate();transition_age=0.0;visual_state=state
	transition_age=minf(DATA.FADE_IN_SECONDS,transition_age+delta)
	var blend=smoothstep(0.0,DATA.FADE_IN_SECONDS,transition_age)
	# Ultra is the fully charged tier; its visual bar stays charged until that tier ends.
	var target_gauge=1.0 if state==5 else gauge_fraction()
	shown_gauge=lerpf(shown_gauge,target_gauge,1.0-exp(-delta*10.0))
	beam_color=Color(0,0,0,0)
	for index in 6:
		var target=1.0 if index==state else 0.0
		phase_weights[index]=lerpf(float(transition_from[index]),target,blend)
		beam_color+=profile_color(index)*float(phase_weights[index])
	weights=[float(phase_weights[2]),float(phase_weights[3]),float(phase_weights[4]),float(phase_weights[5])]
func special_art(type:int,item:int,beat:float) -> Texture2D:
	var slot=clampi(int(clampf(beat,0,1)*11.989999771),0,11)
	var group=""
	if type==0:group="s1"+str([2,3,4,5,6,6,6,6,6,6,6,1][slot])
	elif type==1:group="s5"+str([2,3,3,3,4,4,4,4,4,4,4,1][slot])
	elif type==2:group="s2"+str([2,3,4,5,6,6,6,6,6,6,6,1][slot])
	else:group=("s3" if type==3 else "s4")+str(clampi(item,0,5)+1)
	return preload("res://scripts/ssrg_presentation_art.gd").TEXTURES.get("n"+group,null)

func current_card() -> Dictionary:
	if cards.is_empty():return {}
	var value=cards[card_index]
	return value if value is Dictionary else {}

static func apply_events(notes:Array,config:Dictionary) -> void:
	# Event schedules belong to the supplied metadata, not guessed SEQ flag meanings.
	var events:Dictionary={}
	var schedule=config.get("events",[])
	if not schedule is Array:return
	for event in schedule:
		if not event is Dictionary:continue
		var kind=int(event.get("type",-1));var order=int(event.get("order",-1))
		if kind>=0 and kind<5 and order>=0:events[order]=event
	for note in notes:
		var order=int(note.get("ssrg_order",-1))
		if events.has(order):
			note.ssrg_special=int(events[order].type)
			note.ssrg_item=clampi(int(events[order].get("item",0)),0,5)
