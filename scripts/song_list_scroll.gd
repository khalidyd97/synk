extends Node
# One pointer owns a gesture. Float position and analytic friction give the same
# coast at every refresh rate. GUI clicks are cancelled only after a real drag.
const MODAL=preload("res://scripts/modal_input.gd")
const CANCEL_DEVICE=-923
var scroll:ScrollContainer
var horizontal=false
var pressing=false
var dragged=false
var pointer=-2
var start=Vector2.ZERO
var previous=Vector2.ZERO
var origin=0.0
var velocity=0.0
var last_us=0
var moved_us=0
var motion_position=0.0
var friction=7.0
var on_press:Callable
var on_drag:Callable
var on_release:Callable
func _ready() -> void:
	scroll.visibility_changed.connect(func():if not scroll.is_visible_in_tree():stop())
func position_value() -> float:return float(scroll.scroll_horizontal if horizontal else scroll.scroll_vertical)
func limit() -> float:
	var bar=scroll.get_h_scroll_bar() if horizontal else scroll.get_v_scroll_bar()
	return maxf(0,bar.max_value-bar.page)
func set_position(value:float) -> void:
	motion_position=clampf(value,0,limit())
	if horizontal:scroll.scroll_horizontal=roundi(motion_position)
	else:scroll.scroll_vertical=roundi(motion_position)
func stop() -> void:
	pressing=false;dragged=false;pointer=-2;velocity=0
func cancel_gui_press() -> void:
	var away=Vector2(-10000,-10000)
	if pointer>=0:
		var cancelled=InputEventScreenTouch.new();cancelled.device=CANCEL_DEVICE;cancelled.index=pointer;cancelled.position=away;cancelled.pressed=false;cancelled.canceled=true
		get_viewport().push_input.call_deferred(cancelled,true)
	else:
		var motion=InputEventMouseMotion.new();motion.device=CANCEL_DEVICE;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;motion.position=away;motion.global_position=away
		var up=InputEventMouseButton.new();up.device=CANCEL_DEVICE;up.button_index=MOUSE_BUTTON_LEFT;up.position=away;up.global_position=away;up.pressed=false
		get_viewport().push_input.call_deferred(motion,true);get_viewport().push_input.call_deferred(up,true)
func handle(id:int,point:Vector2,down:bool,up:bool,cancelled:bool=false) -> void:
	if not scroll.is_visible_in_tree() or MODAL.blocked(scroll):stop();return
	if down:
		if pressing or not scroll.get_global_rect().has_point(point):return
		var bar=scroll.get_h_scroll_bar() if horizontal else scroll.get_v_scroll_bar()
		if bar.is_visible_in_tree() and bar.get_global_rect().has_point(point):stop();return
		if on_press.is_valid():on_press.call()
		pressing=true;dragged=false;pointer=id;start=point;previous=point
		origin=position_value();motion_position=origin;velocity=0;last_us=Time.get_ticks_usec();moved_us=last_us;return
	if not pressing or id!=pointer:return
	if up or cancelled:
		if cancelled or Time.get_ticks_usec()-moved_us>90000:velocity=0
		if dragged:get_viewport().set_input_as_handled()
		pressing=false;pointer=-2
		if on_release.is_valid():on_release.call()
		return
	var distance=point-start
	var primary=distance.x if horizontal else distance.y
	var secondary=distance.y if horizontal else distance.x
	if not dragged:
		if absf(primary)<=12 or absf(primary)<absf(secondary)*.8:return
		dragged=true;cancel_gui_press()
		if on_drag.is_valid():on_drag.call()
	var scale=scroll.get_global_transform_with_canvas().get_scale()
	var factor=maxf(.01,absf(scale.x if horizontal else scale.y))
	set_position(origin-primary/factor)
	var now=Time.get_ticks_usec();var dt=maxf(.001,(now-last_us)/1000000.0)
	var movement=previous.x-point.x if horizontal else previous.y-point.y
	velocity=lerpf(velocity,clampf(movement/factor/dt,-6000,6000),1.0-exp(-dt*24.0))
	previous=point;last_us=now;moved_us=now
	get_viewport().set_input_as_handled()
func _input(event:InputEvent) -> void:
	if event.device==CANCEL_DEVICE:return
	if scroll==null or not scroll.is_visible_in_tree() or MODAL.blocked(scroll):stop();return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT]:
		if scroll.get_global_rect().has_point(event.position):stop()
		return
	if event is InputEventScreenTouch:handle(event.index,event.position,event.pressed,not event.pressed,event.canceled)
	elif event is InputEventScreenDrag:handle(event.index,event.position,false,false)
	elif event is InputEventMouseButton and event.device!=-1 and event.button_index==MOUSE_BUTTON_LEFT:handle(-1,event.position,event.pressed,not event.pressed)
	elif event is InputEventMouseMotion and event.device!=-1:handle(-1,event.position,false,false)
func _process(delta:float) -> void:
	if scroll==null:return
	if not scroll.is_visible_in_tree() or MODAL.blocked(scroll):stop();return
	if pressing or absf(velocity)<8:return
	var decay=exp(-friction*delta)
	var requested=motion_position+velocity*(1.0-decay)/friction
	set_position(requested);velocity*=decay
	if requested<0 or requested>limit():velocity=0
