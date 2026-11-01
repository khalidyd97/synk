extends "res://scripts/highway_look_preview.gd"
# Hit effects page preview: the live highway, firing about three hits a second across the lanes
# (taps, flicks and slides in turn), so style, size, colour, flashes and particles show at once.
const PATTERN = [[2.0,"tap",0],[6.0,"tap",0],[4.0,"flick",0],[8.0,"tap",0],[1.0,"slide",0],[5.0,"flick",1],[7.0,"tap",0],[3.0,"flick",3]]
const INTERVAL = .32
var clock = 0.0
var step = 0

func _process(delta: float) -> void:
    super._process(delta)
    if not is_visible_in_tree() or game==null or game.field==null: clock=0.0; return
    clock+=delta
    if clock<INTERVAL: return
    clock=0.0
    var hit=PATTERN[step%PATTERN.size()]; step+=1
    game.field.world.spawn_hit(float(hit[0]),str(hit[1]),int(hit[2]))
