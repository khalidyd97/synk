extends RefCounted
# Serialized level10 UINumber/UISprite values; see docs/SSRG_HUD_SOURCE_AUDIT.md.
const SUPER = [
	preload("res://assets/ssrg/imported/hud/combo/super_0.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_1.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_2.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_3.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_4.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_5.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_6.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_7.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_8.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_9.png"),
]
const PERFECT = [
	preload("res://assets/ssrg/imported/hud/combo/perfect_0.png"),
	preload("res://assets/ssrg/imported/hud/combo/perfect_1.png"),
	preload("res://assets/ssrg/imported/hud/combo/perfect_2.png"),
	preload("res://assets/ssrg/imported/hud/combo/perfect_3.png"),
	preload("res://assets/ssrg/imported/hud/combo/perfect_4.png"),
	preload("res://assets/ssrg/imported/hud/combo/perfect_5.png"),
	preload("res://assets/ssrg/imported/hud/combo/perfect_6.png"),
	preload("res://assets/ssrg/imported/hud/combo/perfect_7.png"),
	preload("res://assets/ssrg/imported/hud/combo/perfect_8.png"),
	preload("res://assets/ssrg/imported/hud/combo/perfect_9.png"),
]
const GOOD = [
	preload("res://assets/ssrg/imported/hud/combo/good_0.png"),
	preload("res://assets/ssrg/imported/hud/combo/good_1.png"),
	preload("res://assets/ssrg/imported/hud/combo/good_2.png"),
	preload("res://assets/ssrg/imported/hud/combo/good_3.png"),
	preload("res://assets/ssrg/imported/hud/combo/good_4.png"),
	preload("res://assets/ssrg/imported/hud/combo/good_5.png"),
	preload("res://assets/ssrg/imported/hud/combo/good_6.png"),
	preload("res://assets/ssrg/imported/hud/combo/good_7.png"),
	preload("res://assets/ssrg/imported/hud/combo/good_8.png"),
	preload("res://assets/ssrg/imported/hud/combo/good_9.png"),
]
const SUPER_BACK = [
	preload("res://assets/ssrg/imported/hud/combo/super_back_0.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_back_1.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_back_2.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_back_3.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_back_4.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_back_5.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_back_6.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_back_7.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_back_8.png"),
	preload("res://assets/ssrg/imported/hud/combo/super_back_9.png"),
]
const SCORE_COMMA=preload("res://assets/ssrg/imported/hud/UI_score_com.png")
const SCORE_RIGHT_EDGES=[249.0,229.0,209.0,179.0,159.0,139.0,109.0]
const COMBO_SIZE=Vector2(56,90)
const COMBO_Y=3.0
const SUPER_TINT=Color(.9245283007621765,.9245283007621765,.9245283007621765,1)
const SUPER_BACK_TINT=Color(.3607843220233917,.3607843220233917,.3607843220233917,.3607843220233917)
const RAVE_MULTIPLIERS={
	2:preload("res://assets/ssrg/imported/hud/rave_bonus_x2.png"),
	3:preload("res://assets/ssrg/imported/hud/rave_bonus_x3.png"),
	4:preload("res://assets/ssrg/imported/hud/rave_bonus_x4.png"),
}
const RAVE_DIGIT_CENTERS=[135.0,117.0,99.0,76.0,58.0,40.0,14.0]
