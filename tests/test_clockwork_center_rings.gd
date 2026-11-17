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
   assert(rings==(1 if mask in [1,2,4,8,5,10] else 0))
 view.queue_free()
 print("Clockwork center rings: both colors, all 16 masks; exactly one centered fixed ring for straights/endpoints only")
 quit()
