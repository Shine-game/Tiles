# Adding a theme

Christmas joy ships with the game and has a source preset in `theme_drafts/christmas_joy.json` and source artwork in `theme_drafts/christmas_joy/`. The preview uses the snowy background, ice frame, snow paths, and the two motifs for isolated tiles and endpoints. Christmas joy shares Vines audio. Higher-tier formations are disabled until Christmas artwork is available.

1. In a disposable development checkout, run `python3 tools/scaffold_theme.py winter_garden --name "Winter Garden" --preview`.
2. Store source artwork and its assembly JSON in `theme_drafts/<id>/`. Use the same relative paths they should have in `assets/themes/<id>/`. The scaffold copies these files over the Vines template and adds them to the generated manifest. In the preset, `profile_overrides` replaces whole profile sections such as the frame or junction bindings. Use `omit_placeholders` to drop template files once their references have been replaced.
3. Generate a fresh preview in a disposable checkout after changing the source artwork. Open the Themes menu and select the draft. Try both board sizes, exercise the construction tiers, and save an image to the Gallery.
4. Run `tests/test_export_sprite_inventory.gd` and the isolated resource-pack checks in [Android startup checks](android-export-checks.md).

The registry controls availability. For a paid theme, add a unique `play_product` to the theme profile and configure the matching non-consumable one-time product in Play Console. The update bundles the manifest-listed artwork, and the purchase unlocks replay. See [Christmas joy paid theme](christmas-joy-test.md).
