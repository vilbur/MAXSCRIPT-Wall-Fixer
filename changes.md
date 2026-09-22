# Changes

2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: replaced direction-angle `atan2` calculation with explicit vector-length geometry using `acos(abs(dz) / edge_length)`. This makes angle-from-vertical and angle-from-horizontal unambiguous; the reported edge 6–13 case evaluates to about 2.67° from vertical and falls inside an Angle=40 check. Extended `testDirectionAngleThreshold` with matching vertical/horizontal regression vectors; project version 0.922.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: Smart Explode confirmed-split failures now fall back to the source Editable Poly element groups; when a higher-priority NORMALS / FACE DIRECTION / XY POSITION detach fails but multiple mesh elements remain, those elements are detached instead of returning the source as failed; fallback logs the detected element count and counts as a successful split; project version 0.921.

2026-09-22 — `Wall-Fixer-Pipeline.ms`, `Wall-Fixer-Core.ms`, `Wall-Fixer.ms`: fixed `SLICE SELECTED WALLS` for selected topology created by a previous slice; selected Edit Poly vertices that do not map to base-object vertices are captured as live world-space slice planes before old slice modifiers are rebuilt, Edge subobject selection uses its edge endpoints and prefers the selected edge as the direction source, and selected-live slicing may use internal slice edges such as vertex pairs `12-14` and `8-13`; base-mapped selected vertices keep the existing fast path; added selected-live slice tests; project version 0.92.

2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: corrected EDGE FIXER direction-angle selection semantics. CHECK HORIZONTAL now selects only edges within 0..Angle degrees of horizontal; CHECK VERTICAL selects only edges within 0..Angle degrees of vertical. The threshold is inclusive and `testDirectionAngleThreshold` now validates 0°, boundary, and just-over-boundary behavior; project version 0.89.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added Slice Walls `H \ V` button between the main Slice and Select controls; LMB/RMB activate `SLICE HORIZONTAL` / `SLICE VERTICAL`, and CTRL variants also enter Edge sub-object level 2; project version 0.91.

2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added HELPERS `Split`; LMB requires one selected geometry object and one selected edge, supports Editable Poly and top Edit Poly, splits the edge, explodes disconnected elements, cleans redundant vertices, and succeeds when exactly two objects result; project version 0.90.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added sequential main pipeline rollout prefixes: `1 PRE-PROCESS & FIX GEOMETRY`, `2 GET OUTER WALLS`, `3 EDGE FIXER`, `4 SLICE WALLS`, and `5 POST-PROCESS`; `Options` and `HELPERS` remain unnumbered; project version 0.89.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: renamed the Slice Walls main action from `9. SLICE SELECTED WALLS` to `9. SLICE WALLS`; project version 0.88.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added HELPERS `Align Camera`; LMB reads selected Editable Poly/top Edit Poly wall faces, builds an averaged world-space face normal, transfers that orientation through a temporary orthographic camera into User view, deletes the camera, and Zoom Extents Selected frames the selection; project version 0.87.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: fixed rollout-state persistence crash triggered by `SLICE SELECTED WALLS`; replaced invalid rollout `.rolledUp` reads with native rollout `.open` and invert the value when storing the existing `1 = rolled up` INI format; added `testRolloutOpenPersistence`; project version 0.85.

2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer.ms`: fixed `SLICE SELECTED WALLS` LMB directional dispatch; Vertical now builds only the `SLICE VERTICAL` pass, Horizontal builds only the `SLICE HORIZONTAL` pass, while `#all` remains a single mixed pass and the UI RMB both-modes action remains separate; added `testSliceDirectionalPassKinds`; project version 0.84.

2026-09-22 — `Wall-Fixer-Pipeline.ms`, `Wall-Fixer-Core.ms`, `Wall-Fixer.ms`: optimized large `SLICE SELECTED WALLS` batches by treating Edit Poly slice-created topology as appended indices; new edges are detected from the appended edge range instead of comparing every current edge against every pre-slice edge, Slice Precision inspects only appended vertex IDs, and sliced-edge cleanup inspects only newly reported edges plus their touched vertices; geometric re-resolution remains for topology-changing cleanup operations; added appended-index tests; project version 0.83.

2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added a progress-bar overlay showing object progress as `x \ n` plus current object name and vertex count; Core now supplies object context alongside task progress, and running/idle visibility is synchronized so the progress area replaces the idle status area only while work is active; project version 0.82.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: rollout rolled-up/expanded states are now persisted in `Wall-Fixer.ini` and restored for all parent workflow rollouts plus nested EDGE FIXER / GET OUTER WALLS Options rollouts; project version 0.81.

2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer.ms`: successful `SLICE SELECTED WALLS` runs now record elapsed processing time, processed object count, and total processed source-vertex count in the success report and append each successful run to `Wall-Fixer-Slice-Stats.csv` in the 3ds Max plugcfg folder; project version 0.80.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: removed `SLICE WALLS > CHECK RESULT` and compacted the Slice Walls rollout; updated the parent-width layout test; project version 0.79.

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
## 2026-09-22
- `Wall-Fixer-UI.ms`: fixed the stray comma after `testRolloutOpenPersistence`, which caused an init-time MAXScript parser error.
- `Wall-Fixer.ms`: applied the same fix to the bundled UI snapshot; bumped bundled loader/UI project registration to 0.86.
- Verified the standalone UI has no other function-ending `),` parser pattern at top level.

