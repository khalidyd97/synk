extends Control
const JOB=preload("res://scripts/ssrg_import_job.gd")
const TX=preload("res://scripts/ssrg_import_transaction.gd")
var host:Control
var job=JOB.new()
var sources=PackedStringArray()
var revision=-1
var selected=-1
var list:VBoxContainer
var details:VBoxContainer
var status:Label
var summary:Label
var progress:ProgressBar
var warning_ack:CheckBox
var import_button:Button
var cancel_button:Button
var retry_button:Button
var report_button:Button
var files_button:Button
var folder_button:Button
var clear_button:Button
var blocker:ColorRect
var picker:FileDialog
var folder_picker:FileDialog
var report_picker:FileDialog
var pick_kind="sources"
var pick_chart=""
var refresh_pending=false
var last_phase="idle"
var public_items:Array=[]
var row_checks:Array[CheckBox]=[]
var recovery_blocked=false
var recovery_message=""

func label(value:String,parent:Node=null,font_size:int=17) -> Label:
	var node=Label.new();node.text=value;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size",font_size)
	(details if parent==null else parent).add_child(node);return node
func button(value:String,parent:Node,callback:Callable) -> Button:
	var node=Button.new();node.text=value;node.custom_minimum_size=Vector2(0,44)
	node.add_theme_font_size_override("font_size",16);parent.add_child(node);node.pressed.connect(callback);return node
func row(parent:Node) -> HBoxContainer:
	var node=HBoxContainer.new();node.add_theme_constant_override("separation",10);parent.add_child(node);return node
func clear_children(node:Node) -> void:
	for child in node.get_children():node.remove_child(child);child.queue_free()

func _ready() -> void:
	name="SSRGImportWizard";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_STOP
	var shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.88)
	var panel=PanelContainer.new();add_child(panel)
	panel.anchor_left=.025;panel.anchor_right=.975;panel.anchor_top=.025;panel.anchor_bottom=.975
	var style=StyleBoxFlat.new();style.bg_color=Color("11131e");style.set_corner_radius_all(18);style.content_margin_left=20;style.content_margin_right=20;style.content_margin_top=16;style.content_margin_bottom=16
	panel.add_theme_stylebox_override("panel",style)
	var content=VBoxContainer.new();panel.add_child(content);content.add_theme_constant_override("separation",10)
	var heading=row(content)
	var title=label("SSRG  /  SCAN · REVIEW · IMPORT",heading,22);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button("CLOSE",heading,func():hide())
	var tools=row(content)
	files_button=button("ADD FILES / ZIP",tools,choose_files)
	folder_button=button("CHOOSE FOLDER",tools,choose_folder)
	# The iOS Files picker returns files, not folders; ZIPs and multi-select cover whole songs there.
	folder_button.visible=OS.get_name()!="iOS"
	clear_button=button("CLEAR",tools,clear)
	summary=label("Choose a folder, ZIP, or song files.",content,16)
	progress=ProgressBar.new();progress.show_percentage=false;progress.custom_minimum_size.y=8;content.add_child(progress)
	var body=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",18);content.add_child(body)
	var left=VBoxContainer.new();left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;left.size_flags_stretch_ratio=.8;body.add_child(left)
	var select_row=row(left);button("SELECT VALID",select_row,func():select_all(true));button("NONE",select_row,func():select_all(false))
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;left.add_child(scroll)
	list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",8);scroll.add_child(list)
	var right=ScrollContainer.new();right.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.size_flags_stretch_ratio=1.25;body.add_child(right)
	details=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.add_theme_constant_override("separation",9);right.add_child(details)
	blocker=ColorRect.new();body.add_child(blocker);blocker.top_level=true;blocker.color=Color(0,0,0,.35);blocker.hide()
	body.resized.connect(func():blocker.position=body.global_position;blocker.size=body.size)
	warning_ack=CheckBox.new();warning_ack.text="I reviewed the warnings for the selected songs.";content.add_child(warning_ack);warning_ack.toggled.connect(func(_value):update_controls())
	status=label("Original charts and drafts stay protected.",content,15);status.custom_minimum_size.y=26
	var footer=row(content)
	import_button=button("IMPORT SELECTED",footer,start_import);import_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cancel_button=button("CANCEL",footer,func():job.cancel();status.text="Canceling after the current safe step…")
	retry_button=button("RETRY FAILED",footer,func():job.retry_failed())
	report_button=button("SAVE REPORT",footer,func():report_picker.popup_centered_ratio(.8))
	picker=FileDialog.new();add_child(picker);picker.file_mode=FileDialog.FILE_MODE_OPEN_FILES;picker.access=FileDialog.ACCESS_FILESYSTEM;picker.use_native_dialog=true
	picker.filters=PackedStringArray(["*.zip,*.seq,*.bytes,*.ogg,*.mp3,*.wav,*.png,*.jpg,*.jpeg,*.webp;SSRG song files"])
	picker.files_selected.connect(picked);picker.file_selected.connect(func(path):picked(PackedStringArray([path])))
	folder_picker=FileDialog.new();add_child(folder_picker);folder_picker.file_mode=FileDialog.FILE_MODE_OPEN_DIR;folder_picker.access=FileDialog.ACCESS_FILESYSTEM;folder_picker.use_native_dialog=true;folder_picker.dir_selected.connect(func(path):add_sources(PackedStringArray([path])))
	report_picker=FileDialog.new();add_child(report_picker);report_picker.file_mode=FileDialog.FILE_MODE_SAVE_FILE;report_picker.access=FileDialog.ACCESS_FILESYSTEM;report_picker.use_native_dialog=true;report_picker.current_file="SYNK-import-report.json"
	report_picker.file_selected.connect(save_report)
	visible=false;show_details();update_controls()

