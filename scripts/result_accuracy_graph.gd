extends Control
var samples: Array=[]
var start=0.0
var finish=1.0
var progress=1.0
var points: Array=[]
var range_low=0.0
var range_high=1.0
func _ready() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE
func rebuild() -> void:
    points.clear()
    var bins: Dictionary={}
    for sample in samples:
        if not sample is Dictionary or not sample.has("time") or not sample.has("weight"): continue
        var amount=maxi(1,int(sample.get("amount",1)))
        var bucket=clampi(floori((float(sample.time)-start)/maxf(.001,finish-start)*32),0,31)
        if not bins.has(bucket): bins[bucket]={"weight":0.0,"amount":0}
        bins[bucket].weight+=clampf(float(sample.weight),0,1)*amount
        bins[bucket].amount+=amount
    var keys=bins.keys(); keys.sort()
    for bucket in keys: points.append(Vector2((float(bucket)+.5)/32.0,bins[bucket].weight/bins[bucket].amount))
    if not points.is_empty():
        range_low=1.0; range_high=0.0
        for point in points: range_low=minf(range_low,point.y); range_high=maxf(range_high,point.y)
        range_low=maxf(0,range_low-.03); range_high=minf(1,range_high+.03)
        if range_high-range_low<.12:
            range_low=maxf(0,range_high-.12); range_high=minf(1,range_low+.12)
        tooltip_text="Weighted judgment accuracy by time window. Vertical range: %.1f–%.1f%%. Empty windows are omitted." % [range_low*100,range_high*100]
        mouse_filter=Control.MOUSE_FILTER_PASS
    queue_redraw()
func tint(x: float) -> Color:
    return Color("2bdaed").lerp(Color("f12bc6"),x)
func _draw() -> void:
    if points.is_empty():
        draw_string(get_theme_font("font"),Vector2(0,size.y*.5),"No judgments recorded for this run",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("8d85a6")); return
    var path=points.duplicate()
    if path.size()==1: path=[Vector2(0,path[0].y),Vector2(1,path[0].y)]
    for i in range(1,path.size()):
        if path[i-1].x>progress: break
        var left: Vector2=path[i-1]; var right: Vector2=path[i]
        if right.x>progress: right=left.lerp(right,(progress-left.x)/maxf(.001,right.x-left.x))
        var a=Vector2(left.x*size.x,8+(1-(left.y-range_low)/maxf(.001,range_high-range_low))*(size.y-16)*.82)
        var b=Vector2(right.x*size.x,8+(1-(right.y-range_low)/maxf(.001,range_high-range_low))*(size.y-16)*.82)
        var ca=tint(left.x); var cb=tint(right.x)
        draw_polygon(PackedVector2Array([a,b,Vector2(b.x,size.y),Vector2(a.x,size.y)]),PackedColorArray([Color(ca,.22),Color(cb,.22),Color(cb,0),Color(ca,0)]))
        draw_line(a,b,ca.lerp(cb,.5),3.5,true)
