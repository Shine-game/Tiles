extends RefCounted

const Geometry = preload("res://scripts/piece_geometry.gd")
const Rules = preload("res://scripts/rules.gd")
const MIN_CONTROL_SIDE := 28.0
const BOARD_FRAME := 28.0

static func measure(view: Vector2, safe: Vector4, edge: float, gap: float, board_size: int) -> Dictionary:
	var portrait := view.y >= view.x
	var control_side := clampf(view.x * 0.112, 36, 72) if portrait else clampf(view.y * 0.09, 28, 48)
	var dock_side := clampf(view.x * 0.225, 56, 128) if portrait else clampf(view.y * 0.14, 40, 64)
	var dock_padding := (view.x - 3 * dock_side) / 6.0
	var dock_vertical_padding := safe.w if portrait else minf(dock_padding, minf(safe.w, view.y * 0.015))
	var upper_gap := maxf(12.0, gap) if portrait else gap
	var board_gap := upper_gap if portrait else dock_vertical_padding
	var available_height := view.y - safe.y - dock_side - dock_vertical_padding - board_gap - upper_gap
	var full_width := maxf(1, view.x - 2 * edge)
	var extent := Vector2i.ONE
	for definition: Dictionary in Rules.PIECES.values():
		var bounds := Geometry.extent(definition.cells)
		extent = extent.max(Vector2i(maxi(bounds.x, bounds.y), mini(bounds.x, bounds.y)))

	# In portrait, compact the header before giving up full board width.
	var fit_control_side := MIN_CONTROL_SIDE if portrait else control_side
	var preview_width := maxf(1, view.x - 2 * (maxf(safe.x, safe.z) + fit_control_side + 2 * gap))
	var available_header := maxf(0, available_height - 2 * gap)
	var vertical_limit := minf(
		available_header - 3 * fit_control_side,
		(available_header * board_size + BOARD_FRAME * extent.y) / (board_size + extent.y)
	)
	var horizontal_limit := BOARD_FRAME + preview_width * board_size / extent.x
	var board_side := maxf(1, minf(full_width, minf(vertical_limit, horizontal_limit)))
	if portrait and available_header - full_width >= 3 * MIN_CONTROL_SIDE:
		board_side = full_width
	var header_height := maxf(0, available_height - board_side)
	control_side = clampf((header_height - 2 * gap) / 3.0, 0, control_side)
	if portrait:
		var tray_height := extent.y * maxf(1, (board_side - BOARD_FRAME) / board_size) + 2 * gap
		var preferred_header := maxf(3 * control_side + 2 * gap, tray_height)
		var spacing := maxf(0, header_height - preferred_header) / 2.0
		header_height -= 2 * spacing
		upper_gap += spacing
		board_gap += spacing

	return {
		"board_side": board_side,
		"header_height": header_height,
		"control_side": control_side,
		"dock_side": dock_side,
		"dock_padding": dock_padding,
		"upper_gap": upper_gap,
		"board_to_dock_gap": board_gap,
	}
