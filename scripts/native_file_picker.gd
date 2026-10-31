class_name NativeFilePicker
# On iOS, Godot's FileDialog cannot reach the Files app; the synk_ios_picker GDExtension (built
# only into iOS exports) opens the system picker instead. Elsewhere open() returns false and the
# caller shows its normal native FileDialog.
static var picker: Object

static func available() -> bool:
	return OS.get_name()=="iOS" and ClassDB.class_exists("IOSFilePicker")

# Calls on_picked with a PackedStringArray of local copies of the chosen files.
static func open(multiple: bool, on_picked: Callable) -> bool:
	return start("open",[multiple],on_picked)

# Images: asks Photo Library or Files first. Photos arrive as JPEG copies (HEIC is converted).
static func open_image(on_picked: Callable) -> bool:
	return start("open_image",[],on_picked)

static func start(method: String, arguments: Array, on_picked: Callable) -> bool:
	if not available(): return false
	if picker==null: picker=ClassDB.instantiate("IOSFilePicker")
	for connection in picker.get_signal_connection_list("picked"): picker.disconnect("picked",connection.callable)
	picker.connect("picked",on_picked,CONNECT_ONE_SHOT)
	picker.callv(method,arguments)
	return true