func open() -> void:
	job.root=host.game.library.root_path
	if not job.busy():
		var recovered=TX.recover(job.root)
		recovery_blocked=recovered.any(func(message):return str(message).begins_with("Recovery needs attention"))
		recovery_message=" ".join(recovered) if recovery_blocked else ""
		if not recovered.is_empty():
			var restored=TX.read_json(job.root.path_join("songs/library.json"),[])
			if restored is Array:host.game.library.songs=restored
			status.text=" ".join(recovered)
	show();update_controls()

func choose_files() -> void:
	if job.busy():return
	pick_kind="sources"
	if NativeFilePicker.open(true,picked):return
	picker.file_mode=FileDialog.FILE_MODE_OPEN_FILES;picker.popup_centered_ratio(.85)
func choose_folder() -> void:
	if not job.busy():folder_picker.popup_centered_ratio(.85)
func add_sources(paths:PackedStringArray) -> void:
	if job.busy():return
	for path in paths:
		if path not in sources:sources.append(path)
	job.root=host.game.library.root_path;warning_ack.button_pressed=false
	job.scan(sources,host.game.library.songs);show()
func clear() -> void:
	if job.busy():return
	job.clear_cache();job.plan.clear();job.reports.clear();public_items.clear();sources.clear();selected=-1
	job.publish("idle","Choose a folder, ZIP, or song files.");render_list();show_details()

func choose_match(kind:String,path:String="") -> void:
	if job.busy() or selected<0:return
	pick_kind=kind;pick_chart=path
	if kind in ["art","cover"] and NativeFilePicker.open_image(picked):return
	if kind not in ["art","cover"] and NativeFilePicker.open(false,picked):return
	picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE;picker.popup_centered_ratio(.85)
func picked(paths:PackedStringArray) -> void:
	if paths.is_empty() or job.busy():return
	if pick_kind=="sources":add_sources(paths);return
	if selected<0 or selected>=job.plan.size():return
	if pick_kind=="cover":
		# Album art needs no recheck; it is saved once the song is imported.
		job.plan[selected].cover=paths[0];public_items[selected].cover=paths[0];show_details();return
	var changes={}
	match pick_kind:
		"audio":changes={"audio":paths[0],"audio_manual":true}
		"art":changes={"background":paths[0],"background_manual":true}
		"chart":
			var chart_files=job.plan[selected].chart_files.duplicate()
			var i=chart_files.find(pick_chart)
			if i<0:return
			chart_files[i]=paths[0];changes={"chart_files":chart_files}
	job.recheck(selected,changes,host.game.library.songs)

