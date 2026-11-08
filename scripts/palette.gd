class_name TilePalette
extends RefCounted

# Keep stable logical IDs; the flora palette now uses green and yellow.
const BLUE := Color("159864")
const CORAL := Color("e5b52c")
const INVALID := Color("96999c")
const INVALID_BORDER := Color("6f7377")

static func tile(color: int) -> Color:
	return BLUE if color == 1 else CORAL

static func accent(color: int) -> Color:
	return CORAL if color == 1 else BLUE
