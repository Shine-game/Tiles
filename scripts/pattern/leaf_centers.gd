extends RefCounted
const Metadata = preload("res://scripts/pattern/sprite_metadata.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Topology = preload("res://scripts/pattern/topology.gd")
static func placements(config: Dictionary, cell: Vector2i, color: int, mask: int) -> Array:
 var count: int = config.core_count if mask==0 else config.endpoint_count
 var result: Array = []
 var forward := Vector2.RIGHT
 if mask!=0:
  for i in range(4):
   if mask & (1<<i):forward = -Vector2(Topology.DIRECTIONS[i])
 for i in range(count):
  var record = Metadata.load_sprite(config.decorations[i%config.decorations.size()])
  assert(record.ok)
  var direction := Vector2.from_angle(i*TAU/count) if mask==0 else forward
  var flip := Vector2(-1 if i%2 else 1,1)
  var native_forward := Vector2(record.resolved.forward[0],record.resolved.forward[1])*flip
  var scale: float = config.scale/256.0
  var matrix := Transform2D(direction.angle()-native_forward.angle(),flip*scale,0,Vector2.ZERO)
  var anchor := Vector2(cell)+Vector2.ONE*0.5
  if mask==0:anchor+=direction*float(config.core_radius_cells)
  else:anchor+=forward*float(config.endpoint_offset_cells)+forward.orthogonal()*float(config.endpoint_spacing_cells)*(i-0.5)
  matrix.origin=anchor-matrix.basis_xform(Vector2(record.resolved.origin[0],record.resolved.origin[1]))
  result.append({"asset":Assets.texture(record.images["color%d"%[3-color]]),"source_transform":matrix,"lifecycle":"external","material":null})
 return result
