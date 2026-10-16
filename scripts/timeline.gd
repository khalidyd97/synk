extends Control

var game: Control
var view_start=0.0
var window_start=0.0
var dragging=false
var note_drag=false
var drag_checkpoint=false
var shape_point=-1
var tail_drag=false
var pending_create=false
var pending_shape=false
var press_point=Vector2.ZERO
var grab_offset=0.0
var pan_origin=0.0
var touches: Dictionary={}
var multi_touch=false
var range_active=false
var range_anchor=0.0
var range_start=0.0
var range_end=0.0
var range_indices: Array[int]=[]
var last_pointer=Vector2.ZERO
var touch_range_snapshot: Dictionary={}
var group_mode=false
var group_drag=false
var group_sources: Array=[]
var group_start=0.0
var group_end=0.0
var selection_locked=false
var selection_count=0
var selection_gap=0.0
var selection_span=0.0
const HANDLE_RADIUS=22.0

func _ready() -> void:
    clip_contents=true
    mouse_filter=Control.MOUSE_FILTER_STOP
func grid() -> Rect2: return Rect2(82,34,maxf(10,size.x-86),maxf(10,size.y-38))
func start_time() -> float: return view_start
func lane_x(value: float) -> float: return grid().position.x+(value+.5)*grid().size.x/SynkChart.LANES
func time_y(time: float) -> float: return grid().position.y+(time-view_start)/game.zoom_seconds*grid().size.y
func point_time(point: Vector2) -> float: return clampf(view_start+(point.y-grid().position.y)/grid().size.y*game.zoom_seconds,0,game.length())
func lane(x: float) -> int: return clampi(int((x-grid().position.x)/grid().size.x*SynkChart.LANES),0,SynkChart.MAX_LANE)
func free_lane(x: float) -> float:
    var value=clampf((x-grid().position.x)/grid().size.x*SynkChart.LANES-.5,0,SynkChart.MAX_LANE)
    return roundf(value) if absf(value-roundf(value))<.18 else value
func limit_view() -> void: view_start=clampf(view_start,0,maxf(0,game.length()-game.zoom_seconds*.6))
func reveal_time(time: float) -> void:
    if time<view_start or time>view_start+game.zoom_seconds: view_start=maxf(0,time-game.zoom_seconds*.3)
    limit_view()
func zoom_by(factor: float) -> void:
    var anchor=game.cursor
    var fraction=(anchor-view_start)/game.zoom_seconds
    game.zoom_seconds=clampf(game.zoom_seconds*factor,1,64)
    view_start=anchor-fraction*game.zoom_seconds; limit_view(); queue_redraw()
func selected_slide() -> Dictionary:
    var n: Dictionary=game.document.selection()
    return n if not n.is_empty() and n.kind=="slide" else {}
func begin_shape(point: Vector2, allow_insert: bool = true) -> bool:
    var n=selected_slide()
    if n.is_empty(): return false
    var path: Array=n.path if n.path.size()>=2 else [{"offset":0.0,"lane":float(n.lane)},{"offset":float(n.duration),"lane":float(n.end_lane)}]
    for i in path.size():
        var handle=Vector2(lane_x(float(path[i].lane)),time_y(float(n.time)+float(path[i].offset)))
        if handle.distance_to(point)<=HANDLE_RADIUS:
            if i==path.size()-1: tail_drag=true; return true
            if i==0: return false
            n.path=path; shape_point=i; return true
    if not allow_insert: return false
    var at=point_time(point)
    var offset=at-float(n.time)
    if offset<=.03 or offset>=float(n.duration)-.03: return false
    if absf(lane_x(SynkChart.lane_at(n,at))-point.x)>HANDLE_RADIUS: return false
    game.document.checkpoint(); drag_checkpoint=true; n.path=path
    var insert_at=1
    while insert_at<n.path.size() and float(n.path[insert_at].offset)<offset: insert_at+=1
    n.path.insert(insert_at,{"offset":offset,"lane":SynkChart.lane_at(n,at)})
    shape_point=insert_at
    return true
func move_shape(point: Vector2) -> void:
    var n=selected_slide()
    if n.is_empty() or shape_point<0 or shape_point>=n.path.size(): return
    if not drag_checkpoint: game.document.checkpoint(); drag_checkpoint=true
    var at=SynkChart.snap(point_time(point),game.chart_bpm(),game.snap_division,game.chart_offset())
    n.path[shape_point].offset=clampf(at-float(n.time),float(n.path[shape_point-1].offset)+.01,float(n.path[shape_point+1].offset)-.01)
    n.path[shape_point].lane=free_lane(point.x)
    game.document.dirty=true; game.refresh_editor()
