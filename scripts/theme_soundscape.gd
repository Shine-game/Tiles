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
var active_stops:Dictionary={}
func _ready():
 add_child(ambience)
 for tier in [1,2,3,23]:
  var voice=AudioStreamPlayer.new()
  add_child(voice)
  voices[tier]=voice
func route(background:String,effects:String):
 background_bus=background
 effects_bus=effects
 ambience.bus=background
 for voice in voices.values():voice.bus=effects
func cancel_effects():
 active_stops.clear()
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
 var stream:AudioStream=load(config.ambience.path).duplicate()
 if stream is AudioStreamWAV:
  stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
  stream.loop_begin=0
  stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
 elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
  stream.loop=true
 ambience.stream=stream
 ambience.volume_db=config.ambience.gain_db
 ambience.play()
 for tier in [1,2,3,23]:
  var clip:Dictionary=config.get("combined",{}) if tier==23 else config.tiers[str(tier)]
  voices[tier].stream=load(clip.path) if clip.has("path") else null
  voices[tier].volume_db=clip.get("gain_db",0.0)
static func tier1_end(model)->float:
 var end:=0.0
 for event in model.sprite_growth_events.values():
  if not event.old:end=maxf(end,float(event.end))
 for edge in model.edges:
  if not edge.old:end=maxf(end,float(edge.finish))
 for at in model.arrivals.values():
  if at>=0:end=maxf(end,float(at))
 return end
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
  if not record.old:cues.append({"id":"formation/"+str(record.origin),"tier":2,"time":record.start,"members":[str(record.origin)]})
 var connections:Variant=model.get("chains")
 if connections is Dictionary:connections=connections.values()
 else:connections=model.links
 for record in connections:
  if not record.old:
   var offset:Array=settings.get("connection_origin_offset",[0,0])
   var delta:=Vector2i(offset[0],offset[1])
   cues.append({"id":"connection/"+str(record.a)+"/"+str(record.b),"tier":3,"time":record.start,"members":[str(record.a-delta),str(record.b-delta)]})
 var growth_end:=tier1_end(model) if settings.tiers["1"].get("stop_at_tier_end",false) else INF
 for cue in cues:
  if cue.tier==1 and growth_end!=INF:cue.stop_at=growth_end
  cue.time+=float(settings.tiers[str(cue.tier)].get("offset_seconds",0.0))
  cue.seek_seconds=float(settings.tiers[str(cue.tier)].get("seek_seconds",0.0))
 cues.sort_custom(func(a,b):return a.time<b.time if a.time!=b.time else a.id<b.id)
 var result:Array=[]
 var last:Dictionary={}
 for cue in cues:
  if cue.time-float(last.get(cue.tier,-1000))<float(settings.tiers[str(cue.tier)].coalesce_seconds):continue
  last[cue.tier]=cue.time
  result.append(cue)
 return combine(result,settings)
static func combine(cues:Array,settings:Dictionary)->Array:
 var combined:Dictionary=settings.get("combined",{})
 if combined.is_empty():return cues
 var removed:Dictionary={}
 var replacements:Array=[]
 for third in cues:
  if third.tier!=3:continue
  for bloom in cues:
   if bloom.tier!=2 or removed.has(bloom.id):continue
   var shares:=false
   for member in third.get("members",[]):
    if member in bloom.get("members",[]):shares=true
   if not shares or absf((third.time-bloom.time)-float(combined.tier3_offset_seconds))>float(combined.get("tolerance_seconds",0.05)):continue
   removed[bloom.id]=true
   removed[third.id]=true
   replacements.append({"id":"combined/"+bloom.id+"/"+third.id,"tier":23,"time":bloom.time+float(combined.get("offset_seconds",0.0)),"seek_seconds":float(combined.get("seek_seconds",0.0))})
   break
 var result:Array=[]
 for cue in cues:
  if not removed.has(cue.id):result.append(cue)
 result.append_array(replacements)
 result.sort_custom(func(a,b):return a.time<b.time)
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
 _apply_stops(clock)
 while not pending.is_empty() and pending[0].time<=clock:
  var cue:Dictionary=pending.pop_front()
  if played.has(cue.id):continue
  played[cue.id]=true
  var voice:AudioStreamPlayer=voices[cue.tier]
  # Let each one-shot finish; separate tiers can overlap without restarting it.
  if voice.playing:continue
  if cue.has("stop_at") and clock>=float(cue.stop_at):continue
  var clip:Dictionary=config.combined if cue.tier==23 else config.tiers[str(cue.tier)]
  voice.volume_db=clip.gain_db
  voice.play(float(cue.get("seek_seconds",0.0)))
  if cue.has("stop_at"):
   active_stops[cue.tier]={"end":cue.stop_at,"gain_db":clip.gain_db,"fade":clip.get("fade_out_seconds",0.04)}
  event_log.append({"tier":cue.tier,"scheduled":cue.time,"clock":clock,"placement":placement})
  if event_log.size()>256:event_log.pop_front()

func _apply_stops(clock:float):
 for tier in active_stops.keys():
  var envelope:Dictionary=active_stops[tier]
  var voice:AudioStreamPlayer=voices[tier]
  var remaining:float=envelope.end-clock
  if remaining<=0.0 or not voice.playing:
   voice.stop()
   voice.volume_db=envelope.gain_db
   active_stops.erase(tier)
  else:
   var fade:float=maxf(0.000001,float(envelope.fade))
   voice.volume_db=float(envelope.gain_db)+linear_to_db(clampf(remaining/fade,0.000001,1.0))

func _exit_tree():
 ambience.stop()
 ambience.stream=null
 for voice in voices.values():
  voice.stop()
  voice.stream=null
