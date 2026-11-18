extends RefCounted
const Assets=preload("res://scripts/pattern/asset_library.gd")
const Themes=preload("res://scripts/pattern/theme_registry.gd")
static var pools:Dictionary={}
static func choice(theme:String,cell:Vector2i,color:int)->Dictionary:
 var config:Dictionary=Themes.profile(theme).get("tier1_artwork",{})
 if not config.get("cell_variation",false) or color!=int(config.get("logical_color",2)):return {}
 var seed_value:int=int(config.get("seed",10973))
 var key=theme+"/"+str(seed_value)
 if not pools.has(key):
  var catalog=Assets.load_sprite_catalog(Themes.sprite_catalog_path(theme),"res://",theme)
  if not catalog.ok:return {}
  var family:Dictionary=catalog.families[config.get("family","default")]
  var records:Array=family.bases.duplicate()
  records.sort_custom(func(a,b):return a.path<b.path)
  if records.size()<4:return {}
  var shuffle=RandomNumberGenerator.new()
  shuffle.seed=seed_value
  for i in range(records.size()-1,0,-1):
   var j=shuffle.randi_range(0,i)
   var temp=records[i]
   records[i]=records[j]
   records[j]=temp
  pools[key]={"records":records,"variant":family.logical_colors[str(color)].image_variant}
 var pool:Dictionary=pools[key]
 # Four disjoint pools guarantee different sprites in all eight touching cells.
 # The assignment depends only on coordinates, so additions/undo never recolor neighbors.
 var bucket=posmod(cell.x,2)+2*posmod(cell.y,2)
 var options:Array=[]
 for i in range(bucket,pool.records.size(),4):options.append(pool.records[i])
 var rng=RandomNumberGenerator.new()
 rng.seed=JSON.stringify([seed_value,cell.x,cell.y]).sha256_text().substr(0,15).hex_to_int()
 var record:Dictionary=options[rng.randi_range(0,options.size()-1)]
 return {"base_path":record.path,"texture":Assets.resolve(record.images[pool.variant]),"center":Vector2(record.resolved.origin[0],record.resolved.origin[1]),"rotation_deg":rng.randi_range(0,3)*90.0+rng.randf_range(-4.0,4.0),"flip_x":rng.randf()<0.5}
