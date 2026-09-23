2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: removed the slash separator from the EDGE FIXER direction button captions; they now read `VERTICAL SKEWED` and `HORIZONTAL SLOPED`. Mouse routing and direction-selection behavior are unchanged; project version 1.002.

2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: removed the slash separator from the EDGE FIXER direction button captions; they now read `VERTICAL SKEWED` and `HORIZONTAL SLOPED`. Mouse routing and direction-selection behavior are unchanged; project version 1.002.

2026-09-23 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: EDGE FIXER direction detection now uses the stable world-space `acos` axis-deviation classifier for exact and Angle checks; added direct `#horizontal`, `#vertical`, `#skewed`, and `#sloped` selection tests; Straight Edge Fixer 0.43, bundled loader 0.984, project version 1.001.

2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: widened GET OUTER WALLS `INNER \\ OUTTER` to 126 px so the title stays on one line, rebalanced adjacent `EXPLODE` and `LAYER` buttons to 84 px each, and corrected `testWallFaceOptionsLayout` to the current three-button row; project version 1.000.

2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added HELPERS > Select Degenerated Objects; LMB scans visible geometry non-destructively and selects objects whose evaluated vertices collapse to one non-zero line and whose evaluated vertex normals all share one direction. Added pure rule regression coverage; project version 0.999.

2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: GET OUTER WALLS layer creation and assignment now build class targets from the complete current layer name plus the class suffix, e.g. `WALLS-01-OUTTER`; added a pure naming regression test; project version 0.998.

2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: increased the remaining numbered WinForms workflow button heights by about 4 px where they were shorter than the established 38 px controls, improving wrapped/two-line title fit without changing positions, widths, text, or event routing; project version 0.997.

2026-09-23 — `Wall-Fixer-Core.ms`, `Wall-Fixer.ms`: Slice Walls now clears Face selections on every processed Editable Poly/top Edit Poly object after the batch, before restoring/focusing the final result; final Edge-level completion behavior is preserved; project version 0.996.

2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: fixed Slice Walls progress visibility by moving the .NET running-progress label below the native progress bar so it no longer visually covers the green bar; object/task progress text remains visible; project version 0.995.

2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added DEBUG > Dialog Info, a read-only Listener diagnostic reporting current dialog size, position, CUI registration state, and dock state; added layout test; project version 0.994.

2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: increased EDGE FIXER Vertical/Skewed and Horizontal/Sloped WinForms button heights from 34 px to 38 px without changing positions, widths, styling, or mouse routing; project version 0.993.

2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: locked the Wall-Fixer dialog width and removed resize-window styling while preserving CUI docking/floating, saved position, and saved height behavior; project version 0.992.

2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: EDGE FIXER Angle spinner field width reduced from 48 px to 40 px and the visible degree label was removed; direction behavior and angle range are unchanged; project version 0.991.

2026-09-23 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: fixed EDGE FIXER Horizontal/Vertical angle selection reading zero topology from a newly created or stale `STRAIGHT EDGE FIXER` Edit Poly. The geometry adapter now binds and prepares the modifier before any edge scan, forces evaluation only when needed, rebuilds a stale zero-topology named modifier once for Editable Poly sources, and `getEdgeCount` retries preparation before accepting a zero result. Added `testStraightEdgeFixerLiveTopology` and included it in `testDirectionCheckerRegression`; exact-LMB and Angle-based RMB semantics are unchanged. Project version 0.990.

2026-09-23 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: fixed the shared project-version registration that could make the UI title fall back to 0.987 even when the bundled loader was newer. Straight Edge Fixer was still using version epoch 2 while the loader/Core/UI use epoch 3; loading it reset `WallFixerVersion`, allowing the older UI project value to win afterward. Straight Edge Fixer now uses epoch 3, so the highest loaded project version remains authoritative. Project version 0.989.

