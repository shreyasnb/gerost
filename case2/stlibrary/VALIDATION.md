# Validation notes

Packaging-time validation performed in the build environment:

- 53 MATLAB `.m` source files are included in this build; MATLAB/Octave runtime validation must be run locally as noted below.
- The included synthetic CDnet-shaped sequence contains 100 input frames and 100 ground-truth frames at 96x72 pixels, with ROI/temporal ROI metadata and CDnet-style labels.
- `dataset/demo.avi`: MJPEG, 96x72, 100 frames, 12 fps.
- `dataset/synthetic_demo/synthetic_square_preview.mp4`: H.264, 96x72, 100 frames, 12 fps.
- `libs/third_party_manifest.json` parses successfully.
- No unexpected zero-byte files were found.

MATLAB and Octave are not installed in the build environment, so the upstream algorithms could not be executed here. After `setup_third_party` in MATLAB R2025b, run:

```matlab
st_setup;
run_tests;
demo;
```

`run_tests` includes framework/metric tests, shared-SVD/ISTA initialization tests, a palette-aware CDnet ground-truth decoding regression test, and an algorithm smoke test that verifies every installed adapter receives the identical canonical `sharedInitialization.U0`. The dependency-aware smoke test automatically skips until the third-party dependencies are installed.

## 2026-09-13 diagnostics update

Added a fast real-CDnet diagnostic path in response to zero-valid-pixel metrics and Linux video-profile failures:

- `read_cdnet_roi.m` decodes indexed ROI images through their colormap before thresholding.
- `load_cdnet_sequence.m` records exact input/GT/ROI/temporalROI source paths and supports `cfg.io.frameRange` in native CDnet frame numbers.
- `check_cdnet_highway.m` checks three real highway frames, source-file/loaded-array equality, ROI coverage, GT labels, and writes a diagnostic PNG/CSV.
- `quick_cdnet_smoke.m` runs a tiny resized real-highway slice and writes per-algorithm input/background/foreground/mask/GT PNG panels.
- `run_algorithm.m` attaches data provenance to every result.
- `run_all_algorithms.m` separates tracker failures from optional output/video failures.
- Video writers query supported profiles and fall back from MPEG-4 to Motion JPEG AVI when required.
- Added regression tests for indexed ROI decoding and native frame-range selection.

MATLAB is not installed in this build environment, so R2025b execution remains a local validation step. Static source inspection, package integrity, and synthetic asset integrity are checked here.


## Performance regression checks

- `tests/test_gerost_reduced_innermax.m` numerically compares the reduced GeRoST inner solve against `gerost.inner_max` on a small random problem when the third-party repository is installed.
- `diagnose_grasta_highway` compares three GRASTA step profiles while holding the initial subspace and data slice fixed.
- `profile_gerost_speed` compares GREAT, upstream GeRoST, and reduced GeRoST on the same real CDnet slice and records GeRoST stage timings.


## Snapshot-PDF update (2026-09-13)

The benchmark now captures only requested background columns for publication
snapshots and stores them in each algorithm `result.mat`.  The new
`test_snapshot_capture` unit test checks that the capture helper allocates only
those columns.  MATLAB/Octave is not available in this build environment, so
`run_tests` remains the executable R2025b validation step for PDF export and
tracker integration.

## Time-metric diagnostics patch (2026-09-13)

Static review added for the frame-resolved PDF path:

- `compute_frame_metrics_over_time.m` computes per-frame CDnet confusion
  metrics using the same fixed threshold/mask as the final benchmark result.
- `subspace_chordal_distance.m` uses projector/chordal distance and supports
  unequal estimated/reference dimensions.
- each tracker records only scalar subspace distances online; estimated
  subspace histories are not retained.
- default subspace sampling is every 5 frames to limit overhead.
- chordal diagnostic time is measured separately inside each adapter and
  subtracted from the reported benchmark runtime/FPS.
- CDnet `referenceMode='auto'` does not fabricate a ground-truth reference;
  it plots update magnitude only unless truth/reference is supplied. Explicit
  `referenceMode='initial'` remains available for drift-from-U0 diagnostics.
- `test_time_diagnostics.m` covers chordal invariance, true/initial reference
  selection, rolling-window metrics, and monotone threshold-swept ROC curves.

MATLAB/Octave are not installed in the packaging environment, so graphical
PDF export and the new unit test must be executed in MATLAB R2025b with
`run_tests` / `demo_cdnet`.

## Time-metric plotting correction (2026-09-13)

The second time-metrics pass corrected three interpretation/statistics issues:

- rolling segmentation metrics are derived from rolling TP/TN/FP/FN sums;
  nonlinear metrics are no longer averaged directly across frames,
- score means are weighted by the number of foreground/background pixels in
  each window,
- `roc_curve.pdf` is a true threshold-swept pixel ROC; the former connected
  frame-wise TPR/FPR trajectory was not a ROC curve,
- chordal distance orthonormalizes each basis with thin QR before comparing
  column spaces,
- CDnet `referenceMode='auto'` no longer treats common `U0` as a surrogate
  truth curve. `referenceMode='initial'` remains available explicitly.

`test_time_diagnostics.m` now includes pooled-window F1, monotone/perfect ROC,
and basis-scaling-invariant chordal regression tests. MATLAB/Octave is still
not installed in the packaging environment; run `run_tests` in R2025b for
executable validation.

## Replot bundle update (2026-09-14)

The benchmark now writes `plot_data.mat` by default. The bundle contains only
plotting sufficient statistics and selected scalar/snapshot traces; dense
video, mask, score, background and subspace histories are excluded.
`plot_results.m` regenerates comparison, time-metric, ROC, snapshot and GeRoST
robustness figures from this bundle without calling an algorithm or CDnet
loader. Snapshot capture also accepts a small vector of native frame numbers
so multiple publication snapshots can be selected later without another
tracker pass.

MATLAB R2025b is not available in the packaging environment, so the included
`test_plot_data_bundle.m` and existing test suite should be executed with
`run_tests` on the target MATLAB installation.