func render_list() -> void:
	clear_children(list);row_checks.clear()
	for i in public_items.size():
		var item:Dictionary=public_items[i];var line=row(list)
		var include=CheckBox.new();include.button_pressed=bool(item.get("include",true)) and bool(item.get("ready",false));include.disabled=not bool(item.get("ready",false));line.add_child(include)
		row_checks.append(include)
		include.toggled.connect(func(value):
			if not job.busy():job.plan[i].include=value;job.plan[i].include_edited=true;warning_ack.button_pressed=false;update_controls())
		var description=str(item.get("title",item.get("song_id","Song")))
		description+="\n"+("Needs attention" if not item.get("ready",false) else ("Existing song" if item.get("existing",false) else "New song"))
		if item.get("warnings",[]).size()>0:description+=" · %d review warnings" % item.warnings.size()
		var select=button(description,line,func():selected=i;show_details());select.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		select.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;select.alignment=HORIZONTAL_ALIGNMENT_LEFT;select.custom_minimum_size.y=64
	if selected<0 and not public_items.is_empty():selected=0

func show_details() -> void:
	clear_children(details)
	if selected<0 or selected>=public_items.size():
		label("Review before saving",details,24)
		label("Choose a folder, a ZIP, or chart/audio files. You can correct matches and key counts, then select which difficulties to import.")
		label("Updates add missing difficulties by default. Replace imported only replaces charts that still match their import baseline and have no draft.")
		return
	var item:Dictionary=public_items[selected];var index=selected
	label(str(item.title),details,24)
	var fields=row(details)
	for field in ["title","artist","game"]:
		var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;fields.add_child(column)
		label(str(field).capitalize(),column,14)
		var edit=LineEdit.new();edit.text=str(item.get(field,""));edit.custom_minimum_size.y=42;column.add_child(edit)
		edit.text_changed.connect(func(value):
			if not job.busy():job.plan[index][field]=value;job.plan[index][field+"_edited"]=true)
	var audio_row=row(details);label("Audio: "+str(item.get("audio","")).get_file(),audio_row,15);button("CHOOSE AUDIO",audio_row,func():choose_match("audio"))
	if item.get("audio_matches",[]).size()>1:
		var matches=OptionButton.new();matches.custom_minimum_size.y=40;matches.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		matches.add_item("Suggested audio matches…")
		for value in item.audio_matches:matches.add_item(str(value.path).get_file())
		details.add_child(matches);matches.item_selected.connect(func(i):
			if i>0 and not job.busy():job.recheck(index,{"audio":item.audio_matches[i-1].path,"audio_manual":true},host.game.library.songs))
	if float(item.get("duration",0))>0:label("Audio length: %.2f seconds" % float(item.duration),details,14)
	var art_row=row(details);button("CHOOSE ARTWORK",art_row,func():choose_match("art"));button("NO ARTWORK",art_row,func():job.recheck(index,{"background":"","background_manual":true},host.game.library.songs))
	if not str(item.get("background","")).is_empty():
		var image=Image.load_from_file(ProjectSettings.globalize_path(str(item.background)))
		if image:
			var art=TextureRect.new();art.texture=ImageTexture.create_from_image(image);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.custom_minimum_size.y=110;details.add_child(art)
	var cover_row=row(details);button("CHOOSE COVER",cover_row,func():choose_match("cover"))
	var cover_path=str(item.get("cover",""))
	if not cover_path.is_empty():
		button("NO COVER",cover_row,func():
			if not job.busy():job.plan[index].erase("cover");public_items[index].erase("cover");show_details())
		var cover_image=Image.load_from_file(ProjectSettings.globalize_path(cover_path))
		if cover_image:
			var cover=TextureRect.new();cover.texture=ImageTexture.create_from_image(cover_image);cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;cover.custom_minimum_size.y=110;details.add_child(cover)
	label("Difficulties",details,19)
	for chart in item.get("chart_reports",[]):
		var line=row(details);var checked=CheckBox.new();checked.text="%d keys · %d notes · %.2f BPM" % [int(chart.keys),int(chart.notes),float(chart.bpm)];checked.button_pressed=int(chart.keys) in item.get("selected_keys",[]);checked.disabled=not chart.errors.is_empty();line.add_child(checked)
		checked.toggled.connect(func(value):
			if job.busy():return
			var keys:int=int(chart.keys)
			if value and keys not in job.plan[index].selected_keys:job.plan[index].selected_keys.append(keys)
			elif not value:job.plan[index].selected_keys.erase(keys)
			job.plan[index].ready=job.plan[index].errors.is_empty() and not job.plan[index].selected_keys.is_empty();update_controls())
		var key_choice=OptionButton.new();line.add_child(key_choice)
		for key in [4,7,13]:key_choice.add_item(str(key)+" keys",key)
		key_choice.select([4,7,13].find(int(chart.keys)))
		key_choice.item_selected.connect(func(i):
			if not job.busy():
				var overrides=item.get("key_overrides",{}).duplicate();overrides[str(chart.path)]=[4,7,13][i]
				job.recheck(index,{"key_overrides":overrides},host.game.library.songs))
		button("FILE…",line,func():choose_match("chart",str(chart.path)))
		label(str(chart.path).get_file(),details,13)
		for error in chart.errors:label("Cannot import: "+str(error),details,14).modulate=Color("ff9c9c")
	label("Existing song policy",details,14)
	var policy_row=row(details)
	var policy=OptionButton.new();policy.custom_minimum_size.y=44;policy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;policy_row.add_child(policy)
	for caption in ["Add missing difficulties", "Replace unchanged imported charts", "Skip this song"]:policy.add_item(caption)
	policy.select(["add_missing","replace_imported","skip"].find(str(item.get("policy","add_missing"))))
	policy.item_selected.connect(func(i):
		if not job.busy():job.plan[index].policy=["add_missing","replace_imported","skip"][i])
	button("APPLY TO SELECTED",policy_row,func():
		if not job.busy():
			for value in job.plan:
				if value.get("include",true) and value.get("ready",false):value.policy=job.plan[index].policy
			status.text="Policy applied to selected songs. Edited charts and drafts remain protected.")
	for chart in item.get("existing_charts",[]):label("Saved %d keys: %s" % [int(chart.keys),"unchanged import; replaceable" if chart.replaceable else "protected (edited, draft, or no baseline)"],details,14)
	for error in item.get("errors",[]):label("Needs attention: "+str(error),details,15).modulate=Color("ff9c9c")
	for warning in item.get("warnings",[]):label("Review: "+str(warning),details,14).modulate=Color("ffd36a")

