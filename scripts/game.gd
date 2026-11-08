class_name TileGame
extends RefCounted

const Rules = preload("res://scripts/rules.gd")
var board: Array
var queue: Array = []
var index := 0
var moves := 0
var history: Array = []
var over := false
var current_color := Rules.BLUE
var restored_cells: Array = []
var rng := RandomNumberGenerator.new()

func _init(n: int = 9, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	board = Rules.create_board(n)
	_add_bag()
	_refresh_over()

func _add_bag() -> void:
	var bag: Array = Rules.PIECES.keys()
	for i in range(bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = bag[i]
		bag[i] = bag[j]
		bag[j] = swap
	queue.append_array(bag)

func piece() -> Dictionary:
	return {"cells": Rules.PIECES[queue[index]].cells, "color": current_color}

func place(cells: Array, anchor: Vector2i) -> Dictionary:
	if over:
		return {"ok": false, "reason": "No safe placements remain. Go back or start a new garden."}
	var result: Dictionary = Rules.placement(board, cells, piece().color, anchor)
	if not result.ok:
		return result
	history.append({"board": board, "index": index, "moves": moves, "color": current_color, "cells": cells.duplicate()})
	if history.size() > 3:
		history.pop_front()
	board = result.board
	moves += 1
	index += 1
	if index == queue.size():
		_add_bag()
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
	_refresh_over()
	return true

func _refresh_over() -> void:
	over = Rules.first_legal_move(board, piece()).is_empty()
