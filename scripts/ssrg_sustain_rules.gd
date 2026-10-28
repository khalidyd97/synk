extends RefCounted
## Original long-note node state rules, recovered from the supplied ARM64 APK.
## This deliberately has no wall-clock gap grace: the next node's deadline rules.

const InputRules=preload("res://scripts/ssrg_input_rules.gd")
enum TrackState { IDLE=0, BEGAN=1, MOVED=2, HELD=3, LOST=4, ENDED=5 }

static func deadline(node_time: float, is_end: bool) -> float:
	return node_time+(InputRules.END_WINDOW if is_end else InputRules.MIDDLE_WINDOW)

static func can_regrab(now: float, next_node_time: float, is_end: bool, chain_missed: bool = false) -> bool:
	return not chain_missed and now<=deadline(next_node_time,is_end)

static func action(now: float, node_time: float, is_end: bool, state: int, chain_missed: bool = false) -> String:
	if chain_missed: return "miss"
	if now>deadline(node_time,is_end): return "miss"
	var front=InputRules.END_WINDOW if is_end else InputRules.MIDDLE_WINDOW
	if now<node_time-front: return "wait"
	if is_end and state==TrackState.ENDED and node_time-now<=InputRules.early_release_window(): return "hit"
	# A held connector is automatic: the early input window must not consume
	# its puck/tail before it actually reaches the judgment line.
	if state in [TrackState.BEGAN,TrackState.MOVED,TrackState.HELD] and now>=node_time: return "hit"
	return "wait"

static func node_grade(error: float, is_end: bool, previous_grade: String, released: bool = false, previously_interrupted: bool = false) -> String:
	# Grade a deliberate end release by its captured timing instead of forcing
	# Good on an on-time lift. The separate early-release limit still applies.
	if previously_interrupted:return "GOOD"
	if released:return InputRules.grade(error)
	# Middle nodes retain the grade earned by the preceding judged node.
	if not is_end:
		return previous_grade if previous_grade in ["PERFECT","GREAT","GOOD"] else "GOOD"
	return InputRules.grade(error)

static func next_node(note: Dictionary, checks_done: int) -> Dictionary:
	var checkpoints: Array=note.get("checkpoints",[])
	if checks_done<checkpoints.size():
		return {"time":float(note.time)+float(checkpoints[maxi(0,checks_done)]),"is_end":false}
	return {"time":float(note.time)+float(note.duration),"is_end":true}
