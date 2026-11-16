shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/tile_surface.gdshaderinc"
uniform vec2 trunk_origin = vec2(0.0);
uniform float screen_pixel = 1.0;
varying vec2 board_point;
void vertex() { board_point = VERTEX + trunk_origin; }
void fragment() { COLOR.a *= surface_coverage(surface_distance(board_point, 0.0), screen_pixel); }
