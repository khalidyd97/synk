extends SceneTree

const Rules=preload("res://scripts/ssrg_input_rules.gd")

func _initialize() -> void:
	assert(Rules.grade(0.0)=="PERFECT")
	assert(Rules.grade(0.09)=="PERFECT")
	assert(Rules.grade(0.0901)=="GREAT")
	assert(Rules.grade(0.21)=="GREAT")
	assert(Rules.grade(0.2101)=="GOOD")
	assert(Rules.grade(0.2999)=="GOOD")
	assert(Rules.grade(0.3)=="MISS")
	assert(Rules.grade(-1.0)=="MISS")
	assert(is_equal_approx(Rules.rate(-0.12),Rules.rate(0.12)))
	assert(Rules.grade(0.06,true)=="PERFECT")
	assert(Rules.grade(0.061,true)=="GREAT")
	assert(Rules.grade(0.141,true)=="GOOD")
	assert(Rules.grade(0.201,true)=="MISS")
	assert(is_equal_approx(Rules.early_release_window(),0.225))
	for keys in [4,7,13]:
		for channel in range(0,13,4 if keys==4 else (2 if keys==7 else 1)):
			var center=Rules.channel_center(channel)
			assert(Rules.contains_lane(Vector2(center,-234),channel,keys))
			assert(not Rules.contains_lane(Vector2(center+Rules.touch_width(keys)*0.501,-234),channel,keys))
			assert(not Rules.contains_lane(Vector2(center,2),channel,keys))
		assert(Rules.side_channel(Vector2(-510,-234),keys)==0)
		assert(Rules.side_channel(Vector2(510,-234),keys)==12)
	assert(Rules.original_ui_speed(1.0)==3.0)
	print("SSRG input rules: packaged timing thresholds, touch rectangles, release and speed PASS")
	quit()
