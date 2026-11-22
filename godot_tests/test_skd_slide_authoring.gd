extends SceneTree
var failures=0
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.recorder_skd_view=true;game.mode="record";game.arranging=true
	var note=SynkChart.note(1.0,2,"slide");note.duration=1.0;note.end_lane=8;note.ssrg_path=true
	note.path=[{"offset":0.0,"lane":2.0},{"offset":.5,"lane":5.4,"curve":true},{"offset":1.0,"lane":8.0}]
	note.checkpoints=[.5]
	game.arrange_selection={"note":note,"document":false}
	var arranger=game.note_arranger;arranger.expanded=true;arranger._process(0)
	check(not arranger.curve_button.visible and not arranger.preset_buttons.wave.visible,"SKD view hides curved and wave authoring")
	check(arranger.shape_buttons.straighten.visible and not arranger.shape_buttons.smooth.visible,"SKD view keeps straight node-chain cleanup only")
	var wanted:Array=game.correct_bar.wanted()
	check(wanted.has("shape") and wanted.has("points") and not wanted.has("draw") and not wanted.has("letter"),"SKD toolbar exposes node and connector editing without freehand silhouettes")
	check(game.snap_slide_lane(4.37)==4.0,"SKD authoring always snaps to a whole channel")
	var step=60.0/game.chart_bpm()/float(game.recorder.division)
	var snapped=game.snap_slide_time(game.chart_offset()+step*2.37)
	check(is_equal_approx(snapped,game.chart_offset()+step*2.0),"SKD connector time snaps to the visible chart grid")
	var edited=arranger.edit(note,"point",.07,.42,1,5.0);arranger.snap_point(edited,1)
	check(float(edited.path[1].lane)==6.0 and not edited.path[1].has("curve"),"Dragging a connector produces one straight whole-channel node")
	var path=[{"offset":0.0,"lane":2.0,"curve":true},{"offset":step,"lane":4.4,"curve":true},{"offset":step*2.0,"lane":7.6,"curve":true},{"offset":1.0,"lane":8.0,"curve":true}]
	arranger.write_path(note,path)
	check(note.get("ssrg_path",false) and note.path.all(func(p):return not p.has("curve") and is_equal_approx(float(p.lane),roundf(float(p.lane)))),"Saved SKD slide is an ordered straight-segment channel chain")
	check(note.get("checkpoints",[]).size()==note.path.size()-2,"Every inner SKD node is a playable connector")
	game.queue_free();await process_frame
	print("SKD node-chain slide authoring failures: ",failures);quit(failures)
