extends RefCounted
const TAP_LIMIT := 0.25
const SLOP := 10.0
var active := false
var pointer_id := -1
var age := 0.0
var mode := "pending"
var start := Vector2.ZERO
var grabbed := Vector2i.ZERO
var from_tray := false
var tool := "piece"

static func pointer(event: InputEvent) -> Dictionary:
	if event is InputEventMouseButton:
		if event.device == -1 or event.button_index != MOUSE_BUTTON_LEFT: return {}
		return {"point":event.position,"id":-1,"kind":"press" if event.pressed else "release","canceled":false}
	if event is InputEventMouseMotion:
		if event.device == -1: return {}
		return {"point":event.position,"id":-1,"kind":"move","canceled":false}
	if event is InputEventScreenTouch:
		return {"point":event.position,"id":event.index,"kind":"press" if event.pressed else "release","canceled":event.canceled}
	if event is InputEventScreenDrag:
		return {"point":event.position,"id":event.index,"kind":"move","canceled":false}
	return {}

func begin(point: Vector2, id: int, selection: Dictionary) -> bool:
	if active or selection.is_empty(): return false
	active = true
	pointer_id = id
	age = 0
	mode = "pending"
	start = point
	grabbed = selection.cell
	from_tray = selection.get("from_tray",false)
	tool = selection.get("tool","piece")
	return true

func tick(delta: float) -> void:
	if active: age += delta

func cancel() -> void:
	active = false
	mode = "pending"
	age = 0

func move(point: Vector2, id: int) -> Dictionary:
	if not active or id != pointer_id: return {}
	var started := mode == "pending" and point.distance_to(start) >= SLOP
	if started: mode = "move"
	return {"point":point,"moving":mode == "move","started":started,"released":false,"canceled":false,"tap":false,"tool":tool,"grabbed":grabbed,"from_tray":from_tray}

func finish(point: Vector2, id: int, canceled: bool = false) -> Dictionary:
	if not active or id != pointer_id: return {}
	var result := move(start if canceled else point,id)
	result.point = point
	result.released = true
	result.canceled = canceled
	result.tap = not canceled and mode == "pending" and age <= TAP_LIMIT
	if canceled: result.moving = false
	active = false
	return result

# Only picking a target and consuming the result depend on the active view.
func handle(event: InputEvent, pick: Callable) -> Dictionary:
	var p := pointer(event)
	if p.is_empty(): return {}
	if p.kind == "press":
		if active or p.canceled: return {}
		var selection: Dictionary = pick.call(p.point)
		if not begin(p.point,p.id,selection): return {}
		return move(p.point,p.id)
	if p.kind == "move": return move(p.point,p.id)
	return finish(p.point,p.id,p.canceled)
