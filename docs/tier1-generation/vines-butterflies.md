# Vines tier-two butterflies

`art/themes/vines/sets/tier2.json` now uses the `vines.sprite_formation` provider. Logical pink vines (1) use the rosa butterfly, and logical violet vines (2) use the violet butterfly. Source PNG bytes and original colors are preserved; no palette shader or tint is applied.

Each butterfly has a JSON sidecar in `art/themes/vines/artwork/tier2/`, with its 255×255 source canvas, center [127,127], scale 1 and fixed zero rotation. The marked center is placed at the center of each completed 2×2 formation. The assembly canvas is two squares wide and high. The existing 0.25-second fade follows the perimeter growth prerequisites. Settled and restored formations appear fully visible.

Fountain artwork is no longer selected. Water connections remain disabled. Bend/T/X flowers and the eight-leaf core/endpoint assembly retain their tier-one rules.

`tests/test_vines_butterflies.gd` checks both palette bindings, source texture dimensions, centered transforms, size and construction timing. `tests/test_vines_fountains.gd` verifies that no continuous water layer is created.
