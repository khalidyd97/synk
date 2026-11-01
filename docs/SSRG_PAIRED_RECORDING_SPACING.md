# Paired recording spacing correction — 2026-11-01

The user confirmed **3.6 in both games**, correcting the earlier 3.8 report.
Reference: `ScreenRecording_11-01-2026 00-45-55_1_hevc_720p.mp4`.
SYNK: `ScreenRecording_11-01-2026 00-56-10_1_720p.mp4`.
Both supplied videos are 1564×720. No phone gameplay was launched by the agent.

## Observation

A right-hand blue tap was tracked near 4.75–5.08 seconds in the reference
and 8.73–9.09 seconds in SYNK. Compare positions on the highway, not video
timestamps: these recordings begin at different song positions.
Color-component bounds normalized by the existing 640-unit canvas and
sixth-power projection give median visible width factors of approximately
0.75 in the reference and 0.95 in SYNK. Their ratio is approximately 0.79.
Independent edge-template checks on reference frames estimated note scales
0.77–0.82. Compression, bright hit effects, animation and the color mask
make these measurements approximate; they are not recovered runtime settings.

The reference trajectory fits a full travel duration of approximately 2.94 s
using the existing sixth-power curve. At the corrected setting 3.6, SYNK's
packaged-default calculation is 3.5 / (3.6 / 3) = 2.9167 s. This comparison
does not establish an appreciable speed conversion error. The earlier
comparison against 3.8 (2.7632 s) should not be used to tune movement.

## Change

SRRG rules mode, including forced SRRG runs on local charts, applies a 0.8
artwork multiplier to tap/hold heads, continuation/end pucks and the source
connector calculation. Existing user note-size customization still multiplies
this value; preferences are not overwritten. The mesh cache includes the
effective artwork scale so switching modes cannot reuse a differently sized
mesh. Other highway styles retain their previous artwork sizes.

Position, acceleration, speed conversion, input rectangles, judgment windows,
audio clock and hit effects are unchanged. This is a fit to the supplied visual
reference, not proof of identical source-game feel or live configuration.

## Validation

The reference footprint regression checks head/tail sizes, matching connector
width, the unchanged 3.6 duration and acceleration, preservation of user sizing,
and cache isolation across modes. Shared gameplay, full SSRG integration,
screen fitting and connector geometry suites also passed. The headless host
emits certificate-store warnings; some existing suites emit shutdown resource
warnings, with zero reported assertion failures.
