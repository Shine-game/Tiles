extends SceneTree
const Audio=preload("res://scripts/growth_audio.gd")
const Board=preload("res://scripts/board_view.gd")
const Rules=preload("res://scripts/rules.gd")
const Palette=preload("res://scripts/palette.gd")
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 assert(ok,label)
func _initialize():run.call_deferred()
func run():
 var sound=Audio.new()
 sound.settings_path="/tmp/tier3-loop-test.cfg"
 root.add_child(sound)
 var view=Board.new()
 root.add_child(view)
 view.size=Vector2(600,600)
 sound.attach_board(view)
 view.growth_canceled.connect(sound.cancel)
 view.growth_finished.connect(sound.finish)
 for theme in ["clockwork","coral_reef"]:
  Palette.select_theme(theme)
  var empty=Rules.empty_board(7)
  var board=empty.duplicate(true)
  for y in range(2,4):
   for x in range(2,6):board[y][x]=1
  view.show_settled(empty)
  var loop=sound.soundscape.structure_loop if theme=="clockwork" else sound.reef.structure_loop
  check(not loop.player.playing,"No structure means no tier-three loop")
  view.animate_growth(empty,board)
  view.set_process(false)
  check(not loop.player.playing,"Wait for tier three to appear")
  view.advance_growth(view.pattern.duration+1)
  check(loop.player.playing,"Tier-three audio continues after construction")
  check(not view.growing,"Loop does not hold placement gate")
  var stream=loop.player.stream
  check(stream.loop if stream is AudioStreamOggVorbis else stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Tier three is looped")
  check(loop.player.bus==(sound.effects_bus if theme=="clockwork" else sound.reef.bus_name),"Uses effects routing")
  var playback=loop.player.get_stream_playback()
  view.show_settled(board,true)
  check(loop.player.playing and loop.player.get_stream_playback()==playback,"Settled redraw keeps same playback")
  var smaller=board.duplicate(true)
  smaller[2][5]=0
  smaller[3][5]=0
  view.show_settled(smaller,true)
  check(loop.player.playing,"Removing some structures preserves remaining loop")
  sound.set_effects_enabled(false)
  check(AudioServer.is_bus_mute(AudioServer.get_bus_index(sound.effects_bus)),"Effects toggle controls tier-three loop")
  sound.set_effects_enabled(true)
  view.show_settled(empty,true)
  check(not loop.player.playing,"Removing last structure stops loop")
  view.show_settled(board)
  check(loop.player.playing,"Restored structures restart continuous sound")
 Palette.select_theme("vines")
 view.show_settled(Rules.empty_board(7))
 check(not sound.soundscape.structure_loop.player.playing and not sound.reef.structure_loop.player.playing,"Theme switch stops both old loops")
 sound.soundscape.deactivate()
 sound.reef.deactivate()
 await create_timer(0.7).timeout
 view.queue_free()
 sound.queue_free()
 await create_timer(0.15).timeout
 print("Tier-three sound persistence: %d checks pass"%checks)
 quit()
