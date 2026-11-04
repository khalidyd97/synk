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
  check(slide.lane==2 and slide.end_lane==8 and is_equal_approx(slide.duration,2),"Endpoints and timing stay accurate")
  check(absf(SynkChart.lane_at(slide,2)-5)<.01,"Diagonal is straight, without lane steps")
  var loaded=SynkChart.notes_from_file({"version":3,"notes":[slide]})
  check(loaded is Array and loaded[0].get("ssrg_path",false),"Clean geometry survives save/load")
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
 check(turn.checkpoints.size()<=1,"Complex slide adds at most its real reversal as a connector")
 var sharp=SynkCapture.new();sharp.begin(1,0,position(3),"slide")
 for i in 120:
  var t=float(i+1)/120.0
  var base=3.0+4.0*minf(t/.5,1.0) if t<=.5 else 7.0-4.0*minf((t-.5)/.5,1.0)
  sharp.move(1,t,position(base+sin(i*1.9)*.10))
 var zigzag=sharp.end(1,1,position(3))
 check(zigzag.path.size()<=4,"Fast sharp turn uses a few clean SSRG anchors")
 check(zigzag.checkpoints.size()==1,"Sharp reversal has one authored continuation node")
 check(SynkChart.lane_at(zigzag,.5)>6.6,"Fast reversal keeps its sharp apex")
 check(SynkCapture.slide_checkpoints([{"offset":0.0,"lane":2.0},{"offset":.2,"lane":3.0},{"offset":.5,"lane":5.0},{"offset":1.0,"lane":7.0}]).is_empty(),"Straight ramp has no extra connector heads")
 var restored=SynkChart.notes_from_file({"version":3,"notes":[zigzag]})
 check(restored is Array and restored.size()==1 and restored[0].checkpoints==zigzag.checkpoints,"Sharp connector nodes survive chart save/load")
 var shaped=preload("res://scripts/recorder_note_arranger.gd").edit(zigzag,"point",.08,-.5,1,2.0)
 check(shaped.checkpoints.size()==1 and absf(float(shaped.checkpoints[0])-float(shaped.path[1].offset))<.001,"Stretching a connector moves its gameplay timing with the trail handle")
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
 print("Recorder clean hold/slide shapes failures: ",failures);quit(failures)
