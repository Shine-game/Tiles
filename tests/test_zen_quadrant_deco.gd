extends SceneTree
const Assets=preload("res://scripts/pattern/asset_library.gd")
const Planner=preload("res://scripts/pattern/sprite_planner.gd")
func _initialize():
 var catalog=Assets.load_sprite_catalog("res://art/themes/zen_garden/sets/tier1-artwork.json")
 var planner=Planner.new()
 var counts={}
 var quadrants={}
 for base in catalog.families.stones.bases:
  for seed_value in range(16):
   var plan=planner.plan(catalog,"stones",2,"quadrant",seed_value,{"base_path":base.path,"include_footprints":false})
   assert(plan.ok and plan.decorations.size() in [1,2] and plan.decorations.size()==plan.target_count)
   assert(plan.rejections.is_empty() and plan.warnings.is_empty())
   counts[plan.decorations.size()]=true
   var seen={}
   for deco in plan.decorations:
    assert(not seen.has(deco.anchor_group))
    seen[deco.anchor_group]=true
    quadrants[deco.anchor_group]=true
    assert(deco.scale==4.0 and not deco.footprint_computed)
 assert(counts.size()==2 and quadrants.size()==4)
 assert(planner.cache_sizes().geometry.footprints==0)
 print("Zen quadrant deco: 12 stones x16 seeds, 1–2 separate quadrants, 4x size, zero overlap/raster attempts")
 quit()
