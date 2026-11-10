# Clockwork Workshop

Clockwork is the startup theme and first entry in the theme cycle: Clockwork → Vines → Labyrinth → Coral Reef. Drafting paper fills the entire screen; the shared frame component displays the supplied walnut texture. Its fixed geometry remains a 14-unit rim and 10-unit lower sidewall. Occupied plates, offered pieces and hovering pieces use 4 UI units of thickness in this theme. Other themes retain their existing depth rules.

## Source and agreed rules

The original runtime files from `Clockwork_Workshop_v1_Codex.zip` are preserved under `art/themes/clockwork_workshop`. All 67 archive checksums were independently verified; all 59 PNGs decode; all manifest references resolve. The two ground variants match along their edges across quarter turns. See `clockwork-audit.json`, the supplied provenance in `clockwork-rights.md`, and the original handoff in `clockwork-source-handoff.md`. That handoff is source material; the user-approved decisions below supersede its optional position-hashed terminal selection and future fourth-tier suggestion.

Copper and gunmetal map to logical cell IDs 1 and 2. The artwork alternates by layer for readability: core wheels/sockets/pins, tubes/collars/couplings, axles, solid lower 2×2 gears (`L01`) and finishing tops use the primary metal; ornate upper 2×2 gears (`L03`) and chain links (`CH01_link`) use the opposite metal. The other logical color inverts this split. `ClockworkVisuals.art_variant()` owns this selection; event colors, connectivity, symmetry and motion remain logical-color based. Original PNGs are not recolored. Gallery appearance revision `workshop4-v3` distinguishes this arrangement from earlier same-metal stacks. Accents do not create additional game colors. Occupancy, move legality, symmetry, helpers, controls, tile generation and gallery eligibility are unchanged.

1. Ordinary cells assemble fixed sockets, wheels, axle pins, same-color orthogonal tubes/collars and one coupling per unordered neighboring pair. Source-free groups bud simultaneously; attached growth follows actual tube-front arrival. Each tube half takes 0.20 seconds. The first connected center waits 0.435 seconds (two half-tubes plus the 0.035-second reveal tail); each subsequent new center adds 0.585 seconds, including the 0.15-second outward-emission delay. Multiple old entry points propagate simultaneously and the earliest front wins. Sockets, core wheels and pins remain invisible until pressure reaches their center; collars follow arrival at their painted attachment, and couplings follow arrival at the shared boundary. Directional tube fields support core/edge fronts without reversing the mask twice. A small 0.28-second steam puff seals a finished boundary coupling.
2. Every same-color 2×2 creates a mechanism at its shared corner, including overlapping supports. The four core wheels elevate above their fixed sockets; lower gear, centered axle sleeve/upper gear and plain hatch follow the supplied 1.95-second assembly. Rise uses shaded vertical flanks and shadows, with fixed gear centers and no planar gear scaling. Tooth overlap is acceptable; the artwork is not certified for exact meshing.
3. Every immediately neighboring same-color pair of mechanisms receives a two-run chain after both axles are ready. The upper run assembles left to right; the lower simultaneously assembles right to left. Vertical connections rotate the complete pair 90 degrees. Assembly takes 0.45 seconds. Once an axle has a chain, one finishing cap seats in 0.20 seconds. There is no fourth tier.

| Attached chain directions | Finishing cap |
| --- | --- |
| One | Plain hatch |
| Two opposite | Stationary valve |
| Two forming a corner | Slowly rotating wheel |
| Three or four | Exhaust |

Cap choice follows topology, so symmetry is not arbitrarily broken by decorative hashing. A later connection can change the cap type. An axle losing its final chain returns to its second-tier hatch. Exhaust shutters slide over an opaque underlay, and restrained steam is staggered between vents. At most two puffs are visible across the board, including construction puffs.

## State and motion

`clockwork_growth.gd` derives keyed components, mechanisms, chains, support membership, cap types, pins and construction times from before/after boards. Concave and convex exposed contour corners receive rivets; mixed-color ties choose the first actual perimeter support by row/column. Plate texture selection is stable by board coordinate.

`clockwork_visuals.gd` reconciles persistent sprite identities rather than rebuilding shared cores. Construction time and operating time are separate. Active core wheels rotate counterclockwise at approximately 14 rpm, central and upper gears clockwise at 10 rpm and on a shared axle phase, and decorative caps at 3 rpm. Unpowered small wheels stay still. Starts ease in; supported wheels retain phase on additional placements, helpers and theme changes. Chain links are batched in two shader strips per connection, drawing original link art at 2× size (about 108×48 painted source pixels) with a 58-source-pixel pitch instead of 29, roughly five link positions per run instead of nine. Run centerlines remain at ±28 source pixels, the two strip canvases are 128 pixels high, and return housings enlarge only 20% to 108 pixels to give the wider links clearance. Each run starts at its own axle so the larger pitch assembles symmetrically. Linear chain speed and assembly duration stay unchanged. This preserves opposite circulation without thousands of per-link nodes/timers. Return paths are concealed by the provided junction housing, as an artistic abstraction rather than a physical four-chain transmission.

Undo/Erase update the logical board immediately, then reverse only unsupported construction in compressed order: terminal, chains, upper mechanism, axle, lower mechanism and ordinary pieces. Typical dismantling completes within 0.4 seconds. Surviving partial construction retains its progress. Place stays gated until construction/dismantling resolves, while the next piece remains movable. Continuous operation never prolongs that gate. Reset cancels old state. Entering the theme derives completed assemblies without replaying growth; surviving motion phases remain stable when returning to it. Gallery snapshots copy and freeze the live gear/chain phases.

The first implementation operates completed mechanisms normally. `ClockworkVisuals.operating` is a separate policy hook; the idea of operating only while the board has committed symmetry is deliberately deferred, not silently imposed. Construction steam and sounds remain independent of that future operating policy. Scene pause freezes animation and audio together.

## Sound

Original, deterministic stereo PCM samples provide a quiet looping tick/tock background, soft coupling clicks, muted gear-seat clunks and short steam breaths. Generate them with `python3 tools/synthesize_clockwork_audio.py`; no external recordings are used. Tick/tock is at −24 dB player gain; click −18, clunk −16, steam −23. Four one-shot voices and per-kind rate limits bound busy assemblies. The previous foliage/bell and reef layers do not play in this theme. Rapid theme changes cancel obsolete fades, and scene cleanup stops all voices.

## Validation and limits

`tests/test_clockwork_arrivals.gd` reproduces the attached L-shaped piece from the supplied recordings in every rotation and both metals, checks multi-source and independent growth, and verifies on the GPU that each new core stays transparent before arrival. It also checks that completed incoming tubes do not disappear before the later outgoing emission.

`tests/test_clockwork.gd` covers default/order, all 16 arm topologies in both metals, shared cores/couplings, 2×2/3×2/3×3/4×4 and dense 9×9/11×11 graphs, cap rules, timing, motion direction, unpowered wheels, helper reversal, retained partial construction, pause, reset, theme isolation and steam limits. `tests/test_clockwork_native.gd` checks real shader rendering, chain assembly/travel/clipping, actual Place/Undo, gallery phases/frame, and dense 11×11 construction; it skips on the headless renderer. No screenshots or APKs are delivered by these tests.

Original nominal sprite sizes and pivots are preserved. Exact involute tooth contact and hidden sprocket engineering are intentionally outside the visual contract. Desktop rendering and an Android export do not establish phone frame time, speaker balance or phone-scale legibility; those still need actual-device review.
