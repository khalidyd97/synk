extends SceneTree

# Playable visual fixture for reviewing every gameplay note shape on all 13 lanes.
func _initialize() -> void:
	run.call_deferred()

func hold(at: float,lane: float,duration: float) -> Dictionary:
	var note=SynkChart.note(at,lane,"hold")
	note.duration=duration
	note.checkpoints=[duration*.33,duration*.66]
	return note

func slide(at: float,lanes: Array,duration: float) -> Dictionary:
	var note=SynkChart.note(at,float(lanes[0]),"slide")
	note.duration=duration
	note.end_lane=float(lanes[-1])
	note.ssrg_path=true
	note.path=[]
	for index in lanes.size():
		note.path.append({"offset":duration*float(index)/float(lanes.size()-1),"lane":float(lanes[index])})
	note.checkpoints=[]
	for index in range(1,lanes.size()-1):note.checkpoints.append(duration*float(index)/float(lanes.size()-1))
	return note

func review_chart() -> Array:
	var notes:Array=[]
	# Taps: one clean sweep, then widely spaced chords.
	for lane in 13:notes.append(SynkChart.note(5.0+lane*.28,lane))
	for row in 4:
		var at=9.0+row*.62
		for lane in range(row%2,13,3):notes.append(SynkChart.note(at,lane))
	# Flicks: every lane individually, then alternating flick chords.
	for lane in 13:
		var flick=SynkChart.note(12.0+lane*.32,lane,"flick");flick.direction=0;notes.append(flick)
	for row in 4:
		var at=16.5+row*.7
		for lane in [1+row%2,6,11-row%2]:
			var flick=SynkChart.note(at,lane,"flick");flick.direction=0;notes.append(flick)
	# Holds: short, medium and long bodies across the full width.
	for lane in 13:notes.append(hold(20.0+lane*.38,lane,.75+(lane%3)*.42))
	for lane in [0,3,6,9,12]:notes.append(hold(26.0,lane,2.0))
	# Slides: straight diagonals, broad zigzags, edge crossings and compact bends.
	var shapes=[
		[0,3,6],[12,9,6],[1,5,10],[11,7,2],[0,6,12],[12,6,0],
		[2,8,4,10],[10,4,8,2],[0,4,2,7,5,12],[12,8,10,5,7,0],
		[3,3,7,7,11],[9,9,5,5,1]
	]
	for index in shapes.size():notes.append(slide(29.0+index*1.05,shapes[index],.82+(index%3)*.25))
	# Mixed finale: taps, flicks, holds and crossing slides together but still readable.
	for row in 12:
		var at=43.0+row*.72
		notes.append(SynkChart.note(at,(row*5)%13))
		if row%2==0:
			var flick=SynkChart.note(at+.18,(12-row*3)%13,"flick");flick.direction=0;notes.append(flick)
		if row%3==0:notes.append(hold(at+.34,(row*2+3)%13,1.15))
		if row%4==0:notes.append(slide(at+.1,[row%5,6,12-row%5],1.25))
	notes.sort_custom(func(a,b):return float(a.time)<float(b.time))
	return notes

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.auto_play=true
	game.stage_intro_enabled=false
	game.highway_style="ssrg"
	game.ssrg_playable_run=true
	game.ssrg_lane_count=13
	game.start_game(review_chart(),false)
