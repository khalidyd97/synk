# Hold/slide judgment correction — 2026-10-29

## Actual device evidence

Read-only logcat from the user's already-running debug app showed repeated terminal misses on a415-note125BPM13-key chart, including starts47.28,56.19 and59.04 seconds. Those entries had already earned two checkpoints, then expired at the terminal rear deadline with owner-999 and no active contacts. This establishes the terminal miss pattern; it does not by itself establish each physical release position/time. The chart and only the SSRG speed setting were read without launching or controlling the game. Speed was4.0. Local diagnostic copies remain in ignored `.tools/`; phone charts and drafts were not changed.

## Corrections

1. Keep the current source-style shared track owner and retained physical contact identity separate. A transient Lost checkpoint still clears the shared owner. The existing owned-final-release adapter can now recognize the last actual chain contact after that transition instead of treating it as unrelated. An identity generation on every new contact prevents Android finger-index reuse from rescuing an old chain.
2. Honor the same chain's retained sustain autoaim channel on a final lift. The old lift path could accept an off-center finger through the source233.2q by290q sustain rectangle, then reject that finger against the narrower62.75-unit13-key collider. The corrected path requires the same owner/contact generation, matching source channel and same-chain aim token. Global routing and cancellation still apply.
3. Sweep newly eligible linked continuations within the same update. The collapsed SYNK chain formerly advanced at most one node per frame. Source UpdateViewNotes iterates linked Note objects and can advance another eligible next node on a different channel that update. The per-channel consumed gate still stops same-channel duplicate judgments. This matters for the user's short60ms lane changes and quick return tails.

Packaged head/middle/end windows, grade thresholds, early release225ms allowance and inherited chain grade/rate are unchanged. No blanket leniency, automatic completion without eligible contact, new gap grace or unrelated-finger release is added. Native conditional End-state initialization is still not fully recovered: the owned-release identity path is a correction to SYNK's explicit adapter, not a claim of newly proven source behavior. Source references remain SSRG_CONNECTOR_CALL_GATES_AUDIT.md and SSRG_SLIDE_AUTOAIM_EVIDENCE.md.

## Related actual-device errors

JSON-loaded chart summaries contain floating numeric lane counts. Source4/7/13 color lookups now normalize them to integers, fixing the logged13.0 dictionary-key failures in song_row and refresh_detail. App focus-loss pausing skips the visual screen-transition capture, avoiding a CanvasLayer add_child during Android's busy pause notification while still pausing immediately and idempotently.

## Validation

New regressions failed before their fixes and pass afterward: Lost-to-valid-final-lift; retained autoaim with off-center lift; same-update different-channel continuation/tail progression. Negative checks retain early/cancel misses, prevent unrelated reused-finger completion, and prohibit same-channel duplicate scoring.

Eleven targeted suites passed: new release identity tests, source sustain rules, audited linked-node inheritance, sustain integration, contact recovery,30/60/120FPS long-slide timing, multi-finger integration, input timestamps, full SSRG integration, regular SYNK OG isolation, and loaded-chart/browser/background pause.

All109 moving slides in the actual415-note chart were independently followed at the source judgment line with40ms simulated tracking delay and physical lifts, at speed4.0. At30/60/120FPS, each was tested with zero and0.3SYNK-lane lateral variation:654 isolated scenarios, zero misses. This is desktop simulation, not a human Samsung playtest or proof of full original online-game parity.

Diagnostic slide-miss logs now include retained owner and release time/lane/cancellation context so any remaining device-only case can be identified from the user's next run. Logs stay local.

## Delivery

Fresh APK: `builds/android/ssrg-hold-slide-judgment-20261029-091155/SYNK.apk`. Export completed without script/parse/export failures; v2/v3 signatures match the existing signer. SamsungRZCW10J7R7A was connected and authorized; Downloads/SYNK-latest.apk transfer succeeded; `adb install --no-incremental -r` returned Success and package path was verified. No uninstall, data clearing, phone launch or agent phone playtest occurred. Existing chart/draft data was preserved.
