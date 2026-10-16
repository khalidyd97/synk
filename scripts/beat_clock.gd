extends Node
var game: Control
var enabled=false
var last_beat=-999999
var last_time=-1.0
var ticks_emitted=0
var players: Array=[]
var clicks: Array=[]
var subdivision=1
var guide_db=-7.0
func _ready() -> void:
    enabled=bool(game.prefs.get_value("editor","metronome",false))
    subdivision=clampi(int(game.prefs.get_value("recorder","guide_subdivision",1)),1,4)
    guide_db=clampf(float(game.prefs.get_value("recorder","guide_db",-7)),-30,0)
    for hz in [1800,1000]:
        var data=PackedByteArray(); data.resize(1324)
        for i in 662:
            var t=float(i)/22050; data.encode_s16(i*2,roundi(sin(TAU*hz*t)*exp(-t*180)*9000))
        var stream=AudioStreamWAV.new(); stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate=22050; stream.data=data; clicks.append(stream)
    for i in 2:
        var player=AudioStreamPlayer.new(); add_child(player); player.volume_db=-7; players.append(player)
func toggle() -> void:
    enabled=not enabled; last_time=-1
    game.prefs.set_value("editor","metronome",enabled); game.prefs.save("user://preferences.cfg")
func set_offset(value: float) -> void:
    game.features.set_chart_value("beat_offset",clampf(value,0,game.length())); last_time=-1
    game.refresh_editor()
func beat_index(at: float) -> int:
    return floori((at-game.chart_offset())*game.chart_bpm()/60.0+.00001)
func _process(_delta: float) -> void:
    var active=enabled and game.audio.playing and not game.audio.stream_paused and (game.mode=="editor" or (game.mode=="record" and game.countdown==0 and game.resume_countdown==0 and not game.arranging))
    if not active: last_time=-1; return
    var at=game.chart_time(); var beat=floori((at-game.chart_offset())*game.chart_bpm()/60.0*subdivision+.00001)
    if last_time>=0 and at>=last_time and at-last_time<.25 and beat!=last_beat:
        var voice=players[ticks_emitted%2]; voice.volume_db=guide_db+(-4 if posmod(beat,subdivision)!=0 else 0)
        voice.stream=clicks[0 if posmod(beat,4*subdivision)==0 else 1]; voice.play(); ticks_emitted+=1
    last_time=at; last_beat=beat
