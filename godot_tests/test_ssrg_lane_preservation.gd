extends SceneTree
func _initialize() -> void:
	var importer=load("res://scripts/ssrg_import.gd")
	for keys in [4,7,13]:
		var bytes=PackedByteArray(); bytes.resize(0x58+keys*24)
		bytes.encode_double(8,60.0); bytes.encode_u32(16,256)
		bytes.encode_u32(44,keys); bytes.encode_double(80,120.0)
		for index in keys:
			var offset=0x58+index*24
			bytes.encode_s64(offset,index*256)
			bytes.encode_u32(offset+8,index*(12/(keys-1)))
		var chart=importer.parse(bytes)
		assert(chart.keys==keys)
		assert(SynkChart.valid(chart.notes))
		var lanes={}
		for note in chart.notes: lanes[note.lane]=true
		assert(lanes.size()==keys,"Imported lanes must remain distinct")
	print("SSRG lane preservation: PASS")
	quit()
