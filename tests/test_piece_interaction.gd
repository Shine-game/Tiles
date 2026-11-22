extends SceneTree
const Gesture = preload("res://scripts/piece_gesture.gd")
const Geometry = preload("res://scripts/piece_geometry.gd")
const Preview = preload("res://scripts/placement_preview.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func touch(point: Vector2, pressed: bool, id: int = 0, canceled: bool = false) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	event.index = id
	event.canceled = canceled
	return event

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var cells := [Vector2i.ZERO,Vector2i.DOWN,Vector2i.ONE]
	var bounds := Rect2(80,20,180,60)
	var layout := Geometry.tray(cells,bounds,40)
	check(layout.unit == 40 and layout.origin == Vector2(130,20),"Tray retains full-size squares and clamps tall shape above the board")
	for cell: Vector2i in cells:
		check(Geometry.hit(cells,layout.origin+(Vector2(cell)+Vector2.ONE/2)*40,layout.origin,40) == cell,"Every occupied square can be grabbed")
	check(Geometry.hit(cells,layout.origin+Vector2(60,20),layout.origin,40).x < 0,"An empty hole never picks up the piece")
	check(Geometry.anchor(Vector2(130,130),Vector2(10,10),40,Vector2i.ONE) == Vector2i(2,2),"Dragging retains the grabbed-square offset")
	check(Geometry.board_cell(Vector2(9.9,9.9),Vector2(10,10),40) == Vector2i(-1,-1),"Coordinates outside the top-left floor correctly")
	check(Geometry.extent(Geometry.laying([Vector2i.ZERO,Vector2i.DOWN,Vector2i(0,2)])) == Vector2i(3,1),"Offered pieces lie horizontally")
	var pick := func(point):
		var cell := Geometry.hit(cells,point,layout.origin,40)
		return {} if cell.x < 0 else {"cell":cell,"from_tray":true}
	var start: Vector2 = layout.origin+Vector2(20,20)
	var gesture = Gesture.new()
	check(not gesture.handle(touch(start,true,2),pick).is_empty() and gesture.active,"First finger may have any pointer ID")
	check(gesture.handle(touch(start,false,7),pick).is_empty() and gesture.active,"Other finger cannot release an active gesture")
	check(gesture.handle(touch(start,true,7),pick).is_empty() and gesture.pointer_id == 2,"Second finger cannot replace the active pointer")
	check(gesture.handle(touch(start,false,2),pick).tap and not gesture.active,"A short stationary release taps exactly once")
	gesture.handle(touch(start,true),pick)
	gesture.tick(0.5)
	check(not gesture.handle(touch(start,false),pick).tap,"A long hold never rotates")
	gesture.handle(touch(start,true),pick)
	gesture.tick(0.5)
	var move := InputEventScreenDrag.new()
	move.position = start+Vector2(60,80)
	var moved: Dictionary = gesture.handle(move,pick)
	check(moved.moving and moved.started and moved.from_tray,"Moving after a hold starts a drag, not a tap")
	var released: Dictionary = gesture.handle(touch(move.position,false),pick)
	check(released.moving and not released.tap and released.released,"Drag release leaves placement to the Place action")
	gesture.handle(touch(start,true),pick)
	var canceled: Dictionary = gesture.handle(touch(start+Vector2(80,0),false,0,true),pick)
	check(canceled.canceled and not canceled.tap and not canceled.moving and not gesture.active,"System cancellation never rotates or moves on release")
	check(gesture.handle(touch(layout.origin+Vector2(60,20),true),pick).is_empty(),"A target or hole cannot start a drag")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = start
	mouse.device = -1
	check(gesture.handle(mouse,pick).is_empty(),"Touch-emulated mouse input is ignored")
	mouse.device = 0
	gesture.handle(mouse,pick)
	mouse.pressed = false
	check(gesture.handle(mouse,pick).tap,"Real mouse uses the same tap classifier")
	var erase_pick := func(_point):return {"cell":Vector2i(1,1),"tool":"erase"}
	var pressed: Dictionary = gesture.handle(touch(start,true),erase_pick)
	check(pressed.tool == "erase" and not pressed.released,"Erase does not commit on press")
	check(gesture.handle(touch(start,false),erase_pick).released,"Erase is confirmed on release")
	var grid := Rules.empty_board(5)
	for row: Array in grid: row.fill(1)
	var predicted := Preview.board(grid,[Vector2i.ZERO],Vector2i(0,2),2,true)
	var states := Rules.symmetry_states(predicted)
	check(not states[0].possible and not states[0].complete and states[1].complete,"Overlapping visible colors update axes even when placement is invalid")
	check(grid[2][0] == 1 and predicted[2][0] == 2,"Preview never modifies committed cells")
	var clipped := Preview.board(grid,[Vector2i.ZERO,Vector2i.RIGHT],Vector2i(-1,2),2,true)
	check(clipped == predicted,"Partially off-board pieces predict only their visible cells")
	check(Preview.board(grid,cells,Vector2i.ZERO,2,false) == grid,"No active hover restores the committed board")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.size = Vector2(540, 900)
	scene._layout()
	scene.cells = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0)]
	var view = scene.board_view
	var left: Rect2 = scene.erase_button.get_global_rect()
	var right: Rect2 = scene.palette_button.get_global_rect()
	var gap: float = view.field.size.x / 18.0
	for button_rect in [left, right]:
		scene._drag_to(button_rect.get_center())
		scene._rotate()
		scene._flip()
		var face: Vector2 = scene.floating_piece.origin - Vector2(0, scene.floating_piece.lift())
		var width: float = Geometry.extent(scene.cells).x * view.pitch
		check(face.x >= left.end.x + gap - 0.01 and face.x + width <= right.position.x - gap + 0.01,
			"Drag, rotate and flip keep the whole piece clear of the upper buttons")
		check(not scene.piece_on_board, "Moving through the upper zone leaves the board unlocked")
	var board_transform: Transform2D = view.get_global_transform_with_canvas()
	scene._drag_to(board_transform * view._point(Vector2(4.5, 1.5)))
	check(scene.piece_on_board, "The first fully on-board move locks the offer to the board")
	for destination in [Vector2(-2, -3), Vector2(12, 14)]:
		scene._drag_to(board_transform * view._point(destination))
		scene._rotate()
		scene._flip()
		check(scene._board_anchors(scene.cells).has_point(scene.selected),
			"Dragging beyond a board corner and transforming keeps every square on the field")
	scene._clear_selection()
	check(not scene.piece_on_board, "Clearing the offer resets the board lock")
	scene.queue_free()
	print("Piece interaction: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
