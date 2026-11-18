extends SceneTree
const B=preload("res://scripts/board_view.gd")
const P=preload("res://scripts/palette.gd")
const Timing=preload("res://scripts/pattern/sprite_growth.gd")
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
 assert(view.tier1_layer.plans.size()==4)
 var centers={}
 for plan in view.tier1_layer.plans.values():
  var center=plan.base.transform*Vector2(127,127)
  assert(not centers.has(center))
  centers[center]=true
  assert(grid[int(center.y)][int(center.x)]==2)
  assert(center.is_equal_approx(Vector2(floor(center.x)+0.5,floor(center.y)+0.5)))
  assert(is_equal_approx(plan.base.transform.x.length(),1.0/255.0))
  assert(not plan.decorations.is_empty())
  assert(plan.decorations.size() in [1,2])
  var groups={}
  for deco in plan.decorations:
   assert(is_equal_approx(deco.scale,4.0))
   assert(not groups.has(deco.anchor_group))
   groups[deco.anchor_group]=true
   assert(not deco.footprint_computed)
   assert(view.tier1_layer.presenter.renderer.nodes[Timing.event_id(deco.id)].z_index==-1)

 for group in view.zen_visuals.registry.values():assert(group.get_child_count()==1)
 for c in [Vector2i(1,1),Vector2i(2,2),Vector2i(4,4)]:
  var id="junction/zen_garden/2/%d/%d/core"%[c.y,c.x]
  assert(not view.junction_layer.renderer.nodes.has(id))
  assert(not view.tier1_layer.plans["zen_garden/stone/%d/%d"%[c.y,c.x]].decorations.is_empty())
 view.queue_free()
 print("Zen cell stones: one main stone per square, 1–2 unique quadrants, decoration scale 4, no footprint calculation")
 quit()
