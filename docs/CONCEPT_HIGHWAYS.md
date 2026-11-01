# Aurora Glass and Solar Ceramic

Two selectable image-based highway skins under Settings > Visual effects > Highway.

## Rendering and SSRG alignment

The full rail frames and beveled highlights are painted bitmap assets displayed as one flat, unshaded sprite. At the user's request, the center is solid black: the renderer masks out interior lines, reflections and material streaks, while retaining a narrow detail strip at the very left and right edges as in the supplied close-up. There are no modeled rail housings, procedural metal shading or scene lighting for these themes. The image renderer uses the existing SSRG canvas projection; inverse texture coordinates prevent the triangle's collapsed far edge from shearing the artwork.

Both skins preserve all thirteen lane centres, the progress-to-the-sixth note position/size curve, approach duration, judgment time and touch mapping. The painted frames fit outside the same playable boundary. Notes and tails draw above the stage. The full judgment bar and thirteen markers use the original SSRG painted judgment sprite. The bar tapers with the highway, remains centred on the existing timing plane and draws behind notes and tails. Album art sits at the highway entrance. The opaque top-layer pause remains unchanged, and the shared animation clock freezes on pause.

Theme supplies each design's original note palette; Adaptive continues to follow cover colors. Rail and band swatches remain supported. Imported SSRG runs retain their own source stage and return to the selected skin afterward. Recording retains its own readable camera and rails.

## Saved artwork

- `D:/synk/assets/highways/aurora_glass_stage.png`
- `D:/synk/assets/highways/aurora_glass_highway.png`
- `D:/synk/assets/highways/solar_ceramic_stage.png`
- `D:/synk/assets/highways/solar_ceramic_highway.png`

All four files were generated with the built-in image_gen tool, then copied into this project. The two initial concept images were used as material/style references for the highway bitmaps. Scenery contains no baked road, notes or HUD. Highway bitmaps contain no baked notes, judgment line or HUD.

## Generation prompts

Aurora stage:

> Create a premium widescreen 16:9 environment background texture for a mobile rhythm game, inspired by the Aurora Glass concept: midnight navy arctic lake, glowing delicate mint and cyan aurora curtains, distant sharp mountain silhouettes, a few elegant translucent crystalline spires at left and right edges, subtle stars and reflections. Symmetrical stage composition, distant central horizon at 35% image height, dark empty center to accommodate a triangular gameplay highway overlay. Polished atmospheric game art, clean stylized cinematic render, tasteful soft light. All visual detail and bright objects at outer thirds, center mostly dark navy, darker bottom center. Absolutely NO highway, NO road, NO rails, NO notes, NO lane lines, NO UI, NO text, NO logo, NO album cover, NO borders, NO people. Deliver a background-only image; the game draws its highway on top. Match a sophisticated calm glass and aurora palette, not cluttered, high quality.

Solar stage:

> Create a premium widescreen 16:9 environment background texture for a mobile rhythm game, inspired by the Solar Ceramic concept: graphite-black futuristic ceremonial landscape, warm distant giant amber solar disk centered behind the upper horizon, fine champagne orbital arcs and a few dark spherical planets at outer edges, delicate slender copper spires at far left and right, restrained reflection on a black polished lake. Symmetrical stage composition, central horizon 35% image height, disk centered x50% y25%, dark empty central foreground to accommodate triangular highway overlay. Sophisticated stylized cinematic game art, warm luxury, restrained illumination, no blue or purple. Center and lower center must remain dark and uncluttered, warm detail concentrated to left/right and distant top. Absolutely NO highway, NO road, NO rails, NO notes, NO lane lines, NO UI, NO text, NO logo, NO album cover, NO border, NO people. Background-only asset; live game highway will be drawn on top.

Road/rail prompt template, used once for each concept reference with MATERIALS substituted below:

> Use case: ui-mockup, production game sprite texture. The supplied image is a MATERIAL AND STYLE reference for the highway and its FULL BROAD BEVELED RAIL FRAMES only. Create the clean flat rectangular 2D road-and-rails image asset for this same highway, to be mapped by the game into the precise SSRG perspective. NOT another gameplay screenshot. Show an entire rectangular road skin viewed absolutely straight from above, orthographic, no perspective convergence: two perfectly straight parallel long polished rail frames along the left and right edges, each occupying exactly 8% of image width; the central 84% is the smooth very dark road surface. Full rich painted polished rail tops, reflective bevels, thin luminous inside edges and dark outer facets like the reference; MATERIALS. The road has fine understated lengthwise reflection streaks, smooth premium finish, subtle fine material detail, ample dark readability. Orientation road runs vertically from image top to bottom. Left and right rails reach both image edges vertically. Rail thickness constant throughout. Broad cinematic texture sheet, landscape 2:1 aspect ratio. All road and rail lighting is painted into this 2D bitmap. The image must fill the canvas edge to edge with the road and both rails. NO background scene, NO sky, NO planets, NO mountains, NO horizon, NO vanishing point, NO road taper, NO notes, NO circles, NO trails, NO judgment line, NO sparks, NO album art, NO UI, NO text or numbers, NO watermark, NO labels. Keep dark road center, full rail frames clearly visible. This will be displayed as a flat image sprite, like SSRG.

Aurora MATERIALS: `icy cyan, opal silver and smoked navy glass; elongated soft aurora reflections`

Solar MATERIALS: `champagne gold metal with warm copper reflections, graphite-black satin ceramic`

## Validation

`godot_tests/test_concept_highways.gd` renders both designs and checks bitmap use, both rail frames, thirteen touch-aligned positions, unchanged projection and travel, rail customization, pause, recording isolation, return from SSRG and saved selection after restarting. `test_thirteen_lanes.gd` covers the recorder, studio and old-chart migration.
