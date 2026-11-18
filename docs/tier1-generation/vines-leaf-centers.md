# Vines leaf centers and endpoint finishes

Bend, T and X flower overlays use 80% of their former scale (0.8) for both colors. They retain their existing artwork and rotation rules.

The live `leaf_centers` object in the vines junction configuration (`assets/themes/themes.json`) replaces the isolated core image with eight existing decoration leaves, oriented at 45-degree intervals. Each leaf uses its own source metadata attachment and forward direction, the current 80% leaf scale, and the existing logical-color mapping. The small attachment radius is 0.02 square.

Straight endpoints use the same eight-leaf circle, with identical attachments and orientations. Connecting an isolated core no longer changes its geometry or removes it. Existing leaf cores are retained when later connections and junction artwork arrive while their cells remain occupied in the live board; deleting those cells removes the cores. Leaf cores draw above growing stems and stem decorations. Existing stem leaves are retained.

These placements use the existing junction lifecycle for growth, undo and gallery rendering. Counts, spacing, scale and decoration references can be edited in `leaf_centers`. No image compositing, footprint rasterization or collision search is needed.
