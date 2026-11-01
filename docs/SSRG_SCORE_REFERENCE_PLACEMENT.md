# Reference score placement and topmost pause — 2026-11-01

Reference: the user's `ScreenRecording_11-01-2026 00-45-55_1_hevc_720p.mp4`,
1564x720, sampled around five seconds. The gauge begins near x176/y47;
score digits begin near x206/y101, below the gauge, with the rave bonus beside
the score. These are visual measurements, not recovered native layout constants.

The source HUD now anchors its gauge at 11.25% of full-stage width, converting
to the safe-area control's coordinates. Previously it centered a 1136-unit
subcanvas, which inset the HUD too far on wide phones. The SCORE caption,
digit position, .8 digit size and .9 advance were fitted to the recording.
The existing bonus readout moves from below the score to its right and shifts
farther right for longer score values. Scoring arithmetic is unchanged.

Pause backdrop and controls now share `PauseOverlay`, a CanvasLayer at 1000,
above the app's login/text entry/transitions (100), album flight (110), and
notifications (120). It is visible only while paused. Safe-area controls remain
registered for resize/cutout updates; the backdrop still covers the full screen.

HUD placement, album/glide/solid-pause and edge-to-edge suites passed. Desktop
Compatibility renders were inspected for the reference score and opaque pause;
a deliberately red full-screen layer at 120 was fully covered by the pause UI.
Phone gameplay is left to the user.
