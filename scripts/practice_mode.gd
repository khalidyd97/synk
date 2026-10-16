extends Node
var game: Control
var active=false
var repeat_enabled=true
var speed=.75
var start=0.0
var end=8.0
var round_number=0
var source: Array=[]
func launch(notes: Array,a: float,b: float,rate: float,repeat: bool) -> bool:
    if not is_finite(a) or not is_finite(b) or a<0 or b>game.length()+.001 or b-a<.5 or rate<.25 or rate>1:
        game.tell("Choose a practice range of at least 0.5 seconds within the song."); return false
    source=notes.filter(func(n): return float(n.time)>=a and float(n.time)<b).duplicate(true)
    if source.is_empty(): game.tell("This practice range has no notes."); return false
    start=a; end=b; speed=rate; repeat_enabled=repeat; round_number=0
    for n in source: end=maxf(end,minf(game.length(),float(n.time)+float(n.duration)+.2))
    restart(); return true
func restart() -> void:
    round_number+=1
    game.start_game(source,false,"full",true)
    game.start_position=maxf(0,start-1); game.song_time=game.start_position-3
    game.play_range=Vector2(start,end); game.play_finish_time=end
    game.audio.pitch_scale=speed; game.stage_intro.skip()
func finish_round() -> bool:
    if not active or not repeat_enabled: return false
    restart(); return true
