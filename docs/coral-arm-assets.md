# Coral arm and junction texture rotation

The four ordinary coral arms (`arm_n`, `arm_e`, `arm_s`, `arm_w`) keep their logical IDs, growth timings, and component dependencies. Their manifest entries now reference the north-facing artwork for each color and the same north-facing growth field. `artwork_rotation_clockwise` selects 0°, 90°, 180°, or 270°; `CoralVisuals` adds that angle to the sprite transform, rotating both the artwork and its reveal mask together. Source-image bounds and numeric growth paths are expressed in canonical north-facing coordinates.

Keep these three source PNGs and their import settings:

- `art/themes/coral_reef/artwork/salmon/arm_n.png`
- `art/themes/coral_reef/artwork/turquoise/arm_n.png`
- `art/themes/coral_reef/masks/arm_n.png`

The following nine PNGs are no longer referenced by the runtime manifest and can be deleted, together with their matching `.png.import` files:

- `art/themes/coral_reef/artwork/salmon/arm_e.png`
- `art/themes/coral_reef/artwork/salmon/arm_s.png`
- `art/themes/coral_reef/artwork/salmon/arm_w.png`
- `art/themes/coral_reef/artwork/turquoise/arm_e.png`
- `art/themes/coral_reef/artwork/turquoise/arm_s.png`
- `art/themes/coral_reef/artwork/turquoise/arm_w.png`
- `art/themes/coral_reef/masks/arm_e.png`
- `art/themes/coral_reef/masks/arm_s.png`
- `art/themes/coral_reef/masks/arm_w.png`

These files remain in the checkout for the owner's cleanup. Pixel comparison confirmed all nine are exact clockwise rotations of their retained north-facing counterpart. Historical source-package audit records still mention the original filenames and hashes; those records are provenance, not runtime asset references. The junction family has a separate cleanup list below; other component families are unchanged.

`tests/test_coral_arm_rotation.gd` verifies shared texture/mask resources, directional transforms, and two-front timing in both colors. With a graphical renderer it compares early growth, mid-growth, and completed arms against pre-rotated image/mask fixtures, allowing at most one 8-bit quantization level per channel. Its fixtures are generated in memory from the retained north-facing sources, so the runner still works after redundant files are deleted. The existing coral scenario runner checks all 34 supplied topology/growth cases.

## Junction artwork: retain all four masks

The junction components are a separate family. Their salmon and turquoise `junction_es.png`, `junction_sw.png`, and `junction_wn.png` images are exact rotations of `junction_ne.png`. They now also share the `junction_ne.png` artwork at runtime, so these six artwork PNGs and their matching `.png.import` files can be removed:

- `art/themes/coral_reef/artwork/salmon/junction_es.png`
- `art/themes/coral_reef/artwork/salmon/junction_sw.png`
- `art/themes/coral_reef/artwork/salmon/junction_wn.png`
- `art/themes/coral_reef/artwork/turquoise/junction_es.png`
- `art/themes/coral_reef/artwork/turquoise/junction_sw.png`
- `art/themes/coral_reef/artwork/turquoise/junction_wn.png`

Keep `junction_ne.png` in both artwork folders. Also **keep all four** files under `art/themes/coral_reef/masks/`:

- `junction_ne.png`
- `junction_es.png`
- `junction_sw.png`
- `junction_wn.png`

The junction masks encode different geodesic growth paths, including differences inside the visible artwork. They cannot be replaced by rotating a single field without changing the animation. The renderer uses one junction artwork per color and preserves each original mask; `growth_mask_rotation_clockwise` compensates its UV coordinates for the artwork's sprite rotation. Original directional dependencies, paths, and timing remain intact. The same rotation runner checks all junction directions and both colors against their original directional growth masks during growth and after completion.
