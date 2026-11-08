class_name TilePalette
extends RefCounted

const BLUE := Color("168bff")
const CORAL := Color("ff4d6d")
const INVALID := Color("96999c")
const INVALID_BORDER := Color("6f7377")

static func tile(color: int) -> Color:
	return BLUE if color == 1 else CORAL
