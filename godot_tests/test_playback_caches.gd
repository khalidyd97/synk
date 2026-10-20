extends SceneTree
var failures=0
const PlaybackCurve=preload("res://scripts/playback_curve.gd")
const Visibility=preload("res://scripts/playback_visibility.gd")
func check(ok: bool,message: String) -> void:
    if not ok: failures+=1; push_error(message)
func _initialize() -> void:
    var rng=RandomNumberGenerator.new(); rng.seed=901
    for case in 40:
        var note=SynkChart.note(3,2,"slide"); note.duration=5; note.end_lane=8
        if case>1:
            for i in 12: note.path.append({"offset":i*5.0/11,"lane":float(rng.randi_range(0,9))})
        elif case==1: note.path=[{"offset":0.0,"lane":2.0}]
        var original=JSON.stringify(note)
        var cached=PlaybackCurve.new(note)
        for i in 601:
            var at=2.5+i*.01
            check(absf(cached.lane_at(at)-SynkChart.lane_at(note,at))<.0000001,"Cached slide curve matches the original, including turns, flat spans and boundaries")
        check(JSON.stringify(note)==original,"Curve preparation never adds runtime data to the saved note")
    var long_hold=SynkChart.note(1,3,"hold"); long_hold.duration=100
    var live: Array=[{"note":long_hold}]
    for i in range(2,300): live.append({"note":SynkChart.note(float(i),i%10)})
    var timeline=Visibility.new(live,2.6,60.0/2.6)
    for at in [-3.0,0.0,1.0,50.0,80.0,104.0,299.0,10.0]:
        var got=timeline.indices(at)
        for i in live.size():
            var note=live[i].note
            var expected=float(note.time)-2.6<=at and float(note.time)+float(note.duration)+5.0/(60.0/2.6)>=at
            check(got.has(i)==expected,"Visibility timeline agrees with the render window across jumps and backward seeks")
    timeline.indices(50)
    check(timeline.active.has(0) and timeline.active.size()<8,"A long sustain remains visible without scanning all retired notes")
    print("Playback caches: ","PASS" if failures==0 else str(failures)+" FAILED")
    quit(0 if failures==0 else 1)

