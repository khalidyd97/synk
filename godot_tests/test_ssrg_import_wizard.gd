extends SceneTree
const F=preload("res://godot_tests/ssrg_import_fixtures.gd")
const TX=preload("res://scripts/ssrg_import_transaction.gd")
var failures=0
var game
var wizard
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func freeze(node:Node):
	node.set_process(false)
	for child in node.get_children():freeze(child)
func pump(until:Callable) -> bool:
	var deadline=Time.get_ticks_msec()+12000
	while Time.get_ticks_msec()<deadline:
		wizard._process(.016);await process_frame
		if until.call():
			wizard._process(.016);await process_frame;return true
	check(false,"Import worker completed within the test deadline");return false
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1440,640)
	var folder=F.folder("ssrg-import-wizard");var input=folder.path_join("input");var source=F.source(input)
	F.write(input.path_join("artist_song_7.seq"),F.raw([[64,0,0,0],[160,2,0,0]]))
	F.write(input.path_join("artist_song_13.seq"),F.raw([[64,0,0,99]]))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;freeze(game)
	for child in game.get_children():
		if child is CanvasLayer:child.hide()
	game.library=SynkLibrary.new(folder.path_join("library"))
	var host=game.ssrg_playables;host.visible=true;game.ui.show()
	wizard=host.import_wizard;wizard.open();wizard.add_sources(PackedStringArray([input]))
	if not await pump(func():return wizard.job.phase()=="review" and wizard.job.task<0):game.queue_free();quit(1);return
	check(wizard.job.plan.size()==1 and wizard.job.plan[0].ready,"Folder scan groups all difficulties into one reviewable song")
	if wizard.job.plan.is_empty():game.queue_free();quit(1);return
	var item:Dictionary=wizard.job.plan[0]
	check(item.valid_keys==[4,7] or item.valid_keys==[7,4],"Review lists both correct key counts")
	check(str(item.audio)==source.audio and item.audio_hash.length()==64,"Audio is matched and content-hashed before import")
	check(game.library.songs.is_empty(),"Scan/review creates no library entries")
	check(wizard.import_button.disabled and wizard.warning_ack.visible,"Excluded invalid difficulties require explicit warning acknowledgment")
	check(wizard.picker.access==FileDialog.ACCESS_FILESYSTEM and wizard.picker.use_native_dialog,"SSRG Files picker uses native providers rather than forcing app-folder copying")
	wizard.job.plan[0].title="Reviewed title";wizard.job.plan[0].title_edited=true
	wizard.job.plan[0].selected_keys=[4];wizard.warning_ack.button_pressed=true;wizard.update_controls()
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/ssrg-import-review-1440.png")
	wizard.start_import();wizard.hide()
	if not await pump(func():return wizard.job.phase()=="done" and not wizard.job.busy()):game.queue_free();quit(1);return
	check(game.library.songs.size()==1 and game.library.songs[0].title=="Reviewed title","Background import keeps the edited title and completes while wizard is closed")
	var id=str(game.library.songs[0].id)
	check(FileAccess.file_exists(game.library.root_path.path_join("charts/"+id+"_lv4.json")) and not FileAccess.file_exists(game.library.root_path.path_join("charts/"+id+"_lv7.json")),"Only explicitly selected difficulties are saved")
	check(wizard.job.reports.size()==1 and wizard.job.reports[0].outcome=="imported","Completion report records imported song")
	wizard.show();wizard.save_report(folder.path_join("summary.json"))
	check(TX.read_json(folder.path_join("summary.json"),{}).results[0].outcome=="imported","Summary exports to a reusable JSON report")
	wizard.job.scan(PackedStringArray([input]),game.library.songs)
	await pump(func():return wizard.job.phase()=="review" and wizard.job.task<0)
	wizard.job.plan[0].selected_keys=[4,7];wizard.job.plan[0].include=true;wizard.warning_ack.button_pressed=true;wizard.update_controls()
	var original_audio=FileAccess.get_file_as_bytes(source.audio)
	var changed_audio=original_audio.duplicate();changed_audio[-1]=1;F.write(source.audio,changed_audio)
	wizard.start_import()
	await pump(func():return wizard.job.phase()=="done" and not wizard.job.busy())
	check(wizard.job.reports[0].outcome=="failed" and wizard.retry_button.visible,"Source change after review produces a retryable failure")
	check(not FileAccess.file_exists(game.library.root_path.path_join("charts/"+id+"_lv7.json")),"Failed batch does not publish a partial difficulty")
	F.write(source.audio,original_audio);wizard.job.retry_failed();wizard._process(.016)
	wizard.warning_ack.button_pressed=true;wizard.update_controls();wizard.start_import()
	await pump(func():return wizard.job.phase()=="done" and not wizard.job.busy())
	check(game.library.songs.size()==1 and wizard.job.reports[0].outcome=="updated","Duplicate import adds missing difficulty without duplicating audio/song")
	var saved4=FileAccess.get_sha256(game.library.root_path.path_join("charts/"+id+"_lv4.json"))
	check(FileAccess.file_exists(game.library.root_path.path_join("charts/"+id+"_lv7.json")),"Missing difficulty was added")
	check(game.library.songs[0].title=="Reviewed title","Rescan retains previously edited library metadata by default")
	var misleading=input.path_join("short.wav");var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=8000;var samples=PackedByteArray();samples.resize(4000);wav.data=samples;wav.save_to_wav(misleading)
	wizard.job.recheck(0,{"audio":misleading,"audio_manual":true},game.library.songs)
	await pump(func():return wizard.job.phase()=="review" and wizard.job.task<0)
	check(not wizard.job.plan[0].ready and not wizard.job.plan[0].warnings.is_empty(),"Mismatched short audio is visible in review rather than trimming notes")
	wizard.job.recheck(0,{"audio":source.audio,"audio_manual":true},game.library.songs)
	await pump(func():return wizard.job.phase()=="review" and wizard.job.task<0)
	check(wizard.job.plan[0].ready,"Choosing correct audio repairs the review without rebuilding the source files")
	check(FileAccess.get_sha256(game.library.root_path.path_join("charts/"+id+"_lv4.json"))==saved4,"Review corrections never rewrite existing charts")
	F.source(input,13);wizard.job.scan(PackedStringArray([input]),game.library.songs)
	await pump(func():return wizard.job.phase()=="review" and wizard.job.task<0)
	wizard.job.plan[0].selected_keys=[13];wizard.job.plan[0].include=true;wizard.warning_ack.button_pressed=true;wizard.update_controls();wizard.start_import();wizard.job.advance(game.library.songs)
	var deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		wizard.job.poll();await process_frame
		if wizard.job.task<0 and wizard.job.phase()=="prepared":break
	wizard.job.cancel()
	await pump(func():return wizard.job.phase()=="done" and not wizard.job.busy())
	check(wizard.job.reports[0].outcome=="canceled" and not FileAccess.file_exists(game.library.root_path.path_join("charts/"+id+"_lv13.json")),"Cancellation before commit keeps the live library unchanged")
	check(not DirAccess.get_files_at(game.library.root_path.path_join("import_reports")).is_empty(),"Completed and failed batches leave persistent import summaries")
	# Worker ZIP scan uses the same grouping and validation path as folder import.
	var zip_path=folder.path_join("song.zip");var pack=ZIPPacker.new();pack.open(zip_path)
	for pair in [["GAME/seq/artist_song_4.seq",source.chart],["GAME/music/artist_song.wav",source.audio]]:
		pack.start_file(pair[0]);pack.write_file(FileAccess.get_file_as_bytes(pair[1]));pack.close_file()
	pack.close();wizard.job.scan(PackedStringArray([zip_path]),game.library.songs)
	await pump(func():return wizard.job.phase()=="review" and wizard.job.task<0)
	check(wizard.job.plan.size()==1 and wizard.job.plan[0].ready,"ZIP can be reviewed directly without manual file copying")
	for dimensions in [Vector2i(2400,1080),Vector2i(1024,768)]:
		root.size=dimensions
		for frame in 3:await process_frame
		wizard.show();await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/ssrg-import-review-%d.png" % dimensions.x)
	game.queue_free();await process_frame
	print("SSRG import wizard failures: ",failures);quit(failures)