func select_all(value:bool) -> void:
	if job.busy():return
	warning_ack.button_pressed=false
	for item in job.plan:item.include=value and item.ready;item.include_edited=true
	public_items=job.plan.duplicate(false);render_list();update_controls()
func update_controls() -> void:
	if import_button==null:return
	var busy=job.busy();var count=0;var warnings=job.scan_messages.size()
	if not busy:
		for i in job.plan.size():
			var item:Dictionary=job.plan[i]
			if item.get("include",true) and item.get("ready",false):count+=1;warnings+=item.get("warnings",[]).size()
			if i<row_checks.size():
				row_checks[i].disabled=not item.get("ready",false);row_checks[i].set_pressed_no_signal(item.get("include",true) and item.get("ready",false))
	files_button.disabled=busy;folder_button.disabled=busy;clear_button.disabled=busy
	import_button.disabled=recovery_blocked or busy or count==0 or (warnings>0 and not warning_ack.button_pressed)
	import_button.text="IMPORT %d SELECTED" % count
	warning_ack.visible=warnings>0 and not busy
	cancel_button.visible=busy
	retry_button.visible=not busy and job.reports.any(func(report):return report.outcome in ["failed","canceled"])
	report_button.visible=not busy and (not job.reports.is_empty() or not job.scan_messages.is_empty())
	blocker.visible=busy;blocker.position=blocker.get_parent().global_position;blocker.size=blocker.get_parent().size
	if recovery_blocked:status.text=recovery_message

