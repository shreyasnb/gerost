# Subspace Tracking Benchmark for CDnet (MATLAB)

A MATLAB R2025b benchmark for foreground/background separation with online subspace tracking. The repository deliberately mirrors the top-level organization of **LRSLibrary** (`algorithms/`, `dataset/`, `figs/`, `gui/`, `libs/`, `output/`, `utils/`) while narrowing the scope to four ST methods:

- **GRASTA** - Grassmannian Robust Adaptive Subspace Tracking Algorithm.
- **ReProCS** - Recursive Projected Compressive Sensing / dynamic robust PCA.
- **GREAT** - Grassmannian Recursive Algorithm for Tracking.
- **GeRoST** - Min-Max Grassmannian Optimization for Online Subspace Tracking.

The benchmark uses the **CDnet 2014** directory format and evaluates foreground masks only inside CDnet's temporal and spatial ROI. CDnet shadow pixels (50) are treated as background; outside-ROI (85) and unknown-motion (170) pixels are ignored.

## Repository layout

```text
subspace_tracking_cdnet/
  algorithms/st/{GRASTA,ReProCS,GREAT,GeRoST}/run_alg.m
  dataset/
    cdnet2014/                   # downloaded dataset goes here
    synthetic_demo/             # small CDnet-shaped smoke test included
    download_cdnet2014.m
  figs/
  gui/st_gui.m
  libs/
    setup_third_party.m          # fetches open-source upstream code
    third_party_manifest.json
  output/
  utils/
  benchmark_config.m
  environment_check.m
  demo.m
  lrs_gui.m
  process_video.m
  run_algorithm.m
  run_all_algorithms.m          # one sequence, all methods; efficient headless path
  benchmark_cdnet.m             # many CDnet sequences/categories
  st_setup.m
```

## First-time setup

From the repository root in MATLAB:

```matlab
st_setup;
benchmark_version;       % should report 2026.09.14-replot1 for this build
environment_check;       % optional preflight report
setup_third_party;
```

`setup_third_party` fetches the upstream implementations into `libs/` and preserves their license files. It installs:

- GRASTA from the ST/GRASTA portion of LRSLibrary.
- ReProCS from `praneethmurthy/ReProCS` (including YALL1/PROPACK shipped by that repository).
- GeRoST and the GREAT baseline used in the GeRoST experiments from `shreyasnb/GeRoST`. The original GREAT project is also linked below for reference.
- Manopt, required for the GREAT/GeRoST Grassmann exponential-map updates.

The benchmark glue is separate from those upstream repositories. The installer records the exact fetched Git revisions in `libs/installed_versions.csv` and `libs/installed_versions.txt`. See `THIRD_PARTY.md` before redistributing an assembled checkout.

## CDnet 2014

The full CDnet dataset is too large to sensibly vendor into this benchmark. Download it in MATLAB with:

```matlab
download_cdnet2014;
```

or place an existing CDnet 2014 extraction under:

```text
dataset/cdnet2014/dataset/<category>/<sequence>/
```

The loader also recognizes an extraction whose root is `dataset2014/` rather than `dataset/`.

A tiny synthetic CDnet-shaped sequence is included at `dataset/synthetic_demo/baseline/synthetic_square` so I/O, metrics and visualization can be smoke-tested without downloading CDnet.

## Fast headless comparison (recommended)

```matlab
cfg = benchmark_config;
cfg.dataset.root = 'D:/data/CDnet/dataset';
cfg.dataset.category = 'baseline';
cfg.dataset.sequence = 'highway';
cfg.rank = 5;
summary = run_all_algorithms(cfg);
```

The headless runner loads a sequence once and executes one tracker at a time. By default it stores both the loaded video matrix and foreground scores as `single`, promotes only the current frames/warm-up blocks inside the adapters, and does **not** retain dense background/residual matrices unless they are needed for a requested video/background export or `cfg.execution.retainFullResults=true`. This is the recommended path for full CDnet sequences.

Results are saved under `output/<category>/<sequence>/` as MAT files plus `comparison.csv` and `comparison.png`. By default the runner also writes a compact `plot_data.mat` bundle that can regenerate all publication figures later without rerunning a tracker or rereading CDnet. The sequence is read once and reused for all algorithms. By default, large `L/S/score` matrices are released after each method; set `cfg.execution.retainFullResults=true` if you explicitly want them returned in `summary`.

