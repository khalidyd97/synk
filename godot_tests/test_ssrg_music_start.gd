extends SceneTree

# A start marker (position above 12, flag 1) is where the music begins; note times count from it.
# 1004_13.seq starts at tick 896 and its notes only line up with the .ogg once 1.721 s is removed.
func _initialize() -> void:
	var importer=load("res://scripts/ssrg_import.gd")
	var records=[[896,31,1,0],[1024,0,0,0],[1280,5,0,0],[33024,13,0,0]]
	var bytes=PackedByteArray(); bytes.resize(0x58+records.size()*24)
	bytes.encode_double(8,63.4445); bytes.encode_u32(16,256)
	bytes.encode_u32(44,records.size()); bytes.encode_double(80,122.0)
	for i in records.size():
		var at=0x58+i*24
		bytes.encode_s64(at,records[i][0]); bytes.encode_u32(at+8,records[i][1])
		bytes.encode_u32(at+12,records[i][2]); bytes.encode_u32(at+16,records[i][3])
	var chart=importer.parse(bytes)
	var tick=60.0/122.0/256.0
	assert(chart.notes.size()==2,"Markers are not notes")
	assert(is_equal_approx(chart.notes[0].time,128*tick),"Notes count from the music start")
	assert(is_equal_approx(chart.notes[1].time,384*tick))
	assert(is_equal_approx(chart.beat_offset,128*tick),"Beats stay on whole-beat chart ticks")
	assert(is_equal_approx(chart.length,63.4445-896*tick),"Length counts from the music start")
	# Without a start marker nothing moves.
	bytes.encode_u32(0x58+12,0)
	chart=importer.parse(bytes)
	assert(is_equal_approx(chart.notes[0].time,1024*tick) and is_zero_approx(chart.beat_offset))
	print("SSRG music start: PASS")
	quit()
