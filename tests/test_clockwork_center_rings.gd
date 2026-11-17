extends SceneTree
const Board=preload("res://scripts/board_view.gd")
const Rules=preload("res://scripts/rules.gd")
const Palette=preload("res://scripts/palette.gd")
const Topology=preload("res://scripts/pattern/topology.gd")
func _initialize(): run.call_deferred()
func run():
 Palette.select_theme("clockwork")
 var view=Board.new()
 root.add_child(view)
 view.size=Vector2(600,600)
 for color in [1,2]:
  for mask in range(16):
   var grid=Rules.empty_board(5)
   grid[2][2]=color
   for port in range(4):
    if mask & (1<<port):
     var cell=Vector2i(2,2)+Topology.DIRECTIONS[port]
     grid[cell.y][cell.x]=color
   view.show_settled(grid)
   var rings=0
   for plan in view.tier1_layer.plans.values():
    if not (plan.base.transform*Vector2(128,128)).is_equal_approx(Vector2(2.5,2.5)):continue
    for deco in plan.decorations:
     rings+=1
     assert((deco.transform*Vector2(deco.attachment[0],deco.attachment[1])).is_equal_approx(Vector2(2.5,2.5)))
     assert(deco.metadata_path.ends_with("deco_color1_1.json"))
   assert(rings==(1 if mask in [5,10] else 0))
   var shape=Topology.shape(mask)
   var id="junction/clockwork/%d/2/2/%s"%[color,shape]
   var eligible=shape in ["bend","t","cross"]
   assert(view.junction_layer.events.has(id)==eligible)
   var core_id="C01/%d/2/2"%color
   if mask in [0,1,2,4,8]:assert(view.clockwork_visuals.registry.has(core_id))
   if eligible:
    assert(not view.clockwork_visuals.registry.has(core_id))
    var config=view.junction_layer.configuration("clockwork")
    var record=view.junction_layer.load_sprite(config.shapes[shape][str(color)])
    var spec=view.junction_layer.specs[id]
    assert(record.scale==5.0 and record.rotation.range_deg[0]==0.0 and record.rotation.range_deg[1]==360.0)
    assert(record.texture.resource_path.ends_with("color%d_basic.png"%color))
    assert((spec.source_transform*record.center).is_equal_approx(Vector2(2.5,2.5)))
    assert(spec.material==null and view.junction_layer.renderer.nodes[id].visible)

 view.queue_free()
 print("Clockwork center rings: both colors, all 16 masks; exactly one centered fixed ring for straight interiors only; no rings on starting cores or endpoints")
 quit()
