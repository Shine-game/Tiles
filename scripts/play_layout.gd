extends RefCounted

const Geometry = preload("res://scripts/piece_geometry.gd")
const Rules = preload("res://scripts/rules.gd")
const MIN_CONTROL_SIDE := 28.0
const BOARD_FRAME := 28.0

static func portrait(view: Vector2, pixel_scale: float, tray_inset: float) -> Dictionary:
	var margin := 10.0 / pixel_scale
	var border := 50.0 / pixel_scale
	var board_side := maxf(1.0, view.x - 2 * margin)
	var free_height := maxf(0.0, view.y - board_side)
	var top_surface := free_height * 0.6
	var bottom_surface := free_height - top_surface

	var button_gap := 20.0 / pixel_scale
	var row_gap := minf(button_gap, maxf(0.0, (top_surface - 3 * 16.0) / 2.0))
	var top_border := minf(border, maxf(0.0, (top_surface - 3 * MIN_CONTROL_SIDE - 2 * row_gap) / 2.0))
	var header_height := top_surface - 2 * top_border
	# Leave the central tray wide enough for the longest offered piece.
	var column_limit := maxf(1.0, (view.x - 2 * tray_inset - board_side * 0.5) / 2.0)
	var control_side := minf(column_limit, (header_height - 2 * row_gap) / 3.0)
	var bottom_border := minf(border, maxf(0.0, (bottom_surface - 40.0) / 2.0))
	var dock_gap := minf(button_gap, view.x / 6.0)
	var dock_width := view.x - 2 * margin - 2 * dock_gap
	var dock_side := minf(dock_width / 3.0, bottom_surface - 2 * bottom_border)
	return {
		"board_side": board_side,
		"header_top": top_border,
		"header_height": header_height,
		"control_side": control_side,
		"dock_side": dock_side,
		"dock_padding": (view.x - 3 * dock_side - 2 * dock_gap) / 2.0,
		"dock_gap": dock_gap,
		"upper_gap": top_border,
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
