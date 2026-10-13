extends SceneTree

var failures=0
func check(condition: bool, message: String) -> void:
	if not condition: failures+=1; push_error(message)

func _initialize() -> void:
	var capture=SynkCapture.new()
	check(not capture.begin(1,-1,Vector2(.5,.765)),"Countdown cannot create notes")
	check(not capture.begin(1,1,Vector2(.5,.1)),"Toolbar cannot create notes")
	check(capture.begin(1,1,Vector2(.5,.765)),"Touch begins")
	var n=capture.end(1,1.08,Vector2(.5,.765))
	check(n.kind=="tap" and n.time==1 and n.lane==6,"Tap keeps onset and lane")
	capture.begin(1,2,Vector2(.5,.765)); n=capture.end(1,2.6,Vector2(.5,.765))
	check(n.kind=="hold" and is_equal_approx(n.duration,.6),"Hold classification")
	var directions=[Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]
	for i in 4:
		capture.begin(1,3,Vector2(.5,.765)); n=capture.end(1,3.1,Vector2(.5,.765)+directions[i]*.08)
		check(n.kind=="flick" and n.direction==i,"Flick direction "+str(i))
	capture.begin(1,4,Vector2(.5,.765)); capture.move(1,4.3,Vector2(.7,.765)); capture.move(1,4.6,Vector2(.3,.765)); n=capture.end(1,4.9,Vector2(.5,.765))
	check(n.kind=="slide" and SynkChart.lane_at(n,4.3)>8 and SynkChart.lane_at(n,4.6)<4,"Slide preserves turns")
	capture.begin(1,5,Vector2(.5,.765),"slide"); n=capture.end(1,5.1,Vector2(.7,.765)); check(n.kind=="slide","Explicit slide tool")
	var count=capture.notes.size(); capture.begin(1,6,Vector2(.5,.765)); n=capture.end(1,6.3,Vector2(.5,.765),true)
	check(n.is_empty() and capture.notes.size()==count,"Canceled touch discarded")
	capture.begin(1,7,Vector2(.3,.765)); capture.begin(2,7,Vector2(.7,.765))
	check(capture.gestures.size()==2,"Multitouch gestures independent"); capture.gestures.clear()
	var chart=SynkChart.new(); chart.add(2,6); chart.convert("flick",.5,10)
	check(chart.selection().kind=="flick" and chart.selection().duration==0,"Tap converts to flick")
	chart.convert("tap",.5,10); chart.undo(); check(chart.notes[0].kind=="flick","Undo conversion")
	chart.redo(); check(chart.notes[0].kind=="tap","Redo conversion")
	chart.selected=0; chart.convert("slide",.5,10); chart.selection().end_lane=9
	chart.selection().path=[{"offset":0.0,"lane":6.0},{"offset":.5,"lane":9.0}]
	chart.resize(1,10); check(chart.selection().path[1].offset==1,"Resize scales path")
	chart.checkpoint(); chart.move_note(20,20,10); check(chart.selection().time==9 and chart.selection().lane==12,"Dragging bounded to song")
	chart.undo(); check(chart.notes[0].path[1].lane==9 and chart.notes[0].time==2,"Deep path undo")
	check(is_equal_approx(SynkChart.snap(1.13,120,4),1.125),"Beat snapping")
	check(SynkChart.valid(chart.notes),"Valid chart accepted")
	var invalid=chart.notes.duplicate(true); invalid[0].lane=50; check(not SynkChart.valid(invalid),"Invalid lane rejected")
	var folder="user://tests_"+str(Time.get_ticks_usec())
	var library=SynkLibrary.new(folder)
	check(library.save_chart("test",chart.notes)==OK,"Chart saves")
	var reloaded=library.load_chart("test")
	check(reloaded.size()==1 and reloaded[0].path.size()==2 and is_equal_approx(float(reloaded[0].path[1].lane),9) and is_equal_approx(float(reloaded[0].time),2),"Chart reloads with paths")
	check(library.save_chart("test",[])==OK and library.load_chart("test").is_empty(),"Empty chart overwrites correctly")
	var stream=AudioStreamWAV.new(); stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate=8000
	var samples=PackedByteArray(); samples.resize(8000); stream.data=samples
	var path=folder.path_join("fixture.wav"); check(stream.save_to_wav(path)==OK,"Audio fixture created")
	var imported=library.import_song(path); check(not imported.is_empty(),"Runtime WAV import")
	if not imported.is_empty():
		check(FileAccess.file_exists(folder.path_join("songs/"+imported.song.file)),"Imported audio kept")
		var restored=SynkLibrary.new(folder); check(restored.songs.size()==1,"Song library survives restart")
		check(not library.import_song(path).is_empty() and library.songs.size()==1,"Audio imports deduplicate")
	# Test files are isolated from the player's songs and charts.
	for sub in ["songs","charts"]:
		for file in DirAccess.get_files_at(folder.path_join(sub)): DirAccess.remove_absolute(folder.path_join(sub).path_join(file))
		DirAccess.remove_absolute(folder.path_join(sub))
	DirAccess.remove_absolute(path); DirAccess.remove_absolute(folder)
	print("Core tests: ", "PASS" if failures==0 else str(failures)+" FAILED")
	quit(0 if failures==0 else 1)
