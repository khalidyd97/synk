extends RefCounted
# Slow, bounded quality changes avoid chasing individual loading or OS stalls.
var scale=1.0
var elapsed=0.0
var frames=0
var settling=3.0
var good_seconds=0.0
func reset(ceiling: float) -> void:
    scale=ceiling; elapsed=0.0; frames=0; settling=3.0; good_seconds=0.0
func sample(delta: float,target: float,ceiling: float) -> float:
    scale=minf(scale,ceiling)
    if delta<=0.0 or delta>.1: return scale
    if settling>0.0:
        settling-=delta
        return scale
    elapsed+=delta; frames+=1
    if elapsed<2.0: return scale
    var average=elapsed/frames
    if average>1.12/target:
        scale=maxf(minf(.75,ceiling),scale-.05)
        good_seconds=0.0; settling=3.0
    elif average<1.03/target:
        good_seconds+=elapsed
        if good_seconds>=8.0:
            scale=minf(ceiling,scale+.05)
            good_seconds=0.0; settling=3.0
    else: good_seconds=0.0
    elapsed=0.0; frames=0
    return scale