2026-09-23 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: fixed the EDGE FIXER runtime error at bundled line 17571 (`Call needs function or class, got: undefined`). A previous Straight Edge refactor had dropped the complete low-level geometry helper / Border Check block, leaving calls such as `getEdgeCount`, `getEdgeVertIds`, `getVertexWorldPosition`, `isEdgeVisible`, `isHorizontalEdge`, and `isVerticalEdge` undefined. Restored the known-good helper block without replacing the newer checker/modifier logic and added `testGeometryAdapterHelpers`; project version 0.988.\n\n2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: changed SLICE WALLS `Select` to directional modifier filtering. LMB now selects/filters objects containing `SLICE VERTICAL`; RMB selects/filters objects containing `SLICE HORIZONTAL`. When the current selection is empty, both actions search all visible geometry. The previous generic SLICED/UNSLICED Select behavior was removed. Added `testSliceSelectDirectionalRouting`; project version 0.987.

2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: swapped the main `9. SLICE WALLS` mouse actions so LMB now runs `#vertical` and RMB runs `#horizontal`; updated the visible event guide, button tooltip, and `testSliceWallMouseRouting`. The existing single-action MouseDown dispatch and re-entry lock are unchanged; project version 0.986.

2026-09-23 — `Wall-Fixer-Core.ms`, `Wall-Fixer.ms`: fixed `WMC - FIX TWO-EDGE VERTS` leaving an Edit Poly with zero live topology. The dedicated modifier is now bound to its primary node, activated/evaluated, forced to Vertex level with cage off, and validated before use; stale zero-topology copies are rebuilt automatically. Slice processing no longer reuses this dedicated selection modifier for slicing, removes a stale zero-topology copy if encountered, and creates its own slicing modifier above valid copies. Added `testTwoEdgeVertsModifierLiveTopology`; project version 0.985.

2026-09-23 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added SLICE WALLS `Delete`; LMB removes every exact `SLICE VERTICAL` Edit Poly modifier from selected objects and RMB removes every exact `SLICE HORIZONTAL` modifier, preserving `SLICE ALL`, cleanup modifiers, and unrelated user modifiers. Moved the true-90° open-border corner selector out of `Slice Walls > Select` into a dedicated HELPERS `90° Corners` button; Slice Walls Select is again object filtering only. Also restored the requested single-method Slice Walls dispatch in the canonical UI: the main Slice action uses one locked `MouseDown` path and accepts only explicit Horizontal or Vertical modes. Added `testDirectionalSliceDeletePolicy`, `testSliceDeleteRouting`, and `testSliceCornerHelperRouting`; project version 0.984.

2026-09-23 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: SLICE WALLS `Select` CTRL+LMB now works on Editable Poly base objects as well as the current Edit Poly modifier. The current Edit Poly still takes priority when active; otherwise the selected object's Editable Poly base is used directly, with the same true-90° open-border corner rule and 180° exclusion. No modifier is created for the Editable Poly path. Added `testSlice90CornerPolySourceSupport`; project version 0.983.

2026-09-23 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: POST-PROCESS `5. FIND TWO-EDGE VERTS AND REMOVE` LMB now literally selects every vertex with exactly two visible real topology edges in the dedicated `WMC - FIX TWO-EDGE VERTS` Edit Poly modifier. Removed the straight-continuation/corner-angle filter, reuse/create the exact named modifier, keep it active at Vertex level, and verify modifier selection readback equals the detected BitArray; updated tooltip/status and regression test; project version 0.981.

2026-09-23 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: SLICE WALLS `Select` now uses CTRL+LMB to select only true 90° open-border corner vertices on the currently active Edit Poly modifier; straight 180° border vertices are excluded and the existing right-angle tolerance is used. Added a persisted `No edge cleanup` Slice Walls option; when enabled, Slice Precision still runs but the per-cut `Clean Up Sliced Edges` stage is skipped so slice-created edges remain on the top slice modifier for inspection. Added `testExact90BorderCornerRule`, `testSliceEdgeCleanupOption`, and `testSliceSelectCtrlCornerMode`; project version 0.980.

