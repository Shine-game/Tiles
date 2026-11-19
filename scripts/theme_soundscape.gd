extends Node
const Themes=preload("res://scripts/pattern/theme_registry.gd")
var ambience:=AudioStreamPlayer.new()
var voices:Dictionary={}
var theme:=""
var config:Dictionary={}
var pending:Array=[]
var played:Dictionary={}
var placement:=-1
var background_bus:="Master"
var effects_bus:="Master"
var event_log:Array=[]
func _ready():
 add_child(ambience)
 for tier in [1,2,3]:
  var voice=AudioStreamPlayer.new()
  add_child(voice)
  voices[tier]=voice
func route(background:String,effects:String):
 background_bus=background
 effects_bus=effects
 ambience.bus=background
 for voice in voices.values():voice.bus=effects
func cancel_effects():
 pending.clear()
 for voice in voices.values():voice.stop()
func deactivate():
 cancel_effects()
 ambience.stop()
 theme=""
 played.clear()
func activate(next:String):
 if theme==next:return
 deactivate()
 theme=next
 config=Themes.profile(theme).soundscape
 var stream:AudioStreamWAV=load(config.ambience.path).duplicate()
 stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
 stream.loop_begin=0
 stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
 ambience.stream=stream
 ambience.volume_db=config.ambience.gain_db
 ambience.play()
 for tier in [1,2,3]:
  voices[tier].stream=load(config.tiers[str(tier)].path)
  voices[tier].volume_db=config.tiers[str(tier)].gain_db
static func plan(model,settings:Dictionary)->Array:
 var cues:Array=[]
 if settings.get("tier1_component_ids",[]).is_empty():
  for cell in model.arrivals:
   var at:float=model.arrivals[cell]
   if at>=0:cues.append({"id":"cell/"+str(cell),"tier":1,"time":at})
 else:
  for record in model.components.values():
   if not record.old and record.id in settings.tier1_component_ids:cues.append({"id":record.key,"tier":1,"time":record.start})
 for record in model.tier2_records().values():
  if not record.old:cues.append({"id":"formation/"+str(record.origin),"tier":2,"time":record.start})
 var connections:Variant=model.get("chains")
 if connections is Dictionary:connections=connections.values()
 else:connections=model.links
 for record in connections:
  if not record.old:cues.append({"id":"connection/"+str(record.a)+"/"+str(record.b),"tier":3,"time":record.start})
 cues.sort_custom(func(a,b):return a.time<b.time if a.time!=b.time else a.id<b.id)
 var result:Array=[]
 var last:Dictionary={}
 for cue in cues:
  if cue.time-float(last.get(cue.tier,-1000))<float(settings.tiers[str(cue.tier)].coalesce_seconds):continue
  last[cue.tier]=cue.time
  result.append(cue)
 return result
func reconcile(model,next:String,animating:bool,clock:float,placement_id:int):
 activate(next)
 if placement_id!=placement:
  placement=placement_id
  played.clear()
 pending.clear()
 if not animating or model.get("dismantling")==true:return
 for cue in plan(model,config):
  if not played.has(cue.id) and cue.time>=clock-0.001:pending.append(cue)
 advance(clock)
func advance(clock:float):
 if not is_inside_tree() or get_tree().paused:return
 while not pending.is_empty() and pending[0].time<=clock:
  var cue:Dictionary=pending.pop_front()
  if played.has(cue.id):continue
  played[cue.id]=true
  var voice:AudioStreamPlayer=voices[cue.tier]
  # Let each one-shot finish; separate tiers can overlap without restarting it.
  if voice.playing:continue
  voice.play()
  event_log.append({"tier":cue.tier,"scheduled":cue.time,"clock":clock,"placement":placement})
  if event_log.size()>256:event_log.pop_front()

func _exit_tree():
 ambience.stop()
 ambience.stream=null
 for voice in voices.values():
  voice.stop()
  voice.stream=null
