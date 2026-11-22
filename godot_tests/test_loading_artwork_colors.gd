extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func run():
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro.set_process(false); g.highway_colors="theme"
    var intro=g.stage_intro
    for colors in [[Color("e84b20"),Color("e7aa23")],[Color("18aa74"),Color("20a6b5")],[Color("aaaaaa"),Color("444444")]]:
        var image=Image.create(64,64,false,Image.FORMAT_RGBA8)
        image.fill(colors[0]); image.fill_rect(Rect2i(32,0,32,64),colors[1])
        var texture=ImageTexture.create_from_image(image)
        intro.begin(texture,Color.WHITE,"ARTWORK COLORS","NORMAL • 120 BPM",false)
        var expected=SynkCoverPalette.from_image(image)
        if expected.from_cover:
            check(intro.accent.is_equal_approx(expected.notes[0]),"Loading uses the artwork's dominant color even with fixed gameplay colors")
            check(intro.accent_2.is_equal_approx(expected.notes[1]),"Secondary loading color comes from the artwork palette")
        else: check(intro.accent.s<.01 and intro.accent_2.s<.01,"Monochrome artwork uses neutral loading accents")
        check(intro.backdrop_art.material.get_shader_parameter("palette_primary").is_equal_approx(intro.accent),"Animated backdrop shares the artwork palette")
        check(is_equal_approx(intro.load_time,5),"Adaptive loading keeps the five-second duration")
        intro.elapsed=1; intro.animate()
        check(is_equal_approx(intro.card.modulate.r,.9) and intro.backdrop_art.modulate.a<=.35,"Loading keeps the sharp card legible over the artwork backdrop")
        check(is_zero_approx(float(intro.backdrop_art.material.get_shader_parameter("blur_amount"))),"Loading background stays sharp before 100 percent")
        intro.elapsed=intro.load_time+intro.BLUR_TIME*.5;intro.animate()
        var halfway=float(intro.backdrop_art.material.get_shader_parameter("blur_amount"))
        check(halfway>0.0 and halfway<1.0 and is_zero_approx(intro.entrance()),"Gaussian handoff begins only after loading completes and precedes the highway")
        intro.elapsed=intro.load_time+intro.BLUR_TIME;intro.animate()
        check(is_equal_approx(float(intro.backdrop_art.material.get_shader_parameter("blur_amount")),1.0),"Background reaches its full gameplay blur before the stage reveal")
    g.queue_free(); await process_frame
    print("Artwork-adaptive loading: ","PASS" if failures==0 else str(failures)+" FAILED")
    quit(0 if failures==0 else 1)
