# Step 4 — common asset loading and component rendering

The common asset/rendering foundation is implemented and used by compatibility
adapters. Existing artwork, mask/shader semantics, timing, shape selection, UI and
appearance versions remain unchanged. Declarative Clockwork Tier 0/1 selection was subsequently implemented in
[Step 5](clockwork-ordinary-sets.md).

## Asset library

[`asset_library.gd`](../../scripts/pattern/asset_library.gd) accepts a project
texture path, an existing `Texture2D`, or a descriptor:

| Provider | Data |
| --- | --- |
| `texture` | `path`, relative to the set root or explicit `res://`; image imports or a typed binary `Texture2D` resource |
| `atlas` | Source `path`, `region_px: [x,y,width,height]`, optional `filter_clip` |
| `variants` (Step 5) | Named `variants` descriptors, selected explicitly by treatment |
| Registered procedural texture | Project-owned provider ID and `params` object |

Texture and atlas resources are shared through the library cache. Generated
textures are cached by provider ID and encoded parameters. Atlas selection does
not edit the source PNG; pivots are relative to the selected region. The library
accepts project texture types, not script paths or arbitrary external resources.

`status` defaults to `available`. Optional slots can explicitly declare `missing`
or `unused`; they resolve to no artwork, with no substitute from another theme.
`required: true` makes an absent slot a validation error. Failed resolution returns
null and diagnostics. Unknown provider IDs do not execute code. Procedural
factories and optional parameter validators are registered by project code only.

The current rake provider validates canonical masks before generating the exact
existing relief texture. It does not create new rake geometry or lighting.

## Runtime set format

`load_set()` reads a dictionary or a project JSON file using schema
`tiles.pattern-set.v1`. A set has a stable ID, one tier from 0–3, and named
compositions containing named parts. JSON file paths resolve relative to that
file's directory unless explicitly project-absolute.

The executable [Clockwork Tier 0 example](examples/clockwork-tier0.example.json)
uses the actual copper socket, wheel and axle artwork. It demonstrates static
multipart loading only; it is not a replacement for the game's existing
Clockwork assembly, motion, pressure timing or theme definition.

```json
{
  "schema": "tiles.pattern-set.v1",
  "id": "example-family-tier1",
  "tier": 1,
  "compositions": {
    "bend": {
      "parts": {
        "center": {
          "asset": {"status": "missing", "required": false},
          "position_cells": [0.5, 0.5]
        }
      }
    }
  }
}
```

Validation covers schema/ID/tier, compositions/parts, asset presence/type, atlas
bounds, registered providers, placement vector/number types and mask metadata.
The returned dictionary includes `ok`, `errors`, a copied `definition`, and its
resolved `root`. A failed set is not enabled by `compose()`.

Each part can declare a `provider` (`sprite`, `group`, or a registered node ID),
an `asset` for sprites, placement fields, a registered `material` provider and
explicit mask metadata. Mask descriptors require asset, purpose, channel, linear
encoding and zero/one meanings. Supported purposes are reveal, protection,
coverage and placement; introducing the deferred lighting contract is not part
of this format revision. Masks are not automatically treated as reveal fields or
applied twice: a project-owned material/behavior consumes their declared meaning.

Composition selection, topology-to-role assignments, lower-tier suppression,
Tier 3 policies, whole-theme environment/UI definitions and timing declarations
continue through their current adapters. They migrate in Steps 5–9; this loader
does not reinterpret supplied old manifests as the new schema.

## Component renderer

[`component_renderer.gd`](../../scripts/pattern/component_renderer.gd) provides:

- `sprite()` / `configure_sprite()` for common placement of existing and new sprites.
- `material()` for a private mutable ShaderMaterial over an existing shader.
- `ensure(id, spec, parent)` to keep surviving nodes and update their placement.
- `sync(parts, parent, state)` to validate a component collection before replacing
  it and reconcile nodes by stable ID.
- `compose(loaded, composition, parent, state, owner_prefix)` to instantiate a
  loaded multipart composition beneath its feature parent.
- Explicit removal/clear, shader-clock reveal tracking, settled shader release,
  and optional shared-lifecycle opacity/retirement binding.
- Project-registered node, immediate-mode drawing and material providers.

A renderer instance owns the collection passed to `sync`/`compose`; syncing that
instance removes its nodes that are no longer in the collection. A caller building
multiple features can merge their parts under stable namespaced IDs or use a
renderer instance per feature. `owner_prefix` supplies an explicit instance
identity; otherwise the example identity combines set, composition and local part.

Surviving nodes retain identity; an intentional provider-kind change replaces the
node. Existing feature parents and child insertion order remain intact. New
components are appended. Layer/group policies remain explicit; parts do not gain
an automatic z-index from their tier. Invalid data is diagnosed before normal
sync mutations. Project factories must honor their registered output contract;
failed runtime resource/provider resolution is reported rather than substituted.

