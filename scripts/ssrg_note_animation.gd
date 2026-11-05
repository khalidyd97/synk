extends RefCounted
## Static APK ordinary-note appearance. See docs/SSRG_NOTE_ANIMATION_FINDINGS.md.

const BEAT_FRAME_MULTIPLIER := 11.989999771118164
const FRAME_ORDER := [1, 2, 3, 4, 5, 5, 5, 5, 5, 5, 5, 0]
const MISSED_TINT := Color(0.2, 0.2, 0.2, 0.25)
const CONNECTOR_TINT := Color(1.0, 1.0, 1.0, 0.2)
const PRISM_FRAMES := [
	preload("res://assets/ssrg/prism/na1.png"),
	preload("res://assets/ssrg/prism/na2.png"),
	preload("res://assets/ssrg/prism/na3.png"),
	preload("res://assets/ssrg/prism/na4.png"),
	preload("res://assets/ssrg/prism/na5.png"),
	preload("res://assets/ssrg/prism/na6.png"),
]
const TAP_FRAMES := [
	preload("res://assets/ssrg/imported/note_animation/na1.png"),
	preload("res://assets/ssrg/imported/note_animation/na2.png"),
	preload("res://assets/ssrg/imported/note_animation/na3.png"),
	preload("res://assets/ssrg/imported/note_animation/na4.png"),
	preload("res://assets/ssrg/imported/note_animation/na5.png"),
	preload("res://assets/ssrg/imported/note_animation/na6.png"),
]
const HOLD_HEAD_FRAMES := [
	preload("res://assets/ssrg/imported/note_animation/nb1.png"),
	preload("res://assets/ssrg/imported/note_animation/nb2.png"),
	preload("res://assets/ssrg/imported/note_animation/nb3.png"),
	preload("res://assets/ssrg/imported/note_animation/nb4.png"),
	preload("res://assets/ssrg/imported/note_animation/nb5.png"),
	preload("res://assets/ssrg/imported/note_animation/nb6.png"),
]
const HOLD_TAIL_FRAMES := [
	preload("res://assets/ssrg/imported/note_animation/nc1.png"),
	preload("res://assets/ssrg/imported/note_animation/nc2.png"),
	preload("res://assets/ssrg/imported/note_animation/nc3.png"),
	preload("res://assets/ssrg/imported/note_animation/nc4.png"),
	preload("res://assets/ssrg/imported/note_animation/nc5.png"),
	preload("res://assets/ssrg/imported/note_animation/nc6.png"),
]
const OLD_TAP_FRAMES := [
	preload("res://assets/ssrg/old_ui/normal/na1.png"), preload("res://assets/ssrg/old_ui/normal/na2.png"),
	preload("res://assets/ssrg/old_ui/normal/na3.png"), preload("res://assets/ssrg/old_ui/normal/na4.png"),
	preload("res://assets/ssrg/old_ui/normal/na5.png"), preload("res://assets/ssrg/old_ui/normal/na6.png"),
]
const OLD_HOLD_HEAD_FRAMES := [
	preload("res://assets/ssrg/old_ui/normal/nb1.png"), preload("res://assets/ssrg/old_ui/normal/nb2.png"),
	preload("res://assets/ssrg/old_ui/normal/nb3.png"), preload("res://assets/ssrg/old_ui/normal/nb4.png"),
	preload("res://assets/ssrg/old_ui/normal/nb5.png"), preload("res://assets/ssrg/old_ui/normal/nb6.png"),
]
const OLD_HOLD_TAIL_FRAMES := [
	preload("res://assets/ssrg/old_ui/long/nc1.png"), preload("res://assets/ssrg/old_ui/long/nc2.png"),
	preload("res://assets/ssrg/old_ui/long/nc3.png"), preload("res://assets/ssrg/old_ui/long/nc4.png"),
	preload("res://assets/ssrg/old_ui/long/nc5.png"), preload("res://assets/ssrg/old_ui/long/nc6.png"),
]

static func frame_index(beat01: float) -> int:
	# Caller supplies the beat phase, shared by all visible notes.
	return FRAME_ORDER[clampi(int(clampf(beat01, 0.0, 1.0) * BEAT_FRAME_MULTIPLIER), 0, 11)]

static func artwork(is_long: bool, is_long_start: bool, beat01: float, old_ui: bool=false) -> Texture2D:
	var frames = (OLD_TAP_FRAMES if not is_long else (OLD_HOLD_HEAD_FRAMES if is_long_start else OLD_HOLD_TAIL_FRAMES)) if old_ui else (TAP_FRAMES if not is_long else (HOLD_HEAD_FRAMES if is_long_start else HOLD_TAIL_FRAMES))
	return frames[frame_index(beat01)]

static func note_tint(is_long: bool, chain_missed: bool, judged: bool, judgment_is_miss: bool) -> Color:
	# Already successful long heads stay white when a later part of the chain misses.
	return MISSED_TINT if is_long and chain_missed and (not judged or judgment_is_miss) else Color.WHITE

static func connector_tint(chain_missed: bool) -> Color:
	return MISSED_TINT if chain_missed else CONNECTOR_TINT
