extends SceneTree
const Board=preload("res://scripts/board_view.gd")
const Sets=preload("res://scripts/vines_sets.gd")
const Art=preload("res://scripts/vines_renderer.gd")
const Rules=preload("res://scripts/rules.gd")
const Palette=preload("res://scripts/palette.gd")
func _initialize():run.call_deferred()
func run():
 Palette.select_theme("vines")
 Sets.install()
 var spec: Dictionary=Sets.tier3.definition.compositions.butterfly.parts.butterfly
 assert(is_equal_approx(spec.params.size_cells[0],1.0))
 for color in [1,2]:
  for vertical in [false,true]:
   var view=Board.new()
   root.add_child(view)
   view.size=Vector2(600,600)
   var empty=Rules.empty_board(7)
   var board=empty.duplicate(true)
   for y in range(3 if vertical else 2):
    for x in range(2 if vertical else 3):board[y+2][x+2]=color
   view.show_settled(board)
   assert(view.pattern.links.size()==1)
   var link: Dictionary=view.pattern.links[0]
   var chosen=Art.butterfly_choice(spec.params,link)
   assert(chosen.overlap.get_area()==2.0)
   assert(chosen.overlap.has_point(chosen.position_cells))
   assert(chosen==Art.butterfly_choice(spec.params,link))
   assert(chosen.rotation>=0 and chosen.rotation<=TAU)
   var id="junction/vines/%d/2/2/bend"%color
   assert(not view.junction_layer.renderer.nodes[id].visible)
   view.animate_growth(empty,board)
   view.set_process(false)
   var start: float=view.pattern.flowers[Vector2i(3,3)].start
   view.advance_growth(start+Sets.flower().animation.duration_seconds/2)
   var node=view.junction_layer.renderer.nodes[id]
   assert(is_equal_approx(node.modulate.a,0.5))
   view.advance_growth(100)
   assert(not node.visible and not view.growing)
   var corner=Rules.empty_board(7)
   corner[2][2]=color
   corner[2][3]=color
   corner[3][2]=color
   view.show_settled(corner,true)
   assert(view.junction_layer.renderer.nodes[id].visible and view.junction_layer.renderer.nodes[id].modulate.a==1.0)
   view.queue_free()
 print("Vines tier three: both colors/orientations, overlap placement, half size, stable rotation, small-flower crossfade and undo pass")
 quit()
