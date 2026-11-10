# Shared board-frame contract

This is the central implementation and handoff guide for every theme. Personalization lives only in `assets/frames/frames.json` under `themes`: texture path, appearance ID, enabled flag, material direction and provenance. The common `geometry` block applies to every theme. Do not copy layout rules or create theme-specific frame renderers.

## Shared artwork geometry

Provide one straight-alpha RGBA PNG, 256×266px. Its top-facing square is 256×256px, with a 10-row painted lower sidewall at y=256…265. The rim is 14px wide. The 228×228 opening x=14…241, y=14…241 must be fully transparent. All bounds are exclusive at right and bottom when written as rectangles: `Rect2i(14, 14, 228, 228)`. Preserve the four cut lines and the bottom sidewall between themes; change only material artwork. Do not bake in a board, UI, additional extrusion, or strong duplicate shadow.

These are UI/display units. The 10-unit apparent vertical sidewall is not rim width and must not use the coral artwork's 256px-per-cell conversion. The game's global UI scale applies normally. Existing tile depth remains unchanged.

## One runtime implementation

`scripts/board_frame.gd` is a `NinePatchRect` named `BoardFrame`, in the board view's local layout space. It uses patch margins left/top/right=14 and bottom=24, full/default region, `draw_center=false`, stretch in both directions, node scale (1,1), linear filtering, no repeat, and mouse input ignored. No frame shader, second sidewall image, scene file, or additional extrusion is used. PNG imports must be lossless, with straight alpha and mipmaps disabled.

Given a square board opening, the frame position is opening.position−(14,14) and size is opening.size+(28,38). `BoardFrame.fit()` reserves this complete rectangle inside the board's existing available area; it centers the frame and keeps the inner board square. The frame never overflows into controls or makes the page scroll. Grid size, move legality, symmetry and tile depth are unchanged. Existing board-to-screen transforms use the fitted opening, including the board's internal relief/shadow padding. Never use the frame's exterior as the input grid.

The frame draws above the occupied ground/coral perimeter. Coral Reef's existing caustic rectangle expands to the outer frame bounds, with its board-coordinate origin preserved. That existing lighting pass follows the same nine-slice alpha mapping so transparent exterior corners do not tint the white interface. Lagoon color stays inside the opening; the surrounding interface remains white. No separate animation or lighting strength is introduced. Other themes keep their existing lighting. Gallery captures use the same frame and append its appearance ID to the surface identity, preserving old images separately.

## Theme personalization and installation

1. Prepare the material PNG using the common geometry above. Nine-slice stretching preserves rim/corner thickness but stretches longitudinal grain and marine marks; the source is not declared seamless or validated for tiled repetition.
2. Add the PNG at its profile's texture path. For Coral Reef this is `assets/frames/coral_reef_frame.png`.
3. Import with lossless compression, alpha preserved, mipmaps off and linear/clamped sampling. Inspect dimensions and the opening's alpha at native size before enabling a new theme.
4. Update only that theme's profile: set `enabled`, `texture`, a stable nonempty `appearance` ID, `material` and `provenance`. Change the appearance ID when artwork changes. Keep the central geometry intact.
5. Run the frame runner and the UI, water, gallery and platform checks for 9×9 and 11×11, including narrow portrait and landscape layouts. Review grain and marks at game scale when the real artwork is available.

The JSON is explicitly included in Android export. Missing or disabled artwork leaves the existing unframed layout intact; it does not create placeholder artwork or reduce the board for an invisible frame.

## Coral Reef profile and current asset status

The supplied `CODEX_FRAME_HANDOFF.md` defines bleached wreck timber, rounded relief, a cool shaded flank, turquoise inner reveal and restrained marine deposits. Those details are recorded in the Coral Reef profile. The source image is described as generated from the approved mockup and technically aligned with ImageMagick; no additional rights or exclusivity are asserted.

The original `coral_reef_frame.png` has not been exposed as a downloadable file in this session. The inline preview is visible, but its original PNG bytes are unavailable for import. The profile is prepared; no replacement has been generated. The runtime will activate the frame when the actual PNG is installed. Vines and Labyrinth profiles are present but await their own artwork.

`tests/test_board_frame.gd` uses a clearly marked technical color-patch fixture to check nine-slice geometry, transparency, corner/sidewall preservation, responsive fitting, edge-cell input and lighting coordinates. The fixture is never installed as game artwork. Native pixel checks do not constitute validation of the missing production PNG.
