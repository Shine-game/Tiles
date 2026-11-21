extends SceneTree
const Board=preload("res://scripts/board_view.gd")
const Rules=preload("res://scripts/rules.gd")
const Palette=preload("res://scripts/palette.gd")
const Sets=preload("res://scripts/vines_sets.gd")
const Themes=preload("res://scripts/pattern/theme_registry.gd")
func _initialize():run.call_deferred()
func run():
 Palette.select_theme("vines")
 var view=Board.new()
 root.add_child(view)
 view.size=Vector2(600,600)
 for color in [1,2]:
  var empty=Rules.empty_board(7)
  var board=empty.duplicate(true)
  for y in range(2,4):
   for x in range(2,5):board[y][x]=color
  view.animate_growth(empty,board)
  view.set_process(false)
  var event:Dictionary=view.pattern.flowers[Vector2i(3,3)]
  assert(is_equal_approx(event.start,event.tier1_ready+0.2))
  for shot in view.pattern.sprite_growth_events.values():
   if shot.old:continue
   var owner:String=shot.owner
   var c=Vector2i(int(owner.get_slice("/",3)),int(owner.get_slice("/",2)))
   var o=Vector2i(int(owner.get_slice("/",5)),int(owner.get_slice("/",4)))
   if Rect2i(2,2,2,2).has_point(c) and Rect2i(2,2,2,2).has_point(o):assert(event.tier1_ready>=shot.end)
  var seconds:float=3.0
  assert(is_equal_approx(Sets.flower().animation.duration_seconds,seconds))
  var node=view.vines_formations.renderer.nodes["flower/(3, 3)"]
  assert(not node.visible)
  view.advance_growth(event.start-0.001)
  assert(not node.visible)
  view.advance_growth(0.001+seconds/2)
  assert(node.visible and node.material!=null)
  assert(is_equal_approx(node.material.get_shader_parameter("progress"),0.5))
  assert(view.vines_formations.renderer.nodes.values().filter(func(n):return n.z_index==1).all(func(n):return not n.visible))
  view.advance_growth(seconds/2)
  assert(node.visible and node.material==null)
  var link:Dictionary=view.pattern.links[0]
  var complete:float=maxf(view.pattern.formation_complete(view.pattern.flowers[link.a]),view.pattern.formation_complete(view.pattern.flowers[link.b]))
  assert(is_equal_approx(link.start,complete+0.2))
  view.advance_growth(maxf(0.0,link.start-view.clock-0.001))
  assert(view.vines_formations.renderer.nodes.values().filter(func(n):return n.z_index==1).all(func(n):return not n.visible))
  view.advance_growth(0.002)
  assert(view.vines_formations.renderer.nodes.values().filter(func(n):return n.z_index==1).all(func(n):return n.visible))
  view.advance_growth(100)
  assert(not view.growing)
  var saved=node.transform
  view.show_settled(board)
  assert(view.vines_formations.renderer.nodes["flower/(3, 3)"].transform==saved)
  assert(view.vines_formations.renderer.nodes["flower/(3, 3)"].material==null)
 view.queue_free()
 print("Vines delayed reveal: local tier-one readiness, 0.2s waits, three-second mask, delayed butterflies, original settled art pass")
 quit()
