extends SceneTree
const A=preload("res://scripts/pattern/asset_library.gd")
const P=preload("res://scripts/pattern/sprite_planner.gd")
const M=preload("res://scripts/pattern/sprite_metadata.gd")
func _initialize():
 var c=A.load_sprite_catalog("res://art/themes/vines/sets/tier1-artwork.json")
 var p=P.new()
 for sample in range(64):
  var color=1+sample%2
  for turn in range(4):
   var plan=p.plan(c,"default",color,"verify",sample,{"target_forward":Vector2.RIGHT.rotated(turn*PI/2),"include_footprints":false})
   assert(plan.ok)
   assert(plan.group_counts.upper==2)
   assert(plan.group_counts.lower==2)
   assert(plan.decorations.size()==plan.target_count and plan.warnings.is_empty())
   for side in ["upper","lower"]:
    var indices=[]
    for d in plan.decorations:
     if d.anchor_group==side:indices.append(int(d.anchor_id.get_slice("_",1)))
    indices.sort()
    assert(indices[0] in [2,3,4] and indices[1] in [7,8,9] and indices[1]-indices[0]>=4)
   for d in plan.decorations:
    assert(is_equal_approx(d.scale,1.0))
    var meta=M.load_sprite(d.metadata_path)
    var f=Vector2(meta.resolved.forward[0],meta.resolved.forward[1])
    var n=Vector2(-f.y,f.x)
    var direction=d.local_transform.basis_xform(f).normalized()
    assert(is_equal_approx(direction.x,0.5) and is_equal_approx(abs(direction.y),sqrt(3.0)/2.0))
    assert(abs(d.local_transform.basis_xform(f).length()/d.scale-1.0)<0.001)
    assert(abs(d.local_transform.basis_xform(n).length()/d.scale-1.0)<0.001)
 print("Vines: both colors/four rotations; exactly 2 per side, exactly 30 degrees toward growth, native size on both axes verified")
 quit()
