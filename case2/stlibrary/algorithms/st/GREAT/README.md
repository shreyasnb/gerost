# GREAT adapter

The reference benchmark uses `great.m` from the public GeRoST repository so the GREAT baseline is the same implementation family used in the GeRoST experiments. The original GREAT project is linked in `THIRD_PARTY.md`.

For fairness, GREAT receives the benchmark-wide shared `U0` computed once from the common warm-up frames. Its online update mirrors the upstream `great.descent_step`: maintain the last `window` samples, compute the leading window singular value, take `K` Grassmann gradient steps, and update `U`.

For foreground/background separation the adapter also mirrors `case2/bg_fg_main.m`: after updating the subspace, it alternates soft-thresholding of the residual and least-squares coefficient refitting for `istaIterations` steps. The CDnet loader scales frames to `[0,1]`, so `istaLambda` should be tuned on that scale (the upstream synthetic example uses much larger signal/foreground amplitudes).

The upstream class retains every sample and a full `n x k x num_steps` subspace history. This adapter retains only the active window, so the update equations are preserved without video-length storage growth.
