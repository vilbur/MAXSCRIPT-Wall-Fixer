# Changes

2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer.ms`: optimized `SLICE SELECTED WALLS` command-panel handling; Edit Poly Modify context is activated only when the required node/modifier is not already active, repeated per-task Modify-panel refreshes were removed, the batch no longer switches to Create mode after every processed object, and the original command-panel mode/subobject level is restored once after the batch; added `testSliceModifyContextGuards`; project version 0.78.

2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: EDGE FIXER `Angle` now defines the maximum allowed deviation from the requested horizontal/vertical direction; CHECK selects edges above that deviation, so 0° selects every non-matching direction and 45° is the horizontal/vertical crossover; added `testDirectionAngleThreshold`; project version 0.77.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: SLICE WALLS now has a `Select` button beside `9. SLICE SELECTED WALLS`; LMB filters the current selection to objects with Wall-Fixer slice modifiers, RMB filters to objects without them, and an empty selection uses all visible geometry; added slice-modifier classification test; project version 0.76.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: GET OUTER WALLS `LAYER` now assigns selected single-class wall objects to the matching `-OUTTER`, `-INNER`, `-TOP`, or `-BOTTOM` sibling layer after creating/reusing the class layers; mixed or unclassified selections are left unchanged and reported; project version 0.75.

2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: CHECK HORIZONTAL/CHECK VERTICAL and selected-edge straighten now evaluate all Editable Poly/Edit Poly topology edges instead of excluding candidates by edge visibility; fixes skewed boundary edges such as vertex pair 2–4 being skipped. Border/reference visibility logic remains unchanged; project version 0.69.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: fixed EDGE FIXER CHECK HORIZONTAL/CHECK VERTICAL result handling so integer check counts and `#(fixed_count, has_failed_edges)` straighten results are normalized to an explicit Boolean before UI status branching; added `testStraightEdgeResultNormalization`; project version 0.68.

2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: fixed Border Check Editable Poly/Edit Poly adapter dispatch so native selection APIs receive the concrete geometry source instead of the adapter array; parenthesized remaining adapter source arguments to avoid call/index ambiguity; project version 0.67.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: increased expanded nested subrollout slot heights by 24 px (one collapsed rollout header) for GET OUTER WALLS OPTIONS and EDGE FIXER OPTIONS; collapsed slots remain 24 px; project version 0.66.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: moved GET OUTER WALLS `GROUND PIVOT` onto the top Working Pivot row, shifted the remaining OPTIONS controls upward, and reduced the expanded OPTIONS/parent heights to match; project version 0.65.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added GET OUTER WALLS `LAYER` button after EXPLODE; LMB creates/reuses sibling layers beside the current layer named `{Current}-INNER`, `{Current}-OUTTER`, `{Current}-TOP`, and `{Current}-BOTTOM`; project version 0.64.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added GET OUTER WALLS `GROUND PIVOT` option; when enabled, INNER \ OUTTER forces the active analysis origin and actual Working Pivot to world Z = 0 while preserving X/Y from Use Edit Pivot or selection center; debug trace schema now records Ground Pivot state; project version 0.63.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added GET OUTER WALLS DEBUG TRACE mode and PRINT DEBUG report; debug analysis now records selection center, analysis origin, Working Pivot state, thresholds, original face selection, forced faces, per-face classes/scores/resolution reasons, counts and transform in object user properties, while the report prints live vertex/face geometry and Material IDs; RESET clears trace properties; project version 0.62.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: AUTO GROW now discovers live classified scene walls instead of requiring cache membership; FORCED faces act as local barriers instead of blocking whole objects; Wall Thickness now stops a connected candidate when another wall object exists across that candidate within the configured thickness; project version 0.61.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: restored RMB/CTRL+RMB handling for the GET OUTER WALLS class row; OUTER/INNER force and CTRL+RMB auto-grow now auto-analyze fresh geometry first, while TOP/BOTTOM RMB/CTRL+RMB assign cap classes without auto-grow; project version 0.60.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: moved `5. FIND TWO-EDGE VERTS AND REMOVE` to POST-PROCESS, removed pre-process `7. FIX N-GONS`, and moved EDGE FIXER `OPTIONS` to the bottom so it expands downward; project version 0.59.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: fixed GET OUTER WALLS `OPTIONS` rolled-state mapping so expanded uses full slot/parent height and collapsed uses compact height; project version 0.58.

2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: Helpers Attach RMB now welds with the live `Wall-Fixer > Options > Weld Threshold` value instead of hardcoded `0.0`; project version 0.56.
2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: fixed GET OUTER WALLS layout to 310 px parent width, 4 px side padding, balanced action/class buttons, full-width OPTIONS slot, widened OPTIONS controls, and corrected OPTIONS rolled-state height handling; project version 0.55.
2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: Helpers Attach RMB now attaches selection, centers the merged pivot, welds all vertices at 0.0, and uses `PolyToolsModeling.Quadrify false false` when the merged target has at most 12 triangular faces; project version 0.54.
2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: full-row parent controls and parent group boxes now use 4 px side padding; added `testParentControlWidths`; project version 0.53.
2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: subrollout slot widths now use parent rollout width minus 8; project version 0.52.
2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: uppercased `GET OUTER WALLS` rollout title; project version 0.51.

- 2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: EDGE FIXER `OPTIONS` now mirrors Get Outer Walls rolled-state behavior; EDGE FIXER, Get Outer Walls, and main workflow subrollout slots use the full parent width; EDGE FIXER full-row controls retain 4 px side padding when OPTIONS is toggled. Project version 0.57.
