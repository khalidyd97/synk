# SYNK highway projection

**Active:** Gold and Neon now use the SSRG canvas projection and approach curve during gameplay and settings previews. Recording keeps its independent perspective camera and speed. This replaces the earlier restoration of the perspective gameplay view.

Gold and Neon gameplay use SSRG's orthographic canvas, original canvas fitting and progress-to-the-sixth approach curve. Notes share the same scaling and position transform; hold and slide sections use the same projected cross-sections. Rendering travel is 3.5 seconds at 1x. Imported SSRG runs retain their own speed mapping, artwork and stage.

`highway_3d.gd::uses_projected_highway` selects the visual mechanism independently from `main.gd::uses_ssrg_gameplay`. SYNK retains its note textures, solid/neon trail choices, rail and band styles, colors, lane mapping and judgment rules. Static SYNK track/rail shaders project their geometry onto the shared canvas. The recorder disables this projection and retains its perspective camera and 2.6-second travel.

The judgment band remains centered at world Z=0, which is the zero-depth note and input timing plane. The source canvas fitting keeps this plane near the bottom of the display and fits wide note artwork on narrower screens. Held ribbons clip against the projected timing plane. Changing the recorder angle cannot move the gameplay judgment bar.

Prism is removed from the style picker and no longer instantiated. Old saved Prism selections resolve to Gold. Archived artwork is retained on disk.

`test_synk_projected_highway.gd` (reactivated in `godot_tests`) renders Gold and Neon with all three SYNK note shapes and both trail families. It checks far-note raster positions, source projection without source judging, screen fitting at 2400×1080, 1280×720 and 1024×768, bar-to-note alignment, actual on-time input at outer/center lanes, held-trail clipping and recorder isolation.

All SYNK gameplay, recorder and studio coordinates now use thirteen lanes (0–12), saved as chart format 3. Version 1 already uses this layout; version 2 charts are proportionally converted on read. Existing files, drafts and history are not rewritten by loading. Imported SSRG positions now map directly to lane numbers.
