extends SceneTree
const Petals=preload("res://scripts/pattern/radial_petals.gd")
const Sets=preload("res://scripts/coral_sets.gd")
const Growth=preload("res://scripts/coral_growth.gd")
const Rules=preload("res://scripts/rules.gd")
const Metadata=preload("res://scripts/pattern/sprite_metadata.gd")
const PATH="res://art/themes/coral_reef/artwork/petals/radial.json"
func _initialize():
 Sets.install()
 var mirrors={}
 var phases={}
 var selected={}
 assert(Petals.catalog(PATH).petals.size()==12)
 for color in [1,2]:
  for x in range(4):
   var origin=Vector2i(x,2)
   var choices=Petals.choices(PATH,color,origin)
   assert(choices.size()==8 and choices==Petals.choices(PATH,color,origin))
   var used={}
   phases[choices[0].angle]=true
   for i in range(8):
    var chosen=choices[i]
    assert(int(chosen.path.get_file().get_basename().get_slice("_",3)) in range(1,13))
    assert(not used.has(chosen.path))
    used[chosen.path]=true
    selected[chosen.path]=true
    mirrors[chosen.flip_x]=true
    assert(is_equal_approx(chosen.angle-choices[0].angle,i*PI/4))
    var meta=Metadata.load_sprite(chosen.path)
    var event={"radial_petal":chosen,"center":Vector2(3,3),"old":true}
    var spec=Petals.render_spec(event,{},true)
    var attachment=Vector2(meta.resolved.origin[0],meta.resolved.origin[1])
    var forward=Vector2(meta.resolved.forward[0],meta.resolved.forward[1])
    assert((spec.source_transform*attachment).is_equal_approx(Vector2(768,768)))
    assert(spec.source_transform.basis_xform(forward).normalized().is_equal_approx(Vector2.from_angle(chosen.angle)))
    assert((spec.source_transform.determinant()<0)==chosen.flip_x)
  var grid=Rules.empty_board(7)
  for p in [Vector2i(2,2),Vector2i(3,2),Vector2i(2,3),Vector2i(3,3)]:grid[p.y][p.x]=color
  var model=Growth.new()
  model.build(Rules.empty_board(7),grid)
  var body=model.components[Growth.key("colony_body",color,Vector2i(2,2))]
  for i in range(8):
   var petal=model.components[Growth.key("colony_petal_%d"%i,color,Vector2i(2,2))]
   assert(petal.start>=body.end-0.00001)
   assert(petal.radial_petal.variant=="color%d"%color)
  assert(not model.components.values().any(func(e):return e.id.begins_with("colony_fold_") or e.id.begins_with("colony_fingers_")))
 assert(mirrors.size()==2 and phases.size()>1 and selected.size()>8)
 print("Coral radial petals: 12 designs/both colors, eight distinct choices, reflected forms, 45-degree spacing, exact marked origins/axes and plate-first schedule pass")
 quit()