2026-09-23 — `Wall-Fixer-Core.ms`, `Straight-Edge-Fixer.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: enforced the project-wide no-cage rule. Editable Poly bases and Edit Poly modifiers used by Core/UI workflows now set `showCage = off`; EDGE FIXER no longer enables Show Cage when activating its dedicated modifier, newly created/reused fixer modifiers are forced off, and regression tests now require cage display to remain disabled. Added `testEditablePolyCageOff`; project version 0.979.

2026-09-23 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: fixed dedicated EDGE FIXER modifier reuse. `ensureSingleStraightEdgeFixerModifier` now searches for an existing named `STRAIGHT EDGE FIXER` first and returns it immediately; a new Edit Poly is created only when no existing named modifier is found. The helper no longer deletes/rebuilds duplicate entries as part of acquisition. Updated `testSingleStraightEdgeFixerModifier` to verify repeated adapter requests keep the same modifier reference and do not increase the modifier-stack count; project version 0.978.\n\n2026-09-23 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: fixed EDGE FIXER > Checkers for `HORIZONTAL` and `VERTICAL`. LMB remains exact zero-deviation only; RMB is now strictly `> 0°` and `<= Angle`, with vertical deviation read directly from the component-ratio/`asin` angle so tiny real skew such as 0.001 horizontal over 7.15 vertical (~0.008°) stays non-zero. Checker selection is written only to the per-object `STRAIGHT EDGE FIXER`, with that modifier activated in the Modify panel at Edge level before writing, Use Stack Selection disabled, Show Cage enabled, immediate `EditPolyMod.SetSelection` read-back verification, an active-modifier `EditPolyMod.Select` viewport refresh, and final read-back used for listener counts. Per-object exact/skewed IDs are printed as BitArrays, with detailed state diagnostics only on storage/display mismatch. Added `testDirectionCheckerRegression` covering exact/skewed vertical and horizontal edges, tiny non-zero deviation, selection persistence, active fixer modifier, and single-modifier reuse. Project version 0.977.

2026-09-23 — `Straight-Edge-Fixer.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added DEBUG `Angle of Edges`. LMB prints the selected edge IDs plus each edge's world horizontal and vertical deviation angles, preferring the existing `STRAIGHT EDGE FIXER` selection source without creating or changing modifiers; added `getEdgeDirectionAngles`, `testEdgeAngleDebugMath`, and `testDebugAngleOfEdgesButton`. The supplied wall diagnostic was from project 0.973, before the 0.974 dedicated-modifier selection-display fix, so no additional horizontal/sloped selection algorithm change was made from that older snapshot. Project version 0.976.

2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: fixed the main dialog title reverting during CUI dialog-bar registration/docking. Title updates now go through `wallFixerRefreshDialogTitle()`, the early UI-load caption write was removed, and the resolved global project version is re-applied after registration, dock/float restoration, and on dialog open; added `testWallFixerDialogTitle`; project version 0.975.

2026-09-23 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: fixed EDGE FIXER direction-check selections being counted but not visible after the dedicated `STRAIGHT EDGE FIXER` modifier was introduced. Edge selection writes now disable Use Stack Selection, set the modifier primary node and Edge level, read back the actual modifier selection for counts, and activate the dedicated modifier in the Modify panel for single-object checks. Skewed listener output now includes per-object edge IDs as a BitArray and warns if requested/actual selections differ. Added `testDirectionSelectionDisplayActivation`; project version 0.974.

2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: enabled both POST-PROCESS > WALLS COMPLETION steps. `14. ATTACH WALLS TO OBJECTS` now attaches the selected walls into the first selected target and welds the merged Editable Poly using Options > WELD DISTANCE. `15. WELD AND CONNECT WALL CORNERS` now detects open-border vertices that terminate on the interior of vertical open-border edges, divides the hit edge, snaps the branch vertex to the split point, and welds the resulting T-junction; both active/top Edit Poly and Editable Poly topology are supported. Added `testCornerTJunctionProjection` and `testWallsCompletionActions`; project version 0.973.

2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: fixed EDGE FIXER RMB direction selection so `VERTICAL \\ SKEWED` and `HORIZONTAL \\ SLOPED` are the literal set difference from their LMB exact selection inside Angle. RMB now tests `not exact-LMB-match AND angle <= threshold`; it no longer depends on the separately computed angle being strictly greater than zero, so any edge rejected by LMB can still be selected by RMB when it lies inside Angle. Preserved the single dedicated `STRAIGHT EDGE FIXER` modifier workflow from project 0.971 and updated `testDirectionAngleThreshold`; project version 0.972.\n\n2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: EDGE FIXER now uses exactly one dedicated `STRAIGHT EDGE FIXER` Edit Poly modifier per object. Every EDGE FIXER check/fix path creates this modifier only when missing, reuses it on later operations, never writes into unrelated Edit Poly modifiers or directly into Editable Poly, and removes lower duplicate named fixer modifiers while keeping the highest existing one. Added `testSingleStraightEdgeFixerModifier`; refreshed the bundled Straight Edge Fixer snapshot from standalone file version 0.33 so the 0.970 tiny-angle RMB fix remains included. Project version 0.971.

