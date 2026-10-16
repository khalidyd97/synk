extends SceneTree
func _initialize():
    var output="res://assets/brand/"
    for entry in [["icon_launcher.svg","icon.png",512],["icon_launcher.svg","icon_android_192.png",192],["icon_adaptive_foreground.svg","icon_foreground_432.png",432],["icon_adaptive_background.svg","icon_background_432.png",432],["icon_adaptive_monochrome.svg","icon_monochrome_432.png",432]]:
        var image=Image.new()
        var error=image.load_svg_from_string(FileAccess.get_file_as_string(output+entry[0]))
        if error!=OK: push_error("Could not render "+entry[0]); quit(1); return
        image.resize(entry[2],entry[2],Image.INTERPOLATE_LANCZOS)
        if image.save_png(output+entry[1])!=OK: quit(1); return
    print("Launcher icons rendered: legacy, adaptive foreground/background, and monochrome.")
    quit()
