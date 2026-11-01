extends SceneTree
# Launching must not focus a text field: on phones that opens the keyboard (the import
# wizard's hidden SAVE REPORT dialog used to focus its file name at startup).
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	for i in 6: await process_frame
	var focus=root.gui_get_focus_owner()
	check(not (focus is LineEdit or focus is TextEdit),"No text field has focus after launch (focused: %s)" % str(focus))
	for node in root.find_children("FloatingTextEntry","",true,false):
		check(not node.is_visible_in_tree(),"Floating keyboard editor stays closed after launch")
	# A hidden FileDialog is its own window; a focused name field there still opens the keyboard.
	for dialog in root.find_children("","FileDialog",true,false):
		var inner=dialog.gui_get_focus_owner()
		check(not (inner is LineEdit),"Hidden file dialog %s has no focused text field" % dialog.get_path())
	game.ssrg_playables.import_wizard.report_button.pressed.emit()
	check(game.ssrg_playables.import_wizard.report_picker.current_file=="SYNK-import-report.json","SAVE REPORT still suggests the report file name")
	game.ssrg_playables.import_wizard.report_picker.hide()
	game.queue_free(); await process_frame
	if failures==0: print("Launch keyboard: PASS")
	quit(failures)
