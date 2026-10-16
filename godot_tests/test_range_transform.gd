extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func run():
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.set_mode("editor")
    var slide=SynkChart.note(2,1,"slide"); slide.duration=1; slide.end_lane=4
    slide.path=[{"offset":0.0,"lane":1.0},{"offset":1.0,"lane":4.0}]
    var flick=SynkChart.note(3.5,2,"flick"); flick.direction=3
    g.document.load_notes([slide,flick,SynkChart.note(7,0)])
    g.timeline.range_active=true; g.timeline.range_start=2; g.timeline.range_end=4
    check(g.studio.transform_range("mirror"),"Mirror succeeds")
    check(g.document.notes[0].lane==8 and g.document.notes[0].path[1].lane==5 and g.document.notes[1].direction==1,"Mirror transforms slide and directional flick")
    check(g.document.notes[2].lane==0,"Unselected notes stay unchanged")
    g.document.undo(); g.timeline.update_range()
    check(g.document.notes[0].path==slide.path,"One undo restores original paths")
    var before=g.document.notes.duplicate(true); var history=g.document.undo_stack.size()
    check(not g.studio.transform_range("lane",-2) and g.document.notes==before and g.document.undo_stack.size()==history,"Invalid lane shift is atomic")
    check(not g.studio.transform_range("time",-3) and g.document.notes==before,"Negative timing rejected")
    check(g.studio.transform_range("time",1) and g.timeline.range_start==3,"Timing shift moves selection bounds")
    check(g.studio.transform_range("repeat",2) and g.document.notes.size()==7,"Repeat adds two independent passages")
    check(g.document.notes[3].time==5 and g.document.notes[5].time==7,"Repeats preserve relative timing")
    g.document.undo(); check(g.document.notes.size()==3,"One undo removes all repeats")
    g.queue_free(); await process_frame
    print("Range transformations: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
