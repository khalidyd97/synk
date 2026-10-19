class_name SynkGameplayColors
extends RefCounted

# Empty entries inherit the theme. Adaptive mode keeps all per-element overrides dormant.
const GROUPS = {
    "Notes & trails":{"tap":"Tap notes","hold":"Hold notes","slide":"Slide notes","flick":"Flick notes","hold_trail":"Hold trails","slide_trail":"Slide trails","arrows":"Flick arrows"},
    "Highway & atmosphere":{"rail":"Rails","band":"Judgment band","track":"Highway surface","glow":"Rail glow","particles":"Ambient particles","lasers":"Laser streaks"},
    "Hit feedback":{"hits":"Hit bursts","sparks":"Hit sparks","beams":"Touch beams"},
    "Gameplay HUD":{"combo":"Combo counter","judgment":"Judgment text","score":"Score","energy":"Energy gauge","hud":"Song details & labels","countdown":"Countdown"}
}

static func valid_key(key: String) -> bool:
    for group in GROUPS.values():
        if group.has(key): return true
    return false

static func resolve(game: Control,key: String,fallback: Color) -> Color:
    if game.highway_colors=="adaptive" or game.uses_recorder_colors(): return fallback
    var code=str(game.gameplay_colors.get(key,""))
    return Color.from_string(code,fallback) if Color.html_is_valid(code) else fallback

static func preview_default(game: Control,key: String) -> Color:
    var notes=SynkCoverPalette.DEFAULT
    var defaults={"tap":notes[0],"hold":notes[1],"slide":notes[1],"flick":notes[2],"hold_trail":notes[1],"slide_trail":notes[1],"arrows":notes[2],"hits":notes[0],"sparks":notes[0],"beams":notes[0],"particles":notes[1],"lasers":notes[0],"track":Color("050409"),"combo":notes[1],"judgment":Color("eee9ff"),"score":Color("f4f6ff"),"energy":Color("4ff07c"),"hud":Color("eee9ff"),"countdown":notes[0]}
    if key=="rail" or key=="glow":
        var rail=str(game.gameplay_colors.get("rail",game.rail_color)) if key=="glow" else str(game.rail_color)
        return Color.from_string(rail,Color("fff3dc")) if rail!="" else Color("fff3dc")
    if key=="band": return Color.from_string(game.band_color,Color("ffd257")) if game.band_color!="" else (Color("ffd257") if game.highway_style=="gold" else Color("995cff"))
    return defaults.get(key,Color.WHITE)
