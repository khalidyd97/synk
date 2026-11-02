extends SceneTree
const SCROLL=preload("res://scripts/drag_scroll.gd")
const MODAL=preload("res://scripts/modal_input.gd")
const SHEET=preload("res://scripts/color_picker_sheet.gd")
var failures=0
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func _initialize():run.call_deferred()
func touch(point:Vector2,down:bool,index:int=0):
 var event=InputEventScreenTouch.new();event.index=index;event.position=point;event.pressed=down
 root.push_input(event,true);await process_frame
func drag(point:Vector2,relative:Vector2,index:int=0):
 var event=InputEventScreenDrag.new();event.index=index;event.position=point;event.relative=relative
 root.push_input(event,true);await process_frame
func run():
 root.size=Vector2i(1564,720)
 var host=Control.new();root.add_child(host);host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var scroll=ScrollContainer.new();host.add_child(scroll);scroll.position=Vector2(10,10);scroll.size=Vector2(1500,690)
 var content=Control.new();content.custom_minimum_size=Vector2(3000,3000);scroll.add_child(content)
 var helper=SCROLL.attach(scroll)
 for i in 4:await process_frame
 scroll.scroll_vertical=100
 var sheet=SHEET.open(host,"Touch regression",Color.RED,func(_color):pass)
 for i in 4:await process_frame
 helper.velocity=1000;helper.motion_position=100
 var center=sheet.square.get_global_rect().get_center();var old_s=sheet.saturation
 await touch(center,true);await drag(center+Vector2(30,-40),Vector2(30,-40));await touch(center+Vector2(30,-40),false)
 check(absf(sheet.saturation-old_s)>.05,"Native touch changes the real color picker")
 check(scroll.scroll_vertical==100 and helper.velocity==0,"Picker touch and existing momentum cannot move the menu beneath")
 check(MODAL.blocked(scroll),"Popup owns background input")
 check(not MODAL.blocked(sheet.palette_scroll),"A popup's own scroll area remains usable")
 sheet.close(false);await create_timer(.3).timeout
 check(not MODAL.blocked(scroll),"Closed popup releases its background")
 var start=Vector2(200,400)
 await touch(start,true);await drag(start-Vector2(0,100),Vector2(0,-100))
 check(scroll.scroll_vertical>=200,"Native touch scrolls menus")
 var before=scroll.scroll_vertical
 await touch(Vector2(300,300),true,1);await drag(Vector2(300,100),Vector2(0,-200),1)
 check(scroll.scroll_vertical==before,"Another finger cannot steal the gesture")
 await drag(start-Vector2(0,130),Vector2(0,-30));await touch(start-Vector2(0,130),false)
 var released=scroll.scroll_vertical;await create_timer(.12).timeout
 check(scroll.scroll_vertical>released,"Native touch flick glides after release")
 helper.stop();helper.set_process(false)
 var distances=[]
 for frames in [1,30,60]:
  helper.set_position(100);helper.velocity=1000
  for i in frames:helper._process(.5/frames)
  distances.append(helper.motion_position)
 check(absf(distances[0]-distances[1])<.01 and absf(distances[1]-distances[2])<.01,"Momentum distance is independent of refresh rate")
 helper.horizontal=true;helper.set_position(100);helper.set_process(true)
 await touch(Vector2(500,300),true);await drag(Vector2(250,300),Vector2(-250,0));await touch(Vector2(250,300),false)
 check(scroll.scroll_horizontal>=350,"Horizontal song-card gestures use the same native touch path")
 var modal=Control.new();host.add_child(modal);MODAL.register(modal)
 helper.velocity=1000;await process_frame
 check(helper.velocity==0,"Opening another modal cancels card inertia")
 modal.hide();check(not MODAL.blocked(scroll),"Hidden modals do not block input")
 host.queue_free();await process_frame
 print("Modal and native scrolling: ","PASS" if failures==0 else str(failures)+" FAILED")
 quit(failures)
