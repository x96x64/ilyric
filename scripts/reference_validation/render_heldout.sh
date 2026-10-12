#!/bin/zsh
# Renders each held-out song with the released command from its read lyrics and its library audio (read only),
# for comparison with the capture. Usage: render_heldout.sh N01 [...]
set -u
R=reference-private; O=$R/analysis/visual-qualification
M="$REFERENCE_AUDIO"
MODELS="$ILYRICS_MODELS"
for n in "$@"; do
  rel=$(grep "^$n" $R/new-captures/assignment.md | cut -f3)
  [ -f "$O/$n-ilyrics.mp4" ] && continue
  ILYRICS_MODELS=$MODELS .build/release/ilyrics render "$M/$rel" "$O/$n-lyrics.txt" -o "$O/$n-ilyrics.mp4" \
    --report "$O/$n-report.json" -q || echo "render failed $n"
done
echo done
