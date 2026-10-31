# Source-driven SYNK hit effects

**Retired for regular SYNK:** Normal gameplay again uses its original Classic/Bloom renderer. Imported SSRG retains its own effects. The preview BGM and consecutive-run fixes described below remain active.

Projected SYNK gameplay uses `synk_hit_effects.gd` and the new procedural artwork in `synk_hit_burst.gdshader`. The original SSRG stage retains its imported effect frames. The recorder retains the legacy renderer.

The new renderer shares SSRG's 33 fps clock, eleven-frame lifetime, hold retrigger interval and sustain lifetime helper. Every hit owns an independent pooled quad. The artwork has stepped expanding shockwaves, a bright impact core, vertical flare, moving rays and outward sparks. Classic and Bloom select single- and double-shockwave variants. Animation uses the supplied frame index rather than shader wall-clock time, so pause freezes it.

Effects face the orthographic camera and anchor directly to the judgment plane. Holds/slides track their assigned physical pointer and retain its last position across contact gaps. Successful early completion keeps feedback through the physical last connector. Finite taps disappear at the source terminal frame boundary. Warm-up hits are returned to the pool before gameplay.

`test_synk_projected_hit_effects.gd` checks raster motion, timing, exact anchor projection, dense independent hits, pause, contact tracking, early completion, final-connector lifetime and recorder isolation.

SSRG browser previews additionally duck menu BGM to 5% linear volume, or retain a lower selected volume/mute. Ducking follows actual preview playback and restores the selected BGM volume after playback stops. `test_ssrg_preview_bgm.gd` checks those transitions without changing saved volume preferences.

Results and pause return to SSRG through `open_ssrg_playables`, which hides the normal lobby and stops its preview activity. Opening only the SSRG panel left the normal lobby active; its chart refresh could replace the selected SSRG song before the next run. `test_ssrg_consecutive_runs.gd` reproduces the old selection replacement and checks consecutive run startup plus both return routes.
