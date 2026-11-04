extends RefCounted
# Optional display metadata for recognized folder names; never creates list entries.
const GAMES=[
 {"id":"SSSM","name":"SuperStar SMTOWN","badge":"SM","color":"ff83b2","aliases":["SMTOWN","SSM","SM"]},
 {"id":"SSJYP","name":"SuperStar JYPNATION","badge":"JYP","color":"55cfff","aliases":["JYP","JYPNATION"]},
 {"id":"SSYG","name":"SuperStar YG","badge":"YG","color":"fafafa","aliases":["YG"]},
 {"id":"SSSTAYC","name":"SuperStar STAYC","badge":"STAYC","color":"e69aff","aliases":["STAYC","SSSC"]},
 {"id":"SSPLEDIS","name":"SuperStar PLEDIS","badge":"P","color":"9ecaff","aliases":["PLEDIS","SSP"]},
 {"id":"SSSTARSHIP","name":"SuperStar STARSHIP","badge":"STAR","color":"97e3de","aliases":["STARSHIP","SSS"]},
 {"id":"SSWOOLLIM","name":"SuperStar WOOLLIM","badge":"W","color":"f8d15d","aliases":["WOOLLIM","SSW"]},
 {"id":"SSFNC","name":"SuperStar FNC","badge":"FNC","color":"91baff","aliases":["FNC"]},
 {"id":"SSATEEZ","name":"SuperStar ATEEZ","badge":"ATZ","color":"ffb267","aliases":["ATEEZ","SSA"]},
 {"id":"SSTHEBOYZ","name":"SuperStar THE BOYZ","badge":"TBZ","color":"ff767e","aliases":["THEBOYZ","SSTB"]}
]
static func compact(value:String)->String:
 return value.to_upper().replace(" ","").replace("_","").replace("-","")
static func normalize(value:String)->String:
 var key=compact(value)
 if key.is_empty() or key in ["SSRG","IMPORTED"]:return "IMPORTED"
 for entry in GAMES:
  if key==entry.id or key==compact(entry.name):return entry.id
  for alias in entry.aliases:
   if key==compact(alias):return entry.id
 return value.strip_edges().to_upper().left(80)
static func category(song:Dictionary)->String:
 return normalize(str(song.get("ssrg_game",song.get("album","IMPORTED"))))
static func entries(game:Control)->Array:
 var result=[];var names={}
 for entry in result:names[entry.id]=true
 var custom=game.prefs.get_value("ssrg_games","custom",[])
 if custom is Array:
  for name in custom:
   var id=normalize(str(name))
   if not names.has(id):result.append({"id":id,"name":str(name),"badge":str(name).left(3).to_upper(),"color":"b9a1ff"});names[id]=true
 for song in game.library.songs:
  if not song.has("ssrg"):continue
  var id=category(song)
  if not names.has(id):result.append({"id":id,"name":display_name(id),"badge":"♫" if id=="IMPORTED" else id.left(3),"color":"b9a1ff"});names[id]=true
 for entry in result:
  for known in GAMES:
   if known.id==entry.id:entry.badge=known.badge;entry.color=known.color;break
  entry.count=game.library.songs.filter(func(song):return song.has("ssrg") and category(song)==entry.id).size()
 return result
static func display_name(id:String)->String:
 for entry in GAMES:
  if entry.id==normalize(id):return entry.name
 return "Imported songs" if id=="IMPORTED" else id
static func icon_path(id:String)->String:return "user://ssrg_games/"+normalize(id).sha256_text()+".png"
