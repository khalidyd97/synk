extends SceneTree
func _initialize() -> void:
	var note=SynkChart.note(0,1,"slide"); note.duration=2; note.end_lane=1
	note.path=[{"offset":0.0,"lane":1.0},{"offset":1.0,"lane":8.0},{"offset":2.0,"lane":1.0}]
	note.ssrg_path=true
	assert(is_equal_approx(SynkChart.lane_at(note,.25),2.75))
	assert(is_equal_approx(SynkChart.lane_at(note,1.25),6.25))
	var world=load("res://scripts/highway_3d.gd").new()
	var centers=[Vector3(0,0,0),Vector3(5,0,-5),Vector3(-2,0,-9),Vector3(-2,0,-14)]
	var sides=world.connector_sides(centers)
	for i in centers.size()-1:
		var direction: Vector3=(centers[i+1]-centers[i]).normalized()
		var normal=Vector3(-direction.z,0,direction.x)
		assert(is_equal_approx(absf(sides[i].dot(normal)),1.0),"Segment start keeps full width")
		assert(is_equal_approx(absf(sides[i+1].dot(normal)),1.0),"Segment end keeps full width")
	world.free()
	print("SSRG straight connectors and constant width: PASS")
	quit()
