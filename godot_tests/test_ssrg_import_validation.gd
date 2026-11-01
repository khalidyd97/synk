extends SceneTree
const F=preload("res://godot_tests/ssrg_import_fixtures.gd")
const P=preload("res://scripts/ssrg_import.gd")
const A=preload("res://scripts/ssrg_import_archive.gd")
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func zip(path:String,name:String,data:PackedByteArray) -> void:
	var pack=ZIPPacker.new();assert(pack.open(path)==OK);assert(pack.start_file(name)==OK);assert(pack.write_file(data)==OK);pack.close_file();pack.close()
func _initialize():
	var report=P.report(F.raw([[64,0,0,0],[128,4,0,11],[192,8,0,12]]),13)
	check(report.errors.is_empty() and report.chart.keys==13,"Sparse 13-key charts honor explicit filename/review key count")
	check(report.chart.notes.size()==2 and report.chart.notes[0].ssrg_tick==64,"Raw tick and record order are retained")
	check(report.chart.source.ticks_per_beat==256 and not report.chart.source.header_base64.is_empty(),"Source header and tick calibration are retained")
	var dense=P.report(F.raw([[1,0,0,0],[2,0,0,0]],0,96000),4)
	check(dense.chart.notes.size()==2,"Distinct sub-millisecond taps are never rounded away")
	check(not P.report(F.raw([[64,0,0,99]]),4).errors.is_empty(),"Unknown playable type is reported explicitly")
	check(not P.report(F.raw([[64,0,0,11],[64,4,0,12]]),4).errors.is_empty(),"Simultaneous linked connectors are rejected instead of silently approximated")
	check(not P.report(F.raw([[0,0,0,0]],64),4).errors.is_empty(),"Pre-audio notes cannot be silently clamped")
	check(not P.report(PackedByteArray([1,2,3])).errors.is_empty(),"Truncated chart is explained")
	var bad=F.raw([[64,0,0,0]]);bad.encode_double(0x50,NAN)
	check(not P.report(bad,4).errors.is_empty(),"Invalid BPM is rejected")
	var root=F.folder("ssrg-import-validation");var archive=root.path_join("pack.zip")
	zip(archive,"GAME/seq/song_4.seq",F.raw([[64,0,0,0]]))
	var index=A.inspect(archive);check(index.error.is_empty() and index.entries.size()==1,"Standard song ZIP indexed before extraction")
	var unpack=A.extract(archive,root.path_join("cache"),func():return false)
	check(unpack.error.is_empty() and FileAccess.get_file_as_bytes(unpack.files[0])==F.raw([[64,0,0,0]]),"ZIP preserves original chart bytes")
	for name in ["../escaped.seq","/absolute.seq","C:/absolute.seq","nested/../../escaped.seq"]:
		zip(archive,name,PackedByteArray([1,2,3]));check(not A.inspect(archive).error.is_empty(),"ZIP traversal/absolute path rejected: "+name)
	zip(archive,"song.seq",F.raw([[64,0,0,0]]))
	var bytes=FileAccess.get_file_as_bytes(archive)
	for i in range(bytes.size()-46):
		if bytes.decode_u32(i)==0x02014b50:bytes.encode_u32(i+24,0x7fffffff);break
	F.write(archive,bytes);check(not A.inspect(archive).error.is_empty(),"Oversized declared ZIP entry rejected before decompression")
	check(not FileAccess.file_exists(root.path_join("escaped.seq")),"Unsafe archives never write outside their cache")
	print("SSRG import validation failures: ",failures);quit(failures)
