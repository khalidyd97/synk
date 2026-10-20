extends RefCounted
# Solve two screen-to-ground homographies from the actual camera projection.
var state: Array=[]
var planes: Dictionary={}
var origin=Vector3.ZERO
var forward=Vector3.FORWARD
var minimum_depth=0.0
var judgment_y=0.0
var lane_centers=PackedVector2Array()
var builds=0
func prepare(camera: Camera3D,viewport_size: Vector2i,world: Node3D) -> void:
    var current=[camera.get_camera_transform(),camera.get_camera_projection(),viewport_size]
    if current==state: return
    state=current; builds+=1; planes.clear(); lane_centers.clear()
    if viewport_size.x<=0 or viewport_size.y<=0: return
    origin=camera.get_camera_transform().origin; forward=-camera.get_camera_transform().basis.z
    minimum_depth=camera.near if camera.projection==Camera3D.PROJECTION_ORTHOGONAL else 0.0
    var viewport=Vector2(viewport_size)
    for height in [0.0,.035]:
        var rows: Array=[]
        for point in [Vector3(-10,height,0),Vector3(10,height,0),Vector3(-10,height,-60),Vector3(10,height,-60)]:
            var screen=camera.unproject_position(point)/viewport
            var x=screen.x; var y=screen.y; var u=point.x; var v=point.z
            rows.append([x,y,1.0,0.0,0.0,0.0,-u*x,-u*y,u])
            rows.append([0.0,0.0,0.0,x,y,1.0,-v*x,-v*y,v])
        planes[height]=solve(rows)
    judgment_y=camera.unproject_position(Vector3(world.lane_x(world.CENTER_LANE),.035,0)).y/viewport.y
    for lane in SynkChart.LANES: lane_centers.append(camera.unproject_position(Vector3(world.lane_x(lane),.035,0)))
func solve(rows: Array) -> PackedFloat64Array:
    for column in 8:
        var pivot=column
        for row in range(column+1,8):
            if absf(rows[row][column])>absf(rows[pivot][column]): pivot=row
        if absf(rows[pivot][column])<1e-12: return PackedFloat64Array()
        var swap=rows[column]; rows[column]=rows[pivot]; rows[pivot]=swap
        var divisor=float(rows[column][column])
        for cell in range(column,9): rows[column][cell]/=divisor
        for row in 8:
            if row==column: continue
            var factor=float(rows[row][column])
            for cell in range(column,9): rows[row][cell]-=factor*rows[column][cell]
    var result=PackedFloat64Array()
    for i in 8: result.append(float(rows[i][8]))
    return result
func hit(point: Vector2,height: float) -> Variant:
    var h: PackedFloat64Array=planes.get(height,PackedFloat64Array())
    if h.is_empty(): return null
    var divisor=h[6]*point.x+h[7]*point.y+1.0
    if absf(divisor)<1e-9: return null
    var result=Vector3((h[0]*point.x+h[1]*point.y+h[2])/divisor,height,(h[3]*point.x+h[4]*point.y+h[5])/divisor)
    return result if (result-origin).dot(forward)>=minimum_depth else null
