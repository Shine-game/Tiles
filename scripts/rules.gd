class_name TileRules
extends RefCounted

# Colors belong to cells, independently of the pieces that supplied them.
const BLUE = 1
const CORAL = 2
const PIECES = {
	"Dot": {"cells": [Vector2i(0, 0)]},
	"Domino": {"cells": [Vector2i(0, 0), Vector2i(1, 0)]},
	"I3": {"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]},
	"L3": {"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	"I": {"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
	"O": {"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	"S": {"cells": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	"T": {"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]},
	"J": {"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
	"L": {"cells": [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
	"Z": {"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]},
}
const SYMMETRY_NAMES = ["Vertical", "Horizontal", "Diagonal /", "Diagonal \\", "90 degrees", "180 degrees", "270 degrees"]

static func empty_board(n: int) -> Array:
	var board: Array = []
	for y in range(n):
		var row: Array = []
		row.resize(n)
		row.fill(0)
		board.append(row)
	return board

static func create_board(n: int = 9) -> Array:
	var board: Array = empty_board(n)
	board[n / 2][n / 2] = BLUE
	return board

static func rotate(cells: Array) -> Array:
	var result: Array = []
	var minimum := Vector2i(100, 100)
	for cell: Vector2i in cells:
		var turned := Vector2i(-cell.y, cell.x)
		result.append(turned)
		minimum = minimum.min(turned)
	for i in range(result.size()):
		result[i] -= minimum
	return result

static func flip(cells: Array) -> Array:
	var result: Array = []
	var max_x := 0
	for cell: Vector2i in cells:
		max_x = maxi(max_x, cell.x)
	for cell: Vector2i in cells:
		result.append(Vector2i(max_x - cell.x, cell.y))
	return result

static func transform(cell: Vector2i, symmetry: int, n: int) -> Vector2i:
	match symmetry:
		0: return Vector2i(n - 1 - cell.x, cell.y)
		1: return Vector2i(cell.x, n - 1 - cell.y)
		2: return Vector2i(n - 1 - cell.y, n - 1 - cell.x)
		3: return Vector2i(cell.y, cell.x)
		4: return Vector2i(n - 1 - cell.y, cell.x)
		5: return Vector2i(n - 1 - cell.x, n - 1 - cell.y)
		_: return Vector2i(cell.y, n - 1 - cell.x)

static func symmetry_states(board: Array) -> Array:
	var n: int = board.size()
	var result: Array = []
	for symmetry in range(7):
		var possible := true
		var complete := true
		for y in range(n):
			for x in range(n):
				var start := Vector2i(x, y)
				var cell := start
				var color := 0
				# Whole orbits are required: quarter-turn conflicts can be
				# separated by empty squares, so checking neighbors is insufficient.
				while true:
					var value: int = board[cell.y][cell.x]
					if value != 0:
						if color != 0 and value != color:
							possible = false
						color = value
					cell = transform(cell, symmetry, n)
					if cell == start:
						break
				var partner := transform(start, symmetry, n)
				if board[y][x] != board[partner.y][partner.x]:
					complete = false
		result.append({"possible": possible, "complete": complete})
	return result

static func placement(board: Array, cells: Array, color: int, anchor: Vector2i) -> Dictionary:
	var n: int = board.size()
	var touching := false
	for offset: Vector2i in cells:
		var cell := anchor + offset
		if cell.x < 0 or cell.y < 0 or cell.x >= n or cell.y >= n:
			return {"ok": false, "reason": "Keep the whole piece inside the garden."}
		if board[cell.y][cell.x] != 0:
			return {"ok": false, "reason": "Choose empty squares for your piece."}
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var neighbor := cell + Vector2i(dx, dy)
				if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < n and neighbor.y < n:
					if board[neighbor.y][neighbor.x] != 0:
						touching = true
	if not touching:
		return {"ok": false, "reason": "Touch an existing tile at an edge or corner."}
	var next: Array = board.duplicate(true)
	for offset: Vector2i in cells:
		var cell := anchor + offset
		next[cell.y][cell.x] = color
	for state: Dictionary in symmetry_states(next):
		if state.possible:
			return {"ok": true, "board": next}
	return {"ok": false, "reason": "This closes every path to symmetry. Try another position."}

# Search every player-selectable variant before declaring game over.
# The optional restrictions support focused tests and future rule variants.
static func first_legal_move(board: Array, piece: Dictionary, allow_color_change: bool = true, allow_flip: bool = true) -> Dictionary:
	var preferred_color: int = piece.get("color", BLUE)
	var colors: Array = [preferred_color]
	if allow_color_change:
		colors.append(CORAL if preferred_color == BLUE else BLUE)
	var seen: Dictionary = {}
	for mirrored in range(2 if allow_flip else 1):
		var cells: Array = flip(piece.cells) if mirrored else piece.cells
		for rotation in range(4):
			var key: Array = []
			for cell: Vector2i in cells:
				key.append(cell.y * 8 + cell.x)
			key.sort()
			if not seen.has(key):
				seen[key] = true
				for color: int in colors:
					for y in range(board.size()):
						for x in range(board.size()):
							var anchor := Vector2i(x, y)
							if placement(board, cells, color, anchor).ok:
								return {"anchor": anchor, "cells": cells, "rotation": rotation, "flipped": bool(mirrored), "color": color}
			cells = rotate(cells)
	return {}
