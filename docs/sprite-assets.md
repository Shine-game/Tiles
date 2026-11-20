# Sprite file conventions and audit

Sprites remain under `art/themes/<theme>/artwork/` in their tier/role folders, with masks under their theme's masks folder. Names use `theme_tierN_element_colorN_number.png`. Shared or neutral artwork uses `color0`; theme-specific artwork uses `color1`/`color2`. UI assets use `theme_ui_element_colorN_number.png`. Existing canonical single-sprite packs retain their `_basic` suffix. Animated fingers use consecutive variant and frame numbers.

Vines leaf variants are now 1–3 in both colors; Zen's numeric stone variants are 1–11, plus its canonical basic stone. Clockwork's source layer IDs remain logical assembly IDs while their filenames describe their tier and role. Butterfly artwork and its anchor metadata live under Vines tier 3. Case is consistent, including `tjoint` filenames.

`assets/sprites/renames.json` records the old and new PNG paths and SHA-256 hashes. All image pixels, sprite attachment points, growth axes, timing and animation frame order are preserved. JSON sidecars and runtime paths were updated with each rename; texture import options are preserved.

Run `python tools/audit_sprites.py` to regenerate `assets/sprites/audit.json`. The audit traverses runtime set/registry metadata and static script references, checks dynamic pond/tree/steam resources, verifies consecutive numbering and animation frames, checks renamed image hashes, and reports missing runtime references. Source upload names under `authoring`/provenance are historical labels, not runtime resource links.

`assets/sprites/cleanup.json` lists the unreferenced PNGs and unused sprite metadata excluded from Android exports. Files are retained in the repository for provenance and future editing; stale source-inventory entries and the missing Coral review-schedule reference have been removed. Runtime catalogues retain resources used by supported fallback renderers.

Validated: tier-one artwork (52 shared geometries/72 PNGs), shared asset loading, current Clockwork tier-two layout, Coral radial petals and animated fingers, Vines leaf cores and tier-three butterflies, Zen ponds, and Android resource-pack export. Older tests expecting superseded multipart centers or the former Zen default still have stale assertions. APK/device testing is separate from resource-pack validation.
