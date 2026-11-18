# Workshop tier-two assembly

Both copper and gunmetal now use the first driving wheel (`L01`) followed by the plain cap (`H00_plain_hatch`). The driving wheel uses the opposite metal: copper formations use the gunmetal wheel, and gunmetal formations use the copper wheel. Caps and chains retain the formation metal. The intermediate hub (`L02`) and upper wheel (`L03`) are absent from the live tier-two composition; their source artwork remains available in the repository.

The first wheel rises for 0.4 seconds. The cap follows immediately and appears over 0.25 seconds, with uniform 1.5× scale around its existing center. This also scales the plain cap used at chain terminals, so replacement does not shrink it. Chains wait for the completed mechanism.

The cap's visible diameter grows from 60 to 90 source pixels. The two chain runs are placed at ±45 source pixels about the connecting axle line, matching its new radius. This offset is authored in `sets/tier2.json` as `chain_run_offset_px`, and follows the existing chain parent rotation for horizontal and vertical connections. Link dimensions, pitch, travel, return housing, and other third-tier finishing caps retain their existing settings.

`tests/test_clockwork_tier2_layout.gd` verifies both metals, both connection orientations, absence of removed layers, the direct wheel-to-cap schedule, cap scale for initial and terminal placements, chain readiness and run offsets.
