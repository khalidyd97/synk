class_name SynkNoteSpacing
extends RefCounted

# Only simultaneous heads form a chord. Fast single-finger repeats keep their timing.
const SAME_LINE = .001

static func sustain(n: Dictionary) -> bool:
    return n.kind in ["hold","slide"] and float(n.duration)>.04

static func conflict(a: Dictionary,b: Dictionary,gap: float) -> bool:
    if absf(float(a.time)-float(b.time))<=SAME_LINE:
        return absf(float(a.lane)-float(b.lane))<gap-.001
    # Leave room beside a sustained note already passing through this timing line.
    for pair in [[a,b],[b,a]]:
        var head: Dictionary=pair[0]; var trail: Dictionary=pair[1]
        if sustain(trail) and float(head.time)>float(trail.time) and float(head.time)<float(trail.time)+float(trail.duration):
            if absf(float(head.lane)-SynkChart.lane_at(trail,float(head.time)))<gap*.7: return true
    return false

static func shift(n: Dictionary,delta: int) -> void:
    n.lane=int(n.lane)+delta; n.end_lane=int(n.end_lane)+delta
    for point in n.path: point.lane=float(point.lane)+delta

static func can_shift(n: Dictionary,delta: int) -> bool:
    var lanes=[float(n.lane),float(n.end_lane)]
    for point in n.path: lanes.append(float(point.lane))
    for lane in lanes:
        if lane+delta<0 or lane+delta>SynkChart.MAX_LANE: return false
    return true

static func search(state: Dictionary,index: int,last_lane: int,cost: float,placements: Array) -> void:
    if cost>=state.best_cost: return
    if index==state.group.size():
        state.best_cost=cost; state.best=placements.duplicate(); state.best_group=state.group.duplicate(); return
    var entry: Dictionary=state.group[index]
    for candidate in entry.options:
        if index>0 and candidate-last_lane<state.step: continue
        # Reserve enough lanes for the remaining heads before exploring this branch.
        if candidate+(state.group.size()-1-index)*state.step>SynkChart.MAX_LANE: continue
        placements.append(candidate)
        search(state,index+1,candidate,cost+absf(candidate-float(entry.note.lane))*entry.weight,placements)
        placements.pop_back()

static func search_orders(state: Dictionary,prefix: Array,remaining: Array) -> void:
    if remaining.is_empty():
        state.group=prefix; search(state,0,-100,0.0,[]); return
    for i in remaining.size():
        var next=remaining.duplicate(); var entry=next.pop_at(i)
        search_orders(state,prefix+[entry],next)

# Reposition only authoring-session notes; saved/locked chart notes are immutable obstacles.
# Search the whole chord so four close touches can spread to 0/3/6/9 rather than get stuck.
static func place(note: Dictionary,movable: Array,fixed: Array,gap: float=2.4) -> Dictionary:
    var group: Array=[]; var blockers=fixed.duplicate(); var ordinal=0
    for other in movable:
        if is_same(other,note): continue
        if absf(float(other.time)-float(note.time))<=SAME_LINE:
            group.append({"note":other,"order":ordinal,"weight":8.0 if sustain(other) else 1.4})
        else: blockers.append(other)
        ordinal+=1
    group.append({"note":note,"order":ordinal,"weight":8.0 if sustain(note) else 1.0})
    var start=float(note.time); var finish=start
    for entry in group: finish=maxf(finish,float(entry.note.time)+float(entry.note.duration))
    blockers=blockers.filter(func(other): return float(other.time)<=finish+SAME_LINE and float(other.time)+float(other.duration)>=start-SAME_LINE)
    var needs_change=false
    for entry in group:
        for obstacle in blockers:
            if conflict(entry.note,obstacle,gap): needs_change=true
        for other in group:
            if not is_same(entry.note,other.note) and conflict(entry.note,other.note,gap): needs_change=true
    if not needs_change: return {"resolved":true,"moved":0}
    if (group.size()-1)*maxi(1,ceili(gap-.001))>SynkChart.MAX_LANE: return {"resolved":false,"moved":0}
    group.sort_custom(func(a,b): return a.order<b.order if int(a.note.lane)==int(b.note.lane) else int(a.note.lane)<int(b.note.lane))
    for entry in group:
        entry.options=[]
        for lane in SynkChart.LANES:
            var delta=lane-int(entry.note.lane)
            if not can_shift(entry.note,delta): continue
            var candidate: Dictionary=entry.note.duplicate(true); shift(candidate,delta)
            var free=true
            for obstacle in blockers:
                if conflict(candidate,obstacle,gap): free=false; break
            if free: entry.options.append(lane)
    var state={"group":group,"step":maxi(1,ceili(gap-.001)),"best_cost":INF,"best":[]}
    search(state,0,-100,0.0,[])
    # A full-width slide may force a free tap to the opposite side of its head.
    if state.best.is_empty(): search_orders(state,[],group)
    if state.best.is_empty(): return {"resolved":false,"moved":0}
    group=state.best_group
    var moved=0
    for i in group.size():
        var delta=int(state.best[i])-int(group[i].note.lane)
        if delta!=0: shift(group[i].note,delta); moved+=1
    return {"resolved":true,"moved":moved}