func _process(delta: float) -> void:
    if not is_visible_in_tree(): return
    if dragging and game.editor_tool=="range" and not group_drag:
        var edge_direction=-1.0 if last_pointer.y<grid().position.y+24 else (1.0 if last_pointer.y>grid().end.y-24 else 0.0)
        if edge_direction!=0:
            view_start+=edge_direction*delta*game.zoom_seconds*.6; limit_view()
            move_pointer(last_pointer)
    if game.audio.playing and not dragging:
        if game.cursor>view_start+game.zoom_seconds*.82 or game.cursor<view_start:
            view_start=maxf(0,game.cursor-game.zoom_seconds*.3); limit_view()
    queue_redraw()
func _gui_input(event: InputEvent) -> void:
    if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==-1: return
    if event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index]=event.position
            if touches.size()==1:
                touch_range_snapshot={"active":range_active,"start":range_start,"end":range_end}
                begin(event.position)
            else:
                multi_touch=true; dragging=false; pending_create=false; pending_shape=false
                if group_drag: finish_group_drag()
                if game.editor_tool=="range" and not touch_range_snapshot.is_empty():
                    range_active=touch_range_snapshot.active; range_start=touch_range_snapshot.start; range_end=touch_range_snapshot.end
                    update_range()
        else:
            if not multi_touch and dragging: finish(event.position)
            touches.erase(event.index)
            if touches.is_empty(): multi_touch=false
    elif event is InputEventScreenDrag:
        if multi_touch and touches.size()>=2:
            var before=touches.values()
            var center_before=(before[0]+before[1])*.5
            var distance_before=maxf(10,before[0].distance_to(before[1]))
            var anchor=point_time(center_before)
            touches[event.index]=event.position
            var after=touches.values()
            var center_after=(after[0]+after[1])*.5
            var distance_after=maxf(10,after[0].distance_to(after[1]))
            game.zoom_seconds=clampf(game.zoom_seconds*distance_before/distance_after,1,64)
            view_start=anchor-(center_after.y-grid().position.y)/grid().size.y*game.zoom_seconds
            limit_view()
        elif dragging:
            touches[event.index]=event.position; move_pointer(event.position)
    elif event is InputEventMouseButton:
        if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            var direction=-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1
            if event.ctrl_pressed: zoom_by(.8 if direction<0 else 1.25)
            else: view_start+=direction*game.zoom_seconds*.12; limit_view()
        elif event.button_index==MOUSE_BUTTON_LEFT:
            if event.pressed: begin(event.position)
            elif dragging: finish(event.position)
    elif event is InputEventMouseMotion and dragging: move_pointer(event.position)
    accept_event()
func begin(point: Vector2) -> void:
    if not grid().has_point(point): return
    game.stop_audition()
    dragging=true; note_drag=false; tail_drag=false; pending_create=false; pending_shape=false; shape_point=-1; drag_checkpoint=false
    press_point=point; pan_origin=view_start; window_start=view_start
    last_pointer=point
    if game.editor_tool=="range" and range_active and group_mode:
        collect_range()
        if not range_indices.is_empty():
            group_drag=true; group_sources=[]; group_start=range_start; group_end=range_end
            for index in range_indices: group_sources.append(game.document.notes[index].duplicate(true))
            return
    if game.editor_tool=="range":
        selection_locked=false
        range_active=true
        range_anchor=SynkChart.snap(point_time(point),game.chart_bpm(),game.snap_division,game.chart_offset())
        range_start=range_anchor; range_end=range_anchor
        game.document.selected=-1
        update_range(); return
    range_active=false; range_indices.clear()
    if game.editor_tool=="select":
        var selected: Dictionary=game.document.selection()
        if not selected.is_empty() and selected.kind in ["hold","slide"]:
            var tail=Vector2(lane_x(float(selected.end_lane)),time_y(float(selected.time)+float(selected.duration)))
            if tail.distance_to(point)<=HANDLE_RADIUS: tail_drag=true; return
        if begin_shape(point,false): game.refresh_editor(); return
    var nearest=-1; var best=HANDLE_RADIUS
    for i in game.document.notes.size():
        var n: Dictionary=game.document.notes[i]
        var distance=Vector2(lane_x(float(n.lane)),time_y(float(n.time))).distance_to(point)
        if distance<best: best=distance; nearest=i
    if nearest>=0:
        game.document.selected=nearest; note_drag=true
        grab_offset=point_time(point)-float(game.document.selection().time)
    elif game.editor_tool!="select": pending_create=true
    else:
        var selected=selected_slide()
        var at=point_time(point)
        pending_shape=not selected.is_empty() and at>float(selected.time)+.03 and at<float(selected.time)+float(selected.duration)-.03 and absf(point.x-lane_x(SynkChart.lane_at(selected,at)))<=HANDLE_RADIUS
        if not pending_shape: game.document.selected=-1
    game.refresh_editor()
