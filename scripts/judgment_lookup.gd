extends RefCounted
# Entries remain in chart order; completed entries retire between iterations.
var live: Array=[]
var cursor=0
var active: Dictionary={}
var retired: Array=[]
var retired_count=0
var last_time=-INF
func _init(entries: Array) -> void:
    live=entries; retired.resize(entries.size())
func retire(index: int) -> void:
    if active.get(index,false):
        active[index]=false; retired[retired_count]=index; retired_count+=1
func candidates(time: float,lookahead: float=.23) -> Dictionary:
    for i in retired_count: active.erase(retired[i])
    retired_count=0
    if time<last_time: active.clear(); cursor=0
    last_time=time
    while cursor<live.size() and float(live[cursor].note.time)<=time+lookahead:
        if not live[cursor].done: active[cursor]=true
        cursor+=1
    return active
