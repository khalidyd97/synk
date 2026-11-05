extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func gesture(allowed: Array, duration: float, end_position: Vector2) -> Dictionary:
	var capture := SynkCapture.new()
	var start := Vector2(.5, .765)
	check(capture.begin(1, 1.0, start, "auto", [], allowed), "Gesture starts")
	return capture.end(1, 1.0 + duration, end_position)

func _initialize() -> void:
	check(gesture(["tap", "hold", "slide"], .05, Vector2(.5, .765)).kind == "tap", "Quick stationary touch becomes tap")
	check(gesture(["tap", "hold", "slide"], .3, Vector2(.5, .765)).kind == "hold", "Sustained touch becomes hold")
	check(gesture(["tap", "hold", "slide"], .3, Vector2(.7, .765)).kind == "slide", "Lateral drag becomes slide")
	check(gesture(["tap", "hold", "slide", "flick"], .08, Vector2(.5, .68)).kind == "flick", "Quick upward swipe becomes flick")
	check(gesture(["hold", "slide"], .05, Vector2(.5, .765)).is_empty(), "Excluded tap is not captured")
	check(gesture(["tap", "hold"], .3, Vector2(.7, .765)).kind == "hold", "Excluded slide is not captured")
	print("Recorder type selection failures: ", failures)
	quit(1 if failures else 0)