2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: corrected POST-PROCESS `5. FIND TWO-EDGE VERTS AND REMOVE` LMB to match the intended rule exactly: select only vertices with exactly two visible actual poly-topology edges whose directions continue straight; hidden edges do not count and corners are excluded. Visible-edge incidence is now derived from live Edit Poly topology and evaluated edge visibility together, avoiding triangulation-only candidates. Straightness tolerance is 2.0° for processed-wall numeric noise. Added `testFindTwoEdgeVertsVisibleSelection`; project version 0.970.\n\n2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: fixed POST-PROCESS `5. FIND TWO-EDGE VERTS AND REMOVE` LMB. The finder now selects every live Editable Poly/Edit Poly vertex with exactly two actual topology edges instead of requiring exactly two visible TriMesh edges plus near-perfect collinearity; selection is applied directly with `SetSelection`. Updated the tooltip and added `testFindTwoEdgeVertsTopologySelection`; project version 0.969.\n\n2026-09-22 — `Wall-Fixer-Pipeline.ms`, `Wall-Fixer-Core.ms`, `Wall-Fixer.ms`: optimized Slice Walls anchor processing by detecting when the requested slice already exists in the live evaluated topology. Before slicing an anchor, the pipeline now verifies that the wall region crosses the requested plane, an existing on-plane edge passes through the anchor, and no face in that region still straddles the plane; when true, the anchor is skipped because a complete slice edge loop already runs through that location. This detects loops from the base mesh, preserved lower slice modifiers, and earlier tasks in the same pass. An empty newly-created slice modifier is removed when every queued task is skipped/no-change. Added `testExistingSliceLoopCoverageRule`; project version 0.968.

2026-09-22 — `Wall-Fixer-Deploy.ahk`: updated deployment helper to version 1.4. Releases now go inside the current project as `releases\\<tool-version>`, with only the version number used as the release-folder name. The source `releases` tree is excluded together with `.git` to prevent recursive/self-copy and nesting older releases; `--test` now verifies the new path and both exclusions. This utility does not change the Wall-Fixer runtime; tool version remains 0.967.

