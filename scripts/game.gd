class_name TileGame
extends RefCounted

const Rules = preload("res://scripts/rules.gd")
var board: Array
var queue: Array = []
var index := 0
var moves := 0
var history: Array = []
var over := false
var no_space := false
var current_color := Rules.BLUE
var restored_cells: Array = []
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

func _draw_piece() -> String:
	return _choose_from_groups(eligible_groups())

func piece() -> Dictionary:
	return {"cells": [] if queue[index] == "" else Rules.PIECES[queue[index]].cells, "color": current_color}

func place(cells: Array, anchor: Vector2i) -> Dictionary:
	if over:
		return {"ok": false, "reason": "No safe placements remain. Go back or start a new garden."}
	var result: Dictionary = Rules.placement(board, cells, piece().color, anchor)
	if not result.ok:
		return result
	history.append({"board": board, "index": index, "moves": moves, "color": current_color, "cells": cells.duplicate(), "rng_state": rng.state})
	if history.size() > 3:
		history.pop_front()
	board = result.board
	moves += 1
	index += 1
	# Future draws depend on the resulting board; discard any abandoned branch.
	queue.resize(index)
	queue.append(_draw_piece())
	_refresh_over()
	return result

func undo() -> bool:
	if history.is_empty():
		return false
	var previous: Dictionary = history.pop_back()
	board = previous.board
	index = previous.index
	moves = previous.moves
	current_color = previous.color
	restored_cells = previous.cells
	rng.state = previous.rng_state
	queue.resize(index + 1)
	_refresh_over()
	return true

func _refresh_over() -> void:
	no_space = queue[index] == ""
	over = no_space or Rules.first_legal_move(board, piece()).is_empty()
