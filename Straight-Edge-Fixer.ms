/*
Straight Edge Fixer 0.28
Detects repeated horizontal edge levels and aligns nearby horizontal edges to them.
*/

global WallFixerVersion
global WallFixerRollout
global wall_fixer_version_system
global wall_fixer_version_epoch
global straight_edge_fixer_file_version = "0.28"
global straight_edge_fixer_tool_version = 0.930

/*
Registers this file's shared Wall-Fixer tool version.
Accepts legacy string or numeric global versions; the highest loaded version wins.
*/
if wall_fixer_version_system != 1 then
(
    wall_fixer_version_system = 1
)

if wall_fixer_version_epoch != 2 then
(
    wall_fixer_version_epoch = 2
    WallFixerVersion = undefined
)

straight_edge_fixer_current_tool_version_number = undefined

if WallFixerVersion != undefined then
(
    try
    (
        straight_edge_fixer_current_tool_version_number = WallFixerVersion as float
    )
    catch
    (
        straight_edge_fixer_current_tool_version_number = undefined
    )
)

if straight_edge_fixer_current_tool_version_number == undefined then
(
    WallFixerVersion = straight_edge_fixer_tool_version
)
else if straight_edge_fixer_tool_version > straight_edge_fixer_current_tool_version_number then
(
    WallFixerVersion = straight_edge_fixer_tool_version
)

if WallFixerRollout != undefined then
(
    try
    (
        WallFixerRollout.title = ("Wall-Fixer " + (WallFixerVersion as string))
    )
    catch
    (
    )
)


global straightEdgeFixerCompareData
global straightEdgeFixerCompareLevelData
global StraightEdgeFixer_v
global StraightEdgeFixer
global straightEdgeFixer_ui

/*
Compares edge records by their center world Z.
Used by qsort while detecting Z levels.
*/
function straightEdgeFixerCompareData item_a item_b =
(
    if (item_a[4] < item_b[4]) then
    (
        -1
    )
    else if (item_a[4] > item_b[4]) then
    (
        1
    )
    else
    (
        0
    )
) -- return

/*
Compares detected level records from bottom to top.
Used by qsort before reporting and alignment.
*/
function straightEdgeFixerCompareLevelData level_a level_b =
(
    if (level_a[4] < level_b[4]) then
    (
        -1
    )
    else if (level_a[4] > level_b[4]) then
    (
        1
    )
    else
    (
        0
    )
) -- return

