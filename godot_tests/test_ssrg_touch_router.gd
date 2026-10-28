extends SceneTree
const Router=preload("res://scripts/ssrg_touch_router.gd")
const Rules=preload("res://scripts/ssrg_input_rules.gd")
const State=preload("res://scripts/ssrg_sustain_rules.gd").TrackState
var failures=0

func check(ok:bool,label:String) -> void:
	if not ok:failures+=1;push_error(label)

func touch(channel:int,phase:int=0) -> Dictionary:
	return {"ssrg_ui":Vector2(Rules.channel_center(channel),-234.0),"ssrg_phase":phase}

func candidate(channel:int,owner:int,sustain:bool=true,eligible:bool=true) -> Dictionary:
	var geometry=Router.node_geometry(channel,2.0,1.9,3.5,sustain)
	return {"token":"node_%d"%channel,"channel":channel,"owner":owner,"sustain":sustain,"eligible":eligible,"rect":geometry.rect,"center":geometry.center,"q":geometry.q}

func _initialize() -> void:
	var router=Router.new()
	# Recovered calibrated projection and logical touch dimensions, independent
	# of rendered note size and the mode's ordinary channel collider width.
	var geometry=Router.node_geometry(8,2.0,1.9,3.5)
	var expected_q=pow(1.0-.1/3.5,6.0)
	check(is_equal_approx(geometry.q,expected_q),"Node rect uses calibrated sixth-power progress")
	check(geometry.center.is_equal_approx(Vector2(Rules.channel_center(8)*expected_q,280.0-514.0*expected_q)),"Moving node owns its projected center")
	check(geometry.rect.size.is_equal_approx(Vector2(233.2,290.0)*expected_q),"Sustain rect uses logical212x116 times1.1/2.5")
	var head=Router.node_geometry(8,2.0,1.9,3.5,false)
	check(head.rect.size.is_equal_approx(Vector2(233.2,232.0)*expected_q),"Head touch height is2.0 logical heights")
	check(Router.node_geometry(8,2.0,2.1,3.5).q>1.0,"Projected touch rect continues past judgment time")
	check(geometry.rect.has_point(geometry.rect.position) and not geometry.rect.has_point(geometry.rect.end),"Source rect includes minimum and excludes maximum")
	for keys in [4,7,13]:
		var interval=12/(keys-1)
		for slot in keys:
			var channel=slot*interval
			check(Router.raw_channel(Vector2(Rules.channel_center(channel),-234),keys)==channel,"Mode%d channel%d retains collider assignment"%[keys,channel])
		check(Router.raw_channel(Vector2(-525 if keys==4 else -510,-234),keys)==0,"Mode%d left side routes to outer channel"%keys)
		check(Router.raw_channel(Vector2(525 if keys==4 else 510,-234),keys)==12,"Mode%d right side routes to outer channel"%keys)
		# No note-size input exists in this geometry API; changing mode widths
		# must never feed ordinary collider widths into the moving note rect.
		check(Router.node_geometry(8,2.0,1.9,3.5).rect==geometry.rect,"Mode%d leaves logical autoaim rect unchanged"%keys)
	# Establish the chain's existing finger, then place it within the moving
	# node rectangle while physically in a different base channel.
	var owned=touch(6)
	var pointers={7:owned}
	router.route(pointers,[],13,1)
	owned.ssrg_phase=1;owned.ssrg_ui=Vector2(20,geometry.center.y)
	var next=candidate(8,7)
	check(Router.raw_channel(owned.ssrg_ui,13)==6 and next.rect.has_point(owned.ssrg_ui),"Fixture separates physical lane from autoaim lane")
	router.route(pointers,[next],13,2)
	check(owned.ssrg_channel==8 and owned.ssrg_aim.token==next.token,"Existing chain finger receives moving-node autoaim")
	check(router.track(8).pointer==7 and router.track(8).state==State.MOVED,"Autoaim feeds shared UseMoved channel")
	check(router.track(6).state==State.LOST,"Changing effective channel loses the previous track")
	var stranger=touch(6)
	stranger.ssrg_ui=owned.ssrg_ui;stranger.ssrg_phase=2
	router.route({9:stranger},[next],13,3)
	check(stranger.ssrg_channel==6 and stranger.ssrg_aim.is_empty(),"Fresh stationary finger cannot inherit another chain's moving autoaim")
	router.reset()
	owned=touch(6);router.route({7:owned},[],13,1)
	owned.ssrg_phase=1;owned.ssrg_ui=Vector2(20,geometry.center.y)
	next=candidate(8,7,true,false)
	router.route({7:owned},[next],13,2)
	check(owned.ssrg_channel==6 and owned.ssrg_aim.is_empty(),"Ineligible timing/chain candidate cannot give moving autoaim")
	router.reset();owned=touch(6);router.route({7:owned},[],13,1)
	var high_geometry=Router.node_geometry(6,2.0,1.81,3.5)
	next=candidate(6,7);next.rect=high_geometry.rect;next.center=high_geometry.center;next.q=high_geometry.q
	owned.ssrg_phase=1;owned.ssrg_ui=Vector2(0,5)
	check(Router.raw_channel(owned.ssrg_ui,13)==-1 and next.rect.has_point(owned.ssrg_ui),"Fixture is above ordinary channel band but inside moving node")
	router.route({7:owned},[next],13,2)
	check(owned.ssrg_channel==6 and not owned.ssrg_aim.is_empty(),"Owner autoaim can use source global area above ordinary channel colliders")
	# Began cannot autoaim to an already active sustain node, even when it is
	# geometrically closer than an available ordinary/start candidate.
	router.reset();var newcomer=touch(6)
	var pending_head=candidate(8,-999,false)
	pending_head.rect=Rect2(-100,-300,300,200);pending_head.center=Vector2(80,-234)
	var active_tail=candidate(7,42)
	active_tail.rect=Rect2(-100,-300,300,200);active_tail.center=Vector2(0,-234)
	router.route({42:newcomer},[active_tail,pending_head],13,1)
	check(newcomer.ssrg_channel==8 and newcomer.ssrg_aim.token==pending_head.token,"Fresh Began aims at ordinary/head candidate rather than active tail")
	# Shared channel arbitration follows active-touch insertion order, not ID
	# priority or permanent per-chain ownership.
	router.reset()
	var early=touch(6);var late=touch(6)
	pointers={10:early,3:late}
	router.route(pointers,[],13,1)
	check(router.track(6).state==State.BEGAN and router.track(6).pointer==3,"Later-created Began wins shared channel even with lower finger ID")
	early.ssrg_phase=2;late.ssrg_phase=2
	router.route(pointers,[],13,2)
	check(router.track(6).state==State.HELD and router.track(6).pointer==3,"Stationary overwrite retains creation-order winner")
	router.reset();early=touch(6);late=touch(6)
	router.route({3:late,10:early},[],13,1)
	check(router.track(6).pointer==10,"Reversing insertion order reverses channel winner")
	check(router.consume(6),"First judgment consumes channel")
	check(not router.consume(6),"Second judgment in same frame is blocked")
	check(router.consume(7),"Another channel remains independently consumable")
	router.begin_frame(1)
	check(not router.consume(6),"Repeated same-frame routing cannot reset consumed flag")
	router.begin_frame(2)
	check(router.consume(6),"New frame clears channel consumption")
	# A later ending touch clears the channel even after another finger has
	# populated it; cancellation deliberately cannot award a successful tail.
	router.reset();early=touch(6);late=touch(6)
	router.route({10:early,3:late},[],13,1)
	early.ssrg_phase=0;late.ssrg_phase=3
	router.route({10:early,3:late},[],13,2)
	check(router.track(6).state==State.ENDED and router.track(6).pointer==-999,"End clears shared channel without pointer-identity guard")
	late.ssrg_phase=4
	router.route({3:late},[],13,3)
	check(router.track(6).state==State.IDLE and router.track(6).pointer==-999,"OS cancel cannot leave End eligible for release scoring")
	router.reset();owned=touch(6);router.route({7:owned},[],13,1)
	owned.ssrg_phase=1;owned.ssrg_ui=Vector2(Rules.channel_center(7),-234)
	router.route({7:owned},[],13,2)
	check(router.track(6).state==State.LOST and router.track(7).state==State.MOVED,"Physical lane crossing emits Lost and UseMoved")
	owned.ssrg_phase=2;router.route({7:owned},[],13,3)
	check(router.track(6).state==State.IDLE and router.track(7).state==State.HELD,"Next frame clears Lost and retains held destination")
	owned.ssrg_ui=Vector2(700,-234);router.route({7:owned},[],13,4)
	check(owned.ssrg_channel==-1 and owned.ssrg_aim.is_empty() and router.track(7).pointer==-999,"Global exit cleans up effective channel as documented SYNK adaptation")
	router.reset()
	check(router.tracks.is_empty() and router.consumed.is_empty() and router.frame_token==null,"Reset clears all routing history")
	print("SSRG touch router: %d failures"%failures)
	quit(1 if failures else 0)
