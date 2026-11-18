extends SceneTree
const Sets = preload("res://scripts/vines_sets.gd")
const Cells = preload("res://scripts/pattern/cell_sets.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Components = preload("res://scripts/pattern/component_renderer.gd")
const Growth = preload("res://scripts/growth.gd")
const Board = preload("res://scripts/board_view.gd")
const Palette = preload("res://scripts/palette.gd")
const Gallery = preload("res://scripts/gallery.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0
var calls: Array = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: _run.call_deferred()
func probe(_view, spec: Dictionary, context: Dictionary) -> void: calls.append([spec.params.tag, context.tag])
func _run() -> void:
	Palette.select_theme("vines")
	Sets.install()
	check(Sets.tier0.ok and Sets.tier1.ok, "Both live Vines sets validate their registered procedural providers")
	check(Cells.parts_for_role(Sets.tier1, "straight_run_decoration").is_empty(), "No new run-length or decoration policy is invented")
	check(Cells.parts_for_role(Sets.tier1, "vine").connection.provider == "vines.connection", "The live vine role includes existing edge leaves and transient stars")
	check(Sets.centers(0).motif.animation.duration_seconds == Growth.CENTER_POP, "Set center timing preserves the existing growth schedule")
	var alternate: Dictionary = Sets.tier1.duplicate(true)
	alternate.definition.roles.straight = "holding"
	check(Cells.center_parts(5, Sets.tier0, alternate).has("motif") and Sets.centers(5).is_empty(), "Shape roles are selected from data, not a motif-specific branch")
	Components.register_draw_part_provider("test.immediate", probe)
	var renderer := Components.new()
	var parts := {"probe": {"provider": "test.immediate", "params": {"tag": 7}}}
	check(renderer.draw_parts(parts, null, {"tag": 11}) and calls == [[7, 11]], "Common drawing dispatch forwards live part metadata and context")
	var bad: Dictionary = parts.duplicate(true)
	bad.invalid = {"provider": "unknown.procedural"}
	check(not renderer.draw_parts(bad, null) and calls.size() == 1, "An invalid draw batch fails before invoking any provider")
	var parent := Node2D.new()
	check(renderer.ensure("probe", parts.probe, parent) == null and parent.get_child_count() == 0, "Immediate providers cannot silently become node factories")
	parent.free()
	var view := Board.new()
	root.add_child(view)
	view.size = Vector2(540, 540)
	var center := Vector2i(4, 4)
	for palette in range(5):
		Palette.select(palette)
		for color in [1, 2]:
			for mask in range(16):
				var grid := Rules.empty_board(9)
				grid[4][4] = color
				for d in range(4):
					if mask & (1 << d):
						var p: Vector2i = center + Growth.Topology.DIRECTIONS[d]
						grid[p.y][p.x] = color
				view.show_settled(grid)
				check(view.construction_state.records.has("junction/vines/%d/4/4/core" % color) == (mask in [0, 1, 2, 4, 8]), "Shared core overlays appear only on isolated and endpoint cells")
				check(view.construction_state.records.has("vines/cell/%d/4/4" % color), "The diffuse cell wash remains even where the holding motif is suppressed")
				check(Sets.centers(mask).is_empty() == (mask in [5, 10]), "Both straight orientations share the same center omission rule")
	var endpoint := Rules.empty_board(9)
	endpoint[4][3] = 1
	endpoint[4][4] = 1
	view.show_settled(endpoint)
	var original: Dictionary = view.construction_state.records["junction/vines/1/4/4/core"]
	var wave: int = original.created_in
	var straight := endpoint.duplicate(true)
	straight[4][5] = 1
	var edge: Dictionary = view.pattern.edges[0]
	var key := Growth.edge_key(edge.a, edge.b)
	view.direction_by_edge[key].flow = -1
	view.animate_growth(endpoint, straight)
	check(not view.construction_state.records.has("junction/vines/1/4/4/core"), "Continuing an endpoint removes its holding component")
	check(view.direction_by_edge[key].flow == -1, "Existing edge flow choices survive the migration")
	var branch := straight.duplicate(true)
	branch[3][4] = 1
	view.animate_growth(straight, branch)
	var junction_id := "junction/vines/1/4/4/t"
	var record: Dictionary = view.construction_state.records[junction_id]
	check(record.start == 0 and record.phase == "settled" and record.created_in > wave, "A newly required overlay appears on an already reached square")
	check(view.junction_layer.renderer.nodes[junction_id].visible, "New overlay is visible at center arrival")
	view.advance_growth(0.15)
	check(view.junction_layer.renderer.nodes[junction_id].visible, "Direct overlay does not run the removed pop animation")
	view.advance_growth(100)
	check(not view.growing and record.phase == "settled", "Completed motifs release the placement gate")
	var with_other := branch.duplicate(true)
	with_other[0][0] = 2
	var established_wave: int = record.created_in
	view.animate_growth(branch, with_other)
	check(view.construction_state.records[junction_id].created_in == established_wave and view.junction_layer.renderer.nodes[junction_id].visible, "Unrelated placements preserve established motif state without a clock-reset rollback")
	view.show_settled(endpoint, true)
	check(view.construction_state.records["junction/vines/1/4/4/core"].phase == "settled", "Undo/Erase-style restoration shows the settled endpoint immediately")
	var mixed := endpoint.duplicate(true)
	mixed[4][5] = 2
	view.show_settled(mixed)
	check(view.construction_state.records.has("junction/vines/1/4/4/core"), "Different-color contact leaves the first color's endpoint motif intact")
	check(Palette.theme_version() == "1.6" and Gallery.fingerprint(endpoint, 0, "vines", "1.0") != Gallery.fingerprint(endpoint, 0, "vines"), "New Vines appearance saves separately from historical art")
	check(FileAccess.get_file_as_string("res://export_presets.cfg").contains("art/themes/vines/sets/*.json"), "Both sets are packaged in Android exports")
	check(Sets.renderer.diagnostics.is_empty(), "All real Vines drawing batches use valid providers")
	view.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": await check_game()
	print("Vines sets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_game() -> void:
	root.size = Vector2i(720, 1100)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var grid := Rules.empty_board(9)
	for i in range(2, 7):
		grid[4][i] = 1
		grid[i][4] = 1
	for y in [1, 2, 6, 7]:
		for x in [1, 2, 3, 5, 6, 7]: grid[y][x] = 2
	scene.game.board = grid
	scene.game._refresh_over()
	DirAccess.make_dir_recursive_absolute("res://build/vines-sets")
	for palette in range(5):
		Palette.select(palette)
		scene.board_view.show_settled(grid)
		scene._layout()
		scene._refresh()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/vines-sets/palette-%d.png" % palette)
		check(not scene.board_view.construction_state.records.has(Sets.identity(1, Vector2i(3, 4))), "The actual game's straight has no holding motif")
		check(scene.board_view.pattern.flowers.size() == 8 and scene.board_view.pattern.links.size() == 4, "Existing flowers and their higher-tier connections remain available in every palette")
	scene.gallery.directory = "user://vines-sets-%d" % Time.get_ticks_usec()
	check(scene._can_save(), "The normal game allows saving the symmetric design")
	await scene._save_design()
	var entries: Array = scene.gallery.entries()
	check(entries.size() == 1 and entries[0].theme == "vines" and entries[0].theme_version == "1.2", "The normal gallery records the new set-driven appearance")
	if not entries.is_empty(): scene.gallery.picture(entries[0]).get_image().save_png("res://build/vines-sets/artwork.png")
	for f: String in DirAccess.open(scene.gallery.directory).get_files(): DirAccess.remove_absolute(scene.gallery.directory.path_join(f))
	DirAccess.remove_absolute(scene.gallery.directory)
	scene.queue_free()
	await process_frame
