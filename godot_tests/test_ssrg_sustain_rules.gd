extends SceneTree
const Rules=preload("res://scripts/ssrg_sustain_rules.gd")

func _initialize() -> void:
	# Lifting/departing does not kill a chain before its next node deadline.
	assert(Rules.action(1.5,2.0,false,Rules.TrackState.ENDED)=="wait")
	assert(Rules.action(1.9,2.0,false,Rules.TrackState.LOST)=="wait")
	assert(Rules.can_regrab(2.19,2.0,false))
	assert(not Rules.can_regrab(2.201,2.0,false))
	assert(Rules.action(2.201,2.0,false,Rules.TrackState.BEGAN)=="miss")
	assert(Rules.action(2.1,2.0,false,Rules.TrackState.BEGAN)=="hit")
	assert(Rules.action(1.79,2.0,false,Rules.TrackState.HELD)=="wait")
	assert(Rules.action(1.81,2.0,false,Rules.TrackState.HELD)=="hit")
	assert(Rules.action(1.77,2.0,true,Rules.TrackState.ENDED)=="wait")
	assert(Rules.action(1.78,2.0,true,Rules.TrackState.ENDED)=="hit")
	assert(Rules.action(2.29,2.0,true,Rules.TrackState.BEGAN)=="hit")
	assert(Rules.action(2.301,2.0,true,Rules.TrackState.HELD)=="miss")
	assert(not Rules.can_regrab(1.8,2.0,false,true))
	assert(Rules.action(1.9,2.0,false,Rules.TrackState.HELD,true)=="miss")
	assert(Rules.node_grade(.19,false,"PERFECT")=="PERFECT")
	assert(Rules.node_grade(0.0,false,"GOOD")=="GOOD")
	assert(Rules.node_grade(0.0,true,"PERFECT",true)=="GOOD")
	assert(Rules.node_grade(0.0,true,"GOOD")=="PERFECT")
	var note={"time":1.0,"duration":3.0,"checkpoints":[1.0,2.0]}
	assert(Rules.next_node(note,0)=={"time":2.0,"is_end":false})
	assert(Rules.next_node(note,2)=={"time":4.0,"is_end":true})
	print("SSRG sustain rules: node deadlines, regrab, release states and grade inheritance PASS")
	quit()
