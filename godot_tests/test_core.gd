extends SceneTree

var failures=0
func check(condition: bool, message: String) -> void:
	if not condition: failures+=1; push_error(message)

func hue_gap(a: float, b: float) -> float: return SynkCoverPalette.hue_distance(a,b)

func _initialize() -> void:
	var red_cover=Image.create(32,32,false,Image.FORMAT_RGBA8); red_cover.fill(Color("d8203a"))
	var red_palette=SynkCoverPalette.from_image(red_cover)
	check(red_palette.from_cover and hue_gap(red_palette.notes[0].h,0.98)<.05,"Cover palette leads with the cover's dominant hue")
	for a in 3:
		for b in range(a+1,3): check(hue_gap(red_palette.notes[a].h,red_palette.notes[b].h)>.12,"Cover palette note colors stay distinct")
	var gray_cover=Image.create(32,32,false,Image.FORMAT_RGBA8); gray_cover.fill(Color(.5,.5,.5))
	check(not SynkCoverPalette.from_image(gray_cover).from_cover,"Colorless covers keep the house palette")
	var helper_script=load("res://scripts/sync_helper.gd")
	var click_loop: AudioStreamWAV=helper_script.metronome_stream()
	check(click_loop.loop_mode==AudioStreamWAV.LOOP_FORWARD and click_loop.loop_end==int(round(helper_script.beat_period()*4*click_loop.mix_rate)),"Sync helper metronome loops exactly four beats")
	check(click_loop.data.size()/2>click_loop.loop_end+256,"Metronome keeps padding after its loop point so mixing never reads past the buffer")
	var finish_script=load("res://scripts/finish_overlay.gd")
	check(finish_script.banner_for({"PERFECT":10,"GREAT":0,"GOOD":0,"MISS":0},false)=="ALL PERFECT" and finish_script.banner_for({"PERFECT":8,"GREAT":2,"GOOD":0,"MISS":0},false)=="FULL COMBO" and finish_script.banner_for({"PERFECT":8,"GREAT":0,"GOOD":0,"MISS":1},false)=="CLEAR" and finish_script.banner_for({},true)=="AUTO PLAY","Finish banner names the run")
	var capture=SynkCapture.new()
	check(not capture.begin(1,-1,Vector2(.5,.765)),"Countdown cannot create notes")
	check(not capture.begin(1,1,Vector2(.5,.1)),"Toolbar cannot create notes")
	check(capture.begin(1,1,Vector2(.5,.765)),"Touch begins")
	var n=capture.end(1,1.08,Vector2(.5,.765))
	check(n.kind=="tap" and n.time==1 and n.lane==roundi(SynkCapture.lane(.5)),"Tap keeps onset and lane")
	capture.begin(1,2,Vector2(.5,.765)); n=capture.end(1,2.6,Vector2(.5,.765))
	check(n.kind=="hold" and is_equal_approx(n.duration,.6),"Hold classification")
	var directions=[Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]
	for i in 4:
		capture.begin(1,3,Vector2(.5,.765)); n=capture.end(1,3.1,Vector2(.5,.765)+directions[i]*.08)
		check(n.kind=="tap","Quick recorder swipe stays a tap in direction "+str(i))
	for i in [0,1,3]:
		capture.begin(1,3.3,Vector2(.5,.765),"flick")
		n=capture.end(1,3.4,Vector2(.5,.765)+directions[i]*.08)
		check(n.kind=="flick" and n.direction==i,"Manual flick tool records direction "+str(i))
	capture.begin(1,3.5,Vector2(.5,.765),"flick")
	check(capture.end(1,3.6,Vector2(.5,.845)).is_empty(),"Manual downward flick remains disallowed")
	capture.begin(1,4,Vector2(.5,.765)); capture.move(1,4.3,Vector2(.7,.765)); capture.move(1,4.6,Vector2(.3,.765)); n=capture.end(1,4.9,Vector2(.5,.765))
	check(n.kind=="slide" and SynkChart.lane_at(n,4.3)>6 and SynkChart.lane_at(n,4.6)<3,"Slide preserves turns")
	capture.begin(1,5,Vector2(.5,.765),"slide"); n=capture.end(1,5.1,Vector2(.7,.765)); check(n.kind=="slide","Explicit slide tool")
	var all_on_lanes=is_equal_approx(float(n.path[0].lane),roundf(float(n.path[0].lane))) and is_equal_approx(float(n.path[-1].lane),roundf(float(n.path[-1].lane)))
	var offsets_rise=true
	for k in range(1,n.path.size()): if float(n.path[k].offset)<=float(n.path[k-1].offset): offsets_rise=false
	check(all_on_lanes and offsets_rise and SynkChart.valid([n]) and int(n.end_lane)==int(n.path[-1].lane),"Recorded slides start and end on whole lanes")
	var rested=[]
	for k in 31: rested.append({"offset":k*.02,"lane":2.0 if k<12 else (4.1 if k>18 else 2.0+(k-12)*.3)})
	var shaped=SynkCapture.snap_path(rested,.6)
	var held_on=func(lane_value: float, t: float) -> bool:
		var probe=SynkChart.note(0,2,"slide"); probe.duration=.6; probe.path=shaped
		return is_equal_approx(SynkChart.lane_at(probe,t),lane_value)
	check(held_on.call(2.0,.1) and held_on.call(4.0,.5) and shaped[0].lane==2.0 and shaped[-1].lane==4.0,"Lanes the finger rests on become locked runs, ends sit on lanes")
	var swept=shaped.filter(func(point): return float(point.offset)>.24 and float(point.offset)<.36)
	check(not swept.is_empty() and swept.any(func(point): return not is_equal_approx(float(point.lane),roundf(float(point.lane)))),"Lanes swept past quickly stay a smooth curve")
	var count=capture.notes.size(); capture.begin(1,6,Vector2(.5,.765)); n=capture.end(1,6.3,Vector2(.5,.765),true)
	check(n.is_empty() and capture.notes.size()==count,"Canceled touch discarded")
	capture.begin(1,7,Vector2(.3,.765)); capture.begin(2,7,Vector2(.7,.765))
	check(capture.gestures.size()==2,"Multitouch gestures independent"); capture.gestures.clear()
	var chord=SynkCapture.new()
	chord.begin(1,8.0,Vector2(.3,.765)); chord.begin(2,8.045,Vector2(.7,.765))
	var first=chord.end(1,8.08,Vector2(.3,.765))
	var second=chord.end(2,8.1,Vector2(.7,.765))
	check(first.lane!=second.lane and is_equal_approx(first.time,second.time),"Near-simultaneous double taps align as a chord")
	chord.begin(3,8.13,Vector2(.3,.765)); var repeat=chord.end(3,8.2,Vector2(.3,.765))
	check(repeat.time>first.time,"Repeated taps in one lane retain separate timing")
	var chart=SynkChart.new(); chart.add(2,6); chart.convert("flick",.5,10)
	var old_flick=SynkChart.note(1,4,"flick"); old_flick.direction=2
	var migrated=SynkChart.new(); migrated.load_notes([old_flick])
	check(migrated.notes[0].direction==0,"Existing downward flicks open as upward flicks")
	for demo_note in SynkChart.demo():
		check(demo_note.kind!="flick" or demo_note.direction!=2,"Demo has no downward flicks")
	check(chart.selection().kind=="flick" and chart.selection().duration==0,"Tap converts to flick")
	chart.convert("tap",.5,10); chart.undo(); check(chart.notes[0].kind=="flick","Undo conversion")
	chart.redo(); check(chart.notes[0].kind=="tap","Redo conversion")
	chart.selected=0; chart.convert("slide",.5,10); chart.selection().end_lane=9
	chart.selection().path=[{"offset":0.0,"lane":6.0},{"offset":.5,"lane":9.0}]
	chart.resize(1,10); check(chart.selection().path[1].offset==1,"Resize scales path")
	chart.checkpoint(); chart.move_note(20,20,10); check(chart.selection().time==9 and chart.selection().lane==SynkChart.MAX_LANE,"Dragging bounded to song")
	check(SynkChart.LANES==10 and is_equal_approx(SynkCapture.lane(.07+.86*.05),0.0) and is_equal_approx(SynkCapture.lane(.93-.86*.05),SynkChart.MAX_LANE),"The highway has 10 lanes edge to edge")
	var legacy_slide=SynkChart.note(1,0,"slide"); legacy_slide.lane=12; legacy_slide.end_lane=4; legacy_slide.duration=1.0; legacy_slide.path=[{"offset":0.0,"lane":12.0},{"offset":1.0,"lane":2.0}]
	var legacy=SynkChart.notes_from_file({"version":1,"song_id":"x","notes":[legacy_slide,SynkChart.note(2,6)]})
	check(legacy!=null and legacy[0].lane==9 and legacy[0].end_lane==3 and is_equal_approx(legacy[0].path[1].lane,1.5) and legacy[1].lane==roundi(6*.75),"Old 13-lane charts are spread across the 10 lanes")
	check(SynkChart.notes_from_file({"version":2,"notes":[legacy_slide]})==null,"New charts reject lanes past the last lane")
	chart.undo(); check(chart.notes[0].path[1].lane==9 and chart.notes[0].time==2,"Deep path undo")
	check(is_equal_approx(SynkChart.snap(1.13,120,4),1.125),"Beat snapping")
	check(SynkChart.valid(chart.notes),"Valid chart accepted")
	var invalid=chart.notes.duplicate(true); invalid[0].lane=50; check(not SynkChart.valid(invalid),"Invalid lane rejected")
	var dotted=SynkChart.note(1,6,"hold"); dotted.duration=1.0; dotted.checkpoints=[.25,.6]
	check(SynkChart.valid([dotted]),"Checkpoint dots inside a hold are accepted")
	var bad_dots=dotted.duplicate(true); bad_dots.checkpoints=[.6,.25]
	var tap_dots=SynkChart.note(1,6); tap_dots.checkpoints=[.1]
	var late_dots=dotted.duplicate(true); late_dots.checkpoints=[1.2]
	check(not SynkChart.valid([bad_dots]) and not SynkChart.valid([tap_dots]) and not SynkChart.valid([late_dots]),"Unordered, out-of-range or tap checkpoints are rejected")
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
		var unnamed=folder.path_join("selected_document")
		check(DirAccess.copy_absolute(path,unnamed)==OK,"Extensionless picker file created")
		check(not library.import_song(unnamed).is_empty() and library.songs.size()==1,"Audio import recognizes content without a filename extension")
		DirAccess.remove_absolute(unnamed)
		var song_id=str(imported.song.id)
		library.save_chart(song_id,chart.notes); library.delete_chart(song_id)
		check(not library.has_chart(song_id),"Deleting a chart removes its file")
		library.save_chart(song_id,chart.notes)
		check(library.delete_song(song_id)==OK and library.songs.is_empty() and not library.has_chart(song_id) and not FileAccess.file_exists(folder.path_join("songs/"+imported.song.file)) and SynkLibrary.new(folder).songs.is_empty(),"Deleting a song removes its audio, chart and library entry")
	# Test files are isolated from the player's songs and charts.
	for sub in ["songs","charts"]:
		for file in DirAccess.get_files_at(folder.path_join(sub)): DirAccess.remove_absolute(folder.path_join(sub).path_join(file))
		DirAccess.remove_absolute(folder.path_join(sub))
	DirAccess.remove_absolute(path); DirAccess.remove_absolute(folder)
	print("Core tests: ", "PASS" if failures==0 else str(failures)+" FAILED")
	quit(0 if failures==0 else 1)
