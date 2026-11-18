extends SceneTree
const Fingers = preload("res://scripts/pattern/animated_fingers.gd")
const Board = preload("res://scripts/board_view.gd")
const Palette = preload("res://scripts/palette.gd")
const Rules = preload("res://scripts/rules.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize(): run.call_deferred()
func run():
	var data := Fingers.definition()
	for variant in data.variants:
		for path in variant:
			var texture = Fingers.frame_texture({"variant": data.variants.find(variant), "period": 1.0, "phase": 0.0}, variant.find(path)*0.25)
			check(texture != null and texture.get_size() == Vector2(122,174), "Frame canvas remains aligned")
	var sample := {"period": 1.0, "phase": 0.0}
	for i in range(5): check(Fingers.frame_index(sample,i*0.25) == [0,1,2,1,0][i], "Ping-pong loop")
	Palette.select_theme("coral_reef")
	var view = Board.new()
	view.size = Vector2(600,600)
	root.add_child(view)
	for vertical in [false,true]:
		var empty = Rules.empty_board(7)
		var board = empty.duplicate(true)
		for y in range(3 if vertical else 2):
			for x in range(2 if vertical else 3): board[y+2][x+2] = 1
		view.show_settled(board)
		check(view.pattern.unions.size() == 1, "One linked formation")
		check(view.coral_visuals.finger_events.size() == 8, "Eight rays replace old tier-three artwork")
		for id in view.coral_visuals.finger_events:
			var event: Dictionary = view.coral_visuals.finger_events[id]
			var choice: Dictionary = event.animated_finger
			check(choice.period >= 0.8 and choice.period <= 1.2, "Cycle duration range")
			var spec := Fingers.render_spec(event)
			check((spec.source_transform * Vector2(61,153)).distance_to(choice.origin_cells*256) < 0.001, "Anchor remains fixed under mirroring and rotation")
			check(view.coral_visuals.registry[id].visible, "Settled fingers visible")
		view.show_settled(empty)
		check(view.coral_visuals.finger_events.is_empty(), "Undo removes animation bindings")
		view.animate_growth(empty,board)
		view.set_process(false)
		view.advance_growth(100)
		check(not view.growing, "Continuous animation does not block construction completion")
		for id in view.coral_visuals.finger_events: check(view.coral_visuals.registry[id].visible, "Growing fingers become visible")
		view.coral_visuals._process(0.3)
		for row in board:
			for x in range(row.size()):
				if row[x] == 1: row[x] = 2
		view.show_settled(board)
		check(view.coral_visuals.finger_events.is_empty(), "Teal retains legacy artwork")
	view.queue_free()
	print("Animated coral fingers: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
