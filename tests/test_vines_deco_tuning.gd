extends SceneTree
const A=preload("res://scripts/pattern/asset_library.gd")
const P=preload("res://scripts/pattern/sprite_planner.gd")
const Sources=preload("res://scripts/pattern/tier1_sources.gd")
const Growth=preload("res://scripts/growth.gd")
const Rules=preload("res://scripts/rules.gd")
const M=preload("res://scripts/pattern/sprite_metadata.gd")
func _initialize():
 var c=A.load_sprite_catalog("res://assets/themes/vines/assembly/vines_tier1_sprite_catalog.json")
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
    assert(is_equal_approx(d.scale,0.8))
    var meta=M.load_sprite(d.metadata_path)
    var f=Vector2(meta.resolved.forward[0],meta.resolved.forward[1])
    var n=Vector2(-f.y,f.x)
    var direction=d.local_transform.basis_xform(f).normalized()
    assert(is_equal_approx(direction.x,0.5) and is_equal_approx(abs(direction.y),sqrt(3.0)/2.0))
    assert(abs(d.local_transform.basis_xform(f).length()/d.scale-1.0)<0.001)
    assert(abs(d.local_transform.basis_xform(n).length()/d.scale-1.0)<0.001)
 # Assemble real edge halves and check the final world-space growth inclination.
 for color in [1,2]:
  for direction in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
   var before=Rules.empty_board(9)
   before[4][4]=color
   var after=before.duplicate(true)
   for step in range(1,4):
    var cell=Vector2i(4,4)+direction*step
    after[cell.y][cell.x]=color
   var model=Growth.new()
   model.build(before,after)
   for item in Sources.descriptors(model,"vines",before):
    item.context.include_footprints=false
    var plan=p.plan(c,"default",color,item.id,42,item.context)
    assert(plan.ok and plan.decorations.size()==4)
    for d in plan.decorations:
     var meta=M.load_sprite(d.metadata_path)
     var f=Vector2(meta.resolved.forward[0],meta.resolved.forward[1])
     var world=d.transform.basis_xform(f).normalized()
     assert(is_equal_approx(world.dot(Vector2(direction)),0.5))
 print("Vines: both colors/four rotations; exactly 2 per side, exactly 30 degrees toward growth, 80% size on both axes verified")
 quit()
