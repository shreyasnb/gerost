# ReProCS adapter

The public foreground/background ReProCS code uses YALL1 for projected sparse recovery, support least squares, and periodic projection-PCA updates. Its older implementation explicitly constructs `speye(n) - P*P'`, which becomes a dense `n x n` matrix and is not practical for full video frames.

This adapter performs the same projection algebra through function handles and constructs only support-restricted projector columns for the LS step. It therefore remains usable at CDnet dimensions. Upstream `YALL1_v1.4`, `cgls.m`, `proj_PCA_thresh.m`, and optionally `ncrpca.m` are loaded from `libs/ReProCS`.