func create_note(point: Vector2) -> void:
    var time=SynkChart.snap(point_time(point),game.chart_bpm(),game.snap_division,game.chart_offset())
    var n=SynkChart.note(minf(time,game.length()-.01),lane(point.x),game.editor_tool)
    if n.kind in ["hold","slide"]: n.duration=minf(60.0/game.chart_bpm(),game.length()-float(n.time))
    game.document.checkpoint(); drag_checkpoint=true
    game.document.notes.append(n); game.document.selected=game.document.notes.size()-1
    pending_create=false; tail_drag=n.kind in ["hold","slide"]
    game.refresh_editor()
func move_pointer(point: Vector2) -> void:
    last_pointer=point
    if group_drag:
        move_group(point); return
    if game.editor_tool=="range" and range_active:
        var at=SynkChart.snap(point_time(point),game.chart_bpm(),game.snap_division,game.chart_offset())
        range_start=minf(at,range_anchor); range_end=maxf(at,range_anchor)
        update_range(); return
    if pending_shape:
        if point.distance_to(press_point)<8: return
        pending_shape=false
        if begin_shape(press_point): move_shape(point); return
    if shape_point>=0: move_shape(point); return
    if pending_create:
        if press_point.distance_to(point)<8: return
        create_note(press_point)
    if note_drag or tail_drag:
        if not drag_checkpoint: game.document.checkpoint(); drag_checkpoint=true
        var n: Dictionary=game.document.selection()
        if n.is_empty(): return
        var time=SynkChart.snap(point_time(point),game.chart_bpm(),game.snap_division,game.chart_offset())
        if tail_drag:
            var duration=clampf(time-float(n.time),.05,maxf(.05,game.length()-float(n.time)))
            var old_duration=maxf(.001,float(n.duration))
            if n.has("checkpoints"):
                for i in n.checkpoints.size(): n.checkpoints[i]=float(n.checkpoints[i])*duration/old_duration
            if n.kind=="slide" and n.path.size()>=2:
                var old=maxf(.001,float(n.duration))
                for p in n.path: p.offset=float(p.offset)*duration/old
                n.path[-1].lane=float(lane(point.x))
            n.duration=duration
            n.end_lane=lane(point.x) if n.kind=="slide" else int(n.lane)
        else: game.document.move_note(SynkChart.snap(point_time(point)-grab_offset,game.chart_bpm(),game.snap_division,game.chart_offset()),lane(point.x),game.length())
        game.refresh_editor()
    else:
        view_start=pan_origin-(point.y-press_point.y)/grid().size.y*game.zoom_seconds; limit_view()
func finish(point: Vector2) -> void:
    if group_drag:
        move_group(point); finish_group_drag(); dragging=false; game.refresh_editor(); return
    if game.editor_tool=="range" and range_active:
        move_pointer(point)
        if range_end-range_start<.01:
            range_end=minf(game.length(),range_start+(60.0/game.chart_bpm()/maxi(1,game.snap_division)))
        dragging=false; update_range(); return
    if pending_shape: begin_shape(press_point)
    elif pending_create: create_note(press_point)
    elif not note_drag and not tail_drag and shape_point<0 and point.distance_to(press_point)<8:
        game.seek_to(point_time(point))
    dragging=false; pending_create=false; pending_shape=false; shape_point=-1; tail_drag=false
    game.refresh_editor()

func collect_range() -> void:
    if group_drag: return
    if selection_locked and selection_count==game.document.notes.size() and not range_indices.is_empty():
        var first=INF
        for index in range_indices: first=minf(first,float(game.document.notes[index].time))
        range_start=maxf(0,first-selection_gap); range_end=minf(game.length(),range_start+selection_span)
        return
    selection_locked=false
    range_indices.clear()
    for i in game.document.notes.size():
        var time=float(game.document.notes[i].time)
        if time>=range_start-.001 and time<range_end-.001: range_indices.append(i)

