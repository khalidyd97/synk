extends RefCounted
## Packaged SSRG defaults recovered from ARM64 and level10 scene data.
## The shipped game can override these through remote ConfigControl values.
## Use only for SSRG playable imports; recorder and normal charts keep their rules.

const HEAD_WINDOW = 0.3
const MIDDLE_WINDOW = 0.2
const END_WINDOW = 0.3
const GOOD_RATE = 0.00001
const PERFECT_RATE = 0.3
const SUPER_PERFECT_RATE = 0.7
const CHANNEL_STEP = 62.7139231364
const TOUCH_Y_MIN = -449.0
const TOUCH_Y_MAX = 1.0

static func rate(error: float, middle: bool = false) -> float:
	return 1.0-absf(error)/(MIDDLE_WINDOW if middle else HEAD_WINDOW)

static func grade(error: float, middle: bool = false) -> String:
	if error<0: return "MISS"
	var accuracy=rate(error,middle)
	# Internal SYNK names preserve result storage; PERFECT displays S·PERFECT.
	if accuracy>=SUPER_PERFECT_RATE-0.0000001: return "PERFECT"
	if accuracy>=PERFECT_RATE-0.0000001: return "GREAT"
	if accuracy>=GOOD_RATE: return "GOOD"
	return "MISS"

static func perfect_window(middle: bool = false) -> float:
	return (MIDDLE_WINDOW if middle else HEAD_WINDOW)*(1.0-SUPER_PERFECT_RATE)

static func great_window(middle: bool = false) -> float:
	return (MIDDLE_WINDOW if middle else HEAD_WINDOW)*(1.0-PERFECT_RATE)

static func good_window(middle: bool = false) -> float:
	return (MIDDLE_WINDOW if middle else HEAD_WINDOW)*(1.0-GOOD_RATE)

static func early_release_window() -> float:
	# UpdateNoteJudgement 0x258A948 accepts an End state within .75*front-end.
	return END_WINDOW*0.75

static func channel_center(channel: float) -> float:
	return (channel-6.0)*CHANNEL_STEP

static func touch_width(key_count: int) -> float:
	return 251.0 if key_count==4 else (125.5 if key_count==7 else 62.75)

static func contains_lane(ui_position: Vector2, channel: float, key_count: int) -> bool:
	if key_count not in [4,7,13]: return false
	var left=channel_center(channel)-touch_width(key_count)*0.5
	return ui_position.x>=left and ui_position.x<left+touch_width(key_count) and ui_position.y>=TOUCH_Y_MIN and ui_position.y<TOUCH_Y_MAX

static func side_channel(ui_position: Vector2, key_count: int) -> int:
	if key_count not in [4,7,13] or ui_position.y<TOUCH_Y_MIN or ui_position.y>=TOUCH_Y_MAX: return -1
	var center=525.0 if key_count==4 else 510.0
	var width=175.0 if key_count==4 else (200.0 if key_count==7 else 205.0)
	for sign_value in [-1,1]:
		var left=sign_value*center-width*0.5
		if ui_position.x>=left and ui_position.x<left+width: return 0 if sign_value<0 else 12
	return -1

static func original_ui_speed(normalized_speed: float) -> float:
	# Original noteSpeedMultiplier=noteSpeed/3; SYNK already stores multiplier.
	return normalized_speed*3.0
