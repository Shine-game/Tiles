# Authored anchor combinations

Optional base-only `spawn.group_anchor_sets` maps a group name to valid lists of
anchor IDs. Each group must have a matching fixed `spawn.group_counts` quota.
Every option must contain exactly that many distinct anchors from the group.
The planner makes one deterministic seeded choice per group before placing deco.
Omitting this field retains the existing shuffled selection.

Vines has 20 anchors, 10 per side. Each side reserves exactly two leaves. Its
options choose one anchor from 2,3,4 and one from 7,8,9, excluding (4,7).
That gives eight possible pairs per side, each with at least three empty anchors
between leaves. The two sides select independently. Existing native scale,
perpendicular direction, mirroring and progressive reveal remain unchanged.
