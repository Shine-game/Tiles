class_name TileGame
extends RefCounted

const Rules = preload("res://scripts/rules.gd")
var board: Array
var queue: Array = []
var index := 0
var moves := 0
var history: Array = []
var over := false
var lost := false
var symmetry_blocked := false
var no_space := false
var current_color := Rules.BLUE
var restored_cells: Array = []
var undo_left := 3
var skip_left := 3
var erase_left := 3
var rng := RandomNumberGenerator.new()

func _init(n: int = 9, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	board = Rules.create_board(n)
	queue.append(_draw_piece())
	_refresh_over()

# Categories, then shapes, are uniform among those with a physical fit.
# Never filter by symmetry: a physically fitting piece may legitimately end play.
func eligible_groups() -> Array:
	var groups: Array = [[], [], [], []]
	for name: String in Rules.PIECES:
		var definition: Dictionary = Rules.PIECES[name]
		if not Rules.first_physical_move(board, definition).is_empty():
			groups[definition.cells.size() - 1].append(name)
	return groups.filter(func(group: Array): return not group.is_empty())

func _choose_from_groups(groups: Array) -> String:
	if groups.is_empty():
		return ""
	var group: Array = groups[rng.randi_range(0, groups.size() - 1)]
	return group[rng.randi_range(0, group.size() - 1)]

func _draw_piece(exclude: String = "") -> String:
	var groups: Array = eligible_groups()
	if not exclude.is_empty():
		var alternatives: Array = []
		for group: Array in groups:
			var filtered: Array = group.filter(func(name: String): return name != exclude)
			if not filtered.is_empty():
				alternatives.append(filtered)
		if not alternatives.is_empty():
			groups = alternatives
	return _choose_from_groups(groups)

func piece() -> Dictionary:
	return {"cells": [] if queue[index] == "" else (restored_cells if not restored_cells.is_empty() else Rules.PIECES[queue[index]].cells), "color": current_color}

func place(cells: Array, anchor: Vector2i) -> Dictionary:
	if over:
		return {"ok": false, "reason": "No safe placements remain. Go back or start a new garden."}
	var physical: Dictionary = Rules.physical_placement(board, cells, anchor)
	if not physical.ok:
		return physical
	var result: Dictionary = Rules.placement(board, cells, piece().color, anchor)
	history.append({"name": queue[index], "color": current_color, "cells": cells.duplicate(), "anchor": anchor})
	if history.size() > 3:
		history.pop_front()
	moves += 1
	restored_cells = []
	board = board.duplicate(true)
	for cell: Vector2i in cells:
		board[anchor.y + cell.y][anchor.x + cell.x] = current_color
	lost = not result.ok
	index += 1
	# An offer set aside by Undo stays next if it still physically fits.
	if index >= queue.size() or queue[index] == "" or Rules.first_physical_move(board, Rules.PIECES[queue[index]]).is_empty():
		queue.resize(index)
		queue.append(_draw_piece())
	_refresh_over()
	return {"ok": true, "lost": lost, "board": board}

func undo() -> bool:
	if history.is_empty() or undo_left <= 0:
		return false
	var previous: Dictionary = history.pop_back()
	board = board.duplicate(true)
	# Remove only that piece's squares. Later erasures must not be resurrected.
	for offset: Vector2i in previous.cells:
		var cell: Vector2i = previous.anchor + offset
		board[cell.y][cell.x] = 0
	queue.insert(index, previous.name)
	current_color = previous.color
	restored_cells = previous.cells.duplicate()
	moves -= 1
	undo_left -= 1
	lost = not Rules.symmetry_states(board).any(func(state: Dictionary): return state.possible)
	_refresh_over()
	return true

func skip() -> bool:
	if over or skip_left <= 0:
		return false
	var replacement := _draw_piece(queue[index])
	if replacement.is_empty():
		return false
	queue[index] = replacement
	restored_cells = []
	skip_left -= 1
	_refresh_over()
	return true

func erase(cell: Vector2i) -> bool:
	if erase_left <= 0 or cell.x < 0 or cell.y < 0 or cell.x >= board.size() or cell.y >= board.size() or board[cell.y][cell.x] == 0:
		return false
	board = board.duplicate(true)
	board[cell.y][cell.x] = 0
	erase_left -= 1
	# Helpers can reopen an ended garden; remaining fragments need not touch.
	lost = not Rules.symmetry_states(board).any(func(state: Dictionary): return state.possible)
	if queue[index] == "":
		queue[index] = _draw_piece()
	_refresh_over()
	return true

func _refresh_over() -> void:
	no_space = queue[index] == "" or not board.any(func(row: Array): return row.has(0))
	symmetry_blocked = not no_space and Rules.first_legal_move(board, piece()).is_empty()
	over = lost or no_space
