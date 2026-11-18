extends SceneTree
const Sets = preload("res://scripts/vines_sets.gd")
const Art = preload("res://scripts/vines_renderer.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Model = preload("res://scripts/vines_growth.gd")
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
var checks := 0
func check(ok: bool, label: String):
 checks += 1
 assert(ok,label)
func _initialize(): run.call_deferred()
func run():
 Palette.select_theme("vines")
 Sets.install()
 var spec := Sets.flower()
 check(spec.provider=="vines.layered_post","New layered artwork provider is live")
 check(spec.params.layers.size()==6,"Post, vine, four flowers")
 var end := 0.0
 for layer in spec.params.layers:
  check(is_equal_approx(layer.animation.start_seconds,end),"Every layer follows the previous layer")
  check(Art.layer_progress(layer,end)==0.0,"No early layer appearance")
  end+=layer.animation.duration_seconds
  check(is_equal_approx(Art.layer_progress(layer,end),1.0),"Layer completes before next begins")
  var texture := Assets.texture(layer.image,Sets.ROOT)
  check(texture != null and texture.get_size()==Vector2(255,255),"Source canvas registration preserved")
 check(is_equal_approx(end,spec.animation.duration_seconds),"Construction gate includes all six layers")
 for color in [1,2]:
  var empty = Rules.empty_board(7)
  var board = empty.duplicate(true)
  for y in range(2,4):
   for x in range(2,4): board[y][x]=color
  var model=Model.new()
  model.build(empty,board)
  check(model.flowers.size()==1,"Formation uses the new assembly")
  var event: Dictionary = model.flowers.values()[0]
  check(model.duration>=event.start+end,"Growth waits for all flowers")
  model.build(board,board)
  check(model.flowers.values()[0].old,"Restored assemblies remain fully visible")
 print("Vines layered post: %d checks passed"%checks)
 quit()
