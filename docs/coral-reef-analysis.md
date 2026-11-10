# Coral Reef redesign v2 — implementation assessment

Current source: `Coral_Reef_Redesign_01.zip`, SHA-256 `16062dceea0d2a5138393cad894407ec24987c2d2a6fc6f7f30ad22d4a62325b`. This supersedes the original reef runtime assets and its broad fusion policy. The earlier assessment and original artwork remain available in Git history and previously saved gallery PNGs.

## Verified package

The single current manifest, `runtime/theme.json`, describes 32 independently growing component types, 64 variant PNGs, 32 masks, and six opaque ground textures. Source artwork, layered masters, reviews, and optional tools are kept out of the APK. No uploaded build scripts were executed and no PNG artwork was regenerated, stretched, or recolored.

Independent checks verified all 209 supplied checksums, all component dimensions and painted alpha bounds, identical alpha geometry between reciprocal palettes, identical crown fields across eight regions, and all 1,152 facing-edge combinations of the 24 oriented ground variants. `coral-reef-audit.json` records the results and runtime hashes. All 34 supplied logical scenario fixtures are copied into the test suite and checked against derived colonies, joins, and join positions.

The supplied guide is asset/integration guidance, not authority over unrelated game behavior. This task authorizes the redesigned appearance and its explicit immediate-neighbor join rule. Placement legality, logical color IDs, symmetry, controls, helper budgets, and the existing Place-until-growth-finishes gate remain project-owned. The synchronous CPU schedule needs no deferred callbacks that could revive invalid artwork after a helper action.

## Appearance and geometry

The redesigned line is already 77 source pixels wide in a 256px cell. Ordinary components now render at native 1:1 scale. The earlier 3× line scaling, enlarged buds, and relocated finger attachments are removed. Ground appears immediately on occupied cells using the supplied fixed coordinate hash for variant and quarter-turn rotation. Polyomino rotation, color selection, undo, and redraw do not reroll that floor. Empty squares and the rest of the screen are white. The old pale seafoam floor, neutral raised tile faces, and generated terrace shadows are omitted for this theme; the supplied ground and illustrated material relief provide its appearance.

Body, folds, fingers, foot, oral disc, and crown use their supplied geodesic masks. Artwork and masks rotate together. Shader sampling is linear/clamped with lossless straight-alpha imports and **mipmaps disabled**, matching the package's tested ground-edge contract.

## Fusion correction

Every completely occupied same-color 2×2 creates a colony, including overlapping ones. Only origins differing by exactly (±1,0) or (0,±1) get an anemone. Each sorted pair is counted once. Diagonal origins, colonies across an intervening colony, footprint-corner contact, and opposite colors do not join. The old union shelf assets and five broad offset layouts are removed from runtime.

- Filled 4×2 or 2×4: three colonies and two anemones.
- Filled 3×3: four colonies and four anemones.
- Filled 4×4: nine colonies and twelve anemones.

A horizontal pair uses the native vertical 256×512 anemone at the midpoint between colony centers; a vertical pair rotates all its layers by 90°. Underlying colony and ordinary coral artwork remains present.

## Growth and lifecycle

Matching outside sources propagate at 0.20 seconds per cell through simultaneous fronts. Independent new pieces awaken every bud at once. Fingers and junction fillets use the actual attachment positions and dependencies in the new manifest.

A colony body starts after its eight perimeter half-arms finish. Folds and fingers follow body-attachment arrival plus their declared delays. Once both supporting colonies finish, their anemone foot grows; the oral disc begins after the foot reaches its center, and all eight crown regions begin together when the disc finishes. Those regions share a mask and schedule so they reveal a continuous crown rather than independent wedges. The Place gate covers the final crown's soft reveal tail.

Stable keyed sprites and feature containers preserve surviving artwork and order. Undo and Erase remove only invalid target components and settle survivors; Reset clears all active work. Gallery captures copy the same feature order and record visual version `2.0`, so saving the same logical board with redesigned artwork does not return an old v1 image. Existing gallery images are kept.

## Overall platform appearance update

A later user-directed appearance update raises occupied ground by 24 source pixels per 256px cell across all themes. The source PNGs remain unchanged. A separate occupancy-driven shader supplies the sidewall, rim, and contact shadow below the coral ground. Empty areas remain white, and source grain/rotation remains untouched. This supersedes the flat occupied-floor presentation described above; see `raised-platform.md` for layering, clipping, and immediate helper updates.

## Validation and limits

`tests/test_coral.gd` checks all supplied fixtures, forbidden joins, declared timings and dependencies, fixed ground selection, 1:1 artwork geometry, in-cell coverage, helper cancellation, theme behavior, versioned gallery identity, and screen fitting. `tests/render_coral.gd` exercises the real shader, Place-driven growth, gallery capture, undo, and both supplied phone-board review fixtures on the native renderer. Existing rules, UI, audio, gallery, vine, and labyrinth runners remain regression checks.

The worst-case same-color 11×11 derives **3,382 components, 100 colonies, and 180 anemones**. There are fewer joins than v1, but each anemone has ten independently layered components. Only active growth components receive clock updates; completed coral sprites use cached textures. Ground sprites retain a static shared-geometry surface shader for rounded outline clipping and the upper lip; their parameters update only when occupancy or geometry changes. Actual Android frame time and memory still require testing on a device. Desktop capture and a signed APK do not establish dense-board mobile performance.

Provenance and use terms supplied with the redesign are preserved in `coral-reef-rights.md`. The future-theme handoff template remains under `docs/theme-handoff/`.
