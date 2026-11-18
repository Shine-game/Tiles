extends SceneTree
const Leaf=preload("res://scripts/pattern/leaf_centers.gd")
const Themes=preload("res://scripts/pattern/theme_registry.gd")
const Palette=preload("res://scripts/palette.gd")
const Rules=preload("res://scripts/rules.gd")
const Topology=preload("res://scripts/pattern/topology.gd")
const Board=preload("res://scripts/board_view.gd")
func _initialize():run.call_deferred()
func run():
 Palette.select_theme("vines")
 var config: Dictionary=Themes.profile("vines").junctions.leaf_centers
 for color in [1,2]:
  assert(Leaf.placements(config,Vector2i(3,3),color,0).size()==8)
  for mask in [1,2,4,8]:
   var parts=Leaf.placements(config,Vector2i(3,3),color,mask)
   assert(parts.size()==8)
   for part in parts:
    assert(part.asset!=null)
    assert(part.material==null)
  var board=Rules.empty_board(7)
  board[3][3]=color
  var view=Board.new()
  root.add_child(view)
  view.size=Vector2(600,600)
  view.show_settled(board)
  var count=0
  for id in view.junction_layer.specs:
   if "/leaf_" in id:count+=1
  assert(count==8)
  board[3][4]=color
  view.show_settled(board)
  count=0
  for id in view.junction_layer.specs:
   if "/leaf_" in id:count+=1
  assert(count==16)
  var ids=view.junction_layer.specs.keys()
  var original=view.junction_layer.specs["junction/vines/%d/3/3/core/leaf_0"%color].source_transform
  var before=board.duplicate(true)
  board[3][2]=color
  view.animate_growth(before,board)
  assert(view.junction_layer.specs["junction/vines/%d/3/3/core/leaf_0"%color].source_transform==original)
  view.set_process(false)
  view.advance_growth(100)
  for mask in range(16):
   var shape=Topology.shape(mask)
   if shape not in ["bend","t","cross"]:continue
   var endpoint=Rules.empty_board(7)
   endpoint[3][3]=color
   var after=endpoint.duplicate(true)
   var first=true
   for i in range(4):
    if mask & (1<<i):
     var cell=Vector2i(3,3)+Topology.DIRECTIONS[i]
     after[cell.y][cell.x]=color
     if first:
      endpoint[cell.y][cell.x]=color
      first=false
   view.show_settled(endpoint)
   var prefix="junction/vines/%d/3/3/core/"%color
   assert(view.junction_layer.specs.has(prefix+"leaf_0"))
   view.animate_growth(endpoint,after)
   view.set_process(false)
   for id in view.junction_layer.specs:assert(not id.begins_with(prefix))
   var flower="junction/vines/%d/3/3/%s"%[color,shape]
   assert(view.junction_layer.specs.has(flower))
   view.advance_growth(100)
   assert(view.junction_layer.renderer.nodes[flower].visible)
   view.show_settled(endpoint,true)
   assert(view.junction_layer.specs.has(prefix+"leaf_7"))
  view.queue_free()
 print("Vines leaf centers: both colors, eight radial core leaves and eight radial leaves per endpoint, and every bend/T/X replacement pass")
 quit()
