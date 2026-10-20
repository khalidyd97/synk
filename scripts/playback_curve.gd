extends RefCounted
# Exact monotone-cubic coefficients for immutable playback notes. Authoring stays uncached.
var start=0.0
var duration=0.0
var lane=0.0
var end_lane=0.0
var ends=PackedFloat64Array()
var starts=PackedFloat64Array()
var spans=PackedFloat64Array()
var coefficients: Array[PackedFloat64Array]=[]
var last_lane=0.0
func _init(note: Dictionary) -> void:
    start=float(note.time); duration=float(note.duration); lane=float(note.lane); end_lane=float(note.end_lane)
    var path: Array=note.get("path",[])
    last_lane=float(path[-1].lane) if path.size()>1 else end_lane
    for i in range(1,path.size()):
        var t0=float(path[i-1].offset); var t1=float(path[i].offset)
        var span=maxf(.0001,t1-t0)
        var l0=float(path[i-1].lane); var l1=float(path[i].lane)
        var d1=(l1-l0)/span
        var d0=(l0-float(path[i-2].lane))/maxf(.0001,t0-float(path[i-2].offset)) if i>=2 else d1
        var d2=(float(path[i+1].lane)-l1)/maxf(.0001,float(path[i+1].offset)-t1) if i+1<path.size() else d1
        var m0=0.0 if d0*d1<=0 else 2*d0*d1/(d0+d1)
        var m1=0.0 if d1*d2<=0 else 2*d1*d2/(d1+d2)
        starts.append(t0); ends.append(t1); spans.append(span)
        coefficients.append(PackedFloat64Array([2*l0+m0*span-2*l1+m1*span,-3*l0-2*m0*span+3*l1-m1*span,m0*span,l0]))
func lane_at(time: float) -> float:
    var elapsed=clampf(time-start,0,duration)
    if ends.is_empty(): return lerpf(lane,end_lane,smoothstep(0,maxf(.01,duration),elapsed))
    var low=0; var high=ends.size()
    while low<high:
        var middle=(low+high)>>1
        if elapsed<=ends[middle]: high=middle
        else: low=middle+1
    if low==ends.size(): return last_lane
    var t=(elapsed-starts[low])/spans[low]; var c=coefficients[low]
    return clampf(((c[0]*t+c[1])*t+c[2])*t+c[3],0,SynkChart.MAX_LANE)
