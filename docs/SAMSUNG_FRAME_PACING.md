# Samsung frame pacing — 2026-11-01

The user still reported less smooth gameplay after the note-footprint change.
Read-only ADB inspection of their already-running app found Match display
selected (`frame_rate=0`) and an active 120 Hz display. No game was launched
or operated by the agent.

SurfaceFlinger's retained SYNK SurfaceView latency sample contained 125 valid
presentation intervals: 96 near 8.3 ms and 29 near 16.7 ms. Median buffer-ready
interval was about 10.2 ms. This demonstrates uneven recent frame delivery;
it does not identify the sampled gameplay section or prove a particular cause.
The local capture is `.tools/pacing-review/before-latency.txt`.

Auto previously set both VSync and `Engine.max_fps` to the current integer
refresh rate. Auto now keeps VSync enabled and sets `Engine.max_fps=0`,
removing the second software pacing timer. Explicit FPS limits remain intact.
Godot's software delay implementation is documented by its 4.7.2 source:
https://github.com/godotengine/godot/blob/4.7.2-stable/core/os/os.cpp#L671

This is a targeted pacing correction to evaluate, not a claim that smoothness
now matches the original game. Note movement, audio and judgment rules are
unchanged. The agent must not launch gameplay to collect after-update timing;
the user will test the installed build.