For framework tests and an installed-algorithm smoke test:

```matlab
run_tests
```

### Fast CDnet highway diagnostics

Before spending time on the full 1700-frame run, verify the real dataset paths, ROI palette, GT palette, and loader provenance:

```matlab
report = check_cdnet_highway;
% or: report = check_cdnet_highway('/path/to/CDnet/dataset');
```

The checker samples three frames across the official temporal ROI, prints the exact input/GT/ROI files used, prints the decoded GT labels and ROI coverage, compares the loaded `seq.M`/GT arrays back to the source files, and writes `output/diagnostics/highway_check/input_gt_roi_check.png` plus `source_files.csv`. `report.pass` must be true before interpreting CDnet metrics.

Then run the end-to-end short tracker test:

```matlab
summary = quick_cdnet_smoke;
% optionally restrict methods:
% summary = quick_cdnet_smoke([], {'GRASTA','GREAT','GeRoST'});
```

`quick_cdnet_smoke` uses actual `baseline/highway` frames around the start of the temporal ROI, downsamples them to 12.5% resolution, shares one `U0` across all methods, reduces expensive iteration counts, disables video writing, and retains backgrounds only for this tiny run. Each successful algorithm gets a PNG with columns `input | background | foreground-score | binary-mask | ground-truth` under `output/quick_smoke/baseline/highway/<algorithm>/`. These settings are diagnostic only and should not be used for reported benchmark numbers.

### Initialization / CDnet GT sanity checks

Every adapter resolves its starting basis from the canonical
`context.sharedInitialization.U0` object. `run_all_algorithms` computes this
basis once and passes the same matrix to GRASTA, ReProCS, GREAT and GeRoST;
`context.initialSubspace` is retained only as a legacy compatibility alias.
The tests verify both the basis equality and the canonical initialization
source.

At the start of a CDnet run the benchmark now prints how many temporal-ROI
ground-truth frames were matched and how many moving/static-shadow pixels were
decoded. CDnet GT PNGs are read with palette-aware decoding before applying
the canonical labels `0/50/85/170/255`. Missing GT frames are excluded rather
than being silently treated as static background. If Recall/F1/AUC are NaN,
inspect these two diagnostic lines before tuning tracker hyperparameters.

For a quick end-to-end visual smoke test:

```matlab
demo
```

For a concrete CDnet baseline/highway example:

```matlab
summary = demo_cdnet('D:/data/CDnet/dataset');
```

Set `cfg.output.makeVideo=true` to write, for each method, an `input | background | binary-mask` video plus a multi-method mask comparison video. MPEG-4 is used when MATLAB exposes that profile; otherwise the writer falls back to Motion JPEG AVI (notably on Linux).


## Replot figures without rerunning algorithms

Every normal benchmark run now saves:

```text
output/<category>/<sequence>/plot_data.mat
```

This file is intentionally plotting-only: it contains the final table,
per-frame confusion-count/score sufficient statistics, ROC data, sampled
scalar subspace diagnostics, the requested one-frame FG/BG snapshot, and
GeRoST's `xi_hat/rho/lambda*` scalar histories. It does **not** contain the
full video, masks, score video, background video, or subspace matrices.

After the expensive simulation has finished once, regenerate figures with:

```matlab
plot_results('output/baseline/highway');
```

`plot_results.m` has an editable settings block. For example:

```matlab
o = struct();
o.smoothingWindow = 30;
o.timeMetricAlgorithms = {'GREAT','GeRoST'};
o.gerostSmoothingWindow = 15;
o.comparisonFileName = 'paper_comparison.pdf';
plot_results('output/baseline/highway',o);
```

No tracker or CDnet file is touched. See `REPLOTTING.md` for all switches.
Set `cfg.output.savePlotData=false` only when you explicitly want to minimize
diagnostic overhead and do not need later replotting.

## GUI

```matlab
lrs_gui
```

The GUI is intentionally implemented as a normal `.m` file (no App Designer binary) so it is easy to version-control and modify.

A small `dataset/demo.avi` is also included for the LRSLibrary-style `process_video` wrapper:

```matlab
process_video('ST','GeRoST','dataset/demo.avi','output/demo_GeRoST.mp4',benchmark_config);
```

