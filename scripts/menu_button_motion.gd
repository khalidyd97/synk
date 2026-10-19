extends RefCounted

# Draw-only motion keeps touch rectangles and scroll layouts stationary.
var phase=0.0
var press=0.0
var rim=PackedVector2Array()
var lengths=PackedFloat32Array()
var perimeter=0.0
var cached_size=Vector2.ZERO
var cached_radius=0.0

func advance(delta: float,enabled: bool=true) -> void:
    if enabled: phase=fposmod(phase+delta,120.0)
    press=move_toward(press,0,delta*3.5)

func rebuild(size: Vector2,radius: float) -> void:
    if size==cached_size and radius==cached_radius: return
    cached_size=size; cached_radius=radius; rim.clear(); lengths.clear(); perimeter=0
    var rect=Rect2(Vector2.ONE*2,size-Vector2.ONE*4)
    var r=minf(radius,minf(rect.size.x,rect.size.y)*.5)
    var centers=[Vector2(rect.end.x-r,rect.position.y+r),rect.end-Vector2.ONE*r,Vector2(rect.position.x+r,rect.end.y-r),rect.position+Vector2.ONE*r]
    for corner in 4:
        for step in 9:
            var angle=-PI*.5+corner*PI*.5+step*PI/16.0
            rim.append(centers[corner]+Vector2(cos(angle),sin(angle))*r)
    rim.append(rim[0])
    for i in range(1,rim.size()):
        perimeter+=rim[i-1].distance_to(rim[i]); lengths.append(perimeter)

func point_at(distance_value: float) -> Vector2:
    var previous=0.0
    for i in lengths.size():
        if distance_value<=lengths[i]: return rim[i].lerp(rim[i+1],(distance_value-previous)/maxf(.001,lengths[i]-previous))
        previous=lengths[i]
    return rim[0]

func paint(target: Control,tint: Color,strength: float,radius: float=15) -> void:
    if target.size.x<8 or target.size.y<8: return
    rebuild(target.size,radius)
    if strength>.005:
        var head=fposmod(phase*(80+strength*50),perimeter)
        var trail=minf(100,perimeter*.18)
        for i in 16:
            var a=fposmod(head-trail+i*trail/16,perimeter)
            var b=fposmod(head-trail+(i+1)*trail/16,perimeter)
            if b<a: continue
            var alpha=strength*float(i+1)/16
            target.draw_line(point_at(a),point_at(b),Color(tint,alpha*.14),6,true)
            target.draw_line(point_at(a),point_at(b),Color(tint.lightened(.5),alpha*.8),1.6,true)
    if press>.005:
        var inset=2+(1-press)*7
        var feedback=StyleBoxFlat.new(); feedback.set_corner_radius_all(maxi(2,int(radius-inset*.4)))
        feedback.bg_color=Color.TRANSPARENT; feedback.border_color=Color(tint.lightened(.5),press*.65); feedback.set_border_width_all(2)
        target.draw_style_box(feedback,Rect2(Vector2.ONE*inset,target.size-Vector2.ONE*inset*2))
