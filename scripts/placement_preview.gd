extends RefCounted

# Predict the visible board, including overlapping and clipped floating cells.
# This never grants placement permission or changes the committed game.
static func board(committed: Array, cells: Array, anchor: Vector2i, color: int, active: bool) -> Array:
	if not active or cells.is_empty(): return committed
	var predicted := committed.duplicate(true)
	for offset: Vector2i in cells:
		var cell := anchor+offset
		if cell.x >= 0 and cell.y >= 0 and cell.x < committed.size() and cell.y < committed.size():
			predicted[cell.y][cell.x] = color
	return predicted