2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer.ms`: expanded POST-PROCESS `11. REMOVE REDUNDANT LOOPS` detection for straight border/T-junction chains. Straight chain traversal now accepts safe T-junction endpoints whose remaining edges continue as straight pairs, can start from those endpoints, and uses a dedicated 2.0° chain-straightness tolerance while retaining the strict 0.1° face-coplanarity test. Added `testRedundantLoopTerminalTopology`; project version 0.967.

2026-09-22 — `Wall-Fixer-Pipeline.ms`, `Wall-Fixer-Core.ms`, `Wall-Fixer.ms`: fixed stacked Slice Walls live-anchor loss. Live anchors created by a preserved opposite-direction slice modifier are now captured automatically and merged into the next directional queue when not in an explicit sub-object filter; a live intersection with two opposite collinear halves of the same direction is accepted instead of being rejected for having more than one matching edge. Live non-base tasks now re-resolve their saved anchor position as the sliced-edge cleanup chain start, protecting the anchor-connected result from cleanup. Added `testLiveAnchorCollinearDirectionRule`, `testOppositeSliceModifierNamePolicy`, and `testLiveSliceTaskPlaneDeduplication`; project version 0.966.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: removed the obsolete main EDGE FIXER `STRAIGHT EDGE FIXER` button and its UI event; compacted the EDGE FIXER group/rollout and moved the OPTIONS slot upward while keeping the underlying Straight Edge Fixer implementation available internally; updated the EDGE FIXER options layout test; project version 0.965.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: converted GET OUTER WALLS `INNER \\ OUTTER` classify control to the shared dark WinForms button style and set its text to the classifier OUTER green (RGB 60,200,80), preserving its LMB classify behavior and tooltip; project version 0.964.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: GET OUTER WALLS class-row text colors now match the classifier material IDs exactly: OUTER RGB 60/200/80, INNER 255/140/0, TOP 155/205/235, and BOTTOM 190/155/120; dark .NET button styling is preserved; project version 0.963.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: removed the obsolete SLICE WALLS Vertical/Horizontal radiobutton and persisted `SliceDirection` state. The main `9. SLICE WALLS` action now routes LMB directly to `#horizontal` and RMB directly to `#vertical`; a bold visible guide and matching tooltip show `LMB: SLICE HORIZONTAL` / `RMB: SLICE VERTICAL`. The old RMB both-modes runner was removed, while the existing `H \\ V` modifier-activation and `Select` controls remain unchanged. Fix N-gons now uses neutral `#all` direction instead of inheriting a Slice Walls UI mode. Added `testSliceWallMouseRouting`; project version 0.962.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: applied the shared dark `.NET` button template to the GET OUTER WALLS class buttons and EDGE FIXER direction buttons so their background, border, hover/down states, and bold font match the other dark WinForms controls while preserving their orange/light-blue text colors; project version 0.961.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added a distinct `FAILED` completed-status label for non-critical operation failures; safe-to-continue failures now use FAILED, prerequisites/partial outcomes remain WARNING, and hard failures remain ERROR; project version 0.960.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: numbered Slice button 9 now uses orange text while retaining the shared dark-button styling and existing LMB/RMB behavior; project version 0.959.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: GET OUTER WALLS OUTER and INNER .NET class buttons now use orange text; TOP and BOTTOM remain light blue; project version 0.958.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: PRE-PROCESS numbered button 3 (`EXPLODE OBJECTS TO WALLS`) now uses orange text while retaining the shared dark-button styling; project version 0.957.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: converted EDGE FIXER `VERTICAL \\ SKEWED` and `HORIZONTAL \\ SLOPED` direction buttons to WinForms controls with orange text while preserving LMB/RMB/CTRL+RMB behavior; project version 0.956.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: PRE-PROCESS numbered button 2 (`VERTEX CHECK / WELD`) now uses orange text while retaining the shared dark-button styling; project version 0.955.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added a persisted top-level `DEBUG` rollout containing DEBUG TRACE, PRINT DEBUG, and Print Objs; removed those controls from GET OUTER WALLS Options/HELPERS and compacted the Options layout; project version 0.954.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: converted GET OUTER WALLS OUTER/INNER/TOP/BOTTOM class-row controls to WinForms buttons and set the whole row text to light blue while preserving LMB/RMB/CTRL+RMB behavior; project version 0.953.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: SUCCESS status text is now green; WARNING and ERROR colors remain unchanged; project version 0.952.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: removed the duplicate PRE-PROCESS step 2 weld spinner and expanded `2. VERTEX CHECK / WELD` to the full row; step 2 now reads only `Options > WELD DISTANCE`, renamed the Options `Threshold` label to `WELD DISTANCE`, and added `testPreProcessWeldDistanceControl`; project version 0.951.

2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer.ms`: Slice Walls directional runs now preserve the opposite existing slice modifier; Horizontal replaces only `SLICE HORIZONTAL` and keeps `SLICE VERTICAL`, while Vertical replaces only `SLICE VERTICAL` and keeps `SLICE HORIZONTAL`. Legacy `SLICE ALL` and slicing cleanup modifiers are still cleared before a directional rebuild. RMB both-mode slicing therefore finishes with two directional slice modifiers stacked instead of deleting the first pass. Added `testSliceModifierRetentionPolicy`; project version 0.950.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: updated numbered `.NET` workflow buttons with a visible 1 px gray border (RGB 120,120,120) and light-green bold text (RGB 170,220,170); extended `testNumberedDarkButtons` to verify border and foreground styling; project version 0.949.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: fixed init-time MAXScript parser error in `testNumberedDarkButtons`; changed the invalid `.NET` chain `btn.GetType().FullName` to `(btn.GetType()).FullName` and scanned the complete UI/bundle for other unparenthesized `method().property` chains; project version 0.948.

2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer.ms`: Slice Walls success now focuses the last object that actually produced a slice and activates that object's current top modifier; this lands on the final slicing modifier when it is still topmost, or on another modifier when one is above it. Top Edit Poly modifiers still finish in Edge sub-object level 2. Added `testSliceCompletionTargetPolicy`; project version 0.947.

