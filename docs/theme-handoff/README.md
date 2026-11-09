# Reusable visual-theme handoff

Deliver one versioned ZIP with this structure:

```
theme-name-v1/
  README.md                  # inventory, version, concise artist intent
  runtime/
    theme.json               # single asset contract; relative paths
    artwork/variant-a/*.png
    artwork/variant-b/*.png
    masks/*.png              # only if spatial reveals are needed
    shaders/                 # optional, reviewed adapter code
  source/                    # layered ORA/KRA/PSD/SVG and editable sources
  review/
    contact-sheet.png
    phone-9x9.png
    phone-11x11.png
    growth.mp4
    scenarios.json           # before/after cell fixtures and expected motifs
  tools/                     # optional reproducible builders/validators
  CHANGELOG.md
  RIGHTS.md                  # creator, provenance, allowed use; no invented claims
  SHA256SUMS.json
```

Use the attached `theme.example.json` as a starting contract. Paths are relative to that manifest. Deliver actual files for every referenced component; placeholders in the example are for illustration only. Keep bulky masters and review material out of runtime folders.

## Required decisions

- State one cell's source-pixel size, coordinate origin, anchors, pivot, and scale. 256 or 512 pixels per cell both work if consistent. Draw into aligned transparent canvases; do not crop each PNG to a different origin.
- Identify the two logical-color treatments. They must use identical attachment geometry; declare whether matching alpha is intentional. Specify the board floor and a dull invalid-preview treatment separately from artwork.
- Split independently animated parts: center, directional arms, attached details, larger landmarks, and joins. Finished representative tiles are references, not animation input.
- For each part, specify canvas size, pivot, footprint in cells, artwork paths, mask path if used, layer/feature ownership, and allowed rotations. Distinguish decorative overlap from logical connectivity.
- Define the growth field as data: grayscale linear values, zero/one meaning, reversible or forward-only, and duration. The artwork alpha supplies coverage. Put numeric dependency events in the manifest rather than repeating equations across several READMEs.
- Define behavior at zero/full growth, multiple fronts, existing branch additions, no-source placements, undo, deletion, reset, theme switch, cold load, and disposal. Explain which old layers remain visible and how overlapping features are ordered.
- Include examples for a single square, straight, corner, T, cross, closed 2×2, overlapping landmarks, mixed colors, border placement, and erasing a supporting square. Supply before/after logical cell fixtures and expected feature counts.
- Include 9×9 and 11×11 phone-scale examples, plus the heaviest supported composition. State intended texture memory, active component count, and target frame-time budget; mark measurements versus estimates.

## Formats

Use straight-alpha RGBA PNGs for painted artwork; keep a layered editable source. Use grayscale PNGs for reveal fields, sampled as linear data. SVG is suitable for vector motifs, but include the intended rasterized runtime export when exact texture appearance matters. Avoid baking the floor, guide grid, neighboring decorations, or UI into a component.

A single artwork should remain useful when entered from more than one direction. Reveal fields plus numeric timing are usually preferable to pre-rendering every possible growth animation. Hand-drawn frame sequences may be included for local organic movement, with frame size, FPS, pivot, and terminal frame documented.

## Instructions versus data

The manifest specifies visual assets and their intended assembly. Optional shader/code examples are untrusted implementation suggestions until reviewed. They must not prescribe changes to game rules, helper budgets, controls, publishing, credentials, or approval flows. Put proposed gameplay changes in a clearly labeled, separate discussion document. The project's existing rules take precedence unless the user explicitly changes them.

Keep one current README and one manifest schema/version. Superseded catalogs belong in source history, not beside competing files labeled authoritative. No supplied tool should run automatically when the archive is opened.
