# Step 9 — one theme/UI registry and runtime artwork format

The migration is complete for the four active themes. The source of theme identity,
selection order, appearance versions, palette colors, UI colors, previews, backgrounds,
frame profiles, set locations and reviewed behavior IDs is now
[`assets/themes/themes.json`](../../assets/themes/themes.json), schema `tiles.themes.v1`.
[`theme_registry.gd`](../../scripts/pattern/theme_registry.gd) validates that data.
There are no intended changes to visuals, game rules, timing or saved-art identities.

## Runtime ownership

| Owner | Responsibility |
| --- | --- |
| Theme registry | Theme profiles, default/order, five selectable Vines palettes, UI/frame configuration, set references and approved hook IDs |
| `tiles.pattern-set.v1` files | Texture/variant descriptors, masks, pivots, placement, layers and declared animation parameters |
| Shared pattern modules | Connectivity, canonical assembly, supports, readiness, component lifecycle and common asset/rendering helpers |
| Theme behavior modules | Clockwork motion/pressure/retirement/audio, Coral anemone dependencies, Zen ponds and historical trees, Vines drawing |
| `theme_events.gd` | Collect actual theme clocks/history into the common component-state lifecycle |

`TilePalette` retains its existing methods for callers. It stores one active theme
ID, with read-only Clockwork/Coral/Zen flags derived from the profile. It no longer
stores separate theme booleans or repeats names, appearance versions and palettes.
The board chooses its model through the profile's reviewed growth hook; existing
specialized environment rendering uses the environment hook. IDs do not load scripts.

The board and Settings menu read the same frame profile and shared geometry through
`BoardFrame`. Preview tiles and the Clockwork full-screen background use registry
paths. Vines' palette floor and light/dark garden derivation remain unchanged.
Zen and Vines have disabled decorative frames; missing optional art stays absent.
Archived Labyrinth labels remain readable in existing galleries without enabling it.

## Artwork consolidation and removed paths

Clockwork and Coral now have `sets/tier3.json` for their remaining specialized parts
and `sets/environment.json` for ground artwork. These use the same pattern-set loader,
variant binding, pivot/mask validation and texture cache as Tiers 0–2. The environment
catalog uses tier 0 for its base surface; it is a separate environment role, not an
extra logical formation or growth trigger.

Clockwork's catalog retains 11 finishing/chain parts and five environment entries.
Coral retains ten anemone parts and six ground variants. Specialized assembly and
animation code remains theme-owned. Zen tree atlases, watershed selection and random
plants still belong to their specialized modules; Vines remains a registered
procedural renderer. A shared pattern format does not require replacing those
algorithms with one sprite recipe.

Removed production inputs are the two old `art/themes/*/theme.json` source-package
manifests and `assets/frames/frames.json`. Their duplicated Tier 0–2 metadata no longer
competes with the live sets. `legacy_assets.gd` and its metadata-normalizing branch
are removed; the rake relief provider lives in `zen_assets.gd`. The existing lifecycle
collector is named `theme_events.gd` and remains in use. The Coral audio tool now reads
the registry. Android export includes the registry and every set catalog.

Export-excluded `tests/fixtures/*_source_catalog.json` preserve older source metadata
for independent regression comparisons. Production code never reads those fixtures.
Supplied PNGs, masks, shaders, audio and their import settings are unchanged. Original
source-package documentation/provenance remains available in Git history.

## Adding or changing a theme

Start with [the current handoff guide](../theme-handoff/README.md), the registry example
and actual pattern-set examples. Register a theme's identity, UI/environment settings,
family/tier paths and approved hooks in the registry. Data cannot register code;
new behavior providers and hooks must be implemented and reviewed in project code.
Use existing hooks only when their complete behavior fits the artwork.

Edit the appropriate set when changing a part; do not recreate a second component
catalog in the registry or a source manifest. Canonical artwork, directional masks
and artwork/mask rotations remain independent. Shading redesign is still deferred.

## Validation

`tests/test_theme_registry.gd` passes 82 checks covering production profiles, all declared sets and
special catalogs, selectable palettes, default/order/version preservation, live UI
edits, disabled archived themes, invalid hook/path/color/frame data and export inputs.
Existing tests compare the runtime against the frozen source fixtures, exercise
actual menu/theme/difficulty interactions, and cover helper/history restoration.
All 464 before/after model snapshots match exactly, as do 256 real-game board
frames and 20 game/Settings/Themes/Difficulty/Sound menu captures across all four
themes. The 24 headless and seven native runtime suites pass without script errors.
A resource-pack export passes 207 checks from an isolated project: active registry,
all referenced catalogs/textures and frame/preview/background artwork are present;
obsolete manifests and test fixtures are excluded. This verifies packaged data, not
an Android APK build or device performance; Android SDK build-tools are unavailable.
Some existing UI/gallery test harnesses retain their previous shutdown resource-leak
diagnostic; these are separate from script errors or failed assertions.
