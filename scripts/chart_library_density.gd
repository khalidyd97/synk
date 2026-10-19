extends Control
var notes: Array=[]
var duration=1.0
func _ready() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
    var font=ThemeDB.fallback_font
    draw_string(font,Vector2(0,11),"N O T E   D E N S I T Y",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("6dc5e9"))
    var bins: Array=[]; bins.resize(32); bins.fill(0)
    for note in notes:
        var at=clampi(int(float(note.time)/maxf(1,duration)*32),0,31); bins[at]+=1
    var peak=maxf(1,float(bins.max())); var step=size.x/32.0
    for i in 32:
        var h=maxf(2,float(bins[i])/peak*(size.y-20))
        var tint=Color("32d9ed").lerp(Color("e14bd6"),float(i)/31)
        draw_rect(Rect2(i*step,size.y-h,maxf(1,step-3),h),tint if bins[i]>0 else Color("293044"))
