extends SceneTree
const Board=preload("res://scripts/board_view.gd")
const Palette=preload("res://scripts/palette.gd")
const Rules=preload("res://scripts/rules.gd")
const Topology=preload("res://scripts/pattern/topology.gd")
func _initialize():run.call_deferred()
func run():
 Palette.select_theme("zen_garden")
 var view=Board.new()
 root.add_child(view)
 view.size=Vector2(600,600)
 for color in [1,2]:
  for mask in range(16):
   var grid=Rules.empty_board(5)
   grid[2][2]=color
   for port in range(4):
    if mask&(1<<port):
     var p=Vector2i(2,2)+Topology.DIRECTIONS[port]
     grid[p.y][p.x]=color
   view.show_settled(grid)
   var shape=Topology.shape(mask)
   var role="core" if shape in ["isolated","endpoint"] else shape
   var id="junction/zen_garden/%d/2/2/%s"%[color,role]
   var eligible=role in ["core","bend","t","cross"]
   assert(view.junction_layer.events.has(id)==eligible)
   assert(not view.zen_visuals.centerpieces.has(Vector2i(2,2)))
   if eligible:
    var config=view.junction_layer.configuration("zen_garden")
    var record=view.junction_layer.load_sprite(config.shapes[role][str(color)])
    var spec=view.junction_layer.specs[id]
    assert(record.scale==1.0 and record.rotation.is_empty())
    assert((spec.source_transform*record.center).is_equal_approx(Vector2(2.5,2.5)))
    assert(view.junction_layer.renderer.nodes[id].visible and spec.material==null)
   if color==2:
    assert(view.tier1_layer.plans.has("zen_garden/stone/2/2")==(role!="core"))
 var before=Rules.empty_board(7)
 before[3][1]=2
 var after=before.duplicate(true)
 for p in [Vector2i(2,3),Vector2i(3,3),Vector2i(3,4)]:after[p.y][p.x]=2
 view.show_settled(before)
 view.animate_growth(before,after)
 view.set_process(false)
 var id="junction/zen_garden/2/3/3/bend"
 var at=view.junction_layer.events[id].start
 assert(at>0 and not view.junction_layer.renderer.nodes[id].visible)
 view.advance_growth(at)
 assert(view.junction_layer.renderer.nodes[id].visible)
 view.show_settled(before,true)
 assert(view.junction_layer.renderer.nodes.has("junction/zen_garden/2/3/1/core"))
 view.queue_free()
 print("Zen junctions: both paths, all 16 masks, centered unrotated 100 percent artwork, single basic-stone cores, arrival and undo pass")
 quit()
