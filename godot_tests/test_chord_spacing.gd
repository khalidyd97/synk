extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func point(lane: float) -> Vector2: return Vector2(.07+.86*(lane+.5)/SynkChart.LANES,.765)
func separated(notes: Array,gap: float=2.4) -> bool:
    for i in notes.size():
        for j in range(i+1,notes.size()):
            if SynkNoteSpacing.conflict(notes[i],notes[j],gap): return false
    return true
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var capture=SynkCapture.new()
    capture.begin(1,1,point(4)); capture.begin(2,1.045,point(5))
    check(capture.gestures[1].note.time==capture.gestures[2].note.time,"Separate input frames align to the exact same chord line")
    check(abs(capture.gestures[1].note.lane-capture.gestures[2].note.lane)>=3,"Adjacent heads separate before release")
    var right=capture.end(2,1.10,point(5)); var left=capture.end(1,1.14,point(4))
    check(left.time==right.time and separated(capture.notes),"Release order does not break chord alignment or spacing")
    check(left.kind=="tap" and right.kind=="tap","Auto lane movement never turns a tap into a slide")
    for edge in [0,9]:
        capture=SynkCapture.new(); capture.begin(1,2,point(edge)); capture.begin(2,2.03,point(edge))
        capture.end(1,2.08,point(edge)); capture.end(2,2.09,point(edge))
        check(separated(capture.notes) and capture.notes.all(func(n): return int(n.lane)>=0 and int(n.lane)<=9),"Same-lane double touches separate within highway edges")
    capture=SynkCapture.new()
    for i in 4: capture.begin(i,3+i*.01,point(4))
    for i in 4: capture.end(i,3.15+i*.01,point(4))
    check(capture.notes.size()==4 and separated(capture.notes),"Four close touches distribute across all available lanes")
    check(capture.notes.all(func(n): return n.time==3.0),"Four-touch chord stays on one timing line")
    capture=SynkCapture.new()
    capture.begin(1,4,point(4)); var first=capture.end(1,4.02,point(4))
    capture.begin(1,4.045,point(4)); var repeat=capture.end(1,4.07,point(4))
    check(first.time!=repeat.time and first.lane==repeat.lane,"Fast single-finger repeated taps remain separate beats")
    capture=SynkCapture.new()
    capture.begin(1,5,point(2)); capture.begin(2,5.055,point(7)); capture.begin(3,5.11,point(4))
    check(capture.gestures[3].note.time>5.0,"Chord snapping cannot chain a roll into an earlier timing line")
    capture=SynkCapture.new()
    capture.begin(1,6,point(4),"hold"); capture.begin(2,6.03,point(5))
    capture.move(1,7,point(4)); var hold=capture.end(1,8,point(4)); capture.end(2,6.12,point(5))
    check(hold.kind=="hold" and hold.end_lane==hold.lane and hold.path.is_empty(),"Shifted stationary hold stays stationary")
    var slide=SynkChart.note(9,0,"slide"); slide.duration=1; slide.end_lane=9; slide.path=[{"offset":0.0,"lane":0.0},{"offset":1.0,"lane":9.0}]; slide.checkpoints=[.5]
    var original=slide.duplicate(true); var tap=SynkChart.note(9,0)
    var result=SynkNoteSpacing.place(slide,[tap,slide],[],2.4)
    check(result.resolved and slide==original and int(tap.lane)>=3,"A full-width slide stays intact while the free tap moves to its other side")
    var fixed=SynkChart.note(10,4); original=fixed.duplicate(true)
    capture=SynkCapture.new(); capture.begin(1,10.04,point(5),"tap",[fixed]); var overdub=capture.end(1,10.12,point(5))
    check(fixed==original and overdub.time==fixed.time and abs(int(overdub.lane)-int(fixed.lane))>=3,"Overdub aligns and moves only the new note, preserving saved notes")
    var crowded: Array=[]
    for i in 5: crowded.append(SynkChart.note(11,4))
    original={"notes":crowded.duplicate(true)}; result=SynkNoteSpacing.place(crowded[0],crowded,[],2.4)
    check(not result.resolved and crowded==original.notes,"Impossible chords never drop or corrupt notes")
    print("Chord timing and automatic spacing: "+("PASS" if failures==0 else "FAIL"))
    quit(failures)
