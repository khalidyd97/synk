extends Control

var game: Control
var dragging = false
var note_drag = false
var drag_checkpoint = false
var window_start = 0.0
var grab_offset = 0.0

func start_time() -> float: return maxf(0,game.cursor-game.zoom_seconds*.35)
func lane(y: float) -> int: return clampi(int((y-.22)/.78*13),0,12)
func _process(_delta: float) -> void: queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==-1: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed: begin(event.position)
		else: dragging=false
	elif event is InputEventMouseMotion and dragging: move_pointer(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed: begin(event.position)
		else: dragging=false
	elif event is InputEventScreenDrag and dragging: move_pointer(event.position)
	accept_event()
func begin(p: Vector2) -> void:
	dragging=true; drag_checkpoint=false; window_start=start_time()
	var time=window_start+p.x/size.x*game.zoom_seconds
	var nearest=-1; var best=game.zoom_seconds*.02
	if p.y/size.y>=.22:
		for i in game.document.notes.size():
			var n: Dictionary=game.document.notes[i]; var distance=absf(float(n.time)-time)
			if int(n.lane)==lane(p.y/size.y) and distance<best: best=distance; nearest=i
	game.document.selected=nearest; note_drag=nearest>=0
	if note_drag: grab_offset=time-float(game.document.selection().time)
	else: game.seek_to(time)
	game.refresh_editor()
func move_pointer(p: Vector2) -> void:
	var time=window_start+p.x/size.x*game.zoom_seconds
	if note_drag:
		if not drag_checkpoint: game.stop_audition(); game.document.checkpoint(); drag_checkpoint=true
		game.document.move_note(SynkChart.snap(time-grab_offset,game.song.bpm,game.snap_division),lane(p.y/size.y),game.length())
		game.refresh_editor()
	else: game.seek_to(time)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0c1028"))
	if game==null: return
	var start=start_time(); var span=game.zoom_seconds; var font=ThemeDB.fallback_font
	if game.loop_enabled:
		var a=(game.loop_a-start)/span*size.x; var b=(game.loop_b-start)/span*size.x
		draw_rect(Rect2(Vector2(clampf(a,0,size.x),0),Vector2(maxf(0,minf(b,size.x)-maxf(0,a)),size.y)),Color(.15,.6,.3,.15))
	for i in 14:
		var y=(.22+i*.78/13)*size.y; draw_line(Vector2(0,y),Vector2(size.x,y),Color("312141"),1)
		if i<13: draw_string(font,Vector2(3,y+14),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8b76ab"))
	var beat=60.0/float(game.song.bpm); var t=ceil(start/beat)*beat
	while t<start+span:
		var x=(t-start)/span*size.x; draw_line(Vector2(x,0),Vector2(x,size.y),Color(.5,.3,.7,.22),1)
		t+=beat
	for i in 5: draw_string(font,Vector2(i*size.x/5+4,17),"%.2f s" % (start+i*span/5),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a2b9e0"))
	for i in 200:
		var time=start+i*span/200
		if time>game.length() or game.waveform.is_empty(): continue
		var index=clampi(int(time/game.length()*game.waveform.size()),0,game.waveform.size()-1)
		var peak=game.waveform[index]*size.y*.055
		draw_line(Vector2(i*size.x/200,size.y*.13-peak),Vector2(i*size.x/200,size.y*.13+peak),Color("36b6d9"),2)
	var shown=0
	for i in game.document.notes.size():
		var n: Dictionary=game.document.notes[i]
		if n.time+n.duration<start or n.time>start+span: continue
		shown+=1
		if shown>2000: break
		var x=(n.time-start)/span*size.x; var y=(.22+(n.lane+.5)*.78/13)*size.y
		var color=Color("f13ae4") if n.kind=="flick" else Color("29d4ff")
		if n.duration>0:
			var points=PackedVector2Array()
			for part in 25:
				var time=float(n.time)+float(n.duration)*part/24
				points.append(Vector2(clampf((time-start)/span*size.x,0,size.x),(.22+(SynkChart.lane_at(n,time)+.5)*.78/13)*size.y))
			draw_polyline(points,Color(color,.5),5,true)
		if x>=0:
			if i==game.document.selected: draw_rect(Rect2(Vector2(x-9,y-10),Vector2(18,20)),Color.WHITE)
			draw_rect(Rect2(Vector2(x-6,y-7),Vector2(12,14)),color)
			if n.kind=="flick":
				var direction: Vector2=[Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][int(n.direction)]
				var tip=Vector2(x,y)+direction*10; draw_line(tip-direction*6+direction.orthogonal()*5,tip,Color.WHITE,2,true); draw_line(tip,tip-direction*6-direction.orthogonal()*5,Color.WHITE,2,true)
	var playhead=(game.cursor-start)/span*size.x; draw_line(Vector2(playhead,0),Vector2(playhead,size.y),Color("ffe189"),2)