struct StraightEdgeFixer_v
(
    version = "0.2",
    ini_file = ((getDir #plugcfg) + "\\Straight-Edge-Fixer.ini"),
    legacy_ini_file = ((getDir #plugcfg) + "\\Aling-Edges-To-Levels.ini"),

    /*
    Counts enabled bits in a BitArray.
    Used for edge and vertex report counts.
    */
    function countBits bit_set =
    (
        bit_count = 0

        for bit_id in bit_set do
        (
            bit_count += 1
        )

        bit_count
        -- return
    ),


    /*
    Migrates settings from the previous Aling-Edges-To-Levels INI file once.
    Existing Straight Edge Fixer settings are never overwritten.
    */
    function migrateLegacyIni =
    (
        if ((doesFileExist ini_file) == false) and (doesFileExist legacy_ini_file) then
        (
            level_tolerance = getIniSetting legacy_ini_file "Settings" "LevelTolerance"
            min_level_edges = getIniSetting legacy_ini_file "Settings" "MinLevelEdges"
            search_in_z = getIniSetting legacy_ini_file "Settings" "SearchInZ"
            angle_threshold = getIniSetting legacy_ini_file "Settings" "AngleThreshold"
            quiet_mode = getIniSetting legacy_ini_file "Settings" "QuietMode"
            dialog_x = getIniSetting legacy_ini_file "Dialog" "X"
            dialog_y = getIniSetting legacy_ini_file "Dialog" "Y"

            if (level_tolerance != "") then setIniSetting ini_file "Settings" "LevelTolerance" level_tolerance
            if (min_level_edges != "") then setIniSetting ini_file "Settings" "MinLevelEdges" min_level_edges
            if (search_in_z != "") then setIniSetting ini_file "Settings" "SearchInZ" search_in_z
            if (angle_threshold != "") then setIniSetting ini_file "Settings" "AngleThreshold" angle_threshold
            if (quiet_mode != "") then setIniSetting ini_file "Settings" "QuietMode" quiet_mode
            if (dialog_x != "") then setIniSetting ini_file "Dialog" "X" dialog_x
            if (dialog_y != "") then setIniSetting ini_file "Dialog" "Y" dialog_y
        )

        true
        -- return
    ),

    /*
    Safely converts an INI string to a floating-point value.
    Returns default_value when the stored value is missing or invalid.
    */
    function getIniFloat section_name key_name default_value =
    (
        result_value = default_value
        stored_value = getIniSetting ini_file section_name key_name

        if ((stored_value != undefined) and (stored_value != "")) then
        (
            try
            (
                result_value = stored_value as float
            )
            catch
            (
                result_value = default_value
            )
        )

        result_value
        -- return
    ),

    /*
    Safely converts an INI string to an integer value.
    Returns default_value when the stored value is missing or invalid.
    */
    function getIniInteger section_name key_name default_value =
    (
        result_value = default_value
        stored_value = getIniSetting ini_file section_name key_name

        if ((stored_value != undefined) and (stored_value != "")) then
        (
            try
            (
                result_value = stored_value as integer
            )
            catch
            (
                result_value = default_value
            )
        )

        result_value
        -- return
    ),

    /*
    Reads a persisted boolean value.
    Missing values use the supplied default.
    */
    function getIniBoolean section_name key_name default_value =
    (
        result_value = default_value
        stored_value = getIniSetting ini_file section_name key_name

        if (stored_value == "1") then
        (
            result_value = true
        )
        else if (stored_value == "0") then
        (
            result_value = false
        )

        result_value
        -- return
    ),

    /*
    Loads tool settings from the INI file.
    Returns #(level_tolerance, min_level_edges, search_in_z, angle_threshold, quiet_mode).
    */
    function loadSettings =
    (
        level_tolerance = getIniFloat "Settings" "LevelTolerance" 0.01
        min_level_edges = getIniInteger "Settings" "MinLevelEdges" 3
        search_in_z = getIniFloat "Settings" "SearchInZ" 10.0
        angle_threshold = getIniFloat "Settings" "AngleThreshold" 45.0
        quiet_mode = getIniBoolean "Settings" "QuietMode" false

        if (level_tolerance <= 0.0) then
        (
            level_tolerance = 0.01
        )

        if (min_level_edges < 1) then
        (
            min_level_edges = 3
        )

        if (search_in_z < 0.0) then
        (
            search_in_z = 10.0
        )

        if (angle_threshold < 0.0) then
        (
            angle_threshold = 0.0
        )
        else if (angle_threshold > 45.0) then
        (
            angle_threshold = 45.0
        )

        #(level_tolerance, min_level_edges, search_in_z, angle_threshold, quiet_mode)
        -- return
    ),

    /*
    Saves current tool settings to the INI file.
    Called whenever a UI value changes and before an operation starts.
    */
    function saveSettings level_tolerance min_level_edges search_in_z angle_threshold quiet_mode =
    (
        setIniSetting ini_file "Settings" "LevelTolerance" (level_tolerance as string)
        setIniSetting ini_file "Settings" "MinLevelEdges" (min_level_edges as string)
        setIniSetting ini_file "Settings" "SearchInZ" (search_in_z as string)
        setIniSetting ini_file "Settings" "AngleThreshold" (angle_threshold as string)
        setIniSetting ini_file "Settings" "QuietMode" (if quiet_mode then "1" else "0")

        true
        -- return
    ),

    /*
    Loads the saved dialog screen position.
    Returns a Point2 used directly by createDialog.
    */
    function loadDialogPosition =
    (
        position_x = getIniInteger "Dialog" "X" 100
        position_y = getIniInteger "Dialog" "Y" 100

        [position_x, position_y]
        -- return
    ),

    /*
    Saves the dialog screen position.
    The position is stored independently from tool settings.
    */
    function saveDialogPosition dialog_position =
    (
        if (dialog_position != undefined) then
        (
            setIniSetting ini_file "Dialog" "X" (dialog_position.x as string)
            setIniSetting ini_file "Dialog" "Y" (dialog_position.y as string)
        )

        true
        -- return
    ),

    /*
    Finds an existing top Edit Poly modifier.
    Returns undefined when the current top modifier is not Edit Poly.
    */
    function getTopEditPoly node =
    (
        edit_poly = undefined

        if (node.modifiers.count > 0) then
        (
            top_modifier = node.modifiers[1]

            if (classOf top_modifier == Edit_Poly) then
            (
                edit_poly = top_modifier
            )
        )

        edit_poly
        -- return
    ),

    /*
    Returns true when a modifier instance belongs to the supplied node stack.
    Uses modPanel.getModifierIndex so instanced modifiers are handled correctly.
    */
    function modifierBelongsToNode node modifier_value =
    (
        result_value = false

        if ((isValidNode node) and (modifier_value != undefined)) then
        (
            try
            (
                result_value = ((modPanel.getModifierIndex node modifier_value) != undefined)
            )
            catch
            (
                result_value = false
            )
        )

        result_value
        -- return
    ),

    /*
    Returns the currently active Edit Poly modifier when it belongs to this node.
    Undefined is returned when the Modify panel is closed or another stack item is active.
    */
    function getActiveEditPoly node =
    (
        edit_poly = undefined
        current_object = undefined

        try
        (
            current_object = modPanel.getCurrentObject()
        )
        catch
        (
            current_object = undefined
        )

        if ((current_object != undefined) and
            (classOf current_object == Edit_Poly) and
            (modifierBelongsToNode node current_object)) then
        (
            edit_poly = current_object
        )

        edit_poly
        -- return
    ),

    /*
    Finds the first Edit Poly modifier with an exact case-insensitive name.
    Search order follows the modifier stack from top to bottom.
    */
    function findNamedEditPoly node modifier_name =
    (
        edit_poly = undefined
        requested_name = toUpper modifier_name

        for modifier_index = 1 to node.modifiers.count while (edit_poly == undefined) do
        (
            modifier_value = node.modifiers[modifier_index]

            if ((classOf modifier_value == Edit_Poly) and
                ((toUpper modifier_value.name) == requested_name)) then
            (
                edit_poly = modifier_value
            )
        )

        edit_poly
        -- return
    ),

    /*
    Resolves a writable Editable Poly or Edit Poly source without creating duplicates.
    Priority:
    1. Active SLICE HORIZONTAL Edit Poly.
    2. Top SLICE HORIZONTAL Edit Poly.
    3. Any current top Edit Poly.
    4. Existing STRAIGHT EDGE FIXER Edit Poly anywhere in the stack.
    5. Editable Poly base object when no modifiers exist.
    6. Add one STRAIGHT EDGE FIXER Edit Poly only when no reusable source exists.
    */
    function getGeometryAdapter node =
    (
        adapter = undefined
        active_edit_poly = getActiveEditPoly node
        top_edit_poly = getTopEditPoly node
        slice_horizontal = findNamedEditPoly node "SLICE HORIZONTAL"
        existing_fixer = findNamedEditPoly node "STRAIGHT EDGE FIXER"

        if ((active_edit_poly != undefined) and
            ((toUpper active_edit_poly.name) == "SLICE HORIZONTAL")) then
        (
            adapter = #(#edit_poly, active_edit_poly, false)
        )
        else if ((top_edit_poly != undefined) and
                 ((toUpper top_edit_poly.name) == "SLICE HORIZONTAL")) then
        (
            adapter = #(#edit_poly, top_edit_poly, false)
        )
        else if (top_edit_poly != undefined) then
        (
            adapter = #(#edit_poly, top_edit_poly, false)
        )
        else if (existing_fixer != undefined) then
        (
            adapter = #(#edit_poly, existing_fixer, false)
        )
        else if ((node.modifiers.count == 0) and (classOf node.baseObject == Editable_Poly)) then
        (
            adapter = #(#editable_poly, node.baseObject, false)
        )
        else
        (
            new_edit_poly = Edit_Poly()
            new_edit_poly.name = "STRAIGHT EDGE FIXER"
            addModifier node new_edit_poly
            adapter = #(#edit_poly, new_edit_poly, true)
        )

        adapter
        -- return
    ),

    /*
    Returns the number of edges exposed by the current geometry adapter.
    Supports Editable Poly and Edit Poly.
    */
    function getEdgeCount node adapter =
    (
        edge_count = 0

        if (adapter[1] == #editable_poly) then
        (
            edge_count = polyop.getNumEdges (adapter[2])
        )
        else if (adapter[1] == #edit_poly) then
        (
            edge_count = EditPolyMod.GetNumEdges (adapter[2]) node:node
        )

        edge_count
        -- return
    ),

    /*
    Returns the two vertex IDs used by one edge.
    Supports Editable Poly and Edit Poly.
    */
    function getEdgeVertIds node adapter edge_id =
    (
        edge_verts = #()

        if (adapter[1] == #editable_poly) then
        (
            edge_verts = polyop.getEdgeVerts (adapter[2]) edge_id
        )
        else if (adapter[1] == #edit_poly) then
        (
            vert_a = EditPolyMod.GetEdgeVertex (adapter[2]) edge_id 1 node:node
            vert_b = EditPolyMod.GetEdgeVertex (adapter[2]) edge_id 2 node:node
            edge_verts = #(vert_a, vert_b)
        )

        edge_verts
        -- return
    ),


    /*
    Returns true only when the current poly edge is visible.
    Invisible triangulation edges are ignored by direction checks and edge-level analysis.
    */
    function isEdgeVisible node adapter edge_id =
    (
        result_value = false

        try
        (
            if (adapter[1] == #editable_poly) then
            (
                result_value = polyop.getEdgeVis (adapter[2]) edge_id
            )
            else if (adapter[1] == #edit_poly) then
            (
                result_value = polyop.getEdgeVis node edge_id
            )
        )
        catch
        (
            /*
            Fallback for a top Edit Poly over an Editable Poly base object.
            Use this only when the evaluated-node query is unavailable.
            */
            try
            (
                if ((classOf node.baseObject == Editable_Poly) and (edge_id <= polyop.getNumEdges node.baseObject)) then
                (
                    result_value = polyop.getEdgeVis node.baseObject edge_id
                )
                else
                (
                    result_value = false
                )
            )
            catch
            (
                result_value = false
            )
        )

        result_value
        -- return
    ),

    /*
    Returns one vertex position in object-local coordinates.
    Supports Editable Poly and Edit Poly.
    */
    function getVertexPosition node adapter vert_id =
    (
        vertex_position = [0,0,0]

        if (adapter[1] == #editable_poly) then
        (
            vertex_position = polyop.getVert (adapter[2]) vert_id
        )
        else if (adapter[1] == #edit_poly) then
        (
            vertex_position = EditPolyMod.GetVertex (adapter[2]) vert_id node:node
        )

        vertex_position
        -- return
    ),

    /*
    Returns one vertex position in world coordinates.
    The node object transform is applied to the current geometry position.
    */
    function getVertexWorldPosition node adapter vert_id =
    (
        local_position = getVertexPosition node adapter vert_id
        world_position = local_position * node.objectTransform

        world_position
        -- return
    ),


    /*
    Returns true when one visible poly edge is an open border edge.
    Border topology is read from the current Editable Poly or evaluated Edit Poly result.
    */
    function isBorderEdge node adapter edge_id =
    (
        result_value = false

        if (isEdgeVisible node adapter edge_id) then
        (
            try
            (
                if (adapter[1] == #editable_poly) then
                (
                    edge_faces = polyop.getFacesUsingEdge (adapter[2]) edge_id
                )
                else
                (
                    edge_faces = polyop.getFacesUsingEdge node edge_id
                )

                result_value = (edge_faces.numberSet == 1)
            )
            catch
            (
                result_value = false
            )
        )

        result_value
        -- return
    ),

    /*
    Collects all visible open border edges.
    Invisible triangulation edges never participate in Border Check.
    */
    function getVisibleBorderEdges node adapter =
    (
        border_edges = #{}
        edge_count = getEdgeCount node adapter

        for edge_id = 1 to edge_count do
        (
            if (isBorderEdge node adapter edge_id) then
            (
                border_edges[edge_id] = true
            )
        )

        border_edges
        -- return
    ),

    /*
    Returns true when two local XY coordinates match inside tolerance.
    Local Z is intentionally ignored because it represents wall height.
    */
    function localXYMatches point_a point_b tolerance =
    (
        ((abs (point_a.x - point_b.x)) <= tolerance) and
        ((abs (point_a.y - point_b.y)) <= tolerance)
        -- return
    ),

    /*
    Returns true when one border edge follows one local XY column.
    Both endpoints must share the same local X and Y inside tolerance.
    */
    function isLocalVerticalBorderEdge node adapter edge_id tolerance =
    (
        result_value = false
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            point_a = getVertexPosition node adapter edge_verts[1]
            point_b = getVertexPosition node adapter edge_verts[2]
            result_value = localXYMatches point_a point_b tolerance
        )

        result_value
        -- return
    ),

    /*
    Tests whether two one-dimensional Z intervals overlap or touch.
    Tolerance allows tiny coordinate errors around the shared height.
    */
    function zRangesOverlapOrTouch min_a max_a min_b max_b tolerance =
    (
        ((max_a + tolerance) >= min_b) and ((max_b + tolerance) >= min_a)
        -- return
    ),

    /*
    Returns true when two border edges are separate IDs on the same local XY column
    and their local Z ranges overlap or touch without sharing a welded vertex.
    */
    function borderEdgesFormUnweldedColumn node adapter edge_a edge_b tolerance =
    (
        result_value = false
        edge_a_verts = getEdgeVertIds node adapter edge_a
        edge_b_verts = getEdgeVertIds node adapter edge_b

        if ((edge_a_verts.count == 2) and (edge_b_verts.count == 2)) then
        (
            shared_vertex =
                (edge_a_verts[1] == edge_b_verts[1]) or
                (edge_a_verts[1] == edge_b_verts[2]) or
                (edge_a_verts[2] == edge_b_verts[1]) or
                (edge_a_verts[2] == edge_b_verts[2])

            if (not shared_vertex) then
            (
                if ((isLocalVerticalBorderEdge node adapter edge_a tolerance) and
                    (isLocalVerticalBorderEdge node adapter edge_b tolerance)) then
                (
                    edge_a_point = getVertexPosition node adapter edge_a_verts[1]
                    edge_b_point = getVertexPosition node adapter edge_b_verts[1]

                    if (localXYMatches edge_a_point edge_b_point tolerance) then
                    (
                        edge_a_point_2 = getVertexPosition node adapter edge_a_verts[2]
                        edge_b_point_2 = getVertexPosition node adapter edge_b_verts[2]

                        min_a = amin edge_a_point.z edge_a_point_2.z
                        max_a = amax edge_a_point.z edge_a_point_2.z
                        min_b = amin edge_b_point.z edge_b_point_2.z
                        max_b = amax edge_b_point.z edge_b_point_2.z

                        result_value = zRangesOverlapOrTouch min_a max_a min_b max_b tolerance
                    )
                )
            )
        )

        result_value
        -- return
    ),

    /*
    Finds visible border edges that look like an unwelded vertical seam.
    Both members of every matching edge pair are selected.
    */
    function findUnweldedBorderEdges node adapter border_edges tolerance =
    (
        invalid_edges = #{}
        border_edge_array = for edge_id in border_edges collect edge_id

        if (border_edge_array.count > 1) then
        (
            for edge_index_a = 1 to (border_edge_array.count - 1) do
            (
                edge_a = border_edge_array[edge_index_a]

                for edge_index_b = (edge_index_a + 1) to border_edge_array.count do
                (
                    edge_b = border_edge_array[edge_index_b]

                    if (borderEdgesFormUnweldedColumn node adapter edge_a edge_b tolerance) then
                    (
                        invalid_edges[edge_a] = true
                        invalid_edges[edge_b] = true
                    )
                )
            )
        )

        invalid_edges
        -- return
    ),

    /*
    Returns all visible border edges using one vertex.
    Used to walk ordered border loops.
    */
    function getBorderEdgesAtVertex node adapter border_edges vert_id =
    (
        result_edges = #()

        for edge_id in border_edges do
        (
            edge_verts = getEdgeVertIds node adapter edge_id

            if (edge_verts.count == 2) then
            (
                if ((edge_verts[1] == vert_id) or (edge_verts[2] == vert_id)) then
                (
                    append result_edges edge_id
                )
            )
        )

        result_edges
        -- return
    ),

    /*
    Returns the opposite vertex of an edge.
    Zero is returned when the supplied vertex is not part of that edge.
    */
    function getOtherEdgeVertex node adapter edge_id vert_id =
    (
        other_vert = 0
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            if (edge_verts[1] == vert_id) then
            (
                other_vert = edge_verts[2]
            )
            else if (edge_verts[2] == vert_id) then
            (
                other_vert = edge_verts[1]
            )
        )

        other_vert
        -- return
    ),

    /*
    Walks one visible border chain from a seed edge.
    Returns #(ordered_vertices, ordered_edges, is_closed).
    */
    function traceBorderLoop node adapter border_edges seed_edge =
    (
        ordered_vertices = #()
        ordered_edges = #()
        closed_loop = false
        seed_verts = getEdgeVertIds node adapter seed_edge

        if (seed_verts.count == 2) then
        (
            start_vert = seed_verts[1]
            current_vert = seed_verts[2]
            current_edge = seed_edge

            append ordered_vertices start_vert
            append ordered_vertices current_vert
            append ordered_edges current_edge

            continue_walk = true
            safety_count = 0
            max_steps = border_edges.numberSet + 2

            while (continue_walk and (safety_count < max_steps)) do
            (
                safety_count += 1
                incident_edges = getBorderEdgesAtVertex node adapter border_edges current_vert
                next_edge = 0

                for candidate_edge in incident_edges while (next_edge == 0) do
                (
                    if (candidate_edge != current_edge) then
                    (
                        next_edge = candidate_edge
                    )
                )

                if (next_edge == 0) then
                (
                    continue_walk = false
                )
                else
                (
                    next_vert = getOtherEdgeVertex node adapter next_edge current_vert

                    if (next_vert == 0) then
                    (
                        continue_walk = false
                    )
                    else if (next_vert == start_vert) then
                    (
                        append ordered_edges next_edge
                        closed_loop = true
                        continue_walk = false
                    )
                    else if ((findItem ordered_vertices next_vert) > 0) then
                    (
                        continue_walk = false
                    )
                    else
                    (
                        append ordered_edges next_edge
                        append ordered_vertices next_vert
                        current_edge = next_edge
                        current_vert = next_vert
                    )
                )
            )
        )

        #(ordered_vertices, ordered_edges, closed_loop)
        -- return
    ),

    /*
    Calculates a Newell normal from an ordered local-space border loop.
    The normal is used only to distinguish convex and reflex turns.
    */
    function getBorderLoopNormal node adapter ordered_vertices =
    (
        normal_value = [0,0,0]
        vert_count = ordered_vertices.count

        if (vert_count >= 3) then
        (
            for vert_index = 1 to vert_count do
            (
                next_index = if (vert_index == vert_count) then 1 else (vert_index + 1)
                point_a = getVertexPosition node adapter ordered_vertices[vert_index]
                point_b = getVertexPosition node adapter ordered_vertices[next_index]

                normal_value.x += (point_a.y - point_b.y) * (point_a.z + point_b.z)
                normal_value.y += (point_a.z - point_b.z) * (point_a.x + point_b.x)
                normal_value.z += (point_a.x - point_b.x) * (point_a.y + point_b.y)
            )
        )

        if ((length normal_value) > 0.0000001) then
        (
            normal_value = normalize normal_value
        )

        normal_value
        -- return
    ),

    /*
    Finds border edges touching reflex border corners with interior angle above 180 degrees.
    Only closed visible border loops with an unambiguous two-edge border chain are tested.
    */
    function findReflexBorderEdges node adapter border_edges =
    (
        invalid_edges = #{}
        remaining_edges = copy border_edges

        while (remaining_edges.numberSet > 0) do
        (
            seed_edge = 0

            for edge_id in remaining_edges while (seed_edge == 0) do
            (
                seed_edge = edge_id
            )

            if (seed_edge > 0) then
            (
                loop_data = traceBorderLoop node adapter border_edges seed_edge
                ordered_vertices = loop_data[1]
                ordered_edges = loop_data[2]
                closed_loop = loop_data[3]

                for walked_edge in ordered_edges do
                (
                    remaining_edges[walked_edge] = false
                )

                if (closed_loop and (ordered_vertices.count >= 3) and
                    (ordered_edges.count == ordered_vertices.count)) then
                (
                    loop_normal = getBorderLoopNormal node adapter ordered_vertices

                    if ((length loop_normal) > 0.0000001) then
                    (
                        vert_count = ordered_vertices.count

                        for vert_index = 1 to vert_count do
                        (
                            previous_index = if (vert_index == 1) then vert_count else (vert_index - 1)
                            next_index = if (vert_index == vert_count) then 1 else (vert_index + 1)

                            previous_point = getVertexPosition node adapter ordered_vertices[previous_index]
                            current_point = getVertexPosition node adapter ordered_vertices[vert_index]
                            next_point = getVertexPosition node adapter ordered_vertices[next_index]

                            vector_to_previous = previous_point - current_point
                            vector_to_next = next_point - current_point

                            previous_length = length vector_to_previous
                            next_length = length vector_to_next

                            if ((previous_length > 0.0000001) and
                                (next_length > 0.0000001)) then
                            (
                                previous_direction = vector_to_previous / previous_length
                                next_direction = vector_to_next / next_length
                                direction_dot = dot previous_direction next_direction
                                direction_dot = amax -1.0 (amin 1.0 direction_dot)

                                turn_cross = cross vector_to_previous vector_to_next
                                signed_turn = dot turn_cross loop_normal

                                /*
                                Standard reflex corner:
                                With Newell normal built from the same loop order,
                                negative = convex turn and positive = reflex turn.
                                */
                                is_reflex_corner = (signed_turn > 0.0000001)

                                /*
                                360-degree backtrack:
                                Both neighboring vertices lie in almost the same direction
                                from the current border vertex. The border walks out and back
                                on itself. The two remote vertices do NOT need to share position.
                                */
                                is_backtrack_360 = (direction_dot >= 0.9999)

                                if (is_reflex_corner or is_backtrack_360) then
                                (
                                    previous_edge_index = if (vert_index == 1) then ordered_edges.count else (vert_index - 1)
                                    next_edge_index = vert_index

                                    invalid_edges[ordered_edges[previous_edge_index]] = true
                                    invalid_edges[ordered_edges[next_edge_index]] = true
                                )
                            )
                        )
                    )
                )
            )
        )

        invalid_edges
        -- return
    ),

    /*
    Checks visible open borders for unwelded local-Z seams and reflex corners.
    The resulting invalid border edges are selected in Edge sub-object mode.
    */
    function checkBorders tolerance =
    (
        selected_nodes = selection as array
        total_invalid_edges = 0
        total_unwelded_edges = 0
        total_reflex_edges = 0
        processed_count = 0

        if (selected_nodes.count == 0) then
        (
            messageBox "Select at least one geometry object." title:"Straight Edge Fixer"
        )
        else
        (
            for node in selected_nodes do
            (
                if (isValidNode node and (superClassOf node == GeometryClass)) then
                (
                    processed_count += 1
                    adapter = getGeometryAdapter node
                    border_edges = getVisibleBorderEdges node adapter
                    unwelded_edges = findUnweldedBorderEdges node adapter border_edges tolerance
                    reflex_edges = findReflexBorderEdges node adapter border_edges
                    invalid_edges = copy unwelded_edges
                    invalid_edges += reflex_edges

                    setEdgeSelection node adapter invalid_edges

                    total_unwelded_edges += countBits unwelded_edges
                    total_reflex_edges += countBits reflex_edges
                    total_invalid_edges += countBits invalid_edges
                )
            )

            if (processed_count > 0) then
            (
                setCommandPanelTaskMode mode:#modify
                subObjectLevel = 2
                completeRedraw()

                format "Border Check: selected % invalid border edge(s). Unwelded/overlapping: %, reflex >180 deg: %.\n" total_invalid_edges total_unwelded_edges total_reflex_edges
            )
        )

        total_invalid_edges
        -- return
    ),

    /*
    Returns true when an edge is horizontal within tolerance.
    Horizontal means endpoint world-Z difference does not exceed tolerance.
    */
    function isHorizontalEdge node adapter edge_id tolerance =
    (
        result_value = false
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            point_a = getVertexWorldPosition node adapter edge_verts[1]
            point_b = getVertexWorldPosition node adapter edge_verts[2]
            result_value = ((abs (point_a.z - point_b.z)) <= tolerance)
        )

        result_value
        -- return
    ),

    /*
    Returns true when an edge is vertical within tolerance.
    Vertical means endpoint world-X and world-Y differences are within tolerance.
    */
    function isVerticalEdge node adapter edge_id tolerance =
    (
        result_value = false
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            point_a = getVertexWorldPosition node adapter edge_verts[1]
            point_b = getVertexWorldPosition node adapter edge_verts[2]

            result_value =
                ((abs (point_a.x - point_b.x)) <= tolerance) and
                ((abs (point_a.y - point_b.y)) <= tolerance)
        )

        result_value
        -- return
    ),


    /*
    Returns horizontal/vertical direction angles from edge component lengths.
    The result is #(angle_from_horizontal, angle_from_vertical) in degrees.
    */
    function getDirectionAngles horizontal_length vertical_length =
    (
        result_value = #(undefined, undefined)
        edge_length = sqrt ((horizontal_length * horizontal_length) + (vertical_length * vertical_length))

        if (edge_length > 0.0000001) then
        (
            vertical_ratio = vertical_length / edge_length
            vertical_ratio = amin 1.0 (amax 0.0 vertical_ratio)

            angle_from_vertical = acos vertical_ratio
            angle_from_horizontal = 90.0 - angle_from_vertical

            result_value = #(angle_from_horizontal, angle_from_vertical)
        )

        result_value
        -- return
    ),


    /*
    Returns the edge angle from the horizontal world plane in degrees.
    Zero degrees is horizontal and ninety degrees is vertical.
    */
    function getEdgeAngleFromHorizontal node adapter edge_id =
    (
        angle_value = undefined
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            point_a = getVertexWorldPosition node adapter edge_verts[1]
            point_b = getVertexWorldPosition node adapter edge_verts[2]
            edge_vector = point_b - point_a
            horizontal_length = sqrt ((edge_vector.x * edge_vector.x) + (edge_vector.y * edge_vector.y))
            vertical_length = abs edge_vector.z
            direction_angles = getDirectionAngles horizontal_length vertical_length

            angle_value = direction_angles[1]
        )

        angle_value
        -- return
    ),

    /*
    Returns true when an edge is skewed from the target but remains inside Angle.
    Exact zero-degree edges are excluded; the threshold boundary is included.
    */
    function isDirectionAngleSkewed angle_from_target angle_threshold =
    (
        result_value = false

        if (angle_from_target != undefined) then
        (
            result_value = ((angle_from_target > 0.0) and (angle_from_target <= angle_threshold))
        )

        result_value
        -- return
    ),

    /*
    Returns true when an edge is within the configured angle from horizontal.
    At 5 degrees only edges from 0 through 5 degrees from horizontal qualify.
    */
    function isHorizontalCheckCandidate node adapter edge_id tolerance angle_threshold =
    (
        result_value = false
        angle_from_horizontal = getEdgeAngleFromHorizontal node adapter edge_id

        if (angle_from_horizontal != undefined) then
        (
            result_value = isDirectionAngleSkewed angle_from_horizontal angle_threshold
        )

        result_value
        -- return
    ),

    /*
    Returns true when an edge is within the configured angle from vertical.
    At 5 degrees only edges from 0 through 5 degrees from vertical qualify.
    */
    function isVerticalCheckCandidate node adapter edge_id tolerance angle_threshold =
    (
        result_value = false
        angle_from_horizontal = getEdgeAngleFromHorizontal node adapter edge_id

        if (angle_from_horizontal != undefined) then
        (
            angle_from_vertical = 90.0 - angle_from_horizontal
            result_value = isDirectionAngleSkewed angle_from_vertical angle_threshold
        )

        result_value
        -- return
    ),

    /*
    Tests strict-zero versus skewed direction selection boundaries.
    RMB accepts only angles greater than zero and up to Angle inclusive.
    */
    function testDirectionAngleThreshold =
    (
        test_passed = true

        test_passed = test_passed and (not (isDirectionAngleSkewed 0.0 5.0))
        test_passed = test_passed and (isDirectionAngleSkewed 0.001 5.0)
        test_passed = test_passed and (isDirectionAngleSkewed 5.0 5.0)
        test_passed = test_passed and (not (isDirectionAngleSkewed 5.001 5.0))
        test_passed = test_passed and (not (isDirectionAngleSkewed 90.0 5.0))

        vertical_test_angles = getDirectionAngles 0.0466476 1.0
        horizontal_test_angles = getDirectionAngles 1.0 0.0466476

        test_passed = test_passed and ((abs (vertical_test_angles[2] - 2.6704)) < 0.01)
        test_passed = test_passed and (isDirectionAngleSkewed vertical_test_angles[2] 40.0)
        test_passed = test_passed and ((abs (horizontal_test_angles[1] - 2.6704)) < 0.01)
        test_passed = test_passed and (isDirectionAngleSkewed horizontal_test_angles[1] 40.0)

        test_passed
        -- return
    ),


    /*
    Selects an edge BitArray on the current geometry source.
    The tool switches the modifier or object to Edge sub-object level.
    */
    function setEdgeSelection node adapter edge_selection =
    (
        geometry_source = adapter[2]

        if (adapter[1] == #editable_poly) then
        (
            polyop.setEdgeSelection geometry_source edge_selection
        )
        else if (adapter[1] == #edit_poly) then
        (
            EditPolyMod.SetEPolySelLevel geometry_source #Edge
            EditPolyMod.SetSelection geometry_source #Edge edge_selection node:node
        )

        true
        -- return
    ),


    /*
    Returns the current edge selection from Editable Poly or Edit Poly.
    Used by RMB straightening, which works on selected edges only.
    */
    function getEdgeSelection node adapter =
    (
        edge_selection = #{}
        geometry_source = adapter[2]

        if (adapter[1] == #editable_poly) then
        (
            edge_selection = polyop.getEdgeSelection geometry_source
        )
        else if (adapter[1] == #edit_poly) then
        (
            edge_selection = EditPolyMod.GetSelection geometry_source #Edge node:node
        )

        edge_selection
        -- return
    ),

    /*
    Returns the current vertex selection from Editable Poly or Edit Poly.
    */
    function getVertexSelection node adapter =
    (
        vertex_selection = #{}
        geometry_source = adapter[2]

        if (adapter[1] == #editable_poly) then
        (
            vertex_selection = polyop.getVertSelection geometry_source
        )
        else if (adapter[1] == #edit_poly) then
        (
            vertex_selection = EditPolyMod.GetSelection geometry_source #Vertex node:node
        )

        vertex_selection
        -- return
    ),

    /*
    Returns all edges incident to one vertex.
    */
    function getVertexIncidentEdges node adapter vertex_id =
    (
        incident_edges = #{}
        geometry_source = adapter[2]

        if (adapter[1] == #editable_poly) then
        (
            incident_edges = polyop.getEdgesUsingVert geometry_source #{vertex_id}
        )
        else if (adapter[1] == #edit_poly) then
        (
            edge_count = EditPolyMod.GetVertexEdgeCount geometry_source vertex_id node:node

            for edge_slot = 1 to edge_count do
            (
                edge_id = EditPolyMod.GetVertexEdge geometry_source vertex_id edge_slot node:node
                if (edge_id != undefined and edge_id > 0) then incident_edges[edge_id] = true
            )
        )

        incident_edges
        -- return
    ),

    /*
    Sets vertex selection on Editable Poly or Edit Poly.
    Used to expose vertices from edges which cannot be straightened.
    */
    function setVertexSelection node adapter vertex_selection =
    (
        geometry_source = adapter[2]

        if (adapter[1] == #editable_poly) then
        (
            polyop.setVertSelection geometry_source vertex_selection
        )
        else if (adapter[1] == #edit_poly) then
        (
            EditPolyMod.SetEPolySelLevel geometry_source #Vertex
            EditPolyMod.SetSelection geometry_source #Vertex vertex_selection node:node
        )

        true
        -- return
    ),

    /*
    Returns the world-space center of one edge.
    Undefined is returned when the edge does not contain two valid vertices.
    */
    function getEdgeCenterWorld node adapter edge_id =
    (
        center_position = undefined
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            point_a = getVertexWorldPosition node adapter edge_verts[1]
            point_b = getVertexWorldPosition node adapter edge_verts[2]
            center_position = (point_a + point_b) * 0.5
        )

        center_position
        -- return
    ),

    /*
    Returns a normalized world-space edge direction.
    Undefined is returned for a zero-length edge.
    */
    function getEdgeDirectionWorld node adapter edge_id =
    (
        direction_value = undefined
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            point_a = getVertexWorldPosition node adapter edge_verts[1]
            point_b = getVertexWorldPosition node adapter edge_verts[2]
            edge_vector = point_b - point_a

            if ((length edge_vector) > 0.0000001) then
            (
                direction_value = normalize edge_vector
            )
        )

        direction_value
        -- return
    ),

    /*
    Returns face IDs using one edge on the current geometry source.
    Editable Poly reads the base object; Edit Poly reads the evaluated node.
    */
    function getEdgeFaceIds node adapter edge_id =
    (
        face_ids = #{}

        try
        (
            if (adapter[1] == #editable_poly) then
            (
                face_ids = polyop.getFacesUsingEdge (adapter[2]) edge_id
            )
            else if (adapter[1] == #edit_poly) then
            (
                face_ids = polyop.getFacesUsingEdge node edge_id
            )
        )
        catch
        (
            face_ids = #{}
        )

        face_ids
        -- return
    ),


    /*
    Returns ordered vertex IDs for one face on the current geometry source.
    Unavailable topology returns an empty array.
    */
    function getFaceVertIds node adapter face_id =
    (
        face_verts = #()

        try
        (
            if (adapter[1] == #editable_poly) then
            (
                face_verts = polyop.getFaceVerts (adapter[2]) face_id
            )
            else if (adapter[1] == #edit_poly) then
            (
                face_verts = polyop.getFaceVerts node face_id
            )
        )
        catch
        (
            face_verts = #()
        )

        face_verts
        -- return
    ),


    /*
    Builds one face normal directly from world-space face vertices.
    World-space construction preserves rotated wall orientation.
    */
    function getFaceNormalWorld node adapter face_id =
    (
        normal_value = undefined
        face_verts = getFaceVertIds node adapter face_id

        if (face_verts.count >= 3) then
        (
            point_a = getVertexWorldPosition node adapter face_verts[1]

            for vert_index = 2 to (face_verts.count - 1) while (normal_value == undefined) do
            (
                point_b = getVertexWorldPosition node adapter face_verts[vert_index]
                point_c = getVertexWorldPosition node adapter face_verts[vert_index + 1]
                candidate_normal = cross (point_b - point_a) (point_c - point_a)

                if ((length candidate_normal) > 0.0000001) then
                (
                    normal_value = normalize candidate_normal
                )
            )
        )

        normal_value
        -- return
    ),


    /*
    Returns a horizontal tangent perpendicular to one face normal.
    The sign follows the current edge direction to preserve vertex order.
    */
    function getHorizontalDirectionFromFaceNormal face_normal current_direction =
    (
        tangent_direction = undefined

        if ((face_normal != undefined) and (current_direction != undefined)) then
        (
            horizontal_normal = [face_normal.x, face_normal.y, 0.0]

            if ((length horizontal_normal) > 0.0000001) then
            (
                horizontal_normal = normalize horizontal_normal
                tangent_direction = normalize (cross horizontal_normal [0,0,1])

                if ((dot tangent_direction current_direction) < 0.0) then
                (
                    tangent_direction = -tangent_direction
                )
            )
        )

        tangent_direction
        -- return
    ),


    /*
    Finds the adjacent wall-face tangent best aligned with the selected edge.
    If no usable wall face exists, the current XY edge direction is retained.
    */
    function getHorizontalWallDirection node adapter edge_id =
    (
        result_direction = undefined
        edge_direction = getEdgeDirectionWorld node adapter edge_id

        if (edge_direction != undefined) then
        (
            current_xy = [edge_direction.x, edge_direction.y, 0.0]

            if ((length current_xy) > 0.0000001) then
            (
                current_xy = normalize current_xy
                best_alignment = -1.0
                edge_faces = getEdgeFaceIds node adapter edge_id

                for face_id in edge_faces do
                (
                    face_normal = getFaceNormalWorld node adapter face_id
                    tangent_direction = getHorizontalDirectionFromFaceNormal face_normal current_xy

                    if (tangent_direction != undefined) then
                    (
                        alignment = abs (dot tangent_direction current_xy)

                        if (alignment > best_alignment) then
                        (
                            best_alignment = alignment
                            result_direction = tangent_direction
                        )
                    )
                )

                if (result_direction == undefined) then
                (
                    result_direction = current_xy
                )
            )
        )

        result_direction
        -- return
    ),


    /*
    Verifies rotated-wall horizontal tangent construction without scene geometry.
    The tangent must be horizontal and perpendicular to the wall face normal.
    */
    function testHorizontalFaceDirection =
    (
        face_normal = normalize [0.6, 0.8, 0.0]
        current_direction = normalize [0.8, -0.6, 0.0]
        tangent_direction = getHorizontalDirectionFromFaceNormal face_normal current_direction

        test_passed = (
            (tangent_direction != undefined) and
            ((abs tangent_direction.z) < 0.000001) and
            ((abs (dot tangent_direction face_normal)) < 0.000001) and
            ((dot tangent_direction current_direction) > 0.9999)
        )

        test_passed
        -- return
    ),


    /*
    Returns the unsigned parallel angle between two edges in degrees.
    Opposite directions are treated as the same baseline direction.
    */
    function getParallelAngle node adapter edge_a edge_b =
    (
        angle_value = 180.0
        direction_a = getEdgeDirectionWorld node adapter edge_a
        direction_b = getEdgeDirectionWorld node adapter edge_b

        if ((direction_a != undefined) and (direction_b != undefined)) then
        (
            dot_value = abs (dot direction_a direction_b)
            dot_value = amax 0.0 (amin 1.0 dot_value)
            angle_value = acos dot_value
        )

        angle_value
        -- return
    ),

    /*
    Returns a common vertex ID shared by two edges.
    Zero means the edges are not direct neighbors.
    */
    function getSharedVertexId node adapter edge_a edge_b =
    (
        shared_vertex = 0
        edge_a_verts = getEdgeVertIds node adapter edge_a
        edge_b_verts = getEdgeVertIds node adapter edge_b

        if ((edge_a_verts.count == 2) and (edge_b_verts.count == 2)) then
        (
            if ((edge_a_verts[1] == edge_b_verts[1]) or (edge_a_verts[1] == edge_b_verts[2])) then
            (
                shared_vertex = edge_a_verts[1]
            )
            else if ((edge_a_verts[2] == edge_b_verts[1]) or (edge_a_verts[2] == edge_b_verts[2])) then
            (
                shared_vertex = edge_a_verts[2]
            )
        )

        shared_vertex
        -- return
    ),

    /*
    Returns true when an edge is already a valid straight reference for the requested mode.
    Only visible edges can become references.
    */
    function isStraightReferenceEdge node adapter edge_id check_type tolerance =
    (
        result_value = false

        if (isEdgeVisible node adapter edge_id) then
        (
            if (check_type == #horizontal) then
            (
                result_value = isHorizontalEdge node adapter edge_id tolerance
            )
            else if (check_type == #vertical) then
            (
                result_value = isVerticalEdge node adapter edge_id tolerance
            )
        )

        result_value
        -- return
    ),

    /*
    Finds the best visible straight edge directly neighboring the bad edge.
    Candidate reference direction must be within Angle of the selected bad edge.
    Returns #(reference_edge_id, shared_vertex_id, #neighbor) or undefined.
    */
    function findNeighborReference node adapter target_edge check_type tolerance angle_threshold =
    (
        best_reference = undefined
        best_angle = 1.0e30
        edge_count = getEdgeCount node adapter

        for reference_edge = 1 to edge_count do
        (
            if ((reference_edge != target_edge) and (isStraightReferenceEdge node adapter reference_edge check_type tolerance)) then
            (
                shared_vertex = getSharedVertexId node adapter target_edge reference_edge

                if (shared_vertex > 0) then
                (
                    parallel_angle = getParallelAngle node adapter target_edge reference_edge

                    if ((parallel_angle <= angle_threshold) and (parallel_angle < best_angle)) then
                    (
                        best_angle = parallel_angle
                        best_reference = #(reference_edge, shared_vertex, #neighbor)
                    )
                )
            )
        )

        best_reference
        -- return
    ),

    /*
    Finds the nearest visible straight reference on the same Z level.
    Search in Z defines how far the target edge center may be from the reference level.
    Returns #(reference_edge_id, 0, #level) or undefined.
    */
    function findSameLevelReference node adapter target_edge check_type tolerance angle_threshold search_in_z =
    (
        best_reference = undefined
        best_distance = 1.0e30
        target_center = getEdgeCenterWorld node adapter target_edge
        edge_count = getEdgeCount node adapter

        if (target_center != undefined) then
        (
            for reference_edge = 1 to edge_count do
            (
                if ((reference_edge != target_edge) and (isStraightReferenceEdge node adapter reference_edge check_type tolerance)) then
                (
                    reference_center = getEdgeCenterWorld node adapter reference_edge

                    if (reference_center != undefined) then
                    (
                        z_distance = abs (target_center.z - reference_center.z)

                        if (z_distance <= search_in_z) then
                        (
                            parallel_angle = getParallelAngle node adapter target_edge reference_edge

                            if (parallel_angle <= angle_threshold) then
                            (
                                spatial_distance = distance target_center reference_center

                                if (spatial_distance < best_distance) then
                                (
                                    best_distance = spatial_distance
                                    best_reference = #(reference_edge, 0, #level)
                                )
                            )
                        )
                    )
                )
            )
        )

        best_reference
        -- return
    ),

    /*
    Moves one vertex to an exact world-space position.
    Supports Editable Poly and Edit Poly without converting the object.
    */
    function setVertexWorldPosition node adapter vert_id target_world_position =
    (
        result_value = false

        try
        (
            if (adapter[1] == #editable_poly) then
            (
                inverse_tm = inverse node.objectTransform
                target_local_position = target_world_position * inverse_tm
                polyop.setVert (adapter[2]) vert_id target_local_position
                update node
                result_value = true
            )
            else if (adapter[1] == #edit_poly) then
            (
                current_world_position = getVertexWorldPosition node adapter vert_id
                move_delta = target_world_position - current_world_position

                if ((length move_delta) > 0.0000001) then
                (
                    one_vertex = #{}
                    one_vertex[vert_id] = true

                    EditPolyMod.SetEPolySelLevel (adapter[2]) #Vertex
                    EditPolyMod.SetSelection (adapter[2]) #Vertex one_vertex node:node
                    EditPolyMod.MoveSelection (adapter[2]) move_delta
                    EditPolyMod.Commit (adapter[2])
                )

                update node
                result_value = true
            )
        )
        catch
        (
            result_value = false
        )

        result_value
        -- return
    ),

    /*
    Tests Vertical Vertex-mode endpoint alignment.
    The selected vertex takes unselected XY and preserves its own Z.
    */
    function testVerticalSelectedVertexTarget =
    (
        selected_position = [10.0, 20.0, 3.0]
        unselected_position = [30.0, 40.0, 9.0]
        target_position = [unselected_position.x, unselected_position.y, selected_position.z]

        target_position == [30.0, 40.0, 3.0]
        -- return
    ),


    /*
    Tests axis-specific alignment targets.
    Horizontal changes only Z; Vertical changes only XY.
    */
    function testDirectionAlignmentTargets =
    (
        point_a = [10.0, 20.0, 3.0]
        point_b = [14.0, 26.0, 9.0]
        horizontal_reference = [100.0, 200.0, 7.0]
        vertical_reference = [30.0, 40.0, 500.0]

        horizontal_a = [point_a.x, point_a.y, horizontal_reference.z]
        horizontal_b = [point_b.x, point_b.y, horizontal_reference.z]
        vertical_a = [vertical_reference.x, vertical_reference.y, point_a.z]
        vertical_b = [vertical_reference.x, vertical_reference.y, point_b.z]

        test_passed = true
        test_passed = test_passed and horizontal_a.x == point_a.x and horizontal_a.y == point_a.y
        test_passed = test_passed and horizontal_b.x == point_b.x and horizontal_b.y == point_b.y
        test_passed = test_passed and horizontal_a.z == horizontal_reference.z and horizontal_b.z == horizontal_reference.z
        test_passed = test_passed and vertical_a.x == vertical_reference.x and vertical_a.y == vertical_reference.y
        test_passed = test_passed and vertical_b.x == vertical_reference.x and vertical_b.y == vertical_reference.y
        test_passed = test_passed and vertical_a.z == point_a.z and vertical_b.z == point_b.z

        test_passed
        -- return
    ),


    /*
    Fixes one selected edge using the requested alignment axis.
    Horizontal changes Z only and prefers a neighboring horizontal edge Z.
    Vertical changes XY only and prefers a neighboring vertical edge XY.
    */
    function fixSelectedDirectionEdge node adapter edge_id check_type tolerance:0.01 angle_threshold:45.0 =
    (
        result_value = false
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            point_a = getVertexWorldPosition node adapter edge_verts[1]
            point_b = getVertexWorldPosition node adapter edge_verts[2]
            target_a = point_a
            target_b = point_b
            neighbor_reference = findNeighborReference node adapter edge_id check_type tolerance angle_threshold
            can_fix = false

            if (check_type == #horizontal) then
            (
                target_z = (point_a.z + point_b.z) * 0.5

                if (neighbor_reference != undefined) then
                (
                    shared_vertex = neighbor_reference[2]
                    if (shared_vertex > 0) then
                    (
                        reference_position = getVertexWorldPosition node adapter shared_vertex
                        if (reference_position != undefined) then target_z = reference_position.z
                    )
                )

                target_a = [point_a.x, point_a.y, target_z]
                target_b = [point_b.x, point_b.y, target_z]
                can_fix = true
            )
            else if (check_type == #vertical) then
            (
                target_x = (point_a.x + point_b.x) * 0.5
                target_y = (point_a.y + point_b.y) * 0.5

                if (neighbor_reference != undefined) then
                (
                    shared_vertex = neighbor_reference[2]
                    if (shared_vertex > 0) then
                    (
                        reference_position = getVertexWorldPosition node adapter shared_vertex
                        if (reference_position != undefined) then
                        (
                            target_x = reference_position.x
                            target_y = reference_position.y
                        )
                    )
                )

                target_a = [target_x, target_y, point_a.z]
                target_b = [target_x, target_y, point_b.z]
                can_fix = true
            )

            if (can_fix) then
            (
                moved_a = setVertexWorldPosition node adapter edge_verts[1] target_a
                moved_b = setVertexWorldPosition node adapter edge_verts[2] target_b

                if (moved_a and moved_b) then
                (
                    if (check_type == #horizontal) then
                    (
                        result_value = isHorizontalEdge node adapter edge_id tolerance
                    )
                    else if (check_type == #vertical) then
                    (
                        result_value = isVerticalEdge node adapter edge_id tolerance
                    )
                )
            )
        )

        result_value
        -- return
    ),


    /*
    Aligns selected vertices vertically to the unselected endpoint XY of each incident edge.
    Only the selected vertex moves; its Z is preserved.
    */
    function fixSelectedVerticalVertices node adapter selected_vertices tolerance:0.01 angle_threshold:45.0 =
    (
        fixed_count = 0
        failed_vertices = #{}

        for selected_vertex in selected_vertices do
        (
            incident_edges = getVertexIncidentEdges node adapter selected_vertex
            vertex_fixed = false

            for edge_id in incident_edges while not vertex_fixed do
            (
                edge_verts = getEdgeVertIds node adapter edge_id

                if (edge_verts.count == 2) then
                (
                    other_vertex = if (edge_verts[1] == selected_vertex) then edge_verts[2] else edge_verts[1]
                    other_is_selected = (other_vertex <= selected_vertices.count and selected_vertices[other_vertex])

                    if not other_is_selected then
                    (
                        selected_position = getVertexWorldPosition node adapter selected_vertex
                        other_position = getVertexWorldPosition node adapter other_vertex

                        if (selected_position != undefined and other_position != undefined) then
                        (
                            horizontal_length = distance [selected_position.x, selected_position.y, 0.0] [other_position.x, other_position.y, 0.0]
                            vertical_length = abs(selected_position.z - other_position.z)
                            direction_angles = getDirectionAngles horizontal_length vertical_length
                            vertical_angle = direction_angles[2]

                            if (vertical_angle != undefined and vertical_angle < 45.0) then
                            (
                                target_position = [other_position.x, other_position.y, selected_position.z]

                                if (setVertexWorldPosition node adapter selected_vertex target_position) then
                                (
                                    vertex_fixed = true
                                    fixed_count += 1
                                )
                            )
                        )
                    )
                )
            )

            if not vertex_fixed then failed_vertices[selected_vertex] = true
        )

        #(fixed_count, failed_vertices)
        -- return
    ),


    /*
    Fixes every currently selected edge for the requested direction.
    In Vertex sub-object mode, Vertical moves selected vertices to the unselected endpoint XY.
    */
    function fixSelectedDirectionEdges check_type tolerance:0.01 angle_threshold:45.0 =
    (
        selected_nodes = selection as array
        object_results = #()
        total_fixed_edges = 0
        has_failed_edges = false
        failure_report = ""
        use_vertex_vertical_mode = (check_type == #vertical and subObjectLevel == 1)

        if (selected_nodes.count == 0) then
        (
            messageBox "Select at least one geometry object." title:"Straight Edge Fixer"
        )
        else
        (
            undo "Fix Selected Direction Edges" on
            (
                for node in selected_nodes do
                (
                    if (isValidNode node and (superClassOf node == GeometryClass)) then
                    (
                        adapter = getGeometryAdapter node
                        original_edge_selection = getEdgeSelection node adapter
                        failed_vertices = #{}

                        if use_vertex_vertical_mode then
                        (
                            original_vertex_selection = getVertexSelection node adapter
                            vertex_result = fixSelectedVerticalVertices                                 node                                 adapter                                 original_vertex_selection                                 tolerance:tolerance                                 angle_threshold:angle_threshold

                            total_fixed_edges += vertex_result[1]
                            failed_vertices = vertex_result[2]
                        )
                        else
                        (
                            for edge_id in original_edge_selection do
                            (
                                if (fixSelectedDirectionEdge node adapter edge_id check_type tolerance:tolerance angle_threshold:angle_threshold) then
                                (
                                    total_fixed_edges += 1
                                )
                                else
                                (
                                    failed_edge_verts = getEdgeVertIds node adapter edge_id

                                    if (failed_edge_verts.count == 2) then
                                    (
                                        failed_vertices[failed_edge_verts[1]] = true
                                        failed_vertices[failed_edge_verts[2]] = true
                                    )
                                )
                            )
                        )

                        if (failed_vertices.numberSet > 0) then
                        (
                            has_failed_edges = true
                            failure_report += node.name + ": " + (bitIdsToString failed_vertices) + "\n"
                        )

                        append object_results #(node, adapter, original_edge_selection, failed_vertices)
                    )
                )
            )

            if (has_failed_edges) then
            (
                for object_result in object_results do
                (
                    setVertexSelection object_result[1] object_result[2] object_result[4]
                )

                setCommandPanelTaskMode mode:#modify
                subObjectLevel = 1
                completeRedraw()

                messageBox ("Unable to fix selected edges with vertices:\n\n" + failure_report) title:"Straight Edge Fixer"
            )
            else
            (
                for object_result in object_results do
                (
                    setEdgeSelection object_result[1] object_result[2] object_result[3]
                )

                setCommandPanelTaskMode mode:#modify
                subObjectLevel = 2
                completeRedraw()

                format "Straight Edge Fixer: fixed % selected % edge(s).\n" total_fixed_edges check_type
            )
        )

        #(total_fixed_edges, has_failed_edges)
        -- return
    ),


    /*
    Straightens one selected edge using only the coordinate controlled by the requested direction.
    Horizontal uses reference Z while preserving target XY.
    Vertical uses reference XY while preserving target Z.
    */
    function straightenEdgeUsingReference node adapter target_edge reference_data check_type tolerance =
    (
        result_value = false
        target_verts = getEdgeVertIds node adapter target_edge
        reference_edge = reference_data[1]
        shared_vertex = reference_data[2]
        reference_method = reference_data[3]

        if (target_verts.count == 2) then
        (
            point_a = getVertexWorldPosition node adapter target_verts[1]
            point_b = getVertexWorldPosition node adapter target_verts[2]
            reference_position = undefined

            if ((reference_method == #neighbor) and (shared_vertex > 0)) then
            (
                reference_position = getVertexWorldPosition node adapter shared_vertex
            )
            else if (reference_method == #level) then
            (
                reference_position = getEdgeCenterWorld node adapter reference_edge
            )

            if (reference_position != undefined) then
            (
                if (check_type == #horizontal) then
                (
                    target_a = [point_a.x, point_a.y, reference_position.z]
                    target_b = [point_b.x, point_b.y, reference_position.z]
                )
                else if (check_type == #vertical) then
                (
                    target_a = [reference_position.x, reference_position.y, point_a.z]
                    target_b = [reference_position.x, reference_position.y, point_b.z]
                )

                moved_a = setVertexWorldPosition node adapter target_verts[1] target_a
                moved_b = setVertexWorldPosition node adapter target_verts[2] target_b
                result_value = moved_a and moved_b
            )
        )

        if (result_value) then
        (
            if (check_type == #horizontal) then
            (
                result_value = isHorizontalEdge node adapter target_edge tolerance
            )
            else if (check_type == #vertical) then
            (
                result_value = isVerticalEdge node adapter target_edge tolerance
            )
        )

        result_value
        -- return
    ),

    /*
    Converts a BitArray of IDs to comma-separated text.
    Used in the failed-vertex diagnostic message.
    */
    function bitIdsToString bit_set =
    (
        result_text = ""
        first_item = true

        for item_id in bit_set do
        (
            if (not first_item) then
            (
                result_text += ", "
            )

            result_text += (item_id as string)
            first_item = false
        )

        result_text
        -- return
    ),

    /*
    Straightens only the currently selected visible edges for Horizontal or Vertical mode.
    Reference priority is neighboring straight edge, then nearest straight edge on the same level.
    Failed edge vertices are selected automatically for manual correction.
    */
    function straightenSelectedEdges check_type tolerance angle_threshold search_in_z =
    (
        selected_nodes = selection as array
        object_results = #()
        total_selected_candidates = 0
        total_fixed_edges = 0
        has_failed_edges = false
        failure_report = ""

        if (selected_nodes.count == 0) then
        (
            messageBox "Select at least one geometry object." title:"Straight Edge Fixer"
        )
        else
        (
            undo "Straighten Selected Edges" on
            (
                for node in selected_nodes do
                (
                    if (isValidNode node and (superClassOf node == GeometryClass)) then
                    (
                        adapter = getGeometryAdapter node
                        original_edge_selection = getEdgeSelection node adapter
                        pending_edges = #{}
                        failed_vertices = #{}

                        for edge_id in original_edge_selection do
                        (
                            if (check_type == #horizontal) then
                            (
                                if (isHorizontalCheckCandidate node adapter edge_id tolerance angle_threshold) then
                                (
                                    pending_edges[edge_id] = true
                                )
                            )
                            else if (check_type == #vertical) then
                            (
                                if (isVerticalCheckCandidate node adapter edge_id tolerance angle_threshold) then
                                (
                                    pending_edges[edge_id] = true
                                )
                            )
                        )

                        total_selected_candidates += countBits pending_edges
                        continue_processing = true

                        /*
                        Multiple passes let a newly fixed edge become the straight neighbor
                        reference for the next selected edge in a chain.
                        */
                        while ((pending_edges.numberSet > 0) and continue_processing) do
                        (
                            continue_processing = false
                            pending_snapshot = copy pending_edges

                            for edge_id in pending_snapshot do
                            (
                                reference_data = findNeighborReference node adapter edge_id check_type tolerance angle_threshold

                                if (reference_data == undefined) then
                                (
                                    reference_data = findSameLevelReference node adapter edge_id check_type tolerance angle_threshold search_in_z
                                )

                                if (reference_data != undefined) then
                                (
                                    if (straightenEdgeUsingReference node adapter edge_id reference_data check_type tolerance) then
                                    (
                                        pending_edges[edge_id] = false
                                        total_fixed_edges += 1
                                        continue_processing = true
                                    )
                                )
                            )
                        )

                        for failed_edge in pending_edges do
                        (
                            failed_edge_verts = getEdgeVertIds node adapter failed_edge

                            if (failed_edge_verts.count == 2) then
                            (
                                failed_vertices[failed_edge_verts[1]] = true
                                failed_vertices[failed_edge_verts[2]] = true
                            )
                        )

                        if (failed_vertices.numberSet > 0) then
                        (
                            has_failed_edges = true
                            failure_report += node.name + ": " + (bitIdsToString failed_vertices) + "\n"
                        )

                        append object_results #(node, adapter, original_edge_selection, failed_vertices)
                    )
                )
            )

            /*
            If any heuristic failed, expose only failed vertices for manual repair.
            Otherwise keep the original edge selection visible.
            */
            if (has_failed_edges) then
            (
                for object_result in object_results do
                (
                    setVertexSelection object_result[1] object_result[2] object_result[4]
                )

                setCommandPanelTaskMode mode:#modify
                subObjectLevel = 1
                completeRedraw()

                messageBox ("Unable to straighten edges with vertices:\n\n" + failure_report) title:"Straight Edge Fixer"
            )
            else
            (
                for object_result in object_results do
                (
                    setEdgeSelection object_result[1] object_result[2] object_result[3]
                )

                setCommandPanelTaskMode mode:#modify
                subObjectLevel = 2
                completeRedraw()

                format "Straight Edge Fixer: fixed % selected edge(s).\n" total_fixed_edges

                if (total_selected_candidates == 0) then
                (
                    format "Straight Edge Fixer: no selected visible candidate edges matched the requested direction.\n"
                )
            )
        )

        #(total_fixed_edges, has_failed_edges)
        -- return
    ),

    /*
    Selects exact or skewed edges for Horizontal / Vertical direction checks.
    Exact mode uses zero coordinate tolerance; skewed mode uses 0 < deviation <= Angle.
    */
    function checkEdgeDirection check_type tolerance angle_threshold selection_mode:#skewed =
    (
        selected_nodes = selection as array
        total_selected_edges = 0
        processed_count = 0

        if (selected_nodes.count == 0) then
        (
            messageBox "Select at least one geometry object." title:"Straight Edge Fixer"
        )
        else
        (
            for node in selected_nodes do
            (
                if (isValidNode node and (superClassOf node == GeometryClass)) then
                (
                    processed_count += 1
                    adapter = getGeometryAdapter node
                    edge_count = getEdgeCount node adapter
                    matched_edges = #{}

                    for edge_id = 1 to edge_count do
                    (
                        edge_matches = false

                        if (selection_mode == #exact) then
                        (
                            if (check_type == #horizontal) then
                            (
                                edge_matches = isHorizontalEdge node adapter edge_id 0.0
                            )
                            else if (check_type == #vertical) then
                            (
                                edge_matches = isVerticalEdge node adapter edge_id 0.0
                            )
                        )
                        else
                        (
                            if (check_type == #horizontal) then
                            (
                                edge_matches = isHorizontalCheckCandidate node adapter edge_id tolerance angle_threshold
                            )
                            else if (check_type == #vertical) then
                            (
                                edge_matches = isVerticalCheckCandidate node adapter edge_id tolerance angle_threshold
                            )
                        )

                        if (edge_matches) then
                        (
                            matched_edges[edge_id] = true
                        )
                    )

                    setEdgeSelection node adapter matched_edges
                    total_selected_edges += countBits matched_edges
                )
            )

            if (processed_count > 0) then
            (
                setCommandPanelTaskMode mode:#modify
                subObjectLevel = 2
                completeRedraw()

                if (selection_mode == #exact) then
                (
                    format "Check %: selected % exact zero-deviation edge(s).\n" check_type total_selected_edges
                )
                else
                (
                    format "Check %: selected % skewed edge(s), deviation >0 and <= % deg.\n" check_type total_selected_edges angle_threshold
                )
            )
        )

        total_selected_edges
        -- return
    ),


    /*
    Reads all visible horizontal edge data used by level detection.
    Each record is #(edge_id, z_min, z_max, z_center, vert_a, vert_b).
    */
    function getHorizontalEdgeData node adapter level_tolerance =
    (
        edge_data = #()
        edge_count = getEdgeCount node adapter

        for edge_id = 1 to edge_count do
        (
            if (isEdgeVisible node adapter edge_id) then
            (
                if (isHorizontalEdge node adapter edge_id level_tolerance) then
                (
                    edge_verts = getEdgeVertIds node adapter edge_id

                    if (edge_verts.count == 2) then
                    (
                        point_a = getVertexWorldPosition node adapter edge_verts[1]
                        point_b = getVertexWorldPosition node adapter edge_verts[2]
                        z_min = amin point_a.z point_b.z
                        z_max = amax point_a.z point_b.z
                        z_center = (point_a.z + point_b.z) * 0.5

                        append edge_data #(edge_id, z_min, z_max, z_center, edge_verts[1], edge_verts[2])
                    )
                )
            )
        )

        edge_data
        -- return
    ),

    /*
    Builds one detected Z-level record from defining horizontal edges.
    The level center is the midpoint of the minimum and maximum defining edge centers.
    */
    function makeLevel cluster =
    (
        definition_edges = #{}
        level_min = cluster[1][4]
        level_max = cluster[1][4]

        for item in cluster do
        (
            definition_edges[item[1]] = true

            if (item[4] < level_min) then
            (
                level_min = item[4]
            )

            if (item[4] > level_max) then
            (
                level_max = item[4]
            )
        )

        level_center = (level_min + level_max) * 0.5

        #(definition_edges, level_min, level_max, level_center, #{}, level_center, #CENTER, 0)
        -- return
    ),

    /*
    Detects repeated world-Z levels from horizontal edges.
    A valid level requires at least Min Level Edges inside Level Tolerance.
    */
    function findLevels edge_data level_tolerance min_level_edges =
    (
        levels = #()

        if (edge_data.count > 0) then
        (
            qsort edge_data straightEdgeFixerCompareData
            cluster = #()
            cluster_min_z = 0.0
            max_cluster_span = level_tolerance * 2.0

            for item in edge_data do
            (
                if (cluster.count == 0) then
                (
                    cluster = #(item)
                    cluster_min_z = item[4]
                )
                else if ((item[4] - cluster_min_z) <= max_cluster_span) then
                (
                    append cluster item
                )
                else
                (
                    if (cluster.count >= min_level_edges) then
                    (
                        append levels (makeLevel cluster)
                    )

                    cluster = #(item)
                    cluster_min_z = item[4]
                )
            )

            if (cluster.count >= min_level_edges) then
            (
                append levels (makeLevel cluster)
            )

            if (levels.count > 1) then
            (
                qsort levels straightEdgeFixerCompareLevelData
            )
        )

        levels
        -- return
    ),

    /*
    Assigns every horizontal edge to the nearest detected level inside Search in Z.
    An edge can belong to only one detected level.
    */
    function assignEdgesToLevels levels edge_data search_in_z =
    (
        if (levels.count > 0) then
        (
            for item in edge_data do
            (
                edge_id = item[1]
                edge_z = item[4]
                nearest_level = 0
                nearest_distance = 1.0e30

                for level_index = 1 to levels.count do
                (
                    level_distance = abs (edge_z - levels[level_index][4])

                    if (level_distance < nearest_distance) then
                    (
                        nearest_distance = level_distance
                        nearest_level = level_index
                    )
                )

                if ((nearest_level > 0) and (nearest_distance <= search_in_z)) then
                (
                    levels[nearest_level][5][edge_id] = true
                )
            )
        )

        levels
        -- return
    ),

    /*
    Finds one horizontal edge record by edge ID.
    Returns undefined when the edge is not present in edge_data.
    */
    function getEdgeDataById edge_data edge_id =
    (
        result_data = undefined

        for item in edge_data while (result_data == undefined) do
        (
            if (item[1] == edge_id) then
            (
                result_data = item
            )
        )

        result_data
        -- return
    ),

    /*
    Chooses TOP, BOTTOM, or CENTER target Z for every detected edge level.
    The decision uses assigned edge centers outside the defining edge cluster.
    */
    function calculateTargets levels edge_data =
    (
        for level_index = 1 to levels.count do
        (
            level_data = levels[level_index]
            definition_edges = level_data[1]
            assigned_edges = level_data[5]
            level_min = level_data[2]
            level_max = level_data[3]
            level_center = level_data[4]
            outside_count = 0
            below_count = 0
            above_count = 0

            for edge_id in assigned_edges do
            (
                if (not definition_edges[edge_id]) then
                (
                    item = getEdgeDataById edge_data edge_id

                    if (item != undefined) then
                    (
                        outside_count += 1
                        edge_z = item[4]

                        if (edge_z < level_min) then
                        (
                            below_count += 1
                        )
                        else if (edge_z > level_max) then
                        (
                            above_count += 1
                        )
                    )
                )
            )

            if (outside_count == 0) then
            (
                level_data[6] = level_center
                level_data[7] = #CENTER
            )
            else if (below_count == outside_count) then
            (
                level_data[6] = level_max
                level_data[7] = #TOP
            )
            else if (above_count == outside_count) then
            (
                level_data[6] = level_min
                level_data[7] = #BOTTOM
            )
            else
            (
                level_data[6] = level_center
                level_data[7] = #CENTER
            )

            level_data[8] = outside_count
        )

        levels
        -- return
    ),

    /*
    Collects unique vertex IDs used by the assigned edges of one level.
    Shared vertices are moved only once.
    */
    function getLevelVertexIds node adapter assigned_edges =
    (
        vertex_ids = #{}

        for edge_id in assigned_edges do
        (
            edge_verts = getEdgeVertIds node adapter edge_id

            if (edge_verts.count == 2) then
            (
                vertex_ids[edge_verts[1]] = true
                vertex_ids[edge_verts[2]] = true
            )
        )

        vertex_ids
        -- return
    ),

    /*
    Aligns one vertex to target world Z on an Editable Poly base object.
    World X and Y remain unchanged.
    */
    function setEditablePolyVertexWorldZ node editable_poly vert_id target_z =
    (
        object_tm = node.objectTransform
        inverse_tm = inverse object_tm
        local_position = polyop.getVert editable_poly vert_id
        world_position = local_position * object_tm
        target_world_position = [world_position.x, world_position.y, target_z]
        target_local_position = target_world_position * inverse_tm

        polyop.setVert editable_poly vert_id target_local_position

        true
        -- return
    ),

    /*
    Aligns assigned edge vertices directly on an Editable Poly base object.
    Shared vertices are moved once per detected level.
    */
    function applyToEditablePoly node editable_poly adapter levels =
    (
        for level_data in levels do
        (
            vertex_ids = getLevelVertexIds node adapter level_data[5]
            target_z = level_data[6]

            for vert_id in vertex_ids do
            (
                setEditablePolyVertexWorldZ node editable_poly vert_id target_z
            )
        )

        update node
        true
        -- return
    ),

    /*
    Aligns assigned edge vertices through an Edit Poly modifier.
    Existing vertex selection and Edit Poly sub-object level are restored afterwards.
    */
    function applyToEditPoly node edit_poly adapter levels =
    (
        previous_selection = EditPolyMod.GetSelection edit_poly #Vertex node:node
        previous_level = EditPolyMod.GetEPolySelLevel edit_poly
        object_tm = node.objectTransform

        EditPolyMod.SetEPolySelLevel edit_poly #Vertex

        for level_data in levels do
        (
            vertex_ids = getLevelVertexIds node adapter level_data[5]
            target_z = level_data[6]

            for vert_id in vertex_ids do
            (
                current_local_position = EditPolyMod.GetVertex edit_poly vert_id node:node
                current_world_position = current_local_position * object_tm
                world_move_delta = [0,0,(target_z - current_world_position.z)]

                if ((length world_move_delta) > 0.0000001) then
                (
                    one_vert = #{}
                    one_vert[vert_id] = true
                    EditPolyMod.SetSelection edit_poly #Vertex one_vert node:node
                    EditPolyMod.MoveSelection edit_poly world_move_delta
                    EditPolyMod.Commit edit_poly
                )
            )
        )

        EditPolyMod.SetSelection edit_poly #Vertex previous_selection node:node
        EditPolyMod.SetEPolySelLevel edit_poly previous_level
        update node

        true
        -- return
    ),

    /*
    Formats one object's detected edge levels from bottom to top.
    Reports defining edges, outside aligned edges, mode, and final target Z.
    */
    function buildObjectReport node levels =
    (
        report_text = "OBJECT: " + node.name + "\n"

        if (levels.count == 0) then
        (
            report_text += "  No edge levels found.\n"
        )
        else
        (
            for level_index = 1 to levels.count do
            (
                level_data = levels[level_index]
                definition_count = countBits level_data[1]
                assigned_count = countBits level_data[5]
                outside_count = level_data[8]

                report_text +=
                    "  Level " + (level_index as string) +
                    " | detected Z: " + (level_data[4] as string) +
                    " | mode: " + (level_data[7] as string) +
                    " | target Z: " + (level_data[6] as string) +
                    " | level edges: " + (definition_count as string) +
                    " | outside aligned: " + (outside_count as string) +
                    " | total aligned: " + (assigned_count as string) + "\n"
            )
        )

        report_text
        -- return
    ),

    /*
    Processes one selected object using horizontal edges instead of loose vertices.
    Returns a diagnostic text block for that object.
    */
    function processObject node level_tolerance min_level_edges search_in_z =
    (
        report_text = ""
        adapter = undefined
        created_new_modifier = false

        try
        (
            adapter = getGeometryAdapter node
            created_new_modifier = adapter[3]
            edge_data = getHorizontalEdgeData node adapter level_tolerance
            levels = findLevels edge_data level_tolerance min_level_edges
            levels = assignEdgesToLevels levels edge_data search_in_z
            levels = calculateTargets levels edge_data

            if (levels.count > 0) then
            (
                if (adapter[1] == #editable_poly) then
                (
                    applyToEditablePoly node (adapter[2]) adapter levels
                )
                else
                (
                    applyToEditPoly node (adapter[2]) adapter levels
                )
            )
            else if (created_new_modifier) then
            (
                deleteModifier node (adapter[2])
            )

            report_text = buildObjectReport node levels
        )
        catch
        (
            if (created_new_modifier and (adapter != undefined)) then
            (
                try
                (
                    deleteModifier node (adapter[2])
                )
                catch
                (
                )
            )

            report_text = "OBJECT: " + node.name + "\n  ERROR: " + (getCurrentException() as string) + "\n"
        )

        report_text
        -- return
    ),

    /*
    Detects and aligns horizontal edge levels on all selected geometry objects.
    Quiet Mode suppresses the final diagnostic message box.
    */
    function alignSelection level_tolerance:0.01 min_level_edges:3 search_in_z:10.0 quiet_mode:false =
    (
        selected_nodes = selection as array
        report_text = "STRAIGHT EDGE FIXER " + version + "\n\n"
        processed_count = 0

        if (selected_nodes.count == 0) then
        (
            messageBox "Select at least one geometry object." title:"Straight Edge Fixer"
        )
        else
        (
            undo "Straight Edge Fixer" on
            (
                for node in selected_nodes do
                (
                    if (isValidNode node and (superClassOf node == GeometryClass)) then
                    (
                        processed_count += 1
                        report_text += processObject node level_tolerance min_level_edges search_in_z
                        report_text += "\n"
                    )
                )
            )

            completeRedraw()

            if (processed_count == 0) then
            (
                messageBox "The selection contains no supported geometry objects." title:"Straight Edge Fixer"
            )
            else if (not quiet_mode) then
            (
                messageBox report_text title:"Straight Edge Fixer - Report"
            )
        )

        true
        -- return
    ),

    on create do
    (
        migrateLegacyIni()
    )
)

StraightEdgeFixer = StraightEdgeFixer_v()

try
(
    destroyDialog straightEdgeFixer_ui
)
catch
(
)

rollout straightEdgeFixer_ui "Straight Edge Fixer 0.2" width:300
(
    groupBox grp_settings "LEVEL SETTINGS" pos:[8,8] width:284 height:132

    label lbl_level_tolerance "Level Tolerance:" pos:[20,32] width:120 height:18
    spinner spn_level_tolerance "" pos:[150,30] width:125 height:18 range:[0.000001,1000000.0,0.01] type:#worldunits scale:0.001 tooltip:"Maximum world-axis deviation. For level detection it defines horizontal edges and groups their center Z values. The same tolerance is used by the direction checks."

    label lbl_min_level_edges "Min Level Edges:" pos:[20,60] width:120 height:18
    spinner spn_min_level_edges "" pos:[150,58] width:125 height:18 range:[1,100000,3] type:#integer scale:1 tooltip:"Minimum number of horizontal edges required inside Level Tolerance to define a valid Z level."

    label lbl_search_in_z "Search in Z:" pos:[20,88] width:120 height:18
    spinner spn_search_in_z "" pos:[150,86] width:125 height:18 range:[0.0,1000000.0,10.0] type:#worldunits scale:0.1 tooltip:"Maximum world-Z distance from a detected level. Horizontal edges inside this range are assigned to the nearest level and aligned."

    checkbox chk_quiet_mode "Quiet Mode" pos:[20,116] width:240 height:18 checked:false tooltip:"Run edge-level alignment without showing the final report."

    groupBox grp_checks "EDGE CHECKS" pos:[8,148] width:284 height:144

    label lbl_angle_threshold "Angle:" pos:[20,172] width:46 height:18 tooltip:"Maximum allowed angle away from the requested direction. Edges above this angle are selected as direction errors. At 0 degrees every non-matching edge is selected; 45 degrees is the horizontal/vertical crossover."
    spinner spn_angle_threshold "" pos:[64,170] width:58 height:18 range:[0.0,45.0,45.0] type:#float scale:1.0 tooltip:"Maximum allowed direction deviation in degrees. CHECK HORIZONTAL selects edges above this deviation from horizontal. CHECK VERTICAL selects edges above this deviation from vertical."

    button btn_check_horizontal "CHECK HORIZONTAL" pos:[18,198] width:127 height:42 tooltip:"LMB: select visible edges whose deviation from horizontal is greater than Angle.\n\nRMB: straighten currently selected horizontal-direction error edges. Reference priority: straight neighbor, then nearest straight edge on the same level. Failed vertices are selected automatically."
    button btn_check_vertical "CHECK VERTICAL" pos:[155,198] width:127 height:42 tooltip:"LMB: select visible edges whose deviation from vertical is greater than Angle.\n\nRMB: straighten currently selected vertical-direction error edges. Reference priority: straight neighbor, then nearest straight edge on the same level. Failed vertices are selected automatically."

    button btn_border_check "BORDER CHECK" pos:[18,248] width:264 height:28 tooltip:"Select visible border edges with an unwelded/overlapping local-Z seam, a reflex corner above 180 degrees, or a 360-degree backtracking border. Backtracking does not require the remote vertices to share position."

    button btn_align "STRAIGHT EDGE FIXER" pos:[8,302] width:284 height:38 tooltip:"Detect repeated horizontal edge levels and align nearby horizontal edges to TOP, BOTTOM, or CENTER target Z."

    on straightEdgeFixer_ui open do
    (
        settings_data = StraightEdgeFixer.loadSettings()
        spn_level_tolerance.value = settings_data[1]
        spn_min_level_edges.value = settings_data[2]
        spn_search_in_z.value = settings_data[3]
        spn_angle_threshold.value = settings_data[4]
        chk_quiet_mode.checked = settings_data[5]
    )

    on straightEdgeFixer_ui moved dialog_position do
    (
        StraightEdgeFixer.saveDialogPosition dialog_position
    )

    on spn_level_tolerance changed control_value do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_search_in_z.value spn_angle_threshold.value chk_quiet_mode.checked
    )

    on spn_min_level_edges changed control_value do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_search_in_z.value spn_angle_threshold.value chk_quiet_mode.checked
    )

    on spn_search_in_z changed control_value do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_search_in_z.value spn_angle_threshold.value chk_quiet_mode.checked
    )

    on spn_angle_threshold changed control_value do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_search_in_z.value spn_angle_threshold.value chk_quiet_mode.checked
    )

    on chk_quiet_mode changed control_state do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_search_in_z.value spn_angle_threshold.value chk_quiet_mode.checked
    )

    on btn_check_horizontal pressed do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_search_in_z.value spn_angle_threshold.value chk_quiet_mode.checked
        StraightEdgeFixer.checkEdgeDirection #horizontal spn_level_tolerance.value spn_angle_threshold.value
    )


    on btn_check_horizontal rightclick do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_search_in_z.value spn_angle_threshold.value chk_quiet_mode.checked
        StraightEdgeFixer.straightenSelectedEdges #horizontal spn_level_tolerance.value spn_angle_threshold.value spn_search_in_z.value
    )

    on btn_check_vertical pressed do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_search_in_z.value spn_angle_threshold.value chk_quiet_mode.checked
        StraightEdgeFixer.checkEdgeDirection #vertical spn_level_tolerance.value spn_angle_threshold.value
    )


    on btn_check_vertical rightclick do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_search_in_z.value spn_angle_threshold.value chk_quiet_mode.checked
        StraightEdgeFixer.straightenSelectedEdges #vertical spn_level_tolerance.value spn_angle_threshold.value spn_search_in_z.value
    )


    on btn_border_check pressed do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_search_in_z.value spn_angle_threshold.value chk_quiet_mode.checked
        StraightEdgeFixer.checkBorders spn_level_tolerance.value
    )

    on btn_align pressed do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_search_in_z.value spn_angle_threshold.value chk_quiet_mode.checked

        StraightEdgeFixer.alignSelection \
            level_tolerance:spn_level_tolerance.value \
            min_level_edges:spn_min_level_edges.value \
            search_in_z:spn_search_in_z.value \
            quiet_mode:chk_quiet_mode.checked
    )
)

dialog_position = StraightEdgeFixer.loadDialogPosition()
createDialog straightEdgeFixer_ui pos:dialog_position style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
