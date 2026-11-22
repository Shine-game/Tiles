extends RefCounted

const Geometry = preload("res://scripts/piece_geometry.gd")
const Rules = preload("res://scripts/rules.gd")
const BOARD_FRAME := 28.0

static func portrait(view: Vector2, pixel_scale: float, side_safe_area: float) -> Dictionary:
	var margin := 10.0 / pixel_scale
	var board_side := maxf(1.0, view.x - 2 * margin)
	var free_height := maxf(0.0, view.y - board_side)
	var top_surface := free_height * 0.6
	var bottom_surface := free_height - top_surface
	var square := maxf(1.0, board_side - BOARD_FRAME) / 9.0
	# Near-square windows can be too short even for the requested gaps alone.
	var clearance := minf(square / 4.0, minf(top_surface / 5.0, bottom_surface / 3.0))
	var side_inset := maxf(clearance, side_safe_area)
	var header_height := top_surface - 2 * clearance
	var max_top_side := (header_height - 2 * clearance) / 3.0
	var max_bottom_side := minf(bottom_surface - 2 * clearance, (view.x - 2 * side_inset - 2 * clearance) / 3.0)
	var scale := clampf(minf(max_top_side / square, max_bottom_side / (2 * square)), 0.0, 1.0)
	var control_side := square * scale
	var dock_side := 2 * control_side
	return {
		"board_side": board_side,
		"header_top": clearance,
		"header_height": header_height,
		"control_side": control_side,
		"controls_left": side_inset,
		"tray_gap": clearance,
		"dock_side": dock_side,
		"dock_padding": side_inset,
		"dock_gap": (view.x - 2 * side_inset - 3 * dock_side) / 2.0,
		"upper_gap": clearance,
		"board_to_dock_gap": (bottom_surface - dock_side) / 2.0,
	}

static func measure_landscape(view: Vector2, safe: Vector4, edge: float, gap: float, board_size: int) -> Dictionary:
	var control_side := clampf(view.y * 0.09, 28, 48)
	var dock_side := clampf(view.y * 0.14, 40, 64)
	var dock_padding := (view.x - 3 * dock_side) / 6.0
	var board_gap := minf(dock_padding, minf(safe.w, view.y * 0.015))
	var available_height := view.y - safe.y - dock_side - 2 * board_gap - gap
	var full_width := maxf(1, view.x - 2 * edge)
	var extent := Vector2i.ONE
	for definition: Dictionary in Rules.PIECES.values():
		var bounds := Geometry.extent(definition.cells)
		extent = extent.max(Vector2i(maxi(bounds.x, bounds.y), mini(bounds.x, bounds.y)))

	var preview_width := maxf(1, view.x - 2 * (maxf(safe.x, safe.z) + control_side + 2 * gap))
	var available_header := maxf(0, available_height - 2 * gap)
	var vertical_limit := minf(
		available_header - 3 * control_side,
		(available_header * board_size + BOARD_FRAME * extent.y) / (board_size + extent.y)
	)
	var horizontal_limit := BOARD_FRAME + preview_width * board_size / extent.x
	var board_side := maxf(1, minf(full_width, minf(vertical_limit, horizontal_limit)))
	var header_height := maxf(0, available_height - board_side)
	control_side = clampf((header_height - 2 * gap) / 3.0, 0, control_side)

	return {
		"board_side": board_side,
		"header_top": safe.y,
		"header_height": header_height,
		"control_side": control_side,
		"dock_side": dock_side,
		"dock_padding": dock_padding,
		"dock_gap": 2 * dock_padding,
		"upper_gap": gap,
		"board_to_dock_gap": board_gap,
	}
