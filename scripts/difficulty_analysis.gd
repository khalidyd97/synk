extends RefCounted
# Heuristic chart rating for comparison, not an official difficulty scale.
static func analyze(notes: Array,song_length: float) -> Dictionary:
    var ordered=notes.duplicate(true)
    ordered=ordered.filter(func(n): return SynkChart.valid([n]))
    ordered.sort_custom(func(a,b): return float(a.time)<float(b.time))
    var types={"tap":0,"hold":0,"slide":0,"flick":0}
    if ordered.is_empty(): return {"level":0,"tier":"EMPTY","notes":0,"average":0.0,"peak":0.0,"chords":0,"types":types,"movement":0.0}
    var first=float(ordered[0].time); var last=first; var peak=0.0; var left=0
    var chords=0; var group_start=first; var group_count=0; var movement=0.0
    for i in ordered.size():
        var n: Dictionary=ordered[i]; types[n.kind]+=1
        last=maxf(last,float(n.time)+float(n.duration))
        while left<i and float(ordered[left].time)<float(n.time)-2.0: left+=1
        peak=maxf(peak,float(i-left+1)/2.0)
        if float(n.time)-group_start>.04:
            if group_count>1: chords+=1
            group_start=float(n.time); group_count=0
        group_count+=1
        if n.kind=="slide":
            var distance=absf(float(n.end_lane)-float(n.lane))
            if n.path.size()>1:
                distance=0
                for p in range(1,n.path.size()): distance+=absf(float(n.path[p].lane)-float(n.path[p-1].lane))
            movement+=distance
    if group_count>1: chords+=1
    var span=maxf(2,minf(song_length,last)-first)
    var average=ordered.size()/span
    var complexity=1+average*1.6+peak*1.3+float(chords)/ordered.size()*5+float(types.flick)/ordered.size()*2+movement/span*.25
    var level=clampi(roundi(complexity),1,30)
    var tier="EASY" if level<=5 else ("NORMAL" if level<=10 else ("HARD" if level<=16 else ("EXPERT" if level<=23 else "MASTER")))
    return {"level":level,"tier":tier,"notes":ordered.size(),"average":average,"peak":peak,"chords":chords,"types":types,"movement":movement}
