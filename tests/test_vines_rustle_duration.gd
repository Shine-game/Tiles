extends SceneTree
const Board=preload("res://scripts/board_view.gd")
const Audio=preload("res://scripts/growth_audio.gd")
const Palette=preload("res://scripts/palette.gd")
const Rules=preload("res://scripts/rules.gd")
const Sound=preload("res://scripts/theme_soundscape.gd")
func _initialize():run.call_deferred()
func run():
 Palette.select_theme("vines")
 var view=Board.new()
 root.add_child(view)
 view.size=Vector2(600,600)
 var audio=Audio.new()
 audio.settings_path="/tmp/rustle-test-settings.cfg"
 root.add_child(audio)
 audio.attach_board(view)
 view.growth_canceled.connect(audio.cancel)
 view.growth_finished.connect(audio.finish)
 for length in [1,2,4]:
  var before=Rules.empty_board(9)
  before[4][2]=1
  var after=before.duplicate(true)
  for i in range(1,length+1):after[4][2+i]=1
  view.animate_growth(before,after)
  view.set_process(false)
  var end=Sound.tier1_end(view.pattern)
  assert(end>0)
  var plan=Sound.plan(view.pattern,audio.soundscape.config)
  var cue=plan.filter(func(c):return c.tier==1)[0]
  assert(cue.stop_at==end)
  view.advance_growth(cue.time+0.001)
  var voice=audio.soundscape.voices[1]
  assert(voice.playing)
  view.advance_growth(maxf(0,end-0.02-view.clock))
  assert(voice.volume_db<audio.soundscape.config.tiers["1"].gain_db)
  view.advance_growth(end-view.clock+0.001)
  assert(not voice.playing)
  if length==1:assert(end<voice.stream.get_length())
 # A later bloom/butterfly stage must not prolong the tier-one rustle.
 var empty=Rules.empty_board(7)
 var block=empty.duplicate(true)
 for y in range(2,4):
  for x in range(2,5):block[y][x]=1
 view.animate_growth(empty,block)
 view.set_process(false)
 var end=Sound.tier1_end(view.pattern)
 view.advance_growth(end+0.001)
 assert(not audio.soundscape.voices[1].playing)
 assert(audio.soundscape.ambience.playing)
 audio.soundscape.deactivate()
 view.queue_free()
 audio.queue_free()
 await create_timer(0.15).timeout
 print("Vines rustle duration: short/medium/long growth, fade-out, exact stop and independent later tiers pass")
 quit()
