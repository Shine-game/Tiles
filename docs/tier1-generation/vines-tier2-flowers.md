# Vines tier-two flowers

The live assembly in `art/themes/vines/sets/tier2.json` now uses the supplied `flower_rosa_255.png` and `flower_violet_255.png`, replacing the butterfly selection. Source PNG bytes are preserved under standardized `vines_tier2_flower_color{1,2}_basic` names; color1 is violet and color2 is rosa. Logical pink vines select rosa, and logical violet vines select violet.

Each sidecar marks the flower center at [127,127] on its 255×255 canvas. This point is placed at the completed 2×2 formation center. The existing two-square canvas size, 100% assembly scale, fixed orientation and 0.25-second fade are unchanged. No recoloring is applied. Water remains disabled.

Validation: `tests/test_vines_tier2_sprites.gd` checks both source selections, dimensions, center transforms, size and growth completion.
