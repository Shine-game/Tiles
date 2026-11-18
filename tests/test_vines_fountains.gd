extends SceneTree
const Sets = preload("res://scripts/vines_sets.gd")
const Art = preload("res://scripts/vines_renderer.gd")
const Water = preload("res://scripts/vines_fountain_water.gd")
const Board = preload("res://scripts/board_view.gd")
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
var checks := 0
func check(ok: bool,label: String):
 checks+=1
 assert(ok,label)
func _initialize():run.call_deferred()
func run():
 Palette.select_theme("vines")
 Sets.install()
 var spec := Sets.flower()
 if spec.provider != "vines.fountain" or not spec.params.get("enabled",true):
  if spec.provider == "vines.fountain": Art.fountain(null,spec,{})
  check(not Sets.tier2.definition.water.enabled,"Water disabled along with fountains")
  for color in [1,2]:
   var view=Board.new()
   root.add_child(view)
   view.size=Vector2(500,500)
   var grid=Rules.empty_board(7)
   for y in range(2,4):
    for x in range(2,5):grid[y][x]=color
   view.show_settled(grid)
   check(view.fountain_water==null,"Disabled fountains create no continuous water layer")
   view.queue_free()
  print("Vines fountains: disabled artwork and animation checks pass")
  quit()
  return
 check(spec.provider=="vines.fountain","Fountain replaces layered post")
 for color in [1,2]:
  var meta := Art.fountain_metadata(spec.params.sprites[str(color)])
  check(meta.image.ends_with("color%d_basic.png"%[3-color]),"Fountain matches vine color")
  for pitch in [32.0,64.0,100.0]:
   var center := Vector2(150,170)
   var geometry := Art.fountain_geometry(spec.params,color,center,pitch)
   check((geometry.rect.position+Vector2(meta.center_px[0],meta.center_px[1])*geometry.rect.size/255.0).is_equal_approx(center),"Marked basin center lands on formation center")
   check(geometry.water_origin.is_equal_approx(geometry.rect.position+Vector2(meta.water_origin_px[0],meta.water_origin_px[1])*geometry.rect.size/255.0),"Water uses separate outlet marker")
   check(geometry.rect.size==Vector2.ONE*pitch*2,"Fountain fills a two-square canvas")
  for vertical in [false,true]:
   var empty = Rules.empty_board(7)
   var board = empty.duplicate(true)
   for y in range(3 if vertical else 2):
    for x in range(2 if vertical else 3):board[y+2][x+2]=color
   var view=Board.new()
   root.add_child(view)
   view.size=Vector2(600,600)
   view.show_settled(board)
   check(view.pattern.flowers.size()==2 and view.pattern.links.size()==1,"Two fountains and one water connection")
   check(view.fountain_water.is_processing(),"Settled water continues animating")
   var link: Dictionary = view.pattern.links[0]
   var a:=Vector2(link.a)
   var b:=Vector2(link.b)
   check(Water.arc_point(a,b,0,0.5)==a and Water.arc_point(a,b,1,0.5)==b,"Water lands at both fountain centers")
   check(is_zero_approx((b-a).cross(Water.arc_point(a,b,0.5,0.5)-a)) if vertical else absf((b-a).cross(Water.arc_point(a,b,0.5,0.5)-a))>0.0,"Vertical water is straight; horizontal water arcs")
   var elapsed: float = view.fountain_water.elapsed
   view.fountain_water._process(0.2)
   check(view.fountain_water.elapsed>elapsed,"Visual flow has its own clock")
   view.show_settled(empty)
   check(not view.fountain_water.is_processing(),"Undo removes ongoing water activity")
   view.animate_growth(empty,board)
   view.set_process(false)
   var model=view.pattern
   link=model.links[0]
   for event in model.flowers.values():check(link.start>=event.start+spec.animation.duration_seconds,"Water waits for both fountains")
   view.advance_growth(model.duration+1)
   check(not view.growing and view.fountain_water.is_processing(),"Continuous flow releases the placement gate")
   view.show_settled(empty)
   view.queue_free()
 print("Vines fountains: %d checks passed"%checks)
 quit()
