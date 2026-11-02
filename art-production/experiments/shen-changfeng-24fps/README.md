# Shen Changfeng 24 FPS interpolation experiment

Status: **candidate / visual validation only**. Do not replace the in-use sprite atlas.

Source: the user-provided 8-column × 4-row Shen Changfeng sprite sheet (1774 × 887, RGBA). Row mapping for this experiment: idle, walk, attack, guard.

The generated previews and transparent atlases were created in the conversation workspace, but **binary outputs and the second source sheet are not committed by this PR**. Reproduce them locally with the attached script after providing the source image. This PR is therefore a reproducible experiment, not a game integration.

Method: preserve original image proportions; crop on proportional cell boundaries; place each cell on a 224 × 224 transparent canvas with bottom alignment; calculate Farneback optical flow between consecutive source frames; interpolate two in-between frames per original frame; export 24-frame GIF previews and transparent 8 × 3 atlases.

Limitations: optical flow can cause sword/hand ghosting, the wrap from frame 8 to 1 may be unnatural for non-looping attack/guard actions, and anchoring the canvas bottom does not guarantee a fixed planted foot. These outputs are **not approved** for runtime use.

Acceptance before promotion: inspect planted foot, sword silhouette, frame transitions, single-sword consistency, clipping and transparent edges; manually repair failing in-betweens and define non-looping action playback.
