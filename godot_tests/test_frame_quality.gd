extends SceneTree
func _initialize() -> void:
    var q=load("res://scripts/frame_quality.gd").new()
    q.reset(1.0)
    for i in 600: q.sample(1.0/40.0,60.0,1.0)
    assert(q.scale<1.0 and q.scale>=.75,"Sustained slow frames lower quality within bounds")
    var low=q.scale
    for i in 1500: q.sample(1.0/60.0,60.0,1.0)
    assert(q.scale>low and q.scale<=1.0,"Stable frames restore quality gradually")
    q.reset(.85)
    for i in 1200: q.sample(1.0/30.0,60.0,.85)
    assert(is_equal_approx(q.scale,.75),"Heavy load stops at quality floor")
    for i in 3000: q.sample(1.0/60.0,60.0,.85)
    assert(is_equal_approx(q.scale,.85),"User resolution remains the ceiling")
    q.reset(1.0)
    for i in 100: q.sample(.3,60.0,1.0)
    assert(q.scale==1.0,"Isolated large stalls cannot lower quality")
    print("Frame quality: PASS")
    quit()
