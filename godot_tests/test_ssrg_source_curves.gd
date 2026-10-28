extends SceneTree
const CURVES=preload("res://scripts/ssrg_runtime_curves.gd")
class FakeGame extends Control:
	var combo=0
	var judged=0
	var judgement="PERFECT"
	var mode="play"
	var countdown=0.0
	var finishing=false
	var hit_label: Label
	func uses_ssrg_gameplay() -> bool: return true
func _initialize() -> void:
	assert(is_equal_approx(CURVES.beam_alpha(0),1.0))
	assert(is_equal_approx(CURVES.beam_alpha(.05),.5))
	assert(is_zero_approx(CURVES.beam_alpha(.1)))
	assert(CURVES.word_alpha(.999,true)==1.0)
	assert(CURVES.word_alpha(1.0,true)==0.0)
	assert(CURVES.word_alpha(1.1,true)==0.0)
	assert(CURVES.word_alpha(.499)>0)
	assert(CURVES.word_alpha(.5)==0.0)
	assert(CURVES.judgement_alpha(.5)==0.0)
	assert(CURVES.combo_visible(.499,15))
	assert(not CURVES.combo_visible(.5,15))
	assert(not CURVES.combo_visible(0,0))
	assert(CURVES.judgement_scale(0).is_equal_approx(Vector2(1.6,1.6)))
	assert(CURVES.judgement_scale(1.0/12.0).is_equal_approx(Vector2.ONE))
	assert(CURVES.judgement_scale(7.0/60.0).is_equal_approx(Vector2(.7,.7)))
	assert(CURVES.judgement_scale(.15).is_equal_approx(Vector2.ONE))
	assert(CURVES.judgement_scale(0,true).is_equal_approx(Vector2(2.4,.2)))
	assert(CURVES.judgement_offset(1.0,true).is_equal_approx(Vector2(0,10)))
	assert(is_equal_approx(float(CURVES.sample("JudgementGood","float","trans/sprite","Color.a",0)),.2))
	assert(is_equal_approx(float(CURVES.sample("JudgementGood","float","trans/sprite","Color.a",.05)),1.0))
	assert(CURVES.sample_keys([[0,1,0,0],[1,0,0,0]],.5)==.5)
	assert(CURVES.sample_keys([[0,1,"step","step"],[1,0,"step","step"]],.5)==1)
	assert(CURVES.sample_keys([[0,1,"step","step"],[1,0,"step","step"]],1.0)==0)
	var hud=preload("res://scripts/ssrg_judgement.gd").new()
	assert(hud.grade_art("PERFECT").resource_path.ends_with("Text_perpect_super.png"))
	assert(hud.grade_art("GREAT").get_size()==Vector2(272,54))
	assert(hud.grade_art("GOOD").get_size()==Vector2(180,54))
	assert(hud.grade_art("MISS").get_size()==Vector2(146,54))
	# Exercise the display's lifetime clock, including pause, retrigger and a new entrance.
	var fake=FakeGame.new()
	hud.game=fake
	hud._ready()
	fake.combo=1; fake.judged=1
	hud._process(.1)
	assert(is_equal_approx(hud.since_hit,.1))
	assert(hud.word.modulate.a>0)
	fake.mode="paused"
	hud._process(2.0)
	assert(is_equal_approx(hud.since_hit,.1))
	fake.mode="play"
	hud._process(.4)
	assert(is_zero_approx(hud.word.modulate.a))
	fake.combo=2; fake.judged=2
	hud._process(.01)
	assert(hud.word.modulate.a>0)
	assert(hud.since_hit<.02)
	fake.combo=0; fake.judged=3; fake.judgement="MISS"
	hud._process(.5)
	assert(hud.word.modulate.a==1.0)
	hud._process(.5)
	assert(hud.word.modulate.a==0.0)
	fake.countdown=2.0
	hud._process(.01)
	assert(hud.since_hit>1.0 and hud.displayed_grade.is_empty())
	hud.free()
	fake.free()
	print("SSRG source animation curve checks passed")
	quit()
