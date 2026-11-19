extends SceneTree
const Model=preload("res://scripts/coral_growth.gd")
const Plan=preload("res://scripts/coral_audio_plan.gd")
const Audio=preload("res://scripts/coral_audio.gd")
const Rules=preload("res://scripts/rules.gd")
const Themes=preload("res://scripts/pattern/theme_registry.gd")
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 assert(ok,label)
func _initialize():run.call_deferred()
func run():
 check(Themes.profile("coral_reef").audio.events.anemone.assets==["bubble_long_02"],"Only long bubble two")
 var audio=Audio.new()
 root.add_child(audio)
 for color in [1,2]:
  var empty=Rules.empty_board(7)
  var board=empty.duplicate(true)
  for y in range(2,4):
   for x in range(2,4):board[y][x]=color
  var model=Model.new()
  model.build(empty,board)
  for placement in range(20):
   var plan=Plan.build(model,placement)
   var cue:Dictionary=plan.cues[0]
   check(cue.bubbles.size() in [5,6],"Five or six shots")
   var previous=""
   var last=-INF
   for bubble in cue.bubbles:
    check(bubble.asset.begins_with("bubble_short_"),"Short variants only")
    check(bubble.asset!=previous,"Avoid consecutive same clip")
    check(bubble.time>=last and bubble.time>=cue.time and bubble.time<cue.end,"Stagger inside animation window")
    previous=bubble.asset
    last=bubble.time
  audio.invalidate()
  audio.event_log.clear()
  audio.reconcile(model,true,false,0,51+color)
  var cue=Plan.build(model,51+color).cues[0]
  for bubble in cue.bubbles:audio.advance(bubble.time+0.00001)
  check(audio.event_log.filter(func(e):return e.kind=="colony_bubble").size()==cue.bubbles.size(),"All scheduled shots play on visual clock")
  var voice=audio.features.filter(func(v):return v.kind=="colony" and v.player.playing)[0]
  check(voice.player.stream is AudioStreamPolyphonic,"Overlapping short clips mix instead of restarting")
  audio.advance(cue.end)
  check(voice.bubbles.is_empty() and voice.burst_finished,"Animation end stops burst")
  await create_timer(0.1).timeout
 audio.deactivate()
 await create_timer(0.7).timeout
 audio.queue_free()
 await create_timer(0.1).timeout
 print("Coral bubble bursts: %d checks pass"%checks)
 quit()
