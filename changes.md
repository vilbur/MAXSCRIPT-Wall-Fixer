# Changes

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
