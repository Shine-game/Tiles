extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/palette.gd")
const Model = preload("res://scripts/clockwork_growth.gd")
const Visuals = preload("res://scripts/clockwork_visuals.gd")
const Sets = preload("res://scripts/clockwork_sets.gd")
var checks := 0
func check(ok: bool, label: String):
 checks += 1
 assert(ok, label)
func _initialize(): run.call_deferred()
func run():
 Palette.select_theme("clockwork")
 for color in [1,2]:
  for vertical in [false,true]:
   var empty = Rules.empty_board(7)
   var board = empty.duplicate(true)
   for y in range(3 if vertical else 2):
    for x in range(2 if vertical else 3): board[y+2][x+2]=color
   var model = Model.new()
   model.build(empty,board)
   check(model.mechanisms.size()==2 and model.chains.size()==1,"Linked mechanisms remain intact")
   for event in model.components.values(): check(event.id not in ["L02","L03"],"No intermediate hub or second wheel")
   for mechanism in model.mechanisms.values():
    var wheel = model.components[Model.key("L01",color,mechanism.origin)]
    var cap = model.components[Model.key("hatch",color,mechanism.origin)]
    check(is_equal_approx(cap.start,wheel.end),"Cap follows first wheel without removed-layer pause")
    check(mechanism.ready>=cap.end,"Chain waits for enlarged cap")
   var visuals = Visuals.new()
   root.add_child(visuals)
   visuals.reconcile(model,true,false)
   for entry in visuals.registry.values():
    if entry.event.id=="L01":check(entry.node.texture.resource_path==Model.ROOT+"artwork/"+("gunmetal" if color==1 else "copper")+("/clockwork_tier2_wheel_color%d_1.png" % (3-color)),"Wheel uses opposite metal")
    if entry.event.id=="H00_plain_hatch":check(entry.node.texture.resource_path==Model.ROOT+"artwork/"+("copper" if color==1 else "gunmetal")+("/clockwork_tier2_plain_hatch_color%d_1.png" % color),"Cap retains original metal")
    if entry.event.id=="H00_plain_hatch":check(entry.node.scale==Vector2(1.5,1.5),"Initial and terminal plain caps scaled 150 percent")
   for entry in visuals.chain_nodes.values():
    for strip in entry.strips:check(is_equal_approx(absf(strip.position.y+strip.size.y/2),45.0),"Chain run touches enlarged cap radius")
   visuals.queue_free()
 print("Clockwork tier-two layout: %d checks passed"%checks)
 quit()
