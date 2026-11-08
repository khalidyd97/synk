extends SceneTree
# Sliding a held finger across buttons must not light them up (hover, grow or glow).
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else: failures += 1;push_error(message);print("FAIL: ", message)
func _initialize() -> void: run.call_deferred()
func touch(p: Vector2, down: bool) -> void:
	var e=InputEventScreenTouch.new(); e.index=0; e.pressed=down; e.position=p; Input.parse_input_event(e)
func run() -> void:
	var UiMotion=load("res://scripts/ui_motion.gd")
	var NeonAction=load("res://scripts/neon_action.gd")
	var a=NeonAction.new(); a.text="ONE"; root.add_child(a); a.position=Vector2(60,60); a.size=Vector2(200,80)
	var b=NeonAction.new(); b.text="TWO"; root.add_child(b); b.position=Vector2(400,60); b.size=Vector2(200,80)
	for i in 4: await process_frame
	# Finger held on ONE, then the pointer reaches TWO (what Godot reports as the finger slides).
	touch(Vector2(160,100),true); await process_frame
	check(not UiMotion.hover_allowed(), "Hover is off while a finger is held down")
	b.mouse_entered.emit()
	for i in 20: await process_frame
	check(is_equal_approx(b.scale.x,1.0), "A button a held finger slides onto does not grow")
	check(b.state("hover_amount")<.05, "A neon button a held finger slides onto does not glow")
	b.mouse_exited.emit()
	touch(Vector2(160,100),false)
	for i in 4: await process_frame
	check(UiMotion.hover_allowed(), "Hover works again once the finger lifts")
	b.mouse_entered.emit()
	for i in 20: await process_frame
	check(b.scale.x>1.01 and b.state("hover_amount")>.5, "A mouse with no button held still hovers")
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
