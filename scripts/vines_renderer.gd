extends RefCounted
# Procedural art providers. The board supplies its existing curves, brush, clock
# and palette; configuration supplies ordinary motif and foliage proportions.
const FountainAssets = preload("res://scripts/pattern/asset_library.gd")
const Growth = preload("res://scripts/growth.gd")
const Palette = preload("res://scripts/palette.gd")
const Assembly = preload("res://scripts/pattern/assembly.gd")

static func wash(view, spec: Dictionary, context: Dictionary) -> void:
	var cell: Vector2i = context.cell
	var scale: float = view.pop((view.clock - float(view.pattern.arrivals[cell])) / float(spec.animation.duration_seconds))
	if scale <= 0: return
	var p: Dictionary = spec.params
	var center: Vector2 = view._point(Vector2(cell) + Vector2.ONE * 0.5)
	var pigment := Palette.pigment(view.board[cell.y][cell.x])
	for layer in range(int(p.layers)):
		view.draw_circle(center, view.pitch * (float(p.radius) + layer * float(p.radius_step)), Color(pigment, float(p.alpha) * scale), true, -1, true)

static func holding(view, spec: Dictionary, context: Dictionary) -> void:
	var scale: float = context.scale
	if scale <= 0: return
	var cell: Vector2i = context.cell
	var p: Dictionary = spec.params
	var center: Vector2 = view._point(Vector2(cell) + Vector2.ONE * 0.5)
	var ink := Palette.pigment(view.board[cell.y][cell.x])
	var accent := Palette.blossom(view.board[cell.y][cell.x])
	# One canonical frond uses the shared assembly orientation for every port.
	# Preserve the existing L/R/N/S painter order to retain alpha blending.
	for port: float in p.port_order:
		var direction := Assembly.point(Vector2.UP, int(port))
		var normal := Vector2(-direction.y, direction.x)
		var open: bool = Growth.value(view.board, cell + Vector2i(direction)) != view.board[cell.y][cell.x]
		var frond: Dictionary = p.open if open else p.connected
		var tip: Vector2 = center + direction * view.pitch * float(frond.reach) * scale
		var curve: Dictionary = view._curve(center, tip, direction + normal * float(p.curve_normal), -direction)
		view._vine(curve, 0, 1, Color(ink, float(frond.curve_alpha)), 0)
		for side: float in [-1.0, 1.0]:
			if open:
				for i in range(frond.leaf_roots.size()):
					view._paint_leaf(center + direction * view.pitch * float(frond.leaf_roots[i]) * scale,
						(direction + normal * side * float(p.side_normal)).normalized(),
						view.pitch * float(frond.leaf_lengths[i]), view.pitch * float(frond.leaf_widths[i]),
						Color(ink.lightened(float(frond.leaf_lightening[i])), float(frond.leaf_alphas[i])), scale)
			else:
				var root: Vector2 = center + direction * view.pitch * float(frond.leaf_root) * scale
				view._paint_leaf(root, (direction + normal * side * float(frond.side_normal)).normalized(),
					view.pitch * float(frond.leaf_length), view.pitch * float(frond.leaf_width), Color(ink, float(frond.leaf_alpha)), scale)
		view._star(tip, view.pitch * float(frond.star_radius) * scale, Color(accent, float(p.star_alpha)))
	view.draw_circle(center, maxf(0.5, view.pitch * float(p.center_radius) * scale), Color(ink, float(p.center_alpha)), true, -1, true)

static func connection(view, spec: Dictionary, context: Dictionary) -> void:
	var edge: Dictionary = context.edge
	var p: Dictionary = spec.params
	var a: Vector2 = view._point(Vector2(edge.a) + Vector2.ONE * 0.5)
	var b: Vector2 = view._point(Vector2(edge.b) + Vector2.ONE * 0.5)
	var curve: Dictionary = view._curve(a, b, view._port_tangent(edge.a, edge.b), view._port_tangent(edge.b, edge.a))
	var ink := Palette.pigment(edge.color)
	var left: float = 1.0 if edge.old else clampf((view.clock - edge.start_a) / Growth.STEP, 0, 1)
	var right: float = 1.0 if edge.old else clampf((view.clock - edge.start_b) / Growth.STEP, 0, 1)
	var wave: float = 0.0 if edge.old else 1 - smoothstep(edge.finish, edge.finish + Growth.RIPPLE, view.clock)
	if left + right >= 1:
		view._vine(curve, 0, 1, ink, wave)
	else:
		view._vine(curve, 0, left, ink, wave)
		view._vine(curve, 1 - right, 1, ink, wave)
	for sprout: Dictionary in Growth.leaf_sprouts(edge):
		var scale: float = view.pop((view.clock - sprout.start) / Growth.LEAF_POP)
		if scale <= 0: continue
		var tangent: Vector2 = view._curve_tangent(curve, sprout.fraction) * sprout.direction
		var normal: Vector2 = Vector2(-tangent.y, tangent.x) * float(sprout.side)
		var direction: Vector2 = (tangent * float(p.leaf_tangent) + normal * float(p.leaf_normal)).normalized()
		view._paint_leaf(view._curve_point(curve, sprout.fraction), direction, view.pitch * float(p.leaf_length), view.pitch * float(p.leaf_width), Color(ink.lightened(float(p.leaf_lightening)), float(p.leaf_alpha)), scale)
	if not edge.old:
		var t: float = (view.clock - edge.finish) / Growth.STAR_POP
		if t > 0 and t < 1:
			view._star(view._curve_point(curve, 0.5) + Vector2(0, -view.pitch * float(p.star_lift) * t), view.pitch * float(p.star_radius) * sin(PI * t), Color(Palette.blossom(edge.color), 1 - t))

