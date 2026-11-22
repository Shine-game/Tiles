extends SceneTree
const Assembly = preload("res://scripts/pattern/assembly.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Renderer = preload("res://scripts/pattern/component_renderer.gd")
const Coral = preload("res://scripts/coral_sets.gd")
const Clock = preload("res://scripts/clockwork_sets.gd")
const Topology = preload("res://scripts/pattern/topology.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	Coral.install()
	Clock.install()
	var part: Dictionary = {"asset":Assets.select_variant(Clock.vine().asset,"copper"),"pivot_px":[128,128],"scale":[0.7,0.7],"anchor":"shared_edge_midpoint","canonical_port":0,"flip_h_ports":["S","W"]}
	var original: Dictionary = part.duplicate(true)
	var texture: Texture2D
	for d in range(4):
		var cell := Vector2i(3, 5)
		var spec := Assembly.on_port(part, cell, d)
		spec.asset_root = Clock.ROOT
		var node := Renderer.sprite(spec)
		if texture == null: texture = node.texture
		check(node.texture == texture, "All four port sprites share one loaded image")
		var seam := (Vector2(cell) + Vector2.ONE * 0.5 + Vector2(Topology.DIRECTIONS[d]) * 0.5) * 256
		check(node.position == seam, "The basic assembly rotates the anchor around the cell center")
		check((node.transform * (Vector2(128, 0) - Vector2(128, 128) + node.offset)).is_equal_approx(seam), "The canonical border stays on the shared seam after rotation and scaling")
		check(node.flip_h == (d in [2, 3]), "Declared tangential mirroring keeps opposite asymmetric profiles aligned")
		check(is_equal_approx(node.rotation, d * PI / 2), "Common renderer applies the canonical port orientation")
		node.free()
	check(part == original, "Instancing does not modify the canonical set definition")
	var geometry := {"position_cells": [0.25, 0.75], "position_px": [64, 192], "quarter_turns": 1, "requires_mask": 3, "pivot_px": [42, 91], "offset_px": [11, -8], "masks": {"reveal": {"asset": "canonical.png"}}}
	for d in range(4):
		var rotated := Assembly.rotated(geometry, d)
		var restored := Assembly.rotated(rotated, -d)
		check(restored.position_cells == Vector2(0.25, 0.75) and restored.position_px == Vector2(64, 192), "Quarter-turn geometry remains exactly invertible in cells and pixels")
		check(restored.requires_mask == 3 and rotated.requires_mask == Topology.rotate_mask(3, d), "Connection requirements follow assembly orientation")
		check(rotated.pivot_px == geometry.pivot_px and rotated.offset_px == geometry.offset_px, "Local pivot and offset are not rotated twice")
		check(rotated.masks == geometry.masks, "The same canonical field follows the sprite, with no directional path substitution")
	var field: Dictionary = Coral.part("arm_n").masks.reveal.asset
	check(field.provider == "linear_reveal" and Assets.validate(field).is_empty(), "Coral arm reveals have no external mask-file dependency")
	var generated := Assets.resolve(field)
	check(generated == Assets.resolve(field), "Shared generated fields are cached")
	var image := generated.get_image()
	check(image.get_format() == Image.FORMAT_R8 and image.get_size() == Vector2i(256, 256), "Linear fields use the source mask precision and canvas")
	var correct := true
	var data := image.get_data()
	for y in range(256):
		for x in range(256):
			if data[y * 256 + x] != roundi(clampf((128 - y - 0.5) / 128.0, 0, 1) * 255): correct = false
	check(correct, "Every arm reveal pixel follows its center-to-boundary projection")
	var invalid := field.duplicate(true)
	invalid.params.one_px = invalid.params.zero_px
	check(not Assets.validate(invalid).is_empty(), "Degenerate reveal fields fail validation")
	invalid = field.duplicate(true)
	invalid.params.size_px = [0, 256]
	check(not Assets.validate(invalid).is_empty(), "Invalid generated canvas sizes fail validation")
	for color: String in ["salmon", "turquoise"]:
		var arm_asset: Texture2D
		var junction_asset: Texture2D
		var junction_mask: Texture2D
		for d in range(4):
			var arm: Dictionary = Assets.bind_part(Coral.part("arm_" + ["n", "e", "s", "w"][d]), color).part
			var joint: Dictionary = Assets.bind_part(Coral.part("junction_" + ["ne", "es", "sw", "wn"][d]), color).part
			if arm_asset == null:
				arm_asset = Assets.resolve(arm.asset, Coral.ROOT)
				junction_asset = Assets.resolve(joint.asset, Coral.ROOT)
				junction_mask = Assets.resolve(joint.masks.reveal.asset, Coral.ROOT)
			check(Assets.resolve(arm.asset, Coral.ROOT) == arm_asset and Assets.resolve(arm.masks.reveal.asset, Coral.ROOT) == generated, "All Coral arm directions share canonical artwork and generated reveal")
			check(Assets.resolve(joint.asset, Coral.ROOT) == junction_asset and Assets.resolve(joint.masks.reveal.asset, Coral.ROOT) == junction_mask, "All Coral junction directions share one artwork and the retained NE mask")
			check(joint.masks.reveal.rotation_degrees == 0, "Canonical field UVs need no reverse rotation compensation")
	check(Clock.vine().asset.provider == "variants", "Clockwork tube variants represent metals, not copied compass directions")
	print("Pattern assembly: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
