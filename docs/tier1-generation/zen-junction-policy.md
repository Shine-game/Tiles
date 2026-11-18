# Zen junction artwork

Logical color 2 (stone paths) has no bend/T/X overlays. Its ordinary full-cell path stones and their decorations remain. Logical color 1 (rakes) has no isolated or straight-ending core overlay and no legacy centerpiece. Rake bends use the supplied single stone, T uses the three-stone sprite, and X uses the bamboo composition, centered at 100% assembly scale with no rotation.

The per-color selection is authored in the Zen `junctions.disabled_shapes_by_color` configuration in `assets/themes/themes.json`. The existing shared suppression of old center artwork remains active, so removing the new overlays does not restore legacy art. Rake junction sidecars use `scale: 1.0`.

Tests: `test_zen_junction_policy.gd` checks all masks for both colors; `test_zen_junction_overlays.gd` also checks centering, arrival and undo.