2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: replaced the numbered workflow action buttons (1, 2, 3, 5, 9, 10–15) with dark WinForms `.NET` buttons using the shared `setupDarkButton` template; existing positions, sizes, disabled states, tooltips, and LMB/RMB behavior are preserved; added `testNumberedDarkButtons`; project version 0.946.


2026-09-22 — `Wall-Fixer-Deploy.ahk`: added AutoHotkey 1.1.36.02 deployment helper version 1.3. Running it from the project folder creates a sibling `<folder>_<current tool version>` deployment, copies all project content except the `.git` directory, keeps `.gitignore`, and refuses to overwrite an existing deployment. Added a `--test` self-test covering version parsing, sibling naming, copied files, `.gitignore`, and `.git` exclusion. This utility does not change the Wall-Fixer runtime; tool version remains 0.945.


2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: fixed init-time rollout parser error in `testSliceProgressPercent`; removed the stray comma after the rollout function body and verified the standalone UI contains no other standalone `),` rollout/function terminators; project version 0.945.


2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: POST-PROCESS `11. REMOVE REDUNDANT LOOPS` now uses LMB to select detected redundant-loop edges and RMB to remove the current edge selection; when RMB has no selected edges it detects and removes all redundant-loop edges. Selection/removal supports top Edit Poly and Editable Poly edge sources, reuses only the dedicated `WMC - CLEANUP LOOPS` modifier for automatic cleanup, and adds `testPostProcessRedundantLoopRouting`; project version 0.944.


2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: HELPERS `Align Camera` now falls back to the dominant wall-face orientation when no faces are selected; it groups near-parallel/opposite vertical face normals, ignores horizontal caps, uses the orientation represented by the most faces, then keeps the existing orthographic User-view alignment and Zoom Extents Selected behavior; project version 0.943.


2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer.ms`: fixed init-time MAXScript compile error in `testSliceProgressCallbackArguments`; removed the nested callback closure over `captured_values` and moved the test capture state/callback to `WallFixer_v` struct scope. Added closure-pattern regression verification; project version 0.942.


# Changes


2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: fixed Slice Walls progress updates by passing the callback's object metadata as named MAXScript arguments instead of invalid extra positional arguments that were silently caught; the progress bar now advances monotonically across the full multi-object batch, and running-state UI always pumps events even when progress remains at 0 so the `READY` label is hidden immediately rather than painting over the bar; added `testSliceProgressCallbackArguments` and `testSliceProgressPercent`; project version 0.941.


2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: Vertical Vertex-mode skewed realignment now prefers a visible exact-vertical incident edge; when none exists, it uses the most vertical visible incident edge within the current Angle and aligns the selected vertex XY to that edge's opposite endpoint while preserving Z. Invisible triangulation edges are ignored, and the previous hardcoded 45° vertex fallback is removed; added `testVerticalVertexReferenceFallback`; project version 0.940.


2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: Slice Walls final success messages now include elapsed processing time; single-mode uses the Core batch duration and RMB both-mode reports the combined duration of both directional passes; project version 0.939.


2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: removed the obsolete EDGE FIXER `8. CHECK RESULT` group, moved the OPTIONS slot up, compacted collapsed/expanded rollout heights, and updated layout tests; project version 0.938.


2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: set the Wall-Fixer dialog to `lockWidth:false`; startup/restore now keeps the current default width, no longer reads or writes persisted width, and continues persisting height; project version 0.937.


2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: tightened completed-status/progress-bar visibility transitions so one side is explicitly hidden before the other is shown, preventing overlap or stale simultaneous visibility; project version 0.936.


2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: Slice Walls processing now updates the progress overlay text before repainting the progress bar, keeping the current quiet-mode processing message visible instead of letting a stale bar repaint obscure it; project version 0.935.


2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: fixed dialog position persistence drift by reapplying the saved screen position after CUI registration/floating so save and restore use the same coordinate space without cumulative offset; project version 0.934.


2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: removed EDGE FIXER `Slope Z` / SearchInZ and made horizontal row eligibility use the same Angle threshold as vertical checks; Rows distance now only clusters candidate row centers and row/reference assignment has no Z-position cutoff. Display-unit suffixes now resolve Custom display mode through `units.CustomUnit`. Also fixed Border Check LMB Editable Poly/Edit Poly selection dispatch by selecting directly from the concrete geometry source instead of a forward `setEdgeSelection` struct call that could resolve the adapter array as a Modifier. Project version 0.933.


2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: removed the EDGE FIXER `Slope Z` / SearchInZ control and active setting. Horizontal row candidates now use the same Angle threshold as vertical direction checks; Rows distance only clusters candidate edge centers into rows, and row assignment has no Z-distance cutoff. Reference fallback also uses Angle without a Z-position filter. Display-unit suffixes now resolve Custom display mode through `units.CustomUnit` instead of showing `custom`; project version 0.933.


2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: renamed Straight Edge level terminology to Rows in user-facing text; EDGE FIXER OPTIONS now uses `Rows distance` and `Slope Z`, with trailing display-unit labels and spinner widths reduced by 32 px where the unit label is appended. Min Edges shows `edges` and Angle shows `°`; removed the explicit 32 px Angle field width. Angle RMB now toggles from the spinner range minimum to maximum, otherwise back to minimum. Real 3ds Max scene-layer terminology remains unchanged; project version 0.932.


2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: swapped the EDGE FIXER direction controls, renamed them to `VERTICAL \\ SKEWED` and `HORIZONTAL \\ SLOPED`, and moved Angle from OPTIONS between the two buttons. Angle is now a compact float spinner with 0.1° steps, 32 px field width, range 0.1°–45.0°, one-decimal rounding, and RMB min/max toggle. Compacted EDGE FIXER OPTIONS and updated layout tests; project version 0.931.


2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: Vertical realign now handles Vertex sub-object mode explicitly; when `subObjectLevel == 1`, each selected vertex is moved in XY to the unselected endpoint of an incident vertical-direction edge while preserving the selected vertex Z, and the unselected endpoint is left unchanged; added `testVerticalSelectedVertexTarget`; project version 0.930.


2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer.ms`: corrected EDGE FIXER alignment-axis semantics; Horizontal alignment now changes Z only and uses a neighboring horizontal edge Z when available, while Vertical alignment changes XY only and uses a neighboring vertical edge XY when available, preserving target endpoint Z; the reference-based straighten path now follows the same coordinate-only rules instead of projecting the whole edge onto the reference direction; added `testDirectionAlignmentTargets`; project version 0.929.


