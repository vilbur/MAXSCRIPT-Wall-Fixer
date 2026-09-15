/*
WallMeshCleaner
Slices selected wall objects and propagates wall-junction cuts.
Version 0.54

Changes from 0.53:
- Moved Restart from the bottom of the main rollout to a compact top-right button.
- Reduced the main dialog height so Restart no longer adds a full bottom row.
- Kept all cleaner sub-rollout widths and tool behavior unchanged.

Changes from 0.52:
- Reduced the Face Slicer Angle spinner width from 90 px to 45 px.
- Expanded the Cut by edge radio-button area and relaxed the Horizontal offset so the full All label is visible.
- Kept the compact Face Slicer row and original dialog size unchanged.

Changes from 0.51:
- Restored the dialog and child-rollout widths to the pre-0.51 size.
- Removed the visible Cut by edge label to free horizontal space.
- Kept All / Horizontal / Vertical and Angle on one row.
- Used radiobutton offsets so the All column is visually narrower while preserving one native radio group.

Changes from 0.50:
- Kept Cut by edge as All / Horizontal / Vertical radio buttons and moved the Angle spinner onto the same row.
- Renamed the user-facing N-gon cleanup action to Fix N-gons.

Changes from 0.49:
- Restart now prefers the versioned script beside the running file, for example WallMeshCleaner_0.50.ms.
- If the versioned script does not exist, Restart falls back to WallMeshCleaner.ms.
- Restart reports an error without closing the UI if neither file exists.

Changes from 0.48:
- Replaced the Face Slicer "Cut by edge" dropdown with All / Horizontal / Vertical radio buttons.
- Preserved the existing CutMode INI values: 1 = All, 2 = Horizontal, 3 = Vertical.

Changes from 0.46:
- Fix Angles now uses all currently selected vertices, regardless of edge connectivity.
- LMB / RMB align the selected set to its lowest / highest world Z.
- CTRL + LMB / CTRL + RMB align the selected set to its lowest / highest wall-local horizontal position.

Changes from 0.42:
- Fix Angles defaults to vertical world-Z alignment.
- CTRL + LMB / CTRL + RMB switch Fix Angles to horizontal wall-plane alignment.
- Horizontal movement follows the local wall horizontal axis derived from adjacent face normals, preserving the wall plane as much as possible.
- LMB uses the lower active coordinate; RMB uses the higher active coordinate.

Changes from 0.41:
- Reformatted control tooltips into short separated instruction lines.
- Preserved uppercase mouse/modifier labels such as LMB, RMB, and CTRL + RMB.
- Shortened Vertex Cleaner success messages to clear action-oriented text.

Changes from 0.40:
- Reworked Fix Verts to process near-duplicate vertices as individual pairs.
- If a pair has no direct edge, Fix Verts attempts to create one between them.
- The connecting edge is then collapsed so the pair becomes one vertex.
- Pair detection is repeated after each collapse because topology indices can change.

Changes from 0.39:
- Reworked Fix Angles to operate on border edges whose both endpoints are selected.
- LMB Fix Angles snaps the pair to the lower world Z.
- RMB Fix Angles snaps the pair to the higher world Z.
- Only world Z is changed; X/Y remain untouched.

Changes from 0.38:
- Added Fix buttons to both Vertex Cleaner rows.
- Fix Border Angles moves detected border vertices to the nearest valid 90 or 180 degree solution while keeping neighboring border vertices fixed.
- Fix Double Verts welds only the currently detected near-coincident vertices using the Double Vert Threshold.

Changes from 0.37:
- Reworked Vertex Cleaner into one horizontal row per feature.
- Each row now uses Button | Spinner layout.
- Test Border Angles and Find Double Verts buttons now share a taller 34 px height.

Changes from 0.35:
- Added tooltips to all interactive UI controls.
- Tooltips explain geometry actions, display toggles, slicing modes, and validation thresholds.
- Selection-only diagnostics are identified as non-destructive in their tooltips.

Changes from 0.34:
- Moved Options into its own sub-rollout.
- Moved Slice controls into their own sub-rollout and renamed it to Face Slicer.
- Main UI now stacks Options, Face Slicer, Face Cleaner, and Vertex Cleaner as child rollouts.
- Existing behavior and persisted settings are unchanged.

Changes from 0.33:
- Renamed tool to WallMeshCleaner / Wall Mesh Cleaner.
- Renamed the main script file to WallMeshCleaner.ms.
- Updated the visible rollout title to "Wall Mesh Cleaner".

Changes from 0.32:
- Reorganized cleaner UI into sub-rollouts.
- Added Face Cleaner as the first cleaner sub-rollout and moved Fix N-gons into it.
- Added Vertex Cleaner as the second cleaner sub-rollout and moved border-angle / duplicate-vertex controls into it.
- Cleaner functionality and persisted settings remain unchanged.

Changes from 0.31:
- Moved border-angle vertex tools into a dedicated Vertex Cleaner section.
- Added Find Double Verts detector for near-coincident vertices on each selected supported object.
- Added independent Double Vert Threshold stored in system units; default is 1.0 system unit.
- Duplicate detection is selection-only and does not weld or modify geometry.

Changes from 0.30:
- Added a dedicated Border Angle Threshold float spinner for Test Border Angles.
- Border-angle validation no longer shares the slice-orientation Angle spinner.
- Border Angle Threshold is persisted independently in the INI file.
- Spinner uses 0.1 degree increments so decimal tolerances can be entered directly.

Changes from 0.29:
- Added Test Border Angles button.
- Detects every open-border loop, including inner opening borders and the outer wall border.
- A border vertex is valid when its two border edges form approximately 90/270 degrees or 180 degrees using the shared Angle tolerance.
- Vertices whose border angle is neither orthogonal nor straight are selected for inspection.
- Border vertices with an invalid border degree other than two are also selected as problematic.

Changes from 0.28:
- In Slice Selected Walls, Cut by edge = All now runs as two ordered passes.
- The complete Vertical pass runs first on all selected supported objects.
- The complete Horizontal pass runs second.
- Clean slice-edge flags from the Vertical pass are preserved through the Horizontal pass so the second pass treats the established vertical cuts as preferred topology.
- Horizontal-only and Vertical-only modes keep their previous behavior.

Changes from 0.27:
- Prefer protected new slice edges first, existing orthogonal edges second, and old angled internal edges last.
- Detect removable angled internal edges whose two coplanar faces merge into one four-corner orthogonal region.
- Dissolve those angled dirty edges before the older generic redundant-divider cleanup.
- Straight middle vertices exposed by the dissolve are removed by the existing straight-vertex cleanup.
- This fixes the triangle + polygon + N-gon junction case where removing the diagonal divider and its straight middle vertex produces two clean orthogonal polygons.

Changes from 0.26:
- Classify post-slice topology by the actual slice plane instead of treating every newly indexed edge as clean.
- Keep true slice-plane edges clean; split fragments created from old hidden edges stay dirty.
- Before each cut, remember previously clean edge segments so later cuts cannot dirty an earlier clean slice when that edge is split.
- After each cut, prefer clean slice edges over dirty hidden edges at their intersections.
- Dissolve eligible dirty hidden edges touching a clean cut before generic redundant-loop cleanup.
- Allow straight two-edge vertices on a clean cut to dissolve, then transfer the clean flag to the merged replacement edge.
- Added regression notes for cuts crossing hidden triangulation edges.

Changes from 0.25:
- New slice edges take priority; cleanup dissolves eligible old dividers instead.
- Accumulate clean-edge flags across all cuts in the operation.
- Recheck old seams after restoring original material IDs.
- Preserve clean cut intersections during vertex cleanup.

Changes from 0.24:
- Recognize straight vertices with exactly two actual edges regardless of visibility flags.
- Continue checking other vertices when one dissolve fails.
- Sweep vertices after the complete cut sequence as well as after each successful cut.

Changes from 0.23:
- Fix catch rethrow syntax: use a bare throw inside catch.
- After every cut dissolve straight vertices with exactly two visible edges,
  even when additional hidden edges meet there; preserve corners and folds.

Changes from 0.22:
- Check new edges immediately after each main or junction cut.
- Dissolve only a single shared divider between two clean coplanar quads
  whose combined outline is also a single four-sided region.
- Re-read flagged candidates after every dissolve; preserve material and SG boundaries.

Changes from 0.21:
- Share boundary slice planes across each connected coplanar wall island.
- Ignore internal polygon seams when collecting source edges.
- Preserve requested slice edges instead of dissolving rectangular subdivisions.

Changes from 0.05:
- Removed dependency on a manually chosen smoothing-group number.
- Wall identity is detected automatically from the smoothing group of the face
  containing a junction vertex.
- Only the connected face island with that smoothing group is processed.
  Disconnected walls may reuse the same smoothing group safely.
- Added optional vertex welding before the main slice operation.
- Weld threshold defaults to 1.0 system unit.
- Added INI persistence for:
  - Weld Vertices checkbox
  - Weld Threshold
  - Display Hidden Edges
  - Double Side
  - Auto Smooth
  - Rollout/dialog position
- Added "Display Hidden Edges" checkbutton.
  Checked = node.allEdges ON.
- Added "Double Side" checkbutton.
  Checked = object backface culling OFF.
- Added "Auto Smooth" checkbutton to Wall Junction Post-process.
  When enabled, polyop.autoSmooth is applied before junction detection/slicing.
- Fixed Editable Poly weld call:
  polyop.weldVertsByThreshold takes only <poly> and <vertlist>.
  Weld distance is supplied through Editable_Poly.weldThreshold.
- Fixed INI dialog-position loader.
  readIniIntFromSection() was referenced before that struct method existed,
  which resolved to undefined in MaxScript. The helper is now declared first.
- "Auto Smooth" checkbutton moved above "Fix N-gons".
- When Auto Smooth is checked, Auto Smooth is forced before N-gon cutting.
- Auto Smooth is applied with all faces temporarily selected, then the previous
  face selection is restored.
- The selected node list is reused directly so Auto Smooth definitely runs on
  the same objects that are about to be cut.
- Added cleanup after "Fix N-gons":
  1. Weld all possible border vertices with weldThreshold = 0.0.
  2. Find vertices connected to exactly two straight edges.
  3. Remove those redundant vertices with EditablePoly.Remove.
  4. Reapply Auto Smooth when the Auto Smooth checkbutton is enabled.
- Fixed MaxScript struct function-order issue:
  cleanupAfterNgonCut() now appears after autoSmoothNode(), so the call resolves
  correctly instead of evaluating autoSmoothNode as undefined.
- Moved Weld Vertices + Threshold controls into a shared "Options" section.
- Fix N-gons now uses the same Weld Vertices checkbox and Weld Threshold.
- Auto Smooth is now a checkbox instead of a checkbutton.
- Added "Smooth" button next to Auto Smooth for manual Auto Smooth.
- When Auto Smooth is checked, Auto Smooth runs before Fix N-gons and is
  reapplied after cleanup.
*/

try
(
    destroyDialog WallMeshCleanerRollout
)
catch
(
)

global WallMeshCleaner_v
global WallMeshCleaner
global WallMeshCleanerRollout
global WallMeshCleanerOptionsRollout
global WallMeshCleanerFaceSlicerRollout
global WallMeshCleanerFaceCleanerRollout
global WallMeshCleanerVertexCleanerRollout
global WallMeshCleanerScriptPath

WallMeshCleanerScriptPath = getSourceFileName()

