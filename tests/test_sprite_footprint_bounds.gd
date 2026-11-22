extends SceneTree
const Footprint=preload("res://scripts/pattern/sprite_footprint.gd")
const Metadata=preload("res://scripts/pattern/sprite_metadata.gd")
func _initialize():
 var footprint=Footprint.new()
 var rng=RandomNumberGenerator.new()
 rng.seed=57382
 var count=0
 for path in ["res://tests/fixtures/decoration_test.json", "res://assets/themes/vines/sprites/tier1/vines_tier1_deco_color1_01.json", "res://assets/themes/vines/sprites/tier1/vines_tier1_deco_color1_02.json", "res://assets/themes/vines/sprites/tier1/vines_tier1_deco_color1_03.json", "res://assets/themes/coral_reef/sprites/tier1/coral_reef_tier1_deco_color1_01.json"]:
  var meta=Metadata.load_sprite(path)
  assert(meta.ok)
  var origin=Vector2(meta.resolved.origin[0],meta.resolved.origin[1])
  for sample in range(12):
   var transform=Transform2D(rng.randf_range(-PI,PI),Vector2(-2.8 if sample%2 else 2.8,2.8),0,Vector2(rng.randf_range(0,255),rng.randf_range(0,255)))
   var actual=footprint.raster(meta.images.color1,transform,origin)
   var bounds=footprint.raster_bounds(meta.images.color1,transform)
   var summary=footprint.summary(meta.images.color1,transform,origin)
   assert(actual.ok and bounds.ok and summary.ok)
   var low=Vector2i(2147483647,2147483647)
   var high=Vector2i(-2147483647,-2147483647)
   for cell in actual.cells:
    low=low.min(cell)
    high=high.max(cell)
   assert(bounds.min==low and bounds.max==high)
   assert(is_equal_approx(actual.radius,summary.radius))
   count+=1
 footprint.clear()
 assert(footprint.cache_sizes()=={"images":0,"footprints":0})
 print("Footprint bounds: %d rotated/reflected rasters match exact hull bounds and radius"%count)
 quit()
