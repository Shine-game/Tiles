# Tier 1 generation — step 1: corrected asset import

This change stages the corrected artwork in the Godot project. Existing tier 1
set definitions, timing, renderers, and all higher-tier behavior remain active.
The next step is the universal metadata loader/adapter.

## Layout

Each theme has `artwork/tier1/` with standardized PNG names and universal v1
sidecars, and `sets/tier1-artwork.json` with an explicit catalog. The theme
registry references that catalog through `tier1_artwork`, with status `staged`.
This optional link is metadata for the upcoming adapter; it does not select a
new renderer. Existing `tiles.pattern-set.v1` files are unchanged.

74 PNGs and 74 sidecars represent 53 distinct geometries: 15 bases and 38
decorations. Color-paired sidecars are byte-identical and list both images.
Catalogs enumerate each geometry through its color1 sidecar; the consumer selects
the named image variant. Never infer catalog members from consecutive numbers.

| Registry theme | Filename token | Logical color → image variant / treatment |
| --- | --- | --- |
| coral_reef | coral | 1 → color1 / salmon; 2 → color2 / turquoise |
| clockwork | clockwork | 1 → color1 / copper; 2 → color2 / gunmetal |
| vines | vines | 1 → color2 / pink; 2 → color1 / violet |
| zen_garden, stones | zen | 2 → color1 / stone |

Zen rakes belong to logical color 1 and retain their existing family; new rake
artwork is outside this import. Vines' binding describes the supplied Rose/Violet
source artwork. Runtime support for other existing selectable palettes belongs to
the later rendering integration; this import does not change palette choices.

## Coordinates and provenance

Keep the declared source canvas and pivot: some bases are 255×255, others
256×256; leaves are 128×128 and rings are 64×224. The upcoming adapter must map
source pixels to board coordinates using each record's dimensions and frame.
This stage performs no resampling or implicit 255→256 coordinate conversion.

Source: `tier1_artwork_corrected.zip` from this conversation. Turquoise coral is
aligned to the uploaded orange wavy silhouette and its exact alpha. Pink vine
keeps its RGB and uses the violet stem alpha. Other imported PNG bytes are
unchanged from that corrected package. Existing repository artwork is retained.
Discarded leaf designs are absent; retained leaf IDs are 1, 2, 4, 6. All 12 supplied
Zen base variants are imported. Their source-to-standardized name mapping and
package hashes are recorded in `source-manifest.json`.

Decorative mirrors are enabled for coral, leaves, pebbles and moss through
metadata. Rigid clockwork rings keep optional mirroring disabled. Shared renderer
defaults and seeded mirror-selection rules are in
`assets/themes/tier1-generation.json`. The authoring schema is at
`assets/schemas/sprite-metadata-v1.schema.json`. These are input contracts for the
later universal loader/planner, not an alternate implementation of generation.

## Export and checks

The Android preset keeps all PNG resources and explicitly includes the tier 1
JSON sidecars, catalogs, schema and defaults as non-resource files. Godot-generated
`.png.import` descriptors use the new project paths; historical import UIDs/cache
paths are not reused.

Run after a headless editor import:

```
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/test_tier1_artwork.gd
godot --headless --path . --script tests/test_theme_registry.gd
```

To test the actual export filters without building/signing an APK:

```
godot --headless --path . --export-pack Android build/tier1-artwork-check.pck
godot --headless --path . --main-pack build/tier1-artwork-check.pck --script /absolute/path/to/tests/test_tier1_artwork.gd
```

The verification runner lives outside the exported resources because tests are
excluded from production. It checks exported JSON availability and imported
Texture2D resolution, including both color sidecars and the explicit logical
bindings. Use an absolute test-script path for the PCK check.
