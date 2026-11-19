extends SceneTree
const Sound=preload("res://scripts/theme_soundscape.gd")
const Themes=preload("res://scripts/pattern/theme_registry.gd")
const Model=preload("res://scripts/vines_growth.gd")
const Rules=preload("res://scripts/rules.gd")
const Palette=preload("res://scripts/palette.gd")
func _initialize():run.call_deferred()
func run():
 var config:Dictionary=Themes.profile("vines").soundscape
 var bloom={"id":"b","tier":2,"time":1.0,"members":["a"]}
 var butterfly={"id":"f","tier":3,"time":1.25,"members":["a","b"]}
 var merged=Sound.combine([bloom,butterfly],config)
 assert(merged.size()==1 and merged[0].tier==23 and merged[0].time==1.0)
 butterfly.time=2.0
 assert(Sound.combine([bloom,butterfly],config).size()==2)
 butterfly.time=1.25
 butterfly.members=["c","d"]
 assert(Sound.combine([bloom,butterfly],config).size()==2)
 Palette.select_theme("vines")
 var empty=Rules.empty_board(7)
 var board=empty.duplicate(true)
 for y in range(2,4):
  for x in range(2,5):board[y][x]=1
 var model=Model.new()
 model.build(empty,board)
 var plan=Sound.plan(model,config)
 var combo=false
 for cue in plan:
  if cue.tier==23:
   combo=true
   assert(is_equal_approx(cue.time+config.combined.tier3_offset_seconds,model.links[0].start))
 assert(combo)
 for key in ["1","2","3"]:
  var stream=load(config.tiers[key].path)
  assert(stream!=null and stream.get_length()>0)
 print("Combined audio: matching timings merge once, incompatible timings stay separate; actual butterfly onset matches visual tier three")
 quit()
