extends RefCounted
# Two ordered event cursors keep a long sustain from forcing scans of retired notes.
var travel=0.0
var speed=0.0
var enter_times=PackedFloat64Array()
var exits: Array=[]
var active: Dictionary={}
var enter_cursor=0
var exit_cursor=0
var last_time=-INF
func _init(live: Array,travel_seconds: float,travel_speed: float) -> void:
    travel=travel_seconds; speed=travel_speed
    for i in live.size():
        enter_times.append(float(live[i].note.time)-travel)
        exits.append([float(live[i].note.time)+float(live[i].note.duration)+5.0/speed,i])
    exits.sort_custom(func(a,b): return a[0]<b[0])
func indices(time: float) -> Dictionary:
    if time<last_time:
        active.clear(); enter_cursor=0; exit_cursor=0
    last_time=time
    while enter_cursor<enter_times.size() and enter_times[enter_cursor]<=time:
        active[enter_cursor]=true; enter_cursor+=1
    while exit_cursor<exits.size() and exits[exit_cursor][0]<time:
        active.erase(int(exits[exit_cursor][1])); exit_cursor+=1
    return active
