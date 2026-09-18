# GeRoST adapter

The frame ordering follows the public GeRoST Case-2 foreground/background experiment:

1. receive the common benchmark `U0`;
2. compute instantaneous residual-to-signal ratio using the pre-update subspace;
3. map the capped ratio to adaptive `rho_t`;
4. update the sliding-window rank-`d` nominal subspace and take `K` GeRoST Grassmann steps;
5. run the short foreground/background ISTA decomposition using the updated subspace.

The upstream class preallocates full `samples`, `masks_full`, and `U_history`; this adapter keeps only the active window and cached rank-`d` eigenspace.

## Reduced inner maximization

The public `gerost.inner_max` calls `lowrank_topd_eig` repeatedly during bisection, and `lowrank_topd_eig` recomputes `orth([Y,What])` on every evaluation. That is unnecessarily expensive for CDnet ambient dimensions.

The default `innerMaxImplementation='reduced'` exploits

`rank(lambda*P_What - P_Y) <= d+k`.

It constructs the ambient basis for `span([Y,What])` once per GeRoST inner solve, performs bisection eigendecompositions entirely in this at-most-`(d+k)` dimensional basis, and computes the gradient action without forming a dense projector. The optimization problem and worst-case subspace are unchanged.

Set `innerMaxImplementation='upstream'` to call the reference static method. `bisectTol=1e-6` is the default for the reduced implementation; `profileTiming=true` records stage timings in `result.state.timing`.

Run `profile_gerost_speed` for a short direct comparison.
