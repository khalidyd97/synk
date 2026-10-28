extends RefCounted
## Original long-note node state rules, recovered from the supplied ARM64 APK.
## This deliberately has no wall-clock gap grace: the next node's deadline rules.

const InputRules=preload("res://scripts/ssrg_input_rules.gd")
enum TrackState { IDLE=0, BEGAN=1, MOVED=2, HELD=3, LOST=4, ENDED=5 }

static func deadline(node_time: float, is_end: bool) -> float:
	return node_time+(InputRules.END_WINDOW if is_end else InputRules.MIDDLE_WINDOW)

static func can_regrab(now: float, next_node_time: float, is_end: bool, chain_missed: bool = false) -> bool:
	return not chain_missed and now<=deadline(next_node_time,is_end)

static func action(now: float, node_time: float, is_end: bool, state: int, chain_missed: bool = false, travel_seconds:float=3.5, released_chain:bool=false, contact_release:bool=false) -> String:
	if chain_missed: return "miss"
	if now>deadline(node_time,is_end): return "miss"
	var front=InputRules.END_WINDOW if is_end else InputRules.MIDDLE_WINDOW
	if 1.0+(now-node_time)/maxf(.001,travel_seconds)<=.7:return "wait"
	# Native rates must be positive; the exact front/rear boundaries do not hit.
	if now<=node_time-front or now>=deadline(node_time,is_end):return "wait"
	if state==TrackState.ENDED:
		# Preserve verified owned-contact releases as an explicit SYNK adapter;
		# the original initial release-state transition remains unproven.
		return "hit" if is_end and (released_chain or contact_release) and node_time-now<=InputRules.early_release_window() else "wait"
	if state in [TrackState.BEGAN,TrackState.MOVED,TrackState.HELD]:return "hit"
	# Lost is a lane visited and left in THIS input update, not a gap timer.
	if state==TrackState.LOST and not released_chain:return "hit"
	return "wait"

static func node_grade(_error: float, _is_end: bool, previous_grade: String, _released: bool = false, previously_interrupted: bool = false) -> String:
	# Source IsLongMiddle means Long2, including the terminal continuation.
	# Final enum inheritance also overrides a release's provisional rate .1.
	if previously_interrupted:return "GOOD"
	return previous_grade if previous_grade in ["PERFECT","GREAT","GOOD"] else "GOOD"

static func node_rate(previous_rate:float, released:bool=false, previously_interrupted:bool=false) -> float:
	return .1 if released or previously_interrupted or previous_rate<=0 else previous_rate

static func next_node(note: Dictionary, checks_done: int) -> Dictionary:
	var checkpoints: Array=note.get("checkpoints",[])
	if checks_done<checkpoints.size():
		return {"time":float(note.time)+float(checkpoints[maxi(0,checks_done)]),"is_end":false}
	return {"time":float(note.time)+float(note.duration),"is_end":true}