## Multi-sequence benchmark

```matlab
cfg = benchmark_config;
cfg.dataset.root = 'D:/data/CDnet/dataset';
cfg.dataset.categories = {'baseline','dynamicBackground'};
allResults = benchmark_cdnet(cfg);
```

Set `cfg.dataset.categories = {'all'}` to scan every category. To restrict sequences, set `cfg.dataset.sequences` to a cell array of sequence names.

## Evaluation policy

Each adapter produces a continuous foreground score and can return a background matrix `L` when requested. In the memory-efficient headless path, `L` is not retained unless a video/background/full-result output requires it. The common score is the magnitude of the frame minus the current low-rank/background estimate. A binary threshold is calibrated without ground truth from pre-evaluation/warm-up residuals via a robust median/MAD rule. This keeps thresholding and optional morphology outside the algorithm adapters.

Reported metrics include Precision, Recall, Specificity, FPR, FNR, PWC, F1, IoU, MCC, histogram ROC AUC, runtime and FPS. AUC is threshold-free and is useful when comparing trackers whose residual scales differ.

## GREAT / GeRoST parameters worth tuning on CDnet

The highest-impact algorithm-side knobs are `window`, `K`, and `istaLambda` for both GREAT and GeRoST; GeRoST additionally exposes `dataRank`/`dataRankOffset`, `rhoNsrCap`, `rhoScale`, `fallback`, and optional fixed `alpha`. The upstream foreground/background example uses `window=30`, `K=5`, `d=k+2`, an adaptive-rho cap of `0.15`, and five sparse/background refits. Because this loader scales CDnet frames to `[0,1]`, the benchmark defaults `istaLambda=0.02` rather than copying the upstream synthetic value `1.0`.

For `baseline/highway`, a sensible first sweep is `window=[20 30 45 60]`, `K=[3 5 8]`, `istaLambda=[0.005 0.01 0.02 0.03 0.05]`, and for GeRoST `dataRank=k+[1 2 3 4]`, `rhoNsrCap=[0.10 0.15 0.20]`. Keep `alpha=[]` initially so the upstream step-size rule remains active. See `docs/TUNING_GREAT_GEROST.md` for interpretation and example configuration.

## Important reproducibility notes

1. **Initialization is shared by construction.** `run_all_algorithms` computes one rank-k SVD basis from the first `cfg.trainFrames` frames and passes that exact `U0` matrix to GRASTA, ReProCS, GREAT and GeRoST. GRASTA's normal first-call randomization/private warm-up is bypassed, and ReProCS's optional private robust initializer is bypassed in benchmark mode.
2. **ReProCS memory.** The original reference code forms `I - PP'` explicitly. The adapter in this benchmark uses the same projected-CS update but constructs only support-restricted projectors, avoiding an `n x n` dense matrix for video-sized `n`.
3. **GREAT/GeRoST flow and memory.** GREAT and GeRoST follow the `shreyasnb/GeRoST` case-2 foreground/background order: track the current sample, then perform the short alternating sparse/background decomposition. GeRoST additionally uses the case-2 instantaneous residual-to-signal adaptive-rho rule by default. The adapters preserve the per-step equations while replacing full-video histories with fixed-size sliding-window state.
4. **CDnet labels.** Motion=255, static=0, hard-shadow=50 (negative class), outside ROI=85 and unknown=170 (ignored).
5. **No hidden tuning.** Algorithm and foreground threshold parameters live in `benchmark_config.m` and are written into each result bundle.
6. **Resolution.** `cfg.io.resizeScale=1` preserves CDnet resolution. If you downsample, the loader downsamples input, GT and ROI consistently, but those results are no longer directly comparable to official full-resolution CDnet scores.

## Primary upstream references

- LRSLibrary: https://github.com/andrewssobral/lrslibrary
- GRASTA: https://sites.google.com/site/hejunzz/grasta
- ReProCS: https://github.com/praneethmurthy/ReProCS
- GREAT paper: https://arxiv.org/abs/2412.09052
- GREAT original code: https://git.ethz.ch/asasfi/ST_for_sysID
- GeRoST / GREAT implementation used for the GeRoST comparison: https://github.com/shreyasnb/GeRoST
- GeRoST paper: https://arxiv.org/abs/2604.00825v1
- CDnet: https://changedetection.net/
- Manopt: https://www.manopt.org/

