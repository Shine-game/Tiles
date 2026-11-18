extends SceneTree
const Leaf=preload("res://scripts/pattern/leaf_centers.gd")
const Themes=preload("res://scripts/pattern/theme_registry.gd")
const Palette=preload("res://scripts/palette.gd")
const Rules=preload("res://scripts/rules.gd")
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
   for part in parts:assert(part.asset!=null)
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
  view.queue_free()
 print("Vines leaf centers: both colors, eight radial core leaves and eight radial leaves per endpoint pass")
 quit()
