#!/bin/zsh
# Renders each held-out song with the command from its read lyrics and its library audio (read only), for comparison
# with the capture. The audio folder and the installed models are machine-specific and come from the environment:
# REFERENCE_AUDIO is the folder that the third column of reference-private/new-captures/assignment.md is relative to,
# and ILYRICS_MODELS the models folder. Usage: render_heldout.sh N01 [...]
set -u
R=reference-private; O=$R/analysis/visual-qualification
for n in "$@"; do
  rel=$(grep "^$n" $R/new-captures/assignment.md | cut -f3)
  [ -f "$O/$n-ilyrics.mp4" ] && continue
  .build/release/ilyrics render "$REFERENCE_AUDIO/$rel" "$O/$n-lyrics.txt" -o "$O/$n-ilyrics.mp4" \
    --report "$O/$n-report.json" -q || echo "render failed $n"
done
echo done
