# Tier 1 generation — step 2: metadata loader and set adapter

The staged sprite catalogs now have a shared loader. Existing generation and
rendering remain active. Placement selection, lighting choices, random mirrors,
collision rejection and event scheduling are the next integration stages.

## Entry points

```gdscript
const Themes = preload("res://scripts/pattern/theme_registry.gd")
const Assets = preload("res://scripts/pattern/asset_library.gd")
const Metadata = preload("res://scripts/pattern/sprite_metadata.gd")

var catalog = Assets.load_sprite_catalog(
    Themes.sprite_catalog_path(theme_id), "res://", theme_id)
if not catalog.ok:
    # Report catalog.errors; keep the current construction intact.
    return
var staged_set = Assets.load_sprite_set(catalog, "default", logical_color)
# staged_set uses the existing tiles.pattern-set.v1 descriptor format.
# It contains candidate pools, not a finished placement/composition to draw.
```

Zen uses family `stones`, logical color 2 and image variant color1. Calling the
adapter for a missing family or logical color returns diagnostics; there is no
implicit fallback to another theme, family or color. The optional expected theme
argument checks a registry/catalog identity mismatch without a theme-name branch.

The catalog result has `definition` (authored data), `settings`, and `families`.
Each normalized family includes logical bindings, `bases` and `decorations`.
Each record has its canonical project path, original `definition`, `canvas_px`,
resolved absolute image paths, `resolved` defaults, normalized `anchors` and
per-color `reveals` asset descriptors. Callers receive independent dictionary
copies. Cached texture and occupancy resources are shared and must be treated as
read-only; do not mutate a mask returned by `Metadata.occupancy(path)`.

## Validation

`PatternSpriteSchema` implements the exact JSON Schema vocabulary used by the
bundled version-1 sprite and catalog schemas: types, required/unknown fields,
constants/enums, numeric limits, string patterns, object/array bounds, array
prefixes/items/uniqueness, and conditional/allOf rules. It is not a general
implementation of every Draft 2020-12 keyword. Future schema versions introducing
new vocabulary require corresponding runtime support.

Semantic validation additionally checks ordered ranges, nonzero vectors, source
origins/anchors/sockets inside the canvas, unique anchor/socket identities,
progressive direction availability, field scope, unresolved ready-state authoring
work, image existence and dimensions, and every catalog image binding. Review
assets follow the shared loading policy; draft records are always non-renderable.

Only canonical `res://` JSON/PNG paths are accepted. Relative catalog paths can
move between project directories, but cannot escape the project or select a
script. Source parse errors include file and line information. Invalid records
return `{ok: false, errors: [...]}` before normalization or set construction.
A bad replacement does not select an alternate asset or touch the live renderer.

Settings defaults are validated before use. The loader requires complete shared
defaults; optional sprite fields may be omitted. A review record may omit canvas
size and infer it from its actual texture; a ready record must declare it. Both
cases still validate every color image against the same dimensions.

## Resolved data and override precedence

Authored points remain in `record.definition`. The normalized anchor `forward`
field is a unit vector from that anchor, whereas an authored `forward` is a point.
Omitted anchor forward inherits the base vector, not its absolute marker. Source
canvas sizes and fractional coordinates remain intact; no 255/256 conversion or
world placement happens in this stage.

`Metadata.rules(base_definition, decoration_definition, anchor_definition,
catalog.settings)` combines already validated authored records. Its input must
be the original definitions, so an inherited default cannot accidentally erase
an explicit decoration setting. It returns:

- `animation`: defaults -> decoration -> base -> anchor; layout count and spacing
  are excluded. A progressive override needs an explicit decoration direction.
- `orientation`: defaults -> base -> anchor, merged field by field.
- `variation`: defaults -> base -> decoration. Catalog selection weight applies
  to the decoration only; anchor-wide count/spacing are diagnosed as invalid.
- `constraints`: restrictive booleans combine with OR, gaps/margins with max and
  radius limits with min. `base_overlap_checks` retains every non-allow overlap
  requirement. The planner must enforce every check, including both `avoid` and
  `require_attachment` if different scopes impose them; it must not silently
  relax a conflicting requirement.

Placement count/spacing remain in the base's resolved spawn block. `accepts=[]`
remains an explicit empty filter; absent accepts stays absent for the planner's
any-compatible-entry semantics. Grow timings are only data at this point.

## Textures, alpha and reveals

Parsed JSON, normalized records/catalogs, textures, alpha bitmaps and reveal
asset descriptors are cached. Cache keys include the settings content so a strict
review policy cannot reuse a permissive result. Explicit `clear_cache()` handles
editor-side metadata reloads; texture changes still require Godot reimporting the
source resource. Malformed resources never become a successful cache entry.

Occupancy uses the actual imported texture and alpha > 0.01. Completely
transparent art fails loading. Progressive reveal fields project occupied source
pixel centers along the native growth direction, including any art behind the
attachment; the forward extent must be positive. The adapter emits an existing
`linear_reveal` provider descriptor, allowing PatternAssetLibrary to generate and
cache the field. Explicit reveal images must match the source dimensions and be
grayscale; they remain ordinary cached texture descriptors.

Direct decorations may also precompute directional fields when their default
axis has a positive extent, supporting a later valid progressive override.
Neither a field descriptor nor a mask creates a shader animation by itself.

## Existing pattern engine integration

The adapter emits `bases` and `decorations` candidate compositions in a normal
pattern set. Every part uses the existing texture provider and source-pixel
pivot, and carries `sprite_metadata_path`, `source_canvas_px` and `sprite_rules`
for the upcoming planner. Progressive decorations carry a standard reveal-mask
descriptor. The adapter passes these sets back through the existing load_set
validator; the existing texture resolver, part validator and component renderer
remain the rendering infrastructure.

Do not compose the whole candidate pool onto the board: step 3 must first select
one base and a valid subset of anchors/decorations. No renderer activation flag,
new frame loop, sprite-placement RNG or theme-specific placement branch is added
by this stage.

## Verification

`tests/test_sprite_metadata.gd` exercises all 53 actual geometries and selected
color bindings, their adapter output through the existing validators/resolver,
cache reuse and dictionary isolation, optional defaults, malformed records and
catalogs, paths and reveal masks, restrictive overrides, and a synthetic future
identity that loads without adding a theme branch. The same runner works against
an Android resource pack from an empty project directory; export filters include
both schemas and all required runtime inputs.

Use the commands in asset-import.md, replacing the runner with
`tests/test_sprite_metadata.gd` and the resource pack with
`build/tier1-loader-check.pck`. Existing pattern-asset and theme-registry tests
remain regression checks.