Placement fields:

| Field | Interpretation |
| --- | --- |
| `position_cells` | Position multiplied by `pixels_per_cell` (default 256) |
| `position_px` | Explicit source-space position, useful for compatibility adapters |
| `pivot_px` | Attachment point in the texture/atlas-region's source pixels |
| `centered`, `offset_px` | Existing Sprite2D conventions, preserved when specified |
| `size_cells` | Sprite display size, or Control size, in cell units |
| `scale` | Explicit scale; sprites with `size_cells` derive scale from their texture size |
| `rotation_radians` / `quarter_turns` | Explicit orientation; quarter turns are clockwise |
| `texture_filter`, `z_index`, `flip_h/v` | Explicit existing rendering settings |

Missing fields retain node defaults/current values. Sprite pivots map through the
source/region size; they are not assumed to be the canvas center. Registered
procedural nodes receive position, rotation, scale, layer and filtering through
the same interface. Immediate-mode providers run synchronously in their host's
existing draw context, so procedural themes need no replacement sprite pack.

`advance(clock, state)` can apply shared record opacity. Once a bound record is
retired/removed, its node is removed. `lifecycle: external` opts out for a
specialized provider. Spatial masks can instead register a shader-clock binding;
completed ordinary sprites drop private reveal materials, while retained materials
receive their final clock sample. No shader source or shading algorithm is changed.

## Existing integration

[`legacy_assets.gd`](../../scripts/pattern/legacy_assets.gd) normalizes both
Clockwork's `assets/pivot/growth_field` and Coral's `artwork/pivot_px/reveal_mask`
metadata. Artwork variants are selected explicitly; canonical artwork does not
imply that its masks share its path or rotation. Old manifest files are untouched.

| Existing rendering | Step 4 integration |
| --- | --- |
| Coral sprites, multipart colonies/anemones | Common persistent node registry, placement, materials and reveal completion; existing grouping/order and mask parameters retained |
| Clockwork components | Shared texture loading, sprite positioning and material creation; existing assembly, motion, chains, effects and retirement remain in the theme renderer |
| Zen rakes/stones | Shared sprite placement and cached registered rake texture provider; original joins, curves and filter settings preserved |
| Zen seasonal branches | Cached source textures and atlas regions; attachment pivots, historical transforms and season behavior retained |
| Zen ponds/shrubs | Shared texture loading and sprite factory; original masks, lateral placement and random choices retained |
| Vines / Labyrinth | Registered drawing providers call their existing procedural drawing in the real board; no new preview interface |

This plumbing reuse is separate from migrating a theme's Tier 0/1 role rules.
Endpoints outside Clockwork are not silently assigned new art, ordinary Coral
fingers remain omitted, and no straight-run decoration interval is invented.

## Verification

`tests/test_pattern_assets.gd` checks real texture/cache behavior, optional/required
missing slots, unknown providers, atlas clipping/bounds/pivots, generated texture
caching, the versioned example, multipart node retention, invalid replacement
handling, procedural draw/node/material registration, private shader materials,
shared-state progress/retirement, final reveal samples and both legacy manifest
formats. Existing state/topology tests remain applicable.

Twenty deterministic native board captures were taken before the refactor across
all five themes, 9×9/11×11 boards and two patterns containing ordinary shapes and
higher-tier formations. Their pixels match exactly after the integration. The
comparison driver/captures stay in the execution workspace, not the game UI.
All 580 recorded model states also remain byte-identical. Existing theme/UI and
native Clockwork, tree and pond suites pass. Original image files and appearance
versions are unchanged.

## Step 5 extensions

Sets may declare `roles`, mapping shape/behavior names to composition names or
explicit `null` for unused slots. Unknown composition references fail validation.
`PatternCellSets.center_parts()` uses shared topology to select the isolated role
from Tier 0 or the connected role from Tier 1. Its anchor helpers cover cell centers
and once-per-edge ownership of shared boundary midpoints.

Asset descriptors with `provider: variants` contain named treatment descriptors.
All alternatives are validated; `bind_part()` selects artwork and mask variants
without mutating the source set. `compose()` accepts an optional final `treatment`
argument. Unknown treatments fail before replacing existing nodes, with no silent
color fallback. A descriptor can alternatively declare its explicit `variant`.

`release(id)` relinquishes common registry ownership without freeing or reparenting
the node, allowing an existing theme retirement hook to finish its animation.
The caller then owns disposal. Clockwork uses this for its existing retiring tubes
and wheels; surviving ordinary nodes keep their identities and motion phases.

Step 6 adds typed binary `.res` texture loading for the exact floating-point Zen
rake core. Non-texture resources are rejected. See
[Zen ordinary sets](zen-ordinary-sets.md) for the endpoint overlap and staged node provider.
