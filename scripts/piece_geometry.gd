extends RefCounted
const Rules = preload("res://scripts/rules.gd")

static func extent(cells: Array) -> Vector2i:
	var result := Vector2i.ZERO
	for cell: Vector2i in cells: result = result.max(cell+Vector2i.ONE)
	return result

static func laying(cells: Array) -> Array:
	var bounds := extent(cells)
	return Rules.rotate(cells) if bounds.y > bounds.x else cells.duplicate()

static func tray(cells: Array, bounds: Rect2, cell_pitch: float) -> Dictionary:
	var shape := extent(cells)
	if shape == Vector2i.ZERO: return {"origin":bounds.get_center(),"unit":maxf(1,cell_pitch),"scale":1.0}
	var unit := cell_pitch if cell_pitch > 0 else minf(51,minf(bounds.size.x/shape.x,bounds.size.y/shape.y))
	var origin := bounds.position+(bounds.size-Vector2(shape)*unit)/2
	# Tall rotations extend downward without moving the board or shrinking tiles.
	origin.y = maxf(bounds.position.y,origin.y)
	return {"origin":origin,"unit":unit,"scale":1.0}

static func board_cell(point: Vector2, origin: Vector2, pitch: float) -> Vector2i:
	var local := (point-origin)/pitch
	return Vector2i(floori(local.x),floori(local.y))

static func hit(cells: Array, point: Vector2, origin: Vector2, pitch: float) -> Vector2i:
	var cell := board_cell(point,origin,pitch)
	return cell if cell in cells else Vector2i(-1,-1)

static func anchor(point: Vector2, origin: Vector2, pitch: float, grabbed: Vector2i) -> Vector2i:
	return board_cell(point,origin,pitch)-grabbed
