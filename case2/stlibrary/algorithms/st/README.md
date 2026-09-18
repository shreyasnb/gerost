# ST adapters

Each method directory contains a `run_alg.m` adapter, matching the convention used by LRSLibrary. The root `run_algorithm.m` temporarily places one adapter directory at the front of the MATLAB path, invokes `run_alg`, and removes it again so identically named wrappers do not collide.

Common adapter output fields:

- `L`: background / low-rank estimate, pixels x frames.
- `S`: residual, pixels x frames.
- `score`: continuous foreground score, pixels x frames.
- optional `Ufinal`, native masks or diagnostic state.

All foreground thresholding and CDnet metrics are intentionally outside these adapters.
