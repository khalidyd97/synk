extends RefCounted
# Keep rendering close to the heard audio clock, even across stale mixer samples.
const MAX_VISUAL_LEAD=.025
const MAX_VISUAL_LAG=.035
static func heard_position(position:float,since_mix:float,latency:float,pitch:float) -> float:
	return maxf(0,position+(since_mix-latency)*pitch)
static func visual_step(previous:float,target:float,delta:float,pitch:float) -> float:
	if delta<=0 or pitch<=0:return previous
	var dt=maxf(0,delta);var step=dt*maxf(0,pitch)
	var predicted=previous+step
	var correction=(target-predicted)*(1.0-exp(-dt*8.0))
	var smooth=predicted+clampf(correction,-step*.2,step*.2)
	return maxf(previous,clampf(smooth,target-MAX_VISUAL_LAG,target+MAX_VISUAL_LEAD))
