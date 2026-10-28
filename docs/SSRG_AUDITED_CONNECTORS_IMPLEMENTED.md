# Audited connector rules applied — 2026-10-28

Evidence: [connector re-audit](SSRG_CONNECTOR_JUDGMENT_REAUDIT.md). Imported SSRG timed sustain chains now process eligible nodes inside the recovered front window rather than waiting for the exact judgment timestamp. Both intermediate nodes and the terminal continuation inherit the preceding successful node's grade and rate. The release branch's provisional rate of .1 does not independently downgrade the inherited final grade.

An unreleased chain also accepts Lost channel state for the current input update, allowing a finger that just crossed a channel to receive credit. This is not a wall-clock grace period. Released chains exclude Lost. Exact rate-window boundaries remain ineligible; a node beyond its rear deadline misses.

The verified queued-contact, contact-identity, cancellation, timestamp and owned-release protections remain. Owned-contact terminal release is an explicit SYNK adapter: the original initial IsReleased setter is still unproven. Online timing overrides and complete same-tick linked-node reconstruction are also unresolved; this change does not claim complete runtime parity.

Validation: focused sustain rules, inherited grade/rate and Lost integration, multi-finger integration, long-slide source-window timing at 30/60/120 FPS, contact recovery, full integration, input timing, touch routing and gameplay entrance checks passed. An isolated desktop simulation followed all 71 moving slides in the phone's 239-note chart at two touch heights with and without lateral jitter: zero failures in all four scenarios. This is simulated validation, not a human phone playtest. Godot still reports the existing certificate-store and some test-exit resource cleanup warnings.

Android output: `builds/android/ssrg-audited-connectors-20261028/SYNK.apk`. The fixed gold bar, charts, drafts, recorder and customization are preserved. No special-note effects are added.

APK signature verified with v2/v3 and the existing signer. Samsung RZCW10J7R7A was connected and authorized; APK copied to Downloads and installed successfully using `--no-incremental -r`. The game was not launched or playtested on the phone.
