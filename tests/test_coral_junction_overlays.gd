extends SceneTree
const Board=preload("res://scripts/board_view.gd")
const Palette=preload("res://scripts/palette.gd")
const Rules=preload("res://scripts/rules.gd")
const Topology=preload("res://scripts/pattern/topology.gd")
const Themes=preload("res://scripts/pattern/theme_registry.gd")
var checks:=0
var failures:=0
func check(value:bool,label:String):
 checks+=1
 if not value:
  failures+=1
  push_error(label)
func _initialize():run.call_deferred()
func run():
 Palette.select_theme("coral_reef")
 var view=Board.new()
 view.size=Vector2(600,600)
 root.add_child(view)
 var config=Themes.profile("coral_reef").junctions
 check(config.z_index>Themes.profile("coral_reef").tier1_artwork.layer_z_index+1,"Coral overlay renders above stems and decorations")
 for color in [1,2]:
  for mask in range(16):
   var grid=Rules.empty_board(5)
   grid[2][2]=color
   for port in range(4):
    if mask&(1<<port):
     var p=Vector2i(2,2)+Topology.DIRECTIONS[port]
     grid[p.y][p.x]=color
   view.show_settled(grid)
   var shape=Topology.shape(mask)
   var id="junction/coral_reef/%d/2/2/%s"%[color,shape]
   var eligible=shape in ["bend","t","cross"]
   check(view.junction_layer.events.has(id)==eligible,"Only bend/T/X receive new coral centers")
   if not eligible:continue
   var record=view.junction_layer.load_sprite(config.shapes[shape][str(color)])
   var spec=view.junction_layer.specs[id]
   check(record.path.contains("color%d"%color),"Coral color maps to its own archive")
   check(record.scale==1.5 and record.rotation.range_deg[0]==0.0 and record.rotation.range_deg[1]==360.0,"150 percent scale and unrestricted rotation")
   check(spec.material==null,"Original salmon and teal artwork is preserved")
   check((spec.source_transform*record.center).is_equal_approx(Vector2(2.5,2.5)),"Canvas center maps to square center")
   check(not view.coral_visuals.registry.has("core/%d/2/2"%color),"Old coral center removed")
   check(not view.tier1_layer.plans.is_empty(),"Underlying growth remains")
   check(view.junction_layer.renderer.nodes[id].visible,"Settled junction is visible")
 for color in [1,2]:
  var isolated=Rules.empty_board(5)
  isolated[2][2]=color
  view.show_settled(isolated)
  var node=view.coral_visuals.registry["core/%d/2/2"%color]
  check(node.texture.resource_path.ends_with("coral_tier1_bend_color%d_basic.png"%color),"Tier zero uses matching bend artwork")
  check((node.texture.get_size()*node.scale).is_equal_approx(Vector2(256,256)),"Tier zero retains its original one-square size")
 var before=Rules.empty_board(7)
 before[3][1]=1
 var after=before.duplicate(true)
 for p in [Vector2i(2,3),Vector2i(3,3),Vector2i(3,4)]:after[p.y][p.x]=1
 view.show_settled(before)
 view.animate_growth(before,after)
 view.set_process(false)
 var id="junction/coral_reef/1/3/3/bend"
 var at=view.junction_layer.events[id].start
 check(at>0 and not view.junction_layer.renderer.nodes[id].visible,"Junction waits for growth arrival")
 view.advance_growth(at)
 check(view.junction_layer.renderer.nodes[id].visible,"Junction appears at square arrival")
 view.queue_free()
 await process_frame
 print("Coral junction overlays: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
