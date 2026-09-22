## NEXT

UI: remove button "STRAIGHT EDGE FIXER".

## IN PROGRESS

## QUEUE


## DONE TODAY

0.964 UI: INNER / OUTTER button: make the button font/text color green.

0.963 UI: OUTTER / INNER / TOP / BOTTOM row: make each button font/text color match its corresponding Wall Material ID color.

0.961 UI: .NET controls: keep the background color dark grey, matching the other .NET buttons.

0.960 UI: FAILED label: add a "FAILED" status label and use it instead of a warning when a function fails but the failure is non-critical.

0.959 UI: button 9: make the button font/text color orange.

0.958 UI: INNER / OUTTER buttons: make the .NET button font orange.

0.957 UI: button 3: make the button font/text color orange.

0.956 UI: VERTICAL / SKEWED row buttons: make the button font/text color orange.

0.955 UI: button 2: make the button font/text color orange.

0.954 UI: create new rollout "DEBUG" and move both existing Options > Debug buttons plus HELPERS > Print Objs into it.

0.953 UI: rollout 2 button row starting with "OUTTER": make the entire row font/text color light blue.

0.952 UI: SUCCESS label: display the SUCCESS status text in green.

0.939 SLICE WALLS > Completion status: final single-mode and both-mode success messages now include elapsed processing time.

0.938 UI: remove the entire pipeline step/rollout "8. CHECK RESULT".

0.937 DIALOG: set lockWidth = false and prevent registration/restore logic from changing the dialog width.

0.936 UI: status label / progress bar toggle: enforce mutually exclusive visibility so only one of the two controls can be visible at any time.

0.935 SLICE WALLS > Quiet mode formatting: update processing text before the progress-bar repaint so the current Slice message remains visible instead of being obscured by a stale redraw.

0.934 UI: dialog registration/position persistence: fixed saved-position drift so CUI registration and restore use the same coordinates with no cumulative offset.

0.926 HELPERS > SPLIT > LMB: apply Editable Poly, edit the selected edges and run Split, then explode the object by elements into separate objects.

0.925 ROLLOUT 1 > 2. WELD > RMB: when subObjectLevel 1 (vertex) is active, weld only the currently selected vertices.

0.924 HELPERS > Align Camera: align the camera to walls rotated around the Z axis while keeping the camera-view horizon horizontal; do not introduce camera roll.

0.923 HELPERS > Material button: LMB: assign a Multi/Sub-Object (multi-ID) material to the current selection. RMB: remove material from the current selection.

0.91 SLICE WALLS > H \ V button: add button to the SLICE WALLS row. LMB: activate modifier "SLICE HORIZONTAL". RMB: activate modifier "SLICE VERTICAL". CTRL+LMB: activate "SLICE HORIZONTAL" and enter sub-object level 2. CTRL+RMB: activate "SLICE VERTICAL" and enter sub-object level 2.

0.90 HELPERS > SPLIT > LMB: split the current object by the selected edge, when possible, and explode the result into 2 separate objects.

0.89 UI: add sequential index prefixes to all main pipeline rollout titles (example: "2 GET OUTER WALLS"); exclude rollouts named "Options" and "HELPERS".

0.88 UI: change rollout title from "SLICE SELECTED WALLS" to "SLICE WALLS".

## DONE

0.82 UI: show progress bar only while a process is running; hide the status label during processing. When idle, hide the progress bar and show the status label. Both controls must occupy the same UI space.

0.82 SLICE SELECTED WALLS > Status: while processing, show current object number over total processed objects, current object name, and vertex count;

0.82 PROGRESS BAR: place label behind bar which swhow x of n processed objects E.G.: "x \ n" (example: "5 \ 10").

0.81 UI: remember rolled-up/expanded state of all rollouts in the INI file and restore those states when the tool opens.

0.80 SLICE SELECTED WALLS > Success/Stats: on successful completion, show elapsed processing time, processed object count, and total processed vertex count. Append each run to a CSV log for later performance/statistics analysis.

0.79 UI: remove SLICE WALLS > CHECK RESULT

0.75 GET OUTER WALLS > Layer > LMB: after creating the new layer, assign the currently selected objects to that new layer.

0.74 HELPERS > Print Objs > LMB: clear Listener and print formatted diagnostic info for selected objects, including object name/type, layer, transform, topology counts, selected sub-objects, vertex positions, face/vertex normals, material/smoothing data, bounding box, and other geometry/debug data needed for troubleshooting.

0.73 GLOBAL GEOMETRY: after relevant mesh operations, always check for redundant vertices and remove them automatically; no redundant vertices should be left behind.

0.72 SLICE SELECTED WALLS > Progress: fix progress bar to show actual task completion percentage and task count as n/x.

0.71 SLICE SELECTED WALLS > RMB: slice selected in both modes; run the currently active radio-button mode first, then run the other mode.

0.70 UI: EDGE FIXER > Options subrollout toggles slot height in the wrong direction; fix expand/collapse slot-height behavior.

0.65 UI: move Ground Pivot button to the row above

0.64 GET OUTER WALLS > Layer: add as 3rd button after Explode. Layer LMB: create layer next to current layer named "{Current layer name}-{INNER|OUTTER|TOP|BOTTOM}"

0.54 Helpers > Attach > RMB: Attach selection, center pivot, weld all verts with 0.0 threshold, quadrify faces if tri face count of attached object <= 12 triangles

0.53 UI: use full rollout width for parent controls; resize groupbox.width = parent rollout width - 8 (4px side padding)

0.52 UI: resize subrolouts slots, set subrollout.slot.width == parent rollout width - 8

0.51 Uppercase rollout name: GET OUTER WALLS

0.38 Remove "Create Test Scene" button and the label above

0.38 Remove numeric prefix 4. from rollout name Get Outer Walls

0.38 Remove "SELECT" from buttons, move buttons to single row
