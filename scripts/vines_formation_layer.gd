extends Node2D
const Sets=preload("res://scripts/vines_sets.gd")
const Art=preload("res://scripts/vines_renderer.gd")
const Assets=preload("res://scripts/pattern/asset_library.gd")
const Renderer=preload("res://scripts/pattern/component_renderer.gd")
const ShaderReveal=preload("res://shaders/vines_flower_reveal.gdshader")
var renderer=Renderer.new()
var events:Dictionary={}
func _init():z_index=2
func sync(view,settled:bool):
 var specs:Dictionary={}
 events.clear()
 var spec:Dictionary=Sets.flower()
 for corner in view.pattern.flowers:
  var event:Dictionary=view.pattern.flowers[corner]
  var meta=Art.fountain_metadata(spec.params.sprites[str(event.color)])
  var extent:=Vector2(spec.params.size_cells[0],spec.params.size_cells[1])
  var scale:=extent/Vector2(meta.canvas_px[0],meta.canvas_px[1])
  var angle=Art.formation_rotation(spec.params,event.color,corner)
  var matrix:=Transform2D(angle,scale,0,Vector2.ZERO)
  matrix.origin=Vector2(corner)-matrix.basis_xform(Vector2(meta.center_px[0],meta.center_px[1]))
  var id="flower/"+str(corner)
  var material=null if settled or event.old else Renderer.material(ShaderReveal)
  specs[id]={"asset":Assets.texture(meta.image),"source_transform":matrix,"material":material,"z_index":0}
  events[id]={"start":event.start,"duration":spec.animation.duration_seconds,"old":settled or event.old,"flower":true}
 var butterfly:Dictionary=Sets.tier3.definition.compositions.butterfly.parts.butterfly
 for link in view.pattern.links:
  var chosen=Art.butterfly_choice(butterfly.params,link)
  var meta=Art.fountain_metadata(butterfly.params.sprites[str(link.color)])
  var scale:=Vector2(butterfly.params.size_cells[0],butterfly.params.size_cells[1])/Vector2(meta.canvas_px[0],meta.canvas_px[1])
  var matrix:=Transform2D(chosen.rotation,scale,0,Vector2.ZERO)
  matrix.origin=chosen.position_cells-matrix.basis_xform(Vector2(meta.center_px[0],meta.center_px[1]))
  var id="butterfly/"+str(link.a)+"/"+str(link.b)
  specs[id]={"asset":Assets.texture(meta.image),"source_transform":matrix,"material":null,"z_index":1}
  events[id]={"start":link.start,"duration":butterfly.animation.duration_seconds,"old":settled or link.old,"flower":false}
 var synced:bool=renderer.sync(specs,self)
 if not synced:
  push_error(str(renderer.diagnostics))
  return
 advance(view.clock)
func advance(clock:float):
 for id in events:
  var event:Dictionary=events[id]
  var node:Sprite2D=renderer.nodes[id]
  var p:float=1.0 if event.old else clampf((clock-event.start)/event.duration,0.0,1.0)
  node.visible=p>0.0
  if event.flower:
   if p>=1.0:node.material=null
   elif node.material!=null:
    node.material.set_shader_parameter("progress",p)
    node.material.set_shader_parameter("elapsed",maxf(0,clock-event.start))
  else:node.modulate.a=p
