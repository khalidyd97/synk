extends RefCounted
## Source Unity legacy animation keys, including their separate incoming/outgoing tangents.
const DATA: Dictionary = preload("res://scripts/ssrg_source_curve_data.gd").CLIPS
const BEAM_RELEASE_SECONDS := .1 # alpha_out_linear length1 / Awake state speed10.

static func beam_alpha(age: float) -> float:
	return clampf(1.0-age/BEAM_RELEASE_SECONDS,0.0,1.0)

static func sample(clip: String, type: String, path: String, attribute: String, time: float, fallback: Variant = 1.0) -> Variant:
	for track in DATA.get(clip,{}).get("tracks",[]):
		if track.type==type and track.path==path and track.attribute==attribute:
			return sample_keys(track["keys"],time)
	return fallback

static func sample_keys(keys: Array,time: float) -> Variant:
	if time<=float(keys[0][0]): return convert_value(keys[0][1])
	for i in range(1,keys.size()):
		var b: Array=keys[i]
		if time>float(b[0]): continue
		var a: Array=keys[i-1]
		if time==float(b[0]): return convert_value(b[1])
		var duration: float=float(b[0])-float(a[0])
		var t: float=(time-float(a[0]))/duration
		var av: Variant=convert_value(a[1])
		var bv: Variant=convert_value(b[1])
		if a[3] is String or b[2] is String: return av
		var outgoing: Variant=convert_value(a[3])
		var incoming: Variant=convert_value(b[2])
		return (2*t*t*t-3*t*t+1)*av+(t*t*t-2*t*t+t)*duration*outgoing+(-2*t*t*t+3*t*t)*bv+(t*t*t-t*t)*duration*incoming
	return convert_value(keys[-1][1])

static func convert_value(value: Variant) -> Variant:
	if value is Dictionary: return Vector3(float(value.x),float(value.y),float(value.z))
	return float(value)

static func judgement_scale(age: float,miss: bool = false) -> Vector2:
	var result: Vector3=sample("JudgementBreak" if miss else "JudgementGood","scale","trans","",age,Vector3.ONE)
	return Vector2(result.x,result.y)

static func judgement_alpha(age: float,miss: bool = false) -> float:
	if age>=1.0: return 0.0
	return 1.0 if miss else float(sample("JudgementGood","float","trans/sprite","Color.a",age))

static func judgement_offset(age: float,miss: bool = false) -> Vector2:
	if not miss: return Vector2.ZERO
	var result: Vector3=sample("JudgementBreak","position","trans","",age,Vector3.ZERO)
	return Vector2(result.x,-result.y) # Unity up becomes Canvas down.
