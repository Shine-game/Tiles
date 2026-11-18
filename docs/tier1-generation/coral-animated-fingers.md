# Coral tier-three animated fingers

The salmon archive supplies six variants with three aligned 122 × 174 PNG frames each. Originals are preserved byte for byte in `art/themes/coral_reef/artwork/fingers/`. `salmon.json` controls the origin, source direction, native scale, ray count, appearance duration and loop timings. No anchor JSON was supplied: (61, 153) is inferred from the stationary, opaque lower attachment region shared by all 18 frames. Source growth points upward.

After both adjacent tier-two formations finish, eight fingers appear above the plates. The line joins the two plate centers. Rays follow that line and its 45-degree increments; each base lies on the line, projected toward the corresponding plate. This handles horizontal and vertical connections. All six variants are used before a variant repeats, with seeded reflection, phase and independent cycle duration between 0.8 and 1.2 seconds. Selection stays stable across redraws and undo. The source scale is 100%; adjust `scale` in the assembly JSON to change it.

The periodic sequence is 1–2–3–2, returning to 1 at the cycle boundary: a full 1–2–3–2–1 motion. Frames share the same transform and pivot. Fingers fade in over 0.2 seconds after the plates finish; continuous frame animation uses the visual node's process clock, independently of the finite construction schedule. It does not delay input, saving or growth completion. Undo removes obsolete animation bindings. Settled restoration immediately shows the fingers at full opacity.

Only salmon is configured. Teal keeps its existing tier-three composition until matching artwork is supplied. The salmon legacy foot, disc and eight region components are replaced, while tier-two plates and petals remain underneath.

Validation: `tests/test_coral_animated_fingers.gd` covers frame alignment, ping-pong order, connection orientations, pivot transforms, timing bounds, settled restoration, growth completion, undo cleanup and teal compatibility.
