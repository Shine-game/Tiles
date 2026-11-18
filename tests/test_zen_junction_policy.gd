extends SceneTree
const Palette=preload("res://scripts/palette.gd")
const Rules=preload("res://scripts/rules.gd")
const Board=preload("res://scripts/board_view.gd")
const Topology=preload("res://scripts/pattern/topology.gd")
func _initialize():run.call_deferred()
func run():
 Palette.select_theme("zen_garden")
 var view=Board.new()
 root.add_child(view)
 view.size=Vector2(600,600)
 for color in [1,2]:
  for mask in range(16):
   var board=Rules.empty_board(7)
   board[3][3]=color
   for i in range(4):
    if mask & (1<<i):
     var cell=Vector2i(3,3)+Topology.DIRECTIONS[i]
     board[cell.y][cell.x]=color
   view.show_settled(board)
   var prefix="junction/zen_garden/%d/3/3/"%color
   var shape=Topology.shape(mask)
   var count=0
   for id in view.junction_layer.specs:
    if id.begins_with(prefix):count+=1
   if color==2 or shape not in ["bend","t","cross"]:assert(count==0)
   else:
    assert(count==1)
    var id=prefix+shape
    var spec=view.junction_layer.specs[id]
    var path=view.junction_layer.configuration("zen_garden").shapes[shape][str(color)]
    var record=view.junction_layer.load_sprite(path)
    assert(record.scale==1.0)
    assert(is_equal_approx(spec.source_transform.x.length(),1.0/maxf(record.size.x,record.size.y)))
   if color==1:assert(view.zen_visuals.centerpieces.is_empty())
 view.queue_free()
 print("Zen junction policy: all sixteen masks, stone overlays removed, rake cores removed and junction native size pass")
 quit()
