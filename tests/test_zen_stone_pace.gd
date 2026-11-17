extends SceneTree
const Zen=preload("res://scripts/zen_growth.gd")
const Coral=preload("res://scripts/coral_growth.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():
 for color in [1,2]:
  var before=Rules.empty_board(7)
  before[3][1]=color
  var after=before.duplicate(true)
  for x in range(2,6):after[3][x]=color
  var baseline=Coral.new()
  baseline.build(before,after)
  var model=Zen.new()
  model.build(before,after)
  for x in range(2,6):
   assert(is_equal_approx(model.arrivals[Vector2i(x,3)],baseline.arrivals[Vector2i(x,3)]*(2.0 if color==2 else 1.0)))
  assert(model.arrivals[Vector2i(1,3)]<0)
  assert(model.duration>=model.arrivals[Vector2i(5,3)]+(0.48 if color==2 else 0.30)-0.00001)
 print("Zen pace: stone progression doubled, full-square reveal 0.48s, rake progression and settled stones unchanged")
 quit()
