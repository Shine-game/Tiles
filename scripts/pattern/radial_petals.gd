extends RefCounted
const Metadata=preload("res://scripts/pattern/sprite_metadata.gd")
const Assets=preload("res://scripts/pattern/asset_library.gd")
static var catalogs:Dictionary={}
static func catalog(path:String)->Dictionary:
 if catalogs.has(path):return catalogs[path]
 var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 assert(data is Dictionary and data.schema=="tiles.radial-petals.v1")
 assert(data.count>=1 and data.count==floorf(data.count) and data.petals.size()>=data.count)
 for ref in data.petals:
  var record=Metadata.load_sprite(ref)
  assert(record.ok,str(record.get("errors",[])))
  assert(record.definition.kind=="decoration" and record.definition.has("direction"))
  assert(record.images.has("color1") and record.images.has("color2"))
 catalogs[path]=data
 return data
static func choices(path:String,color:int,origin:Vector2i)->Array:
 var data=catalog(path)
 var rng=RandomNumberGenerator.new()
 rng.seed=JSON.stringify([data.seed,color,origin.x,origin.y]).sha256_text().substr(0,15).hex_to_int()
 var refs:Array=data.petals.duplicate()
 for i in range(refs.size()-1,0,-1):
  var j=rng.randi_range(0,i)
  var temp=refs[i]
  refs[i]=refs[j]
  refs[j]=temp
 var phase=rng.randf_range(0,TAU)
 var result:Array=[]
 for i in range(data.count):result.append({"path":refs[i],"variant":"color%d"%color,"angle":phase+i*TAU/data.count,"flip_x":rng.randf()<0.5,"scale":float(data.get("scale",1.0))})
 return result
static func render_spec(event:Dictionary,template:Dictionary,settled:bool)->Dictionary:
 var chosen:Dictionary=event.radial_petal
 var record=Metadata.load_sprite(chosen.path)
 var origin=Vector2(record.resolved.origin[0],record.resolved.origin[1])
 var forward=Vector2(record.resolved.forward[0],record.resolved.forward[1])
 var form=Vector2(-1 if chosen.flip_x else 1,1)
 var rotation=chosen.angle-(forward*form).angle()
 var matrix=Transform2D(rotation,form*chosen.scale,0,Vector2.ZERO)
 matrix.origin=event.center*256.0-matrix.basis_xform(origin)
 var spec=template.duplicate(true)
 for field in ["position_cells","position_px","pivot_px","offset_px","scale","size_cells","max_extent_cells","rotation_radians","quarter_turns","flip_h","flip_v","centered","pixels_per_cell"]:spec.erase(field)
 spec.asset={"provider":"texture","path":record.images[chosen.variant]}
 spec.source_transform=matrix
 spec.material=null
 if not settled and not event.old:
  spec.material={"provider":"coral.reveal","params":{"artwork":spec.asset,"growth_mask":record.reveals[chosen.variant],"asset_root":"res://","growth_mask_rotation_radians":0.0,"start_at_zero":event.start,"start_at_one":event.reverse,"stroke_seconds":event.stroke,"front_one_enabled":false}}
 return spec
