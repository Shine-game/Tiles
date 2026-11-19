extends Node
# One shared loop represents any number of surviving tier-three structures.
var player:=AudioStreamPlayer.new()
var starts:Array=[]
var source:AudioStream
func _ready():add_child(player)
func configure(stream:AudioStream,gain:float,bus:String):
 player.bus=bus
 player.volume_db=gain
 if source==stream:return
 source=stream
 var loop:AudioStream=stream.duplicate()
 if loop is AudioStreamWAV:
  loop.loop_mode=AudioStreamWAV.LOOP_FORWARD
  loop.loop_begin=0
  loop.loop_end=roundi(loop.get_length()*loop.mix_rate)
 elif loop is AudioStreamOggVorbis or loop is AudioStreamMP3:loop.loop=true
 player.stream=loop
func reconcile(records:Array,clock:float,settled:bool=false):
 starts.clear()
 for record in records:starts.append(-100.0 if settled or record.get("old",false) else float(record.start))
 advance(clock)
func advance(clock:float):
 if not is_inside_tree() or get_tree().paused:return
 var audible:=false
 for start in starts:
  if clock>=start:audible=true
 if audible:
  if not player.playing:player.play()
 else:player.stop()
func clear():
 starts.clear()
 player.stop()
func _exit_tree():
 player.stop()
 player.stream=null
