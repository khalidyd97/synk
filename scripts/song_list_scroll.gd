extends Node
# One pointer owns a gesture. Touch/mouse drags cannot accidentally select a row.
var scroll: ScrollContainer
var pressing=false
var dragged=false
var pointer=-2
var start=Vector2.ZERO
var previous=Vector2.ZERO
var origin=0.0
var velocity=0.0
var last_ms=0
var motion_position=0.0
func _ready() -> void:
    scroll.visibility_changed.connect(func():
        if not scroll.is_visible_in_tree(): stop())
func stop() -> void:
    pressing=false; dragged=false; pointer=-2; velocity=0
func handle(id: int,point: Vector2,down: bool,up: bool,cancelled: bool=false) -> void:
    if down:
        if pressing or not scroll.get_global_rect().has_point(point): return
        pressing=true; dragged=false; pointer=id; start=point; previous=point
        origin=scroll.scroll_vertical; velocity=0; last_ms=Time.get_ticks_msec(); return
    if not pressing or id!=pointer: return
    if up or cancelled:
        pressing=false; pointer=-2
        motion_position=scroll.scroll_vertical
        if cancelled: velocity=0
        return
    var factor=maxf(.01,scroll.get_global_transform().get_scale().y)
    var delta=(point.y-start.y)/factor
    if absf(point.y-start.y)>12: dragged=true
    if dragged:
        scroll.scroll_vertical=roundi(origin-delta)
        var now=Time.get_ticks_msec(); var dt=maxf(.008,(now-last_ms)/1000.0)
        velocity=lerpf(velocity,(previous.y-point.y)/factor/dt,.4)
        previous=point; last_ms=now
        scroll.get_viewport().set_input_as_handled()
func _input(event: InputEvent) -> void:
    if not scroll.is_visible_in_tree(): return
    if event is InputEventScreenTouch: handle(event.index,event.position,event.pressed,not event.pressed,event.canceled)
    elif event is InputEventScreenDrag: handle(event.index,event.position,false,false)
    elif event is InputEventMouseButton and event.device!=-1 and event.button_index==MOUSE_BUTTON_LEFT:
        handle(-1,event.position,event.pressed,not event.pressed)
    elif event is InputEventMouseMotion and event.device!=-1: handle(-1,event.position,false,false)
func _process(delta: float) -> void:
    if pressing or not scroll.is_visible_in_tree() or absf(velocity)<8: return
    var old=motion_position
    var rail=scroll.get_v_scroll_bar()
    motion_position=clampf(motion_position+velocity*delta,0,maxf(0,rail.max_value-rail.page))
    scroll.scroll_vertical=roundi(motion_position)
    velocity*=exp(-7*delta)
    if is_equal_approx(old,motion_position): velocity=0
