extends Control
var peaks: PackedFloat32Array=[]
var progress=0.0
var active=false
func _ready() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
    if peaks.is_empty():
        draw_line(Vector2(0,size.y*.5),Vector2(size.x,size.y*.5),Color(.55,.45,.8,.3),1,true)
        return
    var count=90
    var peak_max=.001
    for peak in peaks: peak_max=maxf(peak_max,peak)
    for i in count:
        var sample=clampi(int(float(i)/count*peaks.size()),0,peaks.size()-1)
        var height=maxf(2,sqrt(peaks[sample]/peak_max)*size.y*.85)
        var x=(i+.5)*size.x/count
        var color=Color("65e8ff") if active and float(i)/count<=progress else Color(.7,.5,1,.45)
        draw_line(Vector2(x,(size.y-height)*.5),Vector2(x,(size.y+height)*.5),color,2,true)
