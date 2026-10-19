extends Control
var game: Control
var bins=PackedInt32Array()
var dragging=false
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_STOP
    tooltip_text="Whole song: tap or drag to jump. Cyan lines mark sections."
func rebuild() -> void:
    bins.resize(128); bins.fill(0)
    for n in game.document.notes:
        bins[clampi(int(float(n.time)/maxf(.001,game.length())*128),0,127)]+=1
    queue_redraw()
func seek_at(point: Vector2) -> void:
    game.seek_to(clampf((point.y-24)/maxf(1,size.y-30),0,1)*game.length())
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
        dragging=event.pressed
        if dragging: seek_at(event.position)
        accept_event()
    elif event is InputEventScreenTouch:
        dragging=event.pressed
        if dragging: seek_at(event.position)
        accept_event()
    elif dragging and (event is InputEventMouseMotion or event is InputEventScreenDrag): seek_at(event.position); accept_event()
func _process(_delta: float) -> void:
    if is_visible_in_tree(): queue_redraw()
func _draw() -> void:
    if game==null or bins.is_empty(): return
    draw_rect(Rect2(Vector2.ZERO,size),Color("151515"))
    var font=ThemeDB.fallback_font
    draw_string(font,Vector2(4,16),"ALL",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a5cde8"))
    var h=maxf(1,size.y-30); var length=maxf(.001,game.length()); var peak=1
    for count in bins: peak=maxi(peak,count)
    for i in bins.size():
        var width=sqrt(float(bins[i])/peak)*(size.x-8)
        draw_rect(Rect2(4,24+float(i)/128*h,width,maxf(1,h/128-1)),Color("658cef"))
    var top=24+game.timeline.view_start/length*h
    var bottom=minf(size.y-6,top+game.zoom_seconds/length*h)
    draw_rect(Rect2(1,top,size.x-2,maxf(3,bottom-top)),Color(.5,.8,1,.12))
    draw_rect(Rect2(1,top,size.x-2,maxf(3,bottom-top)),Color("8cceff"),false,1)
    for section in ["verse2","bridge"]:
        var at=game.section_mark(section)
        if at>=0:
            var y=24+at/length*h; draw_line(Vector2(0,y),Vector2(size.x,y),Color("6affdf"),2)
    for bookmark in game.features.bookmarks():
        var mark_y=24+float(bookmark.start)/length*h
        draw_line(Vector2(0,mark_y),Vector2(size.x,mark_y),Color("ffcd73"),2)
    var y=24+game.cursor/length*h
    draw_line(Vector2(0,y),Vector2(size.x,y),Color("ffe699"),2)
