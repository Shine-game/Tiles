extends SceneTree
const Board=preload("res://scripts/board_view.gd")
const Palette=preload("res://scripts/palette.gd")
const Rules=preload("res://scripts/rules.gd")
const Topology=preload("res://scripts/pattern/topology.gd")
const Junctions=preload("res://scripts/pattern/junction_layer.gd")
const Vines=preload("res://scripts/vines_sets.gd")
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
 Palette.select_theme("vines")
 var view=Board.new()
 view.size=Vector2(600,600)
 root.add_child(view)
 var original_config=Themes.definition.themes.vines.junctions.duplicate(true)
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
   var eligible=shape in ["bend","t","cross"]
   var id="junction/vines/%d/2/2/%s"%[color,shape]
   check(view.junction_layer.events.has(id)==eligible,"All masks select only bend/T/X")
   if not eligible:continue
   check(not view.construction_state.records.has(Vines.identity(color,Vector2i(2,2))),"Old bend/T/X center event removed")
   var spec=view.junction_layer.specs[id]
   var record=view.junction_layer.load_sprite(original_config.shapes[shape][str(color)])
   check((spec.source_transform*record.center).is_equal_approx(Vector2(2.5,2.5)),"Marked center maps to square center")
   check(record.path.contains("color%d"%color),"Logical pink stem uses violet asset, and vice versa")
   check(is_equal_approx(record.scale,0.8),"Shape-specific flower size")
   check(spec.material.get_shader_parameter("palette_target")==Palette.accent(color),"Every palette uses the opposite stem color")
   var node=view.junction_layer.renderer.nodes[id]
   var matrix=node.transform
   var growing_before=view.tier1_layer.plans.size()
   view.size=Vector2(850,700)
   view.update_geometry()
   check(node.transform==matrix and node.visible,"Resize preserves stable rotation and visible settled artwork")
   check(growing_before>0,"Stems remain under overlay")
   view.show_settled(Rules.empty_board(5))
   view.animate_growth(Rules.empty_board(5),grid)
   view.set_process(false)
   check(view.junction_layer.renderer.nodes[id].visible,"Overlay appears immediately when center arrival is zero")
   view.advance_growth(100)
   check(not view.growing,"Direct overlay adds no growth tail")

 # Radial isolated cores and forward endpoint leaves share the junction lifecycle.
 for color in [1,2]:
  var initial=Rules.empty_board(7)
  initial[3][3]=color
  view.show_settled(initial)
  var core_id="junction/vines/%d/3/3/core"%color
  for i in range(8):check(view.junction_layer.specs.has(core_id+"/leaf_%d"%i),"Eight radial leaves replace isolated core")
  for direction in Topology.DIRECTIONS:
   view.show_settled(initial)
   var pair=initial.duplicate(true)
   var tip=Vector2i(3,3)+direction
   pair[tip.y][tip.x]=color
   view.animate_growth(initial,pair)
   view.set_process(false)
   view.advance_growth(100)
   var tip_id="junction/vines/%d/%d/%d/core"%[color,tip.y,tip.x]
   for i in range(8):check(view.junction_layer.renderer.nodes[tip_id+"/leaf_%d"%i].visible,"Straight endpoint has eight visible radial leaves")
 # The same class also replaces configured centers in every other model.
 for theme in ["coral_reef","clockwork","zen_garden"]:
  var saved_junctions=Themes.definition.themes[theme].get("junctions", {}).duplicate(true)
  Themes.definition.themes[theme].junctions=original_config.duplicate(true)
  Palette.select_theme(theme)
  var grid=Rules.empty_board(5)
  for p in [Vector2i(2,2),Vector2i(2,1),Vector2i(1,2),Vector2i(3,2)]:grid[p.y][p.x]=1
  view.show_settled(grid)
  check(view.junction_layer.events.has("junction/%s/1/2/2/t"%theme),"One shared system handles every theme's model")
  if theme=="zen_garden":check(not view.zen_visuals.centerpieces.has(Vector2i(2,2)),"Configured overlay replaces the legacy rake centerpiece")
  if theme=="clockwork":check(not view.clockwork_visuals.registry.has("C01/1/2/2"),"Configured overlay replaces legacy clockwork center")
  if theme=="coral_reef":check(not view.coral_visuals.registry.has("core/1/2/2"),"Configured overlay replaces legacy coral center")
  if saved_junctions.is_empty():Themes.definition.themes[theme].erase("junctions")
  else:Themes.definition.themes[theme].junctions=saved_junctions
 Palette.select_theme("vines")
 # A connected addition has a future arrival: verify exact activation and pause.
 var before=Rules.empty_board(7)
 before[3][1]=1
 var after=before.duplicate(true)
 for p in [Vector2i(2,3),Vector2i(3,3),Vector2i(3,4)]:after[p.y][p.x]=1
 view.show_settled(before)
 view.animate_growth(before,after)
 view.set_process(false)
 var id="junction/vines/1/3/3/bend"
 var at=view.junction_layer.events[id].start
 check(at>0 and not view.junction_layer.renderer.nodes[id].visible,"Future junction remains hidden before arrival")
 view.construction_state.schedule.paused=true
 view.advance_growth(1)
 check(not view.junction_layer.renderer.nodes[id].visible,"Pause freezes overlay activation")
 view.construction_state.schedule.paused=false
 view.advance_growth(at)
 check(view.junction_layer.renderer.nodes[id].visible,"Overlay appears at its square arrival")
 var ids=view.junction_layer.renderer.nodes.keys()
 var capture=Board.new()
 root.add_child(capture)
 capture.size=Vector2(900,900)
 capture.show_settled(after)
 check(capture.junction_layer.specs[id].source_transform==view.junction_layer.specs[id].source_transform,"Gallery uses same rotation and assembly")
 capture.queue_free()
 # Invalid replacement leaves the established presentation intact.
 var prior_events=view.junction_layer.events.duplicate(true)
 Themes.definition.themes.vines.junctions.shapes.bend["1"]="res://missing-junction.json"
 check(not view.junction_layer.prepare(view.pattern,"vines",before,true,true,0,true,0) and view.junction_layer.events==prior_events,"Invalid metadata replacement is atomic")
 Themes.definition.themes.vines.junctions=original_config.duplicate(true)
 view.show_settled(before,true)
 check(not view.junction_layer.events.has(id),"Undo removes unsupported overlay")
 if not OS.get_cmdline_user_args().has("--production-only"):check_defaults()
 view.queue_free()
 await process_frame
 print("Junction overlays: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)

func check_defaults():
 # Use an existing tiny artwork fixture to test omitted metadata defaults.
 var path="res://build/junction-default-test.json"
 var file=FileAccess.open(path,FileAccess.WRITE)
 file.store_string(JSON.stringify({"schema":"tiles.junction-sprite.v1","image":"res://art/themes/vines/artwork/junctions/vines_tier1_bend_color1_basic.png"}))
 file.close()
 var layer=Junctions.new()
 var minimal=layer.load_sprite(path)
 check(minimal.ok and minimal.center==Vector2(626.5,626.5) and minimal.scale==1.0 and minimal.rotation.is_empty(),"Omitted values mean image center, full scale and zero rotation")
 DirAccess.remove_absolute(path)
 for index in range(6):
  var overrides=[{"scale":0},{"center":[-1,0]},{"rotation":{"range_deg":[30,0]}},{"rotation":{"allowed_deg":[0],"range_deg":[0,360]}},{"color_role":"opposite"},{"source_color":"invalid"}]
  var invalid={"schema":"tiles.junction-sprite.v1","image":"res://art/themes/vines/artwork/junctions/vines_tier1_bend_color1_basic.png"}
  invalid.merge(overrides[index],true)
  var invalid_path="res://build/junction-invalid-%d.json"%index
  var output=FileAccess.open(invalid_path,FileAccess.WRITE)
  output.store_string(JSON.stringify(invalid))
  output.close()
  check(not layer.load_sprite(invalid_path).ok,"Invalid assembly instructions are rejected")
  DirAccess.remove_absolute(invalid_path)
 layer.free()
