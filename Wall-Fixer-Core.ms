/*
Wall-Fixer Core 0.23
Main WallFixer_v implementation and persistent runtime instance.
Load through Wall-Fixer.ms during normal development.
*/

global WallFixerVersion
global WallFixerRollout
global wall_fixer_version_system
global wall_fixer_version_epoch
global wall_fixer_core_file_version = "0.24"
global wall_fixer_core_tool_version = 0.54

/*
Registers this file's shared Wall-Fixer tool version.
Accepts legacy string or numeric global versions; the highest loaded version wins.
*/
if wall_fixer_version_system != 1 then
(
    wall_fixer_version_system = 1
)

if wall_fixer_version_epoch != 3 then
(
    wall_fixer_version_epoch = 3
    WallFixerVersion = undefined
)

wall_fixer_core_current_tool_version_number = undefined

if WallFixerVersion != undefined then
(
    try
    (
        wall_fixer_core_current_tool_version_number = WallFixerVersion as float
    )
    catch
    (
        wall_fixer_core_current_tool_version_number = undefined
    )
)

if wall_fixer_core_current_tool_version_number == undefined then
(
    WallFixerVersion = wall_fixer_core_tool_version
)
else if wall_fixer_core_tool_version > wall_fixer_core_current_tool_version_number then
(
    WallFixerVersion = wall_fixer_core_tool_version
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


global WallFixer_v
global WallFixer

struct WallFixer_v
(
    version = "0.23",
    processed_slice_nodes = #(),
    processed_vertical_planes = #(),
    processed_horizontal_planes = #(),
    processed_vertical_edges = #(),
    processed_horizontal_edges = #(),
    reset_inner_vert_nodes = #(),
    reset_inner_vert_selections = #(),
    last_slice_error = undefined,
    last_slice_count = 0,
    last_slice_report = "",
    batch_quiet = false,
    attach_weld_selection_order = #(),
    last_debug_slice_node = undefined,
    last_debug_slice_new_edges = #{},
    last_debug_slice_start_vertices = #{},
    last_debug_slice_original_vertices = #{},
    epsilon = 0.001,
    axis_angle_threshold = 5.0,
    ini_path = ((getDir #userScripts) + "\\Wall-Fixer.ini"),

    /*
    Returns true only for the non-fatal missing last-slice cleanup context notice.
    UI wrappers use this to keep the notice in the Listener instead of showing a modal message.
    */
    function isLastSliceContextNotice report_text =
    (
        if report_text == undefined then
        (
            false
        )
        else
        (
            findString report_text ": no valid last-slice anchor/direction chain was found. Run Make 1 Slice first." != undefined
        )
        -- return
    ),

    /*
    Returns the per-node index used only to remember processed slice planes.
    The base mesh is analyzed fresh on every Make 1 Slice click.
    */
    function getProcessedSliceNodeIndex node create_if_missing:false =
    (
        for index = 1 to processed_slice_nodes.count do
        (
            if processed_slice_nodes[index] == node then return index
        )

        if create_if_missing then
        (
            append processed_slice_nodes node
            append processed_vertical_planes #()
            append processed_horizontal_planes #()
            append processed_vertical_edges #{}
            append processed_horizontal_edges #{}
            processed_slice_nodes.count
        )
        else
        (
            0
        )
        -- return
    ),

    /*
    Returns true when a geometric slice plane already exists in the supplied plane records.
    Plane identity uses direction plus signed position, independent of which corner defines it.
    */
    function hasSlicePlaneRecord world_anchor world_axis plane_records =
    (
        if world_anchor == undefined or world_axis == undefined then return false
        if length world_axis <= epsilon then return false

        plane_axis = normalize world_axis
        plane_tolerance = amax epsilon 0.01
        axis_cos = cos 0.1

        for plane_record in plane_records do
        (
            stored_axis = plane_record[1]
            stored_anchor = plane_record[2]
            if abs(dot stored_axis plane_axis) >= axis_cos then
            (
                if abs(dot (world_anchor - stored_anchor) stored_axis) <= plane_tolerance then return true
            )
        )

        false
        -- return
    ),

    /*
    Returns true when one unchanged base-object border edge already produced a successful Edge Direction slice.
    Edge IDs are stable because Make 1 Slice always analyzes the unchanged Editable Poly base object.
    */
    function isBaseSliceEdgeProcessed node base_edge slice_kind =
    (
        if base_edge <= 0 then return false

        node_index = getProcessedSliceNodeIndex node create_if_missing:false
        if node_index == 0 then return false

        edge_selection = if slice_kind == #vertical then processed_vertical_edges[node_index] else processed_horizontal_edges[node_index]
        if base_edge > edge_selection.count then return false
        edge_selection[base_edge]
        -- return
    ),

    /*
    Remembers one successfully sliced unchanged base-object border edge for Edge Direction mode.
    Vertical and horizontal state stays separate, so one corner may still participate in both directions.
    */
    function markBaseSliceEdgeProcessed node base_edge slice_kind =
    (
        if base_edge <= 0 then return false

        node_index = getProcessedSliceNodeIndex node create_if_missing:true
        if slice_kind == #vertical then
        (
            edge_selection = processed_vertical_edges[node_index]
            edge_selection[base_edge] = true
            processed_vertical_edges[node_index] = edge_selection
        )
        else
        (
            edge_selection = processed_horizontal_edges[node_index]
            edge_selection[base_edge] = true
            processed_horizontal_edges[node_index] = edge_selection
        )

        true
        -- return
    ),

    /*
    Returns true when the same geometric slice plane was already processed in this direction.
    Plane identity is used only by Global Axis mode. Edge Direction uses the defining base edge instead.
    */
    function isBaseSlicePlaneProcessed node world_anchor world_axis slice_kind =
    (
        if world_anchor == undefined or world_axis == undefined then return false
        if length world_axis <= epsilon then return false

        node_index = getProcessedSliceNodeIndex node create_if_missing:false
        if node_index == 0 then return false

        plane_records = if slice_kind == #vertical then processed_vertical_planes[node_index] else processed_horizontal_planes[node_index]
        hasSlicePlaneRecord world_anchor world_axis plane_records
        -- return
    ),

    /*
    Remembers one successfully processed geometric slice plane for Global Axis mode.
    Failed attempts are never stored because later topology changes may make the same plane useful.
    */
    function markBaseSlicePlaneProcessed node world_anchor world_axis slice_kind =
    (
        if world_anchor == undefined or world_axis == undefined then return false
        if length world_axis <= epsilon then return false

        node_index = getProcessedSliceNodeIndex node create_if_missing:true
        plane_record = #(normalize world_axis, world_anchor)

        if slice_kind == #vertical then
        (
            append processed_vertical_planes[node_index] plane_record
        )
        else
        (
            append processed_horizontal_planes[node_index] plane_record
        )

        true
        -- return
    ),

    /*
    Returns the cache index for INNER VERTS captured by Reset Slicing.
    The cached BitArray keeps the exact base vertex IDs found during reset.
    */
    function getResetInnerVertNodeIndex node create_if_missing:false =
    (
        for index = 1 to reset_inner_vert_nodes.count do
        (
            if reset_inner_vert_nodes[index] == node then return index
        )

        if create_if_missing then
        (
            append reset_inner_vert_nodes node
            append reset_inner_vert_selections #{}
            reset_inner_vert_nodes.count
        )
        else
        (
            0
        )
        -- return
    ),

    /*
    Stores the exact INNER VERTS reported by Reset Slicing for one wall.
    Check Corners reuses this BitArray instead of recalculating corner availability.
    */
    function setResetInnerVertSelection node vertex_selection =
    (
        cache_index = getResetInnerVertNodeIndex node create_if_missing:true
        reset_inner_vert_selections[cache_index] = copy vertex_selection
        true
        -- return
    ),

    /*
    Returns the exact INNER VERTS captured by the last successful Reset Slicing.
    Undefined means Reset Slicing has not produced a cache for this wall yet.
    */
    function getResetInnerVertSelection node =
    (
        cache_index = getResetInnerVertNodeIndex node create_if_missing:false
        if cache_index == 0 then
        (
            undefined
        )
        else
        (
            copy reset_inner_vert_selections[cache_index]
        )
        -- return
    ),

    /*
    Clears the cached INNER VERTS before Reset Slicing analyzes the wall again.
    A failed reset therefore cannot leave stale corner IDs available to Check Corners.
    */
    function clearResetInnerVertSelection node =
    (
        cache_index = getResetInnerVertNodeIndex node create_if_missing:false
        if cache_index > 0 then
        (
            deleteItem reset_inner_vert_nodes cache_index
            deleteItem reset_inner_vert_selections cache_index
        )
        true
        -- return
    ),

    /*
    Clears remembered slice-plane state for one wall.
    Used by Reset Slicing so vertical and horizontal processing starts fresh.
    */
    function resetProcessedSliceState node =
    (
        node_index = getProcessedSliceNodeIndex node create_if_missing:false
        if node_index > 0 then
        (
            deleteItem processed_slice_nodes node_index
            deleteItem processed_vertical_planes node_index
            deleteItem processed_horizontal_planes node_index
            deleteItem processed_vertical_edges node_index
            deleteItem processed_horizontal_edges node_index
        )
        true
        -- return
    ),

    /*
    Clears the last successful Make 1 Slice edge-cleanup context.
    Reset Slicing and a new Make 1 Slice invalidate old Edit Poly edge IDs.
    */
    function clearLastDebugSliceContext node:undefined =
    (
        if node == undefined or last_debug_slice_node == node then
        (
            last_debug_slice_node = undefined
            last_debug_slice_new_edges = #{}
            last_debug_slice_start_vertices = #{}
            last_debug_slice_original_vertices = #{}
        )

        true
        -- return
    ),

    /*
    Returns true only for Edit Poly modifiers owned by Wall-Fixer.
    New modifiers use the WMC prefix; exact legacy names remain recognized for older scene stacks.
    */
    function isWallFixerEditPolyModifier stack_modifier =
    (
        if stack_modifier == undefined then return false
        if classOf stack_modifier != Edit_Poly then return false

        modifier_name = stack_modifier.name as string
        if findString modifier_name "WMC - " == 1 then return true

        legacy_names = #(
            "Cleanup LOOPS",
            "Wall topology cleanup",
            "FIX TWO-EDGE VERTS",
            "CLEAN UP SLICED EDGES POSTPROCESS",
            "SLICE ALL",
            "SLICE HORIZONTAL",
            "SLICE VERTICAL"
        )

        (findItem legacy_names modifier_name) > 0
        -- return
    ),

    /*
    Removes only Wall-Fixer-owned Edit Poly modifiers from one wall.
    User modifiers and non-Edit-Poly modifiers are always preserved.
    */
    function removeWallFixerEditPolyModifiers node =
    (
        if node == undefined or not(isValidNode node) then return false

        modifier_index = node.modifiers.count
        while modifier_index >= 1 do
        (
            stack_modifier = node.modifiers[modifier_index]
            if isWallFixerEditPolyModifier stack_modifier then
            (
                deleteModifier node stack_modifier
            )

            modifier_index -= 1
        )

        update node
        true
        -- return
    ),

    /*
    Returns true only for Edit Poly modifiers used by the slicing workflow.
    Directional slice modifiers use exact user-facing names; legacy topology names remain supported.
    */
    function isWallFixerSliceModifier stack_modifier =
    (
        if stack_modifier == undefined then return false
        if classOf stack_modifier != Edit_Poly then return false

        modifier_name = stack_modifier.name as string
        slice_modifier_names = #(
            "SLICE ALL",
            "SLICE HORIZONTAL",
            "SLICE VERTICAL",
            "WMC - WALL TOPOLOGY CLEANUP",
            "Wall topology cleanup"
        )

        (findItem slice_modifier_names modifier_name) > 0
        -- return
    ),

    /*
    Removes only Edit Poly modifiers that belong to the slicing workflow.
    Other Wall-Fixer modifiers and all user modifiers remain untouched.
    */
    function removeWallFixerSliceModifiers node =
    (
        if node == undefined or not(isValidNode node) then return false

        modifier_index = node.modifiers.count
        while modifier_index >= 1 do
        (
            stack_modifier = node.modifiers[modifier_index]
            if isWallFixerSliceModifier stack_modifier then
            (
                deleteModifier node stack_modifier
            )

            modifier_index -= 1
        )

        update node
        true
        -- return
    ),

    /*
    Resets one wall for Reset Slicing by clearing processed state and modifier history.
    */
    function resetNodeForCheckMesh node =
    (
        if node == undefined or not(isValidNode node) then return false

        resetProcessedSliceState node
        clearResetInnerVertSelection node
        clearLastDebugSliceContext node:node
        removeWallFixerEditPolyModifiers node

        base_obj = node.baseObject
        if classOf base_obj == Editable_Poly then
        (
            polyop.setVertSelection base_obj #{}
            polyop.setEdgeSelection base_obj #{}
            polyop.setFaceSelection base_obj #{}
        )

        true
        -- return
    ),

    /*
    Returns batch-slice nodes after skipping simple four-vertex planar walls.
    Four-vertex Editable Poly walls cannot contain an inner corner that needs slicing.
    */
    function getBatchSliceProcessNodes nodes =
    (
        local process_nodes = #()
        if nodes == undefined then return process_nodes

        for node in nodes do
        (
            local skip_node = false

            if node != undefined and isValidNode node then
            (
                local base_obj = node.baseObject
                if classOf base_obj == Editable_Poly then
                (
                    local vert_count = polyop.getNumVerts base_obj
                    local dead_vert_count = (polyop.getDeadVerts base_obj).numberSet
                    local live_vert_count = vert_count - dead_vert_count

                    if live_vert_count == 4 then
                    (
                        skip_node = true
                    )
                )
            )

            if not skip_node then
            (
                append process_nodes node
            )
        )

        process_nodes
        -- return
    ),

    /*
    Splits one Editable Poly base object into connected coplanar wall regions.
    Crease edges between differently oriented walls become independent region borders.
    */
    function getBasePlanarWallRegions node planar_tolerance:1.0 =
    (
        local result = #()
        if node == undefined or not(isValidNode node) then return result

        local base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then return result

        local vert_count = polyop.getNumVerts base_obj
        local edge_count = polyop.getNumEdges base_obj
        local face_count = polyop.getNumFaces base_obj
        if vert_count < 3 or edge_count < 3 or face_count < 1 then return result

        local object_tm = node.objectTransform
        local world_points = #()
        for vertex_index = 1 to vert_count do
        (
            append world_points ((polyop.getVert base_obj vertex_index) * object_tm)
        )

        local face_normals = #()
        local face_origins = #()
        for face_index = 1 to face_count do
        (
            local face_verts = polyop.getFaceVerts base_obj face_index
            local face_normal = undefined
            local face_origin = undefined

            if face_verts != undefined and face_verts.count >= 3 then
            (
                face_origin = world_points[face_verts[1]]
                local normal_sum = [0.0,0.0,0.0]

                for corner_index = 2 to (face_verts.count - 1) do
                (
                    local point_b = world_points[face_verts[corner_index]]
                    local point_c = world_points[face_verts[corner_index + 1]]
                    normal_sum += cross (point_b - face_origin) (point_c - face_origin)
                )

                if length normal_sum > epsilon then
                (
                    face_normal = normalize normal_sum
                )
            )

            append face_normals face_normal
            append face_origins face_origin
        )

        local processed_faces = #{}
        local normal_limit = cos 0.1
        local region_id = 0

        for seed_face = 1 to face_count do
        (
            if not processed_faces[seed_face] and face_normals[seed_face] != undefined then
            (
                region_id += 1
                local region_faces = #{seed_face}
                local face_queue = #(seed_face)
                local queue_index = 1
                local wall_normal = face_normals[seed_face]
                local wall_origin = face_origins[seed_face]
                processed_faces[seed_face] = true

                while queue_index <= face_queue.count do
                (
                    local current_face = face_queue[queue_index]
                    queue_index += 1

                    local current_edges = polyop.getEdgesUsingFace base_obj #{current_face}
                    for edge_index in current_edges do
                    (
                        local adjacent_faces = polyop.getFacesUsingEdge base_obj #{edge_index}
                        for adjacent_face in adjacent_faces do
                        (
                            if not processed_faces[adjacent_face] and face_normals[adjacent_face] != undefined then
                            (
                                local normal_matches = abs(dot wall_normal face_normals[adjacent_face]) >= normal_limit
                                local plane_matches = normal_matches

                                if plane_matches then
                                (
                                    local adjacent_verts = polyop.getFaceVerts base_obj adjacent_face
                                    for vertex_index in adjacent_verts while plane_matches do
                                    (
                                        if abs(dot (world_points[vertex_index] - wall_origin) wall_normal) > planar_tolerance then
                                        (
                                            plane_matches = false
                                        )
                                    )
                                )

                                if plane_matches then
                                (
                                    processed_faces[adjacent_face] = true
                                    region_faces[adjacent_face] = true
                                    append face_queue adjacent_face
                                )
                            )
                        )
                    )
                )

                local region_edges = polyop.getEdgesUsingFace base_obj region_faces
                local border_edges = #{}
                local vertex_border_edges = for vertex_index = 1 to vert_count collect #{}

                for edge_index in region_edges do
                (
                    local edge_faces = polyop.getFacesUsingEdge base_obj #{edge_index}
                    local region_face_count = 0
                    local only_region_face = 0

                    for face_index in edge_faces do
                    (
                        if region_faces[face_index] then
                        (
                            region_face_count += 1
                            only_region_face = face_index
                        )
                    )

                    if region_face_count == 1 then
                    (
                        local edge_verts = polyop.getEdgeVerts base_obj edge_index
                        local face_verts = polyop.getFaceVerts base_obj only_region_face
                        local face_edge_uses = 0

                        /*
                        A same-face bridge used twice is an internal hole bridge, not a region border.
                        Count ordered boundary uses before accepting the edge.
                        */
                        if edge_verts != undefined and edge_verts.count == 2 and face_verts != undefined and face_verts.count >= 3 then
                        (
                            for face_corner = 1 to face_verts.count do
                            (
                                local next_corner = if face_corner == face_verts.count then 1 else face_corner + 1
                                local face_vertex_a = face_verts[face_corner]
                                local face_vertex_b = face_verts[next_corner]

                                if (face_vertex_a == edge_verts[1] and face_vertex_b == edge_verts[2]) or \
                                   (face_vertex_a == edge_verts[2] and face_vertex_b == edge_verts[1]) then
                                (
                                    face_edge_uses += 1
                                )
                            )
                        )

                        if face_edge_uses == 1 then
                        (
                            border_edges[edge_index] = true
                            vertex_border_edges[edge_verts[1]][edge_index] = true
                            vertex_border_edges[edge_verts[2]][edge_index] = true
                        )
                    )
                )

                if border_edges.numberSet > 0 then
                (
                    local wall_vertical = [0,0,1] - wall_normal * (dot wall_normal [0,0,1])
                    local wall_horizontal = undefined

                    if length wall_vertical > epsilon then
                    (
                        wall_vertical = normalize wall_vertical
                        wall_horizontal = normalize (cross wall_vertical wall_normal)
                    )
                    else
                    (
                        local longest_vector = [0,0,0]

                        for edge_index in border_edges do
                        (
                            local edge_verts = polyop.getEdgeVerts base_obj edge_index
                            if edge_verts != undefined and edge_verts.count == 2 then
                            (
                                local edge_vector = world_points[edge_verts[2]] - world_points[edge_verts[1]]
                                if length edge_vector > length longest_vector then
                                (
                                    longest_vector = edge_vector
                                )
                            )
                        )

                        if length longest_vector > epsilon then
                        (
                            wall_horizontal = normalize longest_vector
                            wall_vertical = normalize (cross wall_normal wall_horizontal)
                        )
                    )

                    if wall_horizontal != undefined and wall_vertical != undefined then
                    (
                        append result #(
                            region_faces,
                            wall_normal,
                            wall_origin,
                            border_edges,
                            vertex_border_edges,
                            wall_horizontal,
                            wall_vertical,
                            region_id,
                            world_points
                        )
                    )
                )
            )
        )

        result
        -- return
    ),

    /*
    Analyzes every planar wall region in the unchanged Editable Poly base object.
    Each candidate keeps the wall-region frame so bent wall objects do not inherit the first face normal.
    */
    function getBaseInnerSliceCandidates node angle_threshold:5.0 source_vertices:undefined planar_tolerance:1.0 =
    (
        local result = #()
        if node == undefined or not(isValidNode node) then return result

        local base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then return result

        local edge_count = polyop.getNumEdges base_obj
        local planar_regions = getBasePlanarWallRegions node planar_tolerance:planar_tolerance
        if planar_regions.count == 0 then return result

        local direction_cos = cos (amin 45.0 (amax 0.0 angle_threshold))

        for region_data in planar_regions do
        (
            local wall_normal = region_data[2]
            local wall_origin = region_data[3]
            local border_edges = region_data[4]
            local vertex_border_edges = region_data[5]
            local wall_horizontal = region_data[6]
            local wall_vertical = region_data[7]
            local region_id = region_data[8]
            local world_points = region_data[9]

            local edge_kinds = for edge_index = 1 to edge_count collect #diagonal
            for edge_index in border_edges do
            (
                local edge_verts = polyop.getEdgeVerts base_obj edge_index
                if edge_verts != undefined and edge_verts.count == 2 then
                (
                    local edge_vector = world_points[edge_verts[2]] - world_points[edge_verts[1]]
                    if length edge_vector > epsilon then
                    (
                        edge_vector = normalize edge_vector
                        if abs(dot edge_vector wall_horizontal) >= direction_cos then
                        (
                            edge_kinds[edge_index] = #horizontal
                        )
                        else if abs(dot edge_vector wall_vertical) >= direction_cos then
                        (
                            edge_kinds[edge_index] = #vertical
                        )
                    )
                )
            )

            local remaining_edges = copy border_edges
            local loops = #()

            while remaining_edges.numberSet > 0 do
            (
                local start_edge = (remaining_edges as array)[1]
                local start_edge_verts = polyop.getEdgeVerts base_obj start_edge

                if start_edge_verts == undefined or start_edge_verts.count != 2 then
                (
                    remaining_edges[start_edge] = false
                )
                else
                (
                    local start_vertex = start_edge_verts[1]
                    local current_vertex = start_vertex
                    local current_edge = start_edge
                    local loop_vertices = #()
                    local closed = false
                    local safety = 0

                    while not closed and safety <= edge_count do
                    (
                        safety += 1
                        append loop_vertices current_vertex
                        remaining_edges[current_edge] = false

                        local current_edge_verts = polyop.getEdgeVerts base_obj current_edge
                        local next_vertex = if current_edge_verts[1] == current_vertex then current_edge_verts[2] else current_edge_verts[1]

                        if next_vertex == start_vertex then
                        (
                            closed = true
                        )
                        else
                        (
                            local next_edges = (vertex_border_edges[next_vertex] * border_edges) as array
                            if next_edges.count != 2 then
                            (
                                safety = edge_count + 1
                            )
                            else
                            (
                                local next_edge = if next_edges[1] == current_edge then next_edges[2] else next_edges[1]
                                current_vertex = next_vertex
                                current_edge = next_edge
                            )
                        )
                    )

                    if closed and loop_vertices.count >= 3 then
                    (
                        append loops loop_vertices
                    )
                )
            )

            if loops.count > 0 then
            (
                local loop_areas = #()
                for loop_vertices in loops do
                (
                    local loop_area = 0.0
                    local loop_origin = world_points[loop_vertices[1]]

                    for loop_position = 1 to loop_vertices.count do
                    (
                        local next_position = if loop_position == loop_vertices.count then 1 else loop_position + 1
                        local point_a = world_points[loop_vertices[loop_position]] - loop_origin
                        local point_b = world_points[loop_vertices[next_position]] - loop_origin
                        local point_a_x = dot point_a wall_horizontal
                        local point_a_y = dot point_a wall_vertical
                        local point_b_x = dot point_b wall_horizontal
                        local point_b_y = dot point_b wall_vertical
                        loop_area += point_a_x * point_b_y - point_b_x * point_a_y
                    )

                    append loop_areas (loop_area * 0.5)
                )

                local outer_index = 1
                local outer_area = abs(loop_areas[1])
                for loop_index = 2 to loops.count do
                (
                    local current_area = abs(loop_areas[loop_index])
                    if current_area > outer_area then
                    (
                        outer_area = current_area
                        outer_index = loop_index
                    )
                )

                for loop_index = 1 to loops.count do
                (
                    local loop_vertices = loops[loop_index]
                    local signed_area = loop_areas[loop_index]
                    local orientation = if signed_area >= 0.0 then 1.0 else -1.0

                    for corner_index = 1 to loop_vertices.count do
                    (
                        local vertex_index = loop_vertices[corner_index]
                        local border_at_vertex = (vertex_border_edges[vertex_index] * border_edges) as array

                        if border_at_vertex.count == 2 then
                        (
                            local previous_index = if corner_index == 1 then loop_vertices.count else corner_index - 1
                            local next_index = if corner_index == loop_vertices.count then 1 else corner_index + 1
                            local previous_vertex = loop_vertices[previous_index]
                            local next_vertex = loop_vertices[next_index]
                            local dir_a = world_points[previous_vertex] - world_points[vertex_index]
                            local dir_b = world_points[next_vertex] - world_points[vertex_index]

                            if length dir_a > epsilon and length dir_b > epsilon then
                            (
                                dir_a = normalize dir_a
                                dir_b = normalize dir_b
                                local is_straight = abs(dot dir_a dir_b) >= direction_cos
                                local is_inner = false

                                if not is_straight then
                                (
                                    is_inner = loop_index != outer_index

                                    if not is_inner then
                                    (
                                        local point_0 = world_points[previous_vertex]
                                        local point_1 = world_points[vertex_index]
                                        local point_2 = world_points[next_vertex]
                                        local x_0 = dot point_0 wall_horizontal
                                        local y_0 = dot point_0 wall_vertical
                                        local x_1 = dot point_1 wall_horizontal
                                        local y_1 = dot point_1 wall_vertical
                                        local x_2 = dot point_2 wall_horizontal
                                        local y_2 = dot point_2 wall_vertical
                                        local turn_cross = ((x_1 - x_0) * (y_2 - y_1)) - ((y_1 - y_0) * (x_2 - x_1))
                                        is_inner = (turn_cross * orientation) < -epsilon
                                    )
                                )

                                if source_vertices != undefined then
                                (
                                    local source_enabled = vertex_index <= source_vertices.count and source_vertices[vertex_index]
                                    is_inner = is_inner and source_enabled
                                )

                                if is_inner then
                                (
                                    local can_vertical = false
                                    local can_horizontal = false
                                    local vertical_base_edge = 0
                                    local horizontal_base_edge = 0

                                    for edge_index in border_at_vertex do
                                    (
                                        local edge_kind = edge_kinds[edge_index]

                                        if edge_kind == #vertical then
                                        (
                                            can_vertical = true
                                            vertical_base_edge = edge_index
                                        )

                                        if edge_kind == #horizontal then
                                        (
                                            can_horizontal = true
                                            horizontal_base_edge = edge_index
                                        )
                                    )

                                    local vertical_edge_axis = undefined
                                    local horizontal_edge_axis = undefined

                                    if vertical_base_edge > 0 then
                                    (
                                        local vertical_edge_verts = polyop.getEdgeVerts base_obj vertical_base_edge
                                        if vertical_edge_verts != undefined and vertical_edge_verts.count == 2 then
                                        (
                                            local vertical_other = if vertical_edge_verts[1] == vertex_index then vertical_edge_verts[2] else vertical_edge_verts[1]
                                            local vertical_line = world_points[vertical_other] - world_points[vertex_index]

                                            if length vertical_line > epsilon then
                                            (
                                                vertical_line = normalize vertical_line
                                                vertical_edge_axis = cross vertical_line wall_normal

                                                if length vertical_edge_axis > epsilon then
                                                (
                                                    vertical_edge_axis = normalize vertical_edge_axis
                                                )
                                                else
                                                (
                                                    vertical_edge_axis = undefined
                                                )
                                            )
                                        )
                                    )

                                    if horizontal_base_edge > 0 then
                                    (
                                        local horizontal_edge_verts = polyop.getEdgeVerts base_obj horizontal_base_edge
                                        if horizontal_edge_verts != undefined and horizontal_edge_verts.count == 2 then
                                        (
                                            local horizontal_other = if horizontal_edge_verts[1] == vertex_index then horizontal_edge_verts[2] else horizontal_edge_verts[1]
                                            local horizontal_line = world_points[horizontal_other] - world_points[vertex_index]

                                            if length horizontal_line > epsilon then
                                            (
                                                horizontal_line = normalize horizontal_line
                                                horizontal_edge_axis = cross horizontal_line wall_normal

                                                if length horizontal_edge_axis > epsilon then
                                                (
                                                    horizontal_edge_axis = normalize horizontal_edge_axis
                                                )
                                                else
                                                (
                                                    horizontal_edge_axis = undefined
                                                )
                                            )
                                        )
                                    )

                                    /*
                                    Store the region normal/origin with every candidate.
                                    The fixed queue can later remap the same planar wall after prior cuts changed face IDs.
                                    */
                                    append result #(
                                        vertex_index,
                                        can_vertical,
                                        can_horizontal,
                                        vertical_base_edge,
                                        horizontal_base_edge,
                                        world_points[vertex_index],
                                        vertical_edge_axis,
                                        horizontal_edge_axis,
                                        wall_horizontal,
                                        wall_vertical,
                                        wall_normal,
                                        wall_origin,
                                        region_id
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )

        if not batch_quiet then format "Wall-Fixer Base Planar Analysis: node:% regions:% candidates:%\n" node.name planar_regions.count result.count
        result
        -- return
    ),

    /*
    Returns base-object inner-corner vertices still available for the next Make 1 Slice pass.
    For All mode, vertical candidates have priority until exhausted, then horizontal candidates are returned.
    */
    function getAvailableBaseSliceCornerSelection node cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 =
    (
        local result = #{}
        local base_candidates = getBaseInnerSliceCandidates node angle_threshold:angle_threshold planar_tolerance:planar_tolerance
        if base_candidates.count == 0 then return result

        local requested_kinds = #()
        if cut_mode == #all or cut_mode == #vertical then append requested_kinds #vertical
        if cut_mode == #all or cut_mode == #horizontal then append requested_kinds #horizontal

        for slice_kind in requested_kinds while result.numberSet == 0 do
        (
            local available_plane_records = #()
            local available_edges = #{}

            for candidate in base_candidates do
            (
                local base_vertex = candidate[1]
                local direction_available = if slice_kind == #vertical then candidate[2] else candidate[3]
                local base_edge = if slice_kind == #vertical then candidate[4] else candidate[5]
                local base_anchor = candidate[6]
                local base_axis = undefined

                if slice_plane_mode == #nextVert then
                (
                    base_axis = if slice_kind == #vertical then candidate[7] else candidate[8]
                )
                else
                (
                    base_axis = if slice_kind == #vertical then candidate[9] else candidate[10]
                )

                if direction_available and base_axis != undefined then
                (
                    local already_processed = false
                    local duplicate_available = false

                    if slice_plane_mode == #nextVert then
                    (
                        already_processed = isBaseSliceEdgeProcessed node base_edge slice_kind
                        duplicate_available = base_edge > 0 and base_edge <= available_edges.count and available_edges[base_edge]
                    )
                    else
                    (
                        already_processed = isBaseSlicePlaneProcessed node base_anchor base_axis slice_kind
                        duplicate_available = hasSlicePlaneRecord base_anchor base_axis available_plane_records
                    )

                    if not already_processed and not duplicate_available then
                    (
                        result[base_vertex] = true
                        if slice_plane_mode == #nextVert then
                        (
                            if base_edge > 0 then available_edges[base_edge] = true
                        )
                        else
                        (
                            append available_plane_records #(normalize base_axis, base_anchor)
                        )
                    )
                )
            )
        )

        result
        -- return
    ),

    /*
    Returns Reset Slicing INNER VERTS that still need a requested slice direction.
    A vertex is removed only after every available requested direction for that vertex was processed.
    */
    function getRemainingResetInnerVertSelection node cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 =
    (
        local reset_inner_vertices = getResetInnerVertSelection node
        if reset_inner_vertices == undefined then return undefined

        local remaining_vertices = copy reset_inner_vertices
        local base_candidates = getBaseInnerSliceCandidates node angle_threshold:angle_threshold source_vertices:reset_inner_vertices planar_tolerance:planar_tolerance planar_tolerance:planar_tolerance
        local request_vertical = cut_mode == #all or cut_mode == #vertical
        local request_horizontal = cut_mode == #all or cut_mode == #horizontal

        for candidate in base_candidates do
        (
            local base_vertex = candidate[1]
            local requested_direction_count = 0
            local processed_direction_count = 0

            if request_vertical and candidate[2] then
            (
                local vertical_base_edge = candidate[4]
                local vertical_anchor = candidate[6]
                local vertical_axis = if slice_plane_mode == #nextVert then candidate[7] else candidate[9]

                if vertical_axis != undefined then
                (
                    requested_direction_count += 1
                    local vertical_processed = if slice_plane_mode == #nextVert then
                    (
                        isBaseSliceEdgeProcessed node vertical_base_edge #vertical
                    )
                    else
                    (
                        isBaseSlicePlaneProcessed node vertical_anchor vertical_axis #vertical
                    )
                    if vertical_processed then processed_direction_count += 1
                )
            )

            if request_horizontal and candidate[3] then
            (
                local horizontal_base_edge = candidate[5]
                local horizontal_anchor = candidate[6]
                local horizontal_axis = if slice_plane_mode == #nextVert then candidate[8] else candidate[10]

                if horizontal_axis != undefined then
                (
                    requested_direction_count += 1
                    local horizontal_processed = if slice_plane_mode == #nextVert then
                    (
                        isBaseSliceEdgeProcessed node horizontal_base_edge #horizontal
                    )
                    else
                    (
                        isBaseSlicePlaneProcessed node horizontal_anchor horizontal_axis #horizontal
                    )
                    if horizontal_processed then processed_direction_count += 1
                )
            )

            if requested_direction_count > 0 and processed_direction_count == requested_direction_count then
            (
                remaining_vertices[base_vertex] = false
            )
        )

        remaining_vertices
        -- return
    ),

    /*
    Returns true when the exact Edit Poly modifier instance exists on the supplied node.
    This keeps CHECK DOUBLE FACES bound to the current modifier instead of any arbitrary stack modifier.
    */
    function nodeHasEditPolyModifier node modifier =
    (
        if node == undefined or modifier == undefined then return false
        if not(isValidNode node) or classOf modifier != Edit_Poly then return false

        found_modifier = false
        for stack_modifier in node.modifiers while not found_modifier do
        (
            if stack_modifier == modifier then found_modifier = true
        )

        found_modifier
        -- return
    ),

    /*
    Returns the geometry source used by CHECK DOUBLE FACES for one node.
    The current Edit Poly modifier wins; otherwise the Editable Poly base object is used.
    */
    function getDoubleFaceSource node active_edit_poly =
    (
        if node == undefined or not(isValidNode node) then return undefined

        if active_edit_poly != undefined and nodeHasEditPolyModifier node active_edit_poly then
        (
            #(#editPoly, active_edit_poly)
        )
        else if classOf node.baseObject == Editable_Poly then
        (
            #(#editablePoly, node.baseObject)
        )
        else
        (
            undefined
        )
        -- return
    ),

    /*
    Returns one face selection BitArray from either the current Edit Poly modifier or Editable Poly base.
    Undefined selections are normalized to an empty BitArray.
    */
    function getDoubleFaceSourceSelection node source_kind source_ref =
    (
        face_selection = #{}

        try
        (
            if source_kind == #editPoly then
            (
                face_selection = source_ref.GetSelection #Face node:node
            )
            else
            (
                face_selection = polyop.getFaceSelection source_ref
            )
        )
        catch
        (
            face_selection = #{}
        )

        if face_selection == undefined then face_selection = #{}
        copy face_selection
        -- return
    ),

    /*
    Writes one face selection to either the current Edit Poly modifier or Editable Poly base.
    No modifier is created and no object is collapsed by this operation.
    */
    function setDoubleFaceSourceSelection node source_kind source_ref face_selection =
    (
        if node == undefined or not(isValidNode node) then return false

        try
        (
            if source_kind == #editPoly then
            (
                source_ref.SetPrimaryNode node
                source_ref.useStackSelection = false
                source_ref.SetSelection #Face face_selection node:node
            )
            else
            (
                polyop.setFaceSelection source_ref face_selection
            )
            true
        )
        catch
        (
            false
        )
        -- return
    ),

    /*
    Builds one world-space polygon record for a face at the selected editing level.
    Record layout is #(source_index, face_index, world_points, center, normal, was_selected).
    */
    function buildDoubleFaceRecord node source_index source_kind source_ref face_index source_selection =
    (
        if node == undefined or not(isValidNode node) then return undefined

        face_vertices = #()
        vertex_points = #()

        try
        (
            if source_kind == #editPoly then
            (
                face_degree = source_ref.GetFaceDegree face_index node:node
                if face_degree == undefined or face_degree < 3 then return undefined

                for corner_index = 1 to face_degree do
                (
                    vertex_index = source_ref.GetFaceVertex face_index corner_index node:node
                    if vertex_index == undefined or vertex_index < 1 then return undefined
                    append face_vertices vertex_index
                )

                for vertex_index in face_vertices do
                (
                    vertex_position = source_ref.GetVertex vertex_index node:node
                    if vertex_position == undefined then return undefined
                    append vertex_points (vertex_position * node.objectTransform)
                )
            )
            else
            (
                face_vertices = polyop.getFaceVerts source_ref face_index
                if face_vertices == undefined or face_vertices.count < 3 then return undefined

                for vertex_index in face_vertices do
                (
                    append vertex_points ((polyop.getVert source_ref vertex_index) * node.objectTransform)
                )
            )
        )
        catch
        (
            return undefined
        )

        if vertex_points.count < 3 then return undefined

        center_point = [0,0,0]
        for vertex_point in vertex_points do center_point += vertex_point
        center_point = center_point / vertex_points.count

        normal_sum = [0,0,0]
        origin_point = vertex_points[1]
        for point_index = 2 to (vertex_points.count - 1) do
        (
            normal_sum += cross (vertex_points[point_index] - origin_point) (vertex_points[point_index + 1] - origin_point)
        )

        if length normal_sum <= epsilon then return undefined
        face_normal = normalize normal_sum
        was_selected = if face_index <= source_selection.count then source_selection[face_index] else false

        #(source_index, face_index, vertex_points, center_point, face_normal, was_selected)
        -- return
    ),

    /*
    Projects a world-space point to a stable 2D plane by dropping the dominant normal axis.
    The result is a two-number array so no external geometry helper is required.
    */
    function projectDoubleFacePoint2D point drop_axis =
    (
        case drop_axis of
        (
            1: #(point.y, point.z)
            2: #(point.x, point.z)
            default: #(point.x, point.y)
        )
        -- return
    ),

    /*
    Returns the signed 2D orientation for three projected points.
    Positive and negative values represent opposite turn directions.
    */
    function getDoubleFaceOrientation2D point_a point_b point_c =
    (
        ((point_b[1] - point_a[1]) * (point_c[2] - point_a[2])) - \
        ((point_b[2] - point_a[2]) * (point_c[1] - point_a[1]))
        -- return
    ),

    /*
    Returns true when a projected point lies on one projected line segment within tolerance.
    This treats touching face boundaries as valid projected overlap.
    */
    function isDoubleFacePointOnSegment2D point_value point_a point_b tolerance:0.0001 =
    (
        orientation = getDoubleFaceOrientation2D point_a point_b point_value
        if abs orientation > tolerance then return false

        point_value[1] >= ((amin point_a[1] point_b[1]) - tolerance) and \
        point_value[1] <= ((amax point_a[1] point_b[1]) + tolerance) and \
        point_value[2] >= ((amin point_a[2] point_b[2]) - tolerance) and \
        point_value[2] <= ((amax point_a[2] point_b[2]) + tolerance)
        -- return
    ),

    /*
    Returns true when two projected polygon edges intersect or touch.
    The test handles both crossing and collinear boundary contact.
    */
    function doDoubleFaceSegmentsIntersect2D a1 a2 b1 b2 tolerance:0.0001 =
    (
        orientation_a = getDoubleFaceOrientation2D a1 a2 b1
        orientation_b = getDoubleFaceOrientation2D a1 a2 b2
        orientation_c = getDoubleFaceOrientation2D b1 b2 a1
        orientation_d = getDoubleFaceOrientation2D b1 b2 a2

        if (((orientation_a > tolerance) and (orientation_b < -tolerance)) or ((orientation_a < -tolerance) and (orientation_b > tolerance))) and \
           (((orientation_c > tolerance) and (orientation_d < -tolerance)) or ((orientation_c < -tolerance) and (orientation_d > tolerance))) then return true

        if abs orientation_a <= tolerance and isDoubleFacePointOnSegment2D b1 a1 a2 tolerance:tolerance then return true
        if abs orientation_b <= tolerance and isDoubleFacePointOnSegment2D b2 a1 a2 tolerance:tolerance then return true
        if abs orientation_c <= tolerance and isDoubleFacePointOnSegment2D a1 b1 b2 tolerance:tolerance then return true
        if abs orientation_d <= tolerance and isDoubleFacePointOnSegment2D a2 b1 b2 tolerance:tolerance then return true

        false
        -- return
    ),

    /*
    Returns true when one projected point is inside or on the boundary of a polygon.
    A standard odd-even ray crossing test supports convex and concave wall faces.
    */
    function isDoubleFacePointInPolygon2D point_value polygon tolerance:0.0001 =
    (
        if polygon == undefined or polygon.count < 3 then return false

        previous_index = polygon.count
        inside = false

        for current_index = 1 to polygon.count do
        (
            point_a = polygon[previous_index]
            point_b = polygon[current_index]

            if isDoubleFacePointOnSegment2D point_value point_a point_b tolerance:tolerance then return true

            if ((point_a[2] > point_value[2]) != (point_b[2] > point_value[2])) then
            (
                crossing_x = ((point_b[1] - point_a[1]) * (point_value[2] - point_a[2]) / (point_b[2] - point_a[2])) + point_a[1]
                if point_value[1] < crossing_x then inside = not inside
            )

            previous_index = current_index
        )

        inside
        -- return
    ),

    /*
    Returns true when two nearly parallel world-space face polygons overlap in projection.
    Vertex containment and edge intersections avoid pairing unrelated nearby parallel walls.
    */
    function doDoubleFacePolygonsOverlap record_a record_b tolerance:0.0001 =
    (
        normal_value = record_a[5]
        normal_abs = [abs normal_value.x, abs normal_value.y, abs normal_value.z]
        drop_axis = 3
        if normal_abs.x >= normal_abs.y and normal_abs.x >= normal_abs.z then
        (
            drop_axis = 1
        )
        else if normal_abs.y >= normal_abs.z then
        (
            drop_axis = 2
        )

        polygon_a = #()
        polygon_b = #()
        for point_value in record_a[3] do append polygon_a (projectDoubleFacePoint2D point_value drop_axis)
        for point_value in record_b[3] do append polygon_b (projectDoubleFacePoint2D point_value drop_axis)

        for point_value in polygon_a do
        (
            if isDoubleFacePointInPolygon2D point_value polygon_b tolerance:tolerance then return true
        )

        for point_value in polygon_b do
        (
            if isDoubleFacePointInPolygon2D point_value polygon_a tolerance:tolerance then return true
        )

        for index_a = 1 to polygon_a.count do
        (
            next_a = if index_a == polygon_a.count then 1 else index_a + 1
            for index_b = 1 to polygon_b.count do
            (
                next_b = if index_b == polygon_b.count then 1 else index_b + 1
                if doDoubleFaceSegmentsIntersect2D polygon_a[index_a] polygon_a[next_a] polygon_b[index_b] polygon_b[next_b] tolerance:tolerance then return true
            )
        )

        false
        -- return
    ),

    /*
    Finds opposing overlapping face pairs on selected objects and writes the resulting face selections.
    RMB mode can keep only already-selected faces whose normals point toward their paired wall faces.
    */
    function checkDoubleFaces max_distance:100.0 inward_only:false use_existing_selection:false angle_threshold:5.0 =
    (
        selected_nodes = selection as array
        last_slice_report = ""
        last_slice_error = undefined

        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select one or more wall objects before running CHECK DOUBLE FACES."
            return false
        )

        active_edit_poly = undefined
        try
        (
            current_object = modPanel.getCurrentObject()
            if current_object != undefined and classOf current_object == Edit_Poly then active_edit_poly = current_object
        )
        catch
        (
            active_edit_poly = undefined
        )

        source_records = #()
        face_records = #()
        had_face_selection = false

        for node in selected_nodes do
        (
            source_data = getDoubleFaceSource node active_edit_poly
            if source_data != undefined then
            (
                source_kind = source_data[1]
                source_ref = source_data[2]
                source_selection = getDoubleFaceSourceSelection node source_kind source_ref
                if source_selection.numberSet > 0 then had_face_selection = true

                face_count = 0
                try
                (
                    face_count = if source_kind == #editPoly then source_ref.GetNumFaces node:node else polyop.getNumFaces source_ref
                )
                catch
                (
                    face_count = 0
                )

                if face_count > 0 then
                (
                    source_index = source_records.count + 1
                    append source_records #(node, source_kind, source_ref, face_count, source_selection)

                    for face_index = 1 to face_count do
                    (
                        face_record = buildDoubleFaceRecord node source_index source_kind source_ref face_index source_selection
                        if face_record != undefined then append face_records face_record
                    )
                )
            )
        )

        if source_records.count == 0 or face_records.count < 2 then
        (
            last_slice_report = "CHECK DOUBLE FACES requires Editable Poly objects or the current Edit Poly modifier with at least two valid faces."
            return false
        )

        output_selections = #()
        for source_record in source_records do append output_selections #{}

        opposite_cos = cos angle_threshold
        pair_count = 0
        inward_pair_count = 0

        for record_a_index = 1 to (face_records.count - 1) do
        (
            record_a = face_records[record_a_index]

            for record_b_index = (record_a_index + 1) to face_records.count do
            (
                record_b = face_records[record_b_index]
                normal_dot = dot record_a[5] record_b[5]

                if normal_dot <= -opposite_cos then
                (
                    center_delta = record_b[4] - record_a[4]
                    distance_a = abs(dot center_delta record_a[5])
                    distance_b = abs(dot center_delta record_b[5])
                    plane_distance = amax distance_a distance_b

                    if plane_distance <= max_distance and doDoubleFacePolygonsOverlap record_a record_b then
                    (
                        pair_count += 1
                        faces_point_toward = (dot record_a[5] center_delta) > epsilon and (dot record_b[5] (-center_delta)) > epsilon
                        if faces_point_toward then inward_pair_count += 1

                        if inward_only then
                        (
                            if faces_point_toward then
                            (
                                if (not use_existing_selection) or (not had_face_selection) or record_a[6] then
                                (
                                    output_selections[record_a[1]][record_a[2]] = true
                                )
                                if (not use_existing_selection) or (not had_face_selection) or record_b[6] then
                                (
                                    output_selections[record_b[1]][record_b[2]] = true
                                )
                            )
                        )
                        else
                        (
                            output_selections[record_a[1]][record_a[2]] = true
                            output_selections[record_b[1]][record_b[2]] = true
                        )
                    )
                )
            )
        )

        selected_face_count = 0
        for source_index = 1 to source_records.count do
        (
            source_record = source_records[source_index]
            setDoubleFaceSourceSelection source_record[1] source_record[2] source_record[3] output_selections[source_index]
            selected_face_count += output_selections[source_index].numberSet
        )

        max modify mode
        if active_edit_poly != undefined then
        (
            primary_node = undefined
            for source_record in source_records while primary_node == undefined do
            (
                if source_record[2] == #editPoly then primary_node = source_record[1]
            )

            if primary_node != undefined then
            (
                active_edit_poly.SetPrimaryNode primary_node
                modPanel.setCurrentObject active_edit_poly
                active_edit_poly.SetEPolySelLevel #Face
                subObjectLevel = 4
            )
        )
        else if source_records.count > 0 then
        (
            first_source = source_records[1]
            if first_source[2] == #editablePoly then
            (
                modPanel.setCurrentObject first_source[3]
                subObjectLevel = 4
            )
        )

        last_slice_report = "CHECK DOUBLE FACES:\n" + \
            "  PAIRS: " + (pair_count as string) + "\n" + \
            "  INWARD PAIRS: " + (inward_pair_count as string) + "\n" + \
            "  SELECTED FACES: " + (selected_face_count as string) + "\n" + \
            "  MAX DISTANCE: " + (max_distance as string)

        if not batch_quiet then format "%\n" last_slice_report
        completeRedraw()
        true
        -- return
    ),

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
    Returns true when the slicer can evaluate an Editable Poly base or an existing Edit Poly modifier.
    This is intentionally separate from isSupportedNode because PolyOp-only tools still require Editable Poly.
    */
    function isSliceSupportedNode node =
    (
        if node == undefined or not(isValidNode node) then
        (
            false
        )
        else
        (
            if classOf node.baseObject == Editable_Poly then
            (
                true
            )
            else
            (
                supported = false
                for modifier in node.modifiers while not supported do
                (
                    if classOf modifier == Edit_Poly then supported = true
                )
                supported
            )
        )
        -- return
    ),

    /*
    Returns a normalized direction from one modifier vertex along one incident edge.
    Undefined is returned for dead, disconnected or zero-length edges.
    */
    function getRedundantLoopEdgeDirection node modifier vertex_index edge_index edge_vertices vertex_points =
    (
        if vertex_index < 1 or vertex_index > vertex_points.count then return undefined
        if edge_index < 1 or edge_index > edge_vertices.count then return undefined

        edge_pair = edge_vertices[edge_index]
        if edge_pair == undefined or edge_pair.count != 2 then return undefined

        other_vertex = 0
        if edge_pair[1] == vertex_index then
        (
            other_vertex = edge_pair[2]
        )
        else if edge_pair[2] == vertex_index then
        (
            other_vertex = edge_pair[1]
        )

        if other_vertex < 1 or other_vertex > vertex_points.count then return undefined
        if vertex_points[vertex_index] == undefined or vertex_points[other_vertex] == undefined then return undefined

        edge_direction = vertex_points[other_vertex] - vertex_points[vertex_index]
        if length edge_direction <= epsilon then return undefined

        normalize edge_direction
        -- return
    ),

    /*
    Returns true when all supplied incident edges can be paired as straight continuations through one vertex.
    An empty set is valid; any unpaired or bent continuation is rejected.
    */
    function areRedundantLoopEdgesStraightPairs node modifier vertex_index edge_set edge_vertices vertex_points angle_threshold:0.1 =
    (
        if edge_set.numberSet == 0 then return true
        if (mod edge_set.numberSet 2) != 0 then return false

        pending_edges = edge_set as array
        straight_limit = cos angle_threshold

        while pending_edges.count > 0 do
        (
            first_edge = pending_edges[1]
            first_direction = getRedundantLoopEdgeDirection node modifier vertex_index first_edge edge_vertices vertex_points
            if first_direction == undefined then return false

            pair_index = 0
            for index = 2 to pending_edges.count while pair_index == 0 do
            (
                pair_direction = getRedundantLoopEdgeDirection node modifier vertex_index pending_edges[index] edge_vertices vertex_points
                if pair_direction != undefined then
                (
                    if dot first_direction pair_direction <= -straight_limit then pair_index = index
                )
            )

            if pair_index == 0 then return false
            deleteItem pending_edges pair_index
            deleteItem pending_edges 1
        )

        true
        -- return
    ),

    /*
    Returns true when every live face incident to one vertex stays on the reference plane direction.
    Smoothing groups are intentionally ignored; only geometric face normals are tested.
    */
    function isRedundantLoopVertexPlanar vertex_index vertex_faces face_normals face_valid reference_normal angle_threshold:0.1 =
    (
        if vertex_index < 1 or vertex_index > vertex_faces.count then return false
        if reference_normal == undefined or length reference_normal <= epsilon then return false

        normal_limit = cos angle_threshold
        live_face_count = 0

        for face_index in vertex_faces[vertex_index] do
        (
            if face_index >= 1 and face_index <= face_normals.count then
            (
                if face_index <= face_valid.count and face_valid[face_index] then
                (
                    face_normal = face_normals[face_index]
                    if face_normal == undefined then return false
                    live_face_count += 1
                    if abs(dot reference_normal face_normal) < normal_limit then return false
                )
            )
        )

        live_face_count > 0
        -- return
    ),

    /*
    Validates a completed border-to-border chain without changing topology.
    Endpoints must split straight borders; internal transverse edges must continue straight and every incident face must stay planar.
    */
    function validateRedundantLoopChain node modifier chain_edges chain_vertices start_vertex end_vertex border_edges vertex_edges vertex_faces edge_vertices vertex_points face_normals face_valid reference_normal angle_threshold:0.1 =
    (
        if chain_edges.numberSet == 0 then return #(false, "empty chain")
        if chain_vertices.count < 2 then return #(false, "chain has fewer than two vertices")
        if start_vertex == end_vertex then return #(false, "chain returns to the same border vertex")

        for vertex_index in chain_vertices do
        (
            if not(isRedundantLoopVertexPlanar vertex_index vertex_faces face_normals face_valid reference_normal angle_threshold:angle_threshold) then
            (
                return #(false, "incident faces are not coplanar at vertex " + (vertex_index as string))
            )

            incident_edges = vertex_edges[vertex_index]
            chain_incident_edges = incident_edges * chain_edges
            border_incident_edges = incident_edges * border_edges
            is_endpoint = vertex_index == start_vertex or vertex_index == end_vertex

            if is_endpoint then
            (
                if chain_incident_edges.numberSet != 1 then
                (
                    return #(false, "endpoint does not have exactly one loop edge at vertex " + (vertex_index as string))
                )
                if border_incident_edges.numberSet != 2 then
                (
                    return #(false, "endpoint is not inside one straight border segment at vertex " + (vertex_index as string))
                )
                if not(areRedundantLoopEdgesStraightPairs node modifier vertex_index border_incident_edges edge_vertices vertex_points angle_threshold:angle_threshold) then
                (
                    return #(false, "endpoint is a border corner at vertex " + (vertex_index as string))
                )

                extra_edges = incident_edges - chain_incident_edges - border_incident_edges
                if extra_edges.numberSet > 0 then
                (
                    return #(false, "endpoint has additional geometry at vertex " + (vertex_index as string))
                )
            )
            else
            (
                if border_incident_edges.numberSet > 0 then
                (
                    return #(false, "chain touches a border before its endpoint at vertex " + (vertex_index as string))
                )
                if chain_incident_edges.numberSet != 2 then
                (
                    return #(false, "internal chain vertex does not have exactly two loop edges at vertex " + (vertex_index as string))
                )
                if not(areRedundantLoopEdgesStraightPairs node modifier vertex_index chain_incident_edges edge_vertices vertex_points angle_threshold:angle_threshold) then
                (
                    return #(false, "loop changes direction at vertex " + (vertex_index as string))
                )

                transverse_edges = incident_edges - chain_incident_edges
                if transverse_edges.numberSet > 0 then
                (
                    if not(areRedundantLoopEdgesStraightPairs node modifier vertex_index transverse_edges edge_vertices vertex_points angle_threshold:angle_threshold) then
                    (
                        return #(false, "transverse continuation changes direction at vertex " + (vertex_index as string))
                    )
                )
            )
        )

        #(true, "")
        -- return
    ),

    /*
    Detects geometrically redundant straight internal loops on the current Edit Poly topology.
    Returns #(loop_records, all_redundant_edges); each loop record is #(edge_bitarray, start_vertex, end_vertex).
    */
    function detectRedundantLoops node modifier angle_threshold:0.1 debug_output:false =
    (
        loop_records = #()
        all_redundant_edges = #{}

        if node == undefined or not(isValidNode node) then return #(loop_records, all_redundant_edges)
        if modifier == undefined or classOf modifier != Edit_Poly then return #(loop_records, all_redundant_edges)

        update node
        vertex_count = modifier.GetNumVertices node:node
        edge_count = modifier.GetNumEdges node:node
        face_count = modifier.GetNumFaces node:node
        if vertex_count < 2 or edge_count < 1 or face_count < 1 then return #(loop_records, all_redundant_edges)

        vertex_points = #()
        vertex_edges = #()
        vertex_faces = #()
        for vertex_index = 1 to vertex_count do
        (
            append vertex_points (modifier.GetVertex vertex_index node:node)
            append vertex_edges #{}
            append vertex_faces #{}
        )

        edge_vertices = #()
        edge_faces = #()
        border_edges = #{}
        border_vertices = #{}

        for edge_index = 1 to edge_count do
        (
            edge_a = modifier.GetEdgeVertex edge_index 1 node:node
            edge_b = modifier.GetEdgeVertex edge_index 2 node:node
            face_a = modifier.GetEdgeFace edge_index 1 node:node
            face_b = modifier.GetEdgeFace edge_index 2 node:node
            edge_live = edge_a != undefined and edge_b != undefined and face_a != undefined and face_b != undefined

            if edge_live then
            (
                edge_live = edge_a >= 1 and edge_a <= vertex_count and edge_b >= 1 and edge_b <= vertex_count
            )
            if edge_live then
            (
                edge_live = vertex_points[edge_a] != undefined and vertex_points[edge_b] != undefined
            )

            if edge_live then
            (
                append edge_vertices #(edge_a, edge_b)
                append edge_faces #(face_a, face_b)
                vertex_edges[edge_a][edge_index] = true
                vertex_edges[edge_b][edge_index] = true

                if (face_a == 0) != (face_b == 0) then
                (
                    border_edges[edge_index] = true
                    border_vertices[edge_a] = true
                    border_vertices[edge_b] = true
                )
            )
            else
            (
                append edge_vertices undefined
                append edge_faces undefined
            )
        )

        face_normals = #()
        face_valid = #{}
        for face_index = 1 to face_count do
        (
            face_degree = modifier.GetFaceDegree face_index node:node
            face_vertex_ids = #()
            face_normal_sum = [0,0,0]
            face_is_valid = face_degree != undefined and face_degree >= 3

            if face_is_valid then
            (
                for corner_index = 1 to face_degree while face_is_valid do
                (
                    face_vertex = modifier.GetFaceVertex face_index corner_index node:node
                    if face_vertex == undefined or face_vertex < 1 or face_vertex > vertex_count then
                    (
                        face_is_valid = false
                    )
                    else if vertex_points[face_vertex] == undefined then
                    (
                        face_is_valid = false
                    )
                    else
                    (
                        append face_vertex_ids face_vertex
                        vertex_faces[face_vertex][face_index] = true
                    )
                )
            )

            if face_is_valid then
            (
                origin_point = vertex_points[face_vertex_ids[1]]
                for corner_index = 2 to (face_vertex_ids.count - 1) do
                (
                    point_b = vertex_points[face_vertex_ids[corner_index]]
                    point_c = vertex_points[face_vertex_ids[corner_index + 1]]
                    face_normal_sum += cross (point_b - origin_point) (point_c - origin_point)
                )
                if length face_normal_sum <= epsilon then face_is_valid = false
            )

            if face_is_valid then
            (
                append face_normals (normalize face_normal_sum)
                face_valid[face_index] = true
            )
            else
            (
                append face_normals undefined
            )
        )

        candidate_edges = #{}
        normal_limit = cos angle_threshold
        for edge_index = 1 to edge_count do
        (
            edge_face_pair = edge_faces[edge_index]
            is_border_edge = edge_index <= border_edges.count and border_edges[edge_index]
            if edge_face_pair != undefined and not is_border_edge then
            (
                face_a = edge_face_pair[1]
                face_b = edge_face_pair[2]
                if face_a > 0 and face_b > 0 and face_a <= face_count and face_b <= face_count then
                (
                    face_a_valid = face_a <= face_valid.count and face_valid[face_a]
                    face_b_valid = face_b <= face_valid.count and face_valid[face_b]
                    if face_a_valid and face_b_valid then
                    (
                        if abs(dot face_normals[face_a] face_normals[face_b]) >= normal_limit then candidate_edges[edge_index] = true
                    )
                )
            )
        )

        accepted_keys = #()
        attempted_keys = #()

        for start_edge in candidate_edges do
        (
            start_edge_vertices = edge_vertices[start_edge]
            if start_edge_vertices != undefined then
            (
                possible_start_vertices = #()
                start_a_is_border = start_edge_vertices[1] <= border_vertices.count and border_vertices[start_edge_vertices[1]]
                start_b_is_border = start_edge_vertices[2] <= border_vertices.count and border_vertices[start_edge_vertices[2]]
                if start_a_is_border then append possible_start_vertices start_edge_vertices[1]
                if start_b_is_border then append possible_start_vertices start_edge_vertices[2]

                for start_vertex in possible_start_vertices do
                (
                    attempt_key = (start_edge as string) + ":" + (start_vertex as string)
                    if findItem attempted_keys attempt_key == 0 then
                    (
                        append attempted_keys attempt_key
                        chain_edges = #{}
                        chain_vertices = #(start_vertex)
                        chain_edges[start_edge] = true
                        previous_vertex = start_vertex
                        current_edge = start_edge
                        current_vertex = if start_edge_vertices[1] == start_vertex then start_edge_vertices[2] else start_edge_vertices[1]
                        append chain_vertices current_vertex
                        rejected_reason = ""
                        completed_chain = false
                        step_count = 0

                        while rejected_reason == "" and not completed_chain and step_count <= edge_count do
                        (
                            step_count += 1

                            current_is_border = current_vertex <= border_vertices.count and border_vertices[current_vertex]
                            if current_is_border then
                            (
                                completed_chain = true
                            )
                            else
                            (
                                incoming_direction = vertex_points[current_vertex] - vertex_points[previous_vertex]
                                if length incoming_direction <= epsilon then
                                (
                                    rejected_reason = "zero-length chain segment"
                                )
                                else
                                (
                                    incoming_direction = normalize incoming_direction
                                    straight_forward_edges = #()
                                    incident_candidates = vertex_edges[current_vertex] * candidate_edges

                                    for candidate_edge in incident_candidates do
                                    (
                                        if candidate_edge != current_edge then
                                        (
                                            candidate_pair = edge_vertices[candidate_edge]
                                            next_vertex = if candidate_pair[1] == current_vertex then candidate_pair[2] else candidate_pair[1]
                                            outgoing_direction = vertex_points[next_vertex] - vertex_points[current_vertex]
                                            if length outgoing_direction > epsilon then
                                            (
                                                outgoing_direction = normalize outgoing_direction
                                                if dot incoming_direction outgoing_direction >= normal_limit then append straight_forward_edges candidate_edge
                                            )
                                        )
                                    )

                                    if straight_forward_edges.count == 0 then
                                    (
                                        rejected_reason = "straight chain stops before reaching another border"
                                    )
                                    else if straight_forward_edges.count > 1 then
                                    (
                                        rejected_reason = "straight chain branches before reaching another border"
                                    )
                                    else
                                    (
                                        next_edge = straight_forward_edges[1]
                                        if chain_edges[next_edge] then
                                        (
                                            rejected_reason = "chain cycles before reaching another border"
                                        )
                                        else
                                        (
                                            next_pair = edge_vertices[next_edge]
                                            next_vertex = if next_pair[1] == current_vertex then next_pair[2] else next_pair[1]
                                            chain_edges[next_edge] = true
                                            previous_vertex = current_vertex
                                            current_vertex = next_vertex
                                            current_edge = next_edge
                                            append chain_vertices current_vertex
                                        )
                                    )
                                )
                            )
                        )

                        if rejected_reason == "" and not completed_chain then rejected_reason = "chain exceeded topology traversal limit"

                        if rejected_reason == "" then
                        (
                            first_edge_faces = edge_faces[start_edge]
                            reference_normal = face_normals[first_edge_faces[1]]
                            validation_result = validateRedundantLoopChain node modifier chain_edges chain_vertices start_vertex current_vertex border_edges vertex_edges vertex_faces edge_vertices vertex_points face_normals face_valid reference_normal angle_threshold:angle_threshold
                            if not validation_result[1] then rejected_reason = validation_result[2]
                        )

                        if rejected_reason == "" then
                        (
                            chain_key = chain_edges as string
                            if findItem accepted_keys chain_key == 0 then
                            (
                                append accepted_keys chain_key
                                append loop_records #(copy chain_edges, start_vertex, current_vertex)
                                all_redundant_edges = all_redundant_edges + chain_edges
                                if debug_output and not batch_quiet then format "Wall-Fixer Redundant Loop Detected: node:% loop:% edges:% startVert:% endVert:%\n" node.name loop_records.count chain_edges start_vertex current_vertex
                            )
                        )
                        else if debug_output then
                        (
                            if not batch_quiet then format "Wall-Fixer Redundant Loop Rejected: node:% startEdge:% startVert:% traversedEdges:% reason:%\n" node.name start_edge start_vertex chain_edges rejected_reason
                        )
                    )
                )
            )
        )

        if debug_output then
        (
            if not batch_quiet then format "Wall-Fixer Redundant Loop Detection Summary: node:% candidateEdges:% loops:% redundantEdges:%\n" node.name candidate_edges loop_records.count all_redundant_edges
        )

        #(loop_records, all_redundant_edges)
        -- return
    ),

    /*
    Detects and removes redundant loops in one dedicated Cleanup LOOPS Edit Poly modifier.
    The modifier is removed again when no valid redundant loops are found.
    */
    function cleanupRedundantLoopsOnNode node angle_threshold:0.1 debug_output:true commit_delete:false =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0, 0, "invalid node")
        if not(isSliceSupportedNode node) then return #(false, 0, 0, "requires Editable Poly geometry or an Edit Poly workflow")

        local cleanup_modifier = undefined
        local operation_error = undefined
        local loop_count = 0
        local redundant_edge_count = 0

        try
        (
            cleanup_modifier = Edit_Poly name:"WMC - CLEANUP LOOPS"
            addModifier node cleanup_modifier
            update node

            select node
            max modify mode
            modPanel.setCurrentObject cleanup_modifier
            cleanup_modifier.SetPrimaryNode node
            cleanup_modifier.useStackSelection = false

            local detection_data = detectRedundantLoops node cleanup_modifier angle_threshold:angle_threshold debug_output:debug_output
            local loop_records = detection_data[1]
            local redundant_edges = detection_data[2]
            loop_count = loop_records.count
            redundant_edge_count = redundant_edges.numberSet

            if redundant_edge_count == 0 then
            (
                deleteModifier node cleanup_modifier
                cleanup_modifier = undefined
                update node

                if debug_output then
                (
                    if not batch_quiet then format "Wall-Fixer Redundant Loop Cleanup: node:% no redundant loops found; Cleanup LOOPS removed.\n" node.name
                )

                return #(true, 0, 0, "")
            )

            local edge_descriptors = #()
            for edge_index in redundant_edges do
            (
                local edge_a = cleanup_modifier.GetEdgeVertex edge_index 1 node:node
                local edge_b = cleanup_modifier.GetEdgeVertex edge_index 2 node:node

                if edge_a == undefined or edge_b == undefined then
                (
                    throw ("Detected redundant-loop edge became invalid before cleanup: " + (edge_index as string))
                )

                local point_a = cleanup_modifier.GetVertex edge_a node:node
                local point_b = cleanup_modifier.GetVertex edge_b node:node

                if point_a == undefined or point_b == undefined then
                (
                    throw ("Detected redundant-loop edge endpoints became invalid before cleanup: " + (edge_index as string))
                )

                append edge_descriptors #(edge_index, point_a, point_b)
            )

            local old_remove_ctrl = cleanup_modifier.remveEdgeCtrlKey
            cleanup_modifier.remveEdgeCtrlKey = false
            cleanup_modifier.SetEPolySelLevel #Edge
            cleanup_modifier.SetSelection #Edge #{} node:node
            cleanup_modifier.Select #Edge redundant_edges node:node

            local stored_selection = cleanup_modifier.GetSelection #Edge node:node
            if stored_selection != redundant_edges then
            (
                throw ("Cleanup LOOPS could not select the detected redundant edges. Requested:" + (redundant_edges as string) + " actual:" + (stored_selection as string))
            )

            cleanup_modifier.SetOperation #RemoveEdge
            cleanup_modifier.Commit()
            cleanup_modifier.remveEdgeCtrlKey = old_remove_ctrl
            update node

            local unresolved_edges = #{}
            for edge_data in edge_descriptors do
            (
                if doesDebugVisibleEdgeExistByEndpointPositions node edge_data[2] edge_data[3] tolerance:0.01 then
                (
                    unresolved_edges[edge_data[1]] = true
                )
            )

            if unresolved_edges.numberSet > 0 then
            (
                throw ("Cleanup LOOPS left detected redundant edges visible: " + (unresolved_edges as string))
            )

            if debug_output then
            (
                if not batch_quiet then format "Wall-Fixer Redundant Loop Cleanup Complete: node:% loops:% removedEdges:% modifier:%\n" node.name loop_count redundant_edge_count cleanup_modifier.name
            )
        )
        catch
        (
            operation_error = getCurrentException()

            if cleanup_modifier != undefined then
            (
                try(deleteModifier node cleanup_modifier)catch()
                cleanup_modifier = undefined
            )

            update node
        )

        if operation_error == undefined then
        (
            #(true, loop_count, redundant_edge_count, "")
        )
        else
        (
            #(false, 0, 0, operation_error as string)
        )
        -- return
    ),

    /*
    Runs redundant-loop cleanup on every selected supported wall and restores the original node selection.
    Nodes with no redundant loops receive no new modifiers.
    */
    function cleanupRedundantLoopsSelection angle_threshold:0.1 debug_output:true =
    (
        last_slice_error = undefined
        last_slice_report = ""
        selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select at least one wall object."
            return false
        )

        total_loops = 0
        total_edges = 0
        processed_nodes = 0
        failed_nodes = #()
        report_text = ""

        for node in selected_nodes do
        (
            cleanup_result = cleanupRedundantLoopsOnNode node angle_threshold:angle_threshold debug_output:debug_output
            if cleanup_result[1] then
            (
                processed_nodes += 1
                total_loops += cleanup_result[2]
                total_edges += cleanup_result[3]
                report_text += node.name + ": loops " + (cleanup_result[2] as string) + ", edges " + (cleanup_result[3] as string) + ".\n"
            )
            else
            (
                append failed_nodes node.name
                report_text += node.name + ": FAILED - " + cleanup_result[4] + ".\n"
            )
        )

        select selected_nodes
        completeRedraw()

        if failed_nodes.count == 0 then
        (
            last_slice_report = "Redundant Loop Cleanup complete. Loops: " + (total_loops as string) + "; edges removed: " + (total_edges as string) + ".\n" + report_text
            if not batch_quiet then format "%" last_slice_report
            true
        )
        else
        (
            last_slice_report = "Redundant Loop Cleanup completed with failures.\n" + report_text
            if not batch_quiet then format "%" last_slice_report
            false
        )
        -- return
    ),

    /*
    Returns the permanent development loader path for Restart.
    The loader resolves the canonical unversioned component filenames on each reload.
    */
    function getRestartScriptPath source_script_path =
    (
        script_dir = getFilenamePath source_script_path
        loader_path = script_dir + "Wall-Fixer.ms"

        if doesFileExist loader_path then
        (
            loader_path
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
    function saveSettings weld_enabled weld_threshold display_hidden_edges double_side auto_smooth cut_mode_index angle_threshold planar_tolerance:1.0 slice_plane_mode_index:2 border_angle_threshold:5.0 right_angle_threshold:0.1 double_vert_threshold:1.0 double_face_threshold:100.0 slice_precision:0.01 quiet_batch:false dialog_position:undefined =
    (
        setIniSetting ini_path "Settings" "WeldVertices" (if weld_enabled then "1" else "0")
        setIniSetting ini_path "Settings" "WeldThreshold" (weld_threshold as string)
        setIniSetting ini_path "Settings" "DisplayHiddenEdges" (if display_hidden_edges then "1" else "0")
        setIniSetting ini_path "Settings" "DoubleSide" (if double_side then "1" else "0")
        setIniSetting ini_path "Settings" "AutoSmooth" (if auto_smooth then "1" else "0")
        setIniSetting ini_path "Settings" "CutMode" (cut_mode_index as string)
        setIniSetting ini_path "Settings" "AngleThreshold" (angle_threshold as string)
        setIniSetting ini_path "Settings" "PlanarTolerance" (planar_tolerance as string)
        setIniSetting ini_path "Settings" "SlicePlaneMode" (slice_plane_mode_index as string)
        setIniSetting ini_path "Settings" "BorderAngleThreshold" (border_angle_threshold as string)
        setIniSetting ini_path "Settings" "RightAngleThreshold" (right_angle_threshold as string)
        setIniSetting ini_path "Settings" "DoubleVertThreshold" (double_vert_threshold as string)
        setIniSetting ini_path "Settings" "DoubleFaceThreshold" (double_face_threshold as string)
        setIniSetting ini_path "Settings" "SlicePrecision" (slice_precision as string)
        setIniSetting ini_path "Settings" "QuietBatch" (if quiet_batch then "1" else "0")

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
                if not batch_quiet then format "Wall-Fixer Weld: weldVertsByThreshold failed on %\n" node.name
            )

            node.weldThreshold = previous_weld_threshold
            completeRedraw()

            if not batch_quiet then format "Wall-Fixer Weld: % | threshold: % | result: %\n" \
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
    Tracks selected geometry in interactive selection order.
    Existing ordered nodes stay first; newly selected nodes are appended and deselected nodes are removed.
    */
    function updateAttachAndWeldSelectionOrder current_selection:undefined =
    (
        local current_nodes = if current_selection == undefined then selection as array else current_selection
        local valid_current_nodes = #()
        local updated_order = #()

        for node in current_nodes do
        (
            if node != undefined and isValidNode node and superClassOf node == GeometryClass then
            (
                append valid_current_nodes node
            )
        )

        if valid_current_nodes.count == 0 then
        (
            attach_weld_selection_order = #()
            return #()
        )

        for node in attach_weld_selection_order do
        (
            if node != undefined and isValidNode node and (findItem valid_current_nodes node) > 0 then
            (
                append updated_order node
            )
        )

        for node in valid_current_nodes do
        (
            if (findItem updated_order node) == 0 then
            (
                append updated_order node
            )
        )

        attach_weld_selection_order = updated_order

        /* Shallow-copy only the array container.
           Plain copy is mapped and would clone every scene node in this node array. */
        copy attach_weld_selection_order #noMap
        -- return
    ),

    /*
    Returns selected geometry in tracked interactive order.
    If no click history exists, current Max selection order is used as a deterministic fallback.
    */
    function getAttachAndWeldSelectionOrder =
    (
        updateAttachAndWeldSelectionOrder()
        -- return
    ),

    /*
    Attaches all selected geometry into the first interactively selected target without welding.
    A top Edit Poly modifier is preserved; Editable Poly targets use polyop.attach directly.
    */
    function attachSelectedObjects =
    (
        selected_nodes = getAttachAndWeldSelectionOrder()
        geometry_nodes = #()
        target_node = undefined
        target_edit_poly = undefined
        attached_count = 0
        failed_count = 0

        for node in selected_nodes do
        (
            if node != undefined and isValidNode node and superClassOf node == GeometryClass then
            (
                append geometry_nodes node
            )
        )

        if geometry_nodes.count < 2 then
        (
            last_slice_report = "Attach: select at least two geometry objects."
            if not batch_quiet then format "%\n" last_slice_report
            return false
        )

        target_node = geometry_nodes[1]

        if target_node.modifiers.count > 0 then
        (
            if classOf target_node.modifiers[1] == Edit_Poly then
            (
                target_edit_poly = target_node.modifiers[1]
            )
        )

        if target_edit_poly == undefined and classOf target_node.baseObject != Editable_Poly then
        (
            try
            (
                convertToPoly target_node
            )
            catch
            (
            )
        )

        if target_edit_poly == undefined and classOf target_node.baseObject != Editable_Poly then
        (
            last_slice_report = "Attach: the target object could not be converted to Editable Poly."
            if not batch_quiet then format "%\n" last_slice_report
            return false
        )

        for source_index = 2 to geometry_nodes.count do
        (
            source_node = geometry_nodes[source_index]

            if isValidNode source_node then
            (
                attach_succeeded = false

                try
                (
                    if target_edit_poly != undefined then
                    (
                        target_edit_poly.Attach source_node editPolyNode:target_node
                    )
                    else
                    (
                        polyop.attach target_node source_node
                    )

                    attach_succeeded = not(isValidNode source_node)
                )
                catch
                (
                    attach_succeeded = false
                )

                if attach_succeeded then
                (
                    attached_count += 1
                )
                else
                (
                    failed_count += 1
                )
            )
        )

        if isValidNode target_node then
        (
            update target_node
            select target_node
        )

        completeRedraw()

        if failed_count > 0 then
        (
            last_slice_report = "Attach: attached " + (attached_count as string) + " object(s); " + (failed_count as string) + " object(s) failed."
            if not batch_quiet then format "%\n" last_slice_report
            false
        )
        else
        (
            last_slice_report = "Attach: attached " + (attached_count as string) + " object(s) into " + target_node.name + "."
            if not batch_quiet then format "%\n" last_slice_report
            true
        )
        -- return
    ),

    /*
    Moves each selected node pivot to the center of its object using the native CenterPivot operation.
    The current object geometry and modifier stack are preserved.
    */
    function centerSelectedPivots =
    (
        selected_nodes = selection as array
        centered_count = 0
        failed_count = 0

        if selected_nodes.count == 0 then
        (
            last_slice_report = "Reset Pivot to Center: select at least one object."
            if not batch_quiet then format "%\n" last_slice_report
            return false
        )

        for node in selected_nodes do
        (
            if node != undefined and isValidNode node then
            (
                try
                (
                    CenterPivot node
                    centered_count += 1
                )
                catch
                (
                    failed_count += 1
                )
            )
        )

        completeRedraw()

        if centered_count == 0 then
        (
            last_slice_report = "Reset Pivot to Center: no selected pivots were changed."
            if not batch_quiet then format "%\n" last_slice_report
            false
        )
        else if failed_count > 0 then
        (
            last_slice_report = "Reset Pivot to Center: centered " + (centered_count as string) + " object(s); " + (failed_count as string) + " object(s) failed."
            if not batch_quiet then format "%\n" last_slice_report
            false
        )
        else
        (
            last_slice_report = "Reset Pivot to Center: centered " + (centered_count as string) + " object pivot(s)."
            if not batch_quiet then format "%\n" last_slice_report
            true
        )
        -- return
    ),

    /*
    Attaches all selected geometry into the first interactively selected target and welds the result.
    Participating objects are baked to Editable Poly before attach; the tracked first object remains the target.
    */
    function attachAndWeldSelection weld_threshold =
    (
        local selected_nodes = getAttachAndWeldSelectionOrder()
        local geometry_nodes = #()
        local target_node = undefined
        local attached_count = 0
        local failed_nodes = #()

        if weld_threshold < 0.0 then weld_threshold = 0.0

        for node in selected_nodes do
        (
            if node != undefined and isValidNode node and superClassOf node == GeometryClass then
            (
                append geometry_nodes node
            )
        )

        if geometry_nodes.count < 2 then
        (
            last_slice_report = "ATTACH AND WELD: select at least two geometry objects."
            if not batch_quiet then format "%\n" last_slice_report
            return false
        )

        target_node = geometry_nodes[1]

        if not batch_quiet then format "Wall-Fixer Attach And Weld Target: %\n" target_node.name

        /* Bake every participant first so Attach always receives Editable Poly nodes.
           The first interactively selected geometry object remains the target and keeps its node identity. */
        for node in geometry_nodes do
        (
            if isValidNode node then
            (
                try(convertToPoly node)catch()

                if not(isValidNode node) or classOf node.baseObject != Editable_Poly then
                (
                    append failed_nodes node
                )
            )
        )

        if failed_nodes.count > 0 or not(isValidNode target_node) or classOf target_node.baseObject != Editable_Poly then
        (
            last_slice_report = "ATTACH AND WELD: one or more selected objects could not be converted to Editable Poly."
            if not batch_quiet then format "%\n" last_slice_report
            select geometry_nodes
            return false
        )

        for source_index = 2 to geometry_nodes.count do
        (
            local source_node = geometry_nodes[source_index]

            if isValidNode source_node then
            (
                local attach_error = undefined

                try
                (
                    polyop.attach target_node source_node
                )
                catch
                (
                    attach_error = getCurrentException()
                )

                if attach_error == undefined and not(isValidNode source_node) then
                (
                    attached_count += 1
                )
                else
                (
                    if isValidNode source_node then append failed_nodes source_node
                    if not batch_quiet then format "Wall-Fixer Attach And Weld Attach FAILED: target:% source:% error:%\n" \
                        target_node.name (if isValidNode source_node then source_node.name else "<deleted>") attach_error
                )
            )
        )

        update target_node
        weldNodeVertices target_node weld_threshold
        select target_node
        completeRedraw()

        if failed_nodes.count > 0 then
        (
            last_slice_report = "ATTACH AND WELD: attached " + (attached_count as string) +                 " object(s); " + (failed_nodes.count as string) + " object(s) failed. Weld was applied to the merged target."
            if not batch_quiet then format "%\n" last_slice_report
            false
        )
        else
        (
            last_slice_report = "ATTACH AND WELD: attached " + (attached_count as string) +                 " object(s) and welded all target vertices with threshold " + (weld_threshold as string) + "."
            if not batch_quiet then format "%\n" last_slice_report
            true
        )
        -- return
    ),


    /*
    Runs the Helpers Attach RMB workflow on the current geometry selection.
    The merged target is welded at 0.0, centered, and quadrified only when its triangle count is within the supplied limit.
    */
    function attachCenterWeldQuadrifySelection triangle_limit:12 =
    (
        local attach_success = attachAndWeldSelection 0.0
        local target_node = if selection.count == 1 then selection[1] else undefined
        local pivot_success = false
        local triangle_count = 0
        local quadrify_attempted = false
        local quadrify_success = true
        local face_count = 0


        if target_node == undefined or not(isValidNode target_node) or classOf target_node.baseObject != Editable_Poly then
        (
            last_slice_report = "Attach RMB: merged Editable Poly target was not available."
            if not batch_quiet then format "%\n" last_slice_report
            return false
        )


        try
        (
            CenterPivot target_node
            pivot_success = true
        )
        catch
        (
            pivot_success = false
        )


        face_count = polyOp.getNumFaces target_node

        for face_index = 1 to face_count do
        (
            if polyOp.getFaceDeg target_node face_index == 3 then
            (
                triangle_count += 1
            )
        )


        if triangle_count <= triangle_limit then
        (
            quadrify_attempted = true

            try
            (
                select target_node
                max modify mode
                subObjectLevel = 0
                quadrify_success = PolyToolsModeling.Quadrify false false
            )
            catch
            (
                quadrify_success = false
            )
        )


        update target_node
        select target_node
        completeRedraw()


        last_slice_report = "Attach RMB: attached selection, centered pivot, welded all vertices at 0.0; triangles: " + \
            (triangle_count as string) + "; quadrify: " + \
            (if quadrify_attempted then (if quadrify_success then "applied" else "failed") else "skipped (> " + (triangle_limit as string) + ")") + "."

        if not batch_quiet then format "%\n" last_slice_report


        attach_success and pivot_success and quadrify_success
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
    Applies viewport display option states to the provided nodes.
    Undefined option values are ignored so each UI option can still be changed independently.
    */
    function setNodesDisplayOptions nodes hidden_edges:undefined double_side:undefined =
    (
        for node in nodes do
        (
            if isValidNode node then
            (
                if hidden_edges != undefined then
                (
                    node.allEdges = hidden_edges
                )

                if double_side != undefined then
                (
                    node.backFaceCull = not double_side
                )
            )
        )

        redrawViews()
        true
        -- return
    ),

    /*
    Selects visible unfrozen mesh/poly objects whose every evaluated face points toward the active viewport.
    A world-state TriMesh snapshot keeps face-normal testing consistent across supported geometry types and modifier stacks.
    */
    function selectFrontFacingObjects =
    (
        local view_tm = undefined
        local matching_objects = #()
        local checked_count = 0
        local failed_count = 0
        local view_error = undefined

        try
        (
            view_tm = inverse (viewport.getTM())
            view_tm.row4 = [0,0,0]
        )
        catch
        (
            view_error = getCurrentException()
        )

        if view_tm == undefined then
        (
            last_slice_report = "SELECTION: could not read the active viewport transform. " + (view_error as string)
            if not batch_quiet then format "%\n" last_slice_report
            return false
        )

        for node in geometry where not node.isHidden and not node.isFrozen do
        (
            local supported_node = isKindOf node Editable_Poly or isKindOf node Editable_Mesh or isKindOf node PolyMeshObject

            if supported_node then
            (
                local all_faces_front = true
                local node_failed = false

                try
                (
                    local poly_node = isKindOf node Editable_Poly
                    local face_count = if poly_node then polyOp.getNumFaces node else meshOp.getNumFaces node

                    for face_index = 1 to face_count while all_faces_front do
                    (
                        local face_normal = if poly_node then polyOp.getFaceNormal node face_index else getFaceNormal node face_index
                        local view_normal = face_normal * view_tm

                        if view_normal.z < 0.0 then
                        (
                            all_faces_front = false
                        )
                    )
                )
                catch
                (
                    node_failed = true
                )

                if node_failed then
                (
                    failed_count += 1
                )
                else
                (
                    checked_count += 1
                    if all_faces_front then append matching_objects node
                )
            )
        )

        select matching_objects
        completeRedraw()

        last_slice_report = "SELECTION: " + (matching_objects.count as string) + " fully front-facing object(s) selected from " + (checked_count as string) + " checked object(s)."
        if failed_count > 0 then
        (
            last_slice_report += " " + (failed_count as string) + " object(s) could not be evaluated."
        )
        if not batch_quiet then format "%\n" last_slice_report

        true
        -- return
    ),

    /*
    Applies viewport edge-display state to all selected nodes.
    Checked Display Hidden Edges corresponds to the node allEdges property.
    */
    function setSelectionDisplayHiddenEdges enabled =
    (
        selected_nodes = selection as array
        setNodesDisplayOptions selected_nodes hidden_edges:enabled
        -- return
    ),

    /*
    Applies double-sided viewport display to all selected nodes.
    Checked Double Side means backface culling is disabled on the object.
    */
    function setSelectionDoubleSide enabled =
    (
        selected_nodes = selection as array
        setNodesDisplayOptions selected_nodes double_side:enabled
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

            if not batch_quiet then format "Wall-Fixer Auto Smooth: % | faces: % | threshold: %\n" \
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
    Returns edges that separate faces which do not share any smoothing-group bit.
    Border edges are ignored because they already delimit an element boundary.
    */
    function getHardSmoothingEdges node =
    (
        hard_edges = #{}

        if not (isValidNode node) then return hard_edges
        if classOf node.baseObject != Editable_Poly then return hard_edges

        base_obj = node.baseObject
        edge_count = polyop.getNumEdges base_obj

        for edge_index = 1 to edge_count do
        (
            edge_faces = polyop.getEdgeFaces base_obj edge_index

            if edge_faces.count == 2 then
            (
                smooth_group_a = polyop.getFaceSmoothGroup base_obj edge_faces[1]
                smooth_group_b = polyop.getFaceSmoothGroup base_obj edge_faces[2]

                if (bit.and smooth_group_a smooth_group_b) == 0 then
                (
                    hard_edges[edge_index] = true
                )
            )
        )

        hard_edges
        -- return
    ),

    /*
    Detaches every disconnected element of one Editable Poly into its own scene node.
    The original node keeps its first element; all newly detached nodes are returned with it.
    */
    function explodeNodeByElements node =
    (
        result_nodes = #()

        if not (isValidNode node) then return result_nodes
        if classOf node.baseObject != Editable_Poly then return result_nodes

        append result_nodes node
        base_obj = node.baseObject
        continue_explode = true

        while continue_explode do
        (
            face_count = polyop.getNumFaces base_obj

            if face_count <= 0 then
            (
                continue_explode = false
            )
            else
            (
                first_element = polyop.getElementsUsingFace base_obj #{1}

                if first_element.numberSet >= face_count then
                (
                    continue_explode = false
                )
                else
                (
                    all_faces = #{1..face_count}
                    remaining_faces = all_faces - first_element
                    remaining_face_array = remaining_faces as array

                    if remaining_face_array.count == 0 then
                    (
                        continue_explode = false
                    )
                    else
                    (
                        element_faces = polyop.getElementsUsingFace base_obj #{remaining_face_array[1]}
                        new_name = uniqueName (node.name + "_WALL")
                        detached = polyop.detachFaces base_obj element_faces delete:true asNode:true name:new_name node:node

                        if detached then
                        (
                            new_node = getNodeByName new_name

                            if isValidNode new_node then
                            (
                                new_node.material = node.material
                                new_node.wirecolor = node.wirecolor
                                append result_nodes new_node
                            )
                            else
                            (
                                continue_explode = false
                            )
                        )
                        else
                        (
                            continue_explode = false
                        )
                    )
                )
            )
        )

        result_nodes
        -- return
    ),

    /*
    Prepares selected geometry as individual planar wall objects.
    One instanced Smooth modifier auto-smooths the selection, hard smoothing boundaries become elements, then elements become objects with smoothing groups cleared.
    */
    function prepareObjects angle_threshold:5.0 =
    (
        selected_nodes = selection as array
        supported_nodes = #()
        prepared_nodes = #()

        for node in selected_nodes do
        (
            if isValidNode node and superClassOf node == GeometryClass then
            (
                append supported_nodes node
            )
        )

        if supported_nodes.count == 0 then
        (
            last_slice_report = "Prepare object: select at least one geometry object."
            return false
        )

        smooth_modifier = Smooth()
        smooth_modifier.name = "PREPARE OBJECT - AUTO SMOOTH"
        smooth_modifier.autosmooth = true
        smooth_modifier.threshold = angle_threshold
        addModifier supported_nodes smooth_modifier

        for node in supported_nodes do
        (
            convertToPoly node

            if isValidNode node and classOf node.baseObject == Editable_Poly then
            (
                base_obj = node.baseObject
                hard_edges = getHardSmoothingEdges node

                if hard_edges.numberSet > 0 then
                (
                    polyop.splitEdges base_obj hard_edges
                    update node
                )

                node_results = explodeNodeByElements node

                for result_node in node_results do
                (
                    if isValidNode result_node then append prepared_nodes result_node
                )
            )
        )

        if prepared_nodes.count > 0 then
        (
            for prepared_node in prepared_nodes do
            (
                if isValidNode prepared_node and classOf prepared_node.baseObject == Editable_Poly then
                (
                    prepared_base_obj = prepared_node.baseObject
                    prepared_face_count = polyop.getNumFaces prepared_base_obj

                    if prepared_face_count > 0 then
                    (
                        polyop.setFaceSmoothGroup prepared_base_obj #{1..prepared_face_count} 0
                        update prepared_node
                    )
                )
            )

            select prepared_nodes
            completeRedraw()

            last_slice_report = (
                "Prepare object complete. Input objects: " + (supported_nodes.count as string) +
                "; planar wall objects: " + (prepared_nodes.count as string) +
                "; Auto Smooth threshold: " + (angle_threshold as string) + " degrees."
            )
            if not batch_quiet then format "Wall-Fixer Prepare Object: input:% output:% threshold:%\n" supported_nodes.count prepared_nodes.count angle_threshold
            true
        )
        else
        (
            last_slice_report = "Prepare object failed: no planar wall objects were produced."
            false
        )
        -- return
    ),

    /*
    Merges selected geometry objects whose pivot positions match within the supplied tolerance.
    Each matching group keeps its first object as the Editable Poly target; singleton groups remain untouched.
    */
    function mergeSelectedObjectsByPivot pivot_tolerance:0.001 =
    (
        selected_nodes = selection as array
        supported_nodes = #()
        pivot_groups = #()
        result_nodes = #()
        merged_group_count = 0
        attached_object_count = 0

        if pivot_tolerance < 0.0 then pivot_tolerance = 0.0

        for node in selected_nodes do
        (
            if isValidNode node and superClassOf node == GeometryClass then
            (
                append supported_nodes node
            )
        )

        if supported_nodes.count == 0 then
        (
            last_slice_report = "Merge Objects by Pivot: select at least one geometry object."
            return false
        )

        for node in supported_nodes do
        (
            matched_group_index = 0
            node_pivot = node.transform.pos

            for group_index = 1 to pivot_groups.count while matched_group_index == 0 do
            (
                group_data = pivot_groups[group_index]
                group_pivot = group_data[1]

                if distance node_pivot group_pivot <= pivot_tolerance then
                (
                    matched_group_index = group_index
                )
            )

            if matched_group_index > 0 then
            (
                group_nodes = pivot_groups[matched_group_index][2]
                append group_nodes node
            )
            else
            (
                append pivot_groups #(node_pivot, #(node))
            )
        )

        for group_data in pivot_groups do
        (
            group_nodes = group_data[2]

            if group_nodes.count <= 1 then
            (
                if group_nodes.count == 1 and isValidNode group_nodes[1] then
                (
                    append result_nodes group_nodes[1]
                )
            )
            else
            (
                target_node = group_nodes[1]

                if isValidNode target_node then
                (
                    try(convertToPoly target_node)catch()

                    if isValidNode target_node and classOf target_node.baseObject == Editable_Poly then
                    (
                        merged_group_count += 1

                        for source_index = 2 to group_nodes.count do
                        (
                            source_node = group_nodes[source_index]

                            if isValidNode source_node then
                            (
                                try(convertToPoly source_node)catch()

                                if isValidNode source_node and classOf source_node.baseObject == Editable_Poly then
                                (
                                    try(polyop.attach target_node source_node)catch()

                                    if not (isValidNode source_node) then
                                    (
                                        attached_object_count += 1
                                    )
                                )

                                if isValidNode source_node then
                                (
                                    append result_nodes source_node
                                )
                            )
                        )

                        if isValidNode target_node then
                        (
                            update target_node
                            append result_nodes target_node
                        )
                    )
                    else
                    (
                        for group_node in group_nodes do
                        (
                            if isValidNode group_node then append result_nodes group_node
                        )
                    )
                )
            )
        )

        if result_nodes.count > 0 then
        (
            select result_nodes
            completeRedraw()
        )

        last_slice_report = (
            "Merge Objects by Pivot complete. Input objects: " + (supported_nodes.count as string) +
            "; pivot groups: " + (pivot_groups.count as string) +
            "; merged groups: " + (merged_group_count as string) +
            "; attached objects: " + (attached_object_count as string) + "."
        )
        if not batch_quiet then format "Wall-Fixer Merge Objects by Pivot: input:% groups:% mergedGroups:% attached:% tolerance:%\n" \
            supported_nodes.count pivot_groups.count merged_group_count attached_object_count pivot_tolerance

        true
        -- return
    ),

    /*
    Returns the current Make 1 Slice vertex-selection filter mapped to unchanged base-object vertex IDs.
    Edit Poly selections are mapped by world position; Editable Poly selections already use base IDs.
    */
    function getActiveMakeOneSliceVertexSelection node match_tolerance:0.01 =
    (
        local mapped_selection = #{}
        local had_vertex_selection = false
        local selection_source = #none

        if node == undefined or not(isValidNode node) then return #(mapped_selection, had_vertex_selection, selection_source)

        local base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then return #(mapped_selection, had_vertex_selection, selection_source)

        local current_object = undefined
        try
        (
            current_object = modPanel.getCurrentObject()
        )
        catch
        (
            current_object = undefined
        )

        if current_object != undefined and classOf current_object == Edit_Poly then
        (
            local belongs_to_node = false
            for modifier in node.modifiers while not belongs_to_node do
            (
                if modifier == current_object then belongs_to_node = true
            )

            if belongs_to_node then
            (
                local modifier_selection = #{}
                try
                (
                    modifier_selection = current_object.GetSelection #Vertex node:node
                )
                catch
                (
                    modifier_selection = #{}
                )

                if modifier_selection != undefined and modifier_selection.numberSet > 0 then
                (
                    had_vertex_selection = true
                    selection_source = #editPoly

                    local object_tm = node.objectTransform
                    local base_vertex_count = polyop.getNumVerts base_obj
                    local search_tolerance = amax epsilon match_tolerance

                    for modifier_vertex in modifier_selection do
                    (
                        local modifier_position = undefined
                        try
                        (
                            modifier_position = current_object.GetVertex modifier_vertex node:node
                        )
                        catch
                        (
                            modifier_position = undefined
                        )

                        if modifier_position != undefined then
                        (
                            local modifier_world = modifier_position * object_tm
                            local best_base_vertex = 0
                            local best_distance = 1e30

                            for base_vertex = 1 to base_vertex_count do
                            (
                                local base_position = undefined
                                try
                                (
                                    base_position = polyop.getVert base_obj base_vertex
                                )
                                catch
                                (
                                    base_position = undefined
                                )

                                if base_position != undefined then
                                (
                                    local base_world = base_position * object_tm
                                    local current_distance = distance modifier_world base_world

                                    if current_distance < best_distance then
                                    (
                                        best_distance = current_distance
                                        best_base_vertex = base_vertex
                                    )
                                )
                            )

                            if best_base_vertex > 0 and best_distance <= search_tolerance then
                            (
                                mapped_selection[best_base_vertex] = true
                            )
                        )
                    )

                    return #(mapped_selection, had_vertex_selection, selection_source)
                )
            )
        )

        local base_selection = polyop.getVertSelection base_obj
        if base_selection != undefined and base_selection.numberSet > 0 then
        (
            mapped_selection = copy base_selection
            had_vertex_selection = true
            selection_source = #editablePoly
        )

        #(mapped_selection, had_vertex_selection, selection_source)
        -- return
    ),

    /* Slice and Fix N-gons now share one native Edit Poly pipeline.
       Legacy weld keywords are accepted, but cleanup never welds borders. */
    function processNode node cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 reset_clean_edges:true clear_clean_edges:true auto_smooth:false operation_mode:#full update_viewport_selection:true =
    (
        last_slice_error = undefined
        last_slice_count = 0
        if not isValidNode node then
        (
            last_slice_error = "The selected node is no longer valid."
            return false
        )
        local supported = isSliceSupportedNode node
        if not supported then
        (
            last_slice_error = "Requires Editable Poly geometry or an Edit Poly modifier."
            return false
        )
        local oldSelection = selection as array
        local oldPanel = getCommandPanelTaskMode()
        local oldCurrent = modPanel.getCurrentObject()
        local oldLevel = subObjectLevel
        local one_slice_selection_data = #(#{}, false, #none)
        if operation_mode == #oneSlice then
        (
            one_slice_selection_data = getActiveMakeOneSliceVertexSelection node match_tolerance:(amax epsilon 0.01)
            if not batch_quiet then format "Wall-Fixer Make 1 Slice Vertex Filter: source:% hadSelection:% mapped:%\n" one_slice_selection_data[3] one_slice_selection_data[2] one_slice_selection_data[1]
        )
        local modifier = undefined
        local backup = undefined
        local added = false
        local success = false
        local failure = undefined
        local settings = undefined
        local debug_vertex_selection = #{}
        local debug_edge_selection = #{}
        local debug_start_vertices = #{}
        local debug_original_vertices = #{}
        try
        (
            -- An instanced object shares its whole evaluated modifier pipeline.
            -- Copy that pipeline for this node before changing any modifier data.
            local stackInstances = #()
            InstanceMgr.GetInstances node &stackInstances
            if stackInstances.count > 1 do
            (
                if not(InstanceMgr.MakeObjectsUnique #(node) #individual) do throw "Cannot isolate the selected wall instance."
                if node.modifiers.count > 0 then oldCurrent = node.modifiers[1] else oldCurrent = node.baseObject
            )
            if node.modifiers.count > 0 do
                if classOf node.modifiers[1] == Edit_Poly do modifier = node.modifiers[1]
            -- Isolate a shared top modifier without changing its base geometry.
            if modifier != undefined do
                if (refs.dependentNodes modifier).count > 1 do
                (
                    if modifier.animationMode != 0 or modifier.currentOperation != 0 do throw "Commit the active Edit Poly operation before slicing."
                    local sharedModifier = modifier
                    if not(InstanceMgr.MakeModifiersUnique #(node) #(modifier) #individual) do throw "Cannot isolate the shared Edit Poly modifier."
                    modifier = node.modifiers[1]
                    if oldCurrent == sharedModifier do oldCurrent = modifier
                )
            if modifier == undefined then
            (
                modifier = Edit_Poly name:"WMC - WALL TOPOLOGY CLEANUP"
                addModifier node modifier
                added = true
            )
            else
            (
                if modifier.animationMode != 0 or modifier.currentOperation != 0 do throw "Commit the active Edit Poly operation before slicing."
                backup = copy modifier
            )
            settings = #(modifier.split,modifier.useStackSelection,modifier.useSoftSel,modifier.remveEdgeCtrlKey)

            /* Edit Poly component Select/Commit needs this modifier to be the active
               Modify-panel object. Keep this mandatory context for topology work even
               when viewport/debug selection is disabled. */
            if update_viewport_selection or operation_mode == #oneSlice or operation_mode == #full then
            (
                select node
                max modify mode
                modPanel.setCurrentObject modifier
            )
            modifier.SetPrimaryNode node
            modifier.split = false
            modifier.useStackSelection = false
            modifier.useSoftSel = false
            modifier.remveEdgeCtrlKey = false
            local pipeline = WMCWallSlicePipeline node:node ep:modifier planarTolerance:(amax 0.0 planar_tolerance) axisTolerance:(amin 45.0 (amax 0.0 angle_threshold)) uiSelection:update_viewport_selection
            case operation_mode of
            (
                #check:
                (
                    local stats = pipeline.checkMesh()
                    local inner_vertex_selection = pipeline.getInnerCornerVertexSelection()
                    setResetInnerVertSelection node inner_vertex_selection
                    debug_vertex_selection = pipeline.getSliceAnchorVertexSelection()
                    last_slice_report = node.name + ":\n" + \
                        "  SLICING STATE: RESET\n" + \
                        "  MESH: OK\n" + \
                        "  INNER VERTS: " + (inner_vertex_selection as string) + "\n" + \
                        "  VERTS: " + (stats[1] as string) + "\n" + \
                        "  EDGES: " + (stats[2] as string) + "\n" + \
                        "  FACES: " + (stats[3] as string) + "\n" + \
                        "  BORDER EDGES: " + (stats[4] as string) + "\n" + \
                        "  CORNERS: " + (stats[5] as string) + "\n" + \
                        "  SLICE ANCHORS: " + (stats[6] as string) + "\n" + \
                        "  SELECTED ANCHORS: " + (debug_vertex_selection.numberSet as string)
                )
                #innerCorners:
                (
                    local stats = pipeline.checkMesh()
                    debug_vertex_selection = pipeline.getInnerCornerVertexSelection()
                    last_slice_report = node.name + ": mesh OK | inner corners selected:" + (debug_vertex_selection.numberSet as string)
                )
                #sliceAlignment:
                (
                    local alignment_debug = pipeline.getOneSliceAlignmentVertices cutMode:cut_mode planeMode:slice_plane_mode
                    if alignment_debug == undefined then throw "No inner corner can define a slice plane in the current direction."
                    debug_vertex_selection = alignment_debug[1]
                    last_slice_report = node.name + ": slice plane aligned to vertices:" + (debug_vertex_selection.numberSet as string) + "; source corner:" + (alignment_debug[2] as string) + "; direction:" + (alignment_debug[3] as string) + "; mode:" + (slice_plane_mode as string) + "; edge:" + (alignment_debug[7] as string) + "."
                    if not batch_quiet then format "Wall-Fixer Slice Alignment Debug: source:% direction:% mode:% edge:% vertices:% count:%\n" alignment_debug[2] alignment_debug[3] slice_plane_mode alignment_debug[7] debug_vertex_selection debug_vertex_selection.numberSet
                )
                #checkCorners:
                (
                    debug_vertex_selection = getResetInnerVertSelection node
                    if debug_vertex_selection == undefined then throw "Run Reset Slicing before Check Corners."

                    last_slice_report = node.name + ":\n" + \
                        "  INNER VERTS FROM RESET SLICING: " + (debug_vertex_selection as string) + "\n" + \
                        "  COUNT: " + (debug_vertex_selection.numberSet as string)
                    if not batch_quiet then format "Wall-Fixer Check Corners:\n%\n" last_slice_report
                )
                #oneSlice:
                (
                    clearLastDebugSliceContext node:node

                    /* Analyze only the unchanged base object to choose the next source corner.
                       Edge Direction consumes successful base edges; Global Axis consumes successful planes. */
                    local reset_inner_vertices = getResetInnerVertSelection node
                    if reset_inner_vertices == undefined then throw "Run Reset Slicing before Make 1 Slice."

                    local one_slice_source_vertices = copy reset_inner_vertices
                    if one_slice_selection_data[2] then
                    (
                        local selected_inner_vertices = reset_inner_vertices * one_slice_selection_data[1]
                        if selected_inner_vertices.numberSet == 0 then
                        (
                            throw "The current vertex selection contains no available Reset Slicing inner corner."
                        )

                        one_slice_source_vertices = selected_inner_vertices
                        if not batch_quiet then format "Wall-Fixer Make 1 Slice Selected INNER VERTS: %\n" one_slice_source_vertices
                    )

                    local base_candidates = getBaseInnerSliceCandidates node angle_threshold:angle_threshold source_vertices:one_slice_source_vertices
                    if base_candidates.count == 0 then throw "Selected/available INNER VERTS cannot define any base slice candidates."

                    local candidate_vertices = #{}
                    for candidate in base_candidates do
                    (
                        candidate_vertices[candidate[1]] = true
                    )
                    local missing_candidate_vertices = one_slice_source_vertices - candidate_vertices
                    if not batch_quiet then format "Wall-Fixer Base Candidates: sourceInner:% candidates:% missing:%\n" one_slice_source_vertices candidate_vertices missing_candidate_vertices

                    local slice_kinds = #()
                    if cut_mode == #all or cut_mode == #vertical then append slice_kinds #vertical
                    if cut_mode == #all or cut_mode == #horizontal then append slice_kinds #horizontal

                    local slice_debug = undefined
                    local used_base_vertex = 0
                    local used_base_edge = 0
                    local used_slice_kind = undefined

                    for slice_kind in slice_kinds while slice_debug == undefined do
                    (
                        /* Failed attempts are remembered only for this click.
                           They remain pending globally so another successful slice can make them useful later. */
                        local attempted_edges = #{}
                        local attempted_planes = #()

                        for candidate in base_candidates while slice_debug == undefined do
                        (
                            local base_vertex = candidate[1]
                            local direction_available = if slice_kind == #vertical then candidate[2] else candidate[3]
                            local base_edge = if slice_kind == #vertical then candidate[4] else candidate[5]
                            local base_anchor = candidate[6]
                            local base_axis = undefined
                            if slice_plane_mode == #nextVert then
                            (
                                base_axis = if slice_kind == #vertical then candidate[7] else candidate[8]
                            )
                            else
                            (
                                base_axis = if slice_kind == #vertical then candidate[9] else candidate[10]
                            )

                            local item_processed = false
                            local attempted_this_click = false
                            if direction_available and base_axis != undefined then
                            (
                                if slice_plane_mode == #nextVert then
                                (
                                    item_processed = isBaseSliceEdgeProcessed node base_edge slice_kind
                                    attempted_this_click = base_edge > 0 and base_edge <= attempted_edges.count and attempted_edges[base_edge]
                                )
                                else
                                (
                                    item_processed = isBaseSlicePlaneProcessed node base_anchor base_axis slice_kind
                                    attempted_this_click = hasSlicePlaneRecord base_anchor base_axis attempted_planes
                                )
                            )

                            if direction_available and base_axis != undefined and not item_processed and not attempted_this_click then
                            (
                                if slice_plane_mode == #nextVert then
                                (
                                    if base_edge > 0 then attempted_edges[base_edge] = true
                                )
                                else
                                (
                                    append attempted_planes #(normalize base_axis, base_anchor)
                                )

                                local wall_normal = candidate[11]
                                local wall_origin = candidate[12]
                                local region_id = candidate[13]

                                if not batch_quiet then format "Wall-Fixer Base Slice: node:% region:% baseVert:% baseEdge:% direction:% mode:% processed:%\n"                                     node.name region_id base_vertex base_edge slice_kind slice_plane_mode item_processed

                                slice_debug = pipeline.makeOneSliceFromBasePlane                                     base_vertex                                     base_anchor                                     base_axis                                     slice_kind                                     wall_normal:wall_normal                                     wall_origin:wall_origin                                     plane_tolerance:(amax 0.0 planar_tolerance)

                                if slice_debug != undefined then
                                (
                                    if slice_plane_mode == #nextVert then
                                    (
                                        markBaseSliceEdgeProcessed node base_edge slice_kind
                                    )
                                    else
                                    (
                                        markBaseSlicePlaneProcessed node base_anchor base_axis slice_kind
                                    )
                                    used_base_vertex = base_vertex
                                    used_base_edge = base_edge
                                    used_slice_kind = slice_kind
                                )
                                else
                                (
                                    /* Do not retire a failed edge or plane.
                                       Later successful slices can repartition faces and make this pending cut valid. */
                                    if not batch_quiet then format "Wall-Fixer Base Slice Pending: baseVert:% baseEdge:% direction:% reason:no topology change; keep for retry.\n" base_vertex base_edge slice_kind
                                )
                            )
                            else if direction_available and base_axis != undefined and item_processed then
                            (
                                if slice_plane_mode == #nextVert then
                                (
                                    if not batch_quiet then format "Wall-Fixer Base Slice Skip: baseVert:% baseEdge:% direction:% reason:base edge already sliced.\n" base_vertex base_edge slice_kind
                                )
                                else
                                (
                                    if not batch_quiet then format "Wall-Fixer Base Slice Skip: baseVert:% direction:% reason:same geometric slice plane already processed.\n" base_vertex slice_kind
                                )
                            )
                            else if direction_available and base_axis != undefined and attempted_this_click then
                            (
                                if not batch_quiet then format "Wall-Fixer Base Slice Skip: baseVert:% baseEdge:% direction:% reason:same pending item already attempted this click.\n" base_vertex base_edge slice_kind
                            )
                            else if direction_available and base_axis == undefined then
                            (
                                if not batch_quiet then format "Wall-Fixer Base Slice Skip: baseVert:% direction:% reason:base slice plane is undefined.\n" base_vertex slice_kind
                            )
                            else if not direction_available then
                            (
                                if not batch_quiet then format "Wall-Fixer Base Slice Skip: baseVert:% direction:% reason:no matching base border edge.\n" base_vertex slice_kind
                            )
                        )
                    )

                    if slice_debug == undefined then
                    (
                        debug_edge_selection = #{}
                        last_slice_report = node.name + ": no pending base edge/plane can change the current topology yet."
                        if not batch_quiet then format "Wall-Fixer Base Slice: %\n" last_slice_report
                    )
                    else
                    (
                        debug_edge_selection = slice_debug[9]
                        debug_original_vertices = copy slice_debug[12]
                        debug_start_vertices = #{}

                        if used_base_edge > 0 then
                        (
                            local defining_edge_vertices = polyop.getEdgeVerts node.baseObject used_base_edge
                            if defining_edge_vertices != undefined and defining_edge_vertices.count == 2 then
                            (
                                debug_start_vertices[defining_edge_vertices[1]] = true
                                debug_start_vertices[defining_edge_vertices[2]] = true
                            )
                        )

                        last_slice_report = node.name + ": base vert " + (used_base_vertex as string) + " sliced " + (used_slice_kind as string) + "; new non-border edges selected:" + (debug_edge_selection.numberSet as string) + "."
                    )
                )
                default:
                (
                    pipeline.run cutMode:cut_mode planeMode:slice_plane_mode
                    if auto_smooth then
                    (
                        local t = pipeline.refreshTopology()
                        local ids = copy t.validFaces
                        t = pipeline.applyOperation #Face ids #Autosmooth
                        pipeline.validateStructure t
                    )
                )
            )
            if operation_mode != #oneSlice and operation_mode != #check and operation_mode != #innerCorners and operation_mode != #sliceAlignment and operation_mode != #checkCorners then
            (
                modifier.SetSelection #Vertex #{} node:node
                modifier.SetSelection #Edge #{} node:node
                modifier.SetSelection #Face #{} node:node
            )
            modifier.split = settings[1]
            modifier.useStackSelection = settings[2]
            modifier.useSoftSel = settings[3]
            modifier.remveEdgeCtrlKey = settings[4]
            last_slice_count = pipeline.cuts
            success = true
            -- Keep the debug Edit Poly when Reset Slicing created it so the selected
            -- anchor vertices remain visible in the viewport. No topology is changed.
        )
        catch
        (
            failure = getCurrentException()
            if modifier != undefined then
            (
                if added then
                (
                    deleteModifier node modifier
                )
                else if backup != undefined then
                (
                    deleteModifier node modifier
                    addModifier node backup
                    if oldCurrent == modifier then oldCurrent = backup
                )
            )
        )
        if operation_mode == #check and success then
        (
            /* Reset Slicing is a hard reset point. The temporary Edit Poly used for
               pipeline analysis is removed and the debug selection is applied
               directly to the base Editable Poly. */
            if modifier != undefined and added then
            (
                deleteModifier node modifier
                modifier = undefined
            )

            if update_viewport_selection then
            (
                select node
                max modify mode
                base_obj = node.baseObject
                if classOf base_obj == Editable_Poly then
                (
                    modPanel.setCurrentObject base_obj
                    subObjectLevel = 1
                    polyop.setVertSelection base_obj debug_vertex_selection
                    if not batch_quiet then format "Wall-Fixer Debug Base Selection: selected:%\n" (polyop.getVertSelection base_obj)
                )
                completeRedraw()
            )
        )
        else if (operation_mode == #oneSlice or operation_mode == #innerCorners or operation_mode == #sliceAlignment) and success and modifier != undefined then
        (
            if operation_mode == #oneSlice then
            (
                last_debug_slice_node = node
                last_debug_slice_new_edges = copy debug_edge_selection
                last_debug_slice_start_vertices = copy debug_start_vertices
                last_debug_slice_original_vertices = copy debug_original_vertices
                if not batch_quiet then format "Wall-Fixer Slice Edge Cleanup Context: newEdges:% startVerts:% originalVerts:%\n" last_debug_slice_new_edges last_debug_slice_start_vertices last_debug_slice_original_vertices.numberSet

                if update_viewport_selection then
                (
                    select node
                    max modify mode
                    modPanel.setCurrentObject modifier
                    modifier.SetPrimaryNode node
                    modifier.useStackSelection = false
                    modifier.SetEPolySelLevel #Edge
                    modifier.SetSelection #Edge #{} node:node
                    local debug_selected_ok = modifier.Select #Edge debug_edge_selection node:node
                    local debug_actual_selection = modifier.GetSelection #Edge node:node
                    if not batch_quiet then format "Wall-Fixer Debug New Edges: requested:% selected:% result:%\n" debug_edge_selection debug_actual_selection debug_selected_ok
                    if debug_actual_selection != debug_edge_selection then
                    (
                        last_slice_report += " | WARNING: edge selection mismatch requested:" + (debug_edge_selection as string) + " actual:" + (debug_actual_selection as string)
                    )
                    completeRedraw()
                )
                if not update_viewport_selection then
                (
                    select oldSelection
                    if oldPanel == #modify and oldCurrent != undefined then
                    (
                        try (modPanel.setCurrentObject oldCurrent) catch ()
                    )
                    setCommandPanelTaskMode oldPanel
                )
            )
            else
            (
                select node
                max modify mode
                modPanel.setCurrentObject modifier
                modifier.SetPrimaryNode node
                modifier.useStackSelection = false
                modifier.SetEPolySelLevel #Vertex
                subObjectLevel = 1
                modifier.SetSelection #Vertex #{} node:node
                local debug_selected_ok = modifier.Select #Vertex debug_vertex_selection node:node
                local debug_actual_selection = modifier.GetSelection #Vertex node:node
                if not batch_quiet then format "Wall-Fixer Debug Selection: requested:% selected:% result:%\n" debug_vertex_selection debug_actual_selection debug_selected_ok
                if debug_actual_selection != debug_vertex_selection then
                (
                    last_slice_report += " | WARNING: viewport selection mismatch requested:" + (debug_vertex_selection as string) + " actual:" + (debug_actual_selection as string)
                )
                completeRedraw()
            )
        )
        else
        (
            select oldSelection
            if oldPanel == #modify and oldCurrent != undefined then
            (
                try (modPanel.setCurrentObject oldCurrent; subObjectLevel = oldLevel) catch ()
            )
            setCommandPanelTaskMode oldPanel
        )
        last_slice_error = failure
        if failure != undefined then
        (
            if not batch_quiet then format "Wall-Fixer: % | restored after failure: %\n" node.name failure
        )
        success
    ),
    /*
    Initializes Reset Slicing directly from the unchanged Editable Poly base object.
    Multiple connected planar wall regions are accepted and their INNER VERTS are merged into one base-ID cache.
    */
    function initializeBaseSliceAnalysis node angle_threshold:5.0 planar_tolerance:1.0 update_viewport_selection:true =
    (
        last_slice_error = undefined
        last_slice_report = ""

        if node == undefined or not(isValidNode node) then
        (
            last_slice_error = "The selected wall is no longer valid."
            return false
        )

        local base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then
        (
            last_slice_error = "Reset Slicing requires an Editable Poly base object."
            return false
        )

        local planar_regions = getBasePlanarWallRegions node planar_tolerance:(amax 0.0 planar_tolerance)
        if planar_regions.count == 0 then
        (
            last_slice_error = "No valid planar wall region was found in the base object."
            return false
        )

        local base_candidates = getBaseInnerSliceCandidates \
            node \
            angle_threshold:angle_threshold \
            planar_tolerance:(amax 0.0 planar_tolerance)

        local inner_vertices = #{}
        for candidate in base_candidates do
        (
            inner_vertices[candidate[1]] = true
        )

        setResetInnerVertSelection node inner_vertices

        local vert_count = polyop.getNumVerts base_obj
        local edge_count = polyop.getNumEdges base_obj
        local face_count = polyop.getNumFaces base_obj
        local region_border_edges = #{}

        for region_data in planar_regions do
        (
            region_border_edges = region_border_edges + region_data[4]
        )

        last_slice_report = node.name + ":\n" + \
            "  SLICING STATE: RESET\n" + \
            "  MESH: OK\n" + \
            "  PLANAR WALLS: " + (planar_regions.count as string) + "\n" + \
            "  INNER VERTS: " + (inner_vertices as string) + "\n" + \
            "  VERTS: " + (vert_count as string) + "\n" + \
            "  EDGES: " + (edge_count as string) + "\n" + \
            "  FACES: " + (face_count as string) + "\n" + \
            "  REGION BORDER EDGES: " + (region_border_edges.numberSet as string) + "\n" + \
            "  SLICE CANDIDATES: " + (base_candidates.count as string)

        if update_viewport_selection then
        (
            select node
            max modify mode
            modPanel.setCurrentObject base_obj
            subObjectLevel = 1
            polyop.setVertSelection base_obj inner_vertices
            completeRedraw()
            if not batch_quiet then format "Wall-Fixer Debug Base Selection: selected:%\n" (polyop.getVertSelection base_obj)
        )

        true
        -- return
    ),

    /*
    Checks selected walls using the same planar/topology validation as Slice Walls.
    No topology changes are made; available slice-anchor vertices remain selected.
    */
    function debugCheckSelection angle_threshold:5.0 planar_tolerance:1.0 update_viewport_selection:true =
    (
        clearListener()

        local selected_nodes = selection as array
        last_slice_report = ""
        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select at least one wall before running Reset Slicing."
            return false
        )
        local all_ok = true
        local report = ""
        for node in selected_nodes do
        (
            if resetNodeForCheckMesh node then
            (
                if initializeBaseSliceAnalysis                     node                     angle_threshold:angle_threshold                     planar_tolerance:planar_tolerance                     update_viewport_selection:update_viewport_selection then
                (
                    report += last_slice_report + "\n"
                )
                else
                (
                    report += node.name + ": " + (last_slice_error as string) + "\n"
                    all_ok = false
                )
            )
            else
            (
                report += node.name + ": RESET FAILED\n"
                all_ok = false
            )
        )
        last_slice_report = report
        if not batch_quiet then format "Wall-Fixer Reset Slicing:\n%\n" last_slice_report
        all_ok
        -- return
    ),
    /*
    Checks selected walls and selects wall-inner corners on openings and the outer border.
    Used by right-click on the Reset Slicing debug button.
    */
    function debugSelectInnerCorners angle_threshold:5.0 planar_tolerance:1.0 =
    (
        local selected_nodes = selection as array
        last_slice_report = ""
        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select at least one wall before selecting inner corners."
            return false
        )
        local all_ok = true
        local report = ""
        for node in selected_nodes do
        (
            if processNode node angle_threshold:angle_threshold planar_tolerance:planar_tolerance operation_mode:#innerCorners then
            (
                report += last_slice_report + "\n"
            )
            else
            (
                report += node.name + ": " + (last_slice_error as string) + "\n"
                all_ok = false
            )
        )
        last_slice_report = report
        if not batch_quiet then format "Wall-Fixer Inner Corners: %\n" last_slice_report
        all_ok
        -- return
    ),
    /*
    Selects every existing vertex lying on the plane that Make 1 Slice would use next.
    No slice or topology modification is performed; this is RMB inspection for Make 1 Slice.
    */
    function debugSelectOneSliceAlignment cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 =
    (
        local selected_nodes = selection as array
        last_slice_report = ""
        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select one wall before inspecting Make 1 Slice alignment."
            return false
        )
        local node = selected_nodes[1]
        if not(processNode node cut_mode:cut_mode slice_plane_mode:slice_plane_mode angle_threshold:angle_threshold planar_tolerance:planar_tolerance operation_mode:#sliceAlignment) then
        (
            last_slice_report = node.name + ": " + (last_slice_error as string)
        )
        completeRedraw()
        last_slice_error == undefined
        -- return
    ),

    /*
    Selects the exact INNER VERTS captured by the last successful Reset Slicing.
    The cached base vertex IDs are reused directly and no corner availability is recalculated.
    */
    function debugCheckCorners cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 =
    (
        selected_nodes = selection as array
        last_slice_report = ""
        last_slice_error = undefined

        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select one wall before running Check Corners."
            return false
        )

        node = selected_nodes[1]
        cached_inner_verts = getResetInnerVertSelection node
        if cached_inner_verts == undefined then
        (
            last_slice_report = node.name + ": no Reset Slicing INNER VERTS cache. Run Reset Slicing first."
            return false
        )

        select node
        max modify mode

        current_edit_poly = undefined
        for modifier in node.modifiers while current_edit_poly == undefined do
        (
            if classOf modifier == Edit_Poly then current_edit_poly = modifier
        )

        if current_edit_poly != undefined then
        (
            current_edit_poly.SetPrimaryNode node
            current_edit_poly.useStackSelection = false
            modPanel.setCurrentObject current_edit_poly
            current_edit_poly.SetEPolySelLevel #Vertex
            subObjectLevel = 1
            current_edit_poly.SetSelection #Vertex #{} node:node
            current_edit_poly.Select #Vertex cached_inner_verts node:node
        )
        else
        (
            base_obj = node.baseObject
            if classOf base_obj != Editable_Poly then
            (
                last_slice_report = node.name + ": Check Corners requires Editable Poly or Edit Poly."
                return false
            )

            modPanel.setCurrentObject base_obj
            subObjectLevel = 1
            polyop.setVertSelection base_obj cached_inner_verts
        )

        last_slice_report = node.name + ":\n" + \
            "  INNER VERTS FROM RESET SLICING: " + (cached_inner_verts as string) + "\n" + \
            "  COUNT: " + (cached_inner_verts.numberSet as string)

        if not batch_quiet then format "Wall-Fixer Check Corners:\n%\n" last_slice_report
        completeRedraw()
        true
        -- return
    ),

    /*
    Performs exactly one debug slice through one detected inner corner on the first selected wall.
    The raw slice result is kept for inspection and every edge not present before the slice remains selected.
    */
    function debugMakeOneSlice cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 update_viewport_selection:true =
    (
        if not batch_quiet then format "\n"

        local selected_nodes = selection as array
        last_slice_report = ""
        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select one wall before running Make 1 Slice."
            return false
        )
        local node = selected_nodes[1]
        undo "Wall-Fixer - Debug Make 1 Slice" on
        (
            if not(processNode node cut_mode:cut_mode slice_plane_mode:slice_plane_mode angle_threshold:angle_threshold planar_tolerance:planar_tolerance operation_mode:#oneSlice update_viewport_selection:update_viewport_selection) then
            (
                last_slice_report = node.name + ": " + (last_slice_error as string)
            )
        )

        local remaining_inner_vertices = getRemainingResetInnerVertSelection node \
            cut_mode:cut_mode \
            slice_plane_mode:slice_plane_mode \
            angle_threshold:angle_threshold \
            planar_tolerance:planar_tolerance
        if remaining_inner_vertices != undefined then
        (
            if not batch_quiet then format "REMAINING INNER VERTS: %\n" remaining_inner_vertices
        )

        if update_viewport_selection then completeRedraw()
        last_slice_error == undefined
        -- return
    ),
    /*
    Adds a fresh Mass Slice working Edit Poly above a manual Cleanup LOOPS modifier when needed.
    The existing loop-cleanup modifier stays untouched and inspectable below the new slicing modifier.
    */
    function ensureMassSliceWorkingModifier node =
    (
        if node == undefined or not(isValidNode node) then return false

        if node.modifiers.count > 0 then
        (
            local top_modifier = node.modifiers[1]
            if classOf top_modifier == Edit_Poly and top_modifier.name == "WMC - CLEANUP LOOPS" then
            (
                local working_modifier = Edit_Poly name:"WMC - WALL TOPOLOGY CLEANUP"
                addModifier node working_modifier
                update node
                if not batch_quiet then format "Wall-Fixer Slice Selected Walls: added fresh working Edit Poly above %.\n" top_modifier.name
            )
        )

        true
        -- return
    ),

    /*
    Returns the number of currently live Edit Poly vertex slots.
    Dead topology slots are ignored because GetVertex returns undefined for them.
    */
    function getLiveEditPolyVertexCount node modifier =
    (
        local live_count = 0
        local vertex_count = modifier.GetNumVertices node:node

        for vertex_index = 1 to vertex_count do
        (
            local vertex_position = undefined
            try
            (
                vertex_position = modifier.GetVertex vertex_index node:node
            )
            catch
            (
                vertex_position = undefined
            )
            if vertex_position != undefined then live_count += 1
        )

        live_count
        -- return
    ),

    /*
    Finds the current live Edit Poly vertex nearest to one base-anchor world position.
    This remaps the anchor after topology commits without relying on a specific surviving vertex ID.
    */
    function findLiveEditPolyVertexAtWorldPoint node modifier target_world precision_threshold:0.01 exclude_vertex:0 =
    (
        local best_vertex = 0
        local best_distance = 1e30
        local vertex_count = modifier.GetNumVertices node:node
        local object_tm = node.objectTransform
        local search_tolerance = amax precision_threshold epsilon

        for vertex_index = 1 to vertex_count do
        (
            local vertex_position = undefined
            if vertex_index != exclude_vertex then
            (
                try
                (
                    vertex_position = modifier.GetVertex vertex_index node:node
                )
                catch
                (
                    vertex_position = undefined
                )
            )

            if vertex_position != undefined then
            (
                local world_position = vertex_position * object_tm
                local current_distance = distance world_position target_world
                if current_distance < best_distance then
                (
                    best_distance = current_distance
                    best_vertex = vertex_index
                )
            )
        )

        if best_distance <= search_tolerance then best_vertex else 0
        -- return
    ),

    /*
    Moves one confirmed new slice vertex exactly onto one existing pre-slice vertex and collapses only that pair.
    The precision threshold authorizes this targeted repair; the normal Weld Threshold is never used here.
    */
    function weldMassSliceVertexToAnchor node modifier new_vertex_index anchor_world precision_threshold:0.01 =
    (
        local anchor_vertex_index = findLiveEditPolyVertexAtWorldPoint node modifier anchor_world precision_threshold:precision_threshold exclude_vertex:new_vertex_index
        if anchor_vertex_index <= 0 then return false
        if new_vertex_index == anchor_vertex_index then return true

        local new_position = undefined
        local anchor_position = undefined
        try
        (
            new_position = modifier.GetVertex new_vertex_index node:node
            anchor_position = modifier.GetVertex anchor_vertex_index node:node
        )
        catch
        (
            new_position = undefined
            anchor_position = undefined
        )
        if new_position == undefined or anchor_position == undefined then return false

        local object_tm = node.objectTransform
        local world_distance = distance (new_position * object_tm) (anchor_position * object_tm)
        if world_distance > precision_threshold then return false

        local before_live_count = getLiveEditPolyVertexCount node modifier
        local single_selection = #{}
        single_selection[new_vertex_index] = true

        modifier.SetEPolySelLevel #Vertex
        modifier.SetSelection #Vertex #{} node:node
        modifier.Select #Vertex single_selection node:node
        if (modifier.GetSelection #Vertex node:node) != single_selection then return false
        modifier.SetOperation #Transform
        modifier.MoveSelection (anchor_position - new_position) parent:(modifier.GetNodeTM node:node) axis:(modifier.GetNodeTM node:node)
        modifier.Commit()
        update node
        modifier.RefreshScreen()

        anchor_vertex_index = findLiveEditPolyVertexAtWorldPoint node modifier anchor_world precision_threshold:precision_threshold exclude_vertex:new_vertex_index
        if anchor_vertex_index <= 0 then return false

        local moved_position = undefined
        try
        (
            moved_position = modifier.GetVertex new_vertex_index node:node
            anchor_position = modifier.GetVertex anchor_vertex_index node:node
        )
        catch
        (
            moved_position = undefined
            anchor_position = undefined
        )
        if moved_position == undefined then return true
        if anchor_position == undefined then return false
        if distance moved_position anchor_position > epsilon then return false

        local pair_selection = #{}
        pair_selection[new_vertex_index] = true
        pair_selection[anchor_vertex_index] = true
        local repair_method = #none
        local repair_success = false

        /* Use the same proven Collapse/Weld sequence as sliced-edge vertex cleanup. */
        modifier.SetSelection #Vertex #{} node:node
        modifier.Select #Vertex pair_selection node:node
        if (modifier.GetSelection #Vertex node:node) != pair_selection then return false
        modifier.ButtonOp #CollapseVertex
        modifier.Commit()
        update node
        modifier.RefreshScreen()

        local after_live_count = getLiveEditPolyVertexCount node modifier
        local anchor_after = findLiveEditPolyVertexAtWorldPoint node modifier anchor_world precision_threshold:precision_threshold
        repair_success = after_live_count < before_live_count and anchor_after > 0
        if repair_success then repair_method = #buttonCollapse

        if not repair_success then
        (
            anchor_vertex_index = findLiveEditPolyVertexAtWorldPoint node modifier anchor_world precision_threshold:precision_threshold exclude_vertex:new_vertex_index
            if anchor_vertex_index > 0 then
            (
                pair_selection = #{}
                pair_selection[new_vertex_index] = true
                pair_selection[anchor_vertex_index] = true
                modifier.SetSelection #Vertex #{} node:node
                modifier.Select #Vertex pair_selection node:node
                if (modifier.GetSelection #Vertex node:node) != pair_selection then return false
                modifier.SetOperation #CollapseVertex
                modifier.Commit()
                update node
                modifier.RefreshScreen()

                after_live_count = getLiveEditPolyVertexCount node modifier
                anchor_after = findLiveEditPolyVertexAtWorldPoint node modifier anchor_world precision_threshold:precision_threshold
                repair_success = after_live_count < before_live_count and anchor_after > 0
                if repair_success then repair_method = #operationCollapse
            )
        )

        if not repair_success then
        (
            anchor_vertex_index = findLiveEditPolyVertexAtWorldPoint node modifier anchor_world precision_threshold:precision_threshold exclude_vertex:new_vertex_index
            if anchor_vertex_index > 0 then
            (
                pair_selection = #{}
                pair_selection[new_vertex_index] = true
                pair_selection[anchor_vertex_index] = true
                modifier.SetSelection #Vertex #{} node:node
                modifier.Select #Vertex pair_selection node:node
                if (modifier.GetSelection #Vertex node:node) != pair_selection then return false
                modifier.ButtonOp #WeldVertex
                modifier.Commit()
                update node
                modifier.RefreshScreen()

                after_live_count = getLiveEditPolyVertexCount node modifier
                anchor_after = findLiveEditPolyVertexAtWorldPoint node modifier anchor_world precision_threshold:precision_threshold
                repair_success = after_live_count < before_live_count and anchor_after > 0
                if repair_success then repair_method = #buttonWeld
            )
        )

        if not batch_quiet then format "Wall-Fixer Slice Precision Repair: newVert:% anchor:% distance:% threshold:% liveBefore:% liveAfter:% method:% success:%\n" new_vertex_index anchor_vertex_index world_distance precision_threshold before_live_count after_live_count repair_method repair_success
        repair_success
        -- return
    ),

    /*
    Finds every vertex created by the latest Make 1 Slice inside the Slice Precision radius of either slice-end anchor.
    All live new vertices around each anchor are collected, including multiple vertices created by hidden-edge intersections.
    */
    function getMassSlicePrecisionCandidates node precision_threshold:0.01 =
    (
        local candidate_vertices = #{}
        local repair_pairs = #()
        local inspection_vertices = #{}
        if precision_threshold <= 0.0 then return #(candidate_vertices, repair_pairs, inspection_vertices)
        if node == undefined or not(isValidNode node) then return #(candidate_vertices, repair_pairs, inspection_vertices)
        if last_debug_slice_node != node then return #(candidate_vertices, repair_pairs, inspection_vertices)
        if last_debug_slice_original_vertices.numberSet == 0 then return #(candidate_vertices, repair_pairs, inspection_vertices)
        if node.modifiers.count == 0 then return #(candidate_vertices, repair_pairs, inspection_vertices)

        local modifier = node.modifiers[1]
        if classOf modifier != Edit_Poly then return #(candidate_vertices, repair_pairs, inspection_vertices)

        local current_vertex_count = modifier.GetNumVertices node:node
        local object_tm = node.objectTransform
        local anchor_vertices = #()
        local anchor_candidate_sets = #()

        for anchor_vertex_index in last_debug_slice_start_vertices do
        (
            local anchor_is_original = anchor_vertex_index <= last_debug_slice_original_vertices.count and last_debug_slice_original_vertices[anchor_vertex_index]
            if anchor_is_original and anchor_vertex_index >= 1 and anchor_vertex_index <= current_vertex_count then
            (
                local anchor_position = undefined
                try
                (
                    anchor_position = modifier.GetVertex anchor_vertex_index node:node
                )
                catch
                (
                    anchor_position = undefined
                )

                if anchor_position != undefined then
                (
                    append anchor_vertices #(anchor_vertex_index, anchor_position * object_tm)
                    append anchor_candidate_sets #{}
                )
            )
        )

        /* Fallback keeps precision repair usable if an older/manual slice cache has no explicit start vertices. */
        if anchor_vertices.count == 0 then
        (
            for original_vertex_index in last_debug_slice_original_vertices do
            (
                if original_vertex_index >= 1 and original_vertex_index <= current_vertex_count then
                (
                    local original_position = undefined
                    try
                    (
                        original_position = modifier.GetVertex original_vertex_index node:node
                    )
                    catch
                    (
                        original_position = undefined
                    )

                    if original_position != undefined then
                    (
                        append anchor_vertices #(original_vertex_index, original_position * object_tm)
                        append anchor_candidate_sets #{}
                    )
                )
            )
        )

        for vertex_index = 1 to current_vertex_count do
        (
            local existed_before_slice = vertex_index <= last_debug_slice_original_vertices.count and last_debug_slice_original_vertices[vertex_index]
            if not existed_before_slice then
            (
                local vertex_position = undefined
                local incident_edge_count = 0
                local vertex_query_ok = true

                try
                (
                    vertex_position = modifier.GetVertex vertex_index node:node
                    if vertex_position != undefined then
                    (
                        incident_edge_count = modifier.GetVertexEdgeCount vertex_index node:node
                    )
                )
                catch
                (
                    vertex_query_ok = false
                )

                if vertex_query_ok and vertex_position != undefined and incident_edge_count > 0 then
                (
                    local vertex_world = vertex_position * object_tm
                    local nearest_anchor_array_index = 0
                    local nearest_anchor_index = 0
                    local nearest_anchor_world = undefined
                    local nearest_distance = 1e30

                    for anchor_array_index = 1 to anchor_vertices.count do
                    (
                        local anchor_item = anchor_vertices[anchor_array_index]
                        local current_distance = distance vertex_world anchor_item[2]
                        if current_distance <= precision_threshold and current_distance < nearest_distance then
                        (
                            nearest_distance = current_distance
                            nearest_anchor_array_index = anchor_array_index
                            nearest_anchor_index = anchor_item[1]
                            nearest_anchor_world = anchor_item[2]
                        )
                    )

                    if nearest_anchor_array_index > 0 then
                    (
                        candidate_vertices[vertex_index] = true
                        inspection_vertices[vertex_index] = true
                        inspection_vertices[nearest_anchor_index] = true
                        anchor_candidate_sets[nearest_anchor_array_index][vertex_index] = true
                        append repair_pairs #(vertex_index, nearest_anchor_index, nearest_anchor_world, nearest_distance)
                    )
                )
            )
        )

        for anchor_array_index = 1 to anchor_vertices.count do
        (
            if not batch_quiet then format "Wall-Fixer Slice Precision Anchor: node:% anchor:% threshold:% candidates:%\n"                 node.name anchor_vertices[anchor_array_index][1] precision_threshold anchor_candidate_sets[anchor_array_index]
        )
        if not batch_quiet then format "Wall-Fixer Slice Precision Candidates: node:% threshold:% candidates:%\n" node.name precision_threshold candidate_vertices
        if not batch_quiet then format "Wall-Fixer Slice Precision Inspection: node:% threshold:% inspection:%\n" node.name precision_threshold inspection_vertices
        #(candidate_vertices, repair_pairs, inspection_vertices)
        -- return
    ),

    /*
    Returns true when one slice-created precision-candidate vertex ID is still live.
    Pre-slice vertices are never accepted as precision candidates.
    */
    function isMassSlicePrecisionCandidateLive node modifier vertex_index =
    (
        if node == undefined or not(isValidNode node) then return false
        if modifier == undefined then return false
        if vertex_index < 1 or vertex_index > modifier.GetNumVertices node:node then return false
        if vertex_index <= last_debug_slice_original_vertices.count and last_debug_slice_original_vertices[vertex_index] then return false

        local vertex_position = undefined
        local incident_edge_count = 0
        local query_ok = true

        try
        (
            vertex_position = modifier.GetVertex vertex_index node:node
            if vertex_position != undefined then
            (
                incident_edge_count = modifier.GetVertexEdgeCount vertex_index node:node
            )
        )
        catch
        (
            query_ok = false
        )

        query_ok and vertex_position != undefined and incident_edge_count > 0
        -- return
    ),

    /*
    Re-resolves one precision candidate without ever resolving onto an original pre-slice vertex.
    Preferred vertex ID is used first so exact duplicate candidates can be repaired independently.
    */
    function findMassSlicePrecisionCandidate node modifier preferred_vertex saved_position tolerance:0.01 =
    (
        if node == undefined or not(isValidNode node) then return 0
        if modifier == undefined or saved_position == undefined then return 0

        if isMassSlicePrecisionCandidateLive node modifier preferred_vertex then
        (
            local preferred_position = modifier.GetVertex preferred_vertex node:node
            if preferred_position != undefined and distance preferred_position saved_position <= tolerance then return preferred_vertex
        )

        local vertex_count = modifier.GetNumVertices node:node
        local found_vertex = 0
        local found_distance = undefined

        for vertex_index = 1 to vertex_count do
        (
            if isMassSlicePrecisionCandidateLive node modifier vertex_index then
            (
                local vertex_position = modifier.GetVertex vertex_index node:node
                if vertex_position != undefined then
                (
                    local vertex_distance = distance vertex_position saved_position
                    if vertex_distance <= tolerance then
                    (
                        if found_distance == undefined or vertex_distance < found_distance then
                        (
                            found_distance = vertex_distance
                            found_vertex = vertex_index
                        )
                    )
                )
            )
        )

        found_vertex
        -- return
    ),

    /*
    Finds the original pre-slice anchor nearest to one saved world-space anchor point.
    Only vertices that existed before Make 1 Slice are eligible anchor targets.
    */
    function findMassSlicePrecisionOriginalAnchor node modifier preferred_anchor anchor_world precision_threshold:0.01 =
    (
        if node == undefined or not(isValidNode node) then return 0
        if modifier == undefined or anchor_world == undefined then return 0

        local object_tm = node.objectTransform
        local vertex_count = modifier.GetNumVertices node:node
        local best_vertex = 0
        local best_distance = undefined

        if preferred_anchor >= 1 and preferred_anchor <= vertex_count then
        (
            local preferred_is_original = preferred_anchor <= last_debug_slice_original_vertices.count and last_debug_slice_original_vertices[preferred_anchor]
            if preferred_is_original then
            (
                local preferred_position = undefined
                try
                (
                    preferred_position = modifier.GetVertex preferred_anchor node:node
                )
                catch
                (
                    preferred_position = undefined
                )

                if preferred_position != undefined then
                (
                    local preferred_distance = distance (preferred_position * object_tm) anchor_world
                    if preferred_distance <= precision_threshold then return preferred_anchor
                )
            )
        )

        for vertex_index in last_debug_slice_original_vertices do
        (
            if vertex_index >= 1 and vertex_index <= vertex_count then
            (
                local vertex_position = undefined
                try
                (
                    vertex_position = modifier.GetVertex vertex_index node:node
                )
                catch
                (
                    vertex_position = undefined
                )

                if vertex_position != undefined then
                (
                    local vertex_distance = distance (vertex_position * object_tm) anchor_world
                    if vertex_distance <= precision_threshold then
                    (
                        if best_distance == undefined or vertex_distance < best_distance then
                        (
                            best_distance = vertex_distance
                            best_vertex = vertex_index
                        )
                    )
                )
            )
        )

        best_vertex
        -- return
    ),

    /*
    Removes one confirmed precision vertex with the same Remove Vertex sequence proven by Clean Up Sliced Edges.
    The selected new vertex is removed directly while the original pre-slice anchor is explicitly protected and verified.
    */
    function removeMassSlicePrecisionVertex node modifier preferred_vertex saved_position preferred_anchor anchor_world precision_threshold:0.01 allow_collapse_fallback:true =
    (
        local lookup_tolerance = amax 0.0001 (amin precision_threshold 0.01)
        local current_vertex = findMassSlicePrecisionCandidate node modifier preferred_vertex saved_position tolerance:lookup_tolerance
        if current_vertex <= 0 then return #(true, 0, #alreadyGone, "")

        local anchor_vertex = findMassSlicePrecisionOriginalAnchor node modifier preferred_anchor anchor_world precision_threshold:precision_threshold
        if anchor_vertex <= 0 then return #(false, current_vertex, #protected, "original pre-slice anchor could not be resolved")

        local object_tm = node.objectTransform
        local current_position = modifier.GetVertex current_vertex node:node
        local anchor_position = modifier.GetVertex anchor_vertex node:node
        if current_position == undefined or anchor_position == undefined then return #(false, current_vertex, #protected, "precision candidate or anchor has no live position")

        local world_distance = distance (current_position * object_tm) (anchor_position * object_tm)
        if world_distance > precision_threshold then return #(false, current_vertex, #protected, "precision candidate is outside Slice Precision threshold")

        local methods = #(#buttonRemoveVertex, #operationRemoveVertex)
        for method in methods do
        (
            current_vertex = findMassSlicePrecisionCandidate node modifier current_vertex saved_position tolerance:lookup_tolerance
            if current_vertex <= 0 then return #(true, 0, method, "")

            anchor_vertex = findMassSlicePrecisionOriginalAnchor node modifier preferred_anchor anchor_world precision_threshold:precision_threshold
            if anchor_vertex <= 0 then return #(false, current_vertex, method, "original pre-slice anchor disappeared before precision repair")

            local before_live_count = getLiveEditPolyVertexCount node modifier
            local requested_selection = #{}
            requested_selection[current_vertex] = true
            local actual_selection = #{}
            local operation_error = undefined

            try
            (
                modifier.SetEPolySelLevel #Vertex
                modifier.SetSelection #Vertex #{} node:node
                modifier.Select #Vertex requested_selection node:node
                actual_selection = modifier.GetSelection #Vertex node:node
                if actual_selection != requested_selection then throw "Edit Poly vertex selection did not match the requested Slice Precision vertex."

                if method == #buttonRemoveVertex then
                (
                    modifier.ButtonOp #RemoveVertex
                )
                else
                (
                    modifier.SetOperation #RemoveVertex
                    modifier.Commit()
                )

                update node
                modifier.RefreshScreen()
            )
            catch
            (
                operation_error = getCurrentException()
            )

            local after_live_count = getLiveEditPolyVertexCount node modifier
            local candidate_still_live = isMassSlicePrecisionCandidateLive node modifier current_vertex
            local anchor_after = findMassSlicePrecisionOriginalAnchor node modifier preferred_anchor anchor_world precision_threshold:precision_threshold
            local removed = operation_error == undefined and not candidate_still_live and anchor_after > 0 and after_live_count < before_live_count
            local failure_reason = ""

            if operation_error != undefined then failure_reason = operation_error as string
            else if candidate_still_live then failure_reason = "selected precision vertex is still live after Remove Vertex"
            else if anchor_after <= 0 then failure_reason = "original pre-slice anchor disappeared after Remove Vertex"
            else if after_live_count >= before_live_count then failure_reason = "live vertex count did not decrease"

            if not batch_quiet then format "Wall-Fixer Slice Precision Remove Attempt: preferredVert:% currentVert:% anchor:% distance:% method:% selectedVerts:% liveBefore:% liveAfter:% success:% reason:%\n" \
                preferred_vertex current_vertex anchor_vertex world_distance method actual_selection before_live_count after_live_count removed failure_reason

            if removed then return #(true, current_vertex, method, "")
        )

        current_vertex = findMassSlicePrecisionCandidate node modifier preferred_vertex saved_position tolerance:lookup_tolerance
        if current_vertex <= 0 then return #(true, 0, #alreadyGone, "")
        if not allow_collapse_fallback then return #(false, current_vertex, #removeVertexOnly, "Remove Vertex did not remove the precision candidate; base anchor collapse is disabled.")

        anchor_vertex = findMassSlicePrecisionOriginalAnchor node modifier preferred_anchor anchor_world precision_threshold:precision_threshold
        if anchor_vertex <= 0 then return #(false, current_vertex, #collapseToAnchor, "original pre-slice anchor could not be resolved for collapse fallback")

        current_position = modifier.GetVertex current_vertex node:node
        anchor_position = modifier.GetVertex anchor_vertex node:node
        if current_position == undefined or anchor_position == undefined then return #(false, current_vertex, #collapseToAnchor, "precision collapse fallback has no live position")

        local move_amount = anchor_position - current_position
        local single_selection = #{}
        single_selection[current_vertex] = true
        local pair_selection = #{}
        pair_selection[current_vertex] = true
        pair_selection[anchor_vertex] = true
        local collapse_error = undefined
        local collapse_before_count = getLiveEditPolyVertexCount node modifier

        try
        (
            modifier.SetEPolySelLevel #Vertex
            modifier.SetSelection #Vertex #{} node:node
            modifier.SetSelection #Vertex single_selection node:node
            modifier.SetOperation #Transform
            modifier.MoveSelection move_amount parent:(modifier.GetNodeTM node:node) axis:(modifier.GetNodeTM node:node)
            modifier.Commit()
            update node
            modifier.RefreshScreen()

            modifier.SetSelection #Vertex #{} node:node
            modifier.SetSelection #Vertex pair_selection node:node
            modifier.SetOperation #CollapseVertex
            modifier.Commit()
            update node
            modifier.RefreshScreen()
        )
        catch
        (
            collapse_error = getCurrentException()
        )

        local collapse_after_count = getLiveEditPolyVertexCount node modifier
        local anchor_after = findLiveEditPolyVertexAtWorldPoint node modifier anchor_world precision_threshold:precision_threshold
        local collapse_success = collapse_error == undefined and collapse_after_count < collapse_before_count and anchor_after > 0
        local collapse_reason = if collapse_error != undefined then collapse_error as string else if collapse_after_count >= collapse_before_count then "live vertex count did not decrease during collapse fallback" else if anchor_after <= 0 then "no live vertex remains at the original anchor after collapse fallback" else ""

        if not batch_quiet then format "Wall-Fixer Slice Precision Collapse Fallback: preferredVert:% currentVert:% anchor:% liveBefore:% liveAfter:% success:% reason:%\n" \
            preferred_vertex current_vertex anchor_vertex collapse_before_count collapse_after_count collapse_success collapse_reason

        #(collapse_success, current_vertex, #collapseToAnchor, collapse_reason)
        -- return
    ),

    /*
    Collapses one anchor plus all saved precision vertices paired to that anchor, then restores the exact anchor position.
    The cluster is re-resolved by position so the opposite side remains safe after topology renumbering.
    */
    function collapseMassSlicePrecisionAnchorCluster node modifier anchor_world candidate_world_positions precision_threshold:0.01 =
    (
        if node == undefined or not(isValidNode node) then return #(false, #{}, 0, "invalid node")
        if modifier == undefined then return #(false, #{}, 0, "invalid Edit Poly modifier")
        if anchor_world == undefined then return #(false, #{}, 0, "missing anchor position")
        if candidate_world_positions.count == 0 then return #(true, #{}, 0, "")

        local anchor_vertex = findLiveEditPolyVertexAtWorldPoint node modifier anchor_world precision_threshold:precision_threshold
        if anchor_vertex <= 0 then return #(false, #{}, 0, "anchor vertex could not be resolved")

        local anchor_position = undefined
        try
        (
            anchor_position = modifier.GetVertex anchor_vertex node:node
        )
        catch
        (
            anchor_position = undefined
        )
        if anchor_position == undefined then return #(false, #{}, 0, "anchor vertex has no live position")

        local lookup_tolerance = amax epsilon (amin precision_threshold 0.01)
        local object_tm = node.objectTransform
        local cluster_selection = #{}
        local vertex_count = modifier.GetNumVertices node:node

        cluster_selection[anchor_vertex] = true

        for vertex_index = 1 to vertex_count do
        (
            local vertex_position = undefined
            try
            (
                vertex_position = modifier.GetVertex vertex_index node:node
            )
            catch
            (
                vertex_position = undefined
            )

            if vertex_position != undefined then
            (
                local vertex_world = vertex_position * object_tm
                local matches_candidate = false

                for candidate_world in candidate_world_positions while not matches_candidate do
                (
                    if distance vertex_world candidate_world <= lookup_tolerance then matches_candidate = true
                )

                if matches_candidate then cluster_selection[vertex_index] = true
            )
        )

        if cluster_selection.numberSet <= 1 then return #(false, cluster_selection, anchor_vertex, "precision cluster contains no redundant vertex")

        local live_before = getLiveEditPolyVertexCount node modifier
        local actual_selection = #{}
        local collapse_error = undefined

        try
        (
            modifier.SetEPolySelLevel #Vertex
            modifier.SetSelection #Vertex #{} node:node
            modifier.Select #Vertex cluster_selection node:node
            actual_selection = modifier.GetSelection #Vertex node:node
            if actual_selection != cluster_selection then throw "Edit Poly collapse selection did not match the requested Slice Precision cluster."

            modifier.ButtonOp #CollapseVertex
            update node
            ::WallFixer.refreshDebugModifierTopology node
            modifier.RefreshScreen()
        )
        catch
        (
            collapse_error = getCurrentException()
        )

        local live_after_collapse = getLiveEditPolyVertexCount node modifier
        if collapse_error != undefined then return #(false, cluster_selection, 0, collapse_error as string)

        /*
        Fall back to the targeted precision-pair repair when CollapseVertex refuses a valid connected cluster.
        Each saved precision vertex is re-resolved by world position, moved onto the saved anchor, then collapsed/welded only with that anchor.
        */
        if live_after_collapse >= live_before then
        (
            local fallback_success = true

            for candidate_world in candidate_world_positions while fallback_success do
            (
                local current_anchor_vertex = findLiveEditPolyVertexAtWorldPoint node modifier anchor_world precision_threshold:precision_threshold
                local current_candidate_vertex = 0

                if current_anchor_vertex > 0 then
                (
                    current_candidate_vertex = findLiveEditPolyVertexAtWorldPoint node modifier candidate_world precision_threshold:precision_threshold exclude_vertex:current_anchor_vertex
                )

                if current_candidate_vertex > 0 then
                (
                    fallback_success = weldMassSliceVertexToAnchor node modifier current_candidate_vertex anchor_world precision_threshold:precision_threshold
                )
            )

            live_after_collapse = getLiveEditPolyVertexCount node modifier
            if not batch_quiet then format "Wall-Fixer Slice Precision Cluster Fallback: anchorWorld:% selected:% liveBefore:% liveAfter:% success:%\n" anchor_world cluster_selection live_before live_after_collapse fallback_success

            if (not fallback_success) or live_after_collapse >= live_before then
            (
                return #(false, cluster_selection, 0, "collapse/weld fallback did not reduce live vertex count")
            )
        )

        local survivor_vertex = findLiveEditPolyVertexAtWorldPoint node modifier anchor_world precision_threshold:precision_threshold
        if survivor_vertex <= 0 then return #(false, cluster_selection, 0, "collapsed survivor could not be resolved near original anchor")

        local survivor_position = undefined
        try
        (
            survivor_position = modifier.GetVertex survivor_vertex node:node
        )
        catch
        (
            survivor_position = undefined
        )
        if survivor_position == undefined then return #(false, cluster_selection, survivor_vertex, "collapsed survivor has no live position")

        local move_amount = anchor_position - survivor_position
        local survivor_selection = #{}
        survivor_selection[survivor_vertex] = true
        local move_error = undefined

        try
        (
            modifier.SetSelection #Vertex #{} node:node
            modifier.SetSelection #Vertex survivor_selection node:node
            modifier.SetOperation #Transform
            modifier.MoveSelection move_amount parent:(modifier.GetNodeTM node:node) axis:(modifier.GetNodeTM node:node)
            modifier.Commit()
            update node
            ::WallFixer.refreshDebugModifierTopology node
            modifier.RefreshScreen()
        )
        catch
        (
            move_error = getCurrentException()
        )

        if move_error != undefined then return #(false, cluster_selection, survivor_vertex, move_error as string)

        local final_position = undefined
        try
        (
            final_position = modifier.GetVertex survivor_vertex node:node
        )
        catch
        (
            final_position = undefined
        )

        local position_ok = final_position != undefined and distance final_position anchor_position <= epsilon
        local cluster_success = position_ok and live_after_collapse <= (live_before - (cluster_selection.numberSet - 1))
        local failure_reason = if not position_ok then "collapsed survivor was not restored to the exact anchor position" else if not cluster_success then "collapse did not merge the full precision cluster" else ""

        if not batch_quiet then format "Wall-Fixer Slice Precision Cluster: anchorWorld:% selected:% liveBefore:% liveAfter:% survivor:% exactPosition:% success:% reason:%\n" \
            anchor_world cluster_selection live_before live_after_collapse survivor_vertex position_ok cluster_success failure_reason

        #(cluster_success, cluster_selection, survivor_vertex, failure_reason)
        -- return
    ),

    /*
    Captures Slice Precision anchor groups before another cleanup changes the latest slice topology.
    Saved world-space positions keep the repair usable after Clean Up Sliced Edges invalidates vertex IDs.
    */
    function captureMassSlicePrecisionCleanupData node precision_threshold:0.01 =
    (
        local candidate_vertices = #{}
        local anchor_groups = #()

        if precision_threshold <= 0.0 then return #(true, candidate_vertices, anchor_groups)
        if node == undefined or not(isValidNode node) then return #(false, candidate_vertices, anchor_groups)
        if last_debug_slice_node != node then return #(false, candidate_vertices, anchor_groups)
        if last_debug_slice_original_vertices.numberSet == 0 then return #(false, candidate_vertices, anchor_groups)
        if node.modifiers.count == 0 then return #(false, candidate_vertices, anchor_groups)

        local modifier = node.modifiers[1]
        if classOf modifier != Edit_Poly then return #(false, candidate_vertices, anchor_groups)

        local precision_data = getMassSlicePrecisionCandidates node precision_threshold:precision_threshold
        candidate_vertices = precision_data[1]
        local repair_pairs = precision_data[2]
        local object_tm = node.objectTransform

        for repair_pair in repair_pairs do
        (
            local candidate_vertex = repair_pair[1]
            local anchor_vertex = repair_pair[2]
            local anchor_world = repair_pair[3]
            local candidate_position = undefined

            try
            (
                candidate_position = modifier.GetVertex candidate_vertex node:node
            )
            catch
            (
                candidate_position = undefined
            )

            if candidate_position != undefined then
            (
                local group_index = 0
                for anchor_group_index = 1 to anchor_groups.count while group_index == 0 do
                (
                    if anchor_groups[anchor_group_index][1] == anchor_vertex then group_index = anchor_group_index
                )

                if group_index == 0 then
                (
                    local candidate_positions = #()
                    local original_candidate_vertices = #{}
                    append candidate_positions (candidate_position * object_tm)
                    original_candidate_vertices[candidate_vertex] = true
                    append anchor_groups #(anchor_vertex, anchor_world, candidate_positions, original_candidate_vertices)
                )
                else
                (
                    append anchor_groups[group_index][3] (candidate_position * object_tm)
                    anchor_groups[group_index][4][candidate_vertex] = true
                )
            )
        )

        if not batch_quiet then format "Wall-Fixer Slice Precision Capture: node:% threshold:% candidates:% groups:%\n" node.name precision_threshold candidate_vertices anchor_groups.count
        #(true, candidate_vertices, anchor_groups)
        -- return
    ),

    /*
    Repairs previously captured Slice Precision anchor groups after other cleanup operations changed topology.
    Each anchor side is collapsed independently and the surviving vertex is restored to the saved anchor position.
    */
    function cleanupCapturedMassSlicePrecisionVerts node precision_cleanup_data precision_threshold:0.01 =
    (
        local empty_candidates = #{}
        if precision_threshold <= 0.0 then return #(true, 0, empty_candidates)
        if node == undefined or not(isValidNode node) then return #(false, 0, empty_candidates)
        if precision_cleanup_data == undefined or precision_cleanup_data.count < 3 then return #(false, 0, empty_candidates)
        if node.modifiers.count == 0 then return #(false, 0, empty_candidates)

        local modifier = node.modifiers[1]
        if classOf modifier != Edit_Poly then return #(false, 0, empty_candidates)

        local candidate_vertices = precision_cleanup_data[2]
        local anchor_groups = precision_cleanup_data[3]
        local repaired_vertices = #{}
        local unresolved_vertices = #{}

        select node
        max modify mode
        modPanel.setCurrentObject modifier
        modifier.SetPrimaryNode node
        modifier.useStackSelection = false

        for anchor_group in anchor_groups do
        (
            local anchor_vertex = anchor_group[1]
            local anchor_world = anchor_group[2]
            local candidate_positions = anchor_group[3]
            local original_candidate_vertices = anchor_group[4]
            local collapse_result = collapseMassSlicePrecisionAnchorCluster node modifier anchor_world candidate_positions precision_threshold:precision_threshold
            local already_clean = (not collapse_result[1]) and collapse_result[2].numberSet == 1 and collapse_result[3] > 0

            if collapse_result[1] or already_clean then
            (
                repaired_vertices += original_candidate_vertices
                if already_clean then
                (
                    if not batch_quiet then format "Wall-Fixer Slice Precision Cluster: node:% anchorVert:% candidates:% already removed by earlier cleanup.\n" node.name anchor_vertex original_candidate_vertices
                )
            )
            else
            (
                unresolved_vertices += original_candidate_vertices
                if not batch_quiet then format "Wall-Fixer Slice Precision Cluster FAILED: node:% anchorVert:% candidates:% reason:%\n" node.name anchor_vertex original_candidate_vertices collapse_result[4]
            )
        )

        modifier.SetSelection #Vertex #{} node:node
        if not batch_quiet then format "Wall-Fixer Slice Precision: node:% threshold:% candidates:% repaired:% unresolved:% groups:%\n" node.name precision_threshold candidate_vertices repaired_vertices unresolved_vertices anchor_groups.count
        #(unresolved_vertices.numberSet == 0, repaired_vertices.numberSet, candidate_vertices)
        -- return
    ),

    /*
    Repairs every precision candidate from the latest Make 1 Slice while preserving all original pre-slice anchors.
    Manual mode captures and repairs immediately; batch mode can keep the same capture across sliced-edge cleanup.
    */
    function cleanupMassSlicePrecisionVerts node precision_threshold:0.01 preserve_base_ids:false =
    (
        if preserve_base_ids then
        (
            local empty_candidates = #{}
            if precision_threshold <= 0.0 then return #(true, 0, empty_candidates)
            if node == undefined or not(isValidNode node) then return #(false, 0, empty_candidates)
            if last_debug_slice_node != node then return #(false, 0, empty_candidates)
            if node.modifiers.count == 0 then return #(false, 0, empty_candidates)

            local modifier = node.modifiers[1]
            if classOf modifier != Edit_Poly then return #(false, 0, empty_candidates)

            local precision_data = getMassSlicePrecisionCandidates node precision_threshold:precision_threshold
            local candidate_vertices = precision_data[1]
            local repair_pairs = precision_data[2]
            if candidate_vertices.numberSet == 0 then return #(true, 0, candidate_vertices)

            /* Capture every new precision vertex before any removal can renumber Edit Poly topology. */
            local repair_items = #()
            for repair_pair in repair_pairs do
            (
                local candidate_vertex = repair_pair[1]
                local candidate_position = undefined
                try
                (
                    candidate_position = modifier.GetVertex candidate_vertex node:node
                )
                catch
                (
                    candidate_position = undefined
                )

                if candidate_position != undefined then
                (
                    append repair_items #(candidate_vertex, candidate_position, repair_pair[2], repair_pair[3])
                )
            )

            local repaired_vertices = #{}
            local unresolved_vertices = #{}

            select node
            max modify mode
            modPanel.setCurrentObject modifier
            modifier.SetPrimaryNode node
            modifier.useStackSelection = false

            for repair_item in repair_items do
            (
                local candidate_vertex = repair_item[1]
                local removal_result = removeMassSlicePrecisionVertex \
                    node \
                    modifier \
                    candidate_vertex \
                    repair_item[2] \
                    repair_item[3] \
                    repair_item[4] \
                    precision_threshold:precision_threshold \
                    allow_collapse_fallback:false

                if removal_result[1] then repaired_vertices[candidate_vertex] = true
                else unresolved_vertices[candidate_vertex] = true
            )

            modifier.SetSelection #Vertex #{} node:node
            if not batch_quiet then format "Wall-Fixer Slice Precision Preserve Base: node:% threshold:% candidates:% repaired:% unresolved:%\n" \
                node.name precision_threshold candidate_vertices repaired_vertices unresolved_vertices

            #(unresolved_vertices.numberSet == 0, repaired_vertices.numberSet, candidate_vertices)
        )
        else
        (
            local precision_cleanup_data = captureMassSlicePrecisionCleanupData node precision_threshold:precision_threshold
            if not precision_cleanup_data[1] then return #(false, 0, precision_cleanup_data[2])

            cleanupCapturedMassSlicePrecisionVerts node precision_cleanup_data precision_threshold:precision_threshold
        )
        -- return
    ),

    /*
    Builds one fixed slice-task queue from unchanged base-object INNER VERTS.
    Horizontal tasks are grouped only inside the same planar wall region so cuts stop at wall corners.
    */
    function buildBaseSliceTaskQueue node cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 horizontal_level_tolerance:0.001 planar_tolerance:1.0 =
    (
        local result = #()
        if node == undefined or not(isValidNode node) then return result

        local reset_inner_vertices = getResetInnerVertSelection node
        if reset_inner_vertices == undefined then return result

        local base_candidates = getBaseInnerSliceCandidates \
            node \
            angle_threshold:angle_threshold \
            source_vertices:reset_inner_vertices \
            planar_tolerance:planar_tolerance

        /* Vertical mode keeps one task per candidate and planar wall region. */
        if cut_mode == #all or cut_mode == #vertical then
        (
            for candidate in base_candidates do
            (
                local base_vertex = candidate[1]
                local direction_available = candidate[2]
                local base_edge = candidate[4]
                local base_anchor = candidate[6]
                local base_axis = if slice_plane_mode == #nextVert then candidate[7] else candidate[9]
                local wall_normal = candidate[11]
                local wall_origin = candidate[12]
                local region_id = candidate[13]

                if direction_available and base_axis != undefined then
                (
                    local task_edges = #{}
                    local task_vertices = #{}
                    if base_edge > 0 then task_edges[base_edge] = true
                    task_vertices[base_vertex] = true

                    append result #(
                        base_vertex,
                        #vertical,
                        base_edge,
                        base_anchor,
                        base_axis,
                        task_edges,
                        task_vertices,
                        base_anchor.z,
                        wall_normal,
                        wall_origin,
                        region_id
                    )
                )
            )
        )

        /* Horizontal mode groups equal Z levels only within the same planar wall region. */
        if cut_mode == #all or cut_mode == #horizontal then
        (
            local horizontal_groups = #()

            for candidate in base_candidates do
            (
                local base_vertex = candidate[1]
                local direction_available = candidate[3]
                local base_edge = candidate[5]
                local base_anchor = candidate[6]
                local base_axis = if slice_plane_mode == #nextVert then candidate[8] else candidate[10]
                local region_id = candidate[13]

                if direction_available and base_axis != undefined then
                (
                    local level_z = base_anchor.z
                    local group_index = 0

                    for index = 1 to horizontal_groups.count while group_index == 0 do
                    (
                        local same_level = abs(horizontal_groups[index][1] - level_z) <= horizontal_level_tolerance
                        local same_region = horizontal_groups[index][5] == region_id

                        if same_level and same_region then
                        (
                            group_index = index
                        )
                    )

                    if group_index == 0 then
                    (
                        local group_edges = #{}
                        local group_vertices = #{}
                        if base_edge > 0 then group_edges[base_edge] = true
                        group_vertices[base_vertex] = true
                        append horizontal_groups #(level_z, candidate, group_edges, group_vertices, region_id)
                    )
                    else
                    (
                        local group_item = horizontal_groups[group_index]
                        if base_edge > 0 then group_item[3][base_edge] = true
                        group_item[4][base_vertex] = true
                    )
                )
            )

            for group_item in horizontal_groups do
            (
                local level_z = group_item[1]
                local representative = group_item[2]
                local group_edges = copy group_item[3]
                local group_vertices = copy group_item[4]
                local region_id = group_item[5]
                local base_vertex = representative[1]
                local base_edge = representative[5]
                local base_anchor = representative[6]
                local base_axis = if slice_plane_mode == #nextVert then representative[8] else representative[10]
                local wall_normal = representative[11]
                local wall_origin = representative[12]

                append result #(
                    base_vertex,
                    #horizontal,
                    base_edge,
                    base_anchor,
                    base_axis,
                    group_edges,
                    group_vertices,
                    level_z,
                    wall_normal,
                    wall_origin,
                    region_id
                )

                if not batch_quiet then format "Wall-Fixer Horizontal Slice Level Group: node:% region:% z:% verts:% edges:% representative:%\n" \
                    node.name region_id level_z group_vertices group_edges base_vertex
            )
        )

        if not batch_quiet then format "Wall-Fixer Base Slice Task Queue: node:% tasks:% innerVerts:%\n" node.name result.count reset_inner_vertices
        result
        -- return
    ),

    /*
    Builds ordered slicing passes and assigns one Edit Poly modifier name to each pass.
    All mode uses one mixed queue; directional modes run the selected direction first and the opposite direction second.
    */
    function buildBaseSlicePassQueue node cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 =
    (
        local slice_passes = #()

        case cut_mode of
        (
            #horizontal:
            (
                local horizontal_tasks = buildBaseSliceTaskQueue \
                    node \
                    cut_mode:#horizontal \
                    slice_plane_mode:slice_plane_mode \
                    angle_threshold:angle_threshold \
                    planar_tolerance:planar_tolerance

                local vertical_tasks = buildBaseSliceTaskQueue \
                    node \
                    cut_mode:#vertical \
                    slice_plane_mode:slice_plane_mode \
                    angle_threshold:angle_threshold \
                    planar_tolerance:planar_tolerance

                append slice_passes #(#horizontal, "SLICE HORIZONTAL", horizontal_tasks)
                append slice_passes #(#vertical, "SLICE VERTICAL", vertical_tasks)
            )
            #vertical:
            (
                local vertical_tasks = buildBaseSliceTaskQueue \
                    node \
                    cut_mode:#vertical \
                    slice_plane_mode:slice_plane_mode \
                    angle_threshold:angle_threshold \
                    planar_tolerance:planar_tolerance

                local horizontal_tasks = buildBaseSliceTaskQueue \
                    node \
                    cut_mode:#horizontal \
                    slice_plane_mode:slice_plane_mode \
                    angle_threshold:angle_threshold \
                    planar_tolerance:planar_tolerance

                append slice_passes #(#vertical, "SLICE VERTICAL", vertical_tasks)
                append slice_passes #(#horizontal, "SLICE HORIZONTAL", horizontal_tasks)
            )
            default:
            (
                local all_tasks = buildBaseSliceTaskQueue \
                    node \
                    cut_mode:#all \
                    slice_plane_mode:slice_plane_mode \
                    angle_threshold:angle_threshold \
                    planar_tolerance:planar_tolerance

                append slice_passes #(#all, "SLICE ALL", all_tasks)
            )
        )

        slice_passes
        -- return
    ),

    /*
    Verifies that the original base-object vertex ids still exist at their unchanged world positions.
    Slicing may append new Edit Poly vertices, but ids 1..baseVertCount must remain immutable anchors.
    */
    function verifyBaseSliceVerticesPreserved node modifier position_tolerance:0.01 =
    (
        if node == undefined or not(isValidNode node) then return false
        if modifier == undefined then return false
        if classOf node.baseObject != Editable_Poly then return false

        local base_obj = node.baseObject
        local base_vertex_count = polyop.getNumVerts base_obj
        local object_tm = node.objectTransform

        for vertex_index = 1 to base_vertex_count do
        (
            local base_world = (polyop.getVert base_obj vertex_index) * object_tm
            local current_world = undefined
            try
            (
                current_world = modifier.GetVertex vertex_index node:node
            )
            catch
            (
                current_world = undefined
            )

            if current_world == undefined then
            (
                if not batch_quiet then format "Wall-Fixer Base Vertex Preservation FAILED: node:% vertex:% reason:missing current Edit Poly vertex.\n" node.name vertex_index
                return false
            )

            if distance base_world current_world > position_tolerance then
            (
                if not batch_quiet then format "Wall-Fixer Base Vertex Preservation FAILED: node:% vertex:% base:% current:% distance:%\n" \
                    node.name vertex_index base_world current_world (distance base_world current_world)
                return false
            )
        )

        if not batch_quiet then format "Wall-Fixer Base Vertex Preservation: node:% baseVerts:% success:true\n" node.name base_vertex_count
        true
        -- return
    ),

    /*
    Executes one fixed base-object slice-task queue inside one named slicing Edit Poly modifier.
    Each call owns exactly one pass; cleanup never controls or regenerates the fixed base-object task queue.
    */
    function executeBaseSliceTaskQueue node slice_tasks modifier_name:"SLICE ALL" angle_threshold:5.0 planar_tolerance:1.0 precision_threshold:0.01 task_index_offset:0 total_task_count:undefined =
    (
        local success_count = 0
        local no_change_count = 0
        local failure = undefined
        local modifier = undefined
        local queue_total = if total_task_count == undefined then slice_tasks.count else total_task_count

        if node == undefined or not(isValidNode node) then return #(false, 0, 0)
        if classOf node.baseObject != Editable_Poly then return #(false, 0, 0)

        try
        (
            modifier = Edit_Poly name:modifier_name
            addModifier node modifier

            select node
            max modify mode
            modPanel.setCurrentObject modifier
            modifier.SetPrimaryNode node
            modifier.split = false
            modifier.useStackSelection = false
            modifier.useSoftSel = false
            modifier.remveEdgeCtrlKey = false

            local pipeline = WMCWallSlicePipeline \
                node:node \
                ep:modifier \
                planarTolerance:(amax 0.0 planar_tolerance) \
                axisTolerance:(amin 45.0 (amax 0.0 angle_threshold)) \
                uiSelection:false

            local task_index = 0
            for slice_task in slice_tasks do
            (
                task_index += 1
                local display_task_index = task_index_offset + task_index

                local base_vertex = slice_task[1]
                local slice_kind = slice_task[2]
                local base_edge = slice_task[3]
                local base_anchor = slice_task[4]
                local base_axis = slice_task[5]
                local task_base_edges = if slice_task.count >= 6 then copy slice_task[6] else #{}
                local task_base_vertices = if slice_task.count >= 7 then copy slice_task[7] else #{}
                local task_level_z = if slice_task.count >= 8 then slice_task[8] else base_anchor.z
                local wall_normal = if slice_task.count >= 9 then slice_task[9] else undefined
                local wall_origin = if slice_task.count >= 10 then slice_task[10] else undefined
                local region_id = if slice_task.count >= 11 then slice_task[11] else 0

                if task_base_edges.numberSet == 0 and base_edge > 0 then task_base_edges[base_edge] = true
                if task_base_vertices.numberSet == 0 then task_base_vertices[base_vertex] = true

                if batch_quiet then
                (
                    format "Wall-Fixer Batch Base Slice Task: node:% task:%/%\n" node.name display_task_index queue_total
                )
                else
                (
                    format "Wall-Fixer Batch Base Slice Task: node:% modifier:% task:%/% region:% baseVert:% baseEdge:% direction:% levelZ:% groupedVerts:%\n" \
                        node.name modifier_name display_task_index queue_total region_id base_vertex base_edge slice_kind task_level_z task_base_vertices
                )

                local slice_result = pipeline.makeOneSliceFromBasePlane \
                    base_vertex \
                    base_anchor \
                    base_axis \
                    slice_kind \
                    wall_normal:wall_normal \
                    wall_origin:wall_origin \
                    plane_tolerance:(amax 0.0 planar_tolerance)

                if slice_result == undefined then
                (
                    no_change_count += 1
                    if not batch_quiet then format "Wall-Fixer Batch Base Slice Task Skip: node:% modifier:% baseVert:% direction:% reason:no topology change.\n" \
                        node.name modifier_name base_vertex slice_kind
                )
                else
                (
                    success_count += 1

                    /* Manual pipeline context for this exact queued slice.
                       The fixed base-object queue stays authoritative and never depends on cleanup results. */
                    last_debug_slice_node = node
                    last_debug_slice_new_edges = copy slice_result[9]
                    last_debug_slice_original_vertices = copy slice_result[12]
                    last_debug_slice_start_vertices = #{}

                    for defining_edge_index in task_base_edges do
                    (
                        local defining_edge_vertices = polyop.getEdgeVerts node.baseObject defining_edge_index
                        if defining_edge_vertices != undefined and defining_edge_vertices.count == 2 then
                        (
                            last_debug_slice_start_vertices[defining_edge_vertices[1]] = true
                            last_debug_slice_start_vertices[defining_edge_vertices[2]] = true
                        )
                    )

                    if not batch_quiet then format "Wall-Fixer Batch Manual Pipeline Context: node:% modifier:% baseVert:% direction:% groupedBaseVerts:% newEdges:% startVerts:% originalVerts:%\n" \
                        node.name modifier_name base_vertex slice_kind task_base_vertices last_debug_slice_new_edges last_debug_slice_start_vertices last_debug_slice_original_vertices.numberSet

                    /* 2. Fix Slice Precision only when this slice produced precision candidates.
                       Batch uses the same candidate rules but removes only new verts so base-object ids stay unchanged. */
                    local precision_data = ::WallFixer.getMassSlicePrecisionCandidates node precision_threshold:precision_threshold
                    local precision_candidates = precision_data[1]
                    local precision_ok = true

                    if precision_candidates.numberSet > 0 then
                    (
                        local precision_cleanup = ::WallFixer.cleanupMassSlicePrecisionVerts \
                            node \
                            precision_threshold:precision_threshold \
                            preserve_base_ids:true
                        precision_ok = precision_cleanup[1]
                        if not batch_quiet then format "Wall-Fixer Batch Fix Slice Precision: node:% modifier:% baseVert:% direction:% candidates:% fixed:% success:%\n" \
                            node.name modifier_name base_vertex slice_kind precision_candidates precision_cleanup[2] precision_ok
                    )
                    else
                    (
                        if not batch_quiet then format "Wall-Fixer Batch Fix Slice Precision Skip: node:% modifier:% baseVert:% direction:% candidates:#{}\n" \
                            node.name modifier_name base_vertex slice_kind
                    )

                    /* 3. Clean Up Sliced Edges only when redundant edge candidates actually exist.
                       A precision failure skips Step 2 for this slice but never stops the fixed base-object queue. */
                    if precision_ok then
                    (
                        local cleanup_data = ::WallFixer.getDebugSlicedEdgeCleanupCandidates node modifier
                        local removable_edges = if cleanup_data == undefined then #{} else cleanup_data[1]

                        if removable_edges.numberSet > 0 then
                        (
                            local cleanup_ok = ::WallFixer.debugCleanUpSlicedEdges final_redraw:false keep_modify_context:true
                            if not batch_quiet then format "Wall-Fixer Batch Clean Up Sliced Edges: node:% modifier:% baseVert:% direction:% removeEdges:% success:%\n" \
                                node.name modifier_name base_vertex slice_kind removable_edges cleanup_ok
                            if not cleanup_ok then
                            (
                                if not batch_quiet then format "Wall-Fixer Batch Clean Up Sliced Edges WARNING: node:% modifier:% baseVert:% direction:% error:%\n" \
                                    node.name modifier_name base_vertex slice_kind last_slice_report
                            )
                        )
                        else
                        (
                            if not batch_quiet then format "Wall-Fixer Batch Clean Up Sliced Edges Skip: node:% modifier:% baseVert:% direction:% removeEdges:#{}\n" \
                                node.name modifier_name base_vertex slice_kind
                        )
                    )
                    else
                    (
                        if not batch_quiet then format "Wall-Fixer Batch Clean Up Sliced Edges Skip: node:% modifier:% baseVert:% direction:% reason:Slice Precision failed.\n" \
                            node.name modifier_name base_vertex slice_kind
                    )

                    /* Return to this pass modifier and continue directly to the next stored base-object task. */
                    select node
                    max modify mode
                    modPanel.setCurrentObject modifier
                    modifier.SetPrimaryNode node
                    modifier.split = false
                    modifier.useStackSelection = false
                    modifier.useSoftSel = false
                    modifier.remveEdgeCtrlKey = false
                )
            )

            if not(::WallFixer.verifyBaseSliceVerticesPreserved node modifier position_tolerance:0.01) then
            (
                throw ("Base-object vertex ids/positions changed in " + modifier_name + ".")
            )
        )
        catch
        (
            failure = getCurrentException()
        )

        if failure != undefined then
        (
            last_slice_error = failure
            last_slice_report = node.name + ": " + (failure as string)
            if not batch_quiet then format "Wall-Fixer Batch Base Slice Queue FAILED: node:% modifier:% error:%\n" node.name modifier_name failure
        )
        else
        (
            if not batch_quiet then format "Wall-Fixer Batch Base Slice Queue Complete: node:% modifier:% tasks:% sliced:% noChange:%\n" \
                node.name modifier_name slice_tasks.count success_count no_change_count
        )

        #(failure == undefined, success_count, no_change_count)
        -- return
    ),

    /*
    Runs a fixed base-object candidate queue on all selected walls.
    The queue is captured once from Reset Slicing and executed entirely in one Wall topology cleanup Edit Poly.
    */
    function debugSliceSelectedWallsInternal cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 slice_precision:0.01 display_hidden_edges:undefined double_side:undefined progress_callback:undefined =
    (
        local all_selected_nodes = selection as array
        local selected_nodes = getBatchSliceProcessNodes all_selected_nodes
        local processed_count = 0
        local skipped_count = all_selected_nodes.count - selected_nodes.count
        last_slice_report = ""
        last_slice_error = undefined

        if all_selected_nodes.count == 0 then
        (
            if progress_callback != undefined then
            (
                try(progress_callback 0 0)catch()
            )

            last_slice_report = "Select at least one wall before running Slice Selected Walls."
            return false
        )

        if skipped_count > 0 then
        (
            if not batch_quiet then format "Wall-Fixer Slice Selected Walls: skipped % four-vertex wall(s) before batch.\n" skipped_count
        )

        if progress_callback != undefined then
        (
            try(progress_callback processed_count selected_nodes.count)catch()
        )

        if selected_nodes.count == 0 then
        (
            last_slice_report = "Slice Selected Walls: all selected walls have only four vertices; nothing to cut."
            select all_selected_nodes
            return true
        )

        local all_ok = true
        local automation_report = ""

        with redraw off
        (
            for node in selected_nodes do
            (
                local node_ok = true
                local node_error = undefined

                if node == undefined or not(isValidNode node) then
                (
                    node_error = "Selected wall became invalid during Slice Selected Walls."
                    node_ok = false
                )
                else
                (
                    /* Every batch starts from the same unchanged base object.
                       Remove only prior slicing modifiers so the requested modifier layout is deterministic. */
                    if not(::WallFixer.removeWallFixerSliceModifiers node) then
                    (
                        node_error = node.name + ": could not clear previous Wall-Fixer slicing modifiers."
                        node_ok = false
                    )
                    else
                    (
                        ::WallFixer.clearResetInnerVertSelection node
                        ::WallFixer.clearLastDebugSliceContext node:node

                        if not(::WallFixer.initializeBaseSliceAnalysis \
                            node \
                            angle_threshold:angle_threshold \
                            planar_tolerance:planar_tolerance \
                            update_viewport_selection:false) then
                        (
                            node_error = node.name + ": base-object planar-region analysis failed before fixed base-object queue. " + (last_slice_error as string)
                            node_ok = false
                        )
                    )

                    local slice_passes = #()
                    local total_task_count = 0

                    if node_ok then
                    (
                        slice_passes = ::WallFixer.buildBaseSlicePassQueue \
                            node \
                            cut_mode:cut_mode \
                            slice_plane_mode:slice_plane_mode \
                            angle_threshold:angle_threshold \
                            planar_tolerance:planar_tolerance

                        for slice_pass in slice_passes do
                        (
                            total_task_count += slice_pass[3].count
                        )
                    )

                    if node_ok and total_task_count == 0 then
                    (
                        node_error = node.name + ": base object has no slice tasks."
                        node_ok = false
                    )
                    else if node_ok then
                    (
                        local task_index_offset = 0
                        local total_sliced_count = 0
                        local total_no_change_count = 0

                        for slice_pass in slice_passes while node_ok do
                        (
                            local pass_kind = slice_pass[1]
                            local modifier_name = slice_pass[2]
                            local pass_tasks = slice_pass[3]

                            local queue_result = ::WallFixer.executeBaseSliceTaskQueue \
                                node \
                                pass_tasks \
                                modifier_name:modifier_name \
                                angle_threshold:angle_threshold \
                                planar_tolerance:planar_tolerance \
                                precision_threshold:slice_precision \
                                task_index_offset:task_index_offset \
                                total_task_count:total_task_count

                            if not queue_result[1] then
                            (
                                node_error = node.name + ": fixed base-object slice pass failed in " + modifier_name + ". " + last_slice_report
                                node_ok = false
                            )
                            else
                            (
                                total_sliced_count += queue_result[2]
                                total_no_change_count += queue_result[3]

                                if not batch_quiet then format "Wall-Fixer Slice Selected Walls Pass Result: node:% modifier:% direction:% tasks:% sliced:% noChange:%\n" \
                                    node.name modifier_name pass_kind pass_tasks.count queue_result[2] queue_result[3]
                            )

                            task_index_offset += pass_tasks.count
                        )

                        if node_ok and not batch_quiet then
                        (
                            format "Wall-Fixer Slice Selected Walls Queue Result: node:% passes:% tasks:% sliced:% noChange:%\n" \
                                node.name slice_passes.count total_task_count total_sliced_count total_no_change_count
                        )
                    )
                )

                if node_ok then
                (
                    local modifier_report = if cut_mode == #all then "SLICE ALL" else if cut_mode == #horizontal then "SLICE HORIZONTAL -> SLICE VERTICAL" else "SLICE VERTICAL -> SLICE HORIZONTAL"
                    automation_report += node.name + ": fixed base-object slice queue complete in " + modifier_report + ".\n"
                )
                else
                (
                    all_ok = false
                    if node_error == undefined then node_error = "Slice Selected Walls stopped before completion."
                    if last_slice_error == undefined then last_slice_error = node_error
                    automation_report += node_error + "\n"
                )

                max create mode

                processed_count += 1
                if progress_callback != undefined then
                (
                    try(progress_callback processed_count selected_nodes.count)catch()
                )
            )
        )

        if display_hidden_edges != undefined or double_side != undefined then
        (
            setNodesDisplayOptions all_selected_nodes hidden_edges:display_hidden_edges double_side:double_side
        )

        select all_selected_nodes
        completeRedraw()
        last_slice_report = automation_report

        all_ok
        -- return
    ),

    /*
    Runs batch slicing with optional quiet Listener output.
    Quiet state is restored after the batch even when the internal operation throws.
    */
    function debugSliceSelectedWalls cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 slice_precision:0.01 display_hidden_edges:undefined double_side:undefined progress_callback:undefined quiet:false =
    (
        local previous_batch_quiet = batch_quiet
        local completed = false
        local batch_failure = undefined

        batch_quiet = quiet

        try
        (
            completed = debugSliceSelectedWallsInternal \
                cut_mode:cut_mode \
                slice_plane_mode:slice_plane_mode \
                angle_threshold:angle_threshold \
                planar_tolerance:planar_tolerance \
                slice_precision:slice_precision \
                display_hidden_edges:display_hidden_edges \
                double_side:double_side \
                progress_callback:progress_callback
        )
        catch
        (
            batch_failure = getCurrentException()
        )

        batch_quiet = previous_batch_quiet

        if batch_failure != undefined then
        (
            throw (batch_failure as string)
        )

        completed
        -- return
    ),

    /*
    Returns the current top Edit Poly used by the debug slicer.
    No persistent object state is stored.
    */
    function getDebugTopologyModifier node =
    (
        if node == undefined or not(isValidNode node) then return undefined
        if node.modifiers.count < 1 then return undefined
        if classOf node.modifiers[1] != Edit_Poly then return undefined
        node.modifiers[1]
        -- return
    ),

    /*
    Returns redundant edges from the last Make 1 Slice.
    The kept chain starts immediately at either defining border-edge vertex and stops when it first reaches another border vertex.
    */
    function getDebugSlicedEdgeCleanupCandidates node modifier =
    (
        if node == undefined or not(isValidNode node) then return undefined
        if modifier == undefined then return undefined
        if last_debug_slice_node != node then return undefined
        if last_debug_slice_new_edges.numberSet == 0 then return undefined
        if last_debug_slice_start_vertices.numberSet == 0 then return undefined

        local edge_count = modifier.GetNumEdges node:node
        local vertex_count = modifier.GetNumVertices node:node
        local usable_new_edges = #{}
        local border_vertices = #{}
        local vertex_new_edges = for vertex_index = 1 to vertex_count collect #{}

        -- Ignore border edges even if Edit Poly reports them as newly created by Slice.
        for edge_index = 1 to edge_count do
        (
            local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
            local edge_b = modifier.GetEdgeVertex edge_index 2 node:node
            local face_a = modifier.GetEdgeFace edge_index 1 node:node
            local face_b = modifier.GetEdgeFace edge_index 2 node:node
            local is_border_edge = false

            if edge_a != undefined and edge_b != undefined and face_a != undefined and face_b != undefined then
            (
                is_border_edge = (face_a == 0) != (face_b == 0)

                if is_border_edge then
                (
                    if edge_a > 0 then border_vertices[edge_a] = true
                    if edge_b > 0 then border_vertices[edge_b] = true
                )

                if edge_index <= last_debug_slice_new_edges.count and last_debug_slice_new_edges[edge_index] and not is_border_edge then
                (
                    if edge_a >= 1 and edge_a <= vertex_count and edge_b >= 1 and edge_b <= vertex_count then
                    (
                        usable_new_edges[edge_index] = true
                        vertex_new_edges[edge_a][edge_index] = true
                        vertex_new_edges[edge_b][edge_index] = true
                    )
                )
            )
        )

        local kept_edges = #{}
        local visited_vertices = #{}
        local queue_vertices = #()
        local queue_index = 1

        -- Both vertices of the defining base border edge are legal starts, even though they are border vertices.
        for start_vertex in last_debug_slice_start_vertices do
        (
            if start_vertex >= 1 and start_vertex <= vertex_count then
            (
                if vertex_new_edges[start_vertex].numberSet > 0 then
                (
                    if not(start_vertex <= visited_vertices.count and visited_vertices[start_vertex]) then
                    (
                        visited_vertices[start_vertex] = true
                        append queue_vertices start_vertex
                    )
                )
            )
        )

        -- No new slice edge touches the defining anchor/direction edge: do not guess what to remove.
        if queue_vertices.count == 0 then return undefined

        while queue_index <= queue_vertices.count do
        (
            local current_vertex = queue_vertices[queue_index]
            queue_index += 1

            for edge_index in vertex_new_edges[current_vertex] do
            (
                local already_kept = edge_index <= kept_edges.count and kept_edges[edge_index]
                if not already_kept then
                (
                    kept_edges[edge_index] = true

                    local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
                    local edge_b = modifier.GetEdgeVertex edge_index 2 node:node
                    local other_vertex = if edge_a == current_vertex then edge_b else edge_a
                    local other_is_border = other_vertex <= border_vertices.count and border_vertices[other_vertex]
                    local other_is_start = other_vertex <= last_debug_slice_start_vertices.count and last_debug_slice_start_vertices[other_vertex]

                    -- The arriving edge is kept, but traversal never crosses the first non-start border vertex.
                    if not other_is_border or other_is_start then
                    (
                        local already_visited = other_vertex <= visited_vertices.count and visited_vertices[other_vertex]
                        if not already_visited then
                        (
                            visited_vertices[other_vertex] = true
                            append queue_vertices other_vertex
                        )
                    )
                )
            )
        )

        local removable_edges = usable_new_edges - kept_edges
        #(removable_edges, kept_edges, usable_new_edges, border_vertices, copy last_debug_slice_start_vertices)
        -- return
    ),

    /*
    Predicts slice-created vertices that become removable after redundant-edge removal.
    Vertices that existed before the current slice and current corner vertices are always protected.
    */
    function getDebugPredictedSlicedEdgeRemovalVertices node modifier removable_edges protected_pre_slice_vertices:#{} angle_threshold:0.1 =
    (
        local endpoint_candidates = #{}
        local removable_new_vertices = #{}
        local protected_base_vertices = #{}
        local protected_corner_vertices = #{}

        if node == undefined or not(isValidNode node) then return #(removable_new_vertices, protected_base_vertices, protected_corner_vertices, endpoint_candidates)
        if modifier == undefined then return #(removable_new_vertices, protected_base_vertices, protected_corner_vertices, endpoint_candidates)

        local vertex_count = modifier.GetNumVertices node:node
        local edge_count = modifier.GetNumEdges node:node

        for edge_index in removable_edges do
        (
            if edge_index >= 1 and edge_index <= edge_count then
            (
                local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
                local edge_b = modifier.GetEdgeVertex edge_index 2 node:node
                if edge_a != undefined and edge_a > 0 then endpoint_candidates[edge_a] = true
                if edge_b != undefined and edge_b > 0 then endpoint_candidates[edge_b] = true
            )
        )

        for vertex_index in endpoint_candidates do
        (
            local existed_before_slice = vertex_index <= protected_pre_slice_vertices.count and protected_pre_slice_vertices[vertex_index]

            if existed_before_slice then
            (
                protected_base_vertices[vertex_index] = true
            )
            else if vertex_index >= 1 and vertex_index <= vertex_count then
            (
                local vertex_position = modifier.GetVertex vertex_index node:node
                local neighbor_vertices = #()
                local incident_edge_count = modifier.GetVertexEdgeCount vertex_index node:node

                for edge_slot = 1 to incident_edge_count do
                (
                    local edge_index = modifier.GetVertexEdge vertex_index edge_slot node:node
                    local edge_is_removed = edge_index != undefined and edge_index > 0 and edge_index <= removable_edges.count and removable_edges[edge_index]
                    if edge_index != undefined and edge_index > 0 and not edge_is_removed then
                    (
                        local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
                        local edge_b = modifier.GetEdgeVertex edge_index 2 node:node
                        local neighbor_index = if edge_a == vertex_index then edge_b else if edge_b == vertex_index then edge_a else 0
                        if neighbor_index > 0 then append neighbor_vertices neighbor_index
                    )
                )

                local is_removable = false
                if vertex_position != undefined and neighbor_vertices.count == 2 then
                (
                    local neighbor_a = modifier.GetVertex neighbor_vertices[1] node:node
                    local neighbor_b = modifier.GetVertex neighbor_vertices[2] node:node
                    if neighbor_a != undefined and neighbor_b != undefined then
                    (
                        local direction_a = neighbor_a - vertex_position
                        local direction_b = neighbor_b - vertex_position
                        if length direction_a > epsilon and length direction_b > epsilon then
                        (
                            local straight_limit = -(cos angle_threshold)
                            is_removable = (dot (normalize direction_a) (normalize direction_b)) <= straight_limit
                        )
                    )
                )

                if is_removable then removable_new_vertices[vertex_index] = true
                else protected_corner_vertices[vertex_index] = true
            )
        )

        #(removable_new_vertices, protected_base_vertices, protected_corner_vertices, endpoint_candidates)
        -- return
    ),

    /*
    Selects redundant edge candidates and their predicted removable slice-created vertices.
    Edge and vertex selections are both stored; Vertex sub-object level is left active for inspection.
    */
    function debugInspectCleanUpSlicedEdges =
    (
        last_slice_error = undefined
        last_slice_report = ""

        local selected_nodes = selection as array
        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select the wall from the last Make 1 Slice."
            return false
        )

        local node = selected_nodes[1]
        local modifier = getDebugTopologyModifier node
        if modifier == undefined then
        (
            last_slice_report = node.name + ": top Wall topology cleanup Edit Poly was not found."
            return false
        )

        local cleanup_data = getDebugSlicedEdgeCleanupCandidates node modifier
        if cleanup_data == undefined then
        (
            last_slice_report = node.name + ": no valid last-slice anchor/direction chain was found. Run Make 1 Slice first."
            if not batch_quiet then format "%\n" last_slice_report
            return false
        )

        local removable_edges = cleanup_data[1]
        local kept_edges = cleanup_data[2]
        local usable_new_edges = cleanup_data[3]
        local start_vertices = cleanup_data[5]
        local base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then
        (
            last_slice_report = node.name + ": base object must be Editable Poly."
            return false
        )

        local protected_pre_slice_vertices = copy last_debug_slice_original_vertices
        local vertex_cleanup_data = getDebugPredictedSlicedEdgeRemovalVertices \
            node \
            modifier \
            removable_edges \
            protected_pre_slice_vertices:protected_pre_slice_vertices
        local removable_new_vertices = vertex_cleanup_data[1]
        local protected_base_vertices = vertex_cleanup_data[2]
        local protected_corner_vertices = vertex_cleanup_data[3]

        select node
        max modify mode
        modPanel.setCurrentObject modifier
        modifier.SetPrimaryNode node
        modifier.useStackSelection = false

        modifier.SetEPolySelLevel #Edge
        subObjectLevel = 2
        modifier.SetSelection #Edge #{} node:node
        if removable_edges.numberSet > 0 then modifier.Select #Edge removable_edges node:node
        local actual_edge_selection = modifier.GetSelection #Edge node:node

        modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1
        modifier.SetSelection #Vertex #{} node:node
        if removable_new_vertices.numberSet > 0 then modifier.Select #Vertex removable_new_vertices node:node
        local actual_vertex_selection = modifier.GetSelection #Vertex node:node

        last_slice_report = node.name + ": sliced edge cleanup candidates selected - edges:" + (actual_edge_selection.numberSet as string) + "; verts:" + (actual_vertex_selection.numberSet as string) + "."
        if not batch_quiet then format "Wall-Fixer Clean Up Sliced Edges Select: cachedLastSlice:% keep:% removeEdges:% selectedEdges:% removeVerts:% selectedVerts:% protectedBaseVerts:% protectedCornerVerts:%\n" usable_new_edges kept_edges removable_edges actual_edge_selection removable_new_vertices actual_vertex_selection protected_base_vertices protected_corner_vertices
        completeRedraw()

        (actual_edge_selection == removable_edges) and (actual_vertex_selection == removable_new_vertices)
        -- return
    ),

    /*
    Returns true when a slice-created vertex has exactly two straight remaining topology edges.
    Direct incident-edge queries keep Step 2 fast on heavily sliced walls.
    */
    function isDebugRemovableSliceVertex node modifier vertex_index angle_threshold:0.1 =
    (
        if node == undefined or not(isValidNode node) then return false
        if modifier == undefined then return false

        local vertex_count = modifier.GetNumVertices node:node
        if vertex_index < 1 or vertex_index > vertex_count then return false

        local vertex_position = modifier.GetVertex vertex_index node:node
        if vertex_position == undefined then return false

        local incident_edge_count = modifier.GetVertexEdgeCount vertex_index node:node
        if incident_edge_count != 2 then return false

        local neighbor_vertices = #()
        for edge_slot = 1 to incident_edge_count do
        (
            local edge_index = modifier.GetVertexEdge vertex_index edge_slot node:node
            if edge_index == undefined or edge_index <= 0 then return false

            local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
            local edge_b = modifier.GetEdgeVertex edge_index 2 node:node
            local neighbor_index = if edge_a == vertex_index then edge_b else if edge_b == vertex_index then edge_a else 0
            if neighbor_index <= 0 then return false
            append neighbor_vertices neighbor_index
        )

        if neighbor_vertices.count != 2 then return false
        local neighbor_a = modifier.GetVertex neighbor_vertices[1] node:node
        local neighbor_b = modifier.GetVertex neighbor_vertices[2] node:node
        if neighbor_a == undefined or neighbor_b == undefined then return false

        local direction_a = neighbor_a - vertex_position
        local direction_b = neighbor_b - vertex_position
        if length direction_a <= epsilon or length direction_b <= epsilon then return false

        local straight_limit = -(cos angle_threshold)
        (dot (normalize direction_a) (normalize direction_b)) <= straight_limit
        -- return
    ),

    /*
    Returns whether an Edit Poly vertex still exists with live connected topology.
    Uses direct vertex-edge adjacency instead of scanning every edge in the modifier.
    */
    function doesDebugModifierVertexExist node modifier vertex_index =
    (
        if node == undefined or not(isValidNode node) then return false
        if modifier == undefined then return false

        local vertex_count = modifier.GetNumVertices node:node
        if vertex_index < 1 or vertex_index > vertex_count then return false

        local vertex_position = undefined
        local incident_edge_count = 0
        local query_ok = true

        try
        (
            vertex_position = modifier.GetVertex vertex_index node:node
            if vertex_position != undefined then
            (
                incident_edge_count = modifier.GetVertexEdgeCount vertex_index node:node
            )
        )
        catch
        (
            query_ok = false
        )

        query_ok and vertex_position != undefined and incident_edge_count > 0
        -- return
    ),


    /*
    Counts currently live Edit Poly vertex slots.
    Dead topology slots are ignored so cleanup success does not depend on GetNumVertices shrinking.
    */
    function getDebugLiveVertexCount node modifier =
    (
        if node == undefined or not(isValidNode node) then return 0
        if modifier == undefined then return 0

        local live_vertex_count = 0
        local vertex_count = modifier.GetNumVertices node:node

        for vertex_index = 1 to vertex_count do
        (
            local vertex_position = undefined
            try
            (
                vertex_position = modifier.GetVertex vertex_index node:node
            )
            catch
            (
                vertex_position = undefined
            )

            if vertex_position != undefined then
            (
                live_vertex_count += 1
            )
        )

        live_vertex_count
        -- return
    ),

    /*
    Finds the closest directly connected neighbour of one Edit Poly vertex.
    Only vertices joined by a current topology edge are considered collapse targets.
    */
    function getDebugClosestNeighborVertex node modifier vertex_index =
    (
        if not(doesDebugModifierVertexExist node modifier vertex_index) then return 0

        local vertex_position = modifier.GetVertex vertex_index node:node
        local incident_edge_count = modifier.GetVertexEdgeCount vertex_index node:node
        local closest_neighbor_index = 0
        local closest_distance = undefined

        for edge_slot = 1 to incident_edge_count do
        (
            local edge_index = modifier.GetVertexEdge vertex_index edge_slot node:node
            if edge_index != undefined and edge_index > 0 then
            (
                local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
                local edge_b = modifier.GetEdgeVertex edge_index 2 node:node
                local neighbor_index = 0

                if edge_a == vertex_index then
                (
                    neighbor_index = edge_b
                )
                else if edge_b == vertex_index then
                (
                    neighbor_index = edge_a
                )

                if neighbor_index != undefined and neighbor_index > 0 then
                (
                    local neighbor_position = modifier.GetVertex neighbor_index node:node
                    if neighbor_position != undefined then
                    (
                        local neighbor_distance = distance vertex_position neighbor_position
                        if closest_distance == undefined or neighbor_distance < closest_distance then
                        (
                            closest_distance = neighbor_distance
                            closest_neighbor_index = neighbor_index
                        )
                    )
                )
            )
        )

        closest_neighbor_index
        -- return
    ),

    /*
    Finds a live vertex created by the current slice using its saved object-space position.
    Vertices that existed before this slice are excluded even when they came from a lower modifier.
    */
    function findDebugSliceVertexByPosition node modifier target_position protected_vertices:#{} tolerance:0.01 =
    (
        if node == undefined or not(isValidNode node) then return 0
        if modifier == undefined or target_position == undefined then return 0

        local vertex_count = modifier.GetNumVertices node:node
        local found_vertex_index = 0
        local closest_distance = undefined

        for vertex_index = 1 to vertex_count do
        (
            local existed_before_slice = vertex_index <= protected_vertices.count and protected_vertices[vertex_index]

            if not existed_before_slice and doesDebugModifierVertexExist node modifier vertex_index then
            (
                local vertex_position = modifier.GetVertex vertex_index node:node
                if vertex_position != undefined then
                (
                    local vertex_distance = distance vertex_position target_position
                    if vertex_distance <= tolerance then
                    (
                        if closest_distance == undefined or vertex_distance < closest_distance then
                        (
                            closest_distance = vertex_distance
                            found_vertex_index = vertex_index
                        )
                    )
                )
            )
        )

        found_vertex_index
        -- return
    ),


    /* Finds any live Edit Poly vertex by object-space position. */
    function findDebugLiveVertexByPosition node modifier target_position tolerance:0.01 =
    (
        if node == undefined or not(isValidNode node) then return 0
        if modifier == undefined or target_position == undefined then return 0
        local vertex_count = modifier.GetNumVertices node:node
        for vertex_index = 1 to vertex_count do
        (
            if doesDebugModifierVertexExist node modifier vertex_index then
            (
                local vertex_position = modifier.GetVertex vertex_index node:node
                if vertex_position != undefined and distance vertex_position target_position <= tolerance then return vertex_index
            )
        )
        0
    ),

    /*
    Returns whether one current Edit Poly edge slot still has two readable live endpoints.
    Direct endpoint reads avoid recursive whole-topology checks.
    */
    function doesDebugModifierEdgeExist node modifier edge_index =
    (
        if node == undefined or not(isValidNode node) or modifier == undefined then return false
        local edge_count = modifier.GetNumEdges node:node
        if edge_index < 1 or edge_index > edge_count then return false

        local edge_a = undefined
        local edge_b = undefined
        local point_a = undefined
        local point_b = undefined
        try
        (
            edge_a = modifier.GetEdgeVertex edge_index 1 node:node
            edge_b = modifier.GetEdgeVertex edge_index 2 node:node
            if edge_a != undefined and edge_b != undefined and edge_a > 0 and edge_b > 0 then
            (
                point_a = modifier.GetVertex edge_a node:node
                point_b = modifier.GetVertex edge_b node:node
            )
        )
        catch
        (
            edge_a = undefined
            edge_b = undefined
        )

        edge_a != undefined and edge_b != undefined and edge_a > 0 and edge_b > 0 and point_a != undefined and point_b != undefined
        -- return
    ),

    /*
    Resolves a current edge by saved endpoint positions.
    Direct endpoint reads avoid nested live-topology scans.
    */
    function findDebugEdgeByEndpointPositions node modifier point_a point_b tolerance:0.01 =
    (
        if node == undefined or not(isValidNode node) or modifier == undefined then return 0
        local edge_count = modifier.GetNumEdges node:node
        for edge_index = 1 to edge_count do
        (
            local vertex_a = undefined
            local vertex_b = undefined
            local current_a = undefined
            local current_b = undefined
            try
            (
                vertex_a = modifier.GetEdgeVertex edge_index 1 node:node
                vertex_b = modifier.GetEdgeVertex edge_index 2 node:node
                if vertex_a != undefined and vertex_b != undefined and vertex_a > 0 and vertex_b > 0 then
                (
                    current_a = modifier.GetVertex vertex_a node:node
                    current_b = modifier.GetVertex vertex_b node:node
                )
            )
            catch
            (
                current_a = undefined
                current_b = undefined
            )

            if current_a != undefined and current_b != undefined then
            (
                local same_forward = distance current_a point_a <= tolerance and distance current_b point_b <= tolerance
                local same_reverse = distance current_a point_b <= tolerance and distance current_b point_a <= tolerance
                if same_forward or same_reverse then return edge_index
            )
        )
        0
        -- return
    ),

    /* Forces evaluation before reading Edit Poly counts after a topology commit. */
    function refreshDebugModifierTopology node =
    (
        if node == undefined or not(isValidNode node) then return false
        update node
        local evaluated_mesh = snapshotAsMesh node
        if evaluated_mesh != undefined then free evaluated_mesh
        true
    ),

    /* Returns true only when an explicit visible evaluated edge still joins the saved positions. */
    function doesDebugVisibleEdgeExistByEndpointPositions node point_a point_b tolerance:0.01 =
    (
        if node == undefined or not(isValidNode node) or point_a == undefined or point_b == undefined then return false
        local evaluated_mesh = snapshotAsMesh node
        if evaluated_mesh == undefined then return false
        local found = false
        local face_count = getNumFaces evaluated_mesh
        for face_index = 1 to face_count while not found do
        (
            local face_vertices = getFace evaluated_mesh face_index
            local face_vertex_ids = #(face_vertices.x as integer, face_vertices.y as integer, face_vertices.z as integer)
            for face_edge_index = 1 to 3 while not found do
            (
                if getEdgeVis evaluated_mesh face_index face_edge_index then
                (
                    local vertex_a = face_vertex_ids[face_edge_index]
                    local vertex_b = face_vertex_ids[if face_edge_index == 3 then 1 else face_edge_index + 1]
                    local current_a = getVert evaluated_mesh vertex_a
                    local current_b = getVert evaluated_mesh vertex_b
                    local same_forward = distance current_a point_a <= tolerance and distance current_b point_b <= tolerance
                    local same_reverse = distance current_a point_b <= tolerance and distance current_b point_a <= tolerance
                    if same_forward or same_reverse then found = true
                )
            )
        )
        free evaluated_mesh
        found
    ),

    /*
    Returns compact live topology state for diagnostics.
    Vertices and edges are read once without nested full-edge scans.
    */
    function getDebugCleanupTopologyState node modifier =
    (
        local live_vertices = #{}
        local live_edges = #{}
        if node != undefined and isValidNode node and modifier != undefined then
        (
            local vertex_count = modifier.GetNumVertices node:node
            for vertex_index = 1 to vertex_count do
            (
                local vertex_position = undefined
                try
                (
                    vertex_position = modifier.GetVertex vertex_index node:node
                )
                catch
                (
                    vertex_position = undefined
                )
                if vertex_position != undefined then live_vertices[vertex_index] = true
            )

            local edge_count = modifier.GetNumEdges node:node
            for edge_index = 1 to edge_count do
            (
                local edge_a = undefined
                local edge_b = undefined
                try
                (
                    edge_a = modifier.GetEdgeVertex edge_index 1 node:node
                    edge_b = modifier.GetEdgeVertex edge_index 2 node:node
                )
                catch
                (
                    edge_a = undefined
                    edge_b = undefined
                )
                if edge_a != undefined and edge_b != undefined and edge_a > 0 and edge_b > 0 then live_edges[edge_index] = true
            )
        )
        #(live_vertices, live_edges)
        -- return
    ),

    /*
    Removes one redundant edge with the proven Edit Poly UI sequence.
    Viewport refresh and evaluated-mesh snapshots are deferred until the batch ends.
    */
    function removeDebugCleanupEdge node modifier edge_index =
    (
        if not(doesDebugModifierEdgeExist node modifier edge_index) then return false
        local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
        local edge_b = modifier.GetEdgeVertex edge_index 2 node:node
        local point_a = modifier.GetVertex edge_a node:node
        local point_b = modifier.GetVertex edge_b node:node
        local requested_selection = #{}
        requested_selection[edge_index] = true
        local actual_selection = #{}
        local operation_error = undefined
        local old_remove_ctrl = modifier.remveEdgeCtrlKey
        try
        (
            modifier.remveEdgeCtrlKey = false
            modifier.SetEPolySelLevel #Edge
            modifier.SetSelection #Edge #{} node:node
            modifier.Select #Edge requested_selection node:node
            actual_selection = modifier.GetSelection #Edge node:node
            if actual_selection != requested_selection then throw "Edit Poly edge selection did not match the requested redundant edge."
            modifier.ButtonOp #RemoveEdge
            update node
        )
        catch
        (
            operation_error = getCurrentException()
        )
        modifier.remveEdgeCtrlKey = old_remove_ctrl

        local resolved_after = findDebugEdgeByEndpointPositions node modifier point_a point_b tolerance:0.01
        local topology_after = getDebugCleanupTopologyState node modifier
        local removed = operation_error == undefined and resolved_after == 0
        local failure_reason = if operation_error != undefined then operation_error as string else if resolved_after > 0 then "edge endpoints are still connected after ButtonOp #RemoveEdge" else ""
        if not batch_quiet then format "Wall-Fixer Cleanup Edge Attempt: originalEdge:% currentEdge:% method:% selectedEdges:% endpoints:%/% liveVertsAfter:% liveEdgesAfter:% success:% reason:%\n" \
            edge_index resolved_after #buttonRemoveEdge actual_selection point_a point_b topology_after[1] topology_after[2] removed failure_reason
        removed
        -- return
    ),

    /*
    Removes one confirmed current-slice vertex while preserving every vertex that existed before this slice.
    Lower slicing modifiers and earlier cuts in the same modifier are therefore protected.
    */
    function forceRemoveDebugCleanupVertex node modifier original_vertex_index saved_position protected_vertices:#{} =
    (
        local current_vertex_index = findDebugSliceVertexByPosition node modifier saved_position protected_vertices:protected_vertices tolerance:0.01
        if current_vertex_index <= 0 then return #(true, 0, #alreadyGone, "")
        local current_vertex_is_protected = current_vertex_index <= protected_vertices.count and protected_vertices[current_vertex_index]
        if current_vertex_is_protected or not(isDebugRemovableSliceVertex node modifier current_vertex_index) then
        (
            local protect_reason = if current_vertex_is_protected then "resolved vertex existed before the current slice" else "current vertex is not a straight two-edge cleanup vertex"
            local protected_position = modifier.GetVertex current_vertex_index node:node
            local protected_state = getDebugCleanupTopologyState node modifier
            if not batch_quiet then format "Wall-Fixer Cleanup Vert Attempt: originalVert:% currentVert:% method:% selectedVerts:% neighbor:% positionBefore:% positionAfter:% liveVertsAfter:% liveEdgesAfter:% success:false reason:%\n" \
                original_vertex_index current_vertex_index #protected #{} 0 protected_position protected_position protected_state[1] protected_state[2] protect_reason
            return #(false, current_vertex_index, #protected, protect_reason)
        )

        local methods = #(#buttonRemoveVertex, #operationRemoveVertex)
        for method in methods do
        (
            current_vertex_index = findDebugSliceVertexByPosition node modifier saved_position protected_vertices:protected_vertices tolerance:0.01
            if current_vertex_index <= 0 then return #(true, 0, method, "")
            local before_position = modifier.GetVertex current_vertex_index node:node
            local before_live_count = getDebugLiveVertexCount node modifier
            local requested_selection = #{}
            requested_selection[current_vertex_index] = true
            local actual_selection = #{}
            local operation_error = undefined
            try
            (
                modifier.SetEPolySelLevel #Vertex
                modifier.SetSelection #Vertex #{} node:node
                modifier.Select #Vertex requested_selection node:node
                actual_selection = modifier.GetSelection #Vertex node:node
                if actual_selection != requested_selection then throw "Edit Poly vertex selection did not match the requested cleanup vertex."
                if method == #buttonRemoveVertex then modifier.ButtonOp #RemoveVertex
                else
                (
                    modifier.SetOperation #RemoveVertex
                    modifier.Commit()
                )
                update node
            )
            catch
            (
                operation_error = getCurrentException()
            )
            local after_live_count = getDebugLiveVertexCount node modifier
            local resolved_after = findDebugSliceVertexByPosition node modifier saved_position protected_vertices:protected_vertices tolerance:0.01
            local after_position = if resolved_after > 0 then modifier.GetVertex resolved_after node:node else undefined
            local topology_after = getDebugCleanupTopologyState node modifier
            local removed = operation_error == undefined and resolved_after == 0 and after_live_count < before_live_count
            local failure_reason = ""
            if operation_error != undefined then failure_reason = operation_error as string
            else if resolved_after > 0 then failure_reason = "cleanup vertex still resolves at its saved position"
            else if after_live_count >= before_live_count then failure_reason = "live vertex count did not decrease"
            if not batch_quiet then format "Wall-Fixer Cleanup Vert Attempt: originalVert:% currentVert:% method:% selectedVerts:% neighbor:% positionBefore:% positionAfter:% liveVertsAfter:% liveEdgesAfter:% success:% reason:%\n" \
                original_vertex_index current_vertex_index method actual_selection 0 before_position after_position topology_after[1] topology_after[2] removed failure_reason
            if removed then return #(true, current_vertex_index, method, "")
            if not batch_quiet then format "Wall-Fixer Cleanup Vert Transition: originalVert:% failedMethod:% nextMethod:% reason:%\n" \
                original_vertex_index method (if method == #buttonRemoveVertex then #operationRemoveVertex else #guardedCollapse) failure_reason
        )

        current_vertex_index = findDebugSliceVertexByPosition node modifier saved_position protected_vertices:protected_vertices tolerance:0.01
        if current_vertex_index <= 0 then return #(true, 0, #alreadyGone, "")
        local neighbor_index = getDebugClosestNeighborVertex node modifier current_vertex_index
        local neighbor_is_protected = neighbor_index > 0 and neighbor_index <= protected_vertices.count and protected_vertices[neighbor_index]
        if neighbor_is_protected then
        (
            local guarded_position = modifier.GetVertex current_vertex_index node:node
            local guarded_state = getDebugCleanupTopologyState node modifier
            local guarded_reason = "collapse target existed before the current slice and is protected"
            if not batch_quiet then format "Wall-Fixer Cleanup Vert Attempt: originalVert:% currentVert:% method:% selectedVerts:% neighbor:% positionBefore:% positionAfter:% liveVertsAfter:% liveEdgesAfter:% success:false reason:%\n" \
                original_vertex_index current_vertex_index #guardedCollapse #{} neighbor_index guarded_position guarded_position guarded_state[1] guarded_state[2] guarded_reason
            return #(false, current_vertex_index, #guardedCollapse, guarded_reason)
        )

        local collapse_selection = #{current_vertex_index, neighbor_index}
        local collapse_before_position = modifier.GetVertex current_vertex_index node:node
        local collapse_before_count = getDebugLiveVertexCount node modifier
        local collapse_actual_selection = #{}
        local collapse_error = undefined
        try
        (
            modifier.SetEPolySelLevel #Vertex
            modifier.SetSelection #Vertex #{} node:node
            modifier.Select #Vertex collapse_selection node:node
            collapse_actual_selection = modifier.GetSelection #Vertex node:node
            if collapse_actual_selection != collapse_selection then throw "Edit Poly collapse selection did not match the requested slice-created pair."
            modifier.ButtonOp #CollapseVertex
            update node
        )
        catch
        (
            collapse_error = getCurrentException()
        )
        local collapse_after_count = getDebugLiveVertexCount node modifier
        local collapse_resolved_after = findDebugSliceVertexByPosition node modifier saved_position protected_vertices:protected_vertices tolerance:0.01
        local collapse_after_position = if collapse_resolved_after > 0 then modifier.GetVertex collapse_resolved_after node:node else undefined
        local collapse_state = getDebugCleanupTopologyState node modifier
        local collapse_removed = collapse_error == undefined and collapse_resolved_after == 0 and collapse_after_count < collapse_before_count
        local collapse_reason = if collapse_error != undefined then collapse_error as string else if collapse_resolved_after > 0 then "cleanup vertex still resolves after collapse" else if collapse_after_count >= collapse_before_count then "live vertex count did not decrease" else ""
        if not batch_quiet then format "Wall-Fixer Cleanup Vert Attempt: originalVert:% currentVert:% method:% selectedVerts:% neighbor:% positionBefore:% positionAfter:% liveVertsAfter:% liveEdgesAfter:% success:% reason:%\n" \
            original_vertex_index current_vertex_index #buttonCollapseVertex collapse_actual_selection neighbor_index collapse_before_position collapse_after_position collapse_state[1] collapse_state[2] collapse_removed collapse_reason
        #(collapse_removed, current_vertex_index, #buttonCollapseVertex, collapse_reason)
    ),
    /*
    Moves one surviving slice vertex onto its closest connected neighbour and collapses the pair.
    The neighbour is chosen only from current incident Edit Poly edges.
    */
    function collapseDebugVertexToClosestNeighbor node modifier vertex_index =
    (
        if not(doesDebugModifierVertexExist node modifier vertex_index) then return #(false, 0, 0, 0)

        local closest_neighbor_index = getDebugClosestNeighborVertex node modifier vertex_index
        if closest_neighbor_index <= 0 then return #(false, 0, 0, 0)
        if not(doesDebugModifierVertexExist node modifier closest_neighbor_index) then return #(false, 0, 0, 0)

        local vertex_position = modifier.GetVertex vertex_index node:node
        local neighbor_position = modifier.GetVertex closest_neighbor_index node:node
        if vertex_position == undefined or neighbor_position == undefined then return #(false, closest_neighbor_index, 0, 0)

        local move_amount = neighbor_position - vertex_position
        local single_selection = #{}
        single_selection[vertex_index] = true
        local pair_selection = #{}
        pair_selection[vertex_index] = true
        pair_selection[closest_neighbor_index] = true
        local before_vertex_count = modifier.GetNumVertices node:node
        local before_live_vertex_count = getDebugLiveVertexCount node modifier
        local after_vertex_count = before_vertex_count
        local after_live_vertex_count = before_live_vertex_count
        local collapse_ok = true
        local move_ok = false
        local collapse_success = false
        local moved_position = undefined
        local move_distance = undefined
        local collapse_method = #none

        try
        (
            -- Mirror the UI/macro-recorder sequence exactly: Vertex mode -> Transform -> Move -> Commit.
            modifier.SetEPolySelLevel #Vertex
            modifier.SetSelection #Vertex #{} node:node
            modifier.SetSelection #Vertex single_selection node:node

            if (modifier.GetSelection #Vertex node:node) != single_selection then
            (
                throw "Could not set surviving slice vertex selection for move."
            )

            modifier.SetOperation #Transform
            modifier.MoveSelection move_amount parent:(modifier.GetNodeTM node:node) axis:(modifier.GetNodeTM node:node)
            modifier.Commit()
            update node
            modifier.RefreshScreen()

            moved_position = modifier.GetVertex vertex_index node:node
            if moved_position != undefined then
            (
                move_distance = distance moved_position neighbor_position
                move_ok = move_distance <= 0.01
            )

            -- Apply one measured correction if the committed transform did not land exactly.
            if not move_ok and moved_position != undefined then
            (
                local correction_amount = neighbor_position - moved_position
                modifier.SetSelection #Vertex #{} node:node
                modifier.SetSelection #Vertex single_selection node:node
                modifier.SetOperation #Transform
                modifier.MoveSelection correction_amount parent:(modifier.GetNodeTM node:node) axis:(modifier.GetNodeTM node:node)
                modifier.Commit()
                update node
                modifier.RefreshScreen()

                moved_position = modifier.GetVertex vertex_index node:node
                if moved_position != undefined then
                (
                    move_distance = distance moved_position neighbor_position
                    move_ok = move_distance <= 0.01
                )
            )

            if not move_ok then
            (
                throw ("Could not move cleanup vertex onto neighbour. Distance:" + (move_distance as string))
            )

            -- First choice: press the same Collapse button as the Edit Poly UI.
            modifier.SetSelection #Vertex #{} node:node
            modifier.SetSelection #Vertex pair_selection node:node
            if (modifier.GetSelection #Vertex node:node) != pair_selection then
            (
                throw "Could not set collapse vertex pair selection."
            )

            modifier.ButtonOp #CollapseVertex
            modifier.Commit()
            update node
            modifier.RefreshScreen()
            after_vertex_count = modifier.GetNumVertices node:node
            after_live_vertex_count = getDebugLiveVertexCount node modifier
            collapse_success = after_live_vertex_count < before_live_vertex_count or not(doesDebugModifierVertexExist node modifier vertex_index) or not(doesDebugModifierVertexExist node modifier closest_neighbor_index)
            if collapse_success then collapse_method = #buttonCollapse

            -- Second choice: explicit Collapse operation/commit.
            if not collapse_success then
            (
                modifier.SetSelection #Vertex #{} node:node
                modifier.SetSelection #Vertex pair_selection node:node
                modifier.SetOperation #CollapseVertex
                modifier.Commit()
                update node
                modifier.RefreshScreen()
                after_vertex_count = modifier.GetNumVertices node:node
                after_live_vertex_count = getDebugLiveVertexCount node modifier
                collapse_success = after_live_vertex_count < before_live_vertex_count or not(doesDebugModifierVertexExist node modifier vertex_index) or not(doesDebugModifierVertexExist node modifier closest_neighbor_index)
                if collapse_success then collapse_method = #operationCollapse
            )

            -- Third choice: the pair is already coincident, so UI Weld must be safe.
            if not collapse_success then
            (
                modifier.SetSelection #Vertex #{} node:node
                modifier.SetSelection #Vertex pair_selection node:node
                modifier.ButtonOp #WeldVertex
                modifier.Commit()
                update node
                modifier.RefreshScreen()
                after_vertex_count = modifier.GetNumVertices node:node
                after_live_vertex_count = getDebugLiveVertexCount node modifier
                collapse_success = after_live_vertex_count < before_live_vertex_count or not(doesDebugModifierVertexExist node modifier vertex_index) or not(doesDebugModifierVertexExist node modifier closest_neighbor_index)
                if collapse_success then collapse_method = #buttonWeld
            )

            -- Last resort: remove the confirmed slice-created non-corner source vertex at the neighbour position.
            if not collapse_success and doesDebugModifierVertexExist node modifier vertex_index then
            (
                single_selection = #{}
                single_selection[vertex_index] = true
                modifier.SetSelection #Vertex #{} node:node
                modifier.SetSelection #Vertex single_selection node:node
                modifier.ButtonOp #RemoveVertex
                modifier.Commit()
                update node
                modifier.RefreshScreen()
                after_vertex_count = modifier.GetNumVertices node:node
                after_live_vertex_count = getDebugLiveVertexCount node modifier
                collapse_success = after_live_vertex_count < before_live_vertex_count or not(doesDebugModifierVertexExist node modifier vertex_index)
                if collapse_success then collapse_method = #removeVertex
            )
        )
        catch
        (
            collapse_ok = false
        )

        if not batch_quiet then format "Wall-Fixer Collapse Cleanup Vert: source:% neighbor:% moved:% moveDistance:% beforeSlots:% afterSlots:% beforeLive:% afterLive:% method:% success:%\n" vertex_index closest_neighbor_index moved_position move_distance before_vertex_count after_vertex_count before_live_vertex_count after_live_vertex_count collapse_method (collapse_ok and move_ok and collapse_success)

        #(collapse_ok and move_ok and collapse_success, closest_neighbor_index, before_vertex_count, after_vertex_count)
        -- return
    ),

    /*
    Returns candidate vertices that still survive after Remove Vertex.
    Only live Edit Poly vertices with current connected topology are returned.
    */
    function getDebugExistingVertexCandidates node modifier vertex_candidates =
    (
        local existing_vertices = #{}
        if vertex_candidates == undefined then return existing_vertices

        for vertex_index in vertex_candidates do
        (
            if doesDebugModifierVertexExist node modifier vertex_index then
            (
                existing_vertices[vertex_index] = true
            )
        )

        existing_vertices
        -- return
    ),

    /*
    Removes redundant new slice edges and their slice-created non-corner vertices.
    Redundant visible edges are removed and verified before confirmed slice-created vertices are removed.
    */
    function debugCleanUpSlicedEdges final_redraw:true keep_modify_context:false =
    (
        last_slice_error = undefined
        last_slice_report = ""

        local selected_nodes = selection as array
        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select the wall from the last Make 1 Slice."
            return false
        )

        local node = selected_nodes[1]
        local modifier = getDebugTopologyModifier node
        if modifier == undefined then
        (
            last_slice_report = node.name + ": top Wall topology cleanup Edit Poly was not found."
            return false
        )

        local base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then
        (
            last_slice_report = node.name + ": base object must be Editable Poly."
            return false
        )

        local cleanup_data = getDebugSlicedEdgeCleanupCandidates node modifier
        if cleanup_data == undefined then
        (
            last_slice_report = node.name + ": no valid last-slice anchor/direction chain was found. Run Make 1 Slice first."
            if not batch_quiet then format "%\n" last_slice_report
            return false
        )

        local removable_edges = cleanup_data[1]
        local kept_edges = cleanup_data[2]
        local usable_new_edges = cleanup_data[3]
        local start_vertices = cleanup_data[5]
        local protected_pre_slice_vertices = copy last_debug_slice_original_vertices
        local vertex_cleanup_data = getDebugPredictedSlicedEdgeRemovalVertices \
            node \
            modifier \
            removable_edges \
            protected_pre_slice_vertices:protected_pre_slice_vertices
        local removable_new_vertices = vertex_cleanup_data[1]
        local protected_base_vertices = vertex_cleanup_data[2]
        local protected_corner_vertices = vertex_cleanup_data[3]
        local candidate_positions = #()
        local edge_descriptors = #()
        local removed_new_vertices = #{}
        local unresolved_new_vertices = #{}
        local removal_methods = #()
        local removed_edge_count = 0
        local failure = undefined
        local redraw_disabled = false
        local old_remove_ctrl = modifier.remveEdgeCtrlKey

        -- Save candidate positions before any topology-changing operation can invalidate their IDs.
        for vertex_index in removable_new_vertices do
        (
            local candidate_position = modifier.GetVertex vertex_index node:node
            if candidate_position != undefined then
            (
                append candidate_positions #(vertex_index, candidate_position)
            )
        )

        -- Save redundant-edge geometry so every edge can be re-resolved and verified before vertex cleanup.
        for edge_index in removable_edges do
        (
            if doesDebugModifierEdgeExist node modifier edge_index then
            (
                local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
                local edge_b = modifier.GetEdgeVertex edge_index 2 node:node
                append edge_descriptors #(edge_index, modifier.GetVertex edge_a node:node, modifier.GetVertex edge_b node:node)
            )
        )

        try
        (
            disableSceneRedraw()
            redraw_disabled = true
            select node
                max modify mode
                modPanel.setCurrentObject modifier
                modifier.SetPrimaryNode node
                modifier.useStackSelection = false
                modifier.remveEdgeCtrlKey = false
            -- Redundant edges are always removed and verified before any cleanup vertex is touched.
            local unresolved_edges = #{}
            for edge_data in edge_descriptors do
            (
                local original_edge_index = edge_data[1]
                local current_edge_index = findDebugEdgeByEndpointPositions node modifier edge_data[2] edge_data[3] tolerance:0.01
                if current_edge_index > 0 then
                (
                    if removeDebugCleanupEdge node modifier current_edge_index then
                    (
                        removed_edge_count += 1
                    )
                    else
                    (
                        unresolved_edges[original_edge_index] = true
                    )
                )
                else
                (
                    removed_edge_count += 1
                    if not batch_quiet then format "Wall-Fixer Cleanup Edge Attempt: originalEdge:% currentEdge:0 method:alreadyGone selectedEdges:#{} endpoints:%/% success:true reason:\n" original_edge_index edge_data[2] edge_data[3]
                )
            )

            if unresolved_edges.numberSet > 0 then
            (
                throw ("Redundant sliced edges remain after cleanup: " + (unresolved_edges as string))
            )

            -- Re-resolve every saved candidate only after all redundant edges are confirmed gone.
            for candidate_data in candidate_positions do
            (
                local original_vertex_index = candidate_data[1]
                local candidate_position = candidate_data[2]
                local current_vertex_index = findDebugSliceVertexByPosition node modifier candidate_position protected_vertices:protected_pre_slice_vertices tolerance:0.01

                if current_vertex_index > 0 then
                (
                    local removal_result = forceRemoveDebugCleanupVertex node modifier original_vertex_index candidate_position protected_vertices:protected_pre_slice_vertices
                    append removal_methods #(original_vertex_index, current_vertex_index, removal_result[3], removal_result[4])
                    if removal_result[1] then
                    (
                        removed_new_vertices[original_vertex_index] = true
                    )
                    else
                    (
                        unresolved_new_vertices[original_vertex_index] = true
                    )
                )
                else
                (
                    removed_new_vertices[original_vertex_index] = true
                    append removal_methods #(original_vertex_index, 0, #alreadyGone, "removed by an earlier verified operation")
                )
            )
            modifier.remveEdgeCtrlKey = old_remove_ctrl

            last_slice_report = node.name + ": redundant sliced edges removed:" + (removed_edge_count as string) + "; cleanup candidates:" + (removable_new_vertices.numberSet as string) + "; removed verts:" + (removed_new_vertices.numberSet as string) + "; unresolved verts:" + (unresolved_new_vertices as string) + "."
            if not batch_quiet then format "Wall-Fixer Clean Up Sliced Edges Summary: new:% startVerts:% keep:% requestedEdges:% removedEdges:% cleanupCandidates:% removedVerts:% methods:% unresolvedVerts:% protectedPreSliceVerts:% protectedCornerVerts:% preSliceVertCount:%\n" usable_new_edges start_vertices kept_edges removable_edges removed_edge_count removable_new_vertices removed_new_vertices removal_methods unresolved_new_vertices protected_base_vertices protected_corner_vertices protected_pre_slice_vertices.numberSet

            if removed_edge_count > 0 then clearLastDebugSliceContext node:node

            if redraw_disabled then
            (
                enableSceneRedraw()
                redraw_disabled = false
            )
            if not keep_modify_context then max create mode
            if final_redraw then completeRedraw()
        )
        catch
        (
            failure = getCurrentException()
            modifier.remveEdgeCtrlKey = old_remove_ctrl
            if redraw_disabled then
            (
                enableSceneRedraw()
                redraw_disabled = false
            )
            if not keep_modify_context then max create mode
            if final_redraw then completeRedraw()
            last_slice_error = failure
            last_slice_report = node.name + ": " + (failure as string)
        )

        failure == undefined
        -- return
    ),

    /*
    Converts the currently selected sliced edges into non-border sliced vertices.
    The current Edit Poly selection is the only debug state.
    */
    function debugSelectSlicedEdgeVertices =
    (
        last_slice_error = undefined
        last_slice_report = ""

        local selected_nodes = selection as array
        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select the wall containing the sliced-edge selection."
            return false
        )

        local node = selected_nodes[1]
        local modifier = getDebugTopologyModifier node
        if modifier == undefined then
        (
            last_slice_report = node.name + ": top Wall topology cleanup Edit Poly was not found."
            return false
        )

        local sliced_edges = modifier.GetSelection #Edge node:node
        if sliced_edges == undefined or sliced_edges.numberSet == 0 then
        (
            last_slice_report = node.name + ": no sliced edges are selected. Run Make 1 Slice first."
            return false
        )

        local sliced_vertices = getDebugSlicedVertices node modifier sliced_edges

        select node
        max modify mode
        modPanel.setCurrentObject modifier
        modifier.SetPrimaryNode node
        modifier.useStackSelection = false
        modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1
        modifier.SetSelection #Vertex #{} node:node
        local selected_ok = modifier.Select #Vertex sliced_vertices node:node
        local actual_selection = modifier.GetSelection #Vertex node:node
        completeRedraw()

        last_slice_report = node.name + ": sliced verts selected:" + (actual_selection.numberSet as string) + "."
        if not batch_quiet then format "Wall-Fixer Sliced Edge Verts: edges:% requested:% selected:% result:%\n" sliced_edges sliced_vertices actual_selection selected_ok

        actual_selection == sliced_vertices
        -- return
    ),
    /*
    Returns sliced vertices from the supplied currently selected sliced edges.
    Vertices on any current wall/opening border are excluded by definition.
    */
    function getDebugSlicedVertices node modifier sliced_edges =
    (
        local sliced_vertices = #{}
        local border_vertices = #{}
        local edge_count = modifier.GetNumEdges node:node

        for edge_index = 1 to edge_count do
        (
            local face_a = modifier.GetEdgeFace edge_index 1 node:node
            local face_b = modifier.GetEdgeFace edge_index 2 node:node
            if (face_a == 0) != (face_b == 0) then
            (
                local border_a = modifier.GetEdgeVertex edge_index 1 node:node
                local border_b = modifier.GetEdgeVertex edge_index 2 node:node
                if border_a > 0 then border_vertices[border_a] = true
                if border_b > 0 then border_vertices[border_b] = true
            )
        )

        for edge_index in sliced_edges do
        (
            if edge_index >= 1 and edge_index <= edge_count then
            (
                local sliced_a = modifier.GetEdgeVertex edge_index 1 node:node
                local sliced_b = modifier.GetEdgeVertex edge_index 2 node:node
                if sliced_a > 0 then sliced_vertices[sliced_a] = true
                if sliced_b > 0 then sliced_vertices[sliced_b] = true
            )
        )

        sliced_vertices - border_vertices
        -- return
    ),

    /*
    Counts unique visible TriMesh edges incident to one evaluated vertex.
    Invisible triangulation edges are ignored; shared triangle edges count only once.
    */
    function countVisibleEdgesAtVertex mesh_value vertex_index =
    (
        local visible_edge_keys = #()
        local face_count = getNumFaces mesh_value

        for face_index = 1 to face_count do
        (
            local face_vertices = getFace mesh_value face_index
            local face_vertex_ids = #(face_vertices.x as integer, face_vertices.y as integer, face_vertices.z as integer)

            for face_edge_index = 1 to 3 do
            (
                local edge_a = face_vertex_ids[face_edge_index]
                local edge_b = face_vertex_ids[if face_edge_index == 3 then 1 else face_edge_index + 1]

                if (edge_a == vertex_index or edge_b == vertex_index) and (getEdgeVis mesh_value face_index face_edge_index) then
                (
                    local min_vertex = amin edge_a edge_b
                    local max_vertex = amax edge_a edge_b
                    local edge_key = (min_vertex as string) + ":" + (max_vertex as string)
                    if (findItem visible_edge_keys edge_key) == 0 then append visible_edge_keys edge_key
                )
            )
        )

        visible_edge_keys.count
        -- return
    ),

    /*
    Returns unique evaluated visible-edge neighbours of one vertex.
    Hidden triangulation/topology edges are ignored.
    */
    function getVisibleEdgeNeighborVerticesAtVertex mesh_value vertex_index =
    (
        local neighbor_vertices = #()
        if mesh_value == undefined then return neighbor_vertices

        local face_count = getNumFaces mesh_value
        for face_index = 1 to face_count do
        (
            local face_vertices = getFace mesh_value face_index
            local face_vertex_ids = #(face_vertices.x as integer, face_vertices.y as integer, face_vertices.z as integer)

            for face_edge_index = 1 to 3 do
            (
                if getEdgeVis mesh_value face_index face_edge_index then
                (
                    local edge_a = face_vertex_ids[face_edge_index]
                    local edge_b = face_vertex_ids[if face_edge_index == 3 then 1 else face_edge_index + 1]

                    if edge_a == vertex_index and (findItem neighbor_vertices edge_b) == 0 then
                    (
                        append neighbor_vertices edge_b
                    )
                    else if edge_b == vertex_index and (findItem neighbor_vertices edge_a) == 0 then
                    (
                        append neighbor_vertices edge_a
                    )
                )
            )
        )

        neighbor_vertices
        -- return
    ),

    /*
    Returns true only for a vertex with exactly two visible straight edges.
    Extra hidden incident edges are allowed and are cleaned before Remove Vertex.
    */
    function isPostProcessStraightTwoVisibleEdgeVertex mesh_value vertex_index angle_threshold:0.1 =
    (
        if mesh_value == undefined then return false
        if vertex_index < 1 or vertex_index > (getNumVerts mesh_value) then return false

        local neighbor_vertices = ::WallFixer.getVisibleEdgeNeighborVerticesAtVertex mesh_value vertex_index
        if neighbor_vertices.count != 2 then return false

        local vertex_position = getVert mesh_value vertex_index
        local neighbor_a = getVert mesh_value neighbor_vertices[1]
        local neighbor_b = getVert mesh_value neighbor_vertices[2]
        local direction_a = neighbor_a - vertex_position
        local direction_b = neighbor_b - vertex_position

        if length direction_a <= epsilon or length direction_b <= epsilon then return false

        local straight_limit = -(cos angle_threshold)
        (dot (normalize direction_a) (normalize direction_b)) <= straight_limit
        -- return
    ),

    /*
    Returns whether one evaluated edge between the requested live vertex ids is visible.
    The same endpoint pair can appear in two TriMesh faces; any visible occurrence makes it visible.
    */
    function isEvaluatedMeshEdgeVisibleByVertexPair mesh_value vertex_a vertex_b =
    (
        if mesh_value == undefined then return false
        local found_visible = false
        local face_count = getNumFaces mesh_value

        for face_index = 1 to face_count while not found_visible do
        (
            local face_vertices = getFace mesh_value face_index
            local face_vertex_ids = #(face_vertices.x as integer, face_vertices.y as integer, face_vertices.z as integer)

            for face_edge_index = 1 to 3 while not found_visible do
            (
                local edge_a = face_vertex_ids[face_edge_index]
                local edge_b = face_vertex_ids[if face_edge_index == 3 then 1 else face_edge_index + 1]
                local same_edge = (edge_a == vertex_a and edge_b == vertex_b) or (edge_a == vertex_b and edge_b == vertex_a)

                if same_edge and getEdgeVis mesh_value face_index face_edge_index then
                (
                    found_visible = true
                )
            )
        )

        found_visible
        -- return
    ),

    /*
    Returns true when one live vertex is a visible-edge corner instead of a straight continuation.
    Any vertex without exactly two visible neighbours is treated as a corner/non-cleanup vertex.
    */
    function isDebugVisibleCornerVertex mesh_value vertex_index angle_threshold:0.1 =
    (
        if mesh_value == undefined then return true
        if vertex_index < 1 or vertex_index > (getNumVerts mesh_value) then return true

        local neighbor_vertices = ::WallFixer.getVisibleEdgeNeighborVerticesAtVertex mesh_value vertex_index
        if neighbor_vertices.count != 2 then return true

        local vertex_position = getVert mesh_value vertex_index
        local direction_a = (getVert mesh_value neighbor_vertices[1]) - vertex_position
        local direction_b = (getVert mesh_value neighbor_vertices[2]) - vertex_position
        if length direction_a <= epsilon or length direction_b <= epsilon then return true

        local straight_limit = -(cos angle_threshold)
        (dot (normalize direction_a) (normalize direction_b)) > straight_limit
        -- return
    ),

    /*
    Selects all live vertices with exactly two visible collinear edges and excludes visible-edge corners.
    Debug-only inspection; no topology is changed.
    */
    function debugFindTwoEdgeVerts angle_threshold:0.1 =
    (
        last_slice_error = undefined
        last_slice_report = ""

        local selected_nodes = selection as array
        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select one processed wall before Find Two-Edge Verts."
            return false
        )

        local node = selected_nodes[1]
        local modifier = getDebugTopologyModifier node
        local modifier_created = false

        if modifier == undefined then
        (
            modifier = Edit_Poly name:"WMC - FIX TWO-EDGE VERTS"
            addModifier node modifier
            update node
            modifier_created = true
        )

        local failure = undefined
        local evaluated_mesh = undefined
        local candidates = #{}
        local corner_vertices = #{}
        local non_two_visible_vertices = #{}

        try
        (
            update node
            evaluated_mesh = snapshotAsMesh node
            if evaluated_mesh == undefined then throw "Could not evaluate current wall mesh."
            if getNumVerts evaluated_mesh != modifier.GetNumVertices node:node then
            (
                throw "Evaluated mesh vertex indices do not match Edit Poly vertex indices."
            )

            local vertex_count = getNumVerts evaluated_mesh
            for vertex_index = 1 to vertex_count do
            (
                local visible_edge_count = ::WallFixer.countVisibleEdgesAtVertex evaluated_mesh vertex_index
                local is_corner_vertex = ::WallFixer.isDebugVisibleCornerVertex evaluated_mesh vertex_index angle_threshold:angle_threshold
                local is_straight_two_edge = false

                if visible_edge_count == 2 and not is_corner_vertex then
                (
                    is_straight_two_edge = ::WallFixer.isPostProcessStraightTwoVisibleEdgeVertex evaluated_mesh vertex_index angle_threshold:angle_threshold
                )

                if is_straight_two_edge then
                (
                    candidates[vertex_index] = true
                )
                else if is_corner_vertex then
                (
                    corner_vertices[vertex_index] = true
                )
                else if visible_edge_count != 2 then
                (
                    non_two_visible_vertices[vertex_index] = true
                )
            )

            free evaluated_mesh
            evaluated_mesh = undefined

            select node
            max modify mode
            modPanel.setCurrentObject modifier
            modifier.SetPrimaryNode node
            modifier.useStackSelection = false
            modifier.SetEPolySelLevel #Vertex
            subObjectLevel = 1
            modifier.SetSelection #Vertex #{} node:node

            if candidates.numberSet > 0 then
            (
                local selected_ok = modifier.Select #Vertex candidates node:node
                local actual_selection = modifier.GetSelection #Vertex node:node
                if not selected_ok or actual_selection != candidates then
                (
                    throw "Could not select Find Two-Edge Verts candidates."
                )
            )

            if not batch_quiet then format "Wall-Fixer Find Two-Edge Verts: node:% candidates:% count:% angleTolerance:% modifier:% created:%\n" \
                node.name candidates candidates.numberSet angle_threshold modifier.name modifier_created
            last_slice_report = node.name + ": Find Two-Edge Verts selected " + (candidates.numberSet as string) + " vertices in " + modifier.name + "."
            completeRedraw()
        )
        catch
        (
            if evaluated_mesh != undefined then free evaluated_mesh
            failure = getCurrentException()
            last_slice_error = failure
            last_slice_report = node.name + ": " + (failure as string)
        )

        failure == undefined
        -- return
    ),

    /*
    Welds each current Find Two-Edge Verts candidate to the closest neighbour on one of its two visible straight edges.
    Candidates are re-resolved by position after every weld so Edit Poly vertex renumbering cannot redirect later operations.
    */
    function debugWeldTwoEdgeVertsToClosestNeighbor angle_threshold:0.1 position_tolerance:0.01 =
    (
        last_slice_error = undefined
        last_slice_report = ""

        local selected_nodes = selection as array
        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select one processed wall before welding Find Two-Edge Verts candidates."
            return false
        )

        local node = selected_nodes[1]
        local source_modifier = getDebugTopologyModifier node
        if source_modifier == undefined then
        (
            last_slice_report = node.name + ": top Edit Poly modifier was not found."
            return false
        )

        local failure = undefined
        local evaluated_mesh = undefined
        local weld_modifier = undefined
        local candidate_positions = #()
        local welded_count = 0
        local skipped_count = 0
        local failed_positions = #()
        local redraw_disabled = false

        try
        (
            update node
            evaluated_mesh = snapshotAsMesh node
            if evaluated_mesh == undefined then throw "Could not evaluate current wall mesh."
            if getNumVerts evaluated_mesh != source_modifier.GetNumVertices node:node then
            (
                throw "Evaluated mesh vertex indices do not match Edit Poly vertex indices."
            )

            local vertex_count = getNumVerts evaluated_mesh
            for vertex_index = 1 to vertex_count do
            (
                local visible_edge_count = ::WallFixer.countVisibleEdgesAtVertex evaluated_mesh vertex_index
                local is_corner_vertex = ::WallFixer.isDebugVisibleCornerVertex evaluated_mesh vertex_index angle_threshold:angle_threshold
                if visible_edge_count == 2 and not is_corner_vertex then
                (
                    if ::WallFixer.isPostProcessStraightTwoVisibleEdgeVertex evaluated_mesh vertex_index angle_threshold:angle_threshold then
                    (
                        local candidate_position = source_modifier.GetVertex vertex_index node:node
                        if candidate_position != undefined then append candidate_positions candidate_position
                    )
                )
            )

            free evaluated_mesh
            evaluated_mesh = undefined

            if candidate_positions.count == 0 then
            (
                last_slice_report = node.name + ": no Find Two-Edge Verts candidates to weld."
                if not batch_quiet then format "Wall-Fixer Weld Two-Edge Verts: node:% candidates:0 welded:0 skipped:0 failed:0\n" node.name
                return true
            )

            weld_modifier = Edit_Poly name:"WMC - FIX TWO-EDGE VERTS"
            addModifier node weld_modifier
            update node

            select node
            max modify mode
            modPanel.setCurrentObject weld_modifier
            weld_modifier.SetPrimaryNode node
            weld_modifier.useStackSelection = false
            weld_modifier.SetEPolySelLevel #Vertex

            disableSceneRedraw()
            redraw_disabled = true

            local object_tm = node.objectTransform

            for saved_position in candidate_positions do
            (
                local current_vertex = ::WallFixer.findDebugLiveVertexByPosition node weld_modifier saved_position tolerance:position_tolerance
                if current_vertex <= 0 then
                (
                    skipped_count += 1
                    if not batch_quiet then format "Wall-Fixer Weld Two-Edge Vert Skip: savedPosition:% reason:vertex already removed or could not be re-resolved\n" saved_position
                )
                else
                (
                    local current_mesh = snapshotAsMesh node
                    local can_weld = current_mesh != undefined
                    local visible_neighbors = #()

                    if can_weld then
                    (
                        if getNumVerts current_mesh != weld_modifier.GetNumVertices node:node then
                        (
                            can_weld = false
                        )
                        else
                        (
                            can_weld = ::WallFixer.isPostProcessStraightTwoVisibleEdgeVertex current_mesh current_vertex angle_threshold:angle_threshold
                            if can_weld then visible_neighbors = ::WallFixer.getVisibleEdgeNeighborVerticesAtVertex current_mesh current_vertex
                            if visible_neighbors.count != 2 then can_weld = false
                        )
                    )

                    if current_mesh != undefined then free current_mesh

                    if not can_weld then
                    (
                        skipped_count += 1
                        if not batch_quiet then format "Wall-Fixer Weld Two-Edge Vert Skip: source:% reason:no longer a valid two-visible-straight-edge vertex\n" current_vertex
                    )
                    else
                    (
                        local source_position = weld_modifier.GetVertex current_vertex node:node
                        local neighbor_a = visible_neighbors[1]
                        local neighbor_b = visible_neighbors[2]
                        local position_a = weld_modifier.GetVertex neighbor_a node:node
                        local position_b = weld_modifier.GetVertex neighbor_b node:node

                        if source_position == undefined or position_a == undefined or position_b == undefined then
                        (
                            append failed_positions saved_position
                        )
                        else
                        (
                            local source_world = source_position * object_tm
                            local distance_a = distance source_world (position_a * object_tm)
                            local distance_b = distance source_world (position_b * object_tm)
                            local target_vertex = if distance_a <= distance_b then neighbor_a else neighbor_b
                            local target_position = if target_vertex == neighbor_a then position_a else position_b
                            local target_distance = if distance_a <= distance_b then distance_a else distance_b
                            local single_selection = #{}
                            local pair_selection = #{}
                            single_selection[current_vertex] = true
                            pair_selection[current_vertex] = true
                            pair_selection[target_vertex] = true
                            local before_live_count = ::WallFixer.getDebugLiveVertexCount node weld_modifier
                            local weld_success = false

                            weld_modifier.SetSelection #Vertex #{} node:node
                            local source_selected = weld_modifier.Select #Vertex single_selection node:node
                            if source_selected and (weld_modifier.GetSelection #Vertex node:node) == single_selection then
                            (
                                weld_modifier.SetOperation #Transform
                                weld_modifier.MoveSelection (target_position - source_position) parent:(weld_modifier.GetNodeTM node:node) axis:(weld_modifier.GetNodeTM node:node)
                                weld_modifier.Commit()
                                update node

                                /* Moving vertices does not renumber topology, so keep this exact connected pair for the weld. */
                                pair_selection = #{}
                                pair_selection[current_vertex] = true
                                pair_selection[target_vertex] = true
                                weld_modifier.SetSelection #Vertex #{} node:node
                                local pair_selected = weld_modifier.Select #Vertex pair_selection node:node

                                if pair_selected and (weld_modifier.GetSelection #Vertex node:node) == pair_selection then
                                (
                                    weld_modifier.ButtonOp #WeldVertex
                                    weld_modifier.Commit()
                                    update node

                                    local after_live_count = ::WallFixer.getDebugLiveVertexCount node weld_modifier
                                    weld_success = after_live_count < before_live_count

                                    if not batch_quiet then format "Wall-Fixer Weld Two-Edge Vert: source:% target:% distance:% liveBefore:% liveAfter:% success:% modifier:%\n" \
                                        current_vertex target_vertex target_distance before_live_count after_live_count weld_success weld_modifier.name
                                )
                            )

                            if weld_success then
                            (
                                welded_count += 1
                            )
                            else
                            (
                                append failed_positions saved_position
                            )
                        )
                    )
                )
            )

            weld_modifier.SetSelection #Vertex #{} node:node

            if not batch_quiet then format "Wall-Fixer Weld Two-Edge Verts: node:% candidates:% welded:% skipped:% failed:% modifier:%\n" \
                node.name candidate_positions.count welded_count skipped_count failed_positions.count weld_modifier.name

            if failed_positions.count == 0 then
            (
                last_slice_report = node.name + ": welded " + (welded_count as string) + " Find Two-Edge Verts candidates in FIX TWO-EDGE VERTS."
            )
            else
            (
                last_slice_report = node.name + ": welded " + (welded_count as string) + " candidates; " + (failed_positions.count as string) + " failed after processing the full candidate list."
            )
        )
        catch
        (
            if evaluated_mesh != undefined then free evaluated_mesh
            failure = getCurrentException()
            last_slice_error = failure
            last_slice_report = node.name + ": " + (failure as string)

            if weld_modifier != undefined and welded_count == 0 then
            (
                try(deleteModifier node weld_modifier)catch()
                weld_modifier = undefined
                update node
            )
        )

        if redraw_disabled then enableSceneRedraw()
        completeRedraw()

        failure == undefined and failed_positions.count == 0
        -- return
    ),

    /*
    Selects only Clean Up Slice eligible verts without changing topology.
    Eligible verts have exactly two visible edges, are not border verts, and are not cached INNER VERTS.
    */
    function debugInspectCleanUpSlice =
    (
        last_slice_error = undefined
        last_slice_report = ""

        local selected_nodes = selection as array
        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select the wall and sliced vertices before inspecting Clean Up Slice."
            return false
        )

        local node = selected_nodes[1]
        local modifier = getDebugTopologyModifier node
        if modifier == undefined then
        (
            last_slice_report = node.name + ": top Wall topology cleanup Edit Poly was not found."
            return false
        )

        local failure = undefined
        local sliced_vertices = modifier.GetSelection #Vertex node:node
        local protected_inner_vertices = getResetInnerVertSelection node
        local selectable_vertices = #{}
        local protected_selected_vertices = #{}
        local non_two_visible_vertices = #{}
        local border_vertices = #{}
        local border_selected_vertices = #{}
        local evaluated_mesh = undefined

        if sliced_vertices == undefined or sliced_vertices.numberSet == 0 then
        (
            last_slice_report = node.name + ": no sliced verts are selected. RMB Make 1 Slice first."
            return false
        )
        if protected_inner_vertices == undefined then
        (
            last_slice_report = node.name + ": Reset Slicing INNER VERTS cache is missing. Run Reset Slicing before Clean Up Slice."
            return false
        )

        selectable_vertices = copy sliced_vertices
        for sliced_vertex in sliced_vertices do
        (
            if sliced_vertex <= protected_inner_vertices.count and protected_inner_vertices[sliced_vertex] then
            (
                selectable_vertices[sliced_vertex] = false
                protected_selected_vertices[sliced_vertex] = true
            )
        )

        try
        (
            select node
            max modify mode
            modPanel.setCurrentObject modifier
            modifier.SetPrimaryNode node
            modifier.useStackSelection = false

            update node
            evaluated_mesh = snapshotAsMesh node
            if getNumVerts evaluated_mesh != modifier.GetNumVertices node:node then
            (
                throw "Evaluated mesh vertex indices do not match Edit Poly vertex indices."
            )

            -- Build current Edit Poly border vertices from edges with exactly one live face.
            local edge_count = modifier.GetNumEdges node:node
            for edge_index = 1 to edge_count do
            (
                local face_a = modifier.GetEdgeFace edge_index 1 node:node
                local face_b = modifier.GetEdgeFace edge_index 2 node:node
                if (face_a == 0) != (face_b == 0) then
                (
                    local border_a = modifier.GetEdgeVertex edge_index 1 node:node
                    local border_b = modifier.GetEdgeVertex edge_index 2 node:node
                    if border_a > 0 then border_vertices[border_a] = true
                    if border_b > 0 then border_vertices[border_b] = true
                )
            )

            -- LMB Clean Up Slice selects only non-border, non-inner verts with exactly two visible edges.
            for sliced_vertex in (copy selectable_vertices) do
            (
                local visible_edge_count = countVisibleEdgesAtVertex evaluated_mesh sliced_vertex
                local is_border_vertex = sliced_vertex <= border_vertices.count and border_vertices[sliced_vertex]

                if visible_edge_count != 2 then
                (
                    selectable_vertices[sliced_vertex] = false
                    non_two_visible_vertices[sliced_vertex] = true
                )
                else if is_border_vertex then
                (
                    selectable_vertices[sliced_vertex] = false
                    border_selected_vertices[sliced_vertex] = true
                )
            )

            if not batch_quiet then format "Wall-Fixer Clean Up Slice Select: selected:% protectedInner:% border:% nonTwoVisible:% selectable:%\n" sliced_vertices protected_selected_vertices border_selected_vertices non_two_visible_vertices selectable_vertices
            for sliced_vertex in sliced_vertices do
            (
                local visible_edge_count = countVisibleEdgesAtVertex evaluated_mesh sliced_vertex
                local is_border_vertex = sliced_vertex <= border_vertices.count and border_vertices[sliced_vertex]
                local select_vertex = sliced_vertex <= selectable_vertices.count and selectable_vertices[sliced_vertex]
                if not batch_quiet then format "Wall-Fixer Clean Up Slice Select Vert:% visibleEdges:% border:% inner:% select:%\n" sliced_vertex visible_edge_count is_border_vertex (sliced_vertex <= protected_inner_vertices.count and protected_inner_vertices[sliced_vertex]) select_vertex
            )

            free evaluated_mesh
            evaluated_mesh = undefined

            modifier.SetEPolySelLevel #Vertex
            subObjectLevel = 1
            modifier.SetSelection #Vertex #{} node:node
            if selectable_vertices.numberSet > 0 then
            (
                local selected_ok = modifier.Select #Vertex selectable_vertices node:node
                local actual_selection = modifier.GetSelection #Vertex node:node
                if not selected_ok or actual_selection != selectable_vertices then
                (
                    throw "Could not select Clean Up Slice eligible vertices."
                )
            )

            last_slice_report = node.name + ": Clean Up Slice eligible verts selected:" + (selectable_vertices.numberSet as string) + "."
            completeRedraw()
        )
        catch
        (
            if evaluated_mesh != undefined then free evaluated_mesh
            failure = getCurrentException()
            last_slice_error = failure
            last_slice_report = node.name + ": " + (failure as string)
        )

        failure == undefined
        -- return
    ),

    /*
    Removes one already-approved Clean Up Slice vertex with the proven per-vertex Remove Vertex sequence.
    The vertex is re-resolved by position after every topology change so later candidates stay valid.
    */
    function forceRemoveCleanUpSliceVertex node modifier original_vertex_index saved_position tolerance:0.01 =
    (
        local current_vertex_index = ::WallFixer.findDebugLiveVertexByPosition node modifier saved_position tolerance:tolerance
        if current_vertex_index <= 0 then return #(true, 0, #alreadyGone, "")

        local methods = #(#buttonRemoveVertex, #operationRemoveVertex)
        for method in methods do
        (
            current_vertex_index = ::WallFixer.findDebugLiveVertexByPosition node modifier saved_position tolerance:tolerance
            if current_vertex_index <= 0 then return #(true, 0, method, "")

            local before_live_count = ::WallFixer.getDebugLiveVertexCount node modifier
            local requested_selection = #{}
            requested_selection[current_vertex_index] = true
            local actual_selection = #{}
            local operation_error = undefined

            try
            (
                modifier.SetEPolySelLevel #Vertex
                subObjectLevel = 1
                modifier.SetSelection #Vertex #{} node:node
                modifier.Select #Vertex requested_selection node:node
                actual_selection = modifier.GetSelection #Vertex node:node
                if actual_selection != requested_selection then throw "Edit Poly vertex selection did not match the requested Clean Up Slice vertex."

                if method == #buttonRemoveVertex then
                (
                    modifier.ButtonOp #RemoveVertex
                )
                else
                (
                    modifier.SetOperation #RemoveVertex
                    modifier.Commit()
                )

                update node
                ::WallFixer.refreshDebugModifierTopology node
                modifier.RefreshScreen()
            )
            catch
            (
                operation_error = getCurrentException()
            )

            local after_live_count = ::WallFixer.getDebugLiveVertexCount node modifier
            local resolved_after = ::WallFixer.findDebugLiveVertexByPosition node modifier saved_position tolerance:tolerance
            local removed = operation_error == undefined and resolved_after == 0 and after_live_count < before_live_count
            local failure_reason = ""
            if operation_error != undefined then failure_reason = operation_error as string
            else if resolved_after > 0 then failure_reason = "Clean Up Slice vertex still resolves at its saved position"
            else if after_live_count >= before_live_count then failure_reason = "live vertex count did not decrease"

            if not batch_quiet then format "Wall-Fixer Clean Up Slice Vert Attempt: originalVert:% currentVert:% method:% selected:% liveBefore:% liveAfter:% success:% reason:%\n" \
                original_vertex_index current_vertex_index method actual_selection before_live_count after_live_count removed failure_reason

            if removed then return #(true, current_vertex_index, method, "")
        )

        current_vertex_index = ::WallFixer.findDebugLiveVertexByPosition node modifier saved_position tolerance:tolerance
        if current_vertex_index <= 0 then return #(true, 0, #alreadyGone, "")

        local collapse_before_live_count = ::WallFixer.getDebugLiveVertexCount node modifier
        local collapse_result = ::WallFixer.collapseDebugVertexToClosestNeighbor node modifier current_vertex_index
        local collapse_after_live_count = ::WallFixer.getDebugLiveVertexCount node modifier
        local collapse_resolved_after = ::WallFixer.findDebugLiveVertexByPosition node modifier saved_position tolerance:tolerance
        local collapse_removed = collapse_result[1] and collapse_resolved_after == 0 and collapse_after_live_count < collapse_before_live_count
        local collapse_reason = if collapse_removed then "" else "Collapse-to-neighbor fallback did not remove the Clean Up Slice vertex"

        if not batch_quiet then format "Wall-Fixer Clean Up Slice Vert Attempt: originalVert:% currentVert:% method:% selected:% liveBefore:% liveAfter:% success:% reason:%\n" \
            original_vertex_index current_vertex_index #collapseToNeighbor #{} collapse_before_live_count collapse_after_live_count collapse_removed collapse_reason

        if collapse_removed then return #(true, current_vertex_index, #collapseToNeighbor, "")

        #(false, current_vertex_index, #failed, collapse_reason)
        -- return
    ),

    /*
    Removes selected sliced vertices only when they have exactly two visible edges and are not on a border.
    INNER VERTS cached by Reset Slicing are always protected from removal.
    */
    function debugCleanUpSlice =
    (
        last_slice_error = undefined
        last_slice_report = ""

        local selected_nodes = selection as array
        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select the wall and sliced vertices before Clean Up Slice."
            return false
        )

        local node = selected_nodes[1]
        local modifier = getDebugTopologyModifier node
        if modifier == undefined then
        (
            last_slice_report = node.name + ": top Wall topology cleanup Edit Poly was not found."
            return false
        )

        local failure = undefined
        local sliced_vertices = modifier.GetSelection #Vertex node:node
        local protected_inner_vertices = getResetInnerVertSelection node
        local removable_vertices = #{}
        local protected_selected_vertices = #{}
        local non_two_visible_vertices = #{}
        local border_vertices = #{}
        local border_selected_vertices = #{}
        local evaluated_mesh = undefined

        if sliced_vertices == undefined or sliced_vertices.numberSet == 0 then
        (
            last_slice_report = node.name + ": no sliced verts are selected. RMB Make 1 Slice first."
            return false
        )
        if protected_inner_vertices == undefined then
        (
            last_slice_report = node.name + ": Reset Slicing INNER VERTS cache is missing. Run Reset Slicing before Clean Up Slice."
            return false
        )

        removable_vertices = copy sliced_vertices
        protected_selected_vertices = #{}
        for sliced_vertex in sliced_vertices do
        (
            if sliced_vertex <= protected_inner_vertices.count and protected_inner_vertices[sliced_vertex] then
            (
                removable_vertices[sliced_vertex] = false
                protected_selected_vertices[sliced_vertex] = true
            )
        )

        try
        (
            select node
            max modify mode
            modPanel.setCurrentObject modifier
            modifier.SetPrimaryNode node
            modifier.useStackSelection = false

            update node
            evaluated_mesh = snapshotAsMesh node
            if getNumVerts evaluated_mesh != modifier.GetNumVertices node:node then
            (
                throw "Evaluated mesh vertex indices do not match Edit Poly vertex indices."
            )

            -- Build current Edit Poly border vertices from edges with exactly one live face.
            border_vertices = #{}
            local edge_count = modifier.GetNumEdges node:node
            for edge_index = 1 to edge_count do
            (
                local face_a = modifier.GetEdgeFace edge_index 1 node:node
                local face_b = modifier.GetEdgeFace edge_index 2 node:node
                if (face_a == 0) != (face_b == 0) then
                (
                    local border_a = modifier.GetEdgeVertex edge_index 1 node:node
                    local border_b = modifier.GetEdgeVertex edge_index 2 node:node
                    if border_a > 0 then border_vertices[border_a] = true
                    if border_b > 0 then border_vertices[border_b] = true
                )
            )

            -- Clean Up Slice removes only non-border vertices with exactly two visible evaluated edges.
            non_two_visible_vertices = #{}
            border_selected_vertices = #{}
            for sliced_vertex in (copy removable_vertices) do
            (
                local visible_edge_count = countVisibleEdgesAtVertex evaluated_mesh sliced_vertex
                local is_border_vertex = sliced_vertex <= border_vertices.count and border_vertices[sliced_vertex]

                if visible_edge_count != 2 then
                (
                    removable_vertices[sliced_vertex] = false
                    non_two_visible_vertices[sliced_vertex] = true
                )
                else if is_border_vertex then
                (
                    removable_vertices[sliced_vertex] = false
                    border_selected_vertices[sliced_vertex] = true
                )
            )

            if not batch_quiet then format "Wall-Fixer Clean Up Slice: selected:% protectedInner:% border:% nonTwoVisible:% removable:%\n" sliced_vertices protected_selected_vertices border_selected_vertices non_two_visible_vertices removable_vertices
            for sliced_vertex in sliced_vertices do
            (
                local visible_edge_count = countVisibleEdgesAtVertex evaluated_mesh sliced_vertex
                local is_border_vertex = sliced_vertex <= border_vertices.count and border_vertices[sliced_vertex]
                local remove_vertex = sliced_vertex <= removable_vertices.count and removable_vertices[sliced_vertex]
                if not batch_quiet then format "Wall-Fixer Clean Up Slice Vert:% visibleEdges:% border:% remove:%\n" sliced_vertex visible_edge_count is_border_vertex remove_vertex
            )

            free evaluated_mesh
            evaluated_mesh = undefined

            local removable_vertex_data = #()
            for removable_vertex in removable_vertices do
            (
                local removable_position = modifier.GetVertex removable_vertex node:node
                if removable_position != undefined then append removable_vertex_data #(removable_vertex, removable_position)
            )

            local removed_vertices = #{}
            local unresolved_vertices = #{}
            local removal_methods = #()

            for removable_data in removable_vertex_data do
            (
                local original_vertex_index = removable_data[1]
                local saved_position = removable_data[2]
                local remove_result = ::WallFixer.forceRemoveCleanUpSliceVertex node modifier original_vertex_index saved_position tolerance:0.01

                if remove_result[1] then
                (
                    removed_vertices[original_vertex_index] = true
                    append removal_methods #(original_vertex_index, remove_result[3])
                )
                else
                (
                    unresolved_vertices[original_vertex_index] = true
                    append removal_methods #(original_vertex_index, remove_result[3], remove_result[4])
                )
            )

            modifier.SetEPolySelLevel #Vertex
            subObjectLevel = 1
            modifier.SetSelection #Vertex #{} node:node

            if unresolved_vertices.numberSet > 0 then
            (
                throw ("Could not remove all Clean Up Slice vertices. Unresolved: " + (unresolved_vertices as string))
            )

            last_slice_report = node.name + ": sliced verts removed:" + (removed_vertices.numberSet as string) + "; protected inner verts:" + (protected_selected_vertices.numberSet as string) + "; skipped border verts:" + (border_selected_vertices.numberSet as string) + "; skipped non-2-visible verts:" + (non_two_visible_vertices.numberSet as string) + "."
            if not batch_quiet then format "Wall-Fixer Clean Up Slice: requested:% removed:% methods:% protected:% skippedBorder:% skippedNonTwoVisible:%\n" removable_vertices removed_vertices removal_methods protected_selected_vertices border_selected_vertices non_two_visible_vertices
            completeRedraw()
        )
        catch
        (
            if evaluated_mesh != undefined then free evaluated_mesh
            failure = getCurrentException()
            last_slice_error = failure
            last_slice_report = node.name + ": " + (failure as string)
        )

        failure == undefined
        -- return
    ),
    /*
    Removes hidden incident edges from one confirmed two-visible-edge straight vertex.
    Visible edges are never selected; hidden edges are removed only to make Remove Vertex legal.
    */
    function removePostProcessHiddenIncidentEdges node modifier saved_position position_tolerance:0.01 =
    (
        local current_vertex_index = ::WallFixer.findDebugLiveVertexByPosition node modifier saved_position tolerance:position_tolerance
        if current_vertex_index <= 0 then return #(true, 0, 0)

        local evaluated_mesh = snapshotAsMesh node
        if evaluated_mesh == undefined then return #(false, 0, 1)

        if getNumVerts evaluated_mesh != modifier.GetNumVertices node:node then
        (
            free evaluated_mesh
            return #(false, 0, 1)
        )

        local hidden_edge_data = #()
        local edge_count = modifier.GetNumEdges node:node
        for edge_index = 1 to edge_count do
        (
            if ::WallFixer.doesDebugModifierEdgeExist node modifier edge_index then
            (
                local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
                local edge_b = modifier.GetEdgeVertex edge_index 2 node:node

                if edge_a == current_vertex_index or edge_b == current_vertex_index then
                (
                    local other_vertex = if edge_a == current_vertex_index then edge_b else edge_a
                    local edge_visible = ::WallFixer.isEvaluatedMeshEdgeVisibleByVertexPair evaluated_mesh current_vertex_index other_vertex

                    if not edge_visible then
                    (
                        local point_a = modifier.GetVertex edge_a node:node
                        local point_b = modifier.GetVertex edge_b node:node
                        if point_a != undefined and point_b != undefined then append hidden_edge_data #(point_a, point_b)
                    )
                )
            )
        )

        free evaluated_mesh
        evaluated_mesh = undefined

        local removed_count = 0
        local unresolved_count = 0
        local old_remove_ctrl = modifier.remveEdgeCtrlKey

        for edge_data in hidden_edge_data do
        (
            local point_a = edge_data[1]
            local point_b = edge_data[2]
            local current_edge = ::WallFixer.findDebugEdgeByEndpointPositions node modifier point_a point_b tolerance:position_tolerance

            if current_edge > 0 then
            (
                local removed = false
                local operation_error = undefined
                try
                (
                    modifier.remveEdgeCtrlKey = false
                    modifier.SetEPolySelLevel #Edge
                    modifier.SetSelection #Edge #{} node:node

                    local requested_selection = #{}
                    requested_selection[current_edge] = true
                    modifier.Select #Edge requested_selection node:node

                    if (modifier.GetSelection #Edge node:node) != requested_selection then
                    (
                        throw "Could not select hidden incident edge."
                    )

                    modifier.ButtonOp #RemoveEdge
                    update node
                    ::WallFixer.refreshDebugModifierTopology node
                    modifier.RefreshScreen()

                    current_edge = ::WallFixer.findDebugEdgeByEndpointPositions node modifier point_a point_b tolerance:position_tolerance
                    removed = current_edge == 0

                    if not removed and current_edge > 0 then
                    (
                        modifier.SetSelection #Edge #{} node:node
                        requested_selection = #{}
                        requested_selection[current_edge] = true
                        modifier.Select #Edge requested_selection node:node
                        modifier.SetOperation #RemoveEdge
                        modifier.Commit()
                        update node
                        ::WallFixer.refreshDebugModifierTopology node
                        modifier.RefreshScreen()

                        current_edge = ::WallFixer.findDebugEdgeByEndpointPositions node modifier point_a point_b tolerance:position_tolerance
                        removed = current_edge == 0
                    )
                )
                catch
                (
                    operation_error = getCurrentException()
                )

                if not batch_quiet then format "Wall-Fixer Postprocess Hidden Edge Remove: endpoints:%/% success:% reason:%\n" \
                    point_a point_b removed (if operation_error == undefined then "" else operation_error as string)

                if removed then removed_count += 1 else unresolved_count += 1
            )
        )

        modifier.remveEdgeCtrlKey = old_remove_ctrl

        #(unresolved_count == 0, removed_count, unresolved_count)
        -- return
    ),

    /*
    Removes one live vertex with exactly two visible straight edges.
    Hidden incident edges are removed first; then the proven single-vertex Remove Vertex dissolves the vertex.
    */
    function removePostProcessStraightTwoVisibleEdgeVertex node modifier original_vertex_index saved_position position_tolerance:0.01 angle_threshold:0.1 =
    (
        local current_vertex_index = ::WallFixer.findDebugLiveVertexByPosition node modifier saved_position tolerance:position_tolerance
        if current_vertex_index <= 0 then return #(true, 0, #alreadyGone, "")

        local evaluated_mesh = snapshotAsMesh node
        if evaluated_mesh == undefined then return #(false, current_vertex_index, #protected, "could not evaluate current mesh")
        if getNumVerts evaluated_mesh != modifier.GetNumVertices node:node then
        (
            free evaluated_mesh
            return #(false, current_vertex_index, #protected, "evaluated mesh vertex ids do not match Edit Poly")
        )

        local is_candidate = ::WallFixer.isPostProcessStraightTwoVisibleEdgeVertex evaluated_mesh current_vertex_index angle_threshold:angle_threshold
        free evaluated_mesh
        evaluated_mesh = undefined

        if not is_candidate then return #(true, current_vertex_index, #noLongerCandidate, "")

        local hidden_cleanup = ::WallFixer.removePostProcessHiddenIncidentEdges node modifier saved_position position_tolerance:position_tolerance
        if not hidden_cleanup[1] then
        (
            return #(false, current_vertex_index, #hiddenEdgeCleanup, "could not remove every hidden incident edge")
        )

        current_vertex_index = ::WallFixer.findDebugLiveVertexByPosition node modifier saved_position tolerance:position_tolerance
        if current_vertex_index <= 0 then return #(true, 0, #removedWithHiddenEdges, "")

        if not(::WallFixer.isDebugRemovableSliceVertex node modifier current_vertex_index angle_threshold:angle_threshold) then
        (
            return #(false, current_vertex_index, #protected, "vertex did not become an exactly-two-edge straight vertex after hidden-edge cleanup")
        )

        local before_live_count = ::WallFixer.getDebugLiveVertexCount node modifier
        local requested_selection = #{}
        requested_selection[current_vertex_index] = true
        local actual_selection = #{}
        local removed = false
        local method = #buttonRemoveVertex
        local failure_reason = ""

        try
        (
            modifier.SetEPolySelLevel #Vertex
            modifier.SetSelection #Vertex #{} node:node
            modifier.Select #Vertex requested_selection node:node
            actual_selection = modifier.GetSelection #Vertex node:node

            if actual_selection != requested_selection then
            (
                throw "Could not select straight two-visible-edge postprocess vertex."
            )

            modifier.ButtonOp #RemoveVertex
            update node
            ::WallFixer.refreshDebugModifierTopology node
            modifier.RefreshScreen()

            local resolved_after = ::WallFixer.findDebugLiveVertexByPosition node modifier saved_position tolerance:position_tolerance
            local after_live_count = ::WallFixer.getDebugLiveVertexCount node modifier
            removed = resolved_after == 0 and after_live_count == (before_live_count - 1)

            if not removed then
            (
                current_vertex_index = ::WallFixer.findDebugLiveVertexByPosition node modifier saved_position tolerance:position_tolerance
                if current_vertex_index > 0 then
                (
                    requested_selection = #{}
                    requested_selection[current_vertex_index] = true
                    modifier.SetSelection #Vertex #{} node:node
                    modifier.Select #Vertex requested_selection node:node
                    modifier.SetOperation #RemoveVertex
                    modifier.Commit()
                    update node
                    ::WallFixer.refreshDebugModifierTopology node
                    modifier.RefreshScreen()
                    method = #operationRemoveVertex

                    resolved_after = ::WallFixer.findDebugLiveVertexByPosition node modifier saved_position tolerance:position_tolerance
                    after_live_count = ::WallFixer.getDebugLiveVertexCount node modifier
                    removed = resolved_after == 0 and after_live_count == (before_live_count - 1)
                )
            )

            if not removed then failure_reason = "Remove Vertex did not remove the straight two-visible-edge vertex"
        )
        catch
        (
            failure_reason = getCurrentException() as string
            removed = false
        )

        if not batch_quiet then format "Wall-Fixer Postprocess Remove Straight 2-Visible-Edge Vert: originalVert:% currentVert:% hiddenEdgesRemoved:% selected:% method:% success:% reason:%\n" \
            original_vertex_index current_vertex_index hidden_cleanup[2] actual_selection method removed failure_reason

        #(removed, current_vertex_index, method, failure_reason)
        -- return
    ),

    /*
    Selects the exact Clean Up Sliced Edges postprocess candidates without changing topology.
    Uses the current top Edit Poly only; no modifier creation, deletion, or undo block is used.
    */
    function inspectPostProcessCleanUpSliceVerts node angle_threshold:0.1 =
    (
        local candidate_vertices = #{}
        local evaluated_mesh = undefined
        local modifier = undefined
        local failure = undefined

        if node == undefined or not(isValidNode node) then return #(false, candidate_vertices)

        try
        (
            modifier = ::WallFixer.getDebugTopologyModifier node
            if modifier == undefined then throw "The selected wall has no top Edit Poly modifier for postprocess inspection."

            select node
            max modify mode
            modPanel.setCurrentObject modifier
            modifier.SetPrimaryNode node
            modifier.useStackSelection = false

            evaluated_mesh = snapshotAsMesh node
            if evaluated_mesh == undefined then throw "Could not evaluate postprocess inspection mesh."
            if getNumVerts evaluated_mesh != modifier.GetNumVertices node:node then
            (
                throw "Evaluated mesh vertex indices do not match Edit Poly vertex indices."
            )

            local border_vertices = #{}
            local edge_count = modifier.GetNumEdges node:node
            for edge_index = 1 to edge_count do
            (
                local face_a = modifier.GetEdgeFace edge_index 1 node:node
                local face_b = modifier.GetEdgeFace edge_index 2 node:node
                if (face_a == 0) != (face_b == 0) then
                (
                    local border_a = modifier.GetEdgeVertex edge_index 1 node:node
                    local border_b = modifier.GetEdgeVertex edge_index 2 node:node
                    if border_a > 0 then border_vertices[border_a] = true
                    if border_b > 0 then border_vertices[border_b] = true
                )
            )

            local base_vertex_count = polyop.getNumVerts node.baseObject
            local vertex_count = modifier.GetNumVertices node:node
            for vertex_index = (base_vertex_count + 1) to vertex_count do
            (
                if ::WallFixer.doesDebugModifierVertexExist node modifier vertex_index then
                (
                    local is_border_vertex = vertex_index <= border_vertices.count and border_vertices[vertex_index]
                    local is_straight_two_visible = ::WallFixer.isPostProcessStraightTwoVisibleEdgeVertex \
                        evaluated_mesh vertex_index angle_threshold:angle_threshold

                    if not is_border_vertex and is_straight_two_visible then
                    (
                        candidate_vertices[vertex_index] = true
                    )
                )
            )

            free evaluated_mesh
            evaluated_mesh = undefined

            modifier.SetEPolySelLevel #Vertex
            subObjectLevel = 1
            modifier.SetSelection #Vertex #{} node:node
            if candidate_vertices.numberSet > 0 then
            (
                modifier.Select #Vertex candidate_vertices node:node
            )
            update node
            modifier.RefreshScreen()

            local actual_selection = modifier.GetSelection #Vertex node:node
            if actual_selection != candidate_vertices then
            (
                throw ("Could not select every Clean Up Sliced Edges postprocess candidate. Requested:" + (candidate_vertices as string) + " actual:" + (actual_selection as string))
            )

            last_slice_report = node.name + ": Clean Up Sliced Edges postprocess candidates:" + (candidate_vertices as string)
            if not batch_quiet then format "Wall-Fixer Clean Up Sliced Edges Postprocess Inspect: node:% candidates:%\n" node.name candidate_vertices
            completeRedraw()
        )
        catch
        (
            if evaluated_mesh != undefined then free evaluated_mesh
            failure = getCurrentException()
            last_slice_error = failure
            last_slice_report = node.name + ": " + (failure as string)
        )

        #(failure == undefined, candidate_vertices)
        -- return
    ),

    /*
    Removes only newly created non-border vertices with exactly two visible straight edges in a dedicated Edit Poly modifier.
    Base-object ids 1..baseVertCount are immutable anchors and are never postprocessed.
    */
    function postProcessCleanUpSliceVerts node position_tolerance:0.01 angle_threshold:0.1 =
    (
        local unresolved_vertices = #{}
        local removed_vertices = #{}
        local candidate_vertices = #{}
        local candidate_positions = #()
        local post_modifier = undefined
        local evaluated_mesh = undefined
        local failure = undefined

        if node == undefined or not(isValidNode node) then return #(false, 0, 0, unresolved_vertices)

        local base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then return #(false, 0, 0, unresolved_vertices)

        try
        (
            post_modifier = Edit_Poly name:"WMC - CLEAN UP SLICED EDGES POSTPROCESS"
            addModifier node post_modifier
            update node

            select node
            max modify mode
            modPanel.setCurrentObject post_modifier
            post_modifier.SetPrimaryNode node
            post_modifier.useStackSelection = false

            evaluated_mesh = snapshotAsMesh node
            if evaluated_mesh == undefined then throw "Could not evaluate postprocess mesh."
            if getNumVerts evaluated_mesh != post_modifier.GetNumVertices node:node then
            (
                throw "Evaluated mesh vertex indices do not match Edit Poly vertex indices."
            )

            local border_vertices = #{}
            local edge_count = post_modifier.GetNumEdges node:node
            for edge_index = 1 to edge_count do
            (
                local face_a = post_modifier.GetEdgeFace edge_index 1 node:node
                local face_b = post_modifier.GetEdgeFace edge_index 2 node:node
                if (face_a == 0) != (face_b == 0) then
                (
                    local border_a = post_modifier.GetEdgeVertex edge_index 1 node:node
                    local border_b = post_modifier.GetEdgeVertex edge_index 2 node:node
                    if border_a > 0 then border_vertices[border_a] = true
                    if border_b > 0 then border_vertices[border_b] = true
                )
            )

            local base_vertex_count = polyop.getNumVerts base_obj
            local vertex_count = post_modifier.GetNumVertices node:node
            for vertex_index = (base_vertex_count + 1) to vertex_count do
            (
                if ::WallFixer.doesDebugModifierVertexExist node post_modifier vertex_index then
                (
                    local is_border_vertex = vertex_index <= border_vertices.count and border_vertices[vertex_index]
                    local is_straight_two_visible = ::WallFixer.isPostProcessStraightTwoVisibleEdgeVertex \
                        evaluated_mesh vertex_index angle_threshold:angle_threshold

                    if not is_border_vertex and is_straight_two_visible then
                    (
                        local vertex_position = post_modifier.GetVertex vertex_index node:node
                        if vertex_position != undefined then
                        (
                            candidate_vertices[vertex_index] = true
                            append candidate_positions #(vertex_index, vertex_position)
                        )
                    )
                )
            )

            free evaluated_mesh
            evaluated_mesh = undefined

            if not batch_quiet then format "Wall-Fixer Clean Up Sliced Edges Postprocess Candidates: node:% candidates:%\n" node.name candidate_vertices

            if candidate_vertices.numberSet == 0 then
            (
                deleteModifier node post_modifier
                post_modifier = undefined
                update node
                last_slice_report = node.name + ": Clean Up Sliced Edges postprocess found no non-border vertices with exactly two visible straight edges."
                if not batch_quiet then format "Wall-Fixer Clean Up Sliced Edges Postprocess: node:% candidates:#{} removed:#{} unresolved:#{}\n" node.name
                return #(true, 0, 0, unresolved_vertices)
            )

            for candidate_data in candidate_positions do
            (
                local original_vertex_index = candidate_data[1]
                local saved_position = candidate_data[2]
                local remove_result = ::WallFixer.removePostProcessStraightTwoVisibleEdgeVertex \
                    node post_modifier original_vertex_index saved_position position_tolerance:position_tolerance angle_threshold:angle_threshold

                if remove_result[1] then
                (
                    removed_vertices[original_vertex_index] = true
                )
                else
                (
                    unresolved_vertices[original_vertex_index] = true
                )
            )

            if unresolved_vertices.numberSet > 0 then
            (
                throw ("Could not remove all Clean Up Sliced Edges postprocess vertices. Unresolved: " + (unresolved_vertices as string))
            )

            post_modifier.name = "WMC - CLEAN UP SLICED EDGES POSTPROCESS"
            last_slice_report = node.name + ": Clean Up Sliced Edges postprocess removed:" + (removed_vertices.numberSet as string) + "."
            if not batch_quiet then format "Wall-Fixer Clean Up Sliced Edges Postprocess: node:% candidates:% removed:% unresolved:% modifier:%\n" \
                node.name candidate_vertices removed_vertices unresolved_vertices post_modifier.name
            completeRedraw()
        )
        catch
        (
            if evaluated_mesh != undefined then free evaluated_mesh
            if post_modifier != undefined then
            (
                try(deleteModifier node post_modifier)catch()
                update node
            )
            failure = getCurrentException()
            last_slice_error = failure
            last_slice_report = node.name + ": " + (failure as string)
        )

        #(failure == undefined, candidate_vertices.numberSet, removed_vertices.numberSet, unresolved_vertices)
        -- return
    ),

    /*
    Captures the exact manual Clean Up Slice LMB candidates from the latest sliced-edge selection.
    The original edge selection is restored so Clean Up Sliced Edges can run unchanged afterward.
    */
    function captureMassSliceCleanUpSliceData node =
    (
        local empty_vertices = #{}
        local saved_positions = #()
        if node == undefined or not(isValidNode node) then return #(false, empty_vertices, saved_positions)

        local modifier = getDebugTopologyModifier node
        if modifier == undefined then return #(false, empty_vertices, saved_positions)

        local saved_report = last_slice_report
        local saved_error = last_slice_error
        local sliced_edges = modifier.GetSelection #Edge node:node
        if sliced_edges == undefined or sliced_edges.numberSet == 0 then return #(false, empty_vertices, saved_positions)

        local captured_vertices = #{}
        local capture_ok = false
        local capture_error = undefined

        try
        (
            select node
            max modify mode
            modPanel.setCurrentObject modifier
            modifier.SetPrimaryNode node
            modifier.useStackSelection = false

            if not ::WallFixer.debugSelectSlicedEdgeVertices() then throw last_slice_report
            if not ::WallFixer.debugInspectCleanUpSlice() then throw last_slice_report

            captured_vertices = modifier.GetSelection #Vertex node:node
            for vertex_index in captured_vertices do
            (
                local vertex_position = modifier.GetVertex vertex_index node:node
                if vertex_position != undefined then append saved_positions #(vertex_index, vertex_position)
            )
            capture_ok = true
        )
        catch
        (
            capture_error = getCurrentException()
            capture_ok = false
        )

        try
        (
            modifier.SetEPolySelLevel #Edge
            subObjectLevel = 2
            modifier.SetSelection #Edge #{} node:node
            if sliced_edges.numberSet > 0 then modifier.Select #Edge sliced_edges node:node
        )
        catch
        (
        )

        last_slice_report = saved_report
        last_slice_error = saved_error

        if not batch_quiet then format "Wall-Fixer Clean Up Slice Capture: node:% edges:% candidates:% positions:% success:% error:%\n" node.name sliced_edges captured_vertices saved_positions.count capture_ok capture_error
        #(capture_ok, captured_vertices, saved_positions)
        -- return
    ),

    /*
    Re-resolves captured Clean Up Slice verts after prior batch cleanup and removes them with the proven manual method.
    Missing captured verts are treated as already removed by an earlier cleanup pass.
    */
    function cleanupCapturedMassSliceCleanUpSliceVerts node clean_up_slice_data position_tolerance:0.01 =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0, 0)
        if clean_up_slice_data == undefined or clean_up_slice_data.count < 3 then return #(false, 0, 0)

        local modifier = getDebugTopologyModifier node
        if modifier == undefined then return #(false, 0, clean_up_slice_data[2].numberSet)

        local captured_vertices = clean_up_slice_data[2]
        local saved_positions = clean_up_slice_data[3]
        local resolved_vertices = #{}

        for saved_data in saved_positions do
        (
            local saved_position = saved_data[2]
            local current_vertex = ::WallFixer.findDebugLiveVertexByPosition node modifier saved_position tolerance:position_tolerance
            if current_vertex > 0 then resolved_vertices[current_vertex] = true
        )

        if not batch_quiet then format "Wall-Fixer Clean Up Slice Resolve: node:% captured:% resolved:%\n" node.name captured_vertices resolved_vertices

        if resolved_vertices.numberSet == 0 then
        (
            last_slice_report = node.name + ": captured Clean Up Slice verts were already removed by earlier cleanup."
            return #(true, 0, captured_vertices.numberSet)
        )

        select node
        max modify mode
        modPanel.setCurrentObject modifier
        modifier.SetPrimaryNode node
        modifier.useStackSelection = false
        modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1
        modifier.SetSelection #Vertex #{} node:node
        local selected_ok = modifier.Select #Vertex resolved_vertices node:node
        local actual_selection = modifier.GetSelection #Vertex node:node

        if not selected_ok or actual_selection != resolved_vertices then
        (
            last_slice_report = node.name + ": could not restore captured Clean Up Slice vertex selection."
            return #(false, resolved_vertices.numberSet, captured_vertices.numberSet)
        )

        local cleanup_ok = ::WallFixer.debugCleanUpSlice()
        if not batch_quiet then format "Wall-Fixer Clean Up Slice Batch: node:% captured:% resolved:% success:% report:%\n" node.name captured_vertices resolved_vertices cleanup_ok last_slice_report
        #(cleanup_ok, resolved_vertices.numberSet, captured_vertices.numberSet)
        -- return
    ),

    function sliceSelection weld_vertices:false weld_threshold:1.0 cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 =
    (
        local selectedNodes = selection as array
        local processed = 0
        last_slice_report = ""
        if selectedNodes.count == 0 then
        (
            last_slice_report = "Select at least one wall before running this action."
            return false
        )
        undo "Wall-Fixer - Slice" on
        (
            for node in selectedNodes do
            (
                if processNode node cut_mode:cut_mode slice_plane_mode:slice_plane_mode angle_threshold:angle_threshold planar_tolerance:planar_tolerance then
                (
                    processed += 1
                    last_slice_report += node.name + ": completed; " + (last_slice_count as string) + " slice operations.\n"
                )
                else last_slice_report += node.name + ": " + (last_slice_error as string) + "\n"
            )
        )
        completeRedraw()
        processed == selectedNodes.count
    ),
    function propagateAutomaticJunctionCuts node cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 =
    (
        if processNode node cut_mode:cut_mode slice_plane_mode:slice_plane_mode angle_threshold:angle_threshold planar_tolerance:planar_tolerance then last_slice_count else 0
    ),
    function propagateSelectionJunctionCuts weld_vertices:false weld_threshold:1.0 auto_smooth:false cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 =
    (
        local selectedNodes = selection as array
        local processed = 0
        last_slice_report = ""
        if selectedNodes.count == 0 then
        (
            last_slice_report = "Select at least one wall before running this action."
            return false
        )
        undo "Wall-Fixer - Fix N-gons" on
        (
            for node in selectedNodes do
            (
                if processNode node cut_mode:cut_mode slice_plane_mode:slice_plane_mode angle_threshold:angle_threshold planar_tolerance:planar_tolerance auto_smooth:auto_smooth then
                (
                    processed += 1
                    last_slice_report += node.name + ": completed; " + (last_slice_count as string) + " slice operations.\n"
                )
                else last_slice_report += node.name + ": " + (last_slice_error as string) + "\n"
            )
        )
        completeRedraw()
        processed == selectedNodes.count
    ),

    /*
    Returns open border edges from the current Edit Poly modifier or Editable Poly base object.
    The current modifier is never replaced or collapsed.
    */
    function get90AngleOpenBorderEdges node source_kind source_ref =
    (
        local border_edges = #{}
        if node == undefined or not(isValidNode node) then return border_edges
        if source_ref == undefined then return border_edges

        if source_kind == #editPoly then
        (
            local edge_count = 0
            try(edge_count = source_ref.GetNumEdges node:node)catch(edge_count = 0)

            for edge_index = 1 to edge_count do
            (
                local face_a = undefined
                local face_b = undefined
                try
                (
                    face_a = source_ref.GetEdgeFace edge_index 1 node:node
                    face_b = source_ref.GetEdgeFace edge_index 2 node:node
                )
                catch
                (
                    face_a = undefined
                    face_b = undefined
                )

                if face_a != undefined and face_b != undefined then
                (
                    if (face_a == 0) != (face_b == 0) then border_edges[edge_index] = true
                )
            )
        )
        else
        (
            try(border_edges = polyop.getOpenEdges source_ref)catch(border_edges = #{})
        )

        border_edges
        -- return
    ),

    /*
    Returns the two current border-neighbor vertices connected to one border vertex.
    Both Editable Poly and the active Edit Poly modifier use their own current topology.
    */
    function get90AngleBorderNeighborVerts node source_kind source_ref border_edges vert_index =
    (
        local neighbor_verts = #()
        if node == undefined or not(isValidNode node) then return neighbor_verts
        if source_ref == undefined then return neighbor_verts

        if source_kind == #editPoly then
        (
            local connected_edge_count = 0
            try(connected_edge_count = source_ref.GetVertexEdgeCount vert_index node:node)catch(connected_edge_count = 0)

            for edge_slot = 1 to connected_edge_count do
            (
                local edge_index = undefined
                try(edge_index = source_ref.GetVertexEdge vert_index edge_slot node:node)catch(edge_index = undefined)

                if edge_index != undefined and edge_index > 0 and edge_index <= border_edges.count and border_edges[edge_index] then
                (
                    local edge_a = source_ref.GetEdgeVertex edge_index 1 node:node
                    local edge_b = source_ref.GetEdgeVertex edge_index 2 node:node
                    local other_vert = if edge_a == vert_index then edge_b else if edge_b == vert_index then edge_a else 0
                    if other_vert > 0 then appendUniqueInteger neighbor_verts other_vert
                )
            )
        )
        else
        (
            local connected_edges = (polyop.getEdgesUsingVert source_ref vert_index) * border_edges
            for edge_index in connected_edges do
            (
                local edge_verts = polyop.getEdgeVerts source_ref edge_index
                if edge_verts != undefined and edge_verts.count == 2 then
                (
                    local other_vert = if edge_verts[1] == vert_index then edge_verts[2] else if edge_verts[2] == vert_index then edge_verts[1] else 0
                    if other_vert > 0 then appendUniqueInteger neighbor_verts other_vert
                )
            )
        )

        neighbor_verts
        -- return
    ),

    /*
    Returns one current vertex position in object space from either supported editing level.
    */
    function get90AngleVertexPosition node source_kind source_ref vert_index =
    (
        local position_value = undefined
        try
        (
            position_value = if source_kind == #editPoly then source_ref.GetVertex vert_index node:node else polyop.getVert source_ref vert_index
        )
        catch
        (
            position_value = undefined
        )
        position_value
        -- return
    ),

    /*
    Returns the current vertex selection from either supported editing level.
    */
    function get90AngleVertexSelection node source_kind source_ref =
    (
        local selected_verts = #{}
        try
        (
            selected_verts = if source_kind == #editPoly then source_ref.GetSelection #Vertex node:node else polyop.getVertSelection source_ref
        )
        catch
        (
            selected_verts = #{}
        )
        if selected_verts == undefined then selected_verts = #{}
        copy selected_verts
        -- return
    ),

    /*
    Writes the current vertex selection without creating or collapsing modifiers.
    */
    function set90AngleVertexSelection node source_kind source_ref selected_verts =
    (
        if node == undefined or not(isValidNode node) then return false
        if source_ref == undefined then return false

        local success = true
        try
        (
            if source_kind == #editPoly then
            (
                select node
                max modify mode
                modPanel.setCurrentObject source_ref
                source_ref.SetPrimaryNode node
                source_ref.useStackSelection = false
                source_ref.SetEPolySelLevel #Vertex
                subObjectLevel = 1
                source_ref.SetSelection #Vertex selected_verts node:node
            )
            else
            (
                select node
                max modify mode
                modPanel.setCurrentObject source_ref
                subObjectLevel = 1
                polyop.setVertSelection source_ref selected_verts
            )
        )
        catch
        (
            success = false
        )

        success
        -- return
    ),

    /*
    Measures the unsigned border angle at one vertex in world space.
    The result is in degrees in the range 0..180.
    */
    function get90AngleAtBorderVert node source_kind source_ref border_edges vert_index =
    (
        local neighbor_verts = get90AngleBorderNeighborVerts node source_kind source_ref border_edges vert_index
        if neighbor_verts.count != 2 then return undefined

        local center_local = get90AngleVertexPosition node source_kind source_ref vert_index
        local point_a_local = get90AngleVertexPosition node source_kind source_ref neighbor_verts[1]
        local point_b_local = get90AngleVertexPosition node source_kind source_ref neighbor_verts[2]
        if center_local == undefined or point_a_local == undefined or point_b_local == undefined then return undefined

        local center_world = center_local * node.objectTransform
        local point_a_world = point_a_local * node.objectTransform
        local point_b_world = point_b_local * node.objectTransform
        local dir_a = safeNormalize (point_a_world - center_world)
        local dir_b = safeNormalize (point_b_world - center_world)
        if dir_a == undefined or dir_b == undefined then return undefined

        local edge_dot = amax -1.0 (amin 1.0 (dot dir_a dir_b))
        acos edge_dot
        -- return
    ),

    /*
    Returns true for clean 90-degree corners and 180-degree straight border vertices.
    Zero-degree foldbacks are intentionally rejected as invalid border geometry.
    */
    function isValid90BorderAngle angle_value angle_threshold:0.1 =
    (
        if angle_value == undefined then return false
        local tolerance_value = amax 0.0 angle_threshold
        local deviation_90 = abs(angle_value - 90.0)
        local deviation_180 = abs(angle_value - 180.0)
        (amin deviation_90 deviation_180) <= tolerance_value
        -- return
    ),

    /*
    Collects invalid open-border vertices from the current editing level.
    Border junctions without exactly two border neighbors are invalid by definition.
    */
    function collectInvalid90BorderVerts node source_kind source_ref angle_threshold:0.1 =
    (
        local invalid_verts = #{}
        local border_edges = get90AngleOpenBorderEdges node source_kind source_ref
        local border_verts = #{}

        if source_kind == #editPoly then
        (
            for edge_index in border_edges do
            (
                local edge_a = source_ref.GetEdgeVertex edge_index 1 node:node
                local edge_b = source_ref.GetEdgeVertex edge_index 2 node:node
                if edge_a != undefined and edge_a > 0 then border_verts[edge_a] = true
                if edge_b != undefined and edge_b > 0 then border_verts[edge_b] = true
            )
        )
        else
        (
            border_verts = polyop.getVertsUsingEdge source_ref border_edges
        )

        for vert_index in border_verts do
        (
            local angle_value = get90AngleAtBorderVert node source_kind source_ref border_edges vert_index
            if not(isValid90BorderAngle angle_value angle_threshold:angle_threshold) then invalid_verts[vert_index] = true
        )

        invalid_verts
        -- return
    ),

    /*
    Selects every invalid 90/180-degree border vertex at the active editing level.
    No topology or vertex positions are changed.
    */
    function selectInvalid90BorderVerts angle_threshold:0.1 =
    (
        local selected_nodes = selection as array
        local active_edit_poly = undefined
        local processed_nodes = 0
        local total_invalid = 0
        last_slice_report = ""

        try
        (
            local current_object = modPanel.getCurrentObject()
            if current_object != undefined and classOf current_object == Edit_Poly then active_edit_poly = current_object
        )
        catch
        (
            active_edit_poly = undefined
        )

        for node in selected_nodes do
        (
            local source_data = getDoubleFaceSource node active_edit_poly
            if source_data != undefined then
            (
                local source_kind = source_data[1]
                local source_ref = source_data[2]
                local invalid_verts = collectInvalid90BorderVerts node source_kind source_ref angle_threshold:angle_threshold
                if set90AngleVertexSelection node source_kind source_ref invalid_verts then
                (
                    processed_nodes += 1
                    total_invalid += invalid_verts.numberSet
                )
                update node
            )
        )

        if processed_nodes == 0 then
        (
            last_slice_report = "CHECK 90° ANGLES requires an Editable Poly base object or the current Edit Poly modifier."
            return false
        )

        try
        (
            max modify mode
            subObjectLevel = 1
        )
        catch()

        last_slice_report = "CHECK 90° ANGLES: invalid border verts selected:" + (total_invalid as string) + "."
        if not batch_quiet then format "%\n" last_slice_report
        completeRedraw()
        true
        -- return
    ),

    /*
    Calculates the corrected world position for one selected invalid border vertex.
    90-degree corners snap to horizontal/vertical neighbor alignment; near-straight vertices project onto the neighbor line.
    */
    function get90AngleFixTarget node source_kind source_ref border_edges vert_index angle_threshold:0.1 =
    (
        local neighbor_verts = get90AngleBorderNeighborVerts node source_kind source_ref border_edges vert_index
        if neighbor_verts.count != 2 then return undefined

        local center_local = get90AngleVertexPosition node source_kind source_ref vert_index
        local point_a_local = get90AngleVertexPosition node source_kind source_ref neighbor_verts[1]
        local point_b_local = get90AngleVertexPosition node source_kind source_ref neighbor_verts[2]
        if center_local == undefined or point_a_local == undefined or point_b_local == undefined then return undefined

        local center_world = center_local * node.objectTransform
        local point_a_world = point_a_local * node.objectTransform
        local point_b_world = point_b_local * node.objectTransform
        local dir_a = safeNormalize (point_a_world - center_world)
        local dir_b = safeNormalize (point_b_world - center_world)
        if dir_a == undefined or dir_b == undefined then return undefined

        local edge_dot = amax -1.0 (amin 1.0 (dot dir_a dir_b))
        local angle_value = acos edge_dot
        if isValid90BorderAngle angle_value angle_threshold:angle_threshold then return center_world

        local deviation_90 = abs(angle_value - 90.0)
        local deviation_180 = abs(angle_value - 180.0)

        if deviation_180 < deviation_90 then
        (
            local line_vector = point_b_world - point_a_world
            local line_length_sq = dot line_vector line_vector
            if line_length_sq <= epsilon then return undefined
            local line_factor = dot (center_world - point_a_world) line_vector / line_length_sq
            point_a_world + (line_vector * line_factor)
        )
        else
        (
            local world_up = [0.0,0.0,1.0]
            local vertical_error_a = acos (amax 0.0 (amin 1.0 (abs(dot dir_a world_up))))
            local vertical_error_b = acos (amax 0.0 (amin 1.0 (abs(dot dir_b world_up))))
            local horizontal_error_a = abs(90.0 - vertical_error_a)
            local horizontal_error_b = abs(90.0 - vertical_error_b)
            local axis_a = if vertical_error_a <= horizontal_error_a then #vertical else #horizontal
            local axis_b = if vertical_error_b <= horizontal_error_b then #vertical else #horizontal
            local best_error_a = amin vertical_error_a horizontal_error_a
            local best_error_b = amin vertical_error_b horizontal_error_b

            if axis_a == axis_b then
            (
                if best_error_a <= best_error_b then
                (
                    axis_b = if axis_a == #vertical then #horizontal else #vertical
                )
                else
                (
                    axis_a = if axis_b == #vertical then #horizontal else #vertical
                )
            )

            local vertical_neighbor = if axis_a == #vertical then point_a_world else point_b_world
            local horizontal_neighbor = if axis_a == #horizontal then point_a_world else point_b_world
            [vertical_neighbor.x, vertical_neighbor.y, horizontal_neighbor.z]
        )
        -- return
    ),

    /*
    Moves one current vertex to a world-space target at the active editing level.
    Edit Poly uses its native MoveSelection transform; Editable Poly writes the base vertex directly.
    */
    function move90AngleVertexToWorld node source_kind source_ref vert_index target_world =
    (
        if target_world == undefined then return false
        local inverse_tm = inverse node.objectTransform
        local target_local = target_world * inverse_tm

        if source_kind == #editPoly then
        (
            local current_local = get90AngleVertexPosition node source_kind source_ref vert_index
            if current_local == undefined then return false
            local current_world = current_local * node.objectTransform
            local move_delta = target_world - current_world
            local single_selection = #{}
            single_selection[vert_index] = true

            try
            (
                select node
                max modify mode
                modPanel.setCurrentObject source_ref
                source_ref.SetPrimaryNode node
                source_ref.useStackSelection = false
                source_ref.SetEPolySelLevel #Vertex
                subObjectLevel = 1
                source_ref.SetSelection #Vertex single_selection node:node
                source_ref.MoveSelection move_delta
                update node
                true
            )
            catch
            (
                false
            )
        )
        else
        (
            try
            (
                polyop.setVert source_ref #{vert_index} target_local
                update node
                true
            )
            catch
            (
                false
            )
        )
        -- return
    ),

    /*
    Corrects currently selected invalid border vertices at the active editing level.
    The selected vertex moves; its two border-neighbor reference vertices never move.
    */
    function fixSelected90BorderVerts angle_threshold:0.1 =
    (
        local selected_nodes = selection as array
        local active_edit_poly = undefined
        local processed_nodes = 0
        local total_fixed = 0
        last_slice_report = ""

        try
        (
            local current_object = modPanel.getCurrentObject()
            if current_object != undefined and classOf current_object == Edit_Poly then active_edit_poly = current_object
        )
        catch
        (
            active_edit_poly = undefined
        )

        undo "Wall-Fixer - Fix 90 Angles" on
        (
            for node in selected_nodes do
            (
                local source_data = getDoubleFaceSource node active_edit_poly
                if source_data != undefined then
                (
                    local source_kind = source_data[1]
                    local source_ref = source_data[2]
                    local selected_verts = get90AngleVertexSelection node source_kind source_ref
                    local original_selection = copy selected_verts
                    local border_edges = get90AngleOpenBorderEdges node source_kind source_ref

                    processed_nodes += 1
                    for vert_index in selected_verts do
                    (
                        local angle_value = get90AngleAtBorderVert node source_kind source_ref border_edges vert_index
                        if not(isValid90BorderAngle angle_value angle_threshold:angle_threshold) then
                        (
                            local target_world = get90AngleFixTarget node source_kind source_ref border_edges vert_index angle_threshold:angle_threshold
                            if target_world != undefined and move90AngleVertexToWorld node source_kind source_ref vert_index target_world then
                            (
                                total_fixed += 1
                            )
                        )
                    )

                    set90AngleVertexSelection node source_kind source_ref original_selection
                    update node
                )
            )
        )

        if processed_nodes == 0 then
        (
            last_slice_report = "CHECK 90° ANGLES RMB requires an Editable Poly base object or the current Edit Poly modifier."
            return false
        )

        last_slice_report = "CHECK 90° ANGLES: corrected selected border verts:" + (total_fixed as string) + "."
        if not batch_quiet then format "%\n" last_slice_report
        completeRedraw()
        true
        -- return
    ),

    /*
    CHECK 90° ANGLES entry point.
    LMB detects invalid border vertices; RMB corrects the currently selected invalid vertices.
    */
    function check90Angles angle_threshold:0.1 fix_selected:false =
    (
        local threshold_value = amax 0.0 (amin 45.0 angle_threshold)
        if fix_selected then fixSelected90BorderVerts angle_threshold:threshold_value
        else selectInvalid90BorderVerts angle_threshold:threshold_value
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
            messageBox "Wall-Fixer: Select at least one supported Editable Poly wall object."
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

            if not batch_quiet then format "TEST ANGLES: % selected\n" total_bad_verts
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
            messageBox "Wall-Fixer: Select at least one supported Editable Poly wall object."
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

            if not batch_quiet then format "FIND DOUBLE VERTS: % selected\n" total_double_verts
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

        undo "Wall-Fixer - Fix Border Angles" on
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
            messageBox "Wall-Fixer: Select at least one supported Editable Poly wall object."
            false
        )
        else
        (
            if horizontal_mode then
            (
                if use_high_z then
                (
                    if not batch_quiet then format "FIX ANGLES: Horizontal - Align RIGHT\n"
                )
                else
                (
                    if not batch_quiet then format "FIX ANGLES: Horizontal - Align LEFT\n"
                )
            )
            else
            (
                if use_high_z then
                (
                    if not batch_quiet then format "FIX ANGLES: Align TOP\n"
                )
                else
                (
                    if not batch_quiet then format "FIX ANGLES: Align BOTTOM\n"
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

        undo "Wall-Fixer - Fix Double Verts" on
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
            messageBox "Wall-Fixer: Select at least one supported Editable Poly wall object."
            false
        )
        else
        (
            if total_failed_pairs > 0 then
            (
                if not batch_quiet then format "FIX VERTS: % fixed | % unresolved\n" total_collapsed_pairs total_failed_pairs
            )
            else
            (
                if not batch_quiet then format "FIX VERTS: % fixed\n" total_collapsed_pairs
            )
            completeRedraw()
            true
        )
        -- return
    ),

    /*
    Initializes the Wall-Fixer struct instance.
    Persistent settings are loaded by the rollout after creation.
    */
    on create do
    (
    )
)

WallFixer = WallFixer_v()
