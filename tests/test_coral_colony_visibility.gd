extends SceneTree
const Board=preload("res://scripts/board_view.gd")
const Palette=preload("res://scripts/palette.gd")
const Rules=preload("res://scripts/rules.gd")
var failures:=0
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:
  failures+=1
  push_error(label)
func _initialize():run.call_deferred()
func run():
 Palette.select_theme("coral_reef")
 var view=Board.new()
 view.size=Vector2(600,600)
 root.add_child(view)
 for color in [1,2]:
  var empty=Rules.empty_board(7)
  var block=empty.duplicate(true)
  for p in [Vector2i(2,2),Vector2i(3,2),Vector2i(2,3),Vector2i(3,3)]:block[p.y][p.x]=color
  view.show_settled(block)
  check(view.pattern.colonies.size()==1,"The square formation is detected")
  var parts=[]
  for key in view.pattern.components:
   if view.pattern.components[key].id.begins_with("colony_"):parts.append(key)
  check(parts.size()==9,"Plate and eight petals are emitted")
  for key in parts:check(view.coral_visuals.registry.has(key),"Formation artwork is not removed by tier-one junction replacement: "+key)
  view.show_settled(empty)
  view.animate_growth(empty,block)
  view.set_process(false)
  view.advance_growth(100)
  for key in parts:check(view.coral_visuals.registry.has(key) and view.coral_visuals.registry[key].visible,"Growth presents the colony part: "+key)
  view.show_settled(block,true)
  for key in parts:check(view.coral_visuals.registry.has(key),"Undo-style settled restoration retains formation artwork")
 view.queue_free()
 print("Coral colony visibility: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
