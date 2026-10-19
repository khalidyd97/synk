extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false
    var id="history_test_"+str(Time.get_ticks_usec())
    var song={"id":id,"title":"History Test","file":id+".ogg","bpm":120.0}
    g.library.songs.append(song); g.song=song
    var f=g.features
    for level in ["original","hard"]:
        f.current_variant=level
        for count in [1,2,3]:
            var notes: Array=[]
            for i in count: notes.append(SynkChart.note(1.0+i,i))
            check(f.save_chart(notes)==OK,"Save %s with %d notes" % [level,count])
        f.save_chart([SynkChart.note(1.0,0),SynkChart.note(2.0,1),SynkChart.note(3.0,2)])
    var hard=SynkChartVersions.list(id,"hard")
    check(hard.size()==3 and hard[0].number==3 and hard[2].number==1,"Every save is a numbered version; identical saves are skipped")
    check(SynkChartVersions.list(id,"original").size()==3,"Each level keeps its own history")
    check(SynkChartVersions.current_number(id,"hard")==3,"Newest save is the live version")
    var draft={"version":SynkChart.FORMAT_VERSION,"song_id":id,"chart_name":"hard","notes":[SynkChart.note(5,5)]}
    SynkLibrary.atomic_write(SynkChartVersions.draft_file(id,"hard"),draft)
    check(SynkChartVersions.switch_to(id,"hard",hard[2].path)==OK,"Switch to v1")
    var live=SynkChartVersions.read(SynkChartVersions.chart_file(id,"hard"))
    check(SynkChart.notes_from_file(live).size()==1 and SynkChartVersions.current_number(id,"hard")==1,"v1 is now the live chart")
    var after=SynkChartVersions.list(id,"hard")
    check(after.size()==4 and after[0].note.contains("draft") and not FileAccess.file_exists(SynkChartVersions.draft_file(id,"hard")),"Unsaved draft is kept as a version before switching")
    check(SynkChartVersions.switch_to(id,"hard",after[1].path)==OK and SynkChartVersions.current_number(id,"hard")==3,"Switching back restores v3")
    g.set_mode("library"); g.open_chart_history(id,"hard"); await process_frame
    var view=g.ui.get_child(g.ui.get_child_count()-1)
    check(view.list.get_child_count()==SynkChartVersions.list(id,"hard").size(),"History screen lists every version")
    view.close_view()
    g.library.delete_song(id)
    check(SynkChartVersions.list(id,"hard").is_empty(),"Deleting the song removes its history")
    g.queue_free(); await process_frame
    print("Chart versions: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
