extends RefCounted
static func inspect(notes: Array,stream: AudioStream) -> String:
    if not SynkChart.valid(notes): return "This chart has invalid note or slide data. Open Chart Studio to check it."
    if stream==null or not is_finite(stream.get_length()) or stream.get_length()<=0: return "This song's audio is missing or could not be opened."
    var length=stream.get_length()
    for i in notes.size():
        if float(notes[i].time)+float(notes[i].duration)>length+.001:
            return "Note %d extends beyond the audio. Correct it in Chart Studio before playing." % (i+1)
    for path in ["res://assets/neon/Tap_Note_Blue.png","res://assets/neon/Tap_Note_Pink.png","res://assets/neon/Hit_Effect_Blue.png","res://assets/neon/Hit_Effect_Pink.png","res://scripts/flick_arrow.gdshader","res://scripts/circle_note.gdshader"]:
        if not ResourceLoader.exists(path): return "A required gameplay asset is missing. Please rebuild or update the game."
    return ""
