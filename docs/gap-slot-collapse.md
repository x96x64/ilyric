# Gap Slot Collapse

## Outcome and Scope

October 11, 2026. **An instrumental-gap slot now opens only when the gap begins, instead of appearing as a blank space in advance.** The maintainer observed that iLyric reserved an empty slot for the gap indicator below the current line, whereas the native screen keeps lyric lines adjacent and opens the space when the gap arrives. The behavior follows the maintainer's description of the native screen; the opening motion itself has not been measured.

A frame comparison during this work also showed that one apparent gap in the Man in the Mirror video was artificial. The native screen displays a refrain consisting only of vocables at that point, which iLyric had omitted; vocable lines are now omitted only when the alignment produced no estimate for them.

## Implementation

`LyricsComposition` gains an opt-in `collapsesGaps`. Each gap slot has an openness between 0 and 1 that is zero until focus reaches the gap, approaches one with the critically damped response and time constant of the focus motion, and returns to zero in the same way after the next focus event. Every item laid out below a gap moves up by the slot height times the gap's closed fraction, relative to the focus target, so the focused item never jumps; at each focus change the closed fractions involved are continuous. `LocalPresentation.collapsesGaps` enables the behavior, and `LyricsInputProbe --motion measured` turns it on.

A test confirms that the next line sits one slot height higher before the gap, that the layout matches a reserved slot while the gap holds focus, and that the line before the gap moves down to close the slot afterwards.

## Limitations

The opening and closing motion reuses the focus time constant rather than a measured value.

Neither release readiness nor native iOS 27 Music fidelity is established.
