extends RefCounted
static func inspect(notes: Array,song_end: float) -> Array:
    var issues: Array=[]; var ordered: Array=[]
    for i in notes.size():
        if not SynkChart.valid([notes[i]]):
            issues.append({"index":i,"time":0.0,"message":"Invalid note data","severity":"ERROR"}); continue
        var n: Dictionary=notes[i]
        ordered.append({"index":i,"note":n})
        if float(n.time)+float(n.duration)>song_end+.001:
            issues.append({"index":i,"time":n.time,"message":"Note extends past the song end","severity":"ERROR"})
        if n.kind in ["hold","slide"] and float(n.duration)<.04:
            issues.append({"index":i,"time":n.time,"message":"Hold or slide is too short","severity":"WARNING"})
        if n.kind=="slide":
            var path: Array=n.path if n.path.size()>1 else [{"offset":0.0,"lane":float(n.lane)},{"offset":float(n.duration),"lane":float(n.end_lane)}]
            for p in range(1,path.size()):
                var delta=absf(float(path[p].lane)-float(path[p-1].lane))
                var seconds=float(path[p].offset)-float(path[p-1].offset)
                if delta>1 and delta/maxf(.001,seconds)>30:
                    issues.append({"index":i,"time":n.time,"message":"Very fast slide movement; review playability","severity":"WARNING"}); break
    ordered.sort_custom(func(a,b): return float(a.note.time)<float(b.note.time))
    var active: Array=[]
    for entry in ordered:
        var n: Dictionary=entry.note
        active=active.filter(func(e): return float(e.note.time)+maxf(.02,float(e.note.duration))>float(n.time)+.001)
        for other in active:
            if absf(SynkChart.lane_at(other.note,float(n.time))-float(n.lane))<.4:
                issues.append({"index":entry.index,"time":n.time,"message":"Overlaps note %d in the same lane" % (int(other.index)+1),"severity":"WARNING"}); break
        active.append(entry)
        if issues.size()>=250: break
    issues.sort_custom(func(a,b): return float(a.time)<float(b.time))
    return issues
