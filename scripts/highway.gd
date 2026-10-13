extends Control

var game: Control
const PINK = Color("f32af9")
const BLUE = Color("22cfff")
const PURPLE = Color("8c36ff")

func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void: queue_redraw()
func project(lane: float, depth: float) -> Vector2:
	return Vector2(.5 + ((lane + .5) / 13 - .5) * lerpf(.86, .15, depth), lerpf(.765, .12, depth)) * size
func depth(time: float) -> float: return clampf((time - game.song_time) / 2.6, -.12, 1)
func glow(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	for layer in [7, 4, 2]: draw_line(a, b, Color(color, .16 / layer), width * layer, true)
	draw_line(a, b, color, width, true); draw_line(a, b, Color(Color("e8e4ff"),color.a), maxf(1, width * .2), true)
func cap(lane: float, d: float, color: Color) -> void:
	var a = project(lane - .34, d); var b = project(lane + .34, d)
	glow(a, b, lerpf(14, 3, d), color)
	var rect = Rect2(a - Vector2(0, lerpf(7, 1.5, d)), Vector2(b.x - a.x, lerpf(14, 3, d)))
	var style = StyleBoxFlat.new(); style.bg_color = Color(color, .5); style.border_color = Color("f3ddff"); style.set_border_width_all(1); style.set_corner_radius_all(4)
	draw_style_box(style, rect)
func draw_note(n: Dictionary, active = false) -> void:
	var color = PINK if int(n.lane) % 2 == 0 else BLUE
	var d = 0.0 if active else depth(float(n.time))
	var lane = SynkChart.lane_at(n, game.song_time) if active else float(n.lane)
	if n.kind in ["hold", "slide"]:
		var start = maxf(float(n.time), game.song_time) if active else float(n.time)
		var end = float(n.time) + float(n.duration)
		for i in 24:
			var t0 = lerpf(start, end, i / 24.0); var t1 = lerpf(start, end, (i+1) / 24.0)
			if t0 - game.song_time > 2.6: continue
			var l0 = SynkChart.lane_at(n, t0); var l1 = SynkChart.lane_at(n, t1)
			var a = project(l0 - .3, maxf(0, depth(t0))); var b = project(l1 - .3, maxf(0, depth(t1)))
			var c = project(l1 + .3, maxf(0, depth(t1))); var e = project(l0 + .3, maxf(0, depth(t0)))
			draw_colored_polygon(PackedVector2Array([a,b,c,e]), Color(color,.28)); glow(a,b,1.2,color); glow(c,e,1.2,color)
		if end - game.song_time <= 2.6: cap(float(n.end_lane) if n.kind == "slide" else float(n.lane), depth(end), color)
	if n.kind != "flick": cap(lane, d, color); return
	var p = project(lane,d); var scale = lerpf(1,.2,d)
	var direction: Vector2 = [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][int(n.direction)]
	var side = direction.orthogonal()
	for i in 2:
		var tip = p + direction * (12 - i * 15) * scale
		glow(tip + (-direction * 15 + side * 17) * scale, tip, 4 * scale, color)
		glow(tip, tip + (-direction * 15 - side * 17) * scale, 4 * scale, color)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size), Color("02030b"))
	if game == null: return
	for i in 5:
		var spread = .17 + i * .07
		glow(Vector2(.5-spread,.3+i*.08)*size,Vector2(.46,-.05)*size,2,Color(BLUE,.08))
		glow(Vector2(.5+spread,.3+i*.08)*size,Vector2(.54,-.05)*size,2,Color(BLUE,.08))
	draw_colored_polygon(PackedVector2Array([project(-.5,-.12),project(-.5,1),project(12.5,1),project(12.5,-.12)]),Color("060410"))
	for i in 14:
		glow(project(i-.5,-.12),project(i-.5,1),2 if i in [0,13] else .7,Color(PURPLE,.7 if game.mode == "record" else .3))
	for i in 16:
		var d = fposmod(i/16.0 - Time.get_ticks_msec()*.0001,1)
		draw_line(project(-.5,d),project(12.5,d),Color(PURPLE,.12),1,true)
	if game.mode in ["play","paused"]:
		for i in range(game.live.size()-1,-1,-1):
			var live: Dictionary = game.live[i]
			if not live.done and float(live.note.time)-game.song_time<=2.6: draw_note(live.note,live.started)
	if game.mode == "record":
		if game.overdub:
			for n in game.document.notes:
				if n.time+n.duration>=game.song_time and n.time-game.song_time<=2.6: draw_note(n,n.time<=game.song_time)
		for gesture in game.capture.gestures.values(): draw_note(gesture.note,true)
	glow(project(-1,0),project(13,0),3,PINK)
	for lane in 13:
		var p = project(lane,0)
		draw_arc(p,12,0,TAU,24,Color(PURPLE,.8),1,true)
		if game.flash>0 and game.flash_lane==lane: glow(p-Vector2(20,0),p+Vector2(20,0),12*game.flash,Color(PINK,game.flash))
	draw_string(ThemeDB.fallback_font,Vector2(size.x*.445,70),"S Y N K",HORIZONTAL_ALIGNMENT_LEFT,-1,42,Color("d2a6ff"))
