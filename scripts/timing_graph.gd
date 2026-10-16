extends Control
var samples: Array=[]
func _ready(): mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
    var font=ThemeDB.fallback_font
    if samples.is_empty():
        draw_string(font,Vector2(8,size.y*.5),"No manual timing samples",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("a9bbd7")); return
    var mean=0.0
    for sample in samples: mean+=float(sample.ms)
    mean/=samples.size()
    draw_string(font,Vector2(0,16),"%d HITS  /  AVERAGE %+.1f ms" % [samples.size(),mean],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("deecff"))
    var top=27.0; var h=maxf(24,size.y-top); var mid=top+h*.5
    draw_rect(Rect2(0,top,size.x,h),Color("0b152b"))
    draw_line(Vector2(0,mid),Vector2(size.x,mid),Color("c9d8f1"),1)
    draw_string(font,Vector2(4,top+12),"EARLY",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("65dcff"))
    draw_string(font,Vector2(4,size.y-3),"LATE",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ff82d2"))
    var first=float(samples[0].time); var last=float(samples[-1].time)
    for i in mini(300,samples.size()):
        var index=roundi(float(i)/maxi(1,mini(300,samples.size())-1)*(samples.size()-1))
        var sample: Dictionary=samples[index]
        var x=45+(float(sample.time)-first)/maxf(.001,last-first)*(size.x-52)
        var y=mid+clampf(float(sample.ms)/180,-1,1)*(h*.42)
        draw_circle(Vector2(x,y),2.5,Color("65dcff") if float(sample.ms)<0 else Color("ff82d2"))
