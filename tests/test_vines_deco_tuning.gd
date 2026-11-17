extends SceneTree
const A=preload("res://scripts/pattern/asset_library.gd")
const P=preload("res://scripts/pattern/sprite_planner.gd")
const M=preload("res://scripts/pattern/sprite_metadata.gd")
func _initialize():
 var c=A.load_sprite_catalog("res://art/themes/vines/sets/tier1-artwork.json")
 var p=P.new()
 for color in [1,2]:
  for turn in range(4):
   var plan=p.plan(c,"default",color,"verify",42,{"target_forward":Vector2.RIGHT.rotated(turn*PI/2),"include_footprints":false})
   assert(plan.ok)
   assert(plan.group_counts.upper>=5 and plan.group_counts.upper<=6)
   assert(plan.group_counts.lower>=5 and plan.group_counts.lower<=6)
   assert(plan.decorations.size()==plan.target_count and plan.warnings.is_empty())
   for d in plan.decorations:
    var meta=M.load_sprite(d.metadata_path)
    var f=Vector2(meta.resolved.forward[0],meta.resolved.forward[1])
    var n=Vector2(-f.y,f.x)
    var direction=d.local_transform.basis_xform(f).normalized()
    assert(direction.x>=-0.0001 and direction.x<=0.5001)
    assert(abs(d.local_transform.basis_xform(f).length()/d.scale-1.5)<0.001)
    assert(abs(d.local_transform.basis_xform(n).length()/d.scale-2.0)<0.001)
 print("Vines: both colors/four rotations; 5–6 per side, 0–30 degrees toward growth, width x2 and length x1.5 verified")
 quit()
