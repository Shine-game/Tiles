# Zen Garden: ordinary-tile prototype (stage 1)

Open `prototypes/zen_garden/ordinary_tiles.tscn` and run the current scene (F6),
or run:

```sh
godot --path . res://prototypes/zen_garden/ordinary_tiles.tscn
```

The main scene, theme selector, placement rules and existing themes remain as
before. This is a separate review of sand, rake geometry and stepping stones.
The review controls select sand/stones/mixed colors, all 16 topology masks,
layout rotation, 9×9/11×11 field size, light direction and relief lighting.
The default window is 540×825, matching the game's phone-scale preview.

## Geometry and materials

`scripts/zen_geometry.gd` uses the same N/E/S/W bit order as Coral, with a
same-color orthogonal-neighbor mask and canonical masks 0, 1, 5, 3, 11, 15.
Those six motifs rotate around (128,128). The interior paths are mathematical
review approximations of the supplied motifs, not corrected copies of the
painted masters. Bend paths go around an empty center, T paths arch over it,
and cross paths circulate around it. Final interior shape needs visual approval.
Center stones/bamboo and their progression belong to stage 2.

Every active edge has four groove centers at 92/116/140/164 on the 256-pixel
cell, with a shared Gaussian cross-section (sigma 3.2 source pixels). The final
32 pixels have identical values perpendicular to each edge, with zero slope
toward the boundary. Inactive boundaries are flat. Height fields are float
textures generated once per canonical motif and cached. Offline baking and
growth/reconstruction animation are future integration work.

`shaders/zen_sand.gdshader` adapts the user's proposed finite-difference relief
lighting, rotating normals into screen space. It uses a private material uniform
instead of an instance uniform so it works with the project's GL Compatibility
renderer. The sand texture stays in board space when the relief rotates. Flat
illumination is normalized to the unchanged sand surface; restrained cavity
contrast remains when directional lighting is disabled. This is a lighting
experiment, not the final seasonal/day-night lighting system.

The source sand image is unchanged. Mirrored sampling makes its shared edges
continuous, and mipmaps avoid aliasing at phone scale. The same surface is used
for the background and occupied cell faces. `OccupiedPlatform` supplies the
continuous occupancy union, including borders between the two colors. Its new
optional `metal_surface=false` argument permits a fixed 4 UI-pixel sand lip
without Clockwork's metal shader inputs. Existing callers retain their behavior.

The four stepping-stone directional images stay unrotated: their baked light
should not rotate. Each active edge adds its matching half. Isolated stepping
stones use the supplied core image. No new stone art was created or edited.

## Source provenance

Six PNGs were copied byte-for-byte from the user-uploaded archives. Paths and
SHA-256 checksums are in `art/themes/zen_garden/source-assets.json`. Engine import
settings enable mipmaps without changing the source artwork. Rake relief is
procedural geometry, not luminance extracted from the shaded reference images.

## Validation

```sh
godot --headless --path . --script res://tests/test_zen_ordinary.gd
godot --path . --script res://tests/render_zen_ordinary.gd
```

The first checks bend tangent continuity, self-intersections and crossings
between grooves as well as all topology masks and rotations, full 32-pixel port profiles,
flat inactive boundaries, matching visible RGB and alpha on opposing stone
halves, color separation, diagonal exclusion and fixed-depth material behavior.
The second requires a graphics display: it exercises review controls and writes
9×9/11×11 fields, all-shape sheets, rotations, light directions, unlit relief and
a 540×825 phone capture to `build/zen-review/`.

Verified with Godot 4.7.2, GL Compatibility on Mesa software rendering. This is
not an Android export or performance validation. Existing board-frame, native
Clockwork, reef-water and UI tests also cover the shared platform change.

Pending later approvals: center decoration progression, landmarks, watersheds,
ponds, trees, growth history, gameplay theme selection, frame art and gallery
integration. The prototype does not start those stages.
