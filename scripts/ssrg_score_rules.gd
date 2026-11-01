extends RefCounted
# Packaged ScoreData arithmetic, using a neutral CUSTOM card unless explicit
# numeric card points are supplied. No tier-to-stat or server reward inference.
const GRADE_RATE={"MISS":0.0,"GOOD":.5,"GREAT":1.0,"PERFECT":2.0}
const DIFFICULTY=[.800000011920929,.8999999761581421,1.0]
var base=0.0
var score=0.0
var pending_bonus=0.0
var awarded_bonus=0.0
func reset(count:int,keys:int,config:Dictionary={}) -> void:
	var difficulty=0 if keys==4 else (1 if keys==7 else 2)
	var supplied=config.get("card_points",0)
	var points=maxf(0,float(supplied)) if supplied is float or supplied is int else 0.0
	if not is_finite(points):points=0.0
	base=10000.0*(3.0+points)/maxi(1,count)*DIFFICULTY[difficulty]
	score=0;pending_bonus=0;awarded_bonus=0
func add(grade:String,fever_state:int) -> int:
	var rate=float(GRADE_RATE.get(grade,0))
	if rate<=0:return int(score)
	score+=base*rate
	var bonus=[0.0,0.0,.1,.2,.3,.4][clampi(fever_state,0,5)]
	pending_bonus+=base*bonus
	return int(score)
func settle() -> int:
	awarded_bonus=pending_bonus;score+=pending_bonus;pending_bonus=0
	return int(score)
