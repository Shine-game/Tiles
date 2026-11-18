extends SceneTree
const Choices=preload("res://scripts/pattern/cell_variation.gd")
const Board=preload("res://scripts/board_view.gd")
const Rules=preload("res://scripts/rules.gd")
const Palette=preload("res://scripts/palette.gd")
func _initialize():run.call_deferred()
func run():
 Palette.select_theme("zen_garden")
 var paths={}
 var turns={}
 var flips={}
 var offsets={}
 for y in range(-8,9):
  for x in range(-8,9):
   var cell=Vector2i(x,y)
   var item=Choices.choice("zen_garden",cell,2)
   paths[item.base_path]=true
   var turn=roundi(item.rotation_deg/90.0)
   var offset=item.rotation_deg-turn*90.0
   assert(abs(offset)<=4.00001)
   turns[posmod(turn,4)]=true
   flips[item.flip_x]=true
   offsets[signf(offset)]=true
   assert(Choices.choice("zen_garden",cell,2)==item)
   for delta in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE,Vector2i(-1,1)]:
    assert(Choices.choice("zen_garden",cell+delta,2).base_path!=item.base_path)
 assert(paths.size()==12 and turns.size()==4 and flips.size()==2 and offsets.has(-1.0) and offsets.has(1.0))
 var view=Board.new()
 root.add_child(view)
 view.size=Vector2(600,600)
 var grid=Rules.empty_board(7)
 for x in range(1,6):grid[3][x]=2
 view.show_settled(grid)
 for x in range(1,6):
  var item=Choices.choice("zen_garden",Vector2i(x,3),2)
  var transform:Transform2D
  if x in [1,5]:
   var spec=view.junction_layer.specs["junction/zen_garden/2/3/%d/core"%x]
   assert(spec.asset==item.texture)
   transform=spec.source_transform
  else:
   var base=view.tier1_layer.plans["zen_garden/stone/3/%d"%x].base
   assert(base.metadata_path==item.base_path)
   transform=base.transform
  assert((transform*item.center).is_equal_approx(Vector2(x+0.5,3.5)))
  assert((transform.determinant()<0)==item.flip_x)
 view.queue_free()
 print("Zen stone variety: 12 designs, 4 quarter turns, both flip forms, +/-4 degree jitter, no eight-neighbor repeats, stable choices and matching core/path assembly pass")
 quit()
