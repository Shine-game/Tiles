extends SceneTree
const B=preload("res://scripts/board_view.gd")
const P=preload("res://scripts/palette.gd")
const R=preload("res://scripts/rules.gd")
func _initialize(): run.call_deferred()
func run():
 P.select_theme("zen_garden")
 var view=B.new()
 root.add_child(view)
 view.size=Vector2(600,600)
 var grid=R.empty_board(5)
 for c in [Vector2i(1,1),Vector2i(2,1),Vector2i(2,2),Vector2i(4,4)]:grid[c.y][c.x]=2
 view.show_settled(grid)
 assert(view.tier1_layer.plans.size()==1)
 var centers={}
 for plan in view.tier1_layer.plans.values():
  var center=plan.base.transform*Vector2(127,127)
  assert(not centers.has(center))
  centers[center]=true
  assert(grid[int(center.y)][int(center.x)]==2)
  assert(center.is_equal_approx(Vector2(floor(center.x)+0.5,floor(center.y)+0.5)))
  assert(is_equal_approx(plan.base.transform.x.length(),1.0/255.0))
  assert(not plan.decorations.is_empty())
  for deco in plan.decorations:assert(is_equal_approx(deco.scale,1.4))
 for group in view.zen_visuals.registry.values():assert(group.get_child_count()==1)
 for c in [Vector2i(1,1),Vector2i(2,2),Vector2i(4,4)]:
  var id="junction/zen_garden/2/%d/%d/core"%[c.y,c.x]
  assert(view.junction_layer.renderer.nodes.has(id))
  assert(not view.tier1_layer.plans.has("zen_garden/stone/%d/%d"%[c.y,c.x]))
 view.queue_free()
 print("Zen cell stones: one full-canvas stone per occupied stone cell including isolated/endpoints, no legacy duplicate, decoration world size doubled")
 quit()
