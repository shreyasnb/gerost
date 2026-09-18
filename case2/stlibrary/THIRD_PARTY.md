# Third-party code and licenses

This benchmark contains adapter code and installers. The upstream algorithm repositories are **not embedded** in this archive; `libs/setup_third_party.m` downloads them into your working copy.

| Component | Source | Upstream license / note |
|---|---|---|
| GRASTA | https://github.com/andrewssobral/lrslibrary/tree/master/algorithms/st/GRASTA | Files include LGPL/GPL/license notices; preserve them. |
| ReProCS | https://github.com/praneethmurthy/ReProCS | MIT for the repository; bundled YALL1/PROPACK/helper code may carry their own notices. |
| GeRoST + GREAT baseline used by this benchmark | https://github.com/shreyasnb/GeRoST | GPL-3.0. The repository includes the `great.m` baseline used in the GeRoST paper experiments. |
| GREAT original project | https://git.ethz.ch/asasfi/ST_for_sysID | Reference implementation for the GREAT paper. This benchmark intentionally uses the `great.m` copy in the GeRoST repository so GREAT/GeRoST are compared with the same implementation used by the GeRoST authors. |
| Manopt | https://github.com/NicolasBoumal/manopt | See upstream license. |
| CDnet 2014 | https://changedetection.net/ | Dataset terms/citation are controlled by CDnet; do not assume this benchmark's code license covers the data. |

If you redistribute a checkout after running `setup_third_party`, keep all upstream license and attribution files and comply with each upstream project's terms. The GeRoST repository is GPL-3.0, so review its requirements before redistributing a combined bundle.
