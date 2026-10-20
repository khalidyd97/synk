extends RefCounted
# Allocate dictionaries and slots during loading; only fill existing fields on a hit.
var timing: Array=[]
var performance: Array=[]
var timing_count=0
var performance_count=0
var timing_target=0
var performance_target=0
var reserve_cursor=0
var fallback_allocations=0
func reset() -> void:
    timing_count=0; performance_count=0; fallback_allocations=0
func begin_reserve(performance_size: int,timing_size: int) -> void:
    performance_target=performance_size; timing_target=timing_size; reserve_cursor=0
    if performance.size()<performance_size: performance.resize(performance_size)
    if timing.size()<timing_size: timing.resize(timing_size)
func reserve_step(budget_usec: int=4000) -> bool:
    var begin=Time.get_ticks_usec()
    var count=maxi(performance_target,timing_target)
    while reserve_cursor<count and Time.get_ticks_usec()-begin<budget_usec:
        if reserve_cursor<performance_target and performance[reserve_cursor]==null: performance[reserve_cursor]={"time":0.0,"weight":0.0,"amount":1}
        if reserve_cursor<timing_target and timing[reserve_cursor]==null: timing[reserve_cursor]={"time":0.0,"ms":0.0}
        reserve_cursor+=1
    return reserve_cursor>=count
func add_performance(at: float,weight: float) -> void:
    if performance_count>=performance.size(): performance.resize(maxi(16,performance.size()*2))
    if performance[performance_count]==null:
        performance[performance_count]={"time":0.0,"weight":0.0,"amount":1}; fallback_allocations+=1
    var row: Dictionary=performance[performance_count]; row.time=at; row.weight=weight
    performance_count+=1
func add_timing(at: float,ms: float) -> void:
    if timing_count>=timing.size(): timing.resize(maxi(16,timing.size()*2))
    if timing[timing_count]==null:
        timing[timing_count]={"time":0.0,"ms":0.0}; fallback_allocations+=1
    var row: Dictionary=timing[timing_count]; row.time=at; row.ms=ms
    timing_count+=1
func timing_snapshot() -> Array:
    var result: Array=[]
    for i in timing_count: result.append(timing[i].duplicate())
    return result
func performance_snapshot() -> Array:
    var result: Array=[]
    for i in performance_count: result.append(performance[i].duplicate())
    return result
