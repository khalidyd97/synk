extends SceneTree
var failures=0
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func position(lane:float)->Vector2:return Vector2(.07+.86*(lane+.5)/13,.8)
func _initialize():
 for hz in [30,60,120]:
  var capture=SynkCapture.new();capture.begin(1,1,position(2.3))
  for i in hz*2:
   var t=float(i+1)/(hz*2)
   capture.move(1,1+t*2,position(2.3+t*6+sin(i*1.7)*.04))
  var slide=capture.end(1,3,position(8.3))
  check(slide.kind=="slide" and slide.get("ssrg_path",false),"Recorded slides use straight SSRG-style segments")
  check(slide.path.size()==2,"Slow diagonal has two clean anchors at %d Hz, got %d" % [hz,slide.path.size()])
  check(not slide.has("checkpoints"),"Recording a slide leaves connector placement to the user")
  check(slide.lane==2 and slide.end_lane==8 and is_equal_approx(slide.duration,2),"Endpoints and timing stay accurate")
  check(absf(SynkChart.lane_at(slide,2)-5)<.01,"Diagonal is straight, without lane steps")
  var loaded=SynkChart.notes_from_file({"version":3,"notes":[slide]})
  check(loaded is Array and loaded[0].get("ssrg_path",false),"Clean geometry survives save/load")
 var eased=SynkCapture.new();eased.begin(8,0,position(2),"slide")
 for i in 120:
  var t=float(i+1)/120.0
  eased.move(8,t,position(2.0+6.0*(.5-.5*cos(PI*t))+sin(i*2.1)*.08))
 var straight=eased.end(8,1,position(8))
 check(straight.path.size()==2,"A smooth finger sweep records one straight segment")
 var capture=SynkCapture.new();capture.begin(1,0,position(4.35))
 for i in 120:capture.move(1,float(i+1)/60,position(4.35+sin(i)*.08))
 var hold=capture.end(1,2,position(4.4))
 check(hold.kind=="hold" and hold.path.is_empty() and hold.end_lane==4,"Finger jitter stays a straight hold")
 capture.begin(2,3,position(2),"hold");capture.move(2,4,position(9))
 check(capture.gestures[2].note.kind=="hold","Forced hold preview remains a hold")
 hold=capture.end(2,5,position(9));check(hold.kind=="hold" and hold.end_lane==2,"Forced hold stays on its starting lane")
 capture.begin(3,6,position(2),"slide")
 for i in 120:
  var t=float(i+1)/60
  var lane=2.0 if t<.5 else (2+(t-.5)*8 if t<1.125 else 7-(t-1.125)*4)
  capture.move(3,6+t,position(lane))
 var turn=capture.end(3,8,position(3.5))
 check(turn.path.size()<10,"Complex slide uses a few meaningful anchors")
 check(absf(SynkChart.lane_at(turn,6.25)-2)<.1,"Flat hold section remains flat")
 check(SynkChart.lane_at(turn,7.125)>6.7,"Deliberate direction change is preserved")
 check(turn.get("checkpoints",[]).size()==turn.path.size()-2,"Every recorded turn becomes a connector")
 var sharp=SynkCapture.new();sharp.begin(1,0,position(3),"slide")
 for i in 120:
  var t=float(i+1)/120.0
  var base=3.0+4.0*minf(t/.5,1.0) if t<=.5 else 7.0-4.0*minf((t-.5)/.5,1.0)
  sharp.move(1,t,position(base+sin(i*1.9)*.10))
 var zigzag=sharp.end(1,1,position(3))
 check(zigzag.path.size()<=4,"Fast sharp turn uses a few clean SSRG anchors")
 check(zigzag.get("checkpoints",[]).size()==zigzag.path.size()-2,"A sharp reversal's apex becomes a connector")
 check(SynkChart.lane_at(zigzag,.5)>6.6,"Fast reversal keeps its sharp apex")
 var sudden=SynkCapture.snap_path([{"offset":0.0,"lane":3.0},{"offset":.03,"lane":3.0},{"offset":.06,"lane":6.0},{"offset":.09,"lane":3.0},{"offset":.12,"lane":3.0}],.12)
 check(sudden.any(func(point):return absf(float(point.offset)-.06)<.001 and float(point.lane)>5.9),"A quick intentional turn remains pointed")
 var restored=SynkChart.notes_from_file({"version":3,"notes":[zigzag]})
 check(restored is Array and restored.size()==1 and restored[0].get("checkpoints",[])==zigzag.get("checkpoints",[]),"Bend connectors survive chart save/load")
 var shaped=preload("res://scripts/recorder_note_arranger.gd").edit(zigzag,"point",.08,-.5,1,2.0)
 check(absf(float(shaped.checkpoints[0])-float(shaped.path[1].offset))<.002 and float(shaped.path[1].offset)>float(zigzag.path[1].offset),"Stretching a bend moves its connector with it")
 check(float(shaped.path[1].lane)<float(zigzag.path[1].lane),"Dragging a connector bends the trail sideways")
 var arranger=preload("res://scripts/recorder_note_arranger.gd")
 var managed=SynkChart.note(12,2,"slide")
 managed.duration=1.0;managed.end_lane=8
 managed.path=[{"offset":0.0,"lane":2.0},{"offset":.25,"lane":3.5},{"offset":.5,"lane":5.0},{"offset":.75,"lane":7.0},{"offset":1.0,"lane":8.0}]
 managed.checkpoints=[.5,.75]
 var simplified=arranger.smooth_path(managed)
 check(simplified.any(func(point):return is_equal_approx(float(point.offset),.5)) and simplified.any(func(point):return is_equal_approx(float(point.offset),.75)),"Simplifying a slide preserves playable connector anchors")
 arranger.remove_point(managed,2)
 check(managed.path.size()==4 and managed.checkpoints==[.75],"Deleting a selected anchor also removes its matching connector")
 arranger.remove_point(managed,1)
 check(managed.path.size()==3 and managed.checkpoints==[.75],"Deleting a shape anchor keeps other connectors")
 capture.begin(4,10,position(2),"slide");capture.move(4,10.5,position(7));var canceled=capture.end(4,10.6,position(8),true)
 check(canceled.is_empty(),"Cancellation never saves a partial slide")
 # Sliding quickly to a new position and resting there leaves a flat run at that position,
 # with a connector where the finger arrived and where it left, for every step.
 for dense in [false,true]:
  var steps=SynkCapture.new();steps.begin(5,0,position(2),"slide")
  var at=0.0;var from=2.0
  for target in [5.0,8.0,11.0]:
   # A resting finger may send nothing at all (dense=false) or keep reporting small jitter.
   if dense:
    for i in 24:steps.move(5,at+float(i+1)/60,position(from+sin(i*1.7)*.05))
   at+=.4
   for i in 5:steps.move(5,at+.08*float(i+1)/5,position(lerpf(from,target,float(i+1)/5)))
   at+=.08;from=target
  var stairs=steps.end(5,at+.4,position(11))
  check(stairs.path.size()==8 and stairs.get("checkpoints",[]).size()==6,"Each quick step of a slide keeps its rest and connectors (dense=%s, got %d points)" % [dense,stairs.path.size()])
  for step in 4:
   check(absf(SynkChart.lane_at(stairs,step*.48+.2)-(2+step*3))<.01,"The slide lies flat on lane %d while the finger rests there" % (2+step*3))
 print("Recorder clean hold/slide shapes failures: ",failures);quit(failures)
