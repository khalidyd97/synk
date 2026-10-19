extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func clear(toasts):
    for item in toasts.items.duplicate(): toasts.dismiss(item,false)
func run():
    AudioServer.set_bus_mute(0,true)
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.get_node("SafeAreaPoll").stop()
    var toasts=g.toast_layer; clear(toasts)
    g.tell("Chart saved.")
    check(toasts.items.size()==1 and toasts.items[0].kind=="success","Game action feedback uses a success toast")
    check(g.status.text=="Chart saved." and not g.status.visible,"Last-message data remains available without duplicate inline text")
    g.tell("Chart saved.")
    check(toasts.items.size()==1,"Repeated messages refresh one toast rather than stacking duplicates")
    var hint=g.chart_library.message_label.text
    g.chart_library.set_message("Audio could not be loaded.")
    check(toasts.items[0].kind=="error" and g.chart_library.message_label.text==hint,"Library failures route to error toasts instead of replacing permanent guidance")
    g.features.report("Select a range containing notes first.")
    check(toasts.items[0].kind=="warning","Chart tool validation uses warning toasts")
    g.tell("Preview ready.")
    for i in 5: await process_frame
    check(toasts.items.size()==3 and toasts.items[0].message=="Preview ready.","Three notifications stack after text wrapping settles")
    toasts.dismiss(toasts.items.back(),true)
    for i in 8: g.tell("Notice "+str(i),"info")
    check(toasts.items.size()<=3,"Rapid messages remain bounded during dismissal animations")
    clear(toasts); g.tell("Loading audio…"); g.tell("Audio imported.")
    check(toasts.items.size()==1 and toasts.items[0].kind=="success","Completion replaces stale loading notifications")
    clear(toasts); toasts.notify("Temporary notice","info",.03)
    toasts._process(.05); await create_timer(.25).timeout
    check(toasts.items.is_empty(),"Toasts animate out and clean themselves up after expiry")
    g.lobby.show_play_browser(); await process_frame
    g.lobby.search.grab_focus(); await process_frame; await process_frame
    var floating=g.floating_text_input; floating.set_process(false)
    g.set_safe_area_pixels(Rect2(120,0,2280,1080),Vector2(2400,1080))
    floating.layout_for_keyboard(DisplayServer.window_get_size().y*.45)
    g.tell("Bookmark saved.")
    await process_frame; await process_frame; await create_timer(.25).timeout
    var card=toasts.items[0].card
    var safe=g.safe_area_rect
    check(card.position.x>=safe.position.x and card.position.x+card.size.x<=safe.end.x,"Toast avoids simulated display cutouts")
    check(card.position.y+card.size.y<floating.panel.position.y,"Toast remains above the floating field and keyboard")
    check(toasts.overlay.mouse_filter==Control.MOUSE_FILTER_IGNORE and card.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Toast body does not block gameplay input")
    var close=card.get_child(0).get_child(0).get_child(2)
    close.pressed.emit(); await create_timer(.25).timeout
    check(toasts.items.is_empty(),"Dismiss button removes a toast")
    floating.finish(true); clear(toasts)
    g.queue_free(); await process_frame
    print("Unified game toast notifications: ","PASS" if failures==0 else str(failures)+" FAILED")
    quit(0 if failures==0 else 1)
