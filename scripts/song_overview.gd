extends Control
var game: Control
var bins=PackedInt32Array()
var dragging=false
var horizontal=false
var recorder_mode=false
var known_note_count=-1
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_STOP
    tooltip_text="Whole song: tap or drag to jump. Cyan lines mark sections. Seeking a take opens correction mode." if recorder_mode else "Whole song: tap or drag to jump. Cyan lines mark sections."
func rebuild() -> void:
    bins.resize(128); bins.fill(0)
    var sources=[game.document.notes,game.capture.notes] if recorder_mode else [game.document.notes]
    known_note_count=0
    for source in sources:
     known_note_count+=source.size()
     for n in source:
        bins[clampi(int(float(n.time)/maxf(.001,game.length())*128),0,127)]+=1
    queue_redraw()
func seek_at(point: Vector2) -> void:
    if recorder_mode:
        game.seek_recording_to(clampf((point.x-34)/maxf(1,size.x-42),0,1)*game.length())
    else:
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
    if is_visible_in_tree():
        if recorder_mode and known_note_count!=game.document.notes.size()+game.capture.notes.size(): rebuild()
        queue_redraw()
func _draw() -> void:
    if game==null or bins.is_empty(): return
    if horizontal:
        draw_horizontal(); return
    draw_rect(Rect2(Vector2.ZERO,size),Color(1,1,1,.07))
    var font=preload("res://scripts/arcade_style.gd").HEAD
    draw_string(font,Vector2(4,16),"ALL",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d9d4ca"))
    var h=maxf(1,size.y-30); var length=maxf(.001,game.length()); var peak=1
    for count in bins: peak=maxi(peak,count)
    for i in bins.size():
        var width=sqrt(float(bins[i])/peak)*(size.x-8)
        draw_rect(Rect2(4,24+float(i)/128*h,width,maxf(1,h/128-1)),Color("d9d4ca"))
    var top=24+game.timeline.view_start/length*h
    var bottom=minf(size.y-6,top+game.zoom_seconds/length*h)
    draw_rect(Rect2(1,top,size.x-2,maxf(3,bottom-top)),Color(.5,.8,1,.12))
    draw_rect(Rect2(1,top,size.x-2,maxf(3,bottom-top)),Color("d9d4ca"),false,1)
    for section in ["verse2","bridge"]:
        var at=game.section_mark(section)
        if at>=0:
            var y=24+at/length*h; draw_line(Vector2(0,y),Vector2(size.x,y),Color("d9d4ca"),2)
    for bookmark in game.features.bookmarks():
        var mark_y=24+float(bookmark.start)/length*h
        draw_line(Vector2(0,mark_y),Vector2(size.x,mark_y),Color("ffcd73"),2)
    var y=24+game.cursor/length*h
    draw_line(Vector2(0,y),Vector2(size.x,y),Color("ffe699"),2)

func draw_horizontal() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color(1,1,1,.07))
    var font=preload("res://scripts/arcade_style.gd").HEAD
    draw_string(font,Vector2(5,size.y*.5+4),"ALL",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d9d4ca"))
    var left=34.0;var span=maxf(1.0,size.x-42.0);var duration=maxf(.001,game.length())
    var peak=1
    for count in bins:peak=maxi(peak,count)
    for i in bins.size():
        var x=left+float(i)/128.0*span
        var height=sqrt(float(bins[i])/peak)*maxf(2.0,size.y-12.0)
        draw_rect(Rect2(x,size.y*.5-height*.5,maxf(1.0,span/128.0-1.0),height),Color("d9d4ca"))
    if recorder_mode and game.recorder.active:
        var from=left+game.recorder.region.x/duration*span
        var to=left+game.recorder.region.y/duration*span
        draw_rect(Rect2(from,1,maxf(2.0,to-from),size.y-2),Color(.5,.8,1,.12))
        draw_rect(Rect2(from,1,maxf(2.0,to-from),size.y-2),Color("d9d4ca"),false,1)
    for section in ["verse2","bridge"]:
        var at=game.section_mark(section)
        if at>=0:
            var x=left+at/duration*span;draw_line(Vector2(x,0),Vector2(x,size.y),Color("d9d4ca"),2)
    for bookmark in game.features.bookmarks():
        var x=left+float(bookmark.start)/duration*span
        draw_line(Vector2(x,0),Vector2(x,size.y),Color("ffcd73"),2)
    var playhead=game.song_time if recorder_mode else game.cursor
    var x=left+clampf(playhead,0,duration)/duration*span
    draw_line(Vector2(x,0),Vector2(x,size.y),Color("ffe699"),3)