Use the original papers and upstream repositories for definitive algorithm definitions and citations.

## Benchmark validation and performance diagnostics

Before committing to a full 1700-frame highway run:

```matlab
check_cdnet_highway;          % files, ROI and GT decoding
quick_cdnet_smoke;            % tiny end-to-end tracker check
diagnose_grasta_highway;      % compare GRASTA CDnet step profiles
profile_gerost_speed;         % GREAT vs upstream/reduced GeRoST timing
```

GRASTA defaults to `profile='lrslibrary'`: every method still receives the same exact `U0`, while the online phase uses LRSLibrary's documented constant `1e-2` step and a 20-iteration ADMM budget. The benchmark deliberately omits GRASTA-only private training so initialization remains fair. `sharedAdaptive` (native adaptive scale learned from the first online CDnet frame) and `gerostCase2` remain available for diagnosis/replication.

GeRoST defaults to `innerMaxImplementation='reduced'`. This is an algebraically equivalent low-rank implementation of the public worst-case eigenspace calculation: the basis of `span([Y,What])` is formed once per inner solve and all bisection eigendecompositions occur in at most `d+k` dimensions. Use `innerMaxImplementation='upstream'` for direct reference-code reproduction. See `PERFORMANCE_NOTES.md`.


## Saved foreground/background snapshot PDF

`demo_cdnet` now saves a one-frame visual comparison for GRASTA, GREAT and
GeRoST in the sequence output directory.  For the Highway demo the default
snapshot is native CDnet frame 1000:

```text
output/baseline/highway/fg_bg_snapshot_frame001000.pdf
```

The figure has one row per algorithm and three columns: **Original**,
**Foreground**, and **Background**.  The runner does not enable full
background-history storage for this.  Each adapter keeps only the requested
background column while it is already processing that frame, so the memory
cost is roughly one image per algorithm.

To choose another native CDnet frame in a custom run:

```matlab
cfg = benchmark_config();
cfg.dataset.category = 'baseline';
cfg.dataset.sequence = 'highway';
cfg.algorithms = {'GRASTA','GREAT','GeRoST'};
cfg.output.makeSnapshotPdf = true;
cfg.output.snapshotFrame = [800 1000 1200]; % save a few cheap snapshots if desired
summary = run_all_algorithms(cfg);
```

After such a run, the PDF can be regenerated from the saved `result.mat`
files **without rerunning any tracker**:

```matlab
plot_saved_snapshot(summary.outputDir);
% or:
plot_saved_snapshot('output/baseline/highway', 1000, ...
    {'GRASTA','GREAT','GeRoST'});
```

Runs created by older versions with the default `saveBackground=false` and
`saveScores=false` did not retain a time-specific background image, so their
CSV/result files cannot reconstruct this figure retroactively.  In that case
one updated run is required; future PDF regeneration is then free of tracker
computation.


## Time-resolved metric PDFs

Set `cfg.output.makeTimeMetricPdfs=true` to save frame-number plots without
persisting full score/background/subspace histories. `demo_cdnet` enables
this automatically for GRASTA, GREAT and GeRoST. The output directory receives
`segmentation_metrics_vs_frame.pdf`, `roc_curve.pdf`,
`foreground_score_vs_frame.pdf`, and `subspace_distance_vs_frame.pdf`.

The time plots now pool TP/TN/FP/FN before recomputing nonlinear metrics such
as precision/F1/IoU, rather than averaging already-computed frame metrics.
Foreground/background score means are pixel-count weighted. `roc_curve.pdf`
is a genuine threshold-swept ROC using the same histogram accumulation as the
reported AUC; the old connected frame-wise TPR/FPR trajectory was not a ROC
and has been removed.

The segmentation traces use the same single calibrated threshold as the final
benchmark result; thresholds are not retuned per frame. CDnet does **not**
provide a true latent subspace, so `referenceMode='auto'` now plots only
per-update subspace motion unless a true/reference basis is supplied. Use
`referenceMode='initial'` explicitly if you want drift from common `U0`, or
`referenceMode='true'` with `trueSubspace` / `trueSubspaceHistory` for a true
synthetic subspace-error curve. See `TIME_METRICS.md` for details.
