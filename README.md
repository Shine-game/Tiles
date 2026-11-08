# Tiles

A calm, browser-based puzzle about preserving the possibility of symmetry.

## Run

Requires Node.js 20 or newer. No packages or credentials are needed.

```sh
npm start
```

The server listens on port 3000 (override with `PORT`). Run `npm test` for the rules tests.

## Play

- Start with a green center square on a 9×9 or 11×11 board.
- Place the seven standard tetrominoes. I, O, S are green; T, J, L, Z are yellow.
- Each piece must touch an existing square at an edge or corner, without overlapping or leaving the board.
- Hover to preview; click to place. On touch screens, tap to preview and tap the same anchor again to place. The selected square anchors the top-left of the piece's bounding box (which may itself be empty).
- Rotate clockwise with the button or **R**. Reflections of pieces are not allowed.
- Highlighted indicators show possible central reflections and rotations. A check means that symmetry is already complete. Quarter-turn rotations have the same feasibility but are displayed separately for clarity.
- Empty squares may be filled later. A symmetry becomes impossible when an orbit contains both colors. The board does not need to be symmetric after every move.
- Invalid moves are rejected. Play ends when the offered piece has no valid position in any rotation. There is no timer or line clearing.
- Back restores the previous board and offered piece, up to three placements into the past. New placements create a new history branch.
- Pieces use shuffled seven-piece bags, without filtering out difficult pieces. Undo retains the generated sequence.

## Architecture and prototype limits

`rules.js` contains pure board, rotation, orbit, and placement logic plus the game/history model. `app.js` renders the interface independently, allowing future floral motifs to be added without changing the cell rules. `server.js` is a small static server using only Node's standard library.

Possibility currently means **color compatibility**, not a guarantee that remaining gaps can be tiled with future whole pieces. All axes and rotation centers are fixed to the board center. Game state lives in memory; refreshing starts a new game. Decorative flower/leaf overlays are reserved for a later version.

## Validation

`npm test` exercises all seven shapes, both board sizes, asymmetric-but-compatible patterns, reflection and quarter-turn color conflicts, bounds/overlap/contact, invalid moves, three-step undo, and game-over detection. Browser smoke checks during development also exercised placement, undo, help, board resizing, and narrow-screen layout in Chromium.