func start_import() -> void:
	update_controls()
	if import_button.disabled:return
	job.begin_import();refresh_pending=true;warning_ack.button_pressed=false;update_controls()
func save_report(path:String) -> void:
	var result={"version":1,"timestamp":Time.get_datetime_string_from_system(),"results":job.reports,"scan_messages":job.scan_messages}
	status.text="Report saved." if TX.json_file(path,result)==OK else "Could not save report. Choose a writable folder."

func _process(_delta:float) -> void:
	var changed=job.poll(revision)
	if not changed.is_empty():
		revision=int(changed.revision);last_phase=str(changed.phase);status.text=str(changed.message)
		var total=int(changed.get("total",0));var done=int(changed.get("done",0));progress.value=100.0*done/total if total>0 else 0
		if last_phase in ["review","done","idle"] and job.task<0:
			public_items=changed.get("items",[]);render_list();show_details()
			if last_phase=="review":warning_ack.button_pressed=false
			if not changed.get("scan_messages",[]).is_empty():status.text+="\n"+" ".join(changed.scan_messages)
		if last_phase=="done":
			var counts={"imported":0,"updated":0,"skipped":0,"failed":0,"canceled":0}
			for report in job.reports:counts[report.outcome]=int(counts.get(report.outcome,0))+1
			summary.text="%d imported · %d updated · %d skipped · %d failed · %d canceled" % [counts.imported,counts.updated,counts.skipped,counts.failed,counts.canceled]
			for report in job.reports:
				label("%s — %s %s" % [str(report.title),str(report.outcome),str(report.message)],details,15)
				if not report.get("keys",[]).is_empty():label("Saved key counts: "+str(report.keys),details,14)
				for warning in report.get("warnings",[]):label(str(warning),details,14).modulate=Color("ffd36a")
		elif last_phase=="review":
			var ready_count=public_items.filter(func(item):return item.get("ready",false)).size()
			summary.text="%d found · %d ready · %d need attention. Review matches before importing." % [public_items.size(),ready_count,public_items.size()-ready_count]
		else:summary.text=str(changed.message)
		update_controls()
	if job.task<0 and job.phase()=="prepared":
		var result=job.commit_prepared(host.game.library.songs)
		if result.has("songs"):
			host.game.library.songs=result.songs;host.chart_cache.erase(str(result.id));host.game.song_metadata.erase(str(result.id));host.game.song_background_textures.erase(str(result.id))
			save_chosen_cover(str(result.id),str(job.plan[job.current].get("cover","")))
	if job.importing:job.advance(host.game.library.songs)
	elif refresh_pending and job.phase()=="done":
		refresh_pending=false;host.game.refresh_library()
		var report_path=host.game.library.root_path.path_join("import_reports/import-%d-%d.json" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()])
		if TX.json_file(report_path,{"version":1,"timestamp":Time.get_datetime_string_from_system(),"results":job.reports,"scan_messages":job.scan_messages})!=OK:status.text+=" Report could not be saved automatically; use SAVE REPORT."
		if host.game.lobby:host.game.lobby.refresh()
		host.refresh_songs();host.status_label.text=status.text
func _exit_tree() -> void:job.shutdown()

# A cover picked during review becomes the song's album art once it has been imported.
func save_chosen_cover(id:String,path:String) -> void:
	if path.is_empty() or id.is_empty():return
	var image:Variant=host.game.load_picked_image(path)
	if image is Image:
		var problem=host.game.save_cover_image(id,image)
		if not problem.is_empty():status.text=problem
	else:status.text=str(image)