2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: made the first main-menu `Restart` command a direct top-level item instead of opening a Restart submenu; the existing restart behavior is unchanged and `testWallFixerDirectRestartMenu` checks launcher readiness without reloading; project version 0.928.


2026-09-22 — `Straight-Edge-Fixer.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: reworked EDGE FIXER horizontal/vertical events. LMB selects only exact zero-deviation edges; RMB selects skewed edges with `0° < deviation <= Angle`; CTRL+RMB fixes the current edge selection. Vertical fixing aligns to world Z. Horizontal fixing derives a horizontal tangent perpendicular to the best adjacent wall-face normal, preserving rotated wall direction while leveling Z. Added rotated-wall tangent regression coverage; project version 0.927.


2026-09-22 — `Wall-Fixer-Core.ms`, `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: revised HELPERS `Split`; LMB captures the selected edges, applies Editable Poly, splits all surviving selected edges, explodes resulting elements into separate objects, cleans redundant vertices, and succeeds when at least two elements are produced; project version 0.926.


2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: PRE-PROCESS `2. VERTEX CHECK / WELD` RMB now detects Vertex sub-object mode and welds only the currently selected Editable Poly/Edit Poly vertices; outside Vertex mode it keeps the existing duplicate-vertex fix behavior; project version 0.925.


2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: HELPERS `Align Camera` now projects the selected wall normal onto XY and locks camera up to world +Z, keeping Z-rotated walls square to view without introducing camera roll; project version 0.924.


2026-09-22 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: added HELPERS `Material`; LMB assigns one shared 10-ID Multi/Sub-Object material to selected geometry and RMB removes material assignments; project version 0.923.


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

2026-09-23 — `Wall-Fixer-UI.ms`, `Wall-Fixer.ms`: fixed GET OUTER WALLS `LAYER` assignment so a current layer already ending in `-INNER`, `-OUTTER`, `-TOP`, or `-BOTTOM` resolves to the unsuffixed base layer; existing sibling class layers are reused instead of creating doubled suffix names such as `Walls-OUTTER-OUTTER`; added `testWallFaceClassLayerBaseName()`; project version 0.982.