static func flower(view, spec: Dictionary, context: Dictionary) -> void:
	var event: Dictionary = context.event
	var p: Dictionary = spec.params
	var progress: float = clampf((view.clock - event.start) / float(spec.animation.duration_seconds), 0, 1)
	if progress <= 0: return
	var center: Vector2 = view._point(Vector2(context.corner))
	var stem := Palette.pigment(event.color)
	var ink := Palette.blossom(event.color)
	var support_scale: float = minf(1, view.pop(progress / float(p.support_finish)))
	var base: Vector2 = center + Vector2(0, view.pitch * float(p.stem_base_y))
	var curve: Dictionary = view._curve(base, center, Vector2(float(p.stem_tangent_x), -1).normalized(), Vector2(0, 1))
	view._vine(curve, 0, support_scale, stem, 0)
	for side: float in [-1.0, 1.0]:
		for i in range(p.support_leaf_y.size()):
			view._paint_leaf(base + Vector2(0, -view.pitch * float(p.support_leaf_y[i])), Vector2(side * float(p.support_leaf_x[i]), float(p.support_leaf_direction_y[i])).normalized(), view.pitch * float(p.support_leaf_length[i]), view.pitch * float(p.support_leaf_width[i]), Color(stem.lightened(float(p.support_leaf_lightening[i])), float(p.support_leaf_alpha[i])), support_scale)
	var scale: float = minf(1, view.pop((progress - float(p.petal_delay)) / float(p.petal_span)))
	var radius: float = view.pitch * float(p.radius) * scale
	if radius < 0.6: return
	for layer in range(int(p.halo_layers)):
		view.draw_circle(center, radius * (float(p.halo_radius) + layer * float(p.halo_step)), Color(ink, float(p.halo_alpha)), true, -1, true)
	for petal in range(int(p.petals)):
		var direction := Vector2.from_angle(petal * TAU / int(p.petals))
		for i in range(p.petal_root.size()):
			view._paint_leaf(center + direction * radius * float(p.petal_root[i]), direction, radius * float(p.petal_length[i]), radius * float(p.petal_width[i]), Color(ink.lightened(float(p.petal_lightening[i])), float(p.petal_alpha[i])))
	view.draw_circle(center, radius * float(p.center_radius), Palette.tile(event.color), true, -1, true)
	for i in range(int(p.stamens)):
		var offset := Vector2.from_angle(i * TAU / int(p.stamens)) * radius * float(p.stamen_distance)
		view.draw_circle(center + offset, maxf(0.35, radius * float(p.stamen_radius)), Color(stem, float(p.stamen_alpha)), true, -1, true)

# Fountain coordinates are source pixels; the marked outlet lands at the 2x2 center.
static var fountains: Dictionary = {}
static func fountain_metadata(path: String) -> Dictionary:
	if not fountains.has(path):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		data.image = path.get_base_dir().path_join(data.image)
		fountains[path] = data
	return fountains[path]

static func fountain_geometry(params: Dictionary, color: int, center: Vector2, pitch: float) -> Dictionary:
	var meta := fountain_metadata(params.sprites[str(color)])
	var canvas := Vector2(meta.canvas_px[0],meta.canvas_px[1])
	var size := Vector2(params.size_cells[0],params.size_cells[1])*pitch*float(meta.scale)
	var ratio := size/canvas
	var origin := center-Vector2(meta.center_px[0],meta.center_px[1])*ratio
	var water: Array = meta.get("water_origin_px",meta.center_px)
	return {"rect": Rect2(origin,size), "water_origin": origin+Vector2(water[0],water[1])*ratio,"image":meta.image}

static func fountain(view, spec: Dictionary, context: Dictionary) -> void:
	if not spec.params.get("enabled", true): return
	var event: Dictionary = context.event
	var progress: float = 1.0 if event.old else clampf((view.clock-event.start)/float(spec.animation.duration_seconds),0.0,1.0)
	if progress <= 0.0: return
	var geometry := fountain_geometry(spec.params,event.color,view._point(Vector2(context.corner)),view.pitch)
	view.draw_texture_rect(FountainAssets.texture(geometry.image),geometry.rect,false,Color(1,1,1,progress))

# Shared aligned sprite placement for tier-two artwork, without palette treatment.
static func sprite_formation(view, spec: Dictionary, context: Dictionary) -> void:
	fountain(view,spec,context)
