class_name NativeFilePicker
# On iOS, Godot's FileDialog cannot reach the Files app; the synk_ios_picker GDExtension (built
# only into iOS exports) opens the system picker instead. Elsewhere open() returns false and the
# caller shows its normal native FileDialog.
static var picker: Object
const EXTENSION = "res://addons/synk_ios_picker/synk_ios_picker.gdextension"
# On iOS, a picker that failed to load is loaded again once, and the reason is shown once.
static var load_tried = false
static var problem_shown = false

static func available() -> bool:
	if OS.get_name()!="iOS": return false
	if ClassDB.class_exists("IOSFilePicker"): return true
	if not load_tried:
		load_tried=true
		GDExtensionManager.load_extension(EXTENSION)
	return ClassDB.class_exists("IOSFilePicker")

# Calls on_picked with a PackedStringArray of local copies of the chosen files.
static func open(multiple: bool, on_picked: Callable) -> bool:
	return start("open",[multiple],on_picked)

# Images: asks Photo Library or Files first. Photos arrive as JPEG copies (HEIC is converted).
static func open_image(on_picked: Callable) -> bool:
	return start("open_image",[],on_picked)

static func start(method: String, arguments: Array, on_picked: Callable) -> bool:
	if not available():
		if OS.get_name()=="iOS": show_problem()
		return false
	if picker==null: picker=ClassDB.instantiate("IOSFilePicker")
	for connection in picker.get_signal_connection_list("picked"): picker.disconnect("picked",connection.callable)
	picker.connect("picked",on_picked,CONNECT_ONE_SHOT)
	picker.callv(method,arguments)
	return true

# Why the picker is missing on this iPhone: what is installed, and the loader's own errors.
static func diagnosis() -> String:
	var lines=PackedStringArray()
	var frameworks=OS.get_executable_path().get_base_dir().path_join("Frameworks/synk_ios_picker.framework")
	lines.append("Picker framework in app: "+("yes" if DirAccess.dir_exists_absolute(frameworks) else "NO"))
	lines.append("Picker library file: "+("yes" if FileAccess.file_exists(frameworks.path_join("synk_ios_picker")) else "NO"))
	lines.append("Extension file in game: "+("yes" if FileAccess.file_exists(EXTENSION) else "NO"))
	lines.append("Loaded extensions: "+", ".join(GDExtensionManager.get_loaded_extensions()))
	var log_path="user://logs/godot.log"
	if FileAccess.file_exists(log_path):
		for line in FileAccess.get_file_as_string(log_path).split("\n"):
			var lower=line.to_lower()
			if "synk_ios_picker" in lower or "gdextension" in lower or "dynamic library" in lower:lines.append(line.strip_edges().left(300))
	return "\n".join(lines.slice(0,14))

static func show_problem() -> void:
	if problem_shown: return
	problem_shown=true
	var tree=Engine.get_main_loop() as SceneTree
	if tree==null: return
	var box=AcceptDialog.new();box.title="Files / Photos picker did not load"
	box.dialog_text="The iPhone file picker could not start, so the basic file box opens instead.\nPlease send a screenshot of this:\n\n"+diagnosis()
	box.dialog_autowrap=true;box.min_size=Vector2i(720,0)
	tree.root.add_child(box);box.popup_centered();box.confirmed.connect(box.queue_free);box.canceled.connect(box.queue_free)
