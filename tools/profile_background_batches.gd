extends SceneTree
func _initialize():run.call_deferred()
func run():
	var args=OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass a saved baseline background script path after --");quit(2);return
	var report={}
	var renderers=[]
	for path in [args[0],"res://scripts/ssrg_background.gd"]:
		var bg=load(path).new();root.add_child(bg);bg.configure(0);bg.rng.seed=73
		for i in 180:bg.advance(1.0/60)
		renderers.append(bg)
	var samples=[[],[]]
	for i in 600:
		for index in 2:
			var start=Time.get_ticks_usec();renderers[index]._render()
			if i>=100:samples[index].append(Time.get_ticks_usec()-start)
	for index in 2:
		samples[index].sort()
		report["before" if index==0 else "after"]={"particles":renderers[index].particles.size(),"p50_us":samples[index][250],"p95_us":samples[index][475]}
	print("BACKGROUND_BATCHES ",JSON.stringify(report))
	FileAccess.open("res://.tools/background-batches-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
