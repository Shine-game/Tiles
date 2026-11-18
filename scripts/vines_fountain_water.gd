extends Node2D
const Sets = preload("res://scripts/vines_sets.gd")
const Art = preload("res://scripts/vines_renderer.gd")
const Growth = preload("res://scripts/growth.gd")
var view
var elapsed := 0.0
func _init(): z_index = 8
func _process(delta: float):
 elapsed += delta
 queue_redraw()
static func arc_point(a: Vector2,b: Vector2,u: float,height: float) -> Vector2:
 var lift := Vector2.UP if absf(b.x-a.x)>=absf(b.y-a.y) else Vector2.ZERO
 return a.lerp(b,u)+lift*4.0*height*u*(1.0-u)
func _draw():
 if view == null or view.board.is_empty():return
 var config: Dictionary = Sets.tier2.definition.water
 if not config.get("enabled", true):return
 for link: Dictionary in view.pattern.links:
  var progress: float = 1.0 if link.old else clampf((view.clock-link.start)/Growth.LINK_GROW,0.0,1.0)
  if progress<=0.0:continue
  var a: Vector2 = Art.fountain_geometry(Sets.flower().params,link.color,view._point(Vector2(link.a)),view.pitch).water_origin
  var b: Vector2 = Art.fountain_geometry(Sets.flower().params,link.color,view._point(Vector2(link.b)),view.pitch).water_origin
  var height: float = view.pitch*float(config.arc_height_cells)
  var points := PackedVector2Array()
  for i in range(33):points.append(arc_point(a,b,progress*i/32.0,height))
  var ink := Color(config.color)
  var width: float = maxf(1.0,view.pitch*float(config.width_cells))
  draw_polyline(points,Color(ink,0.25),width*2.5,true)
  draw_polyline(points,Color(ink,0.8),width,true)
  for i in range(int(config.droplets_per_arc)):
   var u: float = fposmod(elapsed/float(config.travel_seconds)+float(i)/float(config.droplets_per_arc),1.0)
   if u<=progress:draw_circle(arc_point(a,b,u,height),width*.7,Color(0.9,1.0,1.0,0.95),true,-1,true)
