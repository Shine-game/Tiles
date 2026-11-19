# Vines tier-two flowers

The live assembly in `art/themes/vines/sets/tier2.json` now uses the supplied `flower_rosa_255.png` and `flower_violet_255.png`, replacing the butterfly selection. Source PNG bytes are preserved under standardized `vines_tier2_flower_color{1,2}_basic` names; color1 is violet and color2 is rosa. Logical pink vines select rosa, and logical violet vines select violet.

Each sidecar marks the flower center at [127,127] on its 255×255 canvas. This point is placed at the completed 2×2 formation center. The existing two-square canvas size, 100% assembly scale, stable random 0–360° rotation about the marked center are unchanged; the reveal now follows the timing described below. No recoloring is applied. Water remains disabled.

Validation: `tests/test_vines_tier2_sprites.gd` checks both source selections, dimensions, center transforms, size and growth completion.

## Delayed nebulous reveal

Tier two now waits one second after its own supporting 2×2 stems and leaf decorations finish. `after_tier1_seconds` controls the delay. `VinesGrowth.reschedule_formations` incorporates the actual sprite-growth event ends for half-stems inside the formation, so unrelated growth does not postpone it. Reconciliation reuses the base prerequisite to avoid accumulating the delay.

The reveal duration is read from the configured tier-two sound (currently the three-second bloom), with its configured audio seek offset removed. `VinesFormationLayer` presents the flower through a drifting noise/radial alpha mask and a restrained shimmer. At completion the shader is removed and the original PNG is shown unchanged. Settled boards and galleries immediately show the completed flower. The marked center and seeded free rotation remain unchanged.

Small underlying junction flowers fade away over this same reveal. Third-tier butterflies wait for both supporting flowers’ audio and reveals to complete, then wait one additional second. The audio scheduler consequently selects separate bloom and butterfly cues when the old 0.25-second combined clip no longer matches the visual interval. The tier-one rustle still stops at the end of tier-one growth, before the one-second wait.

`tests/test_vines_delayed_reveal.gd` covers local leaf completion, the exact wait, sound-length reveal progress, delayed butterflies, original settled artwork and audio synchronization for both colors.