func update_range() -> void:
    collect_range()
    game.refresh_editor(); queue_redraw()

func clear_range() -> void:
    range_active=false; range_indices.clear(); group_mode=false; group_drag=false; selection_locked=false; group_sources.clear(); queue_redraw()

func toggle_group_move() -> void:
    if not range_active or range_indices.is_empty(): return
    group_mode=not group_mode; game.refresh_editor()

func move_group(point: Vector2) -> void:
    if group_sources.is_empty() or point.distance_to(press_point)<8: return
    var seconds=(point.y-press_point.y)/grid().size.y*game.zoom_seconds
    if game.snap_division>0: seconds=snappedf(seconds,60.0/float(game.chart_bpm())/game.snap_division)
    var lanes=roundi((point.x-press_point.x)/(grid().size.x/SynkChart.LANES))
    var earliest=group_start; var latest=group_end; var left=INF; var right=-INF
    for n in group_sources:
        earliest=minf(earliest,float(n.time)); latest=maxf(latest,float(n.time)+float(n.duration))
        left=minf(left,minf(float(n.lane),float(n.end_lane))); right=maxf(right,maxf(float(n.lane),float(n.end_lane)))
        for p in n.path: left=minf(left,float(p.lane)); right=maxf(right,float(p.lane))
    seconds=clampf(seconds,-earliest,maxf(-earliest,game.length()-latest))
    lanes=clampi(lanes,ceili(-left),floori(SynkChart.MAX_LANE-right))
    if is_zero_approx(seconds) and lanes==0 and not drag_checkpoint: return
    if not drag_checkpoint: game.document.checkpoint(); drag_checkpoint=true
    for i in range_indices.size():
        var n: Dictionary=group_sources[i].duplicate(true)
        n.time+=seconds; n.lane+=lanes; n.end_lane+=lanes
        for p in n.path: p.lane+=lanes
        game.document.notes[range_indices[i]]=n
    range_start=group_start+seconds; range_end=group_end+seconds
    game.document.dirty=true; game.refresh_editor()

func finish_group_drag() -> void:
    group_drag=false; selection_locked=true; selection_count=game.document.notes.size()
    var first=INF
    for index in range_indices: first=minf(first,float(game.document.notes[index].time))
    selection_gap=first-range_start; selection_span=range_end-range_start
    group_sources.clear()
