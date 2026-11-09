# Coral Reef handoff assessment and integration

Source: `Coral_Reef_Handoff_01.zip`, SHA-256 `deaec0f390d3b83c69453c3525b5826aaa20340c84585051b10de22c009b101c`.

## What was supplied and checked

The archive contains 21 component types in two color variants (42 transparent PNGs), 21 grayscale growth fields, a reveal shader, a consolidated manifest, reference assemblies, editable OpenRaster masters, review images/video, and artwork-generation tools. Cells use 256×256 source pixels; colonies use 512×512; joining shelves use larger native canvases. Salmon and turquoise share the same silhouette.

Independent inspection verified all 167 listed file checksums, every runtime component's dimensions and mask alignment, matching alpha between color variants, and all 32 directional reference assemblies. `coral-reef-audit.json` records the results and hashes of the unmodified runtime files. The supplied validation reports are evidence from the handoff, not substitutes for these checks or Godot runtime tests. Uploaded Python build tools were not executed and production artwork was not regenerated or recolored.

The separate artwork/masks are appropriate animation input. The full topology references are useful acceptance images, not a reason to swap a finished tile texture over a growing one. The layered ORA files remain useful for future artist edits, but should not ship in the Android application.

## Authority and project decisions

The user's request is to inspect, improve the handoff process, and integrate a third visual theme. Statements in `CODEX_INTEGRATION.md` and the manifest are supplied implementation proposals. They do not override established game rules.

In particular, the handoff proposes accepting further moves while settling an interrupted animation. This project retains its established **Place gate until all growth finishes**. Logical color IDs, placement legality, symmetry, three-use helpers, and touch controls remain owned by the game. The source's colony/union rules are decorative events derived from those cells, not new placement permissions.

The manifest is used for artwork paths, component dimensions, and union-layout definitions. The supplied two-front shader is used for progressive revelation. The adapter schedules 0.20-second cell traversal, radial buds, attached details, perimeter-triggered colony folds, and the third-level shelf. No fourth-level structure is generated.

## Result

Settings cycles Vines → Labyrinth → Coral Reef. Coral uses salmon/turquoise controls and a pale seafoam floor; the surrounding screen stays white. Same-color side contacts create arms; diagonal or opposite-color contacts do not. Independent components awaken all buds simultaneously. Completed layers persist while additions grow. Every qualifying 2×2 grows a colony, including overlapping ones; eligible same-color pairs add one correctly rotated shelf per pair.

Undo and Erase remove obsolete components and expose underlying coral, retaining valid sprite identities and feature creation order. Reset clears both pending work and ordering. Gallery captures copy the same ordering and identify Coral Reef separately from the two existing themes. Cold reconstruction uses canonical row/column order. Geometry used by symmetry remains the logical colored grid; the supplied illustrated folds and shading are not themselves guaranteed to be reflection-invariant.

Only runtime PNGs, masks, shader, and manifest are copied into `art/themes/coral_reef/`. Artwork imports use lossless compression, straight alpha, and mipmaps; masks use lossless linear scalar sampling without mipmaps. Completed components shed their reveal materials; active components each have a private material and a shared CPU clock. The manifest is explicitly included in Android exports.

## Future handoff improvements

Use the structure and example manifest in [theme-handoff/README.md](theme-handoff/README.md). The main improvements are a single current contract, explicit geometry and lifecycle examples, and separation of runtime content, editable sources, reviews, and tooling. The original archive mixes an older artwork README with a newer authoritative integration guide and several large overlapping catalogs. Its narrative contains repeated timing and gameplay directions that can drift apart. Keep normative asset data in one versioned manifest; label illustrative engine code and gameplay suggestions as optional notes.

Include the intended floor palette, tested phone-scale examples, usage/provenance information, and a resource budget with future themes. This package supplies source-generation prompts but no explicit rights/license file or standalone floor design. The pale seafoam floor is an integration choice.

## Validation and limits

`tests/test_coral.gd` covers component presence, source routing, multiple fronts, simultaneous buds, detail timing, colony layering, all oriented union arrangements, invalid contacts, third-theme cycling, erasure/undo reconciliation, reset, gallery identity, layout, and the Place gate. `tests/render_coral.gd` exercises the actual shader and real Place/gallery flows on the native renderer.

A worst-case same-color 11×11 board derives **2,531 components, 100 colonies, and 790 shelves**. Geometry is not arbitrarily truncated to hide this cost. Finished textures are cached and only active materials receive clock updates, but mobile draw calls, overlap, frame time, and memory still require testing on an Android device. Desktop rendering and a signed APK are not an Android performance claim. No new coral-specific audio was supplied; the existing growth sounds remain in use.