struct WallMeshCleaner_v
(
    version = "0.54",
    temp_id_start = 60000,
    epsilon = 0.001,
    collinear_dot_limit = 0.9999,
    axis_angle_threshold = 5.0,
    ini_path = ((getDir #userScripts) + "\\WallMeshCleaner.ini"),

    /*
    Returns true when node can be processed directly by PolyOp.
    The current baseline processes nodes whose base object is Editable Poly.
    */
    function isSupportedNode node =
    (
        if node == undefined then
        (
            false
        )
        else
        (
            base_obj = node.baseObject
            ((classOf base_obj) == Editable_Poly)
        )
        -- return
    ),

    /*
    Returns the preferred script path for Restart.
    The matching versioned file is preferred; WallMeshCleaner.ms is the fallback.
    */
    function getRestartScriptPath source_script_path =
    (
        script_dir = getFilenamePath source_script_path
        versioned_script_path = script_dir + "WallMeshCleaner_" + version + ".ms"
        unversioned_script_path = script_dir + "WallMeshCleaner.ms"

        if doesFileExist versioned_script_path then
        (
            versioned_script_path
        )
        else if doesFileExist unversioned_script_path then
        (
            unversioned_script_path
        )
        else
        (
            undefined
        )
        -- return
    ),

    /*
    Builds a safe normalized vector or returns undefined for a degenerate vector.
    This prevents zero-length vectors from producing invalid slice planes.
    */
    function safeNormalize vector_value =
    (
        vector_length = length vector_value

        if vector_length <= epsilon then
        (
            undefined
        )
        else
        (
            vector_value / vector_length
        )
        -- return
    ),

    /*
    Returns true when a WORLD-space edge matches the requested cut orientation.
    All ignores the threshold; Horizontal means near the world XY plane; Vertical means near world Z.
    */
    function edgeMatchesOrientation edge_dir_world cut_mode angle_threshold =
    (
        edge_dir_normal = safeNormalize edge_dir_world

        if edge_dir_normal == undefined then
        (
            false
        )
        else if cut_mode == #all then
        (
            true
        )
        else
        (
            z_alignment = abs (dot edge_dir_normal [0,0,1])

            if cut_mode == #vertical then
            (
                z_alignment >= (cos angle_threshold)
            )
            else if cut_mode == #horizontal then
            (
                z_alignment <= (sin angle_threshold)
            )
            else
            (
                true
            )
        )
        -- return
    ),

    /*
    Converts a local edge represented by two points into a normalized world-space direction.
    Orientation filtering must use world axes even when the object itself is rotated.
    */
    function getWorldEdgeDirection node point_a_local point_b_local =
    (
        point_a_world = point_a_local * node.objectTransform
        point_b_world = point_b_local * node.objectTransform
        safeNormalize (point_b_world - point_a_world)
        -- return
    ),

    /*
    Reads a Boolean value from the tool INI file.
    Missing values fall back to the supplied default.
    */
    function readIniBool key_name default_value =
    (
        default_text = if default_value then "1" else "0"
        value_text = getIniSetting ini_path "Settings" key_name

        if value_text == "" then
        (
            default_value
        )
        else
        (
            value_text == "1"
        )
        -- return
    ),

    /*
    Reads a Float value from the tool INI file.
    Missing or invalid values fall back to the supplied default.
    */
    function readIniFloat key_name default_value =
    (
        value_text = getIniSetting ini_path "Settings" key_name

        if value_text == "" then
        (
            default_value
        )
        else
        (
            parsed_value = undefined

            try
            (
                parsed_value = value_text as float
            )
            catch
            (
                parsed_value = undefined
            )

            if parsed_value == undefined then default_value else parsed_value
        )
        -- return
    ),

    /*
    Reads an Integer value from the tool INI file.
    Missing or invalid values fall back to the supplied default.
    */
    function readIniInt key_name default_value =
    (
        value_text = getIniSetting ini_path "Settings" key_name

        if value_text == "" then
        (
            default_value
        )
        else
        (
            parsed_value = undefined

            try
            (
                parsed_value = value_text as integer
            )
            catch
            (
                parsed_value = undefined
            )

            if parsed_value == undefined then default_value else parsed_value
        )
        -- return
    ),

    /*
    Saves current UI settings to the tool INI file.
    Dialog position is saved when supplied.
    */
    function saveSettings weld_enabled weld_threshold display_hidden_edges double_side auto_smooth cut_mode_index angle_threshold border_angle_threshold:5.0 double_vert_threshold:1.0 dialog_position:undefined =
    (
        setIniSetting ini_path "Settings" "WeldVertices" (if weld_enabled then "1" else "0")
        setIniSetting ini_path "Settings" "WeldThreshold" (weld_threshold as string)
        setIniSetting ini_path "Settings" "DisplayHiddenEdges" (if display_hidden_edges then "1" else "0")
        setIniSetting ini_path "Settings" "DoubleSide" (if double_side then "1" else "0")
        setIniSetting ini_path "Settings" "AutoSmooth" (if auto_smooth then "1" else "0")
        setIniSetting ini_path "Settings" "CutMode" (cut_mode_index as string)
        setIniSetting ini_path "Settings" "AngleThreshold" (angle_threshold as string)
        setIniSetting ini_path "Settings" "BorderAngleThreshold" (border_angle_threshold as string)
        setIniSetting ini_path "Settings" "DoubleVertThreshold" (double_vert_threshold as string)

        if dialog_position != undefined then
        (
            setIniSetting ini_path "Window" "X" ((dialog_position.x as integer) as string)
            setIniSetting ini_path "Window" "Y" ((dialog_position.y as integer) as string)
        )

        true
        -- return
    ),

    /*
    Reads an Integer from a specified INI section.
    This helper is declared before loadDialogPosition so MaxScript resolves it correctly.
    */
    function readIniIntFromSection section_name key_name default_value =
    (
        value_text = getIniSetting ini_path section_name key_name

        if value_text == "" then
        (
            default_value
        )
        else
        (
            parsed_value = undefined

            try
            (
                parsed_value = value_text as integer
            )
            catch
            (
                parsed_value = undefined
            )

            if parsed_value == undefined then default_value else parsed_value
        )
        -- return
    ),

    /*
    Loads the saved rollout/dialog position from the INI file.
    Undefined is returned when no position has been saved yet.
    */
    function loadDialogPosition =
    (
        x_text = getIniSetting ini_path "Window" "X"
        y_text = getIniSetting ini_path "Window" "Y"

        if (x_text == "") or (y_text == "") then
        (
            undefined
        )
        else
        (
            x_value = readIniIntFromSection "Window" "X" 100
            y_value = readIniIntFromSection "Window" "Y" 100
            [x_value, y_value]
        )
        -- return
    ),

    /*
    Welds all vertices of one selected Editable Poly using the requested threshold.
    This follows the verified working Editable Poly weld method directly on the node.
    */
    function weldNodeVertices node weld_threshold =
    (
        if not (isSupportedNode node) then
        (
            false
        )
        else
        (
            previous_weld_threshold = node.weldThreshold
            node.weldThreshold = weld_threshold

            vert_count = polyop.getNumVerts node
            all_verts = #{1..vert_count}

            weld_result = false

            try
            (
                weld_result = polyop.weldVertsByThreshold node all_verts
            )
            catch
            (
                weld_result = false
                format "WallMeshCleaner Weld: weldVertsByThreshold failed on %\n" node.name
            )

            node.weldThreshold = previous_weld_threshold
            completeRedraw()

            format "WallMeshCleaner Weld: % | threshold: % | result: %\n" \
                node.name weld_threshold weld_result

            true
        )
        -- return
    ),

    /*
    Welds all vertices on all currently selected supported wall objects.
    Objects outside the current selection are never processed.
    */
    function weldSelection weld_threshold =
    (
        selected_nodes = selection as array

        for node in selected_nodes do
        (
            weldNodeVertices node weld_threshold
        )

        true
        -- return
    ),

    /*
    Returns the vertex on the opposite side of an edge from the supplied vertex.
    Undefined is returned when the supplied vertex is not part of the edge.
    */
    function getOtherEdgeVertex base_obj edge_index vert_index =
    (
        edge_verts = polyop.getVertsUsingEdge base_obj edge_index
        edge_vert_array = edge_verts as array
        other_vert = undefined

        if edge_vert_array.count == 2 then
        (
            if edge_vert_array[1] == vert_index then
            (
                other_vert = edge_vert_array[2]
            )
            else if edge_vert_array[2] == vert_index then
            (
                other_vert = edge_vert_array[1]
            )
        )

        other_vert
        -- return
    ),

    /*
    Returns true when a vertex has exactly two connected edges forming a straight line.
    Directions are measured away from the vertex, so straight edges have dot product near -1.
    */
    function isTwoEdgeStraightVertex base_obj vert_index =
    (
        used_edges = polyop.getEdgesUsingVert base_obj vert_index

        if used_edges.numberSet != 2 then
        (
            false
        )
        else
        (
            edge_indices = used_edges as array
            other_vert_a = getOtherEdgeVertex base_obj edge_indices[1] vert_index
            other_vert_b = getOtherEdgeVertex base_obj edge_indices[2] vert_index

            if (other_vert_a == undefined) or (other_vert_b == undefined) then
            (
                false
            )
            else
            (
                center_point = polyop.getVert base_obj vert_index
                point_a = polyop.getVert base_obj other_vert_a
                point_b = polyop.getVert base_obj other_vert_b

                dir_a = safeNormalize (point_a - center_point)
                dir_b = safeNormalize (point_b - center_point)

                if (dir_a == undefined) or (dir_b == undefined) then
                (
                    false
                )
                else
                (
                    (dot dir_a dir_b) <= (-collinear_dot_limit)
                )
            )
        )
        -- return
    ),

    /*
    Finds all vertices that have exactly two connected straight edges.
    The resulting bitarray can be passed to EditablePoly.Remove.
    */
    function getTwoEdgeStraightVerts node =
    (
        base_obj = node.baseObject
        vert_count = polyop.getNumVerts base_obj
        straight_verts = #{}

        for vert_index = 1 to vert_count do
        (
            if isTwoEdgeStraightVertex base_obj vert_index then
            (
                straight_verts[vert_index] = true
            )
        )

        straight_verts
        -- return
    ),

    /*
    Removes redundant two-edge straight vertices without deleting their surrounding faces.
    EditablePoly.Remove is used instead of polyop.deleteVerts so polygons are preserved.
    */
    function removeTwoEdgeStraightVerts node =
    (
        if not (isSupportedNode node) then
        (
            0
        )
        else
        (
            base_obj = node.baseObject
            straight_verts = getTwoEdgeStraightVerts node
            remove_count = straight_verts.numberSet

            if remove_count > 0 then
            (
                flag_bit = bit.set 0 30 true
                polyop.setVertFlags base_obj straight_verts flag_bit mask:flag_bit undoable:true
                remove_ok = base_obj.EditablePoly.Remove selLevel:#Vertex flag:flag_bit

                if remove_ok != true then
                (
                    format "WallMeshCleaner Cleanup: Remove failed on %\n" node.name
                )
            )

            update node

            format "WallMeshCleaner Cleanup: % | straight 2-edge verts removed: %\n" \
                node.name remove_count

            remove_count
        )
        -- return
    ),

    /*
    Returns true when two faces are coplanar within the tool tolerance.
    Both parallel and opposite normal directions are accepted.
    */
    function areFacesCoplanar base_obj face_a face_b =
    (
        normal_a = safeNormalize (polyop.getFaceNormal base_obj face_a)
        normal_b = safeNormalize (polyop.getFaceNormal base_obj face_b)

        if (normal_a == undefined) or (normal_b == undefined) then
        (
            false
        )
        else if (abs (dot normal_a normal_b)) < collinear_dot_limit then
        (
            false
        )
        else
        (
            verts_a = polyop.getFaceVerts base_obj face_a
            verts_b = polyop.getFaceVerts base_obj face_b

            if (verts_a.count < 1) or (verts_b.count < 1) then
            (
                false
            )
            else
            (
                point_a = polyop.getVert base_obj verts_a[1]
                point_b = polyop.getVert base_obj verts_b[1]
                plane_distance = abs (dot (point_b - point_a) normal_a)

                plane_distance <= epsilon
            )
        )
        -- return
    ),

    /*
    Adds an integer to an array only when it is not already present.
    This helper is used while building merged face boundaries.
    */
    function appendUniqueInteger value_array value =
    (
        if (findItem value_array value) == 0 then
        (
            append value_array value
        )

        value_array
        -- return
    ),

    /*
    Returns boundary edges of two faces after conceptually dissolving their shared edge.
    Edges used by both faces are omitted; all remaining edges form the merged outline.
    */
    function getMergedBoundaryEdges base_obj face_a face_b =
    (
        edges_a = (polyop.getEdgesUsingFace base_obj face_a) as array
        edges_b = (polyop.getEdgesUsingFace base_obj face_b) as array
        boundary_edges = #()

        for edge_index in edges_a do
        (
            if (findItem edges_b edge_index) == 0 then
            (
                appendUniqueInteger boundary_edges edge_index
            )
        )

        for edge_index in edges_b do
        (
            if (findItem edges_a edge_index) == 0 then
            (
                appendUniqueInteger boundary_edges edge_index
            )
        )

        boundary_edges
        -- return
    ),

    /*
    Returns the boundary-neighbor vertices connected to one vertex by supplied boundary edges.
    A clean polygon boundary should produce exactly two neighbors per boundary vertex.
    */
    function getBoundaryVertexNeighbors base_obj boundary_edges vert_index =
    (
        neighbor_verts = #()

        for edge_index in boundary_edges do
        (
            edge_verts = (polyop.getVertsUsingEdge base_obj edge_index) as array

            if edge_verts.count == 2 then
            (
                if edge_verts[1] == vert_index then
                (
                    appendUniqueInteger neighbor_verts edge_verts[2]
                )
                else if edge_verts[2] == vert_index then
                (
                    appendUniqueInteger neighbor_verts edge_verts[1]
                )
            )
        )

        neighbor_verts
        -- return
    ),

    /*
    Returns true when an edge is horizontal or vertical in world space within the cleanup threshold.
    Horizontal accepts any XY direction, so walls may be freely rotated around world Z.
    */
    function isOrthogonalWallEdge node edge_index angle_threshold:axis_angle_threshold =
    (
        base_obj = node.baseObject
        edge_verts = (polyop.getVertsUsingEdge base_obj edge_index) as array
        is_orthogonal = false

        if edge_verts.count == 2 then
        (
            point_a = polyop.getVert base_obj edge_verts[1]
            point_b = polyop.getVert base_obj edge_verts[2]
            edge_dir_world = getWorldEdgeDirection node point_a point_b

            if edge_dir_world != undefined then
            (
                is_orthogonal = ((edgeMatchesOrientation edge_dir_world #horizontal angle_threshold) or (edgeMatchesOrientation edge_dir_world #vertical angle_threshold))
            )
        )

        is_orthogonal
        -- return
    ),

    /*
    Counts non-collinear corners on the merged outline of two adjacent faces.
    Straight intermediate vertices are ignored, matching the desired clean-quad test.
    */
    function countMergedBoundaryCorners base_obj face_a face_b =
    (
        boundary_edges = getMergedBoundaryEdges base_obj face_a face_b
        boundary_verts = #()
        valid_boundary = true
        corner_count = 0

        for edge_index in boundary_edges do
        (
            edge_verts = (polyop.getVertsUsingEdge base_obj edge_index) as array

            if edge_verts.count == 2 then
            (
                appendUniqueInteger boundary_verts edge_verts[1]
                appendUniqueInteger boundary_verts edge_verts[2]
            )
        )

        for vert_index in boundary_verts while valid_boundary do
        (
            neighbor_verts = getBoundaryVertexNeighbors base_obj boundary_edges vert_index

            if neighbor_verts.count != 2 then
            (
                valid_boundary = false
            )
            else
            (
                center_point = polyop.getVert base_obj vert_index
                point_a = polyop.getVert base_obj neighbor_verts[1]
                point_b = polyop.getVert base_obj neighbor_verts[2]

                dir_a = safeNormalize (point_a - center_point)
                dir_b = safeNormalize (point_b - center_point)

                if (dir_a == undefined) or (dir_b == undefined) then
                (
                    valid_boundary = false
                )
                else if (dot dir_a dir_b) > (-collinear_dot_limit) then
                (
                    corner_count += 1
                )
            )
        )

        if valid_boundary then corner_count else 0
        -- return
    ),

    /*
    Returns true when every surviving edge of a conceptual two-face merge is horizontal or vertical.
    The shared divider itself is excluded because it is the edge being considered for removal.
    */
    function isMergedBoundaryOrthogonal node face_a face_b angle_threshold:axis_angle_threshold =
    (
        base_obj = node.baseObject
        boundary_edges = getMergedBoundaryEdges base_obj face_a face_b
        is_orthogonal = boundary_edges.count >= 4

        for edge_index in boundary_edges while is_orthogonal do
        (
            if not (isOrthogonalWallEdge node edge_index angle_threshold:angle_threshold) then
            (
                is_orthogonal = false
            )
        )

        is_orthogonal
        -- return
    ),

    /*
    Returns true when an old angled internal edge only splits one clean four-corner orthogonal region.
    Coplanarity, material ID and smoothing group are preserved before preferring the orthogonal boundary.
    */
    function isRedundantAngledOldEdge node edge_index angle_threshold:axis_angle_threshold =
    (
        base_obj = node.baseObject
        used_faces = (polyop.getFacesUsingEdge base_obj edge_index) as array
        removable_edge = false

        if used_faces.count == 2 then
        (
            face_a = used_faces[1]
            face_b = used_faces[2]
            same_material = (polyop.getFaceMatID base_obj face_a) == (polyop.getFaceMatID base_obj face_b)
            same_smoothing = (polyop.getFaceSmoothGroup base_obj face_a) == (polyop.getFaceSmoothGroup base_obj face_b)

            if same_material and same_smoothing and (areFacesCoplanar base_obj face_a face_b) then
            (
                shared_edges = (polyop.getEdgesUsingFace base_obj face_a) * (polyop.getEdgesUsingFace base_obj face_b)

                if (shared_edges.numberSet == 1) and (not (isOrthogonalWallEdge node edge_index angle_threshold:angle_threshold)) then
                (
                    removable_edge = (((countMergedBoundaryCorners base_obj face_a face_b) == 4) and (isMergedBoundaryOrthogonal node face_a face_b angle_threshold:angle_threshold))
                )
            )
        )

        removable_edge
        -- return
    ),

    /* Tests whether a face has four convex corners, ignoring straight intermediate vertices.
    This excludes triangles, concave regions and degenerate boundary turns.
    */
    function isCleanQuadFace base_obj face_index =
    (
        local face_verts = polyop.getFaceVerts base_obj face_index
        local corner_count = 0
        local turn_sign = 0
        local clean_face = face_verts.count >= 4
        local face_normal = safeNormalize (polyop.getFaceNormal base_obj face_index)
        if face_normal == undefined then clean_face = false
        for position_index = 1 to face_verts.count while clean_face do
        (
            local previous_index = if position_index == 1 then face_verts.count else position_index - 1
            local next_index = if position_index == face_verts.count then 1 else position_index + 1
            local center_point = polyop.getVert base_obj face_verts[position_index]
            local incoming_dir = safeNormalize (center_point - polyop.getVert base_obj face_verts[previous_index])
            local outgoing_dir = safeNormalize ((polyop.getVert base_obj face_verts[next_index]) - center_point)
            if (incoming_dir == undefined) or (outgoing_dir == undefined) then
            (
                clean_face = false
            )
            else if (dot incoming_dir outgoing_dir) < collinear_dot_limit then
            (
                local turn_value = dot (cross incoming_dir outgoing_dir) face_normal
                local current_sign = if turn_value > 0 then 1 else -1
                if (abs turn_value) < 0.000001 then clean_face = false
                if (turn_sign != 0) and (turn_sign != current_sign) then clean_face = false
                turn_sign = current_sign
                corner_count += 1
            )
        )
        clean_face and (corner_count == 4)
    ),

    /*
    Returns true when an old edge only divides one clean flat four-sided region.
    Material ID and smoothing group must also match so semantic boundaries are preserved.
    */
    function isRedundantOldEdge node edge_index =
    (
        base_obj = node.baseObject
        used_faces = (polyop.getFacesUsingEdge base_obj edge_index) as array

        if used_faces.count != 2 then
        (
            false
        )
        else
        (
            face_a = used_faces[1]
            face_b = used_faces[2]

            same_material = (polyop.getFaceMatID base_obj face_a) == (polyop.getFaceMatID base_obj face_b)
            same_smoothing = (polyop.getFaceSmoothGroup base_obj face_a) == (polyop.getFaceSmoothGroup base_obj face_b)

            if not same_material then
            (
                false
            )
            else if not same_smoothing then
            (
                false
            )
            else if not (areFacesCoplanar base_obj face_a face_b) then
            (
                false
            )
            else
            (
                local shared_edges = (polyop.getEdgesUsingFace base_obj face_a) * (polyop.getEdgesUsingFace base_obj face_b)
                (shared_edges.numberSet == 1) and
                    (isCleanQuadFace base_obj face_a) and
                    (isCleanQuadFace base_obj face_b) and
                    ((countMergedBoundaryCorners base_obj face_a face_b) == 4)
            )
        )
        -- return
    ),

    /* Marks pre-slice edges so topology created by the next slice can be identified.
    User edge flags survive index changes better than relying on numeric edge IDs alone.
    */
    function markExistingSliceEdges node =
    (
        base_obj = node.baseObject
        existing_flag = bit.set 0 27 true
        polyop.setEdgeFlags base_obj (polyop.getEdgesByFlag base_obj 0) existing_flag mask:existing_flag undoable:true
        existing_flag
        -- return
    ),

    /* Stores geometric segments for edges carrying the requested flag.
    The snapshot lets a later slice preserve earlier clean cuts even when an edge is split.
    */
    function collectFlaggedEdgeSegments base_obj edge_flag =
    (
        edge_segments = #()
        flagged_edges = polyop.getEdgesByFlag base_obj edge_flag

        for edge_index in flagged_edges do
        (
            edge_verts = (polyop.getVertsUsingEdge base_obj edge_index) as array

            if edge_verts.count == 2 then
            (
                append edge_segments #(
                    polyop.getVert base_obj edge_verts[1],
                    polyop.getVert base_obj edge_verts[2]
                )
            )
        )

        edge_segments
        -- return
    ),

    /* Tests whether a point lies on a stored straight edge segment within tolerance.
    Projection is used so large world-coordinate values do not depend on angle-only tests.
    */
    function pointLiesOnSegment point_value segment_start segment_end tolerance_value =
    (
        segment_vector = segment_end - segment_start
        segment_length_sq = dot segment_vector segment_vector
        lies_on_segment = false

        if segment_length_sq <= (tolerance_value * tolerance_value) then
        (
            lies_on_segment = (distance point_value segment_start) <= tolerance_value
        )
        else
        (
            projection = (dot (point_value - segment_start) segment_vector) / segment_length_sq

            if (projection >= -0.0001) and (projection <= 1.0001) then
            (
                closest_point = segment_start + (segment_vector * projection)
                lies_on_segment = (distance point_value closest_point) <= tolerance_value
            )
        )

        lies_on_segment
        -- return
    ),

    /* Tests whether both endpoints of an edge lie on one previously stored edge segment.
    This transfers clean status to child segments when a later slice splits an earlier clean cut.
    */
    function edgeLiesOnStoredSegments base_obj edge_index edge_segments tolerance_value =
    (
        edge_verts = (polyop.getVertsUsingEdge base_obj edge_index) as array
        lies_on_stored_segment = false

        if edge_verts.count == 2 then
        (
            point_a = polyop.getVert base_obj edge_verts[1]
            point_b = polyop.getVert base_obj edge_verts[2]

            for edge_segment in edge_segments while not lies_on_stored_segment do
            (
                if (pointLiesOnSegment point_a edge_segment[1] edge_segment[2] tolerance_value) and \
                   (pointLiesOnSegment point_b edge_segment[1] edge_segment[2] tolerance_value) then
                (
                    lies_on_stored_segment = true
                )
            )
        )

        lies_on_stored_segment
        -- return
    ),

    /* Tests whether an edge lies on the actual slice plane.
    Only these topology edges are considered new clean cut edges for the current slice.
    */
    function edgeLiesOnSlicePlane base_obj edge_index slice_ray tolerance_value =
    (
        edge_verts = (polyop.getVertsUsingEdge base_obj edge_index) as array
        plane_normal = safeNormalize slice_ray.dir
        lies_on_plane = false

        if (edge_verts.count == 2) and (plane_normal != undefined) then
        (
            point_a = polyop.getVert base_obj edge_verts[1]
            point_b = polyop.getVert base_obj edge_verts[2]
            distance_a = abs (dot (point_a - slice_ray.pos) plane_normal)
            distance_b = abs (dot (point_b - slice_ray.pos) plane_normal)
            lies_on_plane = (distance_a <= tolerance_value) and (distance_b <= tolerance_value)
        )

        lies_on_plane
        -- return
    ),

    /* Counts clean slice edges incident to a vertex.
    Two or more clean incident edges identify an intersection that belongs to the intended cut line.
    */
    function getCleanEdgeCountUsingVert base_obj vert_index =
    (
        clean_flag = bit.set 0 25 true
        incident_edges = polyop.getEdgesUsingVert base_obj vert_index
        clean_edges = polyop.getEdgesByFlag base_obj clean_flag
        (incident_edges * clean_edges).numberSet
        -- return
    ),

    /* Tests whether an edge shares either endpoint with an edge in the supplied set.
    It is used to extend a newly created cut across old collinear edge segments on the same slice plane.
    */
    function edgeTouchesEdgeSet base_obj edge_index edge_set =
    (
        edge_verts = (polyop.getVertsUsingEdge base_obj edge_index) as array
        touches_edge_set = false

        for vert_index in edge_verts while not touches_edge_set do
        (
            if ((polyop.getEdgesUsingVert base_obj vert_index) * edge_set).numberSet > 0 then
            (
                touches_edge_set = true
            )
        )

        touches_edge_set
        -- return
    ),

    /* Tests whether a dirty hidden edge may be dissolved in favor of a clean slice edge.
    The edge must be internal, coplanar, same material/SG, and touch a vertex carrying the clean cut through it.
    */
    function isDirtyHiddenEdgeAtCleanCut node edge_index =
    (
        base_obj = node.baseObject
        clean_flag = bit.set 0 25 true
        edge_flags = polyop.getEdgeFlags base_obj edge_index
        is_clean = (bit.and edge_flags clean_flag) != 0
        removable_edge = false

        if (not is_clean) and (not (polyop.getEdgeVis base_obj edge_index)) then
        (
            used_faces = (polyop.getFacesUsingEdge base_obj edge_index) as array

            if used_faces.count == 2 then
            (
                face_a = used_faces[1]
                face_b = used_faces[2]
                same_material = (polyop.getFaceMatID base_obj face_a) == (polyop.getFaceMatID base_obj face_b)
                same_smoothing = (polyop.getFaceSmoothGroup base_obj face_a) == (polyop.getFaceSmoothGroup base_obj face_b)

                if same_material and same_smoothing and (areFacesCoplanar base_obj face_a face_b) then
                (
                    edge_verts = (polyop.getVertsUsingEdge base_obj edge_index) as array

                    for vert_index in edge_verts while not removable_edge do
                    (
                        if (getCleanEdgeCountUsingVert base_obj vert_index) >= 2 then
                        (
                            removable_edge = true
                        )
                    )
                )
            )
        )

        removable_edge
        -- return
    ),

    /* Dissolves dirty hidden topology that crosses or terminates on the new clean cut.
    Failed edges are skipped until another successful topology change makes a retry meaningful.
    */
    function cleanupDirtyHiddenEdgesAtCleanCuts node =
    (
        base_obj = node.baseObject
        clean_flag = bit.set 0 25 true
        remove_flag = bit.set 0 31 true
        skipped_flag = bit.set 0 32 true
        removed_count = 0
        keep_checking = true

        polyop.setEdgeFlags base_obj #{} 0 mask:skipped_flag undoable:true

        while keep_checking do
        (
            dirty_edges = (polyop.getEdgesByFlag base_obj 0 mask:clean_flag) - (polyop.getEdgesByFlag base_obj skipped_flag)
            dirty_edge = 0

            for edge_index in dirty_edges while dirty_edge == 0 do
            (
                if isDirtyHiddenEdgeAtCleanCut node edge_index then
                (
                    dirty_edge = edge_index
                )
            )

            if dirty_edge == 0 then
            (
                keep_checking = false
            )
            else
            (
                polyop.setEdgeFlags base_obj #{dirty_edge} remove_flag mask:remove_flag undoable:true

                if (base_obj.EditablePoly.Remove selLevel:#Edge flag:remove_flag) == true then
                (
                    removed_count += 1
                    polyop.setEdgeFlags base_obj #{} 0 mask:skipped_flag undoable:true
                    update node
                )
                else
                (
                    blocked_edges = (polyop.getEdgesByFlag base_obj skipped_flag) + #{dirty_edge}
                    polyop.setEdgeFlags base_obj blocked_edges skipped_flag mask:skipped_flag undoable:true
                )
            )
        )

        polyop.setEdgeFlags base_obj #{} 0 mask:(bit.or remove_flag skipped_flag) undoable:true

        if removed_count > 0 then
        (
            format "WallMeshCleaner Cleanup: % | dirty hidden edges removed at clean cuts: %\n" node.name removed_count
        )

        removed_count
        -- return
    ),

    /* Protects true slice-plane edges and dissolves eligible dirty dividers one at a time.
    Clean flags persist across cuts; final cleanup can run after material restoration.
    */
    function cleanupNewSliceEdges node existing_flag collect_new:true slice_ray:undefined previous_clean_segments:#() =
    (
        base_obj = node.baseObject
        candidate_flag = bit.set 0 28 true
        clean_flag = bit.set 0 25 true
        remove_flag = bit.set 0 29 true
        total_removed = 0
        cleanup_error = undefined
        plane_tolerance = epsilon * 10.0

        if slice_ray != undefined then
        (
            precision_tolerance = (length slice_ray.pos) / 10000000.0

            if precision_tolerance > plane_tolerance then
            (
                plane_tolerance = precision_tolerance
            )
        )

        try
        (
            if collect_new then
            (
                new_edges = polyop.getEdgesByFlag base_obj 0 mask:existing_flag
                live_edges = polyop.getEdgesByFlag base_obj 0
                clean_edges = polyop.getEdgesByFlag base_obj clean_flag
                current_slice_edges = #{}

                for edge_index in new_edges do
                (
                    is_clean_edge = false

                    if slice_ray != undefined then
                    (
                        is_clean_edge = edgeLiesOnSlicePlane base_obj edge_index slice_ray plane_tolerance
                    )
                    else
                    (
                        is_clean_edge = true
                    )

                    if is_clean_edge then
                    (
                        clean_edges[edge_index] = true
                        current_slice_edges[edge_index] = true
                    )
                )

                if (slice_ray != undefined) and (current_slice_edges.numberSet > 0) then
                (
                    keep_promoting = true

                    while keep_promoting do
                    (
                        keep_promoting = false

                        for edge_index in live_edges do
                        (
                            if not clean_edges[edge_index] then
                            (
                                if (edgeLiesOnSlicePlane base_obj edge_index slice_ray plane_tolerance) and \
                                   (edgeTouchesEdgeSet base_obj edge_index clean_edges) then
                                (
                                    clean_edges[edge_index] = true
                                    current_slice_edges[edge_index] = true
                                    keep_promoting = true
                                )
                            )
                        )
                    )
                )

                if previous_clean_segments.count > 0 then
                (
                    for edge_index in live_edges do
                    (
                        if not clean_edges[edge_index] then
                        (
                            if edgeLiesOnStoredSegments base_obj edge_index previous_clean_segments plane_tolerance then
                            (
                                clean_edges[edge_index] = true
                            )
                        )
                    )
                )

                polyop.setEdgeFlags base_obj clean_edges clean_flag mask:clean_flag undoable:true
            )

            cleanupDirtyHiddenEdgesAtCleanCuts node
            old_edges = polyop.getEdgesByFlag base_obj 0 mask:clean_flag
            polyop.setEdgeFlags base_obj old_edges candidate_flag mask:candidate_flag undoable:true
            keep_checking = true

            while keep_checking do
            (
                candidates = (polyop.getEdgesByFlag base_obj candidate_flag) - (polyop.getEdgesByFlag base_obj clean_flag)
                redundant_edge = 0

                /* Prefer dirty angled dividers before orthogonal redundant loops. */
                for edge_index in candidates while redundant_edge == 0 do
                (
                    if isRedundantAngledOldEdge node edge_index then
                    (
                        redundant_edge = edge_index
                    )
                )

                if redundant_edge == 0 then
                (
                    for edge_index in candidates while redundant_edge == 0 do
                    (
                        if isRedundantOldEdge node edge_index then
                        (
                            redundant_edge = edge_index
                        )
                    )
                )

                if redundant_edge == 0 then
                (
                    keep_checking = false
                )
                else
                (
                    polyop.setEdgeFlags base_obj #{redundant_edge} remove_flag mask:remove_flag undoable:true

                    if (base_obj.EditablePoly.Remove selLevel:#Edge flag:remove_flag) == true then
                    (
                        total_removed += 1
                    )
                    else
                    (
                        keep_checking = false
                        format "WallMeshCleaner Cleanup: edge dissolve failed on %\n" node.name
                    )
                )
            )
        )
        catch
        (
            cleanup_error = getCurrentException()
        )

        clear_edge_mask = bit.or existing_flag (bit.or candidate_flag remove_flag)
        polyop.setEdgeFlags base_obj #{} 0 mask:clear_edge_mask undoable:true

        if cleanup_error != undefined then throw cleanup_error

        if total_removed > 0 then
        (
            format "WallMeshCleaner Cleanup: % | redundant dirty dividers removed: %\n" node.name total_removed
        )

        total_removed
        -- return
    ),

    /* Identifies a redundant straight vertex using visible polygon edges only.
    Valence-two vertices simplify when both edges share clean/dirty status; mixed clean-dirty pairs are preserved.
    */
    function isTwoVisibleEdgeStraightVertex base_obj vert_index =
    (
        visible_edges = #()
        incident_edges = polyop.getEdgesUsingVert base_obj vert_index
        removable = false

        if incident_edges.numberSet == 2 then
        (
            clean_edges = polyop.getEdgesByFlag base_obj (bit.set 0 25 true)
            clean_edge_count = (incident_edges * clean_edges).numberSet

            if clean_edge_count != 1 then
            (
                removable = isTwoEdgeStraightVertex base_obj vert_index
            )
        )
        else
        (
            for edge_index in incident_edges do
            (
                if polyop.getEdgeVis base_obj edge_index then
                (
                    append visible_edges edge_index
                )
            )

            clean_edges = polyop.getEdgesByFlag base_obj (bit.set 0 25 true)

            if (incident_edges * clean_edges).numberSet == 0 then
            (
                if visible_edges.count == 2 then
                (
                    other_a = getOtherEdgeVertex base_obj visible_edges[1] vert_index
                    other_b = getOtherEdgeVertex base_obj visible_edges[2] vert_index

                    if (other_a != undefined) and (other_b != undefined) then
                    (
                        center_point = polyop.getVert base_obj vert_index
                        direction_a = safeNormalize ((polyop.getVert base_obj other_a) - center_point)
                        direction_b = safeNormalize ((polyop.getVert base_obj other_b) - center_point)

                        if (direction_a != undefined) and (direction_b != undefined) then
                        (
                            removable = (dot direction_a direction_b) <= (-collinear_dot_limit)
                        )
                    )
                )

                if removable then
                (
                    incident_faces = (polyop.getFacesUsingVert base_obj vert_index) as array

                    if incident_faces.count == 0 then
                    (
                        removable = false
                    )

                    for face_position = 2 to incident_faces.count while removable do
                    (
                        removable = areFacesCoplanar base_obj incident_faces[1] incident_faces[face_position]
                    )
                )
            )
        )

        removable
        -- return
    ),

    /* Finds a live edge directly connecting two vertices.
    The helper is used after dissolving a straight vertex to locate the merged replacement edge.
    */
    function findEdgeBetweenVerts base_obj vert_a vert_b =
    (
        shared_edges = (polyop.getEdgesUsingVert base_obj vert_a) * (polyop.getEdgesUsingVert base_obj vert_b)
        shared_edge_array = shared_edges as array
        edge_index = 0

        if shared_edge_array.count > 0 then
        (
            edge_index = shared_edge_array[1]
        )

        edge_index
        -- return
    ),

    /* Dissolves one straight candidate and transfers clean status to its merged edge.
    This lets 2-edge vertices created by slicing across hidden topology disappear without losing the cut line.
    */
    function removeStraightVertexPreserveClean node vert_index remove_flag =
    (
        base_obj = node.baseObject
        clean_flag = bit.set 0 25 true
        endpoint_a_flag = bit.set 0 31 true
        endpoint_b_flag = bit.set 0 32 true
        incident_edges = polyop.getEdgesUsingVert base_obj vert_index
        preserve_clean = false
        can_track_merge = false
        remove_ok = false

        if incident_edges.numberSet == 2 then
        (
            clean_edges = polyop.getEdgesByFlag base_obj clean_flag
            preserve_clean = ((incident_edges * clean_edges).numberSet == 2)
            incident_edge_array = incident_edges as array
            other_vert_a = getOtherEdgeVertex base_obj incident_edge_array[1] vert_index
            other_vert_b = getOtherEdgeVertex base_obj incident_edge_array[2] vert_index

            if (other_vert_a != undefined) and (other_vert_b != undefined) then
            (
                can_track_merge = true
                polyop.setVertFlags base_obj #{other_vert_a} endpoint_a_flag mask:endpoint_a_flag undoable:true
                polyop.setVertFlags base_obj #{other_vert_b} endpoint_b_flag mask:endpoint_b_flag undoable:true
            )
        )

        polyop.setVertFlags base_obj #{vert_index} remove_flag mask:remove_flag undoable:true
        remove_ok = base_obj.EditablePoly.Remove selLevel:#Vertex flag:remove_flag

        if (remove_ok == true) and preserve_clean and can_track_merge then
        (
            endpoint_a_verts = polyop.getVertsByFlag base_obj endpoint_a_flag
            endpoint_b_verts = polyop.getVertsByFlag base_obj endpoint_b_flag

            if (endpoint_a_verts.numberSet == 1) and (endpoint_b_verts.numberSet == 1) then
            (
                endpoint_a = (endpoint_a_verts as array)[1]
                endpoint_b = (endpoint_b_verts as array)[1]
                merged_edge = findEdgeBetweenVerts base_obj endpoint_a endpoint_b

                if merged_edge > 0 then
                (
                    polyop.setEdgeFlags base_obj #{merged_edge} clean_flag undoable:true
                )
            )
        )

        polyop.setVertFlags base_obj #{} 0 mask:(bit.or endpoint_a_flag endpoint_b_flag) undoable:true
        remove_ok
        -- return
    ),

    /* Dissolves straight two-visible-edge vertices after each cut without deleting faces.
    Clean valence-two cuts are simplified too, with clean status transferred to the replacement edge.
    */
    function removeTwoVisibleEdgeStraightVerts node =
    (
        base_obj = node.baseObject
        remove_flag = bit.set 0 30 true
        removed_count = 0
        skipped_flag = bit.set 0 26 true
        continue_cleanup = true
        polyop.setVertFlags base_obj #{} 0 mask:skipped_flag undoable:true

        try
        (
            while continue_cleanup do
            (
                live_verts = polyop.getVertsByFlag base_obj 0
                candidate_vert = 0
                skipped_verts = polyop.getVertsByFlag base_obj skipped_flag

                for vert_index in (live_verts - skipped_verts) while candidate_vert == 0 do
                (
                    if isTwoVisibleEdgeStraightVertex base_obj vert_index then
                    (
                        candidate_vert = vert_index
                    )
                )

                if candidate_vert == 0 then
                (
                    continue_cleanup = false
                )
                else
                (
                    previous_live_count = live_verts.numberSet
                    remove_ok = removeStraightVertexPreserveClean node candidate_vert remove_flag
                    current_live_count = (polyop.getVertsByFlag base_obj 0).numberSet

                    if (remove_ok == true) and (current_live_count < previous_live_count) then
                    (
                        removed_count += previous_live_count - current_live_count
                        polyop.setVertFlags base_obj #{} 0 mask:skipped_flag undoable:true
                    )
                    else
                    (
                        blocked_vert = polyop.getVertsByFlag base_obj remove_flag
                        skipped_verts = (polyop.getVertsByFlag base_obj skipped_flag) + blocked_vert
                        polyop.setVertFlags base_obj skipped_verts skipped_flag mask:skipped_flag undoable:true
                        format "WallMeshCleaner Cleanup: skipped a blocked vertex on %\n" node.name
                    )
                )
            )
        )
        catch
        (
            polyop.setVertFlags base_obj #{} 0 mask:(bit.or remove_flag skipped_flag) undoable:true
            throw
        )

        polyop.setVertFlags base_obj #{} 0 mask:(bit.or remove_flag skipped_flag) undoable:true

        if removed_count > 0 then
        (
            format "WallMeshCleaner Cleanup: % | straight vertices removed: %\n" node.name removed_count
        )

        removed_count
        -- return
    ),

    /* Slices once and cleans new dividers, clearing the tracking flag on failure.
    All plane and topology operations use the Editable Poly base object's local space.
    */
    function sliceWithCleanup node target_faces slice_ray =
    (
        base_obj = node.baseObject
        clean_flag = bit.set 0 25 true
        previous_clean_segments = collectFlaggedEdgeSegments base_obj clean_flag
        existing_flag = markExistingSliceEdges node
        slice_ok = false

        try
        (
            slice_ok = polyop.slice base_obj target_faces slice_ray

            if slice_ok == true then
            (
                cleanupNewSliceEdges node existing_flag slice_ray:slice_ray previous_clean_segments:previous_clean_segments
                removeTwoVisibleEdgeStraightVerts node
                update node
            )
            else
            (
                polyop.setEdgeFlags base_obj #{} 0 mask:existing_flag undoable:true
            )
        )
        catch
        (
            polyop.setEdgeFlags base_obj #{} 0 mask:existing_flag undoable:true
            throw
        )

        slice_ok
        -- return
    ),

    /*
    Removes redundant flat divider edges from the whole object during post-process cleanup.
    Each edge is validated locally, allowing a redundant loop to continue around corners between different wall SGs.
    */
    function cleanupRedundantPostProcessEdges node =
    (
        if not (isSupportedNode node) then
        (
            0
        )
        else
        (
            base_obj = node.baseObject
            total_removed_edges = 0
            continue_cleanup = true

            while continue_cleanup do
            (
                continue_cleanup = false
                edge_count = polyop.getNumEdges base_obj
                redundant_edge = 0

                for edge_index = 1 to edge_count while redundant_edge == 0 do
                (
                    if isRedundantOldEdge node edge_index then
                    (
                        redundant_edge = edge_index
                    )
                )

                if redundant_edge > 0 then
                (
                    edge_verts = (polyop.getVertsUsingEdge base_obj redundant_edge) as array
                    edge_set = #{}
                    edge_set[redundant_edge] = true

                    edge_flag_bit = bit.set 0 29 true
                    all_edges = #{1..edge_count}
                    polyop.setEdgeFlags base_obj all_edges 0 mask:edge_flag_bit undoable:true
                    polyop.setEdgeFlags base_obj edge_set edge_flag_bit mask:edge_flag_bit undoable:true

                    remove_edge_ok = base_obj.EditablePoly.Remove selLevel:#Edge flag:edge_flag_bit

                    if remove_edge_ok == true then
                    (
                        total_removed_edges += 1
                        update node

                        current_vert_count = polyop.getNumVerts base_obj
                        removable_verts = #{}

                        for vert_index in edge_verts do
                        (
                            if vert_index <= current_vert_count then
                            (
                                if isTwoEdgeStraightVertex base_obj vert_index then
                                (
                                    removable_verts[vert_index] = true
                                )
                            )
                        )

                        if removable_verts.numberSet > 0 then
                        (
                            vert_flag_bit = bit.set 0 30 true
                            all_verts = #{1..current_vert_count}
                            polyop.setVertFlags base_obj all_verts 0 mask:vert_flag_bit undoable:true
                            polyop.setVertFlags base_obj removable_verts vert_flag_bit mask:vert_flag_bit undoable:true
                            base_obj.EditablePoly.Remove selLevel:#Vertex flag:vert_flag_bit
                            update node
                        )

                        continue_cleanup = true
                    )
                    else
                    (
                        format "WallMeshCleaner Post Cleanup: edge Remove failed on % | edge: %\n" \
                            node.name redundant_edge
                    )
                )
            )

            format "WallMeshCleaner Post Cleanup: % | redundant edges removed: %\n" \
                node.name total_removed_edges

            total_removed_edges
        )
        -- return
    ),

    /*
    Applies viewport edge-display state to all selected nodes.
    Checked Display Hidden Edges corresponds to the node allEdges property.
    */
    function setSelectionDisplayHiddenEdges enabled =
    (
        selected_nodes = selection as array

        for node in selected_nodes do
        (
            if isValidNode node then
            (
                node.allEdges = enabled
            )
        )

        redrawViews()
        true
        -- return
    ),

    /*
    Applies double-sided viewport display to all selected nodes.
    Checked Double Side means backface culling is disabled on the object.
    */
    function setSelectionDoubleSide enabled =
    (
        selected_nodes = selection as array

        for node in selected_nodes do
        (
            if isValidNode node then
            (
                node.backFaceCull = not enabled
            )
        )

        redrawViews()
        true
        -- return
    ),

    /*
    Applies Editable Poly Auto Smooth to all faces of the whole object.
    All faces are temporarily selected, Auto Smooth is run, then face selection is restored.
    */
    function autoSmoothNode node =
    (
        if not (isSupportedNode node) then
        (
            false
        )
        else
        (
            base_obj = node.baseObject
            face_count = polyop.getNumFaces base_obj
            previous_face_selection = polyop.getFaceSelection base_obj
            all_faces = #{}

            for face_index = 1 to face_count do
            (
                all_faces[face_index] = true
            )

            polyop.setFaceSelection base_obj all_faces
            polyop.autoSmooth base_obj
            polyop.setFaceSelection base_obj previous_face_selection

            update node

            format "WallMeshCleaner Auto Smooth: % | faces: % | threshold: %\n" \
                node.name face_count base_obj.autoSmoothThreshold

            true
        )
        -- return
    ),

    /*
    Applies Auto Smooth to all selected supported wall objects.
    Objects outside the current selection are never modified.
    */
    function autoSmoothSelection =
    (
        selected_nodes = selection as array

        for node in selected_nodes do
        (
            autoSmoothNode node
        )

        true
        -- return
    ),

    /*
    Runs the post-cut cleanup pipeline on one wall object.
    Welding is followed by redundant-loop cleanup, straight-vertex cleanup, then optional Auto Smooth.
    */
    function cleanupAfterNgonCut node weld_vertices:false weld_threshold:1.0 reapply_auto_smooth:false =
    (
        if not (isSupportedNode node) then
        (
            false
        )
        else
        (
            if weld_vertices then
            (
                weldNodeVertices node weld_threshold
            )

            -- Requested orthogonal dividers must survive post-process cleanup.
            removeTwoEdgeStraightVerts node

            if reapply_auto_smooth then
            (
                autoSmoothNode node
            )

            true
        )
        -- return
    ),

    /*
    Collects object-local slicing planes from all boundary edges of one original face.
    Slice data is stored before topology changes so later edge-index changes do not matter.
    */
    function collectFaceSliceData node face_index cut_mode:#all angle_threshold:5.0 island_faces:#{} =
    (
        base_obj = node.baseObject
        face_normal_local = safeNormalize (polyop.getFaceNormal base_obj face_index)

        if face_normal_local == undefined then
        (
            #()
        )
        else
        (
            face_edges = polyop.getEdgesUsingFace base_obj face_index
            slice_data = #()

            for edge_index in face_edges do
            (
                edge_verts = polyop.getVertsUsingEdge base_obj edge_index
                vert_indices = edge_verts as array

                if (vert_indices.count == 2) and (((polyop.getFacesUsingEdge base_obj edge_index) * island_faces).numberSet <= 1) then
                (
                    point_a = polyop.getVert base_obj vert_indices[1]
                    point_b = polyop.getVert base_obj vert_indices[2]

                    edge_dir_local = safeNormalize (point_b - point_a)
                    edge_dir_world = getWorldEdgeDirection node point_a point_b

                    if (edge_dir_local != undefined) and (edge_dir_world != undefined) then
                    (
                        if edgeMatchesOrientation edge_dir_world cut_mode angle_threshold then
                        (
                            plane_normal_local = safeNormalize (cross edge_dir_local face_normal_local)

                            if plane_normal_local != undefined then
                            (
                                plane_center_local = (point_a + point_b) * 0.5
                                append slice_data #(plane_center_local, plane_normal_local)
                            )
                        )
                    )
                )
            )

            slice_data
        )
        -- return
    ),

    /* Finds one connected coplanar wall before any topology changes.
    Compare against the seed plane to avoid drifting around curved walls.
    */
    function getConnectedPlanarIsland base_obj seed_face =
    (
        local island_faces = #{}
        local face_queue = #(seed_face)
        local queue_position = 1
        island_faces[seed_face] = true

        while queue_position <= face_queue.count do
        (
            local current_face = face_queue[queue_position]
            queue_position += 1
            local face_edges = polyop.getEdgesUsingFace base_obj current_face

            for edge_index in face_edges do
            (
                local neighbor_faces = polyop.getFacesUsingEdge base_obj edge_index
                for neighbor_face in neighbor_faces do
                (
                    if not island_faces[neighbor_face] then
                    (
                        if areFacesCoplanar base_obj seed_face neighbor_face then
                        (
                            island_faces[neighbor_face] = true
                            append face_queue neighbor_face
                        )
                    )
                )
            )
        )
        island_faces
    ),

    /* Collects unique boundary planes for every original face in a flat wall.
    Disconnected walls and walls around corners receive independent plane lists.
    */
    function collectWallSliceData node cut_mode:#all angle_threshold:5.0 =
    (
        local base_obj = node.baseObject
        local face_count = polyop.getNumFaces base_obj
        local face_slice_data = #()
        local visited_faces = #{}
        face_slice_data.count = face_count

        for seed_face = 1 to face_count do
        (
            if not visited_faces[seed_face] then
            (
                local island_faces = getConnectedPlanarIsland base_obj seed_face
                visited_faces = visited_faces + island_faces
                local island_planes = #()

                for face_index in island_faces do
                (
                    local source_planes = collectFaceSliceData node face_index cut_mode:cut_mode angle_threshold:angle_threshold island_faces:island_faces
                    for source_plane in source_planes do
                    (
                        local duplicate_plane = false
                        for stored_plane in island_planes while not duplicate_plane do
                        (
                            if (abs (dot source_plane[2] stored_plane[2])) >= 0.999999 then
                            (
                                if (abs (dot (source_plane[1] - stored_plane[1]) stored_plane[2])) <= epsilon then
                                (
                                    duplicate_plane = true
                                )
                            )
                        )
                        if not duplicate_plane then
                        (
                            append island_planes source_plane
                        )
                    )
                )
                for face_index in island_faces do
                (
                    face_slice_data[face_index] = island_planes
                )
            )
        )
        face_slice_data
    ),

    /*
    Finds all faces currently carrying the requested temporary material ID.
    These faces are treated as descendants of one original source polygon.
    */
    function getFacesByMaterialId node material_id =
    (
        base_obj = node.baseObject
        face_count = polyop.getNumFaces base_obj
        result_faces = #{}

        for face_index = 1 to face_count do
        (
            if (polyop.getFaceMatID base_obj face_index) == material_id then
            (
                result_faces[face_index] = true
            )
        )

        result_faces
        -- return
    ),

    /*
    Slices descendants of one original polygon using stored object-local slice planes.
    polyop.slice receives the plane as a Ray.
    */
    function sliceTrackedFace node material_id slice_data =
    (
        base_obj = node.baseObject
        slice_count = 0

        for slice_item in slice_data do
        (
            tracked_faces = getFacesByMaterialId node material_id

            if tracked_faces.numberSet > 0 then
            (
                plane_center_local = slice_item[1]
                plane_normal_local = slice_item[2]
                slice_ray = ray plane_center_local plane_normal_local
                slice_ok = sliceWithCleanup node tracked_faces slice_ray

                if slice_ok == true then
                (
                    slice_count += 1
                )
            )
        )

        slice_count
        -- return
    ),

    /*
    Processes one Editable Poly node and restores original material IDs afterward.
    Original face data is captured before any slicing changes the topology.
    */
    function processNode node cut_mode:#all angle_threshold:5.0 reset_clean_edges:true clear_clean_edges:true =
    (
        if not (isSupportedNode node) then
        (
            format "WallMeshCleaner: skipped unsupported node: %\n" node.name
            false
        )
        else
        (
            base_obj = node.baseObject
            original_face_count = polyop.getNumFaces base_obj

            if original_face_count < 1 then
            (
                false
            )
            else if (temp_id_start + original_face_count) > 65535 then
            (
                messageBox ("WallMeshCleaner: Too many polygons on object \"" + node.name + "\" for temporary material IDs.")
                false
            )
            else
            (
                if reset_clean_edges then
                (
                    polyop.setEdgeFlags base_obj #{} 0 mask:(bit.set 0 25 true) undoable:true
                )

                face_records = #()
                local wall_slice_data = collectWallSliceData node cut_mode:cut_mode angle_threshold:angle_threshold

                for face_index = 1 to original_face_count do
                (
                    original_mat_id = polyop.getFaceMatID base_obj face_index
                    temp_mat_id = temp_id_start + face_index
                    slice_data = wall_slice_data[face_index]

                    append face_records #(temp_mat_id, original_mat_id, slice_data)
                    polyop.setFaceMatID base_obj #{face_index} temp_mat_id
                )

                total_slices = 0

                for face_record in face_records do
                (
                    total_slices += sliceTrackedFace node face_record[1] face_record[3]
                )

                for face_record in face_records do
                (
                    tracked_faces = getFacesByMaterialId node face_record[1]

                    if tracked_faces.numberSet > 0 then
                    (
                        polyop.setFaceMatID base_obj tracked_faces face_record[2]
                    )
                )

                cleanupNewSliceEdges node (bit.set 0 27 true) collect_new:false
                removeTwoVisibleEdgeStraightVerts node

                if clear_clean_edges then
                (
                    polyop.setEdgeFlags base_obj #{} 0 mask:(bit.set 0 25 true) undoable:true
                )

                update node

                format "WallMeshCleaner: % | original faces: % | slice operations: %\n" \
                    node.name original_face_count total_slices

                true
            )
        )
        -- return
    ),

    /*
    Runs the original edge-based slicer on all currently selected supported objects.
    Optional vertex welding is performed immediately before slicing.
    */
    function sliceSelection weld_vertices:false weld_threshold:1.0 cut_mode:#all angle_threshold:5.0 =
    (
        selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            messageBox "WallMeshCleaner: Select at least one wall object."
            false
        )
        else
        (
            processed_count = 0

            undo "WallMeshCleaner" on
            (
                if weld_vertices then
                (
                    weldSelection weld_threshold
                )

                if cut_mode == #all then
                (
                    vertical_results = #()

                    format "WallMeshCleaner: All pass 1/2 | Vertical\n"

                    for node in selected_nodes do
                    (
                        vertical_result = processNode node \
                            cut_mode:#vertical \
                            angle_threshold:angle_threshold \
                            reset_clean_edges:true \
                            clear_clean_edges:false

                        append vertical_results vertical_result
                    )

                    format "WallMeshCleaner: All pass 2/2 | Horizontal\n"

                    for node_index = 1 to selected_nodes.count do
                    (
                        node = selected_nodes[node_index]
                        vertical_result = vertical_results[node_index]

                        horizontal_result = processNode node \
                            cut_mode:#horizontal \
                            angle_threshold:angle_threshold \
                            reset_clean_edges:(not vertical_result) \
                            clear_clean_edges:true

                        if vertical_result or horizontal_result then
                        (
                            processed_count += 1
                        )
                    )
                )
                else
                (
                    for node in selected_nodes do
                    (
                        if processNode node cut_mode:cut_mode angle_threshold:angle_threshold then
                        (
                            processed_count += 1
                        )
                    )
                )
            )

            format "WallMeshCleaner: processed % of % selected object(s).\n" \
                processed_count selected_nodes.count

            completeRedraw()
            processed_count > 0
        )
        -- return
    ),

    /*
    Returns true when three ordered boundary points form an almost straight line.
    This detects an extra vertex inserted into a formerly single straight edge.
    */
    function isStraightBoundaryVertex point_prev point_current point_next =
    (
        dir_a = safeNormalize (point_current - point_prev)
        dir_b = safeNormalize (point_next - point_current)

        if (dir_a == undefined) or (dir_b == undefined) then
        (
            false
        )
        else
        (
            (dot dir_a dir_b) >= collinear_dot_limit
        )
        -- return
    ),

    /*
    Returns the exact smoothing-group mask stored on one face.
    A zero mask is allowed but is not useful as an automatic wall identifier.
    */
    function getFaceSmoothMask base_obj face_index =
    (
        polyop.getFaceSmoothGroup base_obj face_index
        -- return
    ),

    /*
    Returns true when a vertex is shared by the source wall face and a face with a different SG mask.
    This identifies a real wall junction rather than an arbitrary collinear vertex.
    */
    function isWallJunctionVertex node vert_index source_smooth_mask =
    (
        base_obj = node.baseObject
        used_faces = polyop.getFacesUsingVert base_obj vert_index

        has_source_face = false
        has_other_face = false

        for face_index in used_faces do
        (
            face_smooth_mask = getFaceSmoothMask base_obj face_index

            if face_smooth_mask == source_smooth_mask then
            (
                has_source_face = true
            )
            else
            (
                has_other_face = true
            )
        )

        (has_source_face and has_other_face)
        -- return
    ),

    /*
    Returns the faces connected to a seed face through shared edges with the same SG mask.
    This isolates one physical wall even when disconnected walls reuse the same smoothing group.
    */
    function getConnectedSmoothIsland node seed_face smooth_mask =
    (
        base_obj = node.baseObject
        face_count = polyop.getNumFaces base_obj
        visited_faces = #{}
        island_faces = #{}
        face_queue = #()

        if (seed_face < 1) or (seed_face > face_count) then
        (
            island_faces
        )
        else if (getFaceSmoothMask base_obj seed_face) != smooth_mask then
        (
            island_faces
        )
        else
        (
            append face_queue seed_face
            visited_faces[seed_face] = true

            while face_queue.count > 0 do
            (
                current_face = face_queue[1]
                deleteItem face_queue 1
                island_faces[current_face] = true

                face_edges = polyop.getEdgesUsingFace base_obj current_face

                for edge_index in face_edges do
                (
                    neighbor_faces = polyop.getFacesUsingEdge base_obj edge_index

                    for neighbor_face in neighbor_faces do
                    (
                        if not visited_faces[neighbor_face] then
                        (
                            visited_faces[neighbor_face] = true

                            if (getFaceSmoothMask base_obj neighbor_face) == smooth_mask then
                            (
                                append face_queue neighbor_face
                            )
                        )
                    )
                )
            )

            island_faces
        )
        -- return
    ),

    /*
    Finds a current seed face for a stored junction point and smoothing-group mask.
    This allows the connected wall island to be rebuilt after earlier slice operations.
    */
    function findSeedFaceAtPoint node point_local smooth_mask =
    (
        base_obj = node.baseObject
        face_count = polyop.getNumFaces base_obj
        found_face = 0

        for face_index = 1 to face_count while found_face == 0 do
        (
            if (getFaceSmoothMask base_obj face_index) == smooth_mask then
            (
                face_verts = polyop.getFaceVerts base_obj face_index

                for vert_index in face_verts while found_face == 0 do
                (
                    vert_pos = polyop.getVert base_obj vert_index

                    if (distance vert_pos point_local) <= epsilon then
                    (
                        found_face = face_index
                    )
                )
            )
        )

        found_face
        -- return
    ),

    /*
    Collects automatic junction cuts from all wall faces in the object.
    Each record stores the wall SG mask, a junction point, and a slice-plane normal.
    */
    function collectAutomaticJunctionCuts node cut_mode:#all angle_threshold:5.0 =
    (
        base_obj = node.baseObject
        face_count = polyop.getNumFaces base_obj
        cut_records = #()

        for face_index = 1 to face_count do
        (
            smooth_mask = getFaceSmoothMask base_obj face_index

            if smooth_mask != 0 then
            (
                face_verts = polyop.getFaceVerts base_obj face_index
                vert_count = face_verts.count

                if vert_count > 3 then
                (
                    for face_vert_position = 1 to vert_count do
                    (
                        prev_position = face_vert_position - 1
                        next_position = face_vert_position + 1

                        if prev_position < 1 then
                        (
                            prev_position = vert_count
                        )

                        if next_position > vert_count then
                        (
                            next_position = 1
                        )

                        prev_vert = face_verts[prev_position]
                        current_vert = face_verts[face_vert_position]
                        next_vert = face_verts[next_position]

                        point_prev = polyop.getVert base_obj prev_vert
                        point_current = polyop.getVert base_obj current_vert
                        point_next = polyop.getVert base_obj next_vert

                        if isStraightBoundaryVertex point_prev point_current point_next then
                        (
                            if isWallJunctionVertex node current_vert smooth_mask then
                            (
                                straight_dir_local = safeNormalize (point_next - point_prev)
                                straight_dir_world = getWorldEdgeDirection node point_prev point_next

                                if (straight_dir_local != undefined) and (straight_dir_world != undefined) then
                                (
                                    if edgeMatchesOrientation straight_dir_world cut_mode angle_threshold then
                                    (
                                        append cut_records #(smooth_mask, point_current, straight_dir_local, current_vert, face_index)
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )

        cut_records
        -- return
    ),

    /*
    Propagates all automatically detected junction cuts through their connected wall islands.
    No smoothing-group number is specified by the user.
    */
    function propagateAutomaticJunctionCuts node cut_mode:#all angle_threshold:5.0 =
    (
        if not (isSupportedNode node) then
        (
            format "WallMeshCleaner Junctions: skipped unsupported node: %\n" node.name
            0
        )
        else
        (
            base_obj = node.baseObject
            polyop.setEdgeFlags base_obj #{} 0 mask:(bit.set 0 25 true) undoable:true
            cut_records = collectAutomaticJunctionCuts node cut_mode:cut_mode angle_threshold:angle_threshold
            slice_count = 0

            format "WallMeshCleaner Junctions: % | candidates: %\n" node.name cut_records.count

            for cut_record in cut_records do
            (
                smooth_mask = cut_record[1]
                plane_center = cut_record[2]
                plane_normal = cut_record[3]
                source_vert = cut_record[4]

                seed_face = findSeedFaceAtPoint node plane_center smooth_mask

                if seed_face > 0 then
                (
                    island_faces = getConnectedSmoothIsland node seed_face smooth_mask

                    if island_faces.numberSet > 0 then
                    (
                        slice_ray = ray plane_center plane_normal
                        slice_ok = sliceWithCleanup node island_faces slice_ray

                        if slice_ok == true then
                        (
                            slice_count += 1

                            format "  junction vertex: % | SG mask: % | island faces: %\n" \
                                source_vert smooth_mask island_faces.numberSet
                        )
                    )
                )
            )

            cleanupNewSliceEdges node (bit.set 0 27 true) collect_new:false
            removeTwoVisibleEdgeStraightVerts node
            polyop.setEdgeFlags base_obj #{} 0 mask:(bit.set 0 25 true) undoable:true
            update node

            format "WallMeshCleaner Junctions: % | propagated slices: %\n" \
                node.name slice_count

            slice_count
        )
        -- return
    ),

    /*
    Runs automatic wall-junction propagation and cleanup on all selected supported objects.
    Shared Options control welding; Auto Smooth runs before cutting and again after cleanup.
    */
    function propagateSelectionJunctionCuts weld_vertices:false weld_threshold:1.0 auto_smooth:false cut_mode:#all angle_threshold:5.0 =
    (
        selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            messageBox "WallMeshCleaner: Select at least one wall object."
            false
        )
        else
        (
            total_slices = 0

            undo "WallMeshCleaner - Fix N-gons" on
            (
                if auto_smooth then
                (
                    format "WallMeshCleaner: Auto Smooth before Fix N-gons...\n"

                    for node in selected_nodes do
                    (
                        autoSmoothNode node
                    )
                )

                for node in selected_nodes do
                (
                    total_slices += propagateAutomaticJunctionCuts node cut_mode:cut_mode angle_threshold:angle_threshold
                )

                format "WallMeshCleaner: Post Fix N-gons cleanup...\n"

                for node in selected_nodes do
                (
                    cleanupAfterNgonCut node                         weld_vertices:weld_vertices                         weld_threshold:weld_threshold                         reapply_auto_smooth:auto_smooth
                )
            )

            format "WallMeshCleaner Junctions: total propagated slices: %\n" total_slices
            completeRedraw()
            true
        )
        -- return
    ),

    /*
    Returns all open border edges of the Editable Poly surface.
    Outer wall borders and inner opening borders are both included.
    */
    function getOpenBorderEdges node =
    (
        if not (isSupportedNode node) then
        (
            #{}
        )
        else
        (
            polyop.getOpenEdges node.baseObject
        )
        -- return
    ),

    /*
    Returns neighboring border vertices connected to one vertex by open border edges.
    A clean closed border loop should provide exactly two neighbors for each border vertex.
    */
    function getOpenBorderNeighborVerts base_obj border_edges vert_index =
    (
        connected_edges = (polyop.getEdgesUsingVert base_obj vert_index) * border_edges
        neighbor_verts = #()

        for edge_index in connected_edges do
        (
            edge_verts = (polyop.getVertsUsingEdge base_obj edge_index) as array

            if edge_verts.count == 2 then
            (
                if edge_verts[1] == vert_index then
                (
                    appendUniqueInteger neighbor_verts edge_verts[2]
                )
                else if edge_verts[2] == vert_index then
                (
                    appendUniqueInteger neighbor_verts edge_verts[1]
                )
            )
        )

        neighbor_verts
        -- return
    ),

    /*
    Tests whether one border vertex is orthogonal or straight within the supplied angle tolerance.
    Unsigned edge angle treats both 90-degree and 270-degree corners as the same orthogonal 90-degree condition.
    */
    function isValidBorderAngle node vert_index border_edges angle_threshold:axis_angle_threshold =
    (
        base_obj = node.baseObject
        neighbor_verts = getOpenBorderNeighborVerts base_obj border_edges vert_index
        valid_angle = false

        if neighbor_verts.count == 2 then
        (
            center_world = (polyop.getVert base_obj vert_index) * node.objectTransform
            point_a_world = (polyop.getVert base_obj neighbor_verts[1]) * node.objectTransform
            point_b_world = (polyop.getVert base_obj neighbor_verts[2]) * node.objectTransform
            dir_a = safeNormalize (point_a_world - center_world)
            dir_b = safeNormalize (point_b_world - center_world)

            if (dir_a != undefined) and (dir_b != undefined) then
            (
                edge_dot = dot dir_a dir_b
                orthogonal_limit = sin angle_threshold
                straight_limit = -(cos angle_threshold)

                valid_angle = ((abs edge_dot) <= orthogonal_limit) or (edge_dot <= straight_limit)
            )
        )

        valid_angle
        -- return
    ),

    /*
    Collects border vertices whose two border edges are neither orthogonal nor straight.
    Invalid border junctions that do not have exactly two border neighbors are included as problematic.
    */
    function collectNonOrthoBorderVerts node angle_threshold:axis_angle_threshold =
    (
        bad_verts = #{}

        if isSupportedNode node then
        (
            base_obj = node.baseObject
            border_edges = getOpenBorderEdges node
            border_verts = polyop.getVertsUsingEdge base_obj border_edges

            for vert_index in border_verts do
            (
                if not (isValidBorderAngle node vert_index border_edges angle_threshold:angle_threshold) then
                (
                    bad_verts[vert_index] = true
                )
            )
        )

        bad_verts
        -- return
    ),

    /*
    Selects non-orthogonal and non-straight border vertices on all selected supported wall objects.
    The dedicated Border Angle Threshold value is used as tolerance around 90/270 and 180 degrees.
    */
    function selectNonOrthoBorderVerts angle_threshold:axis_angle_threshold =
    (
        selected_nodes = selection as array
        supported_nodes = #()
        total_bad_verts = 0

        for node in selected_nodes do
        (
            if isSupportedNode node then
            (
                append supported_nodes node
                bad_verts = collectNonOrthoBorderVerts node angle_threshold:angle_threshold
                polyop.setVertSelection node.baseObject bad_verts
                update node
                total_bad_verts += bad_verts.numberSet

            )
        )

        if supported_nodes.count == 0 then
        (
            messageBox "WallMeshCleaner: Select at least one supported Editable Poly wall object."
            false
        )
        else
        (
            try
            (
                max modify mode
                subObjectLevel = 1
            )
            catch
            (
            )

            format "TEST ANGLES: % selected\n" total_bad_verts
            completeRedraw()
            true
        )
        -- return
    ),


    /*
    Collects vertices that have another vertex on the same object within the requested position threshold.
    Both vertices of every near-coincident pair are returned; geometry is not modified.
    */
    function collectDoubleVerts node position_threshold:1.0 =
    (
        double_verts = #{}

        if isSupportedNode node then
        (
            base_obj = node.baseObject
            vert_count = polyop.getNumVerts base_obj
            threshold_value = if position_threshold < 0.0 then 0.0 else position_threshold
            threshold_sq = threshold_value * threshold_value

            if vert_count > 1 then
            (
                for vert_a = 1 to (vert_count - 1) do
                (
                    pos_a = polyop.getVert base_obj vert_a

                    for vert_b = (vert_a + 1) to vert_count do
                    (
                        pos_b = polyop.getVert base_obj vert_b
                        delta_pos = pos_b - pos_a

                        if (abs delta_pos.x <= threshold_value) and \
                           (abs delta_pos.y <= threshold_value) and \
                           (abs delta_pos.z <= threshold_value) then
                        (
                            if (dot delta_pos delta_pos) <= threshold_sq then
                            (
                                double_verts[vert_a] = true
                                double_verts[vert_b] = true
                            )
                        )
                    )
                )
            )
        )

        double_verts
        -- return
    ),

    /*
    Selects all near-coincident vertices on the currently selected supported wall objects.
    The position threshold is measured in 3ds Max system units and the operation is selection-only.
    */
    function selectDoubleVerts position_threshold:1.0 =
    (
        selected_nodes = selection as array
        supported_nodes = #()
        total_double_verts = 0

        for node in selected_nodes do
        (
            if isSupportedNode node then
            (
                append supported_nodes node
                double_verts = collectDoubleVerts node position_threshold:position_threshold
                polyop.setVertSelection node.baseObject double_verts
                update node
                total_double_verts += double_verts.numberSet

            )
        )

        if supported_nodes.count == 0 then
        (
            messageBox "WallMeshCleaner: Select at least one supported Editable Poly wall object."
            false
        )
        else
        (
            try
            (
                max modify mode
                subObjectLevel = 1
            )
            catch
            (
            )

            format "FIND DOUBLE VERTS: % selected\n" total_double_verts
            completeRedraw()
            true
        )
        -- return
    ),

    /*
    Returns the closest point on the line segment between two points.
    This is used when straightening a border vertex to a 180 degree configuration.
    */
    function closestPointOnSegment point_value segment_a segment_b =
    (
        segment_vector = segment_b - segment_a
        segment_length_sq = dot segment_vector segment_vector

        if segment_length_sq <= (epsilon * epsilon) then
        (
            segment_a
        )
        else
        (
            segment_t = (dot (point_value - segment_a) segment_vector) / segment_length_sq
            if segment_t < 0.0 then
            (
                segment_t = 0.0
            )
            else if segment_t > 1.0 then
            (
                segment_t = 1.0
            )
            segment_a + (segment_vector * segment_t)
        )
        -- return
    ),

    /*
    Returns the nearest point that makes the angle A-C-B exactly 90 degrees.
    The solution lies on the circle whose diameter is AB and stays in the original corner plane.
    */
    function closestRightAnglePoint point_value point_a point_b =
    (
        midpoint_value = (point_a + point_b) * 0.5
        diameter_vector = point_b - point_a
        radius_value = (length diameter_vector) * 0.5
        axis_u = safeNormalize diameter_vector

        if (axis_u == undefined) or (radius_value <= epsilon) then
        (
            undefined
        )
        else
        (
            offset_value = point_value - midpoint_value
            offset_parallel = axis_u * (dot offset_value axis_u)
            offset_perpendicular = offset_value - offset_parallel
            axis_v = safeNormalize offset_perpendicular

            if axis_v == undefined then
            (
                undefined
            )
            else
            (
                coord_x = dot offset_value axis_u
                coord_y = dot offset_value axis_v
                radial_length = sqrt ((coord_x * coord_x) + (coord_y * coord_y))

                if radial_length <= epsilon then
                (
                    midpoint_value + (axis_v * radius_value)
                )
                else
                (
                    radial_scale = radius_value / radial_length
                    midpoint_value + (axis_u * (coord_x * radial_scale)) + (axis_v * (coord_y * radial_scale))
                )
            )
        )
        -- return
    ),

    /*
    Returns a stable horizontal world-space axis for a wall edge from its adjacent face normals.
    The axis lies in the wall plane and is perpendicular to world Z, preserving the face plane while moving horizontally.
    */
    function getWallHorizontalAxis node edge_index =
    (
        base_obj = node.baseObject
        edge_faces = polyop.getFacesUsingEdge base_obj edge_index
        normal_sum = [0.0,0.0,0.0]
        valid_normal_count = 0

        for face_index in edge_faces do
        (
            face_verts = polyop.getFaceVerts base_obj face_index

            if face_verts.count >= 3 then
            (
                point_a = (polyop.getVert base_obj face_verts[1]) * node.objectTransform
                found_normal = undefined

                for second_index = 2 to (face_verts.count - 1) while found_normal == undefined do
                (
                    point_b = (polyop.getVert base_obj face_verts[second_index]) * node.objectTransform

                    for third_index = (second_index + 1) to face_verts.count while found_normal == undefined do
                    (
                        point_c = (polyop.getVert base_obj face_verts[third_index]) * node.objectTransform
                        candidate_normal = cross (point_b - point_a) (point_c - point_a)
                        candidate_normal = safeNormalize candidate_normal

                        if candidate_normal != undefined then
                        (
                            found_normal = candidate_normal
                        )
                    )
                )

                if found_normal != undefined then
                (
                    if (valid_normal_count > 0) and ((dot normal_sum found_normal) < 0.0) then
                    (
                        found_normal = -found_normal
                    )

                    normal_sum += found_normal
                    valid_normal_count += 1
                )
            )
        )

        if valid_normal_count == 0 then
        (
            undefined
        )
        else
        (
            wall_normal = safeNormalize normal_sum

            if wall_normal == undefined then
            (
                undefined
            )
            else
            (
                horizontal_axis = safeNormalize (cross [0.0,0.0,1.0] wall_normal)

                if horizontal_axis == undefined then
                (
                    undefined
                )
                else
                (
                    /* Keep axis sign deterministic so lower/higher horizontal position does not depend on face winding. */
                    if (abs horizontal_axis.x) >= (abs horizontal_axis.y) then
                    (
                        if horizontal_axis.x < 0.0 then
                        (
                            horizontal_axis = -horizontal_axis
                        )
                    )
                    else
                    (
                        if horizontal_axis.y < 0.0 then
                        (
                            horizontal_axis = -horizontal_axis
                        )
                    )

                    horizontal_axis
                )
            )
        )
        -- return
    ),

    /*
    Aligns all currently selected vertices, regardless of whether they share edges.
    Default mode fixes vertical position in world Z; CTRL mode fixes horizontal position in the wall plane.
    LMB uses the lower/left extreme and RMB uses the upper/right extreme in the active mode.
    */
    function fixNonOrthoBorderVerts use_high_z:false horizontal_mode:false =
    (
        selected_nodes = selection as array
        supported_nodes = #()
        total_fixed_verts = 0

        undo "WallMeshCleaner - Fix Border Angles" on
        (
            for node in selected_nodes do
            (
                if isSupportedNode node then
                (
                    append supported_nodes node
                    base_obj = node.baseObject
                    selected_verts = polyop.getVertSelection base_obj
                    selected_indices = selected_verts as array

                    if selected_indices.count > 1 then
                    (
                        inverse_tm = inverse node.objectTransform
                        fixed_verts = 0

                        if horizontal_mode then
                        (
                            summed_normal = [0.0,0.0,0.0]
                            used_faces = #{}

                            for vert_index in selected_indices do
                            (
                                vert_faces = polyop.getFacesUsingVert base_obj #{vert_index}
                                used_faces += vert_faces
                            )

                            for face_index in used_faces do
                            (
                                face_normal_local = polyop.getFaceNormal base_obj face_index
                                face_normal_world = normalize (face_normal_local * node.objectTransform)

                                if (length face_normal_world) > epsilon then
                                (
                                    if (length summed_normal) > epsilon then
                                    (
                                        if (dot summed_normal face_normal_world) < 0.0 then
                                        (
                                            face_normal_world = -face_normal_world
                                        )
                                    )

                                    summed_normal += face_normal_world
                                )
                            )

                            if (length summed_normal) > epsilon then
                            (
                                wall_normal = normalize summed_normal
                                horizontal_axis = cross [0.0,0.0,1.0] wall_normal

                                if (length horizontal_axis) > epsilon then
                                (
                                    horizontal_axis = normalize horizontal_axis

                                    if (abs horizontal_axis.x) >= (abs horizontal_axis.y) then
                                    (
                                        if horizontal_axis.x < 0.0 then
                                        (
                                            horizontal_axis = -horizontal_axis
                                        )
                                    )
                                    else
                                    (
                                        if horizontal_axis.y < 0.0 then
                                        (
                                            horizontal_axis = -horizontal_axis
                                        )
                                    )

                                    target_position = undefined

                                    for vert_index in selected_indices do
                                    (
                                        point_world = (polyop.getVert base_obj vert_index) * node.objectTransform
                                        current_position = dot point_world horizontal_axis

                                        if target_position == undefined then
                                        (
                                            target_position = current_position
                                        )
                                        else
                                        (
                                            if use_high_z then
                                            (
                                                if current_position > target_position then
                                                (
                                                    target_position = current_position
                                                )
                                            )
                                            else
                                            (
                                                if current_position < target_position then
                                                (
                                                    target_position = current_position
                                                )
                                            )
                                        )
                                    )

                                    if target_position != undefined then
                                    (
                                        for vert_index in selected_indices do
                                        (
                                            point_world = (polyop.getVert base_obj vert_index) * node.objectTransform
                                            current_position = dot point_world horizontal_axis
                                            position_delta = target_position - current_position

                                            if (abs position_delta) > epsilon then
                                            (
                                                moving_world = point_world + (horizontal_axis * position_delta)
                                                moving_local = moving_world * inverse_tm
                                                polyop.setVert base_obj #{vert_index} moving_local
                                                fixed_verts += 1
                                            )
                                        )
                                    )
                                )
                            )
                        )
                        else
                        (
                            target_z = undefined

                            for vert_index in selected_indices do
                            (
                                point_world = (polyop.getVert base_obj vert_index) * node.objectTransform

                                if target_z == undefined then
                                (
                                    target_z = point_world.z
                                )
                                else
                                (
                                    if use_high_z then
                                    (
                                        if point_world.z > target_z then
                                        (
                                            target_z = point_world.z
                                        )
                                    )
                                    else
                                    (
                                        if point_world.z < target_z then
                                        (
                                            target_z = point_world.z
                                        )
                                    )
                                )
                            )

                            if target_z != undefined then
                            (
                                for vert_index in selected_indices do
                                (
                                    point_world = (polyop.getVert base_obj vert_index) * node.objectTransform

                                    if (abs (point_world.z - target_z)) > epsilon then
                                    (
                                        point_world.z = target_z
                                        moving_local = point_world * inverse_tm
                                        polyop.setVert base_obj #{vert_index} moving_local
                                        fixed_verts += 1
                                    )
                                )
                            )
                        )

                        update node
                        total_fixed_verts += fixed_verts
                    )
                )
            )
        )

        if supported_nodes.count == 0 then
        (
            messageBox "WallMeshCleaner: Select at least one supported Editable Poly wall object."
            false
        )
        else
        (
            if horizontal_mode then
            (
                if use_high_z then
                (
                    format "FIX ANGLES: Horizontal - Align RIGHT\n"
                )
                else
                (
                    format "FIX ANGLES: Horizontal - Align LEFT\n"
                )
            )
            else
            (
                if use_high_z then
                (
                    format "FIX ANGLES: Align TOP\n"
                )
                else
                (
                    format "FIX ANGLES: Align BOTTOM\n"
                )
            )

            completeRedraw()
            true
        )
        -- return
    ),

    /*
    Returns the direct edge shared by two vertices, or undefined when no such edge exists.
    The search uses only native Editable Poly edge/vertex adjacency.
    */
    function getEdgeBetweenVerts base_obj vert_a vert_b =
    (
        result_edge = undefined
        edges_a = polyop.getEdgesUsingVert base_obj #{vert_a}
        edges_b = polyop.getEdgesUsingVert base_obj #{vert_b}
        shared_edges = edges_a * edges_b

        if shared_edges.numberSet > 0 then
        (
            for edge_index in shared_edges while result_edge == undefined do
            (
                edge_verts = polyop.getEdgeVerts base_obj edge_index
                if edge_verts.count == 2 then
                (
                    if ((edge_verts[1] == vert_a) and (edge_verts[2] == vert_b)) or \
                       ((edge_verts[1] == vert_b) and (edge_verts[2] == vert_a)) then
                    (
                        result_edge = edge_index
                    )
                )
            )
        )

        result_edge
        -- return
    ),

    /*
    Finds the closest pair of distinct vertices within the requested threshold.
    Re-running this after every collapse avoids using stale vertex indices.
    */
    function findClosestDoubleVertPair node position_threshold:1.0 blocked_pairs:undefined =
    (
        result_pair = undefined

        if isSupportedNode node then
        (
            base_obj = node.baseObject
            vert_count = polyop.getNumVerts base_obj
            threshold_value = if position_threshold < 0.0 then 0.0 else position_threshold
            threshold_sq = threshold_value * threshold_value
            best_distance_sq = undefined

            if vert_count > 1 then
            (
                for vert_a = 1 to (vert_count - 1) do
                (
                    pos_a = polyop.getVert base_obj vert_a

                    for vert_b = (vert_a + 1) to vert_count do
                    (
                        pos_b = polyop.getVert base_obj vert_b
                        delta_pos = pos_b - pos_a

                        if (abs delta_pos.x <= threshold_value) and \
                           (abs delta_pos.y <= threshold_value) and \
                           (abs delta_pos.z <= threshold_value) then
                        (
                            distance_sq = dot delta_pos delta_pos
                            if distance_sq <= threshold_sq then
                            (
                                pair_key = (vert_a as string) + ":" + (vert_b as string)
                                pair_blocked = if blocked_pairs == undefined then false else ((findItem blocked_pairs pair_key) > 0)

                                if not pair_blocked then
                                (
                                    if (best_distance_sq == undefined) or (distance_sq < best_distance_sq) then
                                    (
                                        best_distance_sq = distance_sq
                                        result_pair = #(vert_a, vert_b)
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )

        result_pair
        -- return
    ),

    /*
    Connects each near-coincident vertex pair with an edge when necessary, then collapses that edge.
    The closest pair is processed first and topology is re-read after every successful collapse.
    */
    function fixDoubleVerts position_threshold:1.0 =
    (
        selected_nodes = selection as array
        supported_nodes = #()
        total_collapsed_pairs = 0
        total_failed_pairs = 0

        undo "WallMeshCleaner - Fix Double Verts" on
        (
            for node in selected_nodes do
            (
                if isSupportedNode node then
                (
                    append supported_nodes node
                    base_obj = node.baseObject
                    collapsed_pairs = 0
                    failed_pairs = 0
                    blocked_pairs = #()
                    keep_processing = true

                    while keep_processing do
                    (
                        pair_value = findClosestDoubleVertPair node position_threshold:position_threshold blocked_pairs:blocked_pairs

                        if pair_value == undefined then
                        (
                            keep_processing = false
                        )
                        else
                        (
                            vert_a = pair_value[1]
                            vert_b = pair_value[2]
                            pair_key = (vert_a as string) + ":" + (vert_b as string)
                            collapse_edge = getEdgeBetweenVerts base_obj vert_a vert_b

                            if collapse_edge == undefined then
                            (
                                try
                                (
                                    collapse_edge = polyop.createEdge base_obj vert_a vert_b
                                )
                                catch
                                (
                                    collapse_edge = undefined
                                )
                            )

                            if collapse_edge != undefined then
                            (
                                collapse_result = false
                                try
                                (
                                    polyop.collapseEdges base_obj #{collapse_edge}
                                    collapse_result = true
                                )
                                catch
                                (
                                    collapse_result = false
                                )

                                if collapse_result then
                                (
                                    collapsed_pairs += 1
                                    blocked_pairs = #()
                                    update node
                                )
                                else
                                (
                                    append blocked_pairs pair_key
                                    failed_pairs += 1
                                )
                            )
                            else
                            (
                                append blocked_pairs pair_key
                                failed_pairs += 1
                            )
                        )
                    )

                    remaining_double_verts = collectDoubleVerts node position_threshold:position_threshold
                    polyop.setVertSelection base_obj remaining_double_verts
                    update node

                    total_collapsed_pairs += collapsed_pairs
                    total_failed_pairs += failed_pairs
                )
            )
        )

        if supported_nodes.count == 0 then
        (
            messageBox "WallMeshCleaner: Select at least one supported Editable Poly wall object."
            false
        )
        else
        (
            if total_failed_pairs > 0 then
            (
                format "FIX VERTS: % fixed | % unresolved\n" total_collapsed_pairs total_failed_pairs
            )
            else
            (
                format "FIX VERTS: % fixed\n" total_collapsed_pairs
            )
            completeRedraw()
            true
        )
        -- return
    ),

    /*
    Initializes the WallMeshCleaner struct instance.
    Persistent settings are loaded by the rollout after creation.
    */
    on create do
    (
    )
)

WallMeshCleaner = WallMeshCleaner_v()

saved_weld_enabled = WallMeshCleaner.readIniBool "WeldVertices" true
saved_weld_threshold = WallMeshCleaner.readIniFloat "WeldThreshold" 1.0
saved_display_hidden_edges = WallMeshCleaner.readIniBool "DisplayHiddenEdges" false
saved_double_side = WallMeshCleaner.readIniBool "DoubleSide" true
saved_auto_smooth = WallMeshCleaner.readIniBool "AutoSmooth" false
saved_cut_mode_index = WallMeshCleaner.readIniInt "CutMode" 1
saved_angle_threshold = WallMeshCleaner.readIniFloat "AngleThreshold" 5.0
saved_border_angle_threshold = WallMeshCleaner.readIniFloat "BorderAngleThreshold" 5.0
saved_double_vert_threshold = WallMeshCleaner.readIniFloat "DoubleVertThreshold" 1.0
saved_dialog_position = WallMeshCleaner.loadDialogPosition()

rollout WallMeshCleanerOptionsRollout "Options" width:310 height:142
(
    checkbox weld_checkbox "Weld Vertices" pos:[8,13] width:110 height:20 checked:saved_weld_enabled tooltip:"Enable vertex welding.\n\nUses Weld Threshold."
    label weld_threshold_label "Threshold:" pos:[140,15] width:62 height:18
    spinner weld_threshold_spinner "" pos:[200,12] width:102 height:20 \
        range:[0.0,1000000.0,saved_weld_threshold] type:#worldUnits scale:0.1 \
        tooltip:"Maximum weld distance.\n\nUnits: system units."

    checkbox auto_smooth_checkbox "Auto Smooth" \
        pos:[8,42] width:126 height:20 checked:saved_auto_smooth \
        tooltip:"Enable automatic smoothing.\n\nApplied around supported cleanup operations."

    button smooth_button "Smooth" \
        pos:[166,38] width:136 height:26 \
        tooltip:"Apply Auto Smooth.\n\nUses the current smoothing threshold."

    checkbutton hidden_edges_checkbutton "Display Hidden Edges" \
        pos:[8,75] width:142 height:26 checked:saved_display_hidden_edges \
        tooltip:"Toggle hidden edge display.\n\nAffects selected wall objects."

    checkbutton double_side_checkbutton "Double Side" \
        pos:[160,75] width:142 height:26 checked:saved_double_side \
        tooltip:"Toggle double-sided display.\n\nDisables backface culling when enabled."

    on weld_checkbox changed state do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on weld_threshold_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on auto_smooth_checkbox changed state do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on hidden_edges_checkbutton changed state do
    (
        WallMeshCleaner.setSelectionDisplayHiddenEdges state
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on double_side_checkbutton changed state do
    (
        WallMeshCleaner.setSelectionDoubleSide state
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on smooth_button pressed do
    (
        ::WallMeshCleanerRollout.runSmooth()
    )
)

rollout WallMeshCleanerFaceSlicerRollout "Face Slicer" width:310 height:86
(
    radiobuttons cut_mode_radio "" pos:[8,8] width:243 height:20 \
        labels:#("All", "Horizontal", "Vertical") default:saved_cut_mode_index columns:3 align:#left \
        offsets:#([0,0],[-15,0],[0,0]) \
        tooltip:"Choose slicing direction.\n\nAll: Vertical first, then Horizontal."

    spinner angle_spinner "Angle:" pos:[257,8] width:45 height:20 \
        range:[0.0,45.0,saved_angle_threshold] type:#float scale:1.0 \
        tooltip:"Orientation tolerance.\n\nUnits: degrees."

    button slice_button "Slice Selected Walls" pos:[8,40] width:294 height:34 tooltip:"Slice selected wall faces.\n\nAll: Vertical first, then Horizontal."

    on cut_mode_radio changed state do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on angle_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on slice_button pressed do
    (
        ::WallMeshCleanerRollout.runFaceSlicer()
    )
)

rollout WallMeshCleanerFaceCleanerRollout "Face Cleaner" width:310 height:60
(
    button junction_button "Fix N-gons" pos:[8,8] width:294 height:34 tooltip:"Reduce wall N-gons.\n\nPrefer orthogonal clean cuts.\n\nRemove redundant dirty topology."

    on junction_button pressed do
    (
        ::WallMeshCleanerRollout.runFaceCleaner()
    )
)

rollout WallMeshCleanerVertexCleanerRollout "Vertex Cleaner" width:310 height:144
(
    button test_border_angles_button "Test Border Angles" \
        pos:[8,8] width:138 height:34 \
        tooltip:"Select bad border-angle vertices.\n\nAccepts orthogonal or straight borders.\n\nSelection only."

    spinner border_angle_threshold_spinner "" pos:[152,14] width:76 height:20 \
        range:[0.0,45.0,saved_border_angle_threshold] type:#float scale:0.1 \
        tooltip:"Border angle tolerance.\n\nValid angles: 90 / 180 / 270 degrees."

    button fix_border_angles_button "Fix Angles" \
        pos:[234,8] width:68 height:34 \
        tooltip:"LMB: Align BOTTOM.\n\nRMB: Align TOP.\n\nCTRL + LMB: Align LEFT.\n\nCTRL + RMB: Align RIGHT.\n\nUses all currently selected vertices.\n\nHorizontal movement stays in the wall plane."

    button find_double_verts_button "Find Double Verts" \
        pos:[8,50] width:138 height:34 \
        tooltip:"Select near-coincident vertices.\n\nUses Double Vert Threshold.\n\nSelection only."

    spinner double_vert_threshold_spinner "" pos:[152,56] width:76 height:20 \
        range:[0.0,1000000.0,saved_double_vert_threshold] type:#worldUnits scale:0.1 \
        tooltip:"Near-coincident distance threshold.\n\nUnits: system units.\n\nDefault: 1 system unit."

    button fix_double_verts_button "Fix Verts" \
        pos:[234,50] width:68 height:34 \
        tooltip:"Fix near-coincident vertex pairs.\n\nCreate edge if needed.\n\nCollapse connected pair.\n\nUnresolved pairs stay selected."

    button test_vertical_position_button "Test Vertical Position" \
        pos:[8,92] width:294 height:34 \
        tooltip:"Use currently selected vertices.\n\nReport maximum Z position difference.\n\nSelection only."

    on border_angle_threshold_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on double_vert_threshold_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on test_border_angles_button pressed do
    (
        ::WallMeshCleanerRollout.runBorderAngleTest()
    )

    on fix_border_angles_button pressed do
    (
        ::WallMeshCleanerRollout.runBorderAngleFix use_high_z:false horizontal_mode:keyboard.controlPressed
    )

    on fix_border_angles_button rightclick do
    (
        ::WallMeshCleanerRollout.runBorderAngleFix use_high_z:true horizontal_mode:keyboard.controlPressed
    )

    on find_double_verts_button pressed do
    (
        ::WallMeshCleanerRollout.runDoubleVertTest()
    )

    on fix_double_verts_button pressed do
    (
        ::WallMeshCleanerRollout.runDoubleVertFix()
    )

    on test_vertical_position_button pressed do
    (
        ::WallMeshCleanerRollout.runVerticalPositionTest()
    )
)

rollout WallMeshCleanerRollout "Wall Mesh Cleaner 0.54" width:344 height:594
(
    button restart_button "Restart" pos:[262,6] width:74 height:22 tooltip:"Reload the matching versioned script first.\nFallback: WallMeshCleaner.ms."
    subRollout tool_subrollout "Wall Mesh Cleaner 0.54" pos:[8,32] width:328 height:554

    /*
    Returns the requested face-slice orientation from the Face Slicer sub-rollout.
    All performs vertical first and horizontal second in the slicer implementation.
    */
    function getCutMode =
    (
        case WallMeshCleanerFaceSlicerRollout.cut_mode_radio.state of
        (
            2: #horizontal
            3: #vertical
            default: #all
        )
        -- return
    )

    /*
    Saves all controls from the four child rollouts to the shared INI file.
    Child rollouts call this parent method so persistence remains centralized.
    */
    function saveUiSettings =
    (
        WallMeshCleaner.saveSettings \
            WallMeshCleanerOptionsRollout.weld_checkbox.checked \
            WallMeshCleanerOptionsRollout.weld_threshold_spinner.value \
            WallMeshCleanerOptionsRollout.hidden_edges_checkbutton.checked \
            WallMeshCleanerOptionsRollout.double_side_checkbutton.checked \
            WallMeshCleanerOptionsRollout.auto_smooth_checkbox.checked \
            WallMeshCleanerFaceSlicerRollout.cut_mode_radio.state \
            WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            border_angle_threshold:WallMeshCleanerVertexCleanerRollout.border_angle_threshold_spinner.value \
            double_vert_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value
        -- return
    )

    /*
    Runs Auto Smooth from the Options sub-rollout.
    The operation remains undoable and redraws the viewport after completion.
    */
    function runSmooth =
    (
        undo "WallMeshCleaner - Auto Smooth" on
        (
            WallMeshCleaner.autoSmoothSelection()
        )

        completeRedraw()
        -- return
    )

    /*
    Runs the main face slicer using shared Options and Face Slicer controls.
    Display options are applied before slicing and current settings are persisted.
    */
    function runFaceSlicer =
    (
        WallMeshCleaner.setSelectionDisplayHiddenEdges WallMeshCleanerOptionsRollout.hidden_edges_checkbutton.checked
        WallMeshCleaner.setSelectionDoubleSide WallMeshCleanerOptionsRollout.double_side_checkbutton.checked
        saveUiSettings()

        WallMeshCleaner.sliceSelection \
            weld_vertices:WallMeshCleanerOptionsRollout.weld_checkbox.checked \
            weld_threshold:WallMeshCleanerOptionsRollout.weld_threshold_spinner.value \
            cut_mode:(getCutMode()) \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value
        -- return
    )

    /*
    Runs the face-cleaner N-gon post-process using the current shared options.
    The handler lives on the parent rollout so the sub-rollout stays UI-only.
    */
    function runFaceCleaner =
    (
        saveUiSettings()

        WallMeshCleaner.propagateSelectionJunctionCuts \
            weld_vertices:WallMeshCleanerOptionsRollout.weld_checkbox.checked \
            weld_threshold:WallMeshCleanerOptionsRollout.weld_threshold_spinner.value \
            auto_smooth:WallMeshCleanerOptionsRollout.auto_smooth_checkbox.checked \
            cut_mode:(getCutMode()) \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value
        -- return
    )

    /*
    Runs border-angle validation from the Vertex Cleaner sub-rollout.
    Problem vertices are selected without modifying geometry.
    */
    function runBorderAngleTest =
    (
        saveUiSettings()
        WallMeshCleaner.selectNonOrthoBorderVerts \
            angle_threshold:WallMeshCleanerVertexCleanerRollout.border_angle_threshold_spinner.value
        -- return
    )

    /*
    Aligns all currently selected vertices as one set.
    LMB/RMB use bottom/top Z; CTRL + LMB/RMB use left/right wall-local horizontal position.
    */
    function runBorderAngleFix use_high_z:false horizontal_mode:false =
    (
        saveUiSettings()
        WallMeshCleaner.fixNonOrthoBorderVerts use_high_z:use_high_z horizontal_mode:horizontal_mode
        -- return
    )

    /*
    Runs duplicate-position vertex detection from the Vertex Cleaner sub-rollout.
    All vertices participating in a near-coincident pair are selected.
    */
    function runDoubleVertTest =
    (
        saveUiSettings()
        WallMeshCleaner.selectDoubleVerts \
            position_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value
        -- return
    )

    /*
    Fixes near-coincident vertices using the current Vertex Cleaner distance threshold.
    Only vertices detected by the duplicate-position test are passed to the weld operation.
    */
    function runDoubleVertFix =
    (
        saveUiSettings()
        WallMeshCleaner.fixDoubleVerts \
            position_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value
        -- return
    )

    /*
    Reports the world-Z range across all currently selected vertices.
    Values are formatted with the current 3ds Max display-unit settings.
    */
    function runVerticalPositionTest =
    (
        selected_nodes = selection as array
        found_vert = false
        min_z = 0.0
        max_z = 0.0

        for node in selected_nodes do
        (
            if WallMeshCleaner.isSupportedNode node then
            (
                base_obj = node.baseObject
                selected_verts = polyop.getVertSelection base_obj

                for vert_index in selected_verts do
                (
                    world_pos = (polyop.getVert base_obj vert_index) * node.objectTransform

                    if not found_vert then
                    (
                        min_z = world_pos.z
                        max_z = world_pos.z
                        found_vert = true
                    )
                    else
                    (
                        if world_pos.z < min_z then min_z = world_pos.z
                        if world_pos.z > max_z then max_z = world_pos.z
                    )
                )
            )
        )

        if found_vert then
        (
            z_difference = max_z - min_z
            formatted_difference = units.formatValue z_difference
            formatted_difference = substituteString formatted_difference " " ""
            format "Z POSITION DIFFERENCE: %\n" formatted_difference
        )
        else
        (
            format "Z POSITION DIFFERENCE: No verts selected\n"
        )
        -- return
    )

    on restart_button pressed do
    (
        script_path = WallMeshCleaner.getRestartScriptPath WallMeshCleanerScriptPath

        if script_path != undefined then
        (
            saveUiSettings()
            destroyDialog WallMeshCleanerRollout
            fileIn script_path
        )
        else
        (
            messageBox (
                "WallMeshCleaner restart failed.\n\n" +
                "Neither the versioned script nor WallMeshCleaner.ms exists beside the running script."
            )
        )
    )

    on WallMeshCleanerRollout open do
    (
        addSubRollout tool_subrollout WallMeshCleanerOptionsRollout
        addSubRollout tool_subrollout WallMeshCleanerFaceSlicerRollout
        addSubRollout tool_subrollout WallMeshCleanerFaceCleanerRollout
        addSubRollout tool_subrollout WallMeshCleanerVertexCleanerRollout
    )

    on WallMeshCleanerRollout close do
    (
        dialog_pos = undefined

        try
        (
            dialog_pos = getDialogPos WallMeshCleanerRollout
        )
        catch
        (
            dialog_pos = undefined
        )

        WallMeshCleaner.saveSettings \
            WallMeshCleanerOptionsRollout.weld_checkbox.checked \
            WallMeshCleanerOptionsRollout.weld_threshold_spinner.value \
            WallMeshCleanerOptionsRollout.hidden_edges_checkbutton.checked \
            WallMeshCleanerOptionsRollout.double_side_checkbutton.checked \
            WallMeshCleanerOptionsRollout.auto_smooth_checkbox.checked \
            WallMeshCleanerFaceSlicerRollout.cut_mode_radio.state \
            WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            border_angle_threshold:WallMeshCleanerVertexCleanerRollout.border_angle_threshold_spinner.value \
            double_vert_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value \
            dialog_position:dialog_pos

        removeSubRollout tool_subrollout WallMeshCleanerVertexCleanerRollout
        removeSubRollout tool_subrollout WallMeshCleanerFaceCleanerRollout
        removeSubRollout tool_subrollout WallMeshCleanerFaceSlicerRollout
        removeSubRollout tool_subrollout WallMeshCleanerOptionsRollout
    )
)

if saved_dialog_position == undefined then
(
    createDialog WallMeshCleanerRollout
)
else
(
    createDialog WallMeshCleanerRollout pos:saved_dialog_position
)

/*
TEST CODE

A. Display Hidden Edges:
1. Select a wall object.
2. Toggle "Display Hidden Edges".
3. Verify Object Properties > Edges Only behavior visually.
4. Listener equivalent:
WallMeshCleaner.setSelectionDisplayHiddenEdges true
WallMeshCleaner.setSelectionDisplayHiddenEdges false

B. Double Side:
1. Select a one-sided wall.
2. Toggle "Double Side".
3. Checked state must set object backFaceCull = false.
4. Listener equivalent:
WallMeshCleaner.setSelectionDoubleSide true
WallMeshCleaner.setSelectionDoubleSide false

C. Main slicer with weld enabled:
WallMeshCleaner.sliceSelection weld_vertices:true weld_threshold:1.0

Weld-only verification:
- Make two border vertices closer than 1 system unit.
- Select the object.
- Run:
WallMeshCleaner.weldSelection 1.0
- The vertices should weld.
- The object's previous Editable Poly weldThreshold value should be restored afterward.

D. Automatic junction propagation with cleanup:
1. Select the architectural wall object.
2. Configure Weld Vertices + Threshold in Options.
3. Enable Auto Smooth if wanted.
4. Press "Fix N-gons".
5. Expected order:
   - Auto Smooth when checked
   - Fix N-gons
   - weld using the Options threshold when Weld Vertices is checked
   - remove vertices with exactly two straight edges
   - Auto Smooth again when checked
5. Listener should print:
   WallMeshCleaner: Auto Smooth before Fix N-gons...
   WallMeshCleaner: Post Fix N-gons cleanup...

Cleanup-only test:
WallMeshCleaner.cleanupAfterNgonCut $     weld_vertices:true     weld_threshold:1.0     reapply_auto_smooth:true

Verify that:
- coincident border vertices are welded with threshold 0.0
- vertices with exactly two collinear edges are removed
- surrounding faces remain intact
- Auto Smooth is reapplied when requested

Listener equivalent:
WallMeshCleaner.propagateSelectionJunctionCuts auto_smooth:true

E. Connected-island protection:
- Different disconnected walls may use the same smoothing-group mask.
- A propagated cut must remain limited to the connected wall island containing
  the detected junction.

F. INI persistence:
1. Rerun the script with an existing WallMeshCleaner.ini.
   The dialog must initialize without an undefined-function error.
2. Change Weld Vertices, Threshold, Display Hidden Edges, Double Side, Auto Smooth.
2. Move the rollout.
3. Close and rerun WallMeshCleaner_0.30.ms.
4. All settings and the rollout position should be restored.

INI location:
<User Scripts>\WallMeshCleaner.ini
*/


/* 0.26 REGRESSION NOTES
Use a fresh test_wall.obj import for each orientation; OBJ import can renumber vertices.
User's Editable Poly pairs BEFORE slicing:
Horizontal: #{9..10}, #{7..8}, #{5..6}
Vertical: #{2,5}, #{3,6}, #{7,9}, #{8,10}
OBJ world-Z levels: 511581.9688, 512207.7188, 513793.9688.
OBJ world-X stations: 1220048.5, 1221966.5, 1223884.5, 1225802.5.
Cuts must continue through both coplanar original polygons wherever wall exists.
Internal diagonal seams must not generate further diagonal cuts.
Clean quad-to-quad dividers may dissolve; opening and non-quad boundaries remain.

Manual regression checklist:
- Doorway, window, U-shaped connected walls, unequal wall heights.
- Adjacent walls sharing an edge; disconnected walls reusing smoothing groups.
- Rotate walls in XY: Horizontal remains relative to world Z.
- Fresh copies for All, Horizontal and Vertical; test 4.9 and 5.1 degree edges.
- Repeat with welding enabled/disabled and Auto Smooth enabled/disabled.
- Fix N-gons removes redundant quad dividers; straight-vertex cleanup preserves faces.
- Original material IDs restored; unselected objects unchanged.
- Rerun with rollout open, then close/reopen and verify INI settings/position.
*/


/* 0.26 CLEANUP TEST NOTES (historical; superseded by 0.26 priority rules and 0.27 hidden-edge priority)
- Cut a flat rectangle: the divider between the two resulting quads should dissolve.
- Cut a strip of clean quads: removable new loop segments should dissolve in sequence.
- A candidate touching a triangle, concave polygon or opening must remain.
- Preserve boundaries between different materials, smoothing groups or noncoplanar faces.
- Historical behavior only: 0.27 now prefers clean slice edges and may dissolve eligible old dirty edges.
- Repeat main cuts and junction cuts; check for stale flags or accidental extra removals.
- Verify no faces disappear and only straight two-edge endpoints are dissolved.
- 0.22's assertion that every requested plane remains is intentionally superseded:
  redundant quad dividers are now expected to be removed.
*/


/* 0.26 TEST NOTES
- Evaluate the complete file: catch blocks must compile (bare throw).
- Slice across an invisible polygon edge: a straight vertex with two visible
  incident edges must dissolve even if hidden incident edges also exist.
- Repeat with Display Hidden Edges on/off: use stored edge visibility, not viewport state.
- Retain a bent two-edge corner, a three-visible-edge T junction, and a folded wall junction.
- Exercise main Slice and Fix N-gons; both call the shared per-cut cleanup.
- Verify removed vertices dissolve surrounding polygons instead of deleting wall surfaces.
- Recheck the 0.23 redundant quad-loop cases after vertex cleanup.
*/



/* 0.26 REGRESSION NOTES
- A straight vertex with exactly two actual polygon edges must dissolve when
  both are visible, only one is visible, or both are hidden.
- Test the same configurations on horizontal and vertical boundaries.
- Vertices with additional hidden edges still require two visible straight
  edges and coplanar incident faces; preserve bent corners and visible junctions.
- A failed removal must not prevent cleanup of later eligible vertices.
- Verify both per-cut cleanup and the final sweep in main and junction slicing.
*/


/* 0.31 BORDER-ANGLE REGRESSION
- Test Border Angles reads polyop.getOpenEdges, so outer borders and inner opening borders are tested while internal two-face seams are ignored.
- A clean border vertex must have exactly two border neighbors.
- With Border Angle Threshold = 5.0 degrees, accept unsigned border-edge angles near 90 degrees or 180 degrees.
  A geometric 270-degree reflex corner has the same unsigned two-ray angle as 90 degrees and is therefore accepted.
- Select every border vertex that is neither orthogonal nor straight.
- Border vertices with a border degree other than two are selected as malformed/problematic.

Direct Listener test on selected supported walls:
WallMeshCleaner.selectNonOrthoBorderVerts angle_threshold:5.0

Deterministic geometry test is provided in WallMeshCleaner_TEST_0.31.ms.
- UI regression: set Border Angle Threshold to 2.5 and reopen the tool; the value must persist independently from the slice Angle spinner.
*/


/* 0.29 ALL-PASS ORDER REGRESSION
For Slice Selected Walls with Cut by edge = All:
- Listener must print "All pass 1/2 | Vertical" before any horizontal pass message.
- All selected supported objects complete the Vertical pass first.
- Then Listener must print "All pass 2/2 | Horizontal" and the Horizontal pass runs.
- Vertical clean slice edges stay protected during the Horizontal pass.
- Horizontal mode alone still performs only horizontal slicing.
- Vertical mode alone still performs only vertical slicing.
*/


/* 0.28 ORTHOGONAL-EDGE PRIORITY REGRESSION
Use the user case containing one triangle, one polygon and one 5+ sided N-gon meeting at the middle wall vertex.

Expected behavior:
- The old internal diagonal/angled divider is dirty and lower priority than horizontal/vertical wall edges.
- If dissolving that angled divider merges its two coplanar same-material/same-SG faces into one four-corner orthogonal region, remove it.
- Run straight-vertex cleanup immediately afterward; the middle vertex that now lies on two collinear orthogonal edges must dissolve.
- The expected fixed result is two orthogonal polygons with no triangle and one fewer vertex.
- A protected clean slice edge always wins even if an older edge would otherwise be preferred.

Listener test on the selected Editable Poly:
format "Before: V=% E=% F=%\n" (polyop.getNumVerts $.baseObject) (polyop.getNumEdges $.baseObject) (polyop.getNumFaces $.baseObject)
WallMeshCleaner.cleanupNewSliceEdges $ (bit.set 0 27 true) collect_new:false
WallMeshCleaner.removeTwoVisibleEdgeStraightVerts $
format "After : V=% E=% F=%\n" (polyop.getNumVerts $.baseObject) (polyop.getNumEdges $.baseObject) (polyop.getNumFaces $.baseObject)

For the supplied regression topology the target is 8 vertices and 2 polygons.
*/


/* 0.27 HIDDEN-EDGE PRIORITY TEST
Use a fresh import of test_wall.obj and enable Display Hidden Edges while inspecting topology.

Expected cleanup behavior after every successful cut:
- Only edges lying on the requested slice plane become new clean edges.
- Edge fragments created by splitting an older hidden edge remain dirty.
- When a clean cut passes through dirty hidden topology, dissolve the dirty hidden edge first.
- If that leaves a straight valence-two vertex on the clean cut, dissolve the vertex and keep the merged edge clean.
- A later perpendicular cut may split an earlier clean cut; both child segments must remain clean.
- Never remove the clean cut just to preserve an older hidden/triangulation edge.

Listener diagnostics after selecting one Editable Poly:
format "Before: V=% E=% F=%\n" (polyop.getNumVerts $.baseObject) (polyop.getNumEdges $.baseObject) (polyop.getNumFaces $.baseObject)
WallMeshCleaner.propagateAutomaticJunctionCuts $ cut_mode:#all angle_threshold:5.0
format "After : V=% E=% F=%\n" (polyop.getNumVerts $.baseObject) (polyop.getNumEdges $.baseObject) (polyop.getNumFaces $.baseObject)

Additional topology check:
problem_verts = #{}
for vert_index = 1 to (polyop.getNumVerts $.baseObject) do
(
    if WallMeshCleaner.isTwoEdgeStraightVertex $.baseObject vert_index then
    (
        problem_verts[vert_index] = true
    )
)
format "Remaining straight 2-edge verts: %\n" problem_verts
*/


/* 0.26 PRIORITY REGRESSION NOTES (supersedes earlier new-divider removal tests)
- Start with a rectangle split by an old vertical edge. Slice horizontally:
  keep the new horizontal divider and remove eligible old vertical segments.
- Add another cut: edges generated by earlier cuts in the same operation remain clean.
- Preserve material, smoothing, border and noncoplanar boundaries.
- Straight valence-two vertices can simplify a clean line; intersections with
  additional old hidden edges must not be dissolved at the expense of that line.
- Main slicing defers seams between tracked original faces until material IDs are
  restored, then rechecks only old edges, preserving the new clean dividers.
*/


/*
FIX ANGLES TEST CODE

1. Select two connected bad-angle border vertices.
2. LMB Fix Angles:
   - default vertical mode
   - higher Z endpoint moves to lower Z
3. RMB Fix Angles:
   - default vertical mode
   - lower Z endpoint moves to higher Z
4. CTRL + LMB Fix Angles:
   - horizontal wall-plane mode
   - higher local horizontal endpoint moves to lower local horizontal position
   - movement stays in the wall plane
5. CTRL + RMB Fix Angles:
   - horizontal wall-plane mode
   - lower local horizontal endpoint moves to higher local horizontal position
   - movement stays in the wall plane

Direct function test:
WallMeshCleaner.fixNonOrthoBorderVerts use_high_z:false horizontal_mode:false
WallMeshCleaner.fixNonOrthoBorderVerts use_high_z:true horizontal_mode:false
WallMeshCleaner.fixNonOrthoBorderVerts use_high_z:false horizontal_mode:true
WallMeshCleaner.fixNonOrthoBorderVerts use_high_z:true horizontal_mode:true
*/


/*
CUT BY EDGE RADIO BUTTON TEST CODE

1. Run WallMeshCleaner_0.54.ms.
2. Face Slicer must show three radio buttons:
   All | Horizontal | Vertical
3. Select each radio button and verify this Listener code:

format "Cut By Edge state: % | mode: %\n" \
    WallMeshCleanerFaceSlicerRollout.cut_mode_radio.state \
    WallMeshCleanerRollout.getCutMode()

Expected mapping:
1 = #all
2 = #horizontal
3 = #vertical

4. Close and reopen the tool. The selected radio button must restore from
   the existing [Settings] CutMode INI value without migration.
*/

/*
FACE SLICER COMPACT ONE-ROW UI TEST CODE

1. Open Face Slicer.
2. There must be no visible "Cut by edge" label.
3. Radio group must remain: All | Horizontal | Vertical.
4. All / Horizontal / Vertical and Angle must stay on the same row.
5. The full All label must be visible.
6. Angle spinner must be about half its previous width (45 px).
7. Main dialog width must remain 344 px.
8. Face Cleaner button text must read "Fix N-gons".
9. Verify UI control positions in Listener:

format "Cut mode pos: % | Angle pos: % | Angle width: % | Dialog size: %\n" \
    WallMeshCleanerFaceSlicerRollout.cut_mode_radio.pos \
    WallMeshCleanerFaceSlicerRollout.angle_spinner.pos \
    WallMeshCleanerFaceSlicerRollout.angle_spinner.width \
    (getDialogSize WallMeshCleanerRollout)

Expected:
- Cut mode pos = [8,8]
- Angle pos = [257,8]
- Angle width = 45
- Dialog width = 344
*/

/*
RESTART FILE PRIORITY TEST CODE

Listener test:
restart_path = WallMeshCleaner.getRestartScriptPath WallMeshCleanerScriptPath
format "Restart source: %\n" WallMeshCleanerScriptPath
format "Restart target: %\n" restart_path

Expected behavior:
1. If WallMeshCleaner_0.54.ms exists beside the running script, restart_path must point to it.
2. Rename or remove WallMeshCleaner_0.54.ms while WallMeshCleaner.ms exists.
   Run the Listener test again; restart_path must point to WallMeshCleaner.ms.
3. If neither file exists, restart_path must be undefined and pressing Restart must keep the UI open and show an error.
*/

/*
RESTART TOP-UI LAYOUT TEST CODE

1. Open WallMeshCleaner_0.54.ms.
2. Restart must be visible at the top-right of the main UI.
3. There must be no Restart row below Vertex Cleaner.
4. Verify the compact layout in Listener:

format "Restart pos: % | size: [% x %] | Dialog size: %\n" \
    WallMeshCleanerRollout.restart_button.pos \
    WallMeshCleanerRollout.restart_button.width \
    WallMeshCleanerRollout.restart_button.height \
    (getDialogSize WallMeshCleanerRollout)

Expected:
- Restart pos = [262,6]
- Restart size = [74 x 22]
- Dialog width = 344
- Dialog height is smaller than 626 px
*/