func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),Color("0c1024"))
    if game==null: return
    var area=grid(); var font=ThemeDB.fallback_font
    var beat=60.0/float(game.chart_bpm())
    var step=beat/maxi(1,game.snap_division)
    if game.zoom_seconds/step>300: step=beat
    for i in SynkChart.LANES:
        var x=area.position.x+i*area.size.x/SynkChart.LANES
        draw_rect(Rect2(x,area.position.y,area.size.x/SynkChart.LANES,area.size.y),Color(.07,.065,.15,.6) if i%2==0 else Color(.035,.04,.1,.5))
        draw_line(Vector2(x,area.position.y),Vector2(x,area.end.y),Color(.45,.35,.65,.3),1)
        draw_string(font,Vector2(lane_x(i)-15,23),str(i+1),HORIZONTAL_ALIGNMENT_CENTER,30,15,Color("baacd9"))
    draw_string(font,Vector2(8,23),"TIME ↓",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8e82b6"))
    if game.loop_enabled:
        var a=clampf(time_y(game.loop_a),area.position.y,area.end.y)
        var b=clampf(time_y(game.loop_b),area.position.y,area.end.y)
        draw_rect(Rect2(area.position.x,a,area.size.x,maxf(0,b-a)),Color(.1,.8,.7,.09))
    if range_active:
        var a=clampf(time_y(range_start),area.position.y,area.end.y)
        var b=clampf(time_y(range_end),area.position.y,area.end.y)
        draw_rect(Rect2(area.position.x,a,area.size.x,maxf(0,b-a)),Color(.22,.75,1,.16))
        for y in [a,b]: draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),Color("65deff"),2,true)
    var offset=game.chart_offset()
    var at=offset+ceil((view_start-offset)/step)*step
    while at<=minf(game.length(),view_start+game.zoom_seconds):
        var y=time_y(at)
        var is_beat=absf((at-offset)/beat-roundf((at-offset)/beat))<.001
        var measure=absf((at-offset)/(beat*4)-roundf((at-offset)/(beat*4)))<.001
        draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),Color(.6,.5,.9,.5 if measure else (.24 if is_beat else .09)),2 if measure else 1)
        if is_beat:
            var label="%d.%d" % [floori(roundf((at-offset)/beat)/4)+1,posmod(roundi((at-offset)/beat),4)+1]
            draw_string(font,Vector2(37,y+5),label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c2b1eb") if measure else Color("706889"))
        at+=step
    var peak_max=.001
    for peak in game.waveform: peak_max=maxf(peak_max,peak)
    for i in 180:
        var time=view_start+float(i)/180*game.zoom_seconds
        if time>game.length() or game.waveform.is_empty(): continue
        var index=clampi(int(time/game.length()*game.waveform.size()),0,game.waveform.size()-1)
        var peak=sqrt(game.waveform[index]/peak_max)*13
        var y=area.position.y+float(i)/180*area.size.y
        draw_line(Vector2(18-peak,y),Vector2(18+peak,y),Color(.22,.75,.9,.65),2,true)
    for i in game.document.notes.size():
        var n: Dictionary=game.document.notes[i]
        if float(n.time)+float(n.duration)<view_start or float(n.time)>view_start+game.zoom_seconds: continue
        var selected=i==game.document.selected or (range_active and range_indices.has(i))
        var color=Color("ff6ddd") if n.kind=="flick" else (Color("b58aff") if n.kind in ["hold","slide"] else Color("52dfff"))
        if game.recorder and not game.recorder.highlights.is_empty() and game.recorder.highlights.has(JSON.stringify(n)):
            color=Color("ffe699")
        var head=Vector2(lane_x(float(n.lane)),time_y(float(n.time)))
        var width=minf(42,area.size.x/SynkChart.LANES*.6)
        if n.kind in ["hold","slide"]:
            var points=PackedVector2Array()
            for part in 49:
                var time=float(n.time)+float(n.duration)*part/48
                points.append(Vector2(lane_x(SynkChart.lane_at(n,time)),time_y(time)))
            draw_polyline(points,Color(color,.18),16,true)
            draw_polyline(points,Color(color,.85),6,true)
            var tail=points[-1]
            draw_circle(tail,10 if selected else 6,color)
            draw_circle(tail,5,Color("101329"))
            if selected: draw_arc(tail,18,0,TAU,32,Color(1,1,1,.7),1.5,true)
        if head.y>=area.position.y:
            if selected: draw_rect(Rect2(head-Vector2(width*.5+4,10),Vector2(width+8,20)),Color.WHITE,false,2)
            draw_rect(Rect2(head-Vector2(width*.5,6),Vector2(width,12)),color)
            if n.kind=="flick":
                var direction=[Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][int(n.direction)]
                var center=head+Vector2(0,-18)
                var tip=center+direction*8
                draw_line(center-direction*5+direction.orthogonal()*6,tip,Color.WHITE,3,true)
                draw_line(tip,center-direction*5-direction.orthogonal()*6,Color.WHITE,3,true)
        if selected and n.kind=="slide":
            for p in n.path:
                var handle=Vector2(lane_x(float(p.lane)),time_y(float(n.time)+float(p.offset)))
                draw_circle(handle,8,Color.WHITE); draw_circle(handle,4,color)
    for mark in [["verse2","VERSE 2",Color("52dfff")],["bridge","BRIDGE",Color("ff6ddd")]]:
        var time=float(game.song.get(mark[0],-1))
        if time<view_start or time>view_start+game.zoom_seconds or time<0: continue
        var y=time_y(time)
        draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),Color(mark[2],.6),2)
        draw_string(font,Vector2(area.position.x+6,y-7),mark[1],HORIZONTAL_ALIGNMENT_LEFT,-1,12,mark[2])
    for bookmark in game.features.bookmarks():
        var mark_y=time_y(float(bookmark.start))
        if mark_y>=area.position.y and mark_y<=area.end.y:
            draw_line(Vector2(area.position.x,mark_y),Vector2(area.end.x,mark_y),Color("ffcd73"),1,true)
            draw_string(font,Vector2(area.position.x+8,mark_y-5),str(bookmark.name).left(24),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffcd73"))
    var playhead=time_y(game.cursor)
    if playhead>=area.position.y and playhead<=area.end.y:
        draw_line(Vector2(area.position.x,playhead),Vector2(area.end.x,playhead),Color("ffe699"),2,true)
        draw_colored_polygon(PackedVector2Array([Vector2(area.position.x-8,playhead-6),Vector2(area.position.x,playhead),Vector2(area.position.x-8,playhead+6)]),Color("ffe699"))
