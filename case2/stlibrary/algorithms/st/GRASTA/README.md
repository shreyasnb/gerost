# GRASTA adapter

Uses `grasta_stream.m` from LRSLibrary's GRASTA directory installed by `setup_third_party`.

All benchmark runs start from the exact common `U0`; the normal `STATUS.init==0` branch that replaces `U0` by a random basis is never allowed to run.

Three online-step profiles are available:

- `sharedAdaptive`: preserves common `U0`, sets `STATUS.step_scale=0`, and lets the native GRASTA adaptive rule infer its scale from the first online CDnet frame. This is preferable when frames are normalized to `[0,1]`.
- `lrslibrary` (**benchmark default**): uses LRSLibrary's online constant step `1e-2`. Because the benchmark intentionally omits LRSLibrary's private 30-cycle training stage, `onlineAdmmIterations` is explicit (default 20).
- `gerostCase2`: reproduces the GeRoST synthetic comparison initialization with adaptive stepping and `STATUS.step_scale=0.01`.

The default foreground score remains `abs(input-background)`, matching LRSLibrary's returned sparse/residual matrix and the ROC construction in the GeRoST Case-2 script. `scoreMode='sparse'` exposes `abs(STATUS.s_t)` for diagnostics.

Use `diagnose_grasta_highway` before a full run if GRASTA performance looks anomalous.
