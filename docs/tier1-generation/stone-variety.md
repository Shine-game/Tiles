# Stone variety

Zen stone paths and their starting/endpoint cores select from the same twelve
basic stone sprites. `tier1_artwork.cell_variation: true` enables shared selection.
Each source is assigned to one of four disjoint coordinate-parity pools, with
seeded shuffling and seeded per-cell selection. This guarantees no matching
source sprite in any of the eight touching squares, even across new additions.
A reflected or rotated copy still counts as the same sprite for this rule.

Each stone receives an independently selected 0/90/180/270-degree turn, an X
reflection choice, and an additional uniform angle in [-4,+4] degrees. The same
transform is applied to its decorations. Core overlays use the same selector.
Bend/T/X cairn artwork and rake paths retain their existing transforms.

Choices are deterministic for the theme seed and square. They remain stable on
redraw, additions, undo and gallery reconstruction; rebuilding an identical board
with the same seed does not reshuffle it. Changing the theme artwork seed changes
the arrangement. Random transform choice takes precedence over the previous
lighting-based preference for these freely oriented stones.

Verified on a 17x17 coordinate area: all twelve sources, all four quarter turns,
both reflection states and both jitter signs occur; no eight-neighbor repeats.
Source and exported-pack tests also verify matching core/interior assembly.
