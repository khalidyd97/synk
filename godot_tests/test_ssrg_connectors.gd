extends SceneTree

func _initialize() -> void:
	var importer=load("res://scripts/ssrg_import.gd")
	for stationary in [false,true]:
		var bytes=PackedByteArray(); bytes.resize(0x58+5*24)
		bytes.encode_double(8,60.0); bytes.encode_u32(16,256)
		bytes.encode_u32(44,5); bytes.encode_double(80,120.0)
		for i in 5:
			var at=0x58+i*24
			bytes.encode_s64(at,i*256)
			bytes.encode_u32(at+8,0 if stationary else [0,4,8,4,12][i])
			bytes.encode_u32(at+16,21 if i==0 else 22)
		var chart=importer.parse(bytes)
		assert(SynkChart.valid(chart.notes))
		assert(chart.notes.size()==1)
		assert(chart.notes[0].kind==("hold" if stationary else "slide"))
		assert(chart.notes[0].checkpoints==[.5,1.0,1.5])
		assert(chart.notes[0].duration==2.0)
	print("SSRG connector import: PASS")
	quit()
