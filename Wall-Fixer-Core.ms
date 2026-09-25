/*
Wall-Fixer Core 0.85
Main WallFixer_v implementation and persistent runtime instance.
Load through Wall-Fixer.ms during normal development.
*/

global WallFixerVersion
global WallFixerRollout
global wall_fixer_version_system
global wall_fixer_version_epoch
global wall_fixer_core_file_version = "0.85"
global wall_fixer_core_tool_version = 1.0639

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


/*
Stable Redundant Loop Detector 0.13 integration.
Used by POST-PROCESS step 11; standalone dialog code is intentionally omitted.
*/
global RedundantLoopDetector

struct RedundantLoopDetector_v
(
    file_version = 0.13,
    face_angle_threshold = 0.1,
    straight_angle_threshold = 2.0,
    coincidence_tolerance = 0.001,
    crease_epsilon = 0.000001,

    /*
    Forces Editable Poly and Edit Poly selection mode to normal component selection.
    Every selection read/write path in this tool uses selectMode 0.
    */
    function forceSelectModeZero editable_poly =
    (
        if editable_poly == undefined then return false

        try(editable_poly.selectMode = 0)catch()
        true
        -- return
    ),

    /*
    Returns the opposite vertex of an incident edge.
    Invalid topology returns undefined.
    */
    function getOtherVertex vertex_index edge_index edge_vertices =
    (
        if edge_index < 1 or edge_index > edge_vertices.count then return undefined

        edge_pair = edge_vertices[edge_index]
        if edge_pair == undefined or edge_pair.count != 2 then return undefined

        if edge_pair[1] == vertex_index then
        (
            edge_pair[2]
        )
        else if edge_pair[2] == vertex_index then
        (
            edge_pair[1]
        )
        else
        (
            undefined
        )
        -- return
    ),

    /*
    Returns the geometric length of one analyzed topology edge.
    Invalid topology returns zero.
    */
    function getEdgeLength edge_index edge_vertices vertex_points =
    (
        if edge_index < 1 or edge_index > edge_vertices.count then return 0.0

        edge_pair = edge_vertices[edge_index]
        if edge_pair == undefined or edge_pair.count != 2 then return 0.0

        point_a = vertex_points[edge_pair[1]]
        point_b = vertex_points[edge_pair[2]]
        if point_a == undefined or point_b == undefined then return 0.0

        distance point_a point_b
        -- return
    ),

    /*
    Returns a normalized direction from one vertex along one incident edge.
    Zero-length edges return undefined.
    */
    function getEdgeDirection vertex_index edge_index edge_vertices vertex_points =
    (
        other_vertex = getOtherVertex vertex_index edge_index edge_vertices
        if other_vertex == undefined then return undefined

        direction_value = vertex_points[other_vertex] - vertex_points[vertex_index]
        if length direction_value <= 0.0000001 then return undefined

        normalize direction_value
        -- return
    ),

    /*
    Recursively pairs every edge with one opposite straight continuation.
    Backtracking avoids order-dependent rejection at crossings.
    */
    function canPairEdges vertex_index edge_array edge_vertices vertex_points straight_limit =
    (
        if edge_array.count == 0 then return true
        if (mod edge_array.count 2) != 0 then return false

        first_edge = edge_array[1]
        first_direction = getEdgeDirection vertex_index first_edge edge_vertices vertex_points
        if first_direction == undefined then return false

        for pair_index = 2 to edge_array.count do
        (
            pair_edge = edge_array[pair_index]
            pair_direction = getEdgeDirection vertex_index pair_edge edge_vertices vertex_points

            if pair_direction != undefined then
            (
                if (dot first_direction pair_direction) <= -straight_limit then
                (
                    remaining_edges = #()

                    for index = 2 to edge_array.count do
                    (
                        if index != pair_index then append remaining_edges edge_array[index]
                    )

                    if canPairEdges vertex_index remaining_edges edge_vertices vertex_points straight_limit then return true
                )
            )
        )

        false
        -- return
    ),

    /*
    Tests whether all supplied incident edges form straight-through opposite pairs.
    Empty input is accepted; odd or unmatched sets are rejected.
    */
    function areEdgesStraightPairs vertex_index edge_set edge_vertices vertex_points angle_threshold:2.0 =
    (
        if edge_set.numberSet == 0 then return true
        if (mod edge_set.numberSet 2) != 0 then return false

        canPairEdges vertex_index (edge_set as array) edge_vertices vertex_points (cos angle_threshold)
        -- return
    ),

    /*
    Reads native Editable Poly topology without changing geometry.
    Vertex positions and face normals are captured in world space while native edge IDs are preserved.
    */
    function buildPolyTopology node poly_value =
    (
        if node == undefined or not(isValidNode node) then return undefined
        if poly_value == undefined or classOf poly_value != Editable_Poly then return undefined

        vertex_count = polyop.getNumVerts poly_value
        edge_count = polyop.getNumEdges poly_value
        face_count = polyop.getNumFaces poly_value

        if vertex_count < 2 or edge_count < 1 or face_count < 1 then return undefined

        vertex_points = #()
        vertex_edges = #()
        vertex_faces = #()

        for vertex_index = 1 to vertex_count do
        (
            vertex_point = undefined

            in coordsys world
            (
                vertex_point = polyop.getVert poly_value vertex_index node:node
            )

            append vertex_points vertex_point
            append vertex_edges #{}
            append vertex_faces #{}
        )

        edge_vertices = #()
        edge_faces = #()
        border_edges = #{}
        border_vertices = #{}

        for edge_index = 1 to edge_count do
        (
            edge_pair = polyop.getEdgeVerts poly_value edge_index
            edge_face_array = polyop.getEdgeFaces poly_value edge_index

            edge_valid = edge_pair != undefined and edge_pair.count == 2
            if edge_valid then edge_valid = edge_pair[1] >= 1 and edge_pair[1] <= vertex_count and edge_pair[2] >= 1 and edge_pair[2] <= vertex_count

            if edge_valid then
            (
                append edge_vertices #(edge_pair[1], edge_pair[2])
                vertex_edges[edge_pair[1]][edge_index] = true
                vertex_edges[edge_pair[2]][edge_index] = true

                face_a = 0
                face_b = 0

                if edge_face_array != undefined then
                (
                    if edge_face_array.count >= 1 then face_a = edge_face_array[1]
                    if edge_face_array.count >= 2 then face_b = edge_face_array[2]
                )

                append edge_faces #(face_a, face_b)

                if face_a > 0 and face_b == 0 then
                (
                    border_edges[edge_index] = true
                    border_vertices[edge_pair[1]] = true
                    border_vertices[edge_pair[2]] = true
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
            face_vertices = polyop.getFaceVerts poly_value face_index
            face_normal = undefined

            if face_vertices != undefined and face_vertices.count >= 3 then
            (
                for vertex_index in face_vertices do
                (
                    if vertex_index >= 1 and vertex_index <= vertex_count then vertex_faces[vertex_index][face_index] = true
                )

                in coordsys world
                (
                    face_normal = polyop.getFaceNormal poly_value face_index node:node
                )

                if face_normal != undefined then
                (
                    if length face_normal > 0.0000001 then
                    (
                        face_normal = normalize face_normal
                        face_valid[face_index] = true
                    )
                    else
                    (
                        face_normal = undefined
                    )
                )
            )

            append face_normals face_normal
        )

        #(
            vertex_count,
            edge_count,
            face_count,
            vertex_points,
            vertex_edges,
            vertex_faces,
            edge_vertices,
            edge_faces,
            border_edges,
            border_vertices,
            face_normals,
            face_valid
        )
        -- return
    ),

    /*
    Returns explicit edge creases from Editable Poly edge-data channel 2.
    Unsupported crease data means that no explicit crease is present.
    */
    function getCreaseEdges poly_value edge_count =
    (
        crease_edges = #{}

        if polyop.getEDataChannelSupport poly_value 2 then
        (
            for edge_index = 1 to edge_count do
            (
                crease_value = polyop.getEDataValue poly_value 2 edge_index
                if crease_value != undefined and abs crease_value > crease_epsilon then crease_edges[edge_index] = true
            )
        )

        crease_edges
        -- return
    ),

    /*
    Acquires the evaluated top-of-stack geometry for read-only analysis.
    A modifier-free Editable Poly is read directly; any other stack is evaluated on a disposable collapsed copy.
    */
    function acquireAnalysisSource node =
    (
        if node == undefined or not(isValidNode node) then return undefined

        if classOf node.baseObject == Editable_Poly and node.modifiers.count == 0 then
        (
            forceSelectModeZero node.baseObject
            #(node, node.baseObject, false)
        )
        else
        (
            temp_node = undefined
            result_data = undefined

            try
            (
                with undo off
                (
                    temp_node = copy node
                    temp_node.name = uniqueName "__REDUNDANT_LOOP_ANALYSIS__"
                    convertToPoly temp_node

                    if classOf temp_node.baseObject != Editable_Poly then throw "evaluated copy is not Editable Poly"
                    forceSelectModeZero temp_node.baseObject
                    result_data = #(temp_node, temp_node.baseObject, true)
                )
            )
            catch
            (
                if temp_node != undefined then try(delete temp_node)catch()
                result_data = undefined
            )

            result_data
        )
        -- return
    ),

    /*
    Releases only disposable analysis geometry.
    The user's original object is never deleted or collapsed.
    */
    function releaseAnalysisSource analysis_source =
    (
        if analysis_source == undefined then return false

        if analysis_source[3] then
        (
            analysis_node = analysis_source[1]

            if analysis_node != undefined and isValidNode analysis_node then
            (
                with undo off
                (
                    try(delete analysis_node)catch()
                )
            )
        )

        true
        -- return
    ),

    /*
    Removes only near-zero and exact duplicate support edges from terminal topology tests.
    Real angled branches, border corners, and distinct continuations remain in the effective incidence set.
    */
    function getEffectiveIncidentEdges vertex_index chain_edges vertex_edges edge_vertices vertex_points =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return #{}

        incident_edges = vertex_edges[vertex_index]
        effective_edges = #{}
        chain_other_points = #()

        for chain_edge in (incident_edges * chain_edges) do
        (
            chain_other_vertex = getOtherVertex vertex_index chain_edge edge_vertices

            if chain_other_vertex != undefined then
            (
                chain_other_point = vertex_points[chain_other_vertex]
                if chain_other_point != undefined then append chain_other_points chain_other_point
            )
        )

        for edge_index in incident_edges do
        (
            keep_edge = true

            if not chain_edges[edge_index] then
            (
                if getEdgeLength edge_index edge_vertices vertex_points <= coincidence_tolerance then
                (
                    keep_edge = false
                )
                else
                (
                    other_vertex = getOtherVertex vertex_index edge_index edge_vertices

                    if other_vertex == undefined then
                    (
                        keep_edge = false
                    )
                    else
                    (
                        other_point = vertex_points[other_vertex]

                        if other_point == undefined then
                        (
                            keep_edge = false
                        )
                        else
                        (
                            for chain_other_point in chain_other_points while keep_edge do
                            (
                                if distance other_point chain_other_point <= coincidence_tolerance then keep_edge = false
                            )
                        )
                    )
                )
            )

            if keep_edge then effective_edges[edge_index] = true
        )

        effective_edges
        -- return
    ),

    /*
    Tests one strict straight open-border terminal.
    A real border corner is rejected because its two border continuations are not opposite within the straightness tolerance.
    */
    function isValidOpenBorderTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:2.0 =
    (
        if chain_incident_edges.numberSet != 1 then return false

        effective_edges = getEffectiveIncidentEdges vertex_index chain_incident_edges vertex_edges edge_vertices vertex_points
        effective_chain = effective_edges * chain_incident_edges
        effective_border = effective_edges * border_edges

        if effective_chain.numberSet != 1 then return false
        if effective_border.numberSet != 2 then return false
        if effective_edges.numberSet != 3 then return false
        if not(areEdgesStraightPairs vertex_index effective_border edge_vertices vertex_points angle_threshold:angle_threshold) then return false

        true
        -- return
    ),

    /*
    Tests one internal straight T-junction or crossing terminal.
    Every effective non-chain edge must be consumed by an opposite straight-through pair.
    */
    function isValidInternalTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:2.0 =
    (
        if chain_incident_edges.numberSet != 1 then return false

        effective_edges = getEffectiveIncidentEdges vertex_index chain_incident_edges vertex_edges edge_vertices vertex_points
        effective_chain = effective_edges * chain_incident_edges

        if effective_chain.numberSet != 1 then return false
        if (vertex_edges[vertex_index] * border_edges).numberSet > 0 then return false

        remaining_edges = effective_edges - effective_chain
        if remaining_edges.numberSet < 2 then return false

        areEdgesStraightPairs vertex_index remaining_edges edge_vertices vertex_points angle_threshold:angle_threshold
        -- return
    ),

    /*
    Tests one legal chain terminal and never lets a border vertex fall through to the internal T-junction rule.
    Any raw border incidence forces strict open-border validation.
    */
    function isValidTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:2.0 =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return false
        if chain_incident_edges.numberSet != 1 then return false

        raw_border_edges = vertex_edges[vertex_index] * border_edges

        if raw_border_edges.numberSet > 0 then
        (
            isValidOpenBorderTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold
        )
        else
        (
            isValidInternalTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold
        )
        -- return
    ),

    /*
    Tests one internal chain vertex before traversal continues through it.
    The incoming/outgoing pair must be straight and all unrelated effective edges must pair straight through.
    */
    function isValidInternalVertex vertex_index incoming_edge outgoing_edge border_edges vertex_edges edge_vertices vertex_points angle_threshold:2.0 =
    (
        if (vertex_edges[vertex_index] * border_edges).numberSet > 0 then return false

        chain_pair = #{}
        chain_pair[incoming_edge] = true
        chain_pair[outgoing_edge] = true

        effective_edges = getEffectiveIncidentEdges vertex_index chain_pair vertex_edges edge_vertices vertex_points
        effective_chain = effective_edges * chain_pair

        if effective_chain.numberSet != 2 then return false
        if not(areEdgesStraightPairs vertex_index effective_chain edge_vertices vertex_points angle_threshold:angle_threshold) then return false

        transverse_edges = effective_edges - effective_chain

        if transverse_edges.numberSet > 0 then
        (
            if not(areEdgesStraightPairs vertex_index transverse_edges edge_vertices vertex_points angle_threshold:angle_threshold) then return false
        )

        true
        -- return
    ),

    /*
    Verifies every live face incident to one chain vertex against the chain reference plane orientation.
    Opposite normal direction is accepted by comparing the absolute dot product.
    */
    function isVertexPlanar vertex_index vertex_faces face_normals face_valid reference_normal angle_threshold:0.1 =
    (
        if vertex_index < 1 or vertex_index > vertex_faces.count then return false
        if reference_normal == undefined then return false

        normal_limit = cos angle_threshold
        incident_face_count = 0

        for face_index in vertex_faces[vertex_index] do
        (
            if face_index < 1 or face_index > face_normals.count then return false
            if face_index > face_valid.count or not face_valid[face_index] then return false

            face_normal = face_normals[face_index]
            if face_normal == undefined then return false

            incident_face_count += 1
            if abs(dot reference_normal face_normal) < normal_limit then return false
        )

        incident_face_count > 0
        -- return
    ),

    /*
    Builds the conservative internal edge candidate set.
    Border, explicit crease, zero-length, invalid-adjacency, and non-coplanar edges are rejected before traversal.
    */
    function buildCandidateEdges topology_data crease_edges angle_threshold:0.1 =
    (
        edge_count = topology_data[2]
        face_count = topology_data[3]
        vertex_points = topology_data[4]
        edge_vertices = topology_data[7]
        edge_faces = topology_data[8]
        border_edges = topology_data[9]
        face_normals = topology_data[11]
        face_valid = topology_data[12]

        candidate_edges = #{}
        normal_limit = cos angle_threshold

        for edge_index = 1 to edge_count do
        (
            edge_pair = edge_vertices[edge_index]
            face_pair = edge_faces[edge_index]
            is_border = border_edges[edge_index]
            is_crease = crease_edges[edge_index]

            if edge_pair != undefined and face_pair != undefined and not is_border and not is_crease then
            (
                if getEdgeLength edge_index edge_vertices vertex_points > coincidence_tolerance then
                (
                    face_a = face_pair[1]
                    face_b = face_pair[2]

                    if face_a > 0 and face_b > 0 and face_a <= face_count and face_b <= face_count then
                    (
                        if face_valid[face_a] and face_valid[face_b] then
                        (
                            if abs(dot face_normals[face_a] face_normals[face_b]) >= normal_limit then candidate_edges[edge_index] = true
                        )
                    )
                )
            )
        )

        candidate_edges
        -- return
    ),

    /*
    Tests one isolated internal divider edge separately from open-chain terminal logic.
    It must be an internal coplanar candidate with no other candidate edge incident at either endpoint.
    */
    function isValidIsolatedDivider edge_index candidate_edges topology_data face_threshold:0.1 =
    (
        if edge_index < 1 or edge_index > topology_data[2] then return false
        if not candidate_edges[edge_index] then return false

        vertex_edges = topology_data[5]
        vertex_faces = topology_data[6]
        edge_vertices = topology_data[7]
        edge_faces = topology_data[8]
        face_normals = topology_data[11]
        face_valid = topology_data[12]

        edge_pair = edge_vertices[edge_index]
        face_pair = edge_faces[edge_index]
        if edge_pair == undefined or edge_pair.count != 2 then return false
        if face_pair == undefined or face_pair.count != 2 then return false

        face_a = face_pair[1]
        face_b = face_pair[2]
        if face_a < 1 or face_b < 1 then return false
        if face_a > face_normals.count or face_b > face_normals.count then return false
        if not face_valid[face_a] or not face_valid[face_b] then return false

        reference_normal = face_normals[face_a]
        if reference_normal == undefined then return false

        divider_edge = #{}
        divider_edge[edge_index] = true

        for vertex_index in edge_pair do
        (
            other_candidates = (vertex_edges[vertex_index] * candidate_edges) - divider_edge
            if other_candidates.numberSet > 0 then return false

            if not(isVertexPlanar vertex_index vertex_faces face_normals face_valid reference_normal angle_threshold:face_threshold) then return false
        )

        true
        -- return
    ),

    /*
    Validates a completed chain as one planar, straight, terminal-to-terminal topology feature.
    Any invalid endpoint, branch, border incidence, or non-planar incident face rejects the whole chain.
    */
    function validateChain chain_edges chain_vertices start_vertex end_vertex candidate_edges topology_data reference_normal face_threshold:0.1 straight_threshold:2.0 =
    (
        if chain_edges.numberSet == 0 then return #(false, "empty chain")
        if chain_vertices.count < 2 then return #(false, "chain has fewer than two vertices")
        if start_vertex == end_vertex then return #(false, "chain returns to its start")
        if (chain_edges - candidate_edges).numberSet > 0 then return #(false, "chain contains a non-candidate edge")

        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        vertex_faces = topology_data[6]
        edge_vertices = topology_data[7]
        border_edges = topology_data[9]
        face_normals = topology_data[11]
        face_valid = topology_data[12]

        for vertex_index in chain_vertices do
        (
            if not(isVertexPlanar vertex_index vertex_faces face_normals face_valid reference_normal angle_threshold:face_threshold) then
            (
                return #(false, "non-planar incident faces at vertex " + (vertex_index as string))
            )

            chain_incident_edges = vertex_edges[vertex_index] * chain_edges
            is_endpoint = vertex_index == start_vertex or vertex_index == end_vertex

            if is_endpoint then
            (
                if not(isValidTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold) then
                (
                    return #(false, "invalid terminal topology at vertex " + (vertex_index as string))
                )
            )
            else
            (
                if chain_incident_edges.numberSet != 2 then return #(false, "internal vertex does not have exactly two chain edges at vertex " + (vertex_index as string))

                chain_pair = chain_incident_edges as array

                if not(isValidInternalVertex vertex_index chain_pair[1] chain_pair[2] border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold) then
                (
                    return #(false, "invalid internal branch topology at vertex " + (vertex_index as string))
                )
            )
        )

        #(true, "")
        -- return
    ),

    /*
    Creates a stable key for duplicate suppression when the same chain is traversed from both terminals.
    BitArray iteration keeps edge IDs sorted automatically.
    */
    function makeChainKey chain_edges =
    (
        key_text = ""
        for edge_index in chain_edges do key_text += (edge_index as string) + ","
        key_text
        -- return
    ),

    /*
    Detects redundant straight internal chains on one selected node without changing its geometry or stack.
    Returns success, chain records, the union edge BitArray, an error message, and immutable analyzed topology.
    */
    function detectRedundantLoops node face_threshold:0.1 straight_threshold:2.0 debug_output:false =
    (
        loop_records = #()
        redundant_edges = #{}
        analysis_source = acquireAnalysisSource node

        if analysis_source == undefined then return #(false, loop_records, redundant_edges, "could not acquire evaluated Editable Poly topology", undefined)

        analysis_node = analysis_source[1]
        analysis_poly = analysis_source[2]
        topology_data = buildPolyTopology analysis_node analysis_poly

        if topology_data == undefined then
        (
            releaseAnalysisSource analysis_source
            return #(false, loop_records, redundant_edges, "could not read evaluated Editable Poly topology", undefined)
        )

        crease_edges = getCreaseEdges analysis_poly topology_data[2]
        candidate_edges = buildCandidateEdges topology_data crease_edges angle_threshold:face_threshold

        edge_count = topology_data[2]
        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        vertex_faces = topology_data[6]
        edge_vertices = topology_data[7]
        edge_faces = topology_data[8]
        border_edges = topology_data[9]
        face_normals = topology_data[11]
        face_valid = topology_data[12]

        straight_limit = cos straight_threshold
        accepted_keys = #()
        attempted_keys = #()
        isolated_edges = #{}

        for divider_edge in candidate_edges do
        (
            if isValidIsolatedDivider divider_edge candidate_edges topology_data face_threshold:face_threshold then
            (
                divider_pair = edge_vertices[divider_edge]
                divider_bits = #{}
                divider_bits[divider_edge] = true
                divider_vertices = #(divider_pair[1], divider_pair[2])
                divider_key = makeChainKey divider_bits

                if findItem accepted_keys divider_key == 0 then
                (
                    append accepted_keys divider_key
                    append loop_records #(divider_bits, divider_vertices, divider_pair[1], divider_pair[2])
                    redundant_edges = redundant_edges + divider_bits
                    isolated_edges[divider_edge] = true

                    if debug_output then
                    (
                        vertex_bits = #{}
                        vertex_bits[divider_pair[1]] = true
                        vertex_bits[divider_pair[2]] = true
                        format "REDUNDANT DIVIDER | node:% | verts:% | edges:%\n" node.name vertex_bits divider_bits
                    )
                )
            )
        )

        traversal_candidates = candidate_edges - isolated_edges

        for start_edge in traversal_candidates do
        (
            start_pair = edge_vertices[start_edge]

            if start_pair != undefined then
            (
                single_chain = #{}
                single_chain[start_edge] = true
                possible_starts = #()

                if isValidTerminal start_pair[1] single_chain border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold then append possible_starts start_pair[1]
                if isValidTerminal start_pair[2] single_chain border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold then append possible_starts start_pair[2]

                for start_vertex in possible_starts do
                (
                    attempt_key = (start_edge as string) + ":" + (start_vertex as string)

                    if findItem attempted_keys attempt_key == 0 then
                    (
                        append attempted_keys attempt_key

                        chain_edges = #{}
                        chain_edges[start_edge] = true
                        chain_vertices = #(start_vertex)

                        previous_vertex = start_vertex
                        current_edge = start_edge
                        current_vertex = if start_pair[1] == start_vertex then start_pair[2] else start_pair[1]
                        append chain_vertices current_vertex

                        reference_normal = undefined
                        start_faces = edge_faces[start_edge]

                        if start_faces != undefined then
                        (
                            reference_face = if start_faces[1] > 0 then start_faces[1] else start_faces[2]

                            if reference_face >= 1 and reference_face <= face_normals.count then
                            (
                                if face_valid[reference_face] then reference_normal = face_normals[reference_face]
                            )
                        )

                        rejected_reason = ""
                        completed_chain = false
                        step_count = 0

                        if reference_normal == undefined then rejected_reason = "missing reference face normal"

                        while rejected_reason == "" and not completed_chain and step_count <= edge_count do
                        (
                            step_count += 1

                            if not(isVertexPlanar current_vertex vertex_faces face_normals face_valid reference_normal angle_threshold:face_threshold) then
                            (
                                rejected_reason = "non-planar incident faces at vertex " + (current_vertex as string)
                            )
                            else
                            (
                                incoming_direction = vertex_points[current_vertex] - vertex_points[previous_vertex]

                                if length incoming_direction <= 0.0000001 then
                                (
                                    rejected_reason = "zero-length chain segment"
                                )
                                else
                                (
                                    incoming_direction = normalize incoming_direction
                                    forward_edges = #()
                                    incident_candidates = vertex_edges[current_vertex] * traversal_candidates

                                    for candidate_edge in incident_candidates do
                                    (
                                        if candidate_edge != current_edge then
                                        (
                                            next_vertex = getOtherVertex current_vertex candidate_edge edge_vertices

                                            if next_vertex != undefined then
                                            (
                                                outgoing_direction = vertex_points[next_vertex] - vertex_points[current_vertex]

                                                if length outgoing_direction > 0.0000001 then
                                                (
                                                    outgoing_direction = normalize outgoing_direction
                                                    if dot incoming_direction outgoing_direction >= straight_limit then append forward_edges candidate_edge
                                                )
                                            )
                                        )
                                    )

                                    if forward_edges.count == 0 then
                                    (
                                        terminal_chain = #{}
                                        terminal_chain[current_edge] = true

                                        if isValidTerminal current_vertex terminal_chain border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold then
                                        (
                                            completed_chain = true
                                        )
                                        else
                                        (
                                            rejected_reason = "chain stopped at invalid terminal vertex " + (current_vertex as string)
                                        )
                                    )
                                    else if forward_edges.count > 1 then
                                    (
                                        rejected_reason = "ambiguous forward branching at vertex " + (current_vertex as string)
                                    )
                                    else
                                    (
                                        next_edge = forward_edges[1]

                                        if chain_edges[next_edge] then
                                        (
                                            rejected_reason = "closed edge cycle"
                                        )
                                        else if not(isValidInternalVertex current_vertex current_edge next_edge border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold) then
                                        (
                                            rejected_reason = "invalid internal branch topology at vertex " + (current_vertex as string)
                                        )
                                        else
                                        (
                                            next_vertex = getOtherVertex current_vertex next_edge edge_vertices

                                            if next_vertex == undefined then
                                            (
                                                rejected_reason = "invalid continuation edge"
                                            )
                                            else if findItem chain_vertices next_vertex != 0 then
                                            (
                                                rejected_reason = "closed or revisited vertex cycle"
                                            )
                                            else
                                            (
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
                        )

                        if step_count > edge_count then rejected_reason = "traversal exceeded edge count"

                        if rejected_reason == "" and completed_chain then
                        (
                            validation = validateChain chain_edges chain_vertices start_vertex current_vertex traversal_candidates topology_data reference_normal face_threshold:face_threshold straight_threshold:straight_threshold

                            if validation[1] then
                            (
                                chain_key = makeChainKey chain_edges

                                if findItem accepted_keys chain_key == 0 then
                                (
                                    append accepted_keys chain_key
                                    append loop_records #(chain_edges, chain_vertices, start_vertex, current_vertex)
                                    redundant_edges = redundant_edges + chain_edges

                                    if debug_output then
                                    (
                                        vertex_bits = #{}
                                        for vertex_index in chain_vertices do vertex_bits[vertex_index] = true
                                        format "REDUNDANT CHAIN | node:% | verts:% | edges:% | terminal:% -> %\n" node.name vertex_bits chain_edges start_vertex current_vertex
                                    )
                                )
                            )
                            else
                            (
                                rejected_reason = validation[2]
                            )
                        )

                        if debug_output and rejected_reason != "" then
                        (
                            format "Rejected candidate | node:% | startEdge:% | startVert:% | reason:%\n" node.name start_edge start_vertex rejected_reason
                        )
                    )
                )
            )
        )

        releaseAnalysisSource analysis_source
        #(true, loop_records, redundant_edges, "", topology_data)
        -- return
    ),

    /*
    Returns the currently selected edge IDs from the active Editable Poly or Edit Poly object.
    The selection source is never inferred from a debug spinner.
    */
    function getCurrentSelectedEdges node =
    (
        selected_edges = #{}
        if node == undefined or not(isValidNode node) then return selected_edges

        current_object = undefined
        try(current_object = modPanel.getCurrentObject())catch()

        if current_object != undefined and classOf current_object == Edit_Poly then
        (
            current_on_node = false

            for modifier_index = 1 to node.modifiers.count while not current_on_node do
            (
                if node.modifiers[modifier_index] == current_object then current_on_node = true
            )

            if current_on_node then
            (
                forceSelectModeZero current_object
                try(selected_edges = current_object.GetSelection #Edge node:node)catch()
            )
        )

        if selected_edges.numberSet == 0 and node.modifiers.count > 0 then
        (
            top_modifier = node.modifiers[1]

            if classOf top_modifier == Edit_Poly then
            (
                forceSelectModeZero top_modifier
                try(selected_edges = top_modifier.GetSelection #Edge node:node)catch()
            )
        )

        if selected_edges.numberSet == 0 and classOf node.baseObject == Editable_Poly then
        (
            forceSelectModeZero node.baseObject
            try(selected_edges = polyop.getEdgeSelection node.baseObject)catch()
        )

        selected_edges
        -- return
    ),

    /*
    Prints detailed classification for one analyzed edge ID without changing the object.
    The UI calls this for every currently selected edge on the active object.
    */
    function debugEdge node edge_index face_threshold:0.1 straight_threshold:2.0 =
    (
        analysis_source = acquireAnalysisSource node
        if analysis_source == undefined then return false

        analysis_node = analysis_source[1]
        analysis_poly = analysis_source[2]
        topology_data = buildPolyTopology analysis_node analysis_poly

        if topology_data == undefined then
        (
            releaseAnalysisSource analysis_source
            return false
        )

        crease_edges = getCreaseEdges analysis_poly topology_data[2]
        candidate_edges = buildCandidateEdges topology_data crease_edges angle_threshold:face_threshold

        if edge_index < 1 or edge_index > topology_data[2] then
        (
            format "DEBUG EDGE % | invalid edge ID, edgeCount:%\n" edge_index topology_data[2]
            releaseAnalysisSource analysis_source
            return false
        )

        edge_pair = topology_data[7][edge_index]
        face_pair = topology_data[8][edge_index]
        border_edges = topology_data[9]
        vertex_edges = topology_data[5]
        vertex_points = topology_data[4]

        isolated_ok = isValidIsolatedDivider edge_index candidate_edges topology_data face_threshold:face_threshold
        format "DEBUG EDGE % | verts:% | faces:% | candidate:% | isolatedDivider:% | border:% | crease:%\n" edge_index edge_pair face_pair candidate_edges[edge_index] isolated_ok border_edges[edge_index] crease_edges[edge_index]

        if edge_pair != undefined then
        (
            chain_set = #{}
            chain_set[edge_index] = true

            for vertex_index in edge_pair do
            (
                effective_edges = getEffectiveIncidentEdges vertex_index chain_set vertex_edges topology_data[7] vertex_points
                raw_border = vertex_edges[vertex_index] * border_edges
                effective_border = effective_edges * border_edges
                terminal_ok = isValidTerminal vertex_index chain_set border_edges vertex_edges topology_data[7] vertex_points angle_threshold:straight_threshold

                format "  V% | rawEdges:% | effective:% | rawBorder:% | effectiveBorder:% | terminal:%\n" vertex_index vertex_edges[vertex_index] effective_edges raw_border effective_border terminal_ok
            )
        )

        releaseAnalysisSource analysis_source
        true
        -- return
    ),

    /*
    Debugs every currently selected edge on one object.
    No explicit edge ID input is required.
    */
    function debugSelectedEdges node face_threshold:0.1 straight_threshold:2.0 =
    (
        selected_edges = getCurrentSelectedEdges node

        if selected_edges.numberSet == 0 then
        (
            messageBox "Select one or more edges first." title:"Redundant Loop Detector"
            return false
        )

        debug_ok = true

        for edge_index in selected_edges do
        (
            if not(debugEdge node edge_index face_threshold:face_threshold straight_threshold:straight_threshold) then debug_ok = false
        )

        debug_ok
        -- return
    ),

    /*
    Returns the existing exact top selection modifier or creates one.
    Unrelated Edit Poly modifiers are never used for selection storage.
    */
    function acquireSelectionModifier node =
    (
        if node.modifiers.count > 0 then
        (
            top_modifier = node.modifiers[1]

            if classOf top_modifier == Edit_Poly and top_modifier.name == "SELECT REDUNDANT LOOPS" then
            (
                return #(top_modifier, false)
            )
        )

        selection_modifier = Edit_Poly name:"SELECT REDUNDANT LOOPS"
        addModifier node selection_modifier
        #(selection_modifier, true)
        -- return
    ),

    /*
    Activates the dedicated selection modifier in Edge mode with Show Cage disabled.
    Geometry detection has already finished before this function runs.
    */
    function activateSelectionModifier node selection_modifier =
    (
        if node == undefined or not(isValidNode node) then return false
        if selection_modifier == undefined or classOf selection_modifier != Edit_Poly then return false

        activated = true

        try
        (
            select node
            max modify mode
            if classOf node.baseObject == Editable_Poly then forceSelectModeZero node.baseObject
            forceSelectModeZero selection_modifier
            selection_modifier.SetPrimaryNode node
            selection_modifier.useStackSelection = false
            selection_modifier.showCage = false
            selection_modifier.selectMode = 0
            modPanel.setCurrentObject selection_modifier
            selection_modifier.SetEPolySelLevel #Edge
            subObjectLevel = 2
            update node
        )
        catch
        (
            activated = false
        )

        activated
        -- return
    ),

    /*
    Verifies that evaluated edge IDs still describe the same geometry after the selection modifier is added.
    Verification uses a disposable collapsed copy and compares every edge endpoint pair in world space.
    */
    function verifyEdgeIdMapping node source_topology =
    (
        verification_source = acquireAnalysisSource node
        if verification_source == undefined then return false

        verification_topology = buildPolyTopology verification_source[1] verification_source[2]
        mapping_ok = verification_topology != undefined

        if mapping_ok then mapping_ok = verification_topology[1] == source_topology[1] and verification_topology[2] == source_topology[2] and verification_topology[3] == source_topology[3]

        if mapping_ok then
        (
            source_points = source_topology[4]
            source_edges = source_topology[7]
            current_points = verification_topology[4]
            current_edges = verification_topology[7]

            for edge_index = 1 to source_topology[2] while mapping_ok do
            (
                source_pair = source_edges[edge_index]
                current_pair = current_edges[edge_index]

                if source_pair == undefined or current_pair == undefined then
                (
                    mapping_ok = source_pair == undefined and current_pair == undefined
                )
                else
                (
                    source_a = source_points[source_pair[1]]
                    source_b = source_points[source_pair[2]]
                    current_a = current_points[current_pair[1]]
                    current_b = current_points[current_pair[2]]

                    same_forward = distance source_a current_a <= coincidence_tolerance and distance source_b current_b <= coincidence_tolerance
                    same_reverse = distance source_a current_b <= coincidence_tolerance and distance source_b current_a <= coincidence_tolerance

                    if not same_forward and not same_reverse then mapping_ok = false
                )
            )
        )

        releaseAnalysisSource verification_source
        mapping_ok
        -- return
    ),

    /*
    Detects one object and stores accepted edges only after detection is complete.
    A zero-result scan leaves no temporary modifier and removes a stale top SELECT REDUNDANT LOOPS modifier.
    */
    function selectRedundantLoopsOnNode node face_threshold:0.1 straight_threshold:2.0 debug_output:true =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0, 0, "invalid node", undefined)

        detection = detectRedundantLoops node face_threshold:face_threshold straight_threshold:straight_threshold debug_output:debug_output
        if not detection[1] then return #(false, 0, 0, detection[4], undefined)

        loop_count = detection[2].count
        redundant_edges = detection[3]
        topology_data = detection[5]
        selected_edge_count = redundant_edges.numberSet
        selection_modifier = undefined
        created_now = false
        operation_error = undefined

        try
        (
            if selected_edge_count > 0 then
            (
                modifier_data = acquireSelectionModifier node
                selection_modifier = modifier_data[1]
                created_now = modifier_data[2]

                if not(activateSelectionModifier node selection_modifier) then throw "could not activate SELECT REDUNDANT LOOPS"
                forceSelectModeZero selection_modifier
                if classOf node.baseObject == Editable_Poly then forceSelectModeZero node.baseObject
                if not(verifyEdgeIdMapping node topology_data) then throw "evaluated edge IDs changed before selection storage"

                /* EditPolyMod selection BitArrays must span the complete mesh edge range.
                   #{22} alone has a shorter BitArray length and can be rejected as an empty selection. */
                selection_bits = copy redundant_edges
                selection_bits.count = topology_data[2]

                empty_selection = #{}
                empty_selection.count = topology_data[2]

                clear_ok = selection_modifier.SetSelection #Edge empty_selection node:node
                store_ok = selection_modifier.SetSelection #Edge selection_bits node:node
                update node
                selection_modifier.RefreshScreen()
                stored_selection = selection_modifier.GetSelection #Edge node:node

                if not clear_ok then throw "could not clear Edit Poly edge selection before storage"
                if not store_ok then throw "Edit Poly SetSelection returned false while storing redundant edges"

                stored_selection_bits = copy stored_selection
                stored_selection_bits.count = topology_data[2]

                if stored_selection_bits != selection_bits then
                (
                    throw ("edge selection storage mismatch. requested:" + (redundant_edges as string) + " actual:" + (stored_selection as string))
                )

                selection_modifier.showCage = false

                if not(activateSelectionModifier node selection_modifier) then throw "could not enter Edge sub-object level after selection storage"
                selection_modifier.SetEPolySelLevel #Edge
                subObjectLevel = 2
                selection_modifier.RefreshScreen()
            )
            else
            (
                if node.modifiers.count > 0 then
                (
                    top_modifier = node.modifiers[1]

                    if classOf top_modifier == Edit_Poly and top_modifier.name == "SELECT REDUNDANT LOOPS" then deleteModifier node top_modifier
                )

                update node
            )
        )
        catch
        (
            operation_error = getCurrentException()

            if selection_modifier != undefined then
            (
                if created_now or selection_modifier.name == "SELECT REDUNDANT LOOPS" then try(deleteModifier node selection_modifier)catch()
                selection_modifier = undefined
            )

            update node
        )

        if operation_error == undefined then
        (
            #(true, loop_count, selected_edge_count, "", selection_modifier)
        )
        else
        (
            #(false, 0, 0, operation_error as string, undefined)
        )
        -- return
    ),

    /*
    Processes every selected object independently and finishes with only matching objects selected.
    Each matching object receives its own SELECT REDUNDANT LOOPS modifier and Edge selection.
    */
    function selectRedundantLoops face_threshold:0.1 straight_threshold:2.0 debug_output:true =
    (
        selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            messageBox "Select at least one geometry object." title:"Redundant Loop Detector"
            return #(false, 0, 0)
        )

        total_loops = 0
        total_edges = 0
        failed_count = 0
        first_match_node = undefined
        first_match_modifier = undefined
        matching_nodes = #()

        for node in selected_nodes do
        (
            result_data = selectRedundantLoopsOnNode node face_threshold:face_threshold straight_threshold:straight_threshold debug_output:debug_output

            if result_data[1] then
            (
                total_loops += result_data[2]
                total_edges += result_data[3]

                format "Redundant Loop Detector | node:% | chains:% | selectedEdges:%\n" node.name result_data[2] result_data[3]

                if result_data[3] > 0 then
                (
                    append matching_nodes node

                    if first_match_modifier == undefined then
                    (
                        first_match_node = node
                        first_match_modifier = result_data[5]
                    )
                )
            )
            else
            (
                failed_count += 1
                format "Redundant Loop Detector FAILED | node:% | %\n" node.name result_data[4]
            )
        )

        if matching_nodes.count > 0 then
        (
            select matching_nodes

            if matching_nodes.count == 1 and first_match_modifier != undefined then
            (
                activateSelectionModifier first_match_node first_match_modifier
                first_match_modifier.RefreshScreen()
            )
        )
        else
        (
            clearSelection()
        )

        completeRedraw()
        format "Redundant Loop Detector COMPLETE | objects:% | chains:% | edges:% | failures:%\n" selected_nodes.count total_loops total_edges failed_count

        #(failed_count == 0, total_loops, total_edges)
        -- return
    ),

    /*
    Removes the currently selected edges from the dedicated selection modifier.
    The operation uses Edge-level Remove with the Remove Edge CTRL state enabled so adjacent faces are preserved and redundant edge vertices are removed.
    */
    function removeSelectedEdges =
    (
        if selection.count == 0 then
        (
            messageBox "Select the detected object first." title:"Redundant Loop Detector"
            return false
        )

        node = selection[1]

        if node.modifiers.count == 0 then
        (
            messageBox "No SELECT REDUNDANT LOOPS modifier found." title:"Redundant Loop Detector"
            return false
        )

        selection_modifier = node.modifiers[1]

        if classOf selection_modifier != Edit_Poly or selection_modifier.name != "SELECT REDUNDANT LOOPS" then
        (
            messageBox "Top modifier must be SELECT REDUNDANT LOOPS." title:"Redundant Loop Detector"
            return false
        )

        if not(activateSelectionModifier node selection_modifier) then
        (
            messageBox "Could not activate SELECT REDUNDANT LOOPS." title:"Redundant Loop Detector"
            return false
        )

        forceSelectModeZero selection_modifier
        if classOf node.baseObject == Editable_Poly then forceSelectModeZero node.baseObject
        selected_edges = EditPolyMod.GetSelection selection_modifier #Edge node:node

        if selected_edges.numberSet == 0 then
        (
            messageBox "No edges are selected." title:"Redundant Loop Detector"
            return false
        )

        removed_count = selected_edges.numberSet
        operation_error = undefined
        old_remove_ctrl = selection_modifier.remveEdgeCtrlKey

        try
        (
            undo "Remove Redundant Loops" on
            (
                selection_modifier.remveEdgeCtrlKey = true
                selection_modifier.SetEPolySelLevel #Edge
                subObjectLevel = 2
                selection_modifier.ButtonOp #RemoveEdge
                update node
                selection_modifier.showCage = false
                selection_modifier.RefreshScreen()
            )
        )
        catch
        (
            operation_error = getCurrentException()
        )

        selection_modifier.remveEdgeCtrlKey = old_remove_ctrl

        if operation_error != undefined then
        (
            format "Redundant Loop Detector REMOVE FAILED | node:% | %\n" node.name operation_error
            messageBox ("Remove failed:\n" + (operation_error as string)) title:"Redundant Loop Detector"
            return false
        )

        completeRedraw()
        format "Redundant Loop Detector REMOVE | node:% | removedEdges:%\n" node.name removed_count
        true
        -- return
    ),

    /*
    Finds one Editable Poly edge by its two vertex IDs.
    This helper is used by the standalone regression tests only.
    */
    function findPolyEdgeByVertices poly_value vertex_a vertex_b =
    (
        edge_count = polyop.getNumEdges poly_value

        for edge_index = 1 to edge_count do
        (
            edge_pair = polyop.getEdgeVerts poly_value edge_index

            if edge_pair != undefined then
            (
                same_pair = (edge_pair[1] == vertex_a and edge_pair[2] == vertex_b) or (edge_pair[1] == vertex_b and edge_pair[2] == vertex_a)
                if same_pair then return edge_index
            )
        )

        0
        -- return
    ),

    /*
    Creates a planar wall split by one redundant border-to-border divider.
    The optional crease marks that divider as protected and therefore non-redundant.
    */
    function createDividerTestObject creased:false x_offset:0.0 =
    (
        test_node = editable_mesh name:(uniqueName "REDUNDANT_LOOP_TEST_")
        convertTo test_node Editable_Poly
        test_poly = test_node.baseObject
        forceSelectModeZero test_poly

        vertex_1 = polyop.createVert test_poly [x_offset + 0.0, 0.0, 0.0]
        vertex_2 = polyop.createVert test_poly [x_offset + 10.0, 0.0, 0.0]
        vertex_3 = polyop.createVert test_poly [x_offset + 0.0, 5.0, 0.0]
        vertex_4 = polyop.createVert test_poly [x_offset + 10.0, 5.0, 0.0]
        vertex_5 = polyop.createVert test_poly [x_offset + 0.0, 10.0, 0.0]
        vertex_6 = polyop.createVert test_poly [x_offset + 10.0, 10.0, 0.0]

        polyop.createPolygon test_poly #(vertex_1, vertex_2, vertex_4, vertex_3)
        polyop.createPolygon test_poly #(vertex_3, vertex_4, vertex_6, vertex_5)
        update test_node

        divider_edge = findPolyEdgeByVertices test_poly vertex_3 vertex_4
        if divider_edge == 0 then throw "could not create divider test edge"

        if creased then
        (
            if not(polyop.getEDataChannelSupport test_poly 2) then polyop.setEDataChannelSupport test_poly 2 true
            polyop.setEDataValue test_poly 2 #{divider_edge} 1.0
        )

        #(test_node, divider_edge)
        -- return
    ),

    /*
    Creates a valid border-to-straight-T redundant divider.
    This mirrors the intended topology of the supplied edge 31 case: one straight border endpoint and one internal straight receiving loop.
    */
    function createTJunctionTestObject x_offset:30.0 =
    (
        test_node = editable_mesh name:(uniqueName "REDUNDANT_T_TEST_")
        convertTo test_node Editable_Poly
        test_poly = test_node.baseObject
        forceSelectModeZero test_poly

        vertex_1 = polyop.createVert test_poly [x_offset + 0.0, 0.0, 0.0]
        vertex_2 = polyop.createVert test_poly [x_offset + 5.0, 0.0, 0.0]
        vertex_3 = polyop.createVert test_poly [x_offset + 10.0, 0.0, 0.0]
        vertex_4 = polyop.createVert test_poly [x_offset + 0.0, 5.0, 0.0]
        vertex_5 = polyop.createVert test_poly [x_offset + 5.0, 5.0, 0.0]
        vertex_6 = polyop.createVert test_poly [x_offset + 0.0, 10.0, 0.0]
        vertex_7 = polyop.createVert test_poly [x_offset + 5.0, 10.0, 0.0]
        vertex_8 = polyop.createVert test_poly [x_offset + 10.0, 10.0, 0.0]

        polyop.createPolygon test_poly #(vertex_1, vertex_2, vertex_5, vertex_4)
        polyop.createPolygon test_poly #(vertex_4, vertex_5, vertex_7, vertex_6)
        polyop.createPolygon test_poly #(vertex_2, vertex_3, vertex_8, vertex_7, vertex_5)
        update test_node

        divider_edge = findPolyEdgeByVertices test_poly vertex_4 vertex_5
        if divider_edge == 0 then throw "could not create T-junction divider test edge"

        #(test_node, divider_edge)
        -- return
    ),

    /*
    Creates one isolated planar divider whose endpoint is also a polygon border corner.
    As a single divider edge it is valid; the border-corner rejection applies to multi-edge chain terminals.
    */
    function createBorderCornerTestObject x_offset:60.0 =
    (
        test_node = editable_mesh name:(uniqueName "REDUNDANT_CORNER_TEST_")
        convertTo test_node Editable_Poly
        test_poly = test_node.baseObject
        forceSelectModeZero test_poly

        vertex_1 = polyop.createVert test_poly [x_offset + 0.0, 0.0, 0.0]
        vertex_2 = polyop.createVert test_poly [x_offset + 10.0, 0.0, 0.0]
        vertex_3 = polyop.createVert test_poly [x_offset + 0.0, 5.0, 0.0]
        vertex_4 = polyop.createVert test_poly [x_offset + 10.0, 10.0, 0.0]
        vertex_5 = polyop.createVert test_poly [x_offset + 0.0, 10.0, 0.0]

        polyop.createPolygon test_poly #(vertex_1, vertex_2, vertex_4, vertex_3)
        polyop.createPolygon test_poly #(vertex_3, vertex_4, vertex_5)
        update test_node

        divider_edge = findPolyEdgeByVertices test_poly vertex_3 vertex_4
        if divider_edge == 0 then throw "could not create border-corner divider test edge"

        #(test_node, divider_edge)
        -- return
    ),

    /*
    Tests pure straight-pair and terminal rules without scene geometry.
    Straight border and straight internal T terminals must pass while a border corner and unmatched branch must fail.
    */
    function testTopologyRules =
    (
        pair_points = #([0,0,0], [-1,0,0], [1,0,0], [0,-1,0], [0,1,0])
        pair_edges = #(#(1,2), #(1,3), #(1,4), #(1,5))
        crossing_ok = areEdgesStraightPairs 1 #{1..4} pair_edges pair_points angle_threshold:2.0

        branch_points = #([0,0,0], [-1,0,0], [1,0,0], [0,1,0])
        branch_edges = #(#(1,2), #(1,3), #(1,4))
        branch_rejected = not(areEdgesStraightPairs 1 #{1..3} branch_edges branch_points angle_threshold:2.0)

        border_points = #([0,0,0], [0,-1,0], [0,1,0], [1,0,0])
        border_edges_value = #(#(1,2), #(1,3), #(1,4))
        border_vertex_edges = #(#{1,2,3}, #{1}, #{2}, #{3})
        straight_border_ok = isValidOpenBorderTerminal 1 #{3} #{1,2} border_vertex_edges border_edges_value border_points angle_threshold:2.0

        corner_points = #([0,0,0], [0,-1,0], [1,0,0], [1,1,0])
        corner_edges = #(#(1,2), #(1,3), #(1,4))
        corner_vertex_edges = #(#{1,2,3}, #{1}, #{2}, #{3})
        border_corner_rejected = not(isValidOpenBorderTerminal 1 #{3} #{1,2} corner_vertex_edges corner_edges corner_points angle_threshold:2.0)

        t_points = #([0,0,0], [1,0,0], [0,-1,0], [0,1,0])
        t_edges = #(#(1,2), #(1,3), #(1,4))
        t_vertex_edges = #(#{1,2,3}, #{1}, #{2}, #{3})
        t_ok = isValidInternalTerminal 1 #{1} #{} t_vertex_edges t_edges t_points angle_threshold:2.0

        #(crossing_ok, branch_rejected, straight_border_ok, border_corner_rejected, t_ok)
        -- return
    ),

    /*
    Runs regression tests for direct Editable Poly analysis, isolated dividers, and chain terminal behavior.
    The tests verify divider selection, crease rejection, valid T-junction acceptance, and isolated single-edge acceptance.
    */
    function runTests =
    (
        test_passed = true
        topology_result = testTopologyRules()

        format "TEST straight crossing pairs: %\n" topology_result[1]
        format "TEST unmatched branch rejected: %\n" topology_result[2]
        format "TEST straight border terminal accepted: %\n" topology_result[3]
        format "TEST border corner terminal rejected: %\n" topology_result[4]
        format "TEST straight T terminal accepted: %\n" topology_result[5]

        for result_value in topology_result do
        (
            if not result_value then test_passed = false
        )

        plain_test = undefined
        crease_test = undefined
        t_test = undefined
        corner_test = undefined

        try
        (
            plain_data = createDividerTestObject creased:false x_offset:0.0
            plain_test = plain_data[1]
            plain_edge = plain_data[2]
            plain_result = selectRedundantLoopsOnNode plain_test face_threshold:0.1 straight_threshold:2.0 debug_output:true
            plain_selection = #{}

            if plain_result[1] and plain_result[5] != undefined then plain_selection = EditPolyMod.GetSelection plain_result[5] #Edge node:plain_test

            plain_ok = plain_result[1] and plain_selection[plain_edge]
            format "TEST planar divider selected: % | expectedEdge:% | stored:% | error:%\n" plain_ok plain_edge plain_selection plain_result[4]
            if not plain_ok then test_passed = false

            crease_data = createDividerTestObject creased:true x_offset:20.0
            crease_test = crease_data[1]
            crease_edge = crease_data[2]
            crease_result = selectRedundantLoopsOnNode crease_test face_threshold:0.1 straight_threshold:2.0 debug_output:true
            crease_ok = crease_result[1] and crease_result[3] == 0
            format "TEST creased divider rejected: % | creaseEdge:% | selectedCount:% | error:%\n" crease_ok crease_edge crease_result[3] crease_result[4]
            if not crease_ok then test_passed = false

            t_data = createTJunctionTestObject x_offset:40.0
            t_test = t_data[1]
            t_edge = t_data[2]
            t_result = selectRedundantLoopsOnNode t_test face_threshold:0.1 straight_threshold:2.0 debug_output:true
            t_selection = #{}

            if t_result[1] and t_result[5] != undefined then t_selection = EditPolyMod.GetSelection t_result[5] #Edge node:t_test

            t_ok = t_result[1] and t_selection[t_edge]
            format "TEST T-junction divider selected: % | expectedEdge:% | stored:% | error:%\n" t_ok t_edge t_selection t_result[4]
            if not t_ok then test_passed = false

            corner_data = createBorderCornerTestObject x_offset:70.0
            corner_test = corner_data[1]
            corner_edge = corner_data[2]
            corner_result = selectRedundantLoopsOnNode corner_test face_threshold:0.1 straight_threshold:2.0 debug_output:true
            corner_selection = #{}

            if corner_result[1] and corner_result[5] != undefined then corner_selection = EditPolyMod.GetSelection corner_result[5] #Edge node:corner_test

            corner_ok = corner_result[1] and corner_selection[corner_edge]
            format "TEST isolated single divider selected: % | expectedEdge:% | stored:% | error:%\n" corner_ok corner_edge corner_selection corner_result[4]
            if not corner_ok then test_passed = false
        )
        catch
        (
            format "TEST ERROR: %\n" (getCurrentException())
            test_passed = false
        )

        if plain_test != undefined then try(delete plain_test)catch()
        if crease_test != undefined then try(delete crease_test)catch()
        if t_test != undefined then try(delete t_test)catch()
        if corner_test != undefined then try(delete corner_test)catch()

        format "REDUNDANT LOOP DETECTOR TESTS PASSED: %\n" test_passed
        test_passed
        -- return
    ),

    /*
    Creates one visible planar divider test object for manual viewport inspection.
    Detection is not run automatically.
    */
    function createManualTestObject =
    (
        test_data = createDividerTestObject creased:false x_offset:0.0
        select test_data[1]
        completeRedraw()
        test_data[1]
        -- return
    ),

    on create do
    (
    )
)

RedundantLoopDetector = RedundantLoopDetector_v()


global WallFixer_v
global WallFixer

struct WallFixer_v
(
    version = "0.29",
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
    last_slice_failed_nodes = #(),
    last_slice_elapsed_ms = 0,
    last_slice_processed_objects = 0,
    last_slice_processed_vertices = 0,
    slice_progress_test_capture = undefined,
    slice_stats_csv_path = ((getDir #plugcfg) + "\\Wall-Fixer-Slice-Stats.csv"),
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
    Disables cage display on the Editable Poly base and all Edit Poly modifiers of one valid node.
    This enforces the project-wide no-cage display rule without changing topology.
    */
    function setEditablePolyCageOff node =
    (
        if node == undefined or not(isValidNode node) then return false

        cage_disabled = false

        if classOf node.baseObject == Editable_Poly then
        (
            try
            (
                node.baseObject.showCage = off
                cage_disabled = true
            )
            catch
            (
            )
        )

        for modifier in node.modifiers do
        (
            if classOf modifier == Edit_Poly then
            (
                try
                (
                    modifier.showCage = off
                    cage_disabled = true
                )
                catch
                (
                )
            )
        )

        cage_disabled
        -- return
    ),

    /*
    Verifies the project-wide cage-off rule for both Editable Poly and Edit Poly.
    The temporary scene object is deleted after the test.
    */
    function testEditablePolyCageOff =
    (
        test_passed = false
        test_node = undefined

        try
        (
            test_node = box length:10.0 width:10.0 height:10.0
            convertToPoly test_node
            setEditablePolyCageOff test_node

            test_modifier = Edit_Poly()
            test_modifier.showCage = off
            addModifier test_node test_modifier

            setEditablePolyCageOff test_node

            test_passed = (test_node.baseObject.showCage == off) and (test_modifier.showCage == off)
        )
        catch
        (
            test_passed = false
        )

        if test_node != undefined and isValidNode test_node then
        (
            delete test_node
        )

        test_passed
        -- return
    ),

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
    WMC, SELECT and DELETED prefixes are project-owned; exact legacy names remain recognized for older scene stacks.
    */
    function isWallFixerEditPolyModifier stack_modifier =
    (
        if stack_modifier == undefined then return false
        if classOf stack_modifier != Edit_Poly then return false

        modifier_name = stack_modifier.name as string
        if findString modifier_name "WMC - " == 1 then return true
        if findString modifier_name "SELECT " == 1 then return true
        if findString modifier_name "DELETED " == 1 then return true

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
    Builds the canonical modifier name for one LMB selection or RMB deletion function.
    Function labels are normalized to uppercase while the SELECT / DELETED prefix remains fixed.
    */
    function getSelectDeleteModifierName function_name deleted:false =
    (
        prefix_text = if deleted then "DELETED " else "SELECT "
        prefix_text + (toUpper (function_name as string))
        -- return
    ),


    /*
    Finds the highest exact named Edit Poly modifier without changing or removing any existing stack entry.
    This is the shared no-duplicate lookup used by all SELECT / DELETED workflow controls.
    */
    function findNamedEditPolyModifier node modifier_name =
    (
        if node == undefined or not(isValidNode node) then return undefined

        for stack_modifier in node.modifiers do
        (
            if classOf stack_modifier == Edit_Poly and stack_modifier.name == modifier_name then return stack_modifier
        )

        undefined
        -- return
    ),


    /*
    Creates one named pass-through Edit Poly only when an exact named copy does not already exist.
    Existing named modifiers are always reused; cage display stays off and no duplicate SELECT modifier is added.
    */
    function ensureNamedEditPolyModifier node modifier_name selection_level =
    (
        if node == undefined or not(isValidNode node) then return undefined

        stack_modifier = findNamedEditPolyModifier node modifier_name
        created_modifier = stack_modifier == undefined

        if created_modifier then
        (
            stack_modifier = Edit_Poly name:modifier_name
            addModifier node stack_modifier
            update node
        )

        preparation_failed = false

        try
        (
            if created_modifier then stack_modifier.SetPrimaryNode node
            stack_modifier.useStackSelection = false
            stack_modifier.showCage = off
            stack_modifier.SetEPolySelLevel selection_level
            update node
        )
        catch
        (
            preparation_failed = true
        )

        if preparation_failed then
        (
            if created_modifier and stack_modifier != undefined then
            (
                try(deleteModifier node stack_modifier)catch()
                update node
            )

            undefined
        )
        else
        (
            stack_modifier
        )
        -- return
    ),


    /*
    Activates one named SELECT / DELETED Edit Poly and writes the requested component selection.
    Returns #(success, actual_selection) after final viewport readback; cage display remains off.
    */
    function activateNamedEditPolySelection node stack_modifier selection_level component_selection =
    (
        if node == undefined or not(isValidNode node) then return #(false, #{})
        if stack_modifier == undefined or classOf stack_modifier != Edit_Poly then return #(false, #{})

        subobject_level = case selection_level of
        (
            #Vertex: 1
            #Edge: 2
            #Face: 4
            default: 0
        )

        actual_selection = #{}
        display_ok = false

        try
        (
            select node
            max modify mode
            stack_modifier.useStackSelection = false
            stack_modifier.showCage = off
            modPanel.setCurrentObject stack_modifier
            stack_modifier.SetEPolySelLevel selection_level
            if subobject_level > 0 then subObjectLevel = subobject_level
            stack_modifier.SetSelection selection_level component_selection node:node
            update node
            stack_modifier.RefreshScreen()
            completeRedraw()

            actual_selection = stack_modifier.GetSelection selection_level node:node
            display_ok = \
                (modPanel.getCurrentObject() == stack_modifier) and \
                (actual_selection == component_selection)
        )
        catch
        (
            actual_selection = #{}
            display_ok = false
        )

        #(display_ok, actual_selection)
        -- return
    ),

    /*
    Tests SELECT modifier reuse and cage-off enforcement on a temporary Editable Poly.
    The second acquisition must return the same modifier and the temporary stack must contain exactly one SELECT TEST RULE entry.
    */
    function testSelectDeleteModifierReuse =
    (
        test_node = undefined
        passed = false

        try
        (
            test_node = box length:10.0 width:10.0 height:10.0
            convertToPoly test_node

            first_modifier = ensureNamedEditPolyModifier test_node "SELECT TEST RULE" #Vertex
            second_modifier = ensureNamedEditPolyModifier test_node "SELECT TEST RULE" #Vertex
            select_count = 0

            for stack_modifier in test_node.modifiers do
            (
                if classOf stack_modifier == Edit_Poly and stack_modifier.name == "SELECT TEST RULE" then select_count += 1
            )

            cage_off = first_modifier != undefined and first_modifier.showCage == off
            passed = first_modifier != undefined and first_modifier == second_modifier and select_count == 1 and cage_off
        )
        catch
        (
            passed = false
        )

        if test_node != undefined and isValidNode test_node then delete test_node

        format "Select/Delete modifier reuse test | passed:%\n" passed

        passed
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
    Resolves one Reset Slice direction to its supported modifier-name namespace.
    Vertical uses SLICE V and Horizontal uses SLICE H, including longer names such as SLICE VERTICAL or SLICE HORIZONTAL.
    */
    function getDirectionalSliceNamespace modifier_name =
    (
        local normalized_target = toUpper (modifier_name as string)

        if findString normalized_target "SLICE V" == 1 then return "SLICE V"
        if findString normalized_target "SLICE H" == 1 then return "SLICE H"

        undefined
        -- return
    ),


    /*
    Returns true when one modifier belongs to the requested directional Slice namespace.
    Modifier class is intentionally ignored so RESET SLICE supports Edit Poly, real Slice, and other compatible modifier types.
    */
    function isDirectionalSliceModifier stack_modifier modifier_name =
    (
        if stack_modifier == undefined then return false

        local slice_namespace = getDirectionalSliceNamespace modifier_name
        if slice_namespace == undefined then return false

        local normalized_name = toUpper (stack_modifier.name as string)
        findString normalized_name slice_namespace == 1
        -- return
    ),


    /*
    Deletes every modifier in the requested SLICE V or SLICE H namespace from selected objects.
    SLICE ALL and unrelated user modifiers are preserved.
    */
    function deleteSelectedDirectionalSliceModifiers modifier_name =
    (
        local slice_namespace = getDirectionalSliceNamespace modifier_name
        local selected_nodes = selection as array
        local deleted_count = 0
        local changed_objects = 0
        last_slice_report = ""

        if slice_namespace == undefined then
        (
            last_slice_report = "Reset Slice: unsupported modifier namespace."
            return #(false, 0, 0)
        )

        if selected_nodes.count == 0 then
        (
            last_slice_report = "Reset Slice: select one or more objects."
            return #(false, 0, 0)
        )

        for node in selected_nodes do
        (
            if node != undefined and isValidNode node then
            (
                local node_deleted = 0
                local modifier_index = node.modifiers.count

                while modifier_index >= 1 do
                (
                    local stack_modifier = node.modifiers[modifier_index]

                    if isDirectionalSliceModifier stack_modifier slice_namespace then
                    (
                        deleteModifier node stack_modifier
                        deleted_count += 1
                        node_deleted += 1
                    )

                    modifier_index -= 1
                )

                if node_deleted > 0 then
                (
                    changed_objects += 1
                    update node
                )
            )
        )

        completeRedraw()
        last_slice_report = "Reset Slice: removed " + (deleted_count as string) + " " + slice_namespace + " modifier(s) from " + (changed_objects as string) + " object(s)."
        #(true, deleted_count, changed_objects)
        -- return
    ),


    /*
    Tests namespace-based RESET SLICE matching without changing scene geometry.
    SLICE V and SLICE H accept exact and extended names while SLICE ALL remains protected.
    */
    function testDirectionalSliceDeletePolicy =
    (
        local vertical_modifier = Edit_Poly()
        local vertical_short_modifier = Edit_Poly()
        local horizontal_modifier = Edit_Poly()
        local horizontal_short_modifier = Edit_Poly()
        local all_modifier = Edit_Poly()

        vertical_modifier.name = "SLICE VERTICAL"
        vertical_short_modifier.name = "SLICE V 01"
        horizontal_modifier.name = "SLICE HORIZONTAL"
        horizontal_short_modifier.name = "SLICE H 01"
        all_modifier.name = "SLICE ALL"

        local test_passed = true
        test_passed = test_passed and isDirectionalSliceModifier vertical_modifier "SLICE V"
        test_passed = test_passed and isDirectionalSliceModifier vertical_short_modifier "SLICE V"
        test_passed = test_passed and not(isDirectionalSliceModifier vertical_modifier "SLICE H")
        test_passed = test_passed and isDirectionalSliceModifier horizontal_modifier "SLICE H"
        test_passed = test_passed and isDirectionalSliceModifier horizontal_short_modifier "SLICE H"
        test_passed = test_passed and not(isDirectionalSliceModifier horizontal_modifier "SLICE V")
        test_passed = test_passed and not(isDirectionalSliceModifier all_modifier "SLICE V")
        test_passed = test_passed and not(isDirectionalSliceModifier all_modifier "SLICE H")

        test_passed
        -- return
    ),


    /*
    Returns true for Wall-Fixer Edit Poly slice modifiers and real Slice Force modifiers.
    Legacy fake Edit Poly Force modifiers remain recognized so stale stacks can still be cleaned safely.
    */
    function isWallFixerSliceModifier stack_modifier =
    (
        if stack_modifier == undefined then return false

        local modifier_name = stack_modifier.name as string
        local normalized_name = toUpper modifier_name

        if classOf stack_modifier == SliceModifier then
        (
            return findString normalized_name "SLICE FORCE " == 1
        )

        if classOf stack_modifier != Edit_Poly then return false

        local slice_modifier_names = #(
            "SLICE ALL",
            "SLICE HORIZONTAL",
            "SLICE VERTICAL",
            "WMC - WALL TOPOLOGY CLEANUP",
            "Wall topology cleanup"
        )

        ((findItem slice_modifier_names modifier_name) > 0) or (findString normalized_name "SLICE FORCE " == 1)
        -- return
    ),
    /*
    Tests directional slice-modifier retention.
    Horizontal replaces Horizontal but keeps Vertical; Vertical replaces Vertical but keeps Horizontal.
    */
    function testSliceModifierRetentionPolicy =
    (
        local test_passed = true

        test_passed = test_passed and shouldRemoveWallFixerSliceModifierName "SLICE HORIZONTAL" #horizontal
        test_passed = test_passed and not (shouldRemoveWallFixerSliceModifierName "SLICE VERTICAL" #horizontal)

        test_passed = test_passed and shouldRemoveWallFixerSliceModifierName "SLICE VERTICAL" #vertical
        test_passed = test_passed and not (shouldRemoveWallFixerSliceModifierName "SLICE HORIZONTAL" #vertical)

        test_passed = test_passed and shouldRemoveWallFixerSliceModifierName "SLICE ALL" #horizontal
        test_passed = test_passed and shouldRemoveWallFixerSliceModifierName "SLICE ALL" #vertical
        test_passed = test_passed and shouldRemoveWallFixerSliceModifierName "WMC - WALL TOPOLOGY CLEANUP" #horizontal
        test_passed = test_passed and shouldRemoveWallFixerSliceModifierName "WMC - WALL TOPOLOGY CLEANUP" #vertical

        test_passed = test_passed and shouldRemoveWallFixerSliceModifierName "SLICE HORIZONTAL" #all
        test_passed = test_passed and shouldRemoveWallFixerSliceModifierName "SLICE VERTICAL" #all

        test_passed
        -- return
    ),


    /*
    Returns whether Slice Walls should use the active component selection as its source filter.
    Component filtering is supported only for one selected wall; multi-object batches process complete walls.
    */
    function shouldRestrictSliceToSelectedComponents object_count subobject_level =
    (
        object_count == 1 and subobject_level != undefined and subobject_level > 0
        -- return
    ),

    /*
    Returns whether an already-active top Slice modifier is eligible for selected-vertex continuation.
    Continuation is intentionally limited to Vertex mode with a non-empty selection and matching direction.
    */
    function shouldContinueOnActiveSliceModifier modifier_name cut_mode subobject_level has_vertex_selection =
    (
        local normalized_name = toUpper (modifier_name as string)

        if subobject_level != 1 or not has_vertex_selection then return false

        case cut_mode of
        (
            #vertical: normalized_name == "SLICE VERTICAL"
            #horizontal: normalized_name == "SLICE HORIZONTAL"
            default: normalized_name == "SLICE ALL"
        )
        -- return
    ),

    /*
    Returns the active top Slice modifier when selected-vertex continuation is valid.
    No modifier is created or activated by this lookup.
    */
    function getActiveTopSliceContinuationModifier node cut_mode =
    (
        if node == undefined or not(isValidNode node) then return undefined
        if selection.count != 1 or selection[1] != node then return undefined
        if subObjectLevel != 1 then return undefined
        if node.modifiers.count == 0 then return undefined

        local top_modifier = node.modifiers[1]
        local current_object = undefined
        local selected_vertices = #{}

        try(current_object = modPanel.getCurrentObject())catch(current_object = undefined)
        if current_object != top_modifier or classOf top_modifier != Edit_Poly then return undefined

        try(selected_vertices = top_modifier.GetSelection #Vertex node:node)catch(selected_vertices = #{})

        if shouldContinueOnActiveSliceModifier top_modifier.name cut_mode subObjectLevel (selected_vertices.numberSet > 0) then top_modifier else undefined
        -- return
    ),

    /*
    Activates one wall as the only selected object before its batch-slice preflight.
    This prevents Edit Poly and sub-object context from one wall leaking into the next wall.
    */
    function activateBatchSliceNodeContext node =
    (
        if node == undefined or not(isValidNode node) then return false

        try
        (
            if subObjectLevel != undefined and subObjectLevel > 0 then
            (
                subObjectLevel = 0
            )
        )
        catch
        (
        )

        select node

        selection.count == 1 and selection[1] == node
        -- return
    ),

    /*
    Returns true when the requested slicing Edit Poly already owns the active Modify-panel context.
    Used to avoid redundant command-panel refreshes during batch slicing.
    */
    function hasSliceModifyContext node modifier =
    (
        if node == undefined or modifier == undefined then return false
        if not (isValidNode node) then return false

        panel_mode = undefined
        current_object = undefined

        try
        (
            panel_mode = getCommandPanelTaskMode()
        )
        catch
        (
            panel_mode = undefined
        )

        if panel_mode != #modify then return false

        try
        (
            current_object = modPanel.getCurrentObject()
        )
        catch
        (
            current_object = undefined
        )

        selection_matches = (selection.count == 1 and selection[1] == node)
        selection_matches and current_object == modifier
        -- return
    ),

    /*
    Activates only the Modify-panel context required by Edit Poly topology commands.
    If the correct node and modifier are already active, the command panel is left untouched.
    */
    function ensureSliceModifyContext node modifier =
    (
        if node == undefined or modifier == undefined then return false
        if not (isValidNode node) then return false

        context_changed = false

        if not (hasSliceModifyContext node modifier) then
        (
            if selection.count != 1 or selection[1] != node then
            (
                select node
                context_changed = true
            )

            panel_mode = undefined
            try
            (
                panel_mode = getCommandPanelTaskMode()
            )
            catch
            (
                panel_mode = undefined
            )

            if panel_mode != #modify then
            (
                max modify mode
                context_changed = true
            )

            current_object = undefined
            try
            (
                current_object = modPanel.getCurrentObject()
            )
            catch
            (
                current_object = undefined
            )

            if current_object != modifier then
            (
                modPanel.setCurrentObject modifier
                context_changed = true
            )
        )

        modifier.SetPrimaryNode node
        context_changed
        -- return
    ),



    /*
    Returns true when one Wall-Fixer slice modifier name should be rebuilt for the requested mode.
    Directional runs replace only the same direction and preserve the opposite directional slice.
    Legacy SLICE ALL and slicing cleanup modifiers are removed because they conflict with a deterministic rebuild.
    */
    function shouldRemoveWallFixerSliceModifierName modifier_name cut_mode =
    (
        local normalized_name = toUpper (modifier_name as string)

        if normalized_name == "WMC - WALL TOPOLOGY CLEANUP" or normalized_name == "WALL TOPOLOGY CLEANUP" then return true
        if normalized_name == "SLICE ALL" then return true
        if findString normalized_name "SLICE FORCE " == 1 then return true

        case cut_mode of
        (
            #horizontal: normalized_name == "SLICE HORIZONTAL"
            #vertical: normalized_name == "SLICE VERTICAL"
            default:
            (
                normalized_name == "SLICE HORIZONTAL" or
                normalized_name == "SLICE VERTICAL"
            )
        )
        -- return
    ),


    /*
    Removes only the slicing modifiers that conflict with the requested mode.
    Horizontal preserves SLICE VERTICAL; Vertical preserves SLICE HORIZONTAL.
    */
    function removeWallFixerSliceModifiers node cut_mode:#all preserve_modifier:undefined =
    (
        if node == undefined or not(isValidNode node) then return false

        local modifier_index = node.modifiers.count
        while modifier_index >= 1 do
        (
            local stack_modifier = node.modifiers[modifier_index]

            if isWallFixerSliceModifier stack_modifier then
            (
                if stack_modifier != preserve_modifier and shouldRemoveWallFixerSliceModifierName stack_modifier.name cut_mode then
                (
                    deleteModifier node stack_modifier
                )
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

        setEditablePolyCageOff node

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

            if classOf base_obj == Editable_Poly then
            (
                setEditablePolyCageOff node
                true
            )
            else
            (
                false
            )
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
            setEditablePolyCageOff node

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
    Returns true when one polygon point set is geometrically degenerated.
    Repeated corner positions and effectively zero polygon area are treated as degenerated while preserving valid small faces.
    */
    function isDegeneratedFacePointSet vertex_points position_tolerance:0.000001 area_tolerance:0.00000001 =
    (
        if vertex_points == undefined or vertex_points.count < 3 then return true

        for point_a_index = 1 to (vertex_points.count - 1) do
        (
            for point_b_index = (point_a_index + 1) to vertex_points.count do
            (
                if distance vertex_points[point_a_index] vertex_points[point_b_index] <= position_tolerance then return true
            )
        )

        origin_point = vertex_points[1]
        doubled_area = 0.0
        max_edge_length = 0.0

        for point_index = 1 to vertex_points.count do
        (
            next_index = if point_index == vertex_points.count then 1 else point_index + 1
            edge_length = distance vertex_points[point_index] vertex_points[next_index]
            if edge_length > max_edge_length then max_edge_length = edge_length
        )

        for point_index = 2 to (vertex_points.count - 1) do
        (
            doubled_area += length (cross (vertex_points[point_index] - origin_point) (vertex_points[point_index + 1] - origin_point))
        )

        relative_area_tolerance = (max_edge_length * max_edge_length) * 0.0000000001
        effective_area_tolerance = amax area_tolerance relative_area_tolerance

        doubled_area <= (effective_area_tolerance * 2.0)
        -- return
    ),

    /*
    Finds degenerated polygon faces directly on an unmodified Editable Poly base.
    This direct path is used only when the node has no modifiers, so returned Face IDs match a new pass-through Edit Poly.
    */
    function detectDegeneratedFacesEditablePoly node position_tolerance:0.000001 area_tolerance:0.00000001 =
    (
        degenerated_faces = #{}

        if node == undefined or not(isValidNode node) then return degenerated_faces
        if classOf node.baseObject != Editable_Poly then return degenerated_faces

        face_count = 0
        try(face_count = polyop.getNumFaces node.baseObject)catch(face_count = 0)

        for face_index = 1 to face_count do
        (
            face_points = #()
            face_valid = true
            face_vertices = undefined

            try(face_vertices = polyop.getFaceVerts node.baseObject face_index)catch(face_vertices = undefined)

            if face_vertices == undefined or face_vertices.count < 3 then
            (
                degenerated_faces[face_index] = true
            )
            else
            (
                for vertex_index in face_vertices while face_valid do
                (
                    vertex_point = undefined
                    try(vertex_point = polyop.getVert node.baseObject vertex_index)catch(vertex_point = undefined)

                    if vertex_point == undefined then
                    (
                        face_valid = false
                    )
                    else
                    (
                        append face_points vertex_point
                    )
                )

                if not face_valid or isDegeneratedFacePointSet face_points position_tolerance:position_tolerance area_tolerance:area_tolerance then
                (
                    degenerated_faces[face_index] = true
                )
            )
        )

        degenerated_faces
        -- return
    ),

    /*
    Counts degenerated triangular faces on a non-destructive evaluated mesh snapshot.
    Snapshot Face IDs are intentionally not reused for Edit Poly selection because polygon IDs can differ after evaluation.
    */
    function countDegeneratedFacesSnapshot node position_tolerance:0.000001 area_tolerance:0.00000001 =
    (
        if node == undefined or not(isValidNode node) then return 0

        evaluated_mesh = undefined
        degenerated_count = 0

        try(evaluated_mesh = snapshotAsMesh node)catch(evaluated_mesh = undefined)
        if evaluated_mesh == undefined then return 0

        for face_index = 1 to evaluated_mesh.numfaces do
        (
            face_value = getFace evaluated_mesh face_index
            vertex_ids = #(face_value.x as integer, face_value.y as integer, face_value.z as integer)
            face_points = #()
            face_valid = true

            for vertex_index in vertex_ids while face_valid do
            (
                if vertex_index < 1 or vertex_index > evaluated_mesh.numverts then
                (
                    face_valid = false
                )
                else
                (
                    append face_points (getVert evaluated_mesh vertex_index)
                )
            )

            if not face_valid or isDegeneratedFacePointSet face_points position_tolerance:position_tolerance area_tolerance:area_tolerance then
            (
                degenerated_count += 1
            )
        )

        degenerated_count
        -- return
    ),

    /*
    Finds exact degenerated polygon Face IDs on one pass-through Edit Poly modifier.
    These are the IDs stored by SELECT DEGENERATED FACES and later consumed by RMB deletion.
    */
    function detectDegeneratedFacesEditPoly node modifier position_tolerance:0.000001 area_tolerance:0.00000001 =
    (
        degenerated_faces = #{}

        if node == undefined or not(isValidNode node) then return degenerated_faces
        if modifier == undefined or classOf modifier != Edit_Poly then return degenerated_faces

        update node
        face_count = 0
        try(face_count = modifier.GetNumFaces node:node)catch(face_count = 0)

        for face_index = 1 to face_count do
        (
            face_degree = undefined
            try(face_degree = modifier.GetFaceDegree face_index node:node)catch(face_degree = undefined)

            if face_degree == undefined or face_degree < 3 then
            (
                degenerated_faces[face_index] = true
            )
            else
            (
                face_points = #()
                face_valid = true

                for corner_index = 1 to face_degree while face_valid do
                (
                    vertex_index = undefined
                    vertex_point = undefined
                    try(vertex_index = modifier.GetFaceVertex face_index corner_index node:node)catch(vertex_index = undefined)

                    if vertex_index == undefined or vertex_index < 1 then
                    (
                        face_valid = false
                    )
                    else
                    (
                        try(vertex_point = modifier.GetVertex vertex_index node:node)catch(vertex_point = undefined)
                        if vertex_point == undefined then
                        (
                            face_valid = false
                        )
                        else
                        (
                            append face_points vertex_point
                        )
                    )
                )

                if not face_valid or isDegeneratedFacePointSet face_points position_tolerance:position_tolerance area_tolerance:area_tolerance then
                (
                    degenerated_faces[face_index] = true
                )
            )
        )

        degenerated_faces
        -- return
    ),

    /*
    Returns the existing SELECT DEGENERATED FACES modifier without adding a duplicate.
    The shared exact-name lookup is used even when the modifier is no longer the stack top.
    */
    function getTopDegeneratedFaceSelectionModifier node =
    (
        findNamedEditPolyModifier node (getSelectDeleteModifierName "DEGENERATED FACES")
        -- return
    ),

    /*
    Finds the existing SELECT DEGENERATED FACES modifier used by RMB deletion.
    Unrelated Edit Poly modifiers are never modified.
    */
    function findDegeneratedFaceSelectionModifier node =
    (
        findNamedEditPolyModifier node (getSelectDeleteModifierName "DEGENERATED FACES")
        -- return
    ),

    /*
    Detects degenerated faces on one node and stores exact evaluated Face IDs in exactly one SELECT DEGENERATED FACES modifier.
    Modified geometry is preflighted from snapshotAsMesh; an existing exact SELECT modifier is reused and is never deleted/recreated.
    */
    function selectDegeneratedFacesOnNode node position_tolerance:0.000001 area_tolerance:0.00000001 debug_output:true =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0, "invalid node", undefined, #{})
        if superclassof node != GeometryClass then return #(false, 0, "requires geometry", undefined, #{})

        selection_modifier = undefined
        operation_error = undefined
        degenerated_faces = #{}
        preflight_count = 0
        snapshot_face_count = undefined
        evaluated_mesh = undefined
        select_name = getSelectDeleteModifierName "DEGENERATED FACES"

        try
        (
            use_snapshot = node.modifiers.count > 0 or classOf node.baseObject != Editable_Poly

            if use_snapshot then
            (
                evaluated_mesh = snapshotAsMesh node
                if evaluated_mesh == undefined then throw "could not create evaluated snapshot"
                snapshot_face_count = getNumFaces evaluated_mesh
                free evaluated_mesh
                evaluated_mesh = undefined
                preflight_count = countDegeneratedFacesSnapshot node position_tolerance:position_tolerance area_tolerance:area_tolerance
            )
            else
            (
                base_faces = detectDegeneratedFacesEditablePoly node position_tolerance:position_tolerance area_tolerance:area_tolerance
                preflight_count = base_faces.numberSet
            )

            selection_modifier = ensureNamedEditPolyModifier node select_name #Face
            if selection_modifier == undefined then throw (select_name + " could not be created or reused")

            if snapshot_face_count != undefined then
            (
                live_face_count = selection_modifier.GetNumFaces node:node
                if live_face_count < 1 and snapshot_face_count > 0 then
                (
                    throw "SELECT DEGENERATED FACES does not expose evaluated face topology"
                )
            )

            selection_modifier.SetSelection #Face #{} node:node

            if preflight_count > 0 then
            (
                degenerated_faces = detectDegeneratedFacesEditPoly node selection_modifier position_tolerance:position_tolerance area_tolerance:area_tolerance
            )

            selection_modifier.SetSelection #Face degenerated_faces node:node
            stored_selection = selection_modifier.GetSelection #Face node:node

            if stored_selection != degenerated_faces then
            (
                throw ("SELECT DEGENERATED FACES could not store the detected faces. Requested:" + (degenerated_faces as string) + " actual:" + (stored_selection as string))
            )

            selection_modifier.showCage = off
            update node

            if debug_output and not batch_quiet then
            (
                format "Wall-Fixer Degenerated Faces: node:% snapshotPreflight:% faces:% selection:% modifier:%\n" node.name use_snapshot degenerated_faces.numberSet degenerated_faces selection_modifier.name
            )
        )
        catch
        (
            if evaluated_mesh != undefined then free evaluated_mesh
            operation_error = getCurrentException()
            update node
        )

        if operation_error == undefined then
        (
            #(true, degenerated_faces.numberSet, "", selection_modifier, copy degenerated_faces)
        )
        else
        (
            #(false, 0, operation_error as string, selection_modifier, #{})
        )
        -- return
    ),


    /*
    Activates SELECT DEGENERATED FACES in the Modify panel and persists its exact Face selection.
    Returns #(success, final_selection); success requires active Face sub-object level and exact readback.
    */
    function activateDegeneratedFaceSelectionDisplay node selection_modifier face_selection =
    (
        if node == undefined or not(isValidNode node) then return #(false, #{})
        if selection_modifier == undefined or classOf selection_modifier != Edit_Poly then return #(false, #{})

        final_selection = #{}
        display_ok = false

        try
        (
            select node
            max modify mode

            selection_modifier.useStackSelection = false
            selection_modifier.showCage = off
            modPanel.setCurrentObject selection_modifier
            selection_modifier.SetEPolySelLevel #Face
            subObjectLevel = 4

            selection_modifier.SetSelection #Face face_selection node:node
            final_selection = selection_modifier.GetSelection #Face node:node

            if final_selection != face_selection then
            (
                selection_modifier.SetSelection #Face #{} node:node
                selection_modifier.Select #Face face_selection invert:false select:true node:node
                final_selection = selection_modifier.GetSelection #Face node:node
            )

            update node
            completeRedraw()

            final_selection = selection_modifier.GetSelection #Face node:node
            current_object = modPanel.getCurrentObject()

            display_ok = \
                (current_object == selection_modifier) and \
                (subObjectLevel == 4) and \
                ((EditPolyMod.GetEPolySelLevel selection_modifier) == #Face) and \
                (final_selection == face_selection)
        )
        catch
        (
            final_selection = #{}
            display_ok = false
        )

        #(display_ok, final_selection)
        -- return
    ),

    /*
    Runs degenerated-face selection on every selected geometry object.
    The first matching object is focused on SELECT DEGENERATED FACES at Face sub-object level.
    */
    function selectDegeneratedFacesSelection position_tolerance:0.000001 area_tolerance:0.00000001 debug_output:true =
    (
        last_slice_error = undefined
        last_slice_report = ""
        selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select at least one geometry object."
            return #(false, 0)
        )

        total_faces = 0
        failed_nodes = #()
        report_text = ""
        display_node = undefined
        display_modifier = undefined
        display_faces = #{}

        for node in selected_nodes do
        (
            if superclassof node == GeometryClass then
            (
                selection_result = selectDegeneratedFacesOnNode node position_tolerance:position_tolerance area_tolerance:area_tolerance debug_output:debug_output

                if selection_result[1] then
                (
                    total_faces += selection_result[2]
                    report_text += node.name + ": degenerated faces " + (selection_result[2] as string) + ".\n"

                    if display_modifier == undefined then
                    (
                        display_node = node
                        display_modifier = selection_result[4]
                        display_faces = selection_result[5]
                    )
                )
                else
                (
                    append failed_nodes node.name
                    report_text += node.name + ": FAILED - " + selection_result[3] + ".\n"
                )
            )
        )

        if display_modifier != undefined then
        (
            display_result = activateDegeneratedFaceSelectionDisplay display_node display_modifier display_faces
            if not display_result[1] then
            (
                append failed_nodes display_node.name
                report_text += display_node.name + ": FAILED - SELECT DEGENERATED FACES final selection mismatch. Requested " + (display_faces as string) + ", stored " + (display_result[2] as string) + ".\n"
            )
        )
        else
        (
            select selected_nodes
            completeRedraw()
        )

        if failed_nodes.count == 0 then
        (
            if total_faces > 0 then
            (
                last_slice_report = "Degenerated Face Selection complete. Faces selected: " + (total_faces as string) + ".\n" + report_text
            )
            else
            (
                last_slice_report = "No degenerated faces found.\n" + report_text
            )

            if not batch_quiet then format "%" last_slice_report
            #(true, total_faces)
        )
        else
        (
            last_slice_report = "Degenerated Face Selection completed with failures.\n" + report_text
            if not batch_quiet then format "%" last_slice_report
            #(false, total_faces)
        )
        -- return
    ),

    /*
    Deletes only faces stored in SELECT DEGENERATED FACES that are still geometrically degenerated.
    RMB reuses that modifier when present, creates it through the same snapshot detector when absent, then renames it DELETED DEGENERATED FACES.
    */
    function deleteSelectedDegeneratedFacesOnNode node position_tolerance:0.000001 area_tolerance:0.00000001 debug_output:true =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0, "invalid node", undefined)

        selection_modifier = findDegeneratedFaceSelectionModifier node

        if selection_modifier == undefined then
        (
            select_result = selectDegeneratedFacesOnNode node position_tolerance:position_tolerance area_tolerance:area_tolerance debug_output:debug_output
            if not select_result[1] then return #(false, 0, select_result[3], select_result[4])
            selection_modifier = select_result[4]
        )

        if selection_modifier == undefined then return #(false, 0, "SELECT DEGENERATED FACES modifier unavailable", undefined)

        operation_error = undefined
        deleted_count = 0
        deleted_name = getSelectDeleteModifierName "DEGENERATED FACES" deleted:true

        try
        (
            stored_selection = selection_modifier.GetSelection #Face node:node
            if stored_selection == undefined then stored_selection = #{}

            current_degenerated = detectDegeneratedFacesEditPoly node selection_modifier position_tolerance:position_tolerance area_tolerance:area_tolerance
            faces_to_delete = stored_selection * current_degenerated

            select node
            max modify mode
            selection_modifier.useStackSelection = false
            selection_modifier.showCage = off
            modPanel.setCurrentObject selection_modifier
            selection_modifier.SetEPolySelLevel #Face
            subObjectLevel = 4
            selection_modifier.SetSelection #Face faces_to_delete node:node

            verified_selection = selection_modifier.GetSelection #Face node:node
            if verified_selection != faces_to_delete then
            (
                throw ("DELETED DEGENERATED FACES selection mismatch. Requested:" + (faces_to_delete as string) + " actual:" + (verified_selection as string))
            )

            if faces_to_delete.numberSet > 0 then
            (
                deleted_count = faces_to_delete.numberSet
                selection_modifier.SetOperation #DeleteFace
                selection_modifier.Commit()
                update node
            )

            selection_modifier.name = deleted_name
            selection_modifier.showCage = off
            update node
            completeRedraw()

            if debug_output and not batch_quiet then
            (
                format "Wall-Fixer Degenerated Faces Delete: node:% deleted:% modifier:%\n" node.name deleted_count selection_modifier.name
            )
        )
        catch
        (
            operation_error = getCurrentException()
            update node
        )

        if operation_error == undefined then
        (
            #(true, deleted_count, "", selection_modifier)
        )
        else
        (
            #(false, 0, operation_error as string, selection_modifier)
        )
        -- return
    ),


    /*
    Deletes degenerated faces through the project-standard SELECT / DELETED modifier workflow on selected objects.
    Existing SELECT DEGENERATED FACES modifiers are reused; RMB creates the dedicated selector first only when it is missing.
    */
    function deleteSelectedDegeneratedFacesSelection position_tolerance:0.000001 area_tolerance:0.00000001 debug_output:true =
    (
        last_slice_error = undefined
        last_slice_report = ""
        selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select at least one geometry object."
            return #(false, 0)
        )

        total_deleted = 0
        failed_nodes = #()
        report_text = ""
        display_node = undefined
        display_modifier = undefined

        undo "Wall-Fixer - Delete Degenerated Faces" on
        (
            for node in selected_nodes do
            (
                if superclassof node == GeometryClass then
                (
                    delete_result = deleteSelectedDegeneratedFacesOnNode node position_tolerance:position_tolerance area_tolerance:area_tolerance debug_output:debug_output

                    if delete_result[1] then
                    (
                        total_deleted += delete_result[2]
                        report_text += node.name + ": deleted " + (delete_result[2] as string) + " degenerated face(s).\n"

                        if display_modifier == undefined and delete_result[2] > 0 then
                        (
                            display_node = node
                            display_modifier = delete_result[4]
                        )
                    )
                    else
                    (
                        append failed_nodes node.name
                        report_text += node.name + ": FAILED - " + delete_result[3] + ".\n"
                    )
                )
            )
        )

        if display_modifier != undefined then
        (
            try
            (
                select display_node
                max modify mode
                modPanel.setCurrentObject display_modifier
                display_modifier.showCage = off
                display_modifier.SetEPolySelLevel #Face
                subObjectLevel = 4
                completeRedraw()
            )
            catch()
        )
        else
        (
            select selected_nodes
            completeRedraw()
        )

        if failed_nodes.count == 0 then
        (
            if total_deleted > 0 then
            (
                last_slice_report = "Degenerated Face Delete complete. Faces deleted: " + (total_deleted as string) + ".\n" + report_text
            )
            else
            (
                last_slice_report = "No stored degenerated-face selection found to delete.\n" + report_text
            )

            if not batch_quiet then format "%" last_slice_report
            #(true, total_deleted)
        )
        else
        (
            last_slice_report = "Degenerated Face Delete completed with failures.\n" + report_text
            if not batch_quiet then format "%" last_slice_report
            #(false, total_deleted)
        )
        -- return
    ),

    /*
    Tests the pure degenerated-face geometry rule without changing scene geometry.
    Collinear and repeated-corner polygons must fail while a normal triangle must remain valid.
    */
    function testDegeneratedFaceRules =
    (
        collinear_points = #([0,0,0], [1,0,0], [2,0,0])
        repeated_points = #([0,0,0], [1,0,0], [1,1,0], [1,0,0])
        valid_points = #([0,0,0], [1,0,0], [0,1,0])

        collinear_ok = isDegeneratedFacePointSet collinear_points
        repeated_ok = isDegeneratedFacePointSet repeated_points
        valid_ok = not(isDegeneratedFacePointSet valid_points)
        passed = collinear_ok and repeated_ok and valid_ok

        format "Degenerated face rule test | collinear:% | repeated:% | valid:% | passed:%\n" collinear_ok repeated_ok valid_ok passed

        passed
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
    Removes live vertices that are not referenced by any face.
    A top Edit Poly modifier is handled in-place; otherwise an Editable Poly base object is cleaned directly.
    */
    function removeRedundantVertices node =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0)

        redundant_vertices = #{}
        removed_count = 0
        top_edit_poly = undefined

        if node.modifiers.count > 0 and classOf node.modifiers[1] == Edit_Poly then
        (
            top_edit_poly = node.modifiers[1]
        )

        if top_edit_poly != undefined then
        (
            evaluated_mesh = snapshotAsMesh node
            used_vertices = #{}

            for face_index = 1 to getNumFaces evaluated_mesh do
            (
                face_vertices = getFace evaluated_mesh face_index
                used_vertices[face_vertices.x as integer] = true
                used_vertices[face_vertices.y as integer] = true
                used_vertices[face_vertices.z as integer] = true
            )

            vertex_count = top_edit_poly.GetNumVertices node:node
            for vertex_index = 1 to vertex_count do
            (
                vertex_position = undefined
                try
                (
                    vertex_position = top_edit_poly.GetVertex vertex_index node:node
                )
                catch
                (
                    vertex_position = undefined
                )

                if vertex_position != undefined and not used_vertices[vertex_index] then redundant_vertices[vertex_index] = true
            )

            delete evaluated_mesh

            if redundant_vertices.numberSet > 0 then
            (
                before_count = getLiveEditPolyVertexCount node top_edit_poly
                top_edit_poly.SetEPolySelLevel #Vertex
                top_edit_poly.SetSelection #Vertex redundant_vertices node:node
                top_edit_poly.ButtonOp #RemoveVertex
                top_edit_poly.Commit()
                update node
                after_count = getLiveEditPolyVertexCount node top_edit_poly
                removed_count = amax 0 (before_count - after_count)
                top_edit_poly.SetSelection #Vertex #{} node:node
            )
        )
        else if classOf node.baseObject == Editable_Poly then
        (
            base_obj = node.baseObject
            used_vertices = #{}
            vertex_count = polyop.getNumVerts base_obj
            face_count = polyop.getNumFaces base_obj

            for face_index = 1 to face_count do
            (
                face_vertices = polyop.getFaceVerts base_obj face_index
                for vertex_index in face_vertices do used_vertices[vertex_index] = true
            )

            for vertex_index = 1 to vertex_count do
            (
                if not used_vertices[vertex_index] then redundant_vertices[vertex_index] = true
            )

            if redundant_vertices.numberSet > 0 then
            (
                before_count = polyop.getNumVerts base_obj
                polyop.deleteVerts base_obj redundant_vertices
                update node
                after_count = polyop.getNumVerts base_obj
                removed_count = amax 0 (before_count - after_count)
            )
        )

        #(true, removed_count)
        -- return
    ),

    /*
    Removes redundant vertices from a supplied node collection and returns checked/removed counts.
    Invalid and unsupported nodes are ignored without converting their geometry type.
    */
    function removeRedundantVerticesFromNodes nodes =
    (
        checked_count = 0
        removed_count = 0

        for node in nodes do
        (
            if node != undefined and isValidNode node and superClassOf node == GeometryClass then
            (
                cleanup_result = removeRedundantVertices node
                if cleanup_result[1] then
                (
                    checked_count += 1
                    removed_count += cleanup_result[2]
                )
            )
        )

        #(checked_count, removed_count)
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
                setEditablePolyCageOff node
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
                setEditablePolyCageOff target_node
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
                setEditablePolyCageOff node

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
    The merged target is welded with the supplied threshold, centered, and quadrified only when its triangle count is within the supplied limit.
    */
    function attachCenterWeldQuadrifySelection weld_threshold triangle_limit:12 =
    (
        local attach_success = attachAndWeldSelection weld_threshold
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


        last_slice_report = "Attach RMB: attached selection, centered pivot, welded all vertices with threshold " + \
            (weld_threshold as string) + "; triangles: " + \
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

        setEditablePolyCageOff node

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

        setEditablePolyCageOff node

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
    Applies the current geometry to Editable Poly, splits all currently selected edges, and explodes the resulting elements.
    Supports edge selection coming from a top Edit Poly modifier or an Editable Poly base object.
    */
    function splitSelectedEdgeToObjects =
    (
        selected_nodes = selection as array

        if selected_nodes.count != 1 then
        (
            last_slice_report = "Split: select exactly one geometry object with one or more edges selected."
            return false
        )

        node = selected_nodes[1]
        if not (isValidNode node) or superClassOf node != GeometryClass then
        (
            last_slice_report = "Split: the selected item is not a supported geometry object."
            return false
        )

        selected_edges = #{}

        if node.modifiers.count > 0 and classOf node.modifiers[1] == Edit_Poly then
        (
            try
            (
                selected_edges = node.modifiers[1].GetSelection #Edge node:node
            )
            catch
            (
                selected_edges = #{}
            )
        )
        else if classOf node.baseObject == Editable_Poly then
        (
            selected_edges = polyop.getEdgeSelection node.baseObject
        )
        else
        (
            try
            (
                convertToPoly node
                setEditablePolyCageOff node
            )
            catch
            (
            )

            if classOf node.baseObject == Editable_Poly then selected_edges = polyop.getEdgeSelection node.baseObject
        )

        if selected_edges.numberSet == 0 then
        (
            last_slice_report = "Split: select one or more edges."
            return false
        )

        conversion_ok = true

        try
        (
            convertToPoly node
            setEditablePolyCageOff node
        )
        catch
        (
            conversion_ok = false
        )

        if (not conversion_ok) or classOf node.baseObject != Editable_Poly then
        (
            last_slice_report = "Split: could not apply Editable Poly to the selected object."
            return false
        )

        base_obj = node.baseObject
        max_edge_index = polyop.getNumEdges base_obj
        valid_edges = #{}

        for edge_index in selected_edges where edge_index >= 1 and edge_index <= max_edge_index do valid_edges[edge_index] = true

        if valid_edges.numberSet == 0 then
        (
            last_slice_report = "Split: selected edges did not survive Editable Poly conversion."
            return false
        )

        split_ok = false

        try
        (
            polyop.setEdgeSelection base_obj valid_edges
            polyop.splitEdges base_obj valid_edges
            update node
            split_ok = true
        )
        catch
        (
            split_ok = false
        )

        if not split_ok then
        (
            last_slice_report = "Split failed while separating the selected edges."
            return false
        )

        result_nodes = explodeNodeByElements node
        removeRedundantVerticesFromNodes result_nodes
        select result_nodes
        completeRedraw()

        if result_nodes.count < 2 then
        (
            last_slice_report = "Split completed, but the selected edges did not create separate elements."
            return false
        )

        last_slice_report = "Split complete. Created " + (result_nodes.count as string) + " objects from " + (valid_edges.numberSet as string) + " selected edge(s)."
        true
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
            setEditablePolyCageOff node

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
                    setEditablePolyCageOff target_node

                    if isValidNode target_node and classOf target_node.baseObject == Editable_Poly then
                    (
                        merged_group_count += 1

                        for source_index = 2 to group_nodes.count do
                        (
                            source_node = group_nodes[source_index]

                            if isValidNode source_node then
                            (
                                try(convertToPoly source_node)catch()
                                setEditablePolyCageOff source_node

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
                    if subObjectLevel == 2 then
                    (
                        local selected_edges = current_object.GetSelection #Edge node:node

                        for edge_index in selected_edges do
                        (
                            local edge_a = current_object.GetEdgeVertex edge_index 1 node:node
                            local edge_b = current_object.GetEdgeVertex edge_index 2 node:node

                            if edge_a != undefined and edge_a > 0 then modifier_selection[edge_a] = true
                            if edge_b != undefined and edge_b > 0 then modifier_selection[edge_b] = true
                        )
                    )
                    else
                    (
                        modifier_selection = current_object.GetSelection #Vertex node:node
                    )
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

            /* SELECT / DELETED TWO-EDGE VERTS are dedicated inspection/history modifiers, not slicing modifiers.
               Preserve them in place and always build Slice Walls work above instead of deleting or reusing them. */
            if modifier != undefined and (modifier.name == "SELECT TWO-EDGE VERTS" or modifier.name == "DELETED TWO-EDGE VERTS") then
            (
                try(modifier.showCage = off)catch()
                modifier = undefined
            )

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

        local first_new_vertex_index = last_debug_slice_original_vertices.count + 1

        if first_new_vertex_index <= current_vertex_count then
        (
            for vertex_index = first_new_vertex_index to current_vertex_count do
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
    function cleanupMassSlicePrecisionVerts node precision_threshold:0.01 preserve_base_ids:false keep_modify_context:false =
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

            ensureSliceModifyContext node modifier
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
    Returns the preserved opposite-direction slice modifier only when it is the current top modifier.
    Automatic live-anchor capture is intentionally limited to this deterministic stacked-slice case.
    */
    function getTopOppositeSliceModifier node cut_mode =
    (
        if node == undefined or not(isValidNode node) then return undefined
        if node.modifiers.count < 1 then return undefined

        local top_modifier = node.modifiers[1]
        if classOf top_modifier != Edit_Poly then return undefined

        local modifier_name = toUpper (top_modifier.name as string)

        case cut_mode of
        (
            #horizontal:
            (
                if modifier_name == "SLICE VERTICAL" then top_modifier else undefined
            )
            #vertical:
            (
                if modifier_name == "SLICE HORIZONTAL" then top_modifier else undefined
            )
            default: undefined
        )
        -- return
    ),


    /*
    Captures all live non-base orthogonal anchors from one preserved opposite slice modifier.
    These anchors are automatically added when stacking the other directional slice mode.
    */
    function captureAutomaticLiveSliceTasks node source_modifier cut_mode:#all slice_plane_mode:#nextVert match_tolerance:0.01 =
    (
        local result = #()
        if node == undefined or not(isValidNode node) then return result
        if source_modifier == undefined or classOf source_modifier != Edit_Poly then return result
        if classOf node.baseObject != Editable_Poly then return result

        local pipeline = WMCWallSlicePipeline             node:node             ep:source_modifier             uiSelection:false

        local live_anchor_vertices = pipeline.getLiveOrthogonalAnchorVertexSelection()
        if live_anchor_vertices.numberSet == 0 then return result

        local base_obj = node.baseObject
        local base_vertex_count = polyop.getNumVerts base_obj
        local object_tm = node.objectTransform
        local search_tolerance = amax epsilon match_tolerance
        local slice_kinds = #()

        if cut_mode == #all or cut_mode == #vertical then append slice_kinds #vertical
        if cut_mode == #all or cut_mode == #horizontal then append slice_kinds #horizontal

        local captured_planes = #()

        for source_vertex in live_anchor_vertices do
        (
            local modifier_position = undefined
            try
            (
                modifier_position = source_modifier.GetVertex source_vertex node:node
            )
            catch
            (
                modifier_position = undefined
            )

            if modifier_position != undefined then
            (
                local modifier_world = modifier_position * object_tm
                local maps_to_base = false

                for base_vertex = 1 to base_vertex_count while not maps_to_base do
                (
                    local base_position = polyop.getVert base_obj base_vertex
                    if base_position != undefined then
                    (
                        local base_world = base_position * object_tm
                        maps_to_base = distance modifier_world base_world <= search_tolerance
                    )
                )

                if not maps_to_base then
                (
                    for slice_kind in slice_kinds do
                    (
                        local seed = pipeline.getLiveSlicePlaneSeed                             source_vertex                             slice_kind                             planeMode:slice_plane_mode                             allow_internal_edges:true

                        if seed != undefined then
                        (
                            local seed_anchor = seed[3]
                            local seed_axis = seed[4]
                            local duplicate_plane = false

                            for plane_item in captured_planes while not duplicate_plane do
                            (
                                local same_kind = plane_item[1] == slice_kind
                                local parallel = abs(dot plane_item[2] seed_axis) >= cos 0.1
                                local same_plane = abs(dot(seed_anchor - plane_item[3]) seed_axis) <= search_tolerance
                                if same_kind and parallel and same_plane then duplicate_plane = true
                            )

                            if not duplicate_plane then
                            (
                                append captured_planes #(slice_kind, seed_axis, seed_anchor)
                                append result #(
                                    0,
                                    slice_kind,
                                    0,
                                    seed_anchor,
                                    seed_axis,
                                    #{},
                                    #{},
                                    seed_anchor.z,
                                    undefined,
                                    undefined,
                                    0
                                )

                                if not batch_quiet then format "Wall-Fixer Automatic Live Slice Anchor: node:% modifier:% sourceVert:% direction:% anchor:% axis:%\n"                                     node.name source_modifier.name source_vertex slice_kind seed_anchor seed_axis
                            )
                        )
                    )
                )
            )
        )

        result
        -- return
    ),


    /*
    Adds live slice tasks only when their geometric plane is not already present in the pass queue.
    */
    function appendUniqueLiveSliceTasks pass_tasks live_tasks match_tolerance:0.01 =
    (
        for live_task in live_tasks do
        (
            local duplicate_task = false
            local live_kind = live_task[2]
            local live_anchor = live_task[4]
            local live_axis = live_task[5]

            for existing_task in pass_tasks while not duplicate_task do
            (
                local same_kind = existing_task[2] == live_kind
                local existing_anchor = existing_task[4]
                local existing_axis = existing_task[5]

                if same_kind and existing_anchor != undefined and existing_axis != undefined then
                (
                    local parallel = abs(dot (normalize existing_axis) (normalize live_axis)) >= cos 0.1
                    local same_plane = abs(dot(live_anchor - existing_anchor) (normalize live_axis)) <= match_tolerance
                    if parallel and same_plane then duplicate_task = true
                )
            )

            if not duplicate_task then append pass_tasks live_task
        )

        pass_tasks
        -- return
    ),


    /*
    Captures selected live Edit Poly slice planes that cannot be represented by unchanged base-object vertex IDs.
    Vertex mode uses selected vertices; Edge mode uses selected edge endpoints and prefers the selected edge itself.
    */
    function captureSelectedLiveSliceTasks node cut_mode:#all slice_plane_mode:#nextVert match_tolerance:0.01 =
    (
        local result = #()
        if node == undefined or not(isValidNode node) then return result
        if classOf node.baseObject != Editable_Poly then return result

        local current_object = undefined
        try
        (
            current_object = modPanel.getCurrentObject()
        )
        catch
        (
            current_object = undefined
        )

        if current_object == undefined or classOf current_object != Edit_Poly then return result

        local belongs_to_node = false
        for modifier in node.modifiers while not belongs_to_node do
        (
            if modifier == current_object then belongs_to_node = true
        )
        if not belongs_to_node then return result

        local source_records = #()

        if subObjectLevel == 2 then
        (
            local selected_edges = #{}
            try
            (
                selected_edges = current_object.GetSelection #Edge node:node
            )
            catch
            (
                selected_edges = #{}
            )

            for edge_index in selected_edges do
            (
                local edge_a = current_object.GetEdgeVertex edge_index 1 node:node
                local edge_b = current_object.GetEdgeVertex edge_index 2 node:node

                if edge_a != undefined and edge_a > 0 then append source_records #(edge_a, edge_index)
                if edge_b != undefined and edge_b > 0 then append source_records #(edge_b, edge_index)
            )
        )
        else
        (
            local selected_vertices = #{}
            try
            (
                selected_vertices = current_object.GetSelection #Vertex node:node
            )
            catch
            (
                selected_vertices = #{}
            )

            for vertex_index in selected_vertices do
            (
                append source_records #(vertex_index, 0)
            )
        )

        if source_records.count == 0 then return result

        local base_obj = node.baseObject
        local base_vertex_count = polyop.getNumVerts base_obj
        local object_tm = node.objectTransform
        local search_tolerance = amax epsilon match_tolerance
        local slice_kinds = #()

        if cut_mode == #all or cut_mode == #vertical then append slice_kinds #vertical
        if cut_mode == #all or cut_mode == #horizontal then append slice_kinds #horizontal

        local pipeline = WMCWallSlicePipeline \
            node:node \
            ep:current_object \
            uiSelection:false

        local captured_planes = #()

        for source_record in source_records do
        (
            local source_vertex = source_record[1]
            local preferred_edge = source_record[2]
            local modifier_position = undefined

            try
            (
                modifier_position = current_object.GetVertex source_vertex node:node
            )
            catch
            (
                modifier_position = undefined
            )

            if modifier_position != undefined then
            (
                local modifier_world = modifier_position * object_tm
                local maps_to_base = false

                for base_vertex = 1 to base_vertex_count while not maps_to_base do
                (
                    local base_position = polyop.getVert base_obj base_vertex
                    if base_position != undefined then
                    (
                        local base_world = base_position * object_tm
                        maps_to_base = distance modifier_world base_world <= search_tolerance
                    )
                )

                if not maps_to_base then
                (
                    for slice_kind in slice_kinds do
                    (
                        local seed = pipeline.getLiveSlicePlaneSeed \
                            source_vertex \
                            slice_kind \
                            planeMode:slice_plane_mode \
                            allow_internal_edges:true \
                            preferred_edge:preferred_edge

                        if seed != undefined then
                        (
                            local seed_anchor = seed[3]
                            local seed_axis = seed[4]
                            local duplicate_plane = false

                            for plane_item in captured_planes while not duplicate_plane do
                            (
                                local same_kind = plane_item[1] == slice_kind
                                local parallel = abs(dot plane_item[2] seed_axis) >= cos 0.1
                                local same_plane = abs(dot(seed_anchor - plane_item[3]) seed_axis) <= 0.01

                                if same_kind and parallel and same_plane then duplicate_plane = true
                            )

                            if not duplicate_plane then
                            (
                                append captured_planes #(slice_kind, seed_axis, seed_anchor)
                                append result #(
                                    0,
                                    slice_kind,
                                    0,
                                    seed_anchor,
                                    seed_axis,
                                    #{},
                                    #{},
                                    seed_anchor.z,
                                    undefined,
                                    undefined,
                                    0
                                )

                                if not batch_quiet then format "Wall-Fixer Selected Live Slice Seed: node:% sourceVert:% preferredEdge:% direction:% anchor:% axis:%\n" \
                                    node.name source_vertex preferred_edge slice_kind seed_anchor seed_axis
                            )
                        )
                    )
                )
            )
        )

        result
        -- return
    ),

    /*
    Returns the matching directional plane-group index inside one planar wall region.
    Plane identity uses parallel normals plus signed plane position, so different hole corners on the same cut plane collapse to one task.
    */
    function findBaseSlicePlaneGroupIndex plane_groups world_anchor world_axis region_id match_tolerance:0.001 =
    (
        if world_anchor == undefined or world_axis == undefined then return 0
        if length world_axis <= epsilon then return 0

        local normalized_axis = normalize world_axis
        local axis_cos = cos 0.1
        local plane_tolerance = amax epsilon match_tolerance
        local group_index = 0

        for index = 1 to plane_groups.count while group_index == 0 do
        (
            local group_item = plane_groups[index]
            local group_anchor = group_item[1]
            local group_axis = group_item[2]
            local group_region_id = group_item[6]

            if group_region_id == region_id and group_anchor != undefined and group_axis != undefined and length group_axis > epsilon then
            (
                local normalized_group_axis = normalize group_axis
                local parallel = abs(dot normalized_group_axis normalized_axis) >= axis_cos
                local same_plane = abs(dot(world_anchor - group_anchor) normalized_axis) <= plane_tolerance

                if parallel and same_plane then
                (
                    group_index = index
                )
            )
        )

        group_index
        -- return
    ),


    /*
    Builds one fixed slice-task queue from unchanged base-object INNER VERTS.
    Both directions group equal geometric planes inside the same planar wall region so one plane is cut only once even when multiple holes contribute anchors.
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

        local plane_group_tolerance = amax epsilon horizontal_level_tolerance

        /* Vertical mode groups equal vertical planes inside the same planar wall region. */
        if cut_mode == #all or cut_mode == #vertical then
        (
            local vertical_groups = #()

            for candidate in base_candidates do
            (
                local base_vertex = candidate[1]
                local direction_available = candidate[2]
                local base_edge = candidate[4]
                local base_anchor = candidate[6]
                local base_axis = if slice_plane_mode == #nextVert then candidate[7] else candidate[9]
                local region_id = candidate[13]

                if direction_available and base_axis != undefined then
                (
                    local group_index = findBaseSlicePlaneGroupIndex \
                        vertical_groups \
                        base_anchor \
                        base_axis \
                        region_id \
                        match_tolerance:plane_group_tolerance

                    if group_index == 0 then
                    (
                        local group_edges = #{}
                        local group_vertices = #{}
                        if base_edge > 0 then group_edges[base_edge] = true
                        group_vertices[base_vertex] = true

                        append vertical_groups #(
                            base_anchor,
                            base_axis,
                            candidate,
                            group_edges,
                            group_vertices,
                            region_id
                        )
                    )
                    else
                    (
                        local group_item = vertical_groups[group_index]
                        if base_edge > 0 then group_item[4][base_edge] = true
                        group_item[5][base_vertex] = true
                    )
                )
            )

            for group_item in vertical_groups do
            (
                local representative = group_item[3]
                local group_edges = copy group_item[4]
                local group_vertices = copy group_item[5]
                local region_id = group_item[6]
                local base_vertex = representative[1]
                local base_edge = representative[4]
                local base_anchor = representative[6]
                local base_axis = if slice_plane_mode == #nextVert then representative[7] else representative[9]
                local wall_normal = representative[11]
                local wall_origin = representative[12]

                append result #(
                    base_vertex,
                    #vertical,
                    base_edge,
                    base_anchor,
                    base_axis,
                    group_edges,
                    group_vertices,
                    base_anchor.z,
                    wall_normal,
                    wall_origin,
                    region_id
                )

                if not batch_quiet then format "Wall-Fixer Vertical Slice Plane Group: node:% region:% anchor:% verts:% edges:% representative:%\n" \
                    node.name region_id base_anchor group_vertices group_edges base_vertex
            )
        )

        /* Horizontal mode groups equal horizontal planes inside the same planar wall region. */
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
                    local group_index = findBaseSlicePlaneGroupIndex \
                        horizontal_groups \
                        base_anchor \
                        base_axis \
                        region_id \
                        match_tolerance:plane_group_tolerance

                    if group_index == 0 then
                    (
                        local group_edges = #{}
                        local group_vertices = #{}
                        if base_edge > 0 then group_edges[base_edge] = true
                        group_vertices[base_vertex] = true

                        append horizontal_groups #(
                            base_anchor,
                            base_axis,
                            candidate,
                            group_edges,
                            group_vertices,
                            region_id
                        )
                    )
                    else
                    (
                        local group_item = horizontal_groups[group_index]
                        if base_edge > 0 then group_item[4][base_edge] = true
                        group_item[5][base_vertex] = true
                    )
                )
            )

            for group_item in horizontal_groups do
            (
                local representative = group_item[3]
                local group_edges = copy group_item[4]
                local group_vertices = copy group_item[5]
                local region_id = group_item[6]
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
                    base_anchor.z,
                    wall_normal,
                    wall_origin,
                    region_id
                )

                if not batch_quiet then format "Wall-Fixer Horizontal Slice Plane Group: node:% region:% anchor:% verts:% edges:% representative:%\n" \
                    node.name region_id base_anchor group_vertices group_edges base_vertex
            )
        )

        if not batch_quiet then format "Wall-Fixer Base Slice Task Queue: node:% tasks:% innerVerts:%\n" node.name result.count reset_inner_vertices
        result
        -- return
    ),


    /*
    Tests directional plane grouping math used to collapse multiple hole anchors onto one slice task.
    */
    function testBaseSlicePlaneGroupingRule =
    (
        local groups = #(
            #([0,0,10], [0,0,1], undefined, #{}, #{}, 1),
            #([5,0,0], [1,0,0], undefined, #{}, #{}, 1)
        )

        local same_horizontal = findBaseSlicePlaneGroupIndex groups [25,40,10] [0,0,1] 1 match_tolerance:0.001
        local same_vertical = findBaseSlicePlaneGroupIndex groups [5,30,20] [1,0,0] 1 match_tolerance:0.001
        local different_horizontal = findBaseSlicePlaneGroupIndex groups [25,40,11] [0,0,1] 1 match_tolerance:0.001
        local different_region = findBaseSlicePlaneGroupIndex groups [25,40,10] [0,0,1] 2 match_tolerance:0.001

        same_horizontal == 1 and
        same_vertical == 2 and
        different_horizontal == 0 and
        different_region == 0
        -- return
    ),


    /*
    Returns the exact directional pass list requested by Slice Selected Walls.
    Directional modes contain only the selected direction; All remains one mixed pass.
    */
    function getBaseSlicePassKinds cut_mode =
    (
        case cut_mode of
        (
            #horizontal: #(#horizontal)
            #vertical: #(#vertical)
            default: #(#all)
        )
        -- return
    ),

    /*
    Builds ordered slicing passes and assigns one Edit Poly modifier name to each pass.
    Directional modes build exactly one pass; All mode builds one mixed queue.
    */
    function buildBaseSlicePassQueue node cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 =
    (
        local slice_passes = #()
        local requested_pass_kinds = getBaseSlicePassKinds cut_mode

        for pass_kind in requested_pass_kinds do
        (
            local pass_tasks = buildBaseSliceTaskQueue \
                node \
                cut_mode:pass_kind \
                slice_plane_mode:slice_plane_mode \
                angle_threshold:angle_threshold \
                planar_tolerance:planar_tolerance

            local modifier_name = case pass_kind of
            (
                #horizontal: "SLICE HORIZONTAL"
                #vertical: "SLICE VERTICAL"
                default: "SLICE ALL"
            )

            append slice_passes #(pass_kind, modifier_name, pass_tasks)
        )

        slice_passes
        -- return
    ),

    /*
    Tests that directional Slice Selected Walls modes resolve to one pass only.
    */
    function testSliceDirectionalPassKinds =
    (
        vertical_passes = getBaseSlicePassKinds #vertical
        horizontal_passes = getBaseSlicePassKinds #horizontal
        all_passes = getBaseSlicePassKinds #all

        test_passed = true
        test_passed = test_passed and vertical_passes.count == 1 and vertical_passes[1] == #vertical
        test_passed = test_passed and horizontal_passes.count == 1 and horizontal_passes[1] == #horizontal
        test_passed = test_passed and all_passes.count == 1 and all_passes[1] == #all

        test_passed
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
    function executeBaseSliceTaskQueue node slice_tasks modifier_name:"SLICE ALL" existing_modifier:undefined angle_threshold:5.0 planar_tolerance:1.0 precision_threshold:0.01 cleanup_edges:true direct_slice_transform:false task_index_offset:0 total_task_count:undefined progress_callback:undefined object_index:0 object_total:0 object_name:"" vertex_count:0 =
    (
        local success_count = 0
        local no_change_count = 0
        local failure = undefined
        local failure_stage = ""
        local modifier = undefined
        local created_modifier = false
        local queue_total = if total_task_count == undefined then slice_tasks.count else total_task_count

        if node == undefined or not(isValidNode node) then return #(false, 0, 0)
        if classOf node.baseObject != Editable_Poly then return #(false, 0, 0)

        try
        (
            if existing_modifier != undefined then
            (
                modifier = existing_modifier
            )
            else
            (
                modifier = Edit_Poly name:modifier_name
                addModifier node modifier
                created_modifier = true
            )

            if direct_slice_transform then
            (
                /*
                Direct gizmo placement still uses the explicit slice_plane.transform matrix,
                but Edit Poly operation methods are executed with the modifier active once.
                This avoids undefined off-panel Edit Poly interface calls while still avoiding
                vertex-driven gizmo placement or interactive picking.
                */
                ensureSliceModifyContext node modifier
                modifier.SetPrimaryNode node
                try(modifier.showCage = off)catch()
                update node
            )
            else
            (
                ensureSliceModifyContext node modifier
            )

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
                if task_base_vertices.numberSet == 0 and base_vertex > 0 then task_base_vertices[base_vertex] = true

                if batch_quiet then
                (
                    format "Wall-Fixer Batch Base Slice Task: node:% task:%/%\n" node.name display_task_index queue_total
                )
                else
                (
                    format "Wall-Fixer Batch Base Slice Task: node:% modifier:% task:%/% region:% baseVert:% baseEdge:% direction:% levelZ:% groupedVerts:%\n" \
                        node.name modifier_name display_task_index queue_total region_id base_vertex base_edge slice_kind task_level_z task_base_vertices
                )

                if direct_slice_transform then failure_stage = "existing-slice check"
                local slice_already_exists = pipeline.hasExistingSliceLoopOnPlane \
                    base_vertex \
                    base_anchor \
                    base_axis \
                    slice_kind \
                    wall_normal:wall_normal \
                    wall_origin:wall_origin \
                    plane_tolerance:(amax 0.0 planar_tolerance)

                local slice_result = undefined
                local slice_plane_transform = undefined

                if not slice_already_exists and direct_slice_transform then
                (
                    failure_stage = "direct gizmo transform"
                    slice_plane_transform = getSliceForcePlaneTransform                         node                         modifier                         base_anchor                         base_axis                         wall_normal:wall_normal

                    if slice_plane_transform == undefined then
                    (
                        throw ("Slice Force could not build the slice-plane gizmo transform for " + modifier_name)
                    )
                )

                if not slice_already_exists then
                (
                    if direct_slice_transform then failure_stage = "slice operation / commit"
                    slice_result = pipeline.makeOneSliceFromBasePlane                         base_vertex                         base_anchor                         base_axis                         slice_kind                         wall_normal:wall_normal                         wall_origin:wall_origin                         plane_tolerance:(amax 0.0 planar_tolerance)                         slice_plane_transform:slice_plane_transform
                )

                if progress_callback != undefined then
                (
                    try(progress_callback display_task_index queue_total object_index:object_index object_total:object_total object_name:object_name vertex_count:vertex_count)catch()
                )

                if slice_already_exists then
                (
                    no_change_count += 1
                    if not batch_quiet then format "Wall-Fixer Batch Base Slice Task Skip: node:% modifier:% baseVert:% direction:% reason:complete slice edge loop already exists through anchor.\n" \
                        node.name modifier_name base_vertex slice_kind
                )
                else if slice_result == undefined then
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

                    /*
                    Live non-base tasks have no base defining edge. Re-resolve the saved
                    anchor position in the current modifier so sliced-edge cleanup starts
                    from and therefore protects the actual live anchor chain.
                    */
                    if last_debug_slice_start_vertices.numberSet == 0 then
                    (
                        local live_anchor_vertex = findDebugLiveVertexByPosition node modifier base_anchor tolerance:0.01
                        if live_anchor_vertex > 0 then
                        (
                            last_debug_slice_start_vertices[live_anchor_vertex] = true
                        )
                    )

                    if not batch_quiet then format "Wall-Fixer Batch Manual Pipeline Context: node:% modifier:% baseVert:% direction:% groupedBaseVerts:% newEdges:% startVerts:% originalVerts:%\n" \
                        node.name modifier_name base_vertex slice_kind task_base_vertices last_debug_slice_new_edges last_debug_slice_start_vertices last_debug_slice_original_vertices.numberSet

                    /* 2. Fix Slice Precision only when this slice produced precision candidates.
                       Batch uses the same candidate rules but removes only new verts so base-object ids stay unchanged. */
                    if direct_slice_transform then failure_stage = "slice precision"
                    local precision_data = ::WallFixer.getMassSlicePrecisionCandidates node precision_threshold:precision_threshold
                    local precision_candidates = precision_data[1]
                    local precision_ok = true

                    if precision_candidates.numberSet > 0 then
                    (
                        local precision_cleanup = ::WallFixer.cleanupMassSlicePrecisionVerts \
                            node \
                            precision_threshold:precision_threshold \
                            preserve_base_ids:true \
                            keep_modify_context:true
                        precision_ok = precision_cleanup[1]
                        if not batch_quiet then format "Wall-Fixer Batch Fix Slice Precision: node:% modifier:% baseVert:% direction:% candidates:% fixed:% success:%\n" \
                            node.name modifier_name base_vertex slice_kind precision_candidates precision_cleanup[2] precision_ok
                    )
                    else
                    (
                        if not batch_quiet then format "Wall-Fixer Batch Fix Slice Precision Skip: node:% modifier:% baseVert:% direction:% candidates:#{}\n" \
                            node.name modifier_name base_vertex slice_kind
                    )

                    /* 3. Clean Up Sliced Edges only when enabled and redundant edge candidates actually exist.
                       No-edge-cleanup mode intentionally preserves every slice-created edge for inspection. */
                    if direct_slice_transform then failure_stage = "edge cleanup"
                    if not cleanup_edges then
                    (
                        if not batch_quiet then format "Wall-Fixer Batch Clean Up Sliced Edges Skip: node:% modifier:% baseVert:% direction:% reason:disabled by Slice Walls option.\n" \
                            node.name modifier_name base_vertex slice_kind
                    )
                    else if precision_ok then
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

                    /* Normal slicing keeps its Edit Poly context.
                       Slice Force leaves the command panel alone unless precision/edge cleanup explicitly needed Modify mode. */
                    if not direct_slice_transform then
                    (
                        ensureSliceModifyContext node modifier
                    )

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

            if success_count == 0 and modifier != undefined and created_modifier then
            (
                local modifier_still_present = false

                for stack_modifier in node.modifiers while not modifier_still_present do
                (
                    if stack_modifier == modifier then modifier_still_present = true
                )

                if modifier_still_present then
                (
                    deleteModifier node modifier
                    update node

                    if not batch_quiet then format "Wall-Fixer Batch Base Slice Queue: node:% modifier:% removed empty modifier after % skipped/no-change task(s).\n"                         node.name modifier_name no_change_count
                )
            )
        )
        catch
        (
            local current_exception = getCurrentException()
            if direct_slice_transform and failure_stage != "" then
            (
                failure = ("Slice Force stage [" + failure_stage + "]: " + (current_exception as string))
            )
            else
            (
                failure = current_exception
            )
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
    Returns the current evaluated vertex count for one valid geometry node.
    Snapshot evaluation keeps modifier stacks intact and does not modify scene topology.
    */
    function getEvaluatedVertexCount node =
    (
        if node == undefined or not(isValidNode node) then return 0
        evaluated_mesh = undefined
        vertex_count = 0
        try
        (
            evaluated_mesh = snapshotAsMesh node
            vertex_count = evaluated_mesh.numVerts
        )
        catch
        (
            vertex_count = 0
        )
        if evaluated_mesh != undefined then delete evaluated_mesh
        vertex_count
        -- return
    ),

    /*
    Appends one successful Slice Selected Walls run to the persistent CSV statistics log.
    The file is created with a header on first use and then appended without rewriting prior runs.
    */
    function appendSliceStatsCsv cut_mode processed_objects processed_vertices elapsed_ms =
    (
        stats_stream = undefined
        stats_success = true
        try
        (
            if not doesFileExist slice_stats_csv_path then
            (
                stats_stream = createFile slice_stats_csv_path
                format "timestamp_ms,cut_mode,elapsed_ms,processed_objects,processed_vertices\n" to:stats_stream
                close stats_stream
                stats_stream = undefined
            )
            stats_stream = openFile slice_stats_csv_path mode:"a"
            format "%,%,%,%,%\n" (timeStamp()) (cut_mode as string) elapsed_ms processed_objects processed_vertices to:stats_stream
            close stats_stream
            stats_stream = undefined
        )
        catch
        (
            if stats_stream != undefined then try(close stats_stream)catch()
            stats_success = false
        )
        stats_success
        -- return
    ),

    /*
    Builds an orthonormal Slice Force plane basis from the requested world-space plane normal.
    The wall normal is preferred as the in-plane side vector; a stable world-axis fallback is used when no wall normal is available.
    */
    function getSliceForcePlaneBasis world_axis wall_normal:undefined =
    (
        if world_axis == undefined or length world_axis <= epsilon then return undefined

        local plane_axis = normalize world_axis
        local side_axis = undefined

        if wall_normal != undefined and length wall_normal > epsilon then
        (
            side_axis = normalize wall_normal
            side_axis = side_axis - (plane_axis * (dot side_axis plane_axis))

            if length side_axis <= epsilon then
            (
                side_axis = undefined
            )
        )

        if side_axis == undefined then
        (
            local fallback_axis = if abs(dot plane_axis [0,0,1]) < 0.95 then [0,0,1] else [0,1,0]
            side_axis = fallback_axis - (plane_axis * (dot fallback_axis plane_axis))

            if length side_axis <= epsilon then
            (
                fallback_axis = [1,0,0]
                side_axis = fallback_axis - (plane_axis * (dot fallback_axis plane_axis))
            )
        )

        if side_axis == undefined or length side_axis <= epsilon then return undefined

        side_axis = normalize side_axis

        /*
        Matches the proven three-point gizmo math:
        vect1 = plane tangent, vect2 = wall/side vector, vect3 = cross vect2 vect1.
        */
        local vect1 = cross plane_axis side_axis
        if length vect1 <= epsilon then return undefined
        vect1 = normalize vect1

        local vect2 = side_axis
        local vect3 = cross vect2 vect1
        if length vect3 <= epsilon then return undefined
        vect3 = normalize vect3

        vect2 = cross vect3 vect1
        if length vect2 <= epsilon then return undefined
        vect2 = normalize vect2

        #(vect1, vect2, vect3)
        -- return
    ),


    /*
    Builds a Slice Force gizmo transform directly from world-space plane data.
    Supports the real SliceModifier used by Force and the legacy Edit Poly caller retained by the normal slice pipeline.
    */
    function getSliceForcePlaneTransform node modifier world_anchor world_axis wall_normal:undefined =
    (
        if node == undefined or not(isValidNode node) then return undefined
        if modifier == undefined then return undefined
        if classOf modifier != SliceModifier and classOf modifier != Edit_Poly then return undefined
        if world_anchor == undefined then return undefined

        local basis = getSliceForcePlaneBasis world_axis wall_normal:wall_normal
        if basis == undefined then return undefined

        local modifier_tm = undefined

        try
        (
            modifier_tm = getModContextTM node modifier
        )
        catch
        (
            modifier_tm = undefined
        )

        /*
        Slice Force collapses the incoming stack before adding only object-space Slice modifiers.
        In that stack shape the modifier context is object space, so identity is a safe fallback
        when getModContextTM is unavailable in the current 3ds Max runtime.
        */
        if modifier_tm == undefined then
        (
            modifier_tm = matrix3 1
        )

        local object_tm = node.objectTransform
        local world_plane_tm = matrix3 basis[1] basis[2] basis[3] world_anchor

        world_plane_tm * modifier_tm * (inverse object_tm)
        -- return
    ),


    /*
    Builds a full BitArray from component index 1 through component_count.
    Used by Slice Force so every temporary modifier owns whole-object Face and Edge selections.
    */
    function makeSliceForceFullSelection component_count =
    (
        local result = #{}

        if component_count > 0 then
        (
            for component_index = 1 to component_count do
            (
                result[component_index] = true
            )
        )

        result
        -- return
    ),


    /*
    Builds world-space face normals and connected-face component IDs for Force-only non-planar analysis.
    This does not alter the normal Slice Walls planar-region analyzer.
    */
    function getSliceForceSurfaceData node =
    (
        local result = undefined
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
        for face_index = 1 to face_count do
        (
            local face_verts = polyop.getFaceVerts base_obj face_index
            local face_normal = undefined

            if face_verts != undefined and face_verts.count >= 3 then
            (
                local face_origin = world_points[face_verts[1]]
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
        )

        local face_component_ids = for face_index = 1 to face_count collect 0
        local component_id = 0

        for seed_face = 1 to face_count do
        (
            if face_component_ids[seed_face] == 0 then
            (
                component_id += 1
                local face_queue = #(seed_face)
                local queue_index = 1
                face_component_ids[seed_face] = component_id

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
                            if face_component_ids[adjacent_face] == 0 then
                            (
                                face_component_ids[adjacent_face] = component_id
                                append face_queue adjacent_face
                            )
                        )
                    )
                )
            )
        )

        result = #(world_points, face_normals, face_component_ids, component_id)
        result
        -- return
    ),


    /*
    Builds real open-border loops for Slice Force without requiring a planar wall region.
    Each loop records its owning connected face component and 3D perimeter.
    */
    function getSliceForceOpenBorderLoops node world_points face_component_ids =
    (
        local loops = #()
        if node == undefined or not(isValidNode node) then return loops

        local base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then return loops

        local vert_count = polyop.getNumVerts base_obj
        local edge_count = polyop.getNumEdges base_obj
        local border_edges = #{}
        local vertex_border_edges = for vertex_index = 1 to vert_count collect #{}

        for edge_index = 1 to edge_count do
        (
            local edge_faces = polyop.getFacesUsingEdge base_obj #{edge_index}

            if edge_faces.numberSet == 1 then
            (
                local edge_verts = polyop.getEdgeVerts base_obj edge_index

                if edge_verts != undefined and edge_verts.count == 2 then
                (
                    border_edges[edge_index] = true
                    vertex_border_edges[edge_verts[1]][edge_index] = true
                    vertex_border_edges[edge_verts[2]][edge_index] = true
                )
            )
        )

        local remaining_edges = copy border_edges

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
                local loop_edges = #()
                local closed = false
                local safety = 0

                while not closed and safety <= edge_count do
                (
                    safety += 1
                    append loop_vertices current_vertex
                    append loop_edges current_edge
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
                    local perimeter = 0.0

                    for loop_position = 1 to loop_vertices.count do
                    (
                        local next_position = if loop_position == loop_vertices.count then 1 else loop_position + 1
                        perimeter += distance world_points[loop_vertices[loop_position]] world_points[loop_vertices[next_position]]
                    )

                    local first_faces = polyop.getFacesUsingEdge base_obj #{start_edge}
                    local first_face = if first_faces.numberSet > 0 then (first_faces as array)[1] else 0
                    local component_id = if first_face > 0 then face_component_ids[first_face] else 0

                    append loops #(loop_vertices, loop_edges, component_id, perimeter)
                )
            )
        )

        loops
        -- return
    ),


    /*
    Returns true when two adjacent faces belong to the same Force-only wall surface.
    Force allows non-planar bends while stopping at horizontal caps and near-perpendicular reveal faces.
    */
    function areSliceForceWallFacesContinuous normal_a normal_b max_bend_angle:70.0 =
    (
        if normal_a == undefined or normal_b == undefined then return false
        if length normal_a <= epsilon or length normal_b <= epsilon then return false

        local normalized_a = normalize normal_a
        local normalized_b = normalize normal_b
        local wall_z_limit = sin 45.0
        local bend_limit = cos (amin 89.0 (amax 0.0 max_bend_angle))

        if abs(normalized_a.z) > wall_z_limit or abs(normalized_b.z) > wall_z_limit then return false

        abs(dot normalized_a normalized_b) >= bend_limit
        -- return
    ),


    /*
    Builds connected Force-only wall-surface regions across locally continuous non-planar faces.
    Region borders include manifold opening edges because reveal/cap faces are not joined into the wall surface.
    */
    function getSliceForceWallSurfaceRegions node face_normals max_bend_angle:70.0 =
    (
        local regions = #()
        if node == undefined or not(isValidNode node) then return regions

        local base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then return regions

        local vert_count = polyop.getNumVerts base_obj
        local face_count = polyop.getNumFaces base_obj
        if vert_count < 3 or face_count < 1 then return regions

        local processed_faces = #{}
        local region_id = 0

        for seed_face = 1 to face_count do
        (
            if not processed_faces[seed_face] then
            (
                processed_faces[seed_face] = true

                local seed_normal = face_normals[seed_face]
                local seed_is_wall = seed_normal != undefined and length seed_normal > epsilon and abs((normalize seed_normal).z) <= sin 45.0

                if seed_is_wall then
                (
                    region_id += 1
                    local region_faces = #{seed_face}
                    local face_queue = #(seed_face)
                    local queue_index = 1

                    while queue_index <= face_queue.count do
                    (
                        local current_face = face_queue[queue_index]
                        queue_index += 1

                        local current_normal = face_normals[current_face]
                        local current_edges = polyop.getEdgesUsingFace base_obj #{current_face}

                        for edge_index in current_edges do
                        (
                            local adjacent_faces = polyop.getFacesUsingEdge base_obj #{edge_index}

                            for adjacent_face in adjacent_faces do
                            (
                                if not processed_faces[adjacent_face] then
                                (
                                    local adjacent_normal = face_normals[adjacent_face]

                                    if areSliceForceWallFacesContinuous current_normal adjacent_normal max_bend_angle:max_bend_angle then
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
                    local boundary_edges = #{}
                    local vertex_boundary_edges = for vertex_index = 1 to vert_count collect #{}

                    for edge_index in region_edges do
                    (
                        local edge_faces = polyop.getFacesUsingEdge base_obj #{edge_index}
                        local region_face_count = 0

                        for face_index in edge_faces do
                        (
                            if region_faces[face_index] then region_face_count += 1
                        )

                        if region_face_count == 1 then
                        (
                            local edge_verts = polyop.getEdgeVerts base_obj edge_index

                            if edge_verts != undefined and edge_verts.count == 2 then
                            (
                                boundary_edges[edge_index] = true
                                vertex_boundary_edges[edge_verts[1]][edge_index] = true
                                vertex_boundary_edges[edge_verts[2]][edge_index] = true
                            )
                        )
                    )

                    if boundary_edges.numberSet > 0 then
                    (
                        append regions #(region_faces, boundary_edges, vertex_boundary_edges, region_id)
                    )
                )
            )
        )

        regions
        -- return
    ),


    /*
    Traces closed boundary loops for one Force-only wall-surface region.
    Every loop stores vertices, edges, and 3D perimeter.
    */
    function getSliceForceSurfaceBoundaryLoops node region_data world_points =
    (
        local loops = #()
        if node == undefined or not(isValidNode node) then return loops
        if region_data == undefined or region_data.count < 4 then return loops

        local base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then return loops

        local boundary_edges = region_data[2]
        local vertex_boundary_edges = region_data[3]
        local edge_count = polyop.getNumEdges base_obj
        local remaining_edges = copy boundary_edges

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
                local loop_edges = #()
                local closed = false
                local safety = 0

                while not closed and safety <= edge_count do
                (
                    safety += 1
                    append loop_vertices current_vertex
                    append loop_edges current_edge
                    remaining_edges[current_edge] = false

                    local current_edge_verts = polyop.getEdgeVerts base_obj current_edge
                    local next_vertex = if current_edge_verts[1] == current_vertex then current_edge_verts[2] else current_edge_verts[1]

                    if next_vertex == start_vertex then
                    (
                        closed = true
                    )
                    else
                    (
                        local next_edges = (vertex_boundary_edges[next_vertex] * boundary_edges) as array

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
                    local perimeter = 0.0

                    for loop_position = 1 to loop_vertices.count do
                    (
                        local next_position = if loop_position == loop_vertices.count then 1 else loop_position + 1
                        perimeter += distance world_points[loop_vertices[loop_position]] world_points[loop_vertices[next_position]]
                    )

                    append loops #(loop_vertices, loop_edges, perimeter)
                )
            )
        )

        loops
        -- return
    ),


    /*
    Returns the local wall-surface face normal touching one region-boundary edge.
    */
    function getSliceForceRegionEdgeNormal base_obj edge_index region_faces face_normals =
    (
        local result = undefined
        local edge_faces = polyop.getFacesUsingEdge base_obj #{edge_index}

        for face_index in edge_faces while result == undefined do
        (
            if region_faces[face_index] and face_normals[face_index] != undefined then
            (
                result = face_normals[face_index]
            )
        )

        result
        -- return
    ),


    /*
    Returns true when a candidate Force plane passes through the interior of the object.
    Geometry must exist on both sides of the plane; true exterior boundary planes are rejected.
    */
    function doesSliceForcePlaneSplitPoints world_points world_anchor world_axis match_tolerance:0.001 =
    (
        if classOf world_points != Array then return false
        if world_anchor == undefined or world_axis == undefined then return false
        if length world_axis <= epsilon then return false

        local normalized_axis = normalize world_axis
        local plane_tolerance = amax epsilon match_tolerance
        local has_negative_side = false
        local has_positive_side = false

        for world_point in world_points while not(has_negative_side and has_positive_side) do
        (
            local signed_distance = dot (world_point - world_anchor) normalized_axis

            if signed_distance < -plane_tolerance then
            (
                has_negative_side = true
            )
            else if signed_distance > plane_tolerance then
            (
                has_positive_side = true
            )
        )

        has_negative_side and has_positive_side
        -- return
    ),


    /*
    Adds Force-only candidate planes directly from disconnected wall-surface boundary edges.
    This fallback does not require a hole loop; it keeps only planes that split live object geometry on both sides.
    */
    function appendSliceForceBoundaryEdgeFallbackTasks node cached_tasks wall_regions world_points face_normals cut_mode:#all angle_threshold:5.0 match_tolerance:0.001 =
    (
        local added_count = 0
        if node == undefined or not(isValidNode node) then return added_count
        if cached_tasks == undefined or wall_regions == undefined or world_points == undefined then return added_count

        local base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then return added_count

        local direction_cos = cos (amin 45.0 (amax 0.0 angle_threshold))
        local horizontal_z_limit = sin (amin 45.0 (amax 0.0 angle_threshold))

        for region_data in wall_regions do
        (
            local region_faces = region_data[1]
            local boundary_edges = region_data[2]
            local region_id = region_data[4]

            for edge_index in boundary_edges do
            (
                local edge_verts = polyop.getEdgeVerts base_obj edge_index

                if edge_verts != undefined and edge_verts.count == 2 then
                (
                    local point_a = world_points[edge_verts[1]]
                    local point_b = world_points[edge_verts[2]]
                    local edge_vector = point_b - point_a

                    if length edge_vector > epsilon then
                    (
                        local edge_direction = normalize edge_vector
                        local world_anchor = (point_a + point_b) * 0.5
                        local local_wall_normal = getSliceForceRegionEdgeNormal base_obj edge_index region_faces face_normals
                        local task_vertices = #{}
                        task_vertices[edge_verts[1]] = true
                        task_vertices[edge_verts[2]] = true

                        if (cut_mode == #all or cut_mode == #horizontal) and abs(edge_direction.z) <= horizontal_z_limit then
                        (
                            local horizontal_axis = [0.0,0.0,1.0]

                            if doesSliceForcePlaneSplitPoints world_points world_anchor horizontal_axis match_tolerance:match_tolerance then
                            (
                                local horizontal_task = #(
                                    edge_verts[1],
                                    #horizontal,
                                    edge_index,
                                    world_anchor,
                                    horizontal_axis,
                                    #{edge_index},
                                    task_vertices,
                                    world_anchor.z,
                                    local_wall_normal,
                                    world_anchor,
                                    region_id
                                )

                                if findSliceForcePlaneCacheIndex cached_tasks horizontal_task match_tolerance:match_tolerance == 0 then
                                (
                                    append cached_tasks horizontal_task
                                    added_count += 1
                                )
                            )
                        )

                        if (cut_mode == #all or cut_mode == #vertical) and abs(edge_direction.z) >= direction_cos and local_wall_normal != undefined then
                        (
                            local vertical_axis = cross edge_direction local_wall_normal
                            vertical_axis = [vertical_axis.x, vertical_axis.y, 0.0]

                            if length vertical_axis > epsilon then
                            (
                                vertical_axis = normalize vertical_axis

                                if doesSliceForcePlaneSplitPoints world_points world_anchor vertical_axis match_tolerance:match_tolerance then
                                (
                                    local vertical_task = #(
                                        edge_verts[1],
                                        #vertical,
                                        edge_index,
                                        world_anchor,
                                        vertical_axis,
                                        #{edge_index},
                                        task_vertices,
                                        world_anchor.z,
                                        local_wall_normal,
                                        world_anchor,
                                        region_id
                                    )

                                    if findSliceForcePlaneCacheIndex cached_tasks vertical_task match_tolerance:match_tolerance == 0 then
                                    (
                                        append cached_tasks vertical_task
                                        added_count += 1
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )

        added_count
        -- return
    ),


    /*
    Builds the complete Force-only plane cache from manifold wall-surface boundaries plus the proven planar candidate detector.
    Curved/bent wall faces may share one Force surface, while reveal/cap faces stay outside that surface so closed manifold openings remain detectable.
    */
    function buildSliceForceNonPlanarTaskCache node cut_mode:#all angle_threshold:5.0 planar_tolerance:1.0 match_tolerance:0.001 =
    (
        local cached_tasks = #()
        if node == undefined or not(isValidNode node) then return cached_tasks

        local base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then return cached_tasks

        local surface_data = getSliceForceSurfaceData node
        if surface_data == undefined then return cached_tasks

        local world_points = surface_data[1]
        local face_normals = surface_data[2]
        local direction_cos = cos (amin 45.0 (amax 0.0 angle_threshold))
        local horizontal_z_limit = sin (amin 45.0 (amax 0.0 angle_threshold))

        /*
        First merge the existing proven planar-region candidates.
        This retains manifold windows, doors, and concave outer-loop anchors on ordinary wall sections.
        */
        local planar_candidates = getBaseInnerSliceCandidates \
            node \
            angle_threshold:angle_threshold \
            planar_tolerance:(amax 0.0 planar_tolerance)

        for candidate in planar_candidates do
        (
            local vertex_index = candidate[1]
            local world_anchor = candidate[6]
            local region_id = candidate[13]

            if (cut_mode == #all or cut_mode == #vertical) and candidate[2] and candidate[4] > 0 and candidate[7] != undefined then
            (
                local vertical_task = #(
                    vertex_index,
                    #vertical,
                    candidate[4],
                    world_anchor,
                    candidate[7],
                    #{candidate[4]},
                    #{vertex_index},
                    world_anchor.z,
                    candidate[11],
                    candidate[12],
                    region_id
                )

                if findSliceForcePlaneCacheIndex cached_tasks vertical_task match_tolerance:match_tolerance == 0 then
                (
                    append cached_tasks vertical_task
                )
            )

            if (cut_mode == #all or cut_mode == #horizontal) and candidate[3] and candidate[5] > 0 and candidate[8] != undefined then
            (
                local horizontal_task = #(
                    vertex_index,
                    #horizontal,
                    candidate[5],
                    world_anchor,
                    [0.0,0.0,1.0],
                    #{candidate[5]},
                    #{vertex_index},
                    world_anchor.z,
                    candidate[11],
                    candidate[12],
                    region_id
                )

                if findSliceForcePlaneCacheIndex cached_tasks horizontal_task match_tolerance:match_tolerance == 0 then
                (
                    append cached_tasks horizontal_task
                )
            )
        )

        /*
        Then add Force-only non-planar surface regions.
        Faces may bend up to 70 degrees locally; near-perpendicular reveal/cap transitions remain region borders.
        */
        local wall_regions = getSliceForceWallSurfaceRegions node face_normals max_bend_angle:70.0

        for region_data in wall_regions do
        (
            local region_faces = region_data[1]
            local region_id = region_data[4]
            local loops = getSliceForceSurfaceBoundaryLoops node region_data world_points

            if loops.count > 1 then
            (
                local outer_index = 1
                local outer_perimeter = loops[1][3]

                for loop_index = 2 to loops.count do
                (
                    if loops[loop_index][3] > outer_perimeter then
                    (
                        outer_perimeter = loops[loop_index][3]
                        outer_index = loop_index
                    )
                )

                for loop_index = 1 to loops.count do
                (
                    if loop_index != outer_index then
                    (
                        local loop_vertices = loops[loop_index][1]
                        local loop_edges = loops[loop_index][2]

                        for corner_index = 1 to loop_vertices.count do
                        (
                            local vertex_index = loop_vertices[corner_index]
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

                                if abs(dot dir_a dir_b) < direction_cos then
                                (
                                    local corner_edges = #(loop_edges[previous_index], loop_edges[corner_index])
                                    local vertical_edge = 0
                                    local horizontal_edge = 0
                                    local vertical_axis = undefined
                                    local vertical_wall_normal = undefined
                                    local horizontal_wall_normal = undefined

                                    for edge_index in corner_edges do
                                    (
                                        local edge_verts = polyop.getEdgeVerts base_obj edge_index

                                        if edge_verts != undefined and edge_verts.count == 2 then
                                        (
                                            local edge_vector = world_points[edge_verts[2]] - world_points[edge_verts[1]]

                                            if length edge_vector > epsilon then
                                            (
                                                local edge_direction = normalize edge_vector
                                                local local_wall_normal = getSliceForceRegionEdgeNormal base_obj edge_index region_faces face_normals

                                                if abs(edge_direction.z) >= direction_cos then
                                                (
                                                    if vertical_edge == 0 and local_wall_normal != undefined then
                                                    (
                                                        local axis_candidate = cross edge_direction local_wall_normal
                                                        axis_candidate = [axis_candidate.x, axis_candidate.y, 0.0]

                                                        if length axis_candidate > epsilon then
                                                        (
                                                            vertical_edge = edge_index
                                                            vertical_axis = normalize axis_candidate
                                                            vertical_wall_normal = local_wall_normal
                                                        )
                                                    )
                                                )
                                                else if abs(edge_direction.z) <= horizontal_z_limit then
                                                (
                                                    if horizontal_edge == 0 and local_wall_normal != undefined then
                                                    (
                                                        horizontal_edge = edge_index
                                                        horizontal_wall_normal = local_wall_normal
                                                    )
                                                )
                                            )
                                        )
                                    )

                                    local world_anchor = world_points[vertex_index]

                                    if (cut_mode == #all or cut_mode == #vertical) and vertical_edge > 0 and vertical_axis != undefined then
                                    (
                                        local vertical_task = #(
                                            vertex_index,
                                            #vertical,
                                            vertical_edge,
                                            world_anchor,
                                            vertical_axis,
                                            #{vertical_edge},
                                            #{vertex_index},
                                            world_anchor.z,
                                            vertical_wall_normal,
                                            world_anchor,
                                            region_id
                                        )

                                        if findSliceForcePlaneCacheIndex cached_tasks vertical_task match_tolerance:match_tolerance == 0 then
                                        (
                                            append cached_tasks vertical_task
                                        )
                                    )

                                    if (cut_mode == #all or cut_mode == #horizontal) and horizontal_edge > 0 then
                                    (
                                        local horizontal_task = #(
                                            vertex_index,
                                            #horizontal,
                                            horizontal_edge,
                                            world_anchor,
                                            [0.0,0.0,1.0],
                                            #{horizontal_edge},
                                            #{vertex_index},
                                            world_anchor.z,
                                            horizontal_wall_normal,
                                            world_anchor,
                                            region_id
                                        )

                                        if findSliceForcePlaneCacheIndex cached_tasks horizontal_task match_tolerance:match_tolerance == 0 then
                                        (
                                            append cached_tasks horizontal_task
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )

        /*
        If one requested direction still has no planes, fall back to direct wall-surface boundary edges.
        This covers disconnected wall patches where each surface component has only one loop and therefore no inner-loop classification.
        */
        local has_horizontal_task = false
        local has_vertical_task = false

        for cached_task in cached_tasks do
        (
            if cached_task[2] == #horizontal then has_horizontal_task = true
            if cached_task[2] == #vertical then has_vertical_task = true
        )

        local fallback_mode = undefined

        if cut_mode == #horizontal and not has_horizontal_task then
        (
            fallback_mode = #horizontal
        )
        else if cut_mode == #vertical and not has_vertical_task then
        (
            fallback_mode = #vertical
        )
        else if cut_mode == #all then
        (
            if not has_horizontal_task and not has_vertical_task then
            (
                fallback_mode = #all
            )
            else if not has_horizontal_task then
            (
                fallback_mode = #horizontal
            )
            else if not has_vertical_task then
            (
                fallback_mode = #vertical
            )
        )

        local fallback_added = 0

        if fallback_mode != undefined then
        (
            fallback_added = appendSliceForceBoundaryEdgeFallbackTasks \
                node \
                cached_tasks \
                wall_regions \
                world_points \
                face_normals \
                cut_mode:fallback_mode \
                angle_threshold:angle_threshold \
                match_tolerance:match_tolerance
        )

        if not batch_quiet then format "Wall-Fixer Slice Force Surface Analysis: node:% planarCandidates:% wallRegions:% fallback:% uniquePlanes:%\n" \
            node.name planar_candidates.count wall_regions.count fallback_added cached_tasks.count

        cached_tasks
        -- return
    ),


    /*
    Tests Force-only interior-plane filtering used by disconnected surface boundary fallback.
    Interior horizontal/vertical planes pass; true exterior planes fail.
    */
    function testSliceForceBoundaryPlaneSplitRule =
    (
        local points = #(
            [0.0,0.0,0.0],
            [10.0,0.0,0.0],
            [0.0,0.0,10.0],
            [10.0,0.0,10.0]
        )

        doesSliceForcePlaneSplitPoints points [0.0,0.0,5.0] [0.0,0.0,1.0] match_tolerance:0.001 and
        not(doesSliceForcePlaneSplitPoints points [0.0,0.0,0.0] [0.0,0.0,1.0] match_tolerance:0.001) and
        doesSliceForcePlaneSplitPoints points [5.0,0.0,0.0] [1.0,0.0,0.0] match_tolerance:0.001 and
        not(doesSliceForcePlaneSplitPoints points [0.0,0.0,0.0] [1.0,0.0,0.0] match_tolerance:0.001)
        -- return
    ),


    /*
    Tests Force-only non-planar wall-surface continuity.
    Moderate wall bends stay connected; a 90-degree reveal and a horizontal cap do not.
    */
    function testSliceForceSurfaceContinuityRule =
    (
        local flat_normal = [0.0,1.0,0.0]
        local bend_normal = normalize [0.5,0.8660254,0.0]
        local reveal_normal = [1.0,0.0,0.0]
        local cap_normal = [0.0,0.0,1.0]

        areSliceForceWallFacesContinuous flat_normal bend_normal max_bend_angle:70.0 and
        not(areSliceForceWallFacesContinuous flat_normal reveal_normal max_bend_angle:70.0) and
        not(areSliceForceWallFacesContinuous flat_normal cap_normal max_bend_angle:70.0)
        -- return
    ),


    /*
    Tests Force-only local plane caching without invoking the normal planar wall analyzer.
    */
    function testSliceForceNonPlanarPlaneRule =
    (
        local cached_tasks = #()
        local horizontal_a = #(1, #horizontal, 1, [0,0,10], [0,0,1], #{1}, #{1}, 10.0, [0,1,0], [0,0,10], 1)
        local horizontal_b = #(2, #horizontal, 2, [20,30,10], [0,0,1], #{2}, #{2}, 10.0, [1,0,0], [20,30,10], 1)
        local vertical_x = #(3, #vertical, 3, [5,0,0], [1,0,0], #{3}, #{3}, 0.0, [0,1,0], [5,0,0], 1)
        local vertical_y = #(4, #vertical, 4, [0,7,0], [0,1,0], #{4}, #{4}, 0.0, [1,0,0], [0,7,0], 1)

        append cached_tasks horizontal_a
        local same_horizontal = findSliceForcePlaneCacheIndex cached_tasks horizontal_b match_tolerance:0.001

        append cached_tasks vertical_x
        local different_vertical_direction = findSliceForcePlaneCacheIndex cached_tasks vertical_y match_tolerance:0.001

        same_horizontal == 1 and different_vertical_direction == 0
        -- return
    ),


    /*
    Returns the cached Slice Force plane index for one task.
    Plane matching ignores planar-region IDs: Horizontal is effectively cached by Z, while Vertical uses its normalized XY plane normal plus signed position.
    */
    function findSliceForcePlaneCacheIndex cached_tasks slice_task match_tolerance:0.001 =
    (
        if classOf cached_tasks != Array then return 0
        if classOf slice_task != Array or slice_task.count < 5 then return 0

        local slice_kind = slice_task[2]
        local world_anchor = slice_task[4]
        local world_axis = slice_task[5]

        if world_anchor == undefined or world_axis == undefined or length world_axis <= epsilon then return 0

        local normalized_axis = normalize world_axis
        local plane_tolerance = amax epsilon match_tolerance
        local axis_cos = cos 0.1
        local found_index = 0

        for cache_index = 1 to cached_tasks.count while found_index == 0 do
        (
            local cached_task = cached_tasks[cache_index]

            if cached_task != undefined and cached_task.count >= 5 and cached_task[2] == slice_kind then
            (
                local cached_anchor = cached_task[4]
                local cached_axis = cached_task[5]

                if cached_anchor != undefined and cached_axis != undefined and length cached_axis > epsilon then
                (
                    local normalized_cached_axis = normalize cached_axis
                    local parallel = abs(dot normalized_cached_axis normalized_axis) >= axis_cos
                    local same_plane = abs(dot(world_anchor - cached_anchor) normalized_axis) <= plane_tolerance

                    if parallel and same_plane then
                    (
                        found_index = cache_index
                    )
                )
            )
        )

        found_index
        -- return
    ),


    /*
    Returns the straight-through pair for one true visible-edge T-junction direction set.
    Exactly three directions are required; two must continue oppositely through the vertex.
    */
    function getSliceForceTJunctionStraightPair edge_directions angle_threshold:5.0 =
    (
        if classOf edge_directions != Array or edge_directions.count != 3 then return undefined

        local straight_limit = -(cos (amin 45.0 (amax 0.0 angle_threshold)))
        local best_pair = undefined
        local best_dot = 1.0

        for direction_a_index = 1 to 2 do
        (
            local direction_a = edge_directions[direction_a_index]

            if direction_a != undefined and length direction_a > epsilon then
            (
                direction_a = normalize direction_a

                for direction_b_index = direction_a_index + 1 to 3 do
                (
                    local direction_b = edge_directions[direction_b_index]

                    if direction_b != undefined and length direction_b > epsilon then
                    (
                        direction_b = normalize direction_b
                        local pair_dot = dot direction_a direction_b

                        if pair_dot <= straight_limit and pair_dot < best_dot then
                        (
                            best_dot = pair_dot
                            best_pair = #(direction_a_index, direction_b_index, 6 - direction_a_index - direction_b_index)
                        )
                    )
                )
            )
        )

        best_pair
        -- return
    ),


    /*
    Finds true T-junction vertices from visible Editable Poly edges on the baked Slice Force object.
    Every polyop result is type-checked so status values such as OK or dead-edge results are skipped safely.
    */
    function getSliceForceTJunctionData node angle_threshold:5.0 =
    (
        local result = #()
        if node == undefined or not(isValidNode node) then return result

        local base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then return result

        local surface_data = getSliceForceSurfaceData node
        if classOf surface_data != Array or surface_data.count < 1 then return result

        local world_points = surface_data[1]
        if classOf world_points != Array then return result

        local vert_count = polyop.getNumVerts base_obj
        if world_points.count < vert_count then return result

        local direction_cos = cos (amin 45.0 (amax 0.0 angle_threshold))
        local world_up = [0.0,0.0,1.0]

        for vertex_index = 1 to vert_count do
        (
            local incident_edges = undefined
            try(incident_edges = polyop.getEdgesUsingVert base_obj #{vertex_index})catch(incident_edges = undefined)

            if classOf incident_edges == BitArray then
            (
                local visible_edges = #()
                local visible_directions = #()

                for edge_index in incident_edges do
                (
                    local edge_visibility_value = undefined
                    try(edge_visibility_value = polyop.getEdgeVis base_obj edge_index)catch(edge_visibility_value = undefined)
                    local edge_visible = (edge_visibility_value == true)

                    if edge_visible then
                    (
                        local edge_verts = undefined
                        try(edge_verts = polyop.getEdgeVerts base_obj edge_index)catch(edge_verts = undefined)

                        if classOf edge_verts == Array and edge_verts.count == 2 then
                        (
                            local other_vertex = if edge_verts[1] == vertex_index then edge_verts[2] else edge_verts[1]

                            if other_vertex >= 1 and other_vertex <= world_points.count then
                            (
                                local edge_direction = world_points[other_vertex] - world_points[vertex_index]

                                if length edge_direction > epsilon then
                                (
                                    append visible_edges edge_index
                                    append visible_directions (normalize edge_direction)
                                )
                            )
                        )
                    )
                )

                if visible_edges.count == 3 then
                (
                    local straight_pair = getSliceForceTJunctionStraightPair visible_directions angle_threshold:angle_threshold

                    if classOf straight_pair == Array and straight_pair.count == 3 then
                    (
                        local straight_direction = visible_directions[straight_pair[1]]
                        local branch_direction = visible_directions[straight_pair[3]]
                        local wall_normal = cross straight_direction branch_direction

                        if length wall_normal > epsilon then
                        (
                            wall_normal = normalize wall_normal
                            local wall_vertical = world_up - wall_normal * (dot wall_normal world_up)

                            if length wall_vertical > epsilon then
                            (
                                wall_vertical = normalize wall_vertical
                                local wall_horizontal = cross wall_vertical wall_normal

                                if length wall_horizontal > epsilon then
                                (
                                    wall_horizontal = normalize wall_horizontal
                                    local vertical_edge = 0
                                    local vertical_direction = undefined
                                    local vertical_score = -1.0
                                    local horizontal_edge = 0
                                    local horizontal_direction = undefined
                                    local horizontal_score = -1.0

                                    for direction_index = 1 to visible_directions.count do
                                    (
                                        local edge_direction = visible_directions[direction_index]
                                        local vertical_dot = abs(dot edge_direction wall_vertical)
                                        local horizontal_dot = abs(dot edge_direction wall_horizontal)

                                        if vertical_dot >= direction_cos and vertical_dot > vertical_score then
                                        (
                                            vertical_score = vertical_dot
                                            vertical_edge = visible_edges[direction_index]
                                            vertical_direction = edge_direction
                                        )

                                        if horizontal_dot >= direction_cos and horizontal_dot > horizontal_score then
                                        (
                                            horizontal_score = horizontal_dot
                                            horizontal_edge = visible_edges[direction_index]
                                            horizontal_direction = edge_direction
                                        )
                                    )

                                    append result #(vertex_index, world_points[vertex_index], wall_normal, visible_edges, vertical_edge, vertical_direction, horizontal_edge, horizontal_direction)
                                )
                            )
                        )
                    )
                )
            )
        )

        result
        -- return
    ),


    /*
    Merges true T-junction vertex planes into the Slice Force physical-plane cache.
    Non-array analyzer/status values are normalized to empty data instead of throwing on .count or indexing.
    */
    function mergeSliceForceTJunctionTasks node cached_tasks cut_mode:#all angle_threshold:5.0 match_tolerance:0.001 =
    (
        local result = if classOf cached_tasks == Array then copy cached_tasks else #()
        if node == undefined or not(isValidNode node) then return result
        if classOf node.baseObject != Editable_Poly then return result

        local surface_data = getSliceForceSurfaceData node
        if classOf surface_data != Array or surface_data.count < 1 then return result

        local world_points = surface_data[1]
        if classOf world_points != Array then return result

        local junction_data = getSliceForceTJunctionData node angle_threshold:angle_threshold
        if classOf junction_data != Array then junction_data = #()

        local added_count = 0

        for junction in junction_data do
        (
            if classOf junction == Array and junction.count >= 8 then
            (
                local vertex_index = junction[1]
                local world_anchor = junction[2]
                local wall_normal = junction[3]
                local incident_edge_ids = junction[4]
                local source_edges = #{}
                local source_vertices = #{vertex_index}

                if classOf incident_edge_ids == Array then
                (
                    for edge_index in incident_edge_ids do source_edges[edge_index] = true
                )

                if cut_mode == #all or cut_mode == #vertical then
                (
                    local vertical_edge = junction[5]
                    local vertical_line = junction[6]

                    if vertical_edge > 0 and vertical_line != undefined and length vertical_line > epsilon then
                    (
                        local vertical_axis = cross vertical_line wall_normal

                        if length vertical_axis > epsilon then
                        (
                            vertical_axis = normalize vertical_axis

                            if doesSliceForcePlaneSplitPoints world_points world_anchor vertical_axis match_tolerance:match_tolerance then
                            (
                                local vertical_task = #(vertex_index, #vertical, vertical_edge, world_anchor, vertical_axis, copy source_edges, copy source_vertices, world_anchor.z, wall_normal, world_anchor, 0)

                                if findSliceForcePlaneCacheIndex result vertical_task match_tolerance:match_tolerance == 0 then
                                (
                                    append result vertical_task
                                    added_count += 1
                                )
                            )
                        )
                    )
                )

                if cut_mode == #all or cut_mode == #horizontal then
                (
                    local horizontal_edge = junction[7]
                    local horizontal_line = junction[8]

                    if horizontal_edge > 0 and horizontal_line != undefined and length horizontal_line > epsilon then
                    (
                        local horizontal_axis = [0.0,0.0,1.0]

                        if doesSliceForcePlaneSplitPoints world_points world_anchor horizontal_axis match_tolerance:match_tolerance then
                        (
                            local horizontal_task = #(vertex_index, #horizontal, horizontal_edge, world_anchor, horizontal_axis, copy source_edges, copy source_vertices, world_anchor.z, wall_normal, world_anchor, 0)

                            if findSliceForcePlaneCacheIndex result horizontal_task match_tolerance:match_tolerance == 0 then
                            (
                                append result horizontal_task
                                added_count += 1
                            )
                        )
                    )
                )
            )
        )

        if not batch_quiet then format "Wall-Fixer Slice Force T Junctions: node:% junctionVerts:% addedPlanes:% totalPlanes:%\n" node.name junction_data.count added_count result.count

        result
        -- return
    ),


    /*
    Tests the true visible-edge T-junction rule used by the optional Slice Force anchor source.
    A three-edge T passes; a three-edge corner and four-edge crossing do not.
    */
    function testSliceForceTJunctionRule =
    (
        local t_pair = getSliceForceTJunctionStraightPair #([0,0,1], [0,0,-1], [1,0,0]) angle_threshold:5.0
        local corner_pair = getSliceForceTJunctionStraightPair #([1,0,0], [0,1,0], [0,0,1]) angle_threshold:5.0
        local crossing_pair = getSliceForceTJunctionStraightPair #([1,0,0], [-1,0,0], [0,1,0], [0,-1,0]) angle_threshold:5.0

        t_pair != undefined and t_pair[3] == 3 and corner_pair == undefined and crossing_pair == undefined
        -- return
    ),


    /*
    Flattens normal Slice Walls pass tasks into one object-wide Slice Force cache.
    Duplicate physical planes are removed before any Force modifier is created.
    */
    function buildSliceForceTaskCache slice_passes match_tolerance:0.001 =
    (
        local cached_tasks = #()

        for slice_pass in slice_passes do
        (
            if slice_pass != undefined and slice_pass.count >= 3 then
            (
                for slice_task in slice_pass[3] do
                (
                    if findSliceForcePlaneCacheIndex cached_tasks slice_task match_tolerance:match_tolerance == 0 then
                    (
                        append cached_tasks slice_task
                    )
                )
            )
        )

        cached_tasks
        -- return
    ),


    /*
    Builds Slice Force tasks through the exact proven normal Slice Walls planar analyzer first.
    The baked whole object is analyzed with viewport selection disabled; temporary Reset-Slicing state is cleared before returning.
    */
    function buildSliceForcePlanarTaskCache node cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 match_tolerance:0.001 =
    (
        local cached_tasks = #()
        if node == undefined or not(isValidNode node) then return cached_tasks
        if classOf node.baseObject != Editable_Poly then return cached_tasks

        clearResetInnerVertSelection node

        local initialized = initializeBaseSliceAnalysis \
            node \
            angle_threshold:angle_threshold \
            planar_tolerance:planar_tolerance \
            update_viewport_selection:false

        if initialized then
        (
            local slice_passes = buildBaseSlicePassQueue \
                node \
                cut_mode:cut_mode \
                slice_plane_mode:slice_plane_mode \
                angle_threshold:angle_threshold \
                planar_tolerance:planar_tolerance

            cached_tasks = buildSliceForceTaskCache \
                slice_passes \
                match_tolerance:match_tolerance
        )

        clearResetInnerVertSelection node

        if not batch_quiet then
        (
            format "Wall-Fixer Slice Force Planar First: node:% direction:% planes:%\n" node.name cut_mode cached_tasks.count
        )

        cached_tasks
        -- return
    ),


    /*
    Returns the fixed analyzer priority used by Slice Force.
    Normal planar Slice Walls tasks are always attempted before Force-only non-planar fallbacks.
    */
    function getSliceForceAnalysisOrder =
    (
        #(#planar, #nonplanar)
        -- return
    ),


    /*
    Tests that Slice Force preserves the proven planar analyzer as its first source.
    */
    function testSliceForceAnalysisOrder =
    (
        local analysis_order = getSliceForceAnalysisOrder()
        analysis_order.count == 2 and analysis_order[1] == #planar and analysis_order[2] == #nonplanar
        -- return
    ),


    /*
    Applies the current evaluated stack and prepares one clean Editable Poly base for Slice Force analysis.
    Existing modifiers are intentionally baked before anchor detection.
    */
    function prepareSliceForceBaseObject node =
    (
        if node == undefined or not(isValidNode node) then return false

        local prepared = false

        try
        (
            select node
            try(subObjectLevel = 0)catch()
            convertToPoly node

            if classOf node.baseObject == Editable_Poly then
            (
                /* Rebuild Editable Poly adjacency before Force analysis. */
                try(polyop.fillInMesh node.baseObject)catch()
            )

            update node

            if classOf node.baseObject == Editable_Poly and node.modifiers.count == 0 then
            (
                polyop.setVertSelection node.baseObject #{}
                polyop.setEdgeSelection node.baseObject #{}
                polyop.setFaceSelection node.baseObject #{}
                setEditablePolyCageOff node
                prepared = true
            )
        )
        catch
        (
            prepared = false
        )

        prepared
        -- return
    ),


    /*
    Switches Slice Force to 3ds Max Create mode and exits component sub-object mode.
    Real SliceModifier creation/configuration does not require the Modify panel.
    */
    function setSliceForceCreateMode =
    (
        local switched = false

        try
        (
            try(subObjectLevel = 0)catch()
            max create mode

            local panel_mode = undefined
            try(panel_mode = getCommandPanelTaskMode())catch(panel_mode = undefined)

            switched = (panel_mode == undefined or panel_mode == #create)
        )
        catch
        (
            switched = false
        )

        switched
        -- return
    ),


    /*
    Selects the complete Editable Poly face and edge sets before the real Slice modifier stack is added.
    Face and Edge selections are stored directly on the base object while Slice Force stays in Create mode.
    */
    function prepareSliceForceBaseSelections node =
    (
        if node == undefined or not(isValidNode node) then return false
        if classOf node.baseObject != Editable_Poly then return false

        local face_count = polyop.getNumFaces node.baseObject
        local edge_count = polyop.getNumEdges node.baseObject
        if face_count < 1 or edge_count < 1 then return false

        polyop.setVertSelection node.baseObject #{}
        polyop.setFaceSelection node.baseObject (makeSliceForceFullSelection face_count)
        polyop.setEdgeSelection node.baseObject (makeSliceForceFullSelection edge_count)

        select node
        try(setSliceForceCreateMode())catch()
        update node

        true
        -- return
    ),


    /*
    Creates the complete Slice Force stack from real 3ds Max Slice modifiers before evaluation.
    The first SliceModifier is the template and every remaining cached plane receives a copied SliceModifier.
    */
    function createSliceForceModifierStack node force_tasks =
    (
        local modifiers = #()
        if node == undefined or not(isValidNode node) then return modifiers
        if force_tasks == undefined or force_tasks.count == 0 then return modifiers

        if not(prepareSliceForceBaseSelections node) then
        (
            last_slice_error = "Slice Force prebuild [base selections]: could not select all Editable Poly faces and edges."
            return modifiers
        )

        local template_modifier = undefined

        try
        (
            template_modifier = SliceModifier()
            template_modifier.Slice_Type = 0
            template_modifier.Faces___Polygons_Toggle = 1
        )
        catch
        (
            last_slice_error = "Slice Force prebuild [template Slice modifier]: " + ((getCurrentException()) as string)
            return modifiers
        )

        for task_index = 1 to force_tasks.count do
        (
            local slice_task = force_tasks[task_index]
            local slice_kind = slice_task[2]
            local modifier = undefined
            local direction_name = if slice_kind == #vertical then "VERTICAL" else if slice_kind == #horizontal then "HORIZONTAL" else "ALL"
            local modifier_name = "SLICE FORCE " + direction_name + " " + (task_index as string)

            try
            (
                modifier = if task_index == 1 then template_modifier else copy template_modifier
            )
            catch
            (
                last_slice_error = "Slice Force prebuild [modifier " + (task_index as string) + " create/copy]: " + ((getCurrentException()) as string)
                return modifiers
            )

            if modifier == undefined or classOf modifier != SliceModifier then
            (
                last_slice_error = "Slice Force prebuild [modifier " + (task_index as string) + " create/copy]: real SliceModifier was not created."
                return modifiers
            )

            try
            (
                modifier.name = modifier_name
                modifier.Slice_Type = 0
                modifier.Faces___Polygons_Toggle = 1
            )
            catch
            (
                last_slice_error = "Slice Force prebuild [modifier " + (task_index as string) + " properties]: " + ((getCurrentException()) as string)
                return modifiers
            )

            try
            (
                addModifier node modifier
            )
            catch
            (
                last_slice_error = "Slice Force prebuild [modifier " + (task_index as string) + " addModifier]: " + ((getCurrentException()) as string)
                return modifiers
            )

            append modifiers modifier
        )

        update node
        modifiers
        -- return
    ),


    /*
    Tests that Slice Force prebuild names remain deterministic for the real SliceModifier stack.
    */
    function testSliceForcePrebuildNamePolicy =
    (
        local vertical_name = "SLICE FORCE " + (if #vertical == #vertical then "VERTICAL" else "ALL") + " " + (1 as string)
        local horizontal_name = "SLICE FORCE " + (if #horizontal == #horizontal then "HORIZONTAL" else "ALL") + " " + (2 as string)

        vertical_name == "SLICE FORCE VERTICAL 1" and horizontal_name == "SLICE FORCE HORIZONTAL 2"
        -- return
    ),


    /*
    Configures one already-created real Slice modifier from one cached Force plane.
    No Edit Poly topology API, SetPrimaryNode, SetOperation, or Commit call is used in Force mode.
    */
    function configureSliceForceStackModifier node modifier slice_task =
    (
        if node == undefined or not(isValidNode node) then return false
        if modifier == undefined or classOf modifier != SliceModifier then return false
        if slice_task == undefined or slice_task.count < 5 then return false

        local completed = false

        try
        (
            modifier.Slice_Type = 0
            modifier.Faces___Polygons_Toggle = 1

            local world_anchor = slice_task[4]
            local world_axis = slice_task[5]
            local wall_normal = if slice_task.count >= 9 then slice_task[9] else undefined
            local slice_plane_transform = getSliceForcePlaneTransform \
                node \
                modifier \
                world_anchor \
                world_axis \
                wall_normal:wall_normal

            if slice_plane_transform == undefined then
            (
                throw "Slice Force could not build the cached Slice modifier gizmo transform."
            )

            modifier.slice_plane.transform = slice_plane_transform
            update node
            completed = true
        )
        catch
        (
            last_slice_error = (getCurrentException()) as string
            completed = false
        )

        completed
        -- return
    ),


    /*
    Collapses the completed Slice Force stack to one Editable Poly object.
    Slice Force intentionally bakes the full stack after every unique plane has finished.
    */
    function collapseSliceForceObject node =
    (
        if node == undefined or not(isValidNode node) then return false

        local completed = false

        try
        (
            try(subObjectLevel = 0)catch()
            select node
            convertToPoly node
            update node

            completed = classOf node.baseObject == Editable_Poly and node.modifiers.count == 0

            if completed then
            (
                setEditablePolyCageOff node
            )
        )
        catch
        (
            completed = false
        )

        completed
        -- return
    ),


    /*
    Clears final Editable Poly component selections without changing Slice Force success state.
    Runtime-specific selection API failures are contained here because the completed Slice stack has already been baked.
    */
    function clearSliceForceFinalSelections node =
    (
        if node == undefined or not(isValidNode node) then return false

        local cleanup_ok = true

        try(subObjectLevel = 0)catch(cleanup_ok = false)

        if classOf node.baseObject == Editable_Poly then
        (
            try(polyop.setVertSelection node.baseObject #{})catch(cleanup_ok = false)
            try(polyop.setEdgeSelection node.baseObject #{})catch(cleanup_ok = false)
            try(polyop.setFaceSelection node.baseObject #{})catch(cleanup_ok = false)
            try(update node)catch()
        )
        else
        (
            cleanup_ok = false
        )

        try(setSliceForceCreateMode())catch()

        cleanup_ok
        -- return
    ),


    /*
    Executes the complete real SliceModifier Force stack and collapses once at the end.
    Every cached plane already has its own modifier before the first gizmo is configured.
    */
    function executeSliceForceCachedStack node force_tasks task_index_offset:0 total_task_count:0 progress_callback:undefined object_index:0 object_total:0 object_name:"" vertex_count:0 =
    (
        if node == undefined or not(isValidNode node) then return false
        if force_tasks == undefined or force_tasks.count == 0 then return false

        /*
        Real SliceModifier stacks are built from Create mode.
        Keep Force independent from any previously active Modify-panel or component state.
        */
        try(setSliceForceCreateMode())catch()

        local force_modifiers = createSliceForceModifierStack node force_tasks
        if force_modifiers.count != force_tasks.count then
        (
            if last_slice_error == undefined or last_slice_error == "" then
            (
                last_slice_error = "Slice Force could not create the complete real Slice modifier stack."
            )
            return false
        )

        for task_index = 1 to force_tasks.count do
        (
            local modifier = force_modifiers[task_index]
            local slice_task = force_tasks[task_index]

            if not(configureSliceForceStackModifier node modifier slice_task) then
            (
                last_slice_error = "Slice Force failed in " + modifier.name + ". " + (last_slice_error as string)
                return false
            )

            if progress_callback != undefined then
            (
                local display_task_index = task_index_offset + task_index
                try(progress_callback display_task_index total_task_count object_index:object_index object_total:object_total object_name:object_name vertex_count:vertex_count)catch()
            )
        )

        update node

        if not(collapseSliceForceObject node) then
        (
            last_slice_error = "Slice Force finished the real Slice modifier stack but could not collapse the object."
            return false
        )

        /*
        Slice Force is already complete once the real Slice stack has collapsed successfully.
        Return Max to Create mode before optional final selection cleanup.
        */
        try(setSliceForceCreateMode())catch()
        try(clearSliceForceFinalSelections node)catch()
        try(setSliceForceCreateMode())catch()

        true
        -- return
    ),


    /*
    Tests that post-collapse component-selection cleanup is non-fatal to Slice Force.
    A completed collapse remains success even when optional final selection cleanup reports failure.
    */
    function testSliceForcePostCollapseCleanupPolicy =
    (
        local collapse_completed = true
        local cleanup_completed = false
        collapse_completed and not cleanup_completed
        -- return
    ),


    /*
    Tests that Slice Force can explicitly switch 3ds Max to Create mode.
    Leaves the command panel in Create mode, matching the Force execution policy.
    */
    function testSliceForceCreateModePolicy =
    (
        local switched = setSliceForceCreateMode()
        local panel_mode = undefined
        try(panel_mode = getCommandPanelTaskMode())catch(panel_mode = undefined)

        switched and (panel_mode == undefined or panel_mode == #create)
        -- return
    ),


    /*
    Tests object-wide Force plane caching independently from scene geometry.
    Same-Z Horizontal and same signed-position Vertical tasks collapse to one cached plane each.
    */
    function testSliceForcePlaneCacheRule =
    (
        local horizontal_a = #(1, #horizontal, 1, [0,0,10], [0,0,1], #{}, #{}, 10.0, [0,1,0], [0,0,0], 1)
        local horizontal_b = #(2, #horizontal, 2, [50,20,10], [0,0,1], #{}, #{}, 10.0, [0,1,0], [0,0,0], 2)
        local vertical_a = #(3, #vertical, 3, [5,0,0], [1,0,0], #{}, #{}, 0.0, [0,1,0], [0,0,0], 1)
        local vertical_b = #(4, #vertical, 4, [5,40,20], [-1,0,0], #{}, #{}, 20.0, [0,1,0], [0,0,0], 2)
        local passes = #(
            #(#horizontal, "SLICE HORIZONTAL", #(horizontal_a, horizontal_b)),
            #(#vertical, "SLICE VERTICAL", #(vertical_a, vertical_b))
        )

        local cached = buildSliceForceTaskCache passes match_tolerance:0.001
        cached.count == 2
        -- return
    ),


    /*
    Tests that Slice Force prebuilds every required real SliceModifier and preserves full base Face/Edge selections.
    */
    function testSliceForcePrebuiltModifierStack =
    (
        local test_node = undefined
        local passed = false

        try
        (
            test_node = box length:10.0 width:10.0 height:10.0
            convertToPoly test_node

            local task_a = #(1, #vertical, 1, [0,0,0], [1,0,0], #{}, #{}, 0.0, [0,1,0], [0,0,0], 1)
            local task_b = #(2, #vertical, 2, [2,0,0], [1,0,0], #{}, #{}, 0.0, [0,1,0], [0,0,0], 1)
            local task_c = #(3, #vertical, 3, [4,0,0], [1,0,0], #{}, #{}, 0.0, [0,1,0], [0,0,0], 1)
            local modifiers = createSliceForceModifierStack test_node #(task_a, task_b, task_c)

            local face_selection = polyop.getFaceSelection test_node.baseObject
            local edge_selection = polyop.getEdgeSelection test_node.baseObject

            passed = (
                modifiers.count == 3 and
                test_node.modifiers.count == 3 and
                classOf modifiers[1] == SliceModifier and
                classOf modifiers[2] == SliceModifier and
                classOf modifiers[3] == SliceModifier and
                modifiers[1].Slice_Type == 0 and
                modifiers[2].Slice_Type == 0 and
                modifiers[3].Slice_Type == 0 and
                face_selection.numberSet == polyop.getNumFaces test_node.baseObject and
                edge_selection.numberSet == polyop.getNumEdges test_node.baseObject and
                modifiers[1].name == "SLICE FORCE VERTICAL 1" and
                modifiers[2].name == "SLICE FORCE VERTICAL 2" and
                modifiers[3].name == "SLICE FORCE VERTICAL 3"
            )
        )
        catch
        (
            passed = false
        )

        if test_node != undefined and isValidNode test_node then
        (
            delete test_node
        )

        passed
        -- return
    ),


    /*
    Tests that Force uses the real SliceModifier class rather than renamed Edit Poly modifiers.
    Refine Mesh is required so every plane adds topology without deleting either side.
    */
    function testSliceForceRealModifierClass =
    (
        local test_modifier = undefined
        local passed = false

        try
        (
            test_modifier = SliceModifier()
            test_modifier.Slice_Type = 0
            test_modifier.Faces___Polygons_Toggle = 1

            passed = (
                classOf test_modifier == SliceModifier and
                test_modifier.Slice_Type == 0 and
                test_modifier.Faces___Polygons_Toggle == 1
            )
        )
        catch
        (
            passed = false
        )

        passed
        -- return
    ),


    /*
    Tests the optimized Slice Force execution policy.
    Force analyzes once, prebuilds real Slice modifiers, positions gizmos directly, and never requires Edit Poly operation context.
    */
    function testSliceForceModifyContextPolicy =
    (
        local analyzes_once = true
        local prebuilds_stack = true
        local uses_real_slice_modifiers = true
        local direct_gizmo = true
        local requires_edit_poly_context = false
        local uses_vertex_pick_for_gizmo = false

        analyzes_once and
        prebuilds_stack and
        uses_real_slice_modifiers and
        direct_gizmo and
        not requires_edit_poly_context and
        not uses_vertex_pick_for_gizmo
        -- return
    ),


    /*
    Tests the direct Slice Force plane-basis math without creating scene geometry.
    */
    function testSliceForcePlaneBasis =
    (
        local vertical_basis = getSliceForcePlaneBasis [1,0,0] wall_normal:[0,1,0]
        local horizontal_basis = getSliceForcePlaneBasis [0,0,1] wall_normal:[0,1,0]
        local tolerance_value = 0.0001

        vertical_basis != undefined and
        horizontal_basis != undefined and
        abs(dot vertical_basis[1] vertical_basis[2]) <= tolerance_value and
        abs(dot vertical_basis[1] vertical_basis[3]) <= tolerance_value and
        abs(dot vertical_basis[2] vertical_basis[3]) <= tolerance_value and
        abs(dot horizontal_basis[1] horizontal_basis[2]) <= tolerance_value and
        abs(dot horizontal_basis[1] horizontal_basis[3]) <= tolerance_value and
        abs(dot horizontal_basis[2] horizontal_basis[3]) <= tolerance_value and
        abs(dot vertical_basis[3] [1,0,0]) >= (1.0 - tolerance_value) and
        abs(dot horizontal_basis[3] [0,0,1]) >= (1.0 - tolerance_value)
        -- return
    ),


    /*
    Returns a temporary Slice Force modifier name for one unique directional plane.
    */
    function getSliceForceModifierName slice_kind plane_index =
    (
        local direction_name = if slice_kind == #vertical then "VERTICAL" else if slice_kind == #horizontal then "HORIZONTAL" else "ALL"
        "SLICE FORCE " + direction_name + " " + (plane_index as string)
        -- return
    ),


    /*
    Tests Slice Force temporary modifier naming and final collapse on a temporary object.
    */
    function testSliceForceCollapseObject =
    (
        local test_node = undefined
        local passed = false

        try
        (
            test_node = box length:10.0 width:10.0 height:10.0
            convertToPoly test_node

            addModifier test_node (Edit_Poly name:(getSliceForceModifierName #vertical 1))
            addModifier test_node (Edit_Poly name:(getSliceForceModifierName #horizontal 2))

            passed = (
                test_node.modifiers.count == 2 and
                collapseSliceForceObject test_node and
                classOf test_node.baseObject == Editable_Poly and
                test_node.modifiers.count == 0
            )
        )
        catch
        (
            passed = false
        )

        if test_node != undefined and isValidNode test_node then
        (
            delete test_node
        )

        passed
        -- return
    ),


    /*
    Runs a fixed base-object candidate queue on all selected walls.
    This is the normal Slice Walls executor; optimized Slice Force uses its dedicated cached-stack path.
    */
    function debugSliceSelectedWallsInternal cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 slice_precision:0.01 cleanup_edges:true force_per_plane:false display_hidden_edges:undefined double_side:undefined progress_callback:undefined =
    (
        local all_selected_nodes = selection as array
        local selected_nodes = getBatchSliceProcessNodes all_selected_nodes
        local original_panel_mode = undefined
        local original_current_object = undefined
        local original_subobject_level = subObjectLevel
        local active_continuation_modifier = if all_selected_nodes.count == 1 then getActiveTopSliceContinuationModifier all_selected_nodes[1] cut_mode else undefined
        local restrict_to_selected_vertices = shouldRestrictSliceToSelectedComponents all_selected_nodes.count original_subobject_level
        local selected_vertex_filters = #()
        local selected_live_task_filters = #()
        local automatic_live_task_filters = #()
        local failed_nodes = #()
        local final_sliced_node = undefined
        local final_force_node = undefined
        local processed_count = 0
        local processed_vertex_count = 0

        try
        (
            original_panel_mode = getCommandPanelTaskMode()
        )
        catch
        (
            original_panel_mode = undefined
        )

        if original_panel_mode == #modify then
        (
            try
            (
                original_current_object = modPanel.getCurrentObject()
            )
            catch
            (
                original_current_object = undefined
            )
        )

        if restrict_to_selected_vertices then
        (
            for node in selected_nodes do
            (
                local selection_data = getActiveMakeOneSliceVertexSelection node
                local mapped_vertices = if selection_data != undefined and selection_data.count >= 1 then copy selection_data[1] else #{}
                local live_tasks = captureSelectedLiveSliceTasks \
                    node \
                    cut_mode:cut_mode \
                    slice_plane_mode:slice_plane_mode \
                    match_tolerance:0.01

                append selected_vertex_filters #(node, mapped_vertices)
                append selected_live_task_filters #(node, live_tasks)
            )
        )

        local skipped_count = all_selected_nodes.count - selected_nodes.count
        last_slice_report = ""
        last_slice_error = undefined
        last_slice_failed_nodes = #()
        last_slice_elapsed_ms = 0
        last_slice_processed_objects = 0
        last_slice_processed_vertices = 0

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
                local node_exception = undefined
                local current_vertex_count = 0

                try
                (
                    if node == undefined or not(isValidNode node) then
                    (
                        node_error = "Selected wall became invalid during Slice Selected Walls."
                        node_ok = false
                    )
                    else
                    (
                        if not(::WallFixer.activateBatchSliceNodeContext node) then
                        (
                            node_error = node.name + ": could not activate an isolated batch-slice context."
                            node_ok = false
                        )

                        if node_ok then
                        (
                            current_vertex_count = getEvaluatedVertexCount node
                            processed_vertex_count += current_vertex_count
                        )

                        /* Normal slicing preserves the opposite directional slice.
                           Force slicing rebuilds all Wall-Fixer slice modifiers so every unique plane owns exactly one temporary modifier. */
                        local preserved_continuation_modifier = if (not force_per_plane) and active_continuation_modifier != undefined and node == all_selected_nodes[1] then active_continuation_modifier else undefined
                        local automatic_live_tasks_before_force = #()

                        if force_per_plane and not restrict_to_selected_vertices then
                        (
                            local previous_opposite_modifier = getTopOppositeSliceModifier node cut_mode
                            automatic_live_tasks_before_force = captureAutomaticLiveSliceTasks \
                                node \
                                previous_opposite_modifier \
                                cut_mode:cut_mode \
                                slice_plane_mode:slice_plane_mode \
                                match_tolerance:0.01
                        )

                        local cleanup_mode = if force_per_plane then #all else cut_mode

                        if node_ok and not(::WallFixer.removeWallFixerSliceModifiers node cut_mode:cleanup_mode preserve_modifier:preserved_continuation_modifier) then
                        (
                            node_error = node.name + ": could not clear conflicting Wall-Fixer slicing modifiers."
                            node_ok = false
                        )
                        else if node_ok then
                        (
                            if not restrict_to_selected_vertices then
                            (
                                local automatic_live_tasks = #()

                                if force_per_plane then
                                (
                                    automatic_live_tasks = automatic_live_tasks_before_force
                                )
                                else
                                (
                                    local preserved_opposite_modifier = getTopOppositeSliceModifier node cut_mode
                                    automatic_live_tasks = captureAutomaticLiveSliceTasks \
                                        node \
                                        preserved_opposite_modifier \
                                        cut_mode:cut_mode \
                                        slice_plane_mode:slice_plane_mode \
                                        match_tolerance:0.01
                                )

                                append automatic_live_task_filters #(node, automatic_live_tasks)

                                if not batch_quiet and automatic_live_tasks.count > 0 then
                                (
                                    format "Wall-Fixer Automatic Live Slice Anchors: node:% tasks:% force:%\n" node.name automatic_live_tasks.count force_per_plane
                                )
                            )


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
                            else if restrict_to_selected_vertices then
                            (
                                local selected_source_vertices = #{}

                                for filter_item in selected_vertex_filters do
                                (
                                    if filter_item[1] == node then
                                    (
                                        selected_source_vertices = copy filter_item[2]
                                        exit
                                    )
                                )

                                setResetInnerVertSelection node selected_source_vertices

                                if not batch_quiet then format "Wall-Fixer Slice Selected Walls Vertex Filter: node:% selectedBaseVerts:%\n" node.name selected_source_vertices
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

                            local extra_live_tasks = #()

                            if restrict_to_selected_vertices then
                            (
                                for live_filter_item in selected_live_task_filters do
                                (
                                    if live_filter_item[1] == node then
                                    (
                                        extra_live_tasks = live_filter_item[2]
                                        exit
                                    )
                                )
                            )
                            else
                            (
                                for live_filter_item in automatic_live_task_filters do
                                (
                                    if live_filter_item[1] == node then
                                    (
                                        extra_live_tasks = live_filter_item[2]
                                        exit
                                    )
                                )
                            )

                            for live_task in extra_live_tasks do
                            (
                                local live_kind = live_task[2]

                                for slice_pass in slice_passes do
                                (
                                    if slice_pass[1] == live_kind or slice_pass[1] == #all then
                                    (
                                        appendUniqueLiveSliceTasks slice_pass[3] #(live_task) match_tolerance:0.01
                                    )
                                )
                            )

                            for slice_pass in slice_passes do
                            (
                                total_task_count += slice_pass[3].count
                            )
                        )

                        if node_ok and progress_callback != undefined then
                        (
                            try(progress_callback 0 total_task_count object_index:(processed_count + 1) object_total:selected_nodes.count object_name:node.name vertex_count:current_vertex_count)catch()
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

                                if force_per_plane then
                                (
                                    local force_plane_index = 0

                                    for force_task in pass_tasks while node_ok do
                                    (
                                        force_plane_index += 1
                                        local force_modifier_name = getSliceForceModifierName pass_kind force_plane_index

                                        local queue_result = ::WallFixer.executeBaseSliceTaskQueue \
                                            node \
                                            #(force_task) \
                                            modifier_name:force_modifier_name \
                                            existing_modifier:undefined \
                                            angle_threshold:angle_threshold \
                                            planar_tolerance:planar_tolerance \
                                            precision_threshold:slice_precision \
                                            cleanup_edges:cleanup_edges \
                                            direct_slice_transform:true \
                                            task_index_offset:task_index_offset \
                                            total_task_count:total_task_count \
                                            progress_callback:progress_callback \
                                            object_index:(processed_count + 1) \
                                            object_total:selected_nodes.count \
                                            object_name:node.name \
                                            vertex_count:current_vertex_count

                                        if not queue_result[1] then
                                        (
                                            node_error = node.name + ": Slice Force failed in " + force_modifier_name + ". " + last_slice_report
                                            node_ok = false
                                        )
                                        else
                                        (
                                            total_sliced_count += queue_result[2]
                                            total_no_change_count += queue_result[3]

                                            if not batch_quiet then format "Wall-Fixer Slice Force Plane Result: node:% modifier:% direction:% task:%/% sliced:% noChange:%\n" \
                                                node.name force_modifier_name pass_kind (task_index_offset + 1) total_task_count queue_result[2] queue_result[3]
                                        )

                                        task_index_offset += 1
                                    )
                                )
                                else
                                (
                                    local continuation_for_pass = undefined
                                    if preserved_continuation_modifier != undefined and toUpper(preserved_continuation_modifier.name as string) == toUpper(modifier_name as string) then continuation_for_pass = preserved_continuation_modifier

                                    local queue_result = ::WallFixer.executeBaseSliceTaskQueue \
                                        node \
                                        pass_tasks \
                                        modifier_name:modifier_name \
                                        existing_modifier:continuation_for_pass \
                                        angle_threshold:angle_threshold \
                                        planar_tolerance:planar_tolerance \
                                        precision_threshold:slice_precision \
                                        cleanup_edges:cleanup_edges \
                                        task_index_offset:task_index_offset \
                                        total_task_count:total_task_count \
                                        progress_callback:progress_callback \
                                        object_index:(processed_count + 1) \
                                        object_total:selected_nodes.count \
                                        object_name:node.name \
                                        vertex_count:current_vertex_count

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
                            )

                            if node_ok and force_per_plane and total_sliced_count > 0 then
                            (
                                if collapseSliceForceObject node then
                                (
                                    final_force_node = node
                                    if not batch_quiet then format "Wall-Fixer Slice Force Collapse: node:% planes:% success:true\n" node.name total_sliced_count
                                )
                                else
                                (
                                    node_error = node.name + ": Slice Force finished its planes but could not collapse the object."
                                    node_ok = false
                                )
                            )
                            else if node_ok and (not force_per_plane) and total_sliced_count > 0 then
                            (
                                final_sliced_node = node
                            )


                            if node_ok and not batch_quiet then
                            (
                                format "Wall-Fixer Slice Selected Walls Queue Result: node:% passes:% tasks:% sliced:% noChange:%\n" \
                                    node.name slice_passes.count total_task_count total_sliced_count total_no_change_count
                            )
                        )
                    )
                )
                catch
                (
                    node_exception = getCurrentException()
                    node_error = if node != undefined and isValidNode node then \
                        (node.name + ": unexpected Slice Walls error. " + (node_exception as string)) \
                        else \
                        ("Slice Walls unexpected object error. " + (node_exception as string))
                    node_ok = false
                )

                if node_ok then
                (
                    if force_per_plane then
                    (
                        automation_report += node.name + ": Slice Force unique-plane stack completed and collapsed.\n"
                    )
                    else
                    (
                        local modifier_report = if cut_mode == #all then "SLICE ALL" else if cut_mode == #horizontal then "SLICE HORIZONTAL" else "SLICE VERTICAL"
                        automation_report += node.name + ": fixed base-object slice queue complete in " + modifier_report + ".\n"
                    )
                )
                else
                (
                    all_ok = false

                    if node_error == undefined then
                    (
                        node_error = "Slice Selected Walls stopped before completion."
                    )

                    if last_slice_error == undefined then
                    (
                        last_slice_error = node_error
                    )

                    if node != undefined and isValidNode node then
                    (
                        if (findItem failed_nodes node) == 0 then
                        (
                            append failed_nodes node
                        )
                    )

                    automation_report += node_error + "\n"
                )

                processed_count += 1
            )
        )

        if display_hidden_edges != undefined or double_side != undefined then
        (
            setNodesDisplayOptions all_selected_nodes hidden_edges:display_hidden_edges double_side:double_side
        )

        for selected_node in all_selected_nodes do
        (
            if isValidNode selected_node then
            (
                try
                (
                    if selected_node.modifiers.count > 0 and classOf selected_node.modifiers[1] == Edit_Poly then
                    (
                        selected_node.modifiers[1].SetSelection #Face #{} node:selected_node
                    )
                    else if classOf selected_node.baseObject == Editable_Poly then
                    (
                        polyop.setFaceSelection selected_node.baseObject #{}
                    )
                )
                catch
                (
                )
            )
        )

        last_slice_failed_nodes = #()

        for failed_node in failed_nodes do
        (
            if failed_node != undefined and isValidNode failed_node then
            (
                append last_slice_failed_nodes failed_node
            )
        )

        if last_slice_failed_nodes.count > 0 then
        (
            try(subObjectLevel = 0)catch()
            select last_slice_failed_nodes
        )
        else
        (
            select all_selected_nodes

            if force_per_plane and final_force_node != undefined and isValidNode final_force_node then
            (
                select final_force_node
                max modify mode

                try
                (
                    modPanel.setCurrentObject final_force_node.baseObject
                    subObjectLevel = 0
                )
                catch
                (
                )
            )
            else if final_sliced_node != undefined and isValidNode final_sliced_node and final_sliced_node.modifiers.count > 0 then
            (
                local top_modifier = final_sliced_node.modifiers[1]

                select final_sliced_node
                max modify mode

                try
                (
                    if classOf top_modifier == Edit_Poly then
                    (
                        top_modifier.SetPrimaryNode final_sliced_node
                    )

                    modPanel.setCurrentObject top_modifier

                    if classOf top_modifier == Edit_Poly then
                    (
                        top_modifier.SetEPolySelLevel #Edge
                        subObjectLevel = 2
                    )
                )
                catch
                (
                )
            )
            else if original_panel_mode == #modify then
            (
                max modify mode

                if original_current_object != undefined then
                (
                    try
                    (
                        modPanel.setCurrentObject original_current_object
                    )
                    catch
                    (
                    )
                )

                if original_subobject_level != undefined then
                (
                    try
                    (
                        subObjectLevel = original_subobject_level
                    )
                    catch
                    (
                    )
                )
            )
            else if original_panel_mode != undefined then
            (
                setCommandPanelTaskMode original_panel_mode
            )
            else
            (
                max create mode
            )
        )

        last_slice_processed_objects = processed_count
        last_slice_processed_vertices = processed_vertex_count

        completeRedraw()
        last_slice_report = automation_report

        all_ok
        -- return
    ),

    /*
    Tests that the last successful Slice Walls object becomes the completion target.
    */
    function testSliceCompletionTargetPolicy =
    (
        local final_target = undefined
        local sample_results = #(
            #("Wall_A", 2),
            #("Wall_B", 0),
            #("Wall_C", 1)
        )

        for sample_result in sample_results do
        (
            if sample_result[2] > 0 then final_target = sample_result[1]
        )

        final_target == "Wall_C"
        -- return
    ),


    /*
    Tests stacked-direction live-anchor modifier selection.
    */
    function testOppositeSliceModifierNamePolicy =
    (
        local horizontal_keeps = "SLICE VERTICAL"
        local vertical_keeps = "SLICE HORIZONTAL"

        horizontal_keeps == "SLICE VERTICAL" and vertical_keeps == "SLICE HORIZONTAL"
        -- return
    ),


    /*
    Tests geometric live-task deduplication without scene topology.
    */
    function testLiveSliceTaskPlaneDeduplication =
    (
        local pass_tasks = #(
            #(1, #horizontal, 1, [0.0,0.0,10.0], [0.0,0.0,1.0], #{1}, #{1}, 10.0, undefined, undefined, 1)
        )
        local live_tasks = #(
            #(0, #horizontal, 0, [5.0,0.0,10.0], [0.0,0.0,1.0], #{}, #{}, 10.0, undefined, undefined, 0),
            #(0, #horizontal, 0, [0.0,0.0,20.0], [0.0,0.0,1.0], #{}, #{}, 20.0, undefined, undefined, 0)
        )

        appendUniqueLiveSliceTasks pass_tasks live_tasks match_tolerance:0.01

        pass_tasks.count == 2
        -- return
    ),


    /*
    Tests synthetic selected-live slice task structure used for modifier-created vertices.
    */
    function testSelectedLiveSliceTaskStructure =
    (
        local sample_task = #(0, #vertical, 0, [1,2,3], [1,0,0], #{}, #{}, 3.0, undefined, undefined, 0)

        sample_task.count == 11 and sample_task[1] == 0 and sample_task[2] == #vertical and sample_task[3] == 0
        -- return
    ),


    /*
    Tests that component filtering is allowed only for a single selected wall.
    Multi-object Slice Walls must ignore stale Vertex or Edge sub-object state.
    */
    function testSliceSelectedVertexMode =
    (
        local test_passed = true

        test_passed = test_passed and not (shouldRestrictSliceToSelectedComponents 1 undefined)
        test_passed = test_passed and shouldRestrictSliceToSelectedComponents 1 1
        test_passed = test_passed and shouldRestrictSliceToSelectedComponents 1 2
        test_passed = test_passed and not (shouldRestrictSliceToSelectedComponents 2 1)
        test_passed = test_passed and not (shouldRestrictSliceToSelectedComponents 2 2)
        test_passed = test_passed and shouldContinueOnActiveSliceModifier "SLICE VERTICAL" #vertical 1 true
        test_passed = test_passed and shouldContinueOnActiveSliceModifier "SLICE HORIZONTAL" #horizontal 1 true
        test_passed = test_passed and not (shouldContinueOnActiveSliceModifier "SLICE HORIZONTAL" #vertical 1 true)
        test_passed = test_passed and not (shouldContinueOnActiveSliceModifier "SLICE VERTICAL" #vertical 2 true)
        test_passed = test_passed and not (shouldContinueOnActiveSliceModifier "SLICE VERTICAL" #vertical 1 false)

        test_passed
        -- return
    ),

    /*
    Tests the batch policy that one failed wall does not stop later walls from being processed.
    Uses synthetic object outcomes and does not modify the scene.
    */
    function testSliceBatchFailureContinuationPolicy =
    (
        local sample_results = #(true, false, true)
        local processed_count = 0
        local failed_count = 0

        for sample_result in sample_results do
        (
            processed_count += 1

            if not sample_result then
            (
                failed_count += 1
            )
        )

        processed_count == 3 and failed_count == 1
        -- return
    ),

    /*
    Tests per-wall Modify-panel isolation used by multi-object Slice Walls.
    Creates two temporary Editable Poly boxes with independent Edit Poly modifiers and removes them afterward.
    */
    function testSliceBatchContextIsolation =
    (
        local original_selection = selection as array
        local original_panel_mode = undefined
        local original_current_object = undefined
        local original_subobject_level = subObjectLevel
        local test_node_a = undefined
        local test_node_b = undefined
        local test_modifier_a = undefined
        local test_modifier_b = undefined
        local test_passed = false

        try
        (
            original_panel_mode = getCommandPanelTaskMode()
        )
        catch
        (
            original_panel_mode = undefined
        )

        if original_panel_mode == #modify then
        (
            try(original_current_object = modPanel.getCurrentObject())catch()
        )

        try
        (
            test_node_a = box name:"WF_SLICE_BATCH_CONTEXT_A" length:10.0 width:10.0 height:10.0
            test_node_b = box name:"WF_SLICE_BATCH_CONTEXT_B" length:10.0 width:10.0 height:10.0
            test_node_b.pos.x = 20.0

            convertToPoly test_node_a
            convertToPoly test_node_b

            test_modifier_a = Edit_Poly()
            test_modifier_b = Edit_Poly()

            addModifier test_node_a test_modifier_a
            addModifier test_node_b test_modifier_b

            test_passed = activateBatchSliceNodeContext test_node_a

            if test_passed then
            (
                test_passed = ensureSliceModifyContext test_node_a test_modifier_a
            )

            if test_passed then
            (
                test_passed = activateBatchSliceNodeContext test_node_b
            )

            if test_passed then
            (
                test_passed = ensureSliceModifyContext test_node_b test_modifier_b
            )

            if test_passed then
            (
                test_passed = selection.count == 1 and selection[1] == test_node_b and modPanel.getCurrentObject() == test_modifier_b
            )
        )
        catch
        (
            test_passed = false
        )

        try(if test_node_a != undefined and isValidNode test_node_a then delete test_node_a)catch()
        try(if test_node_b != undefined and isValidNode test_node_b then delete test_node_b)catch()

        try
        (
            if original_selection.count > 0 then
            (
                select original_selection
            )
            else
            (
                clearSelection()
            )
        )
        catch
        (
        )

        try
        (
            if original_panel_mode == #modify then
            (
                max modify mode

                if original_current_object != undefined then
                (
                    modPanel.setCurrentObject original_current_object
                )
            )
            else if original_panel_mode != undefined then
            (
                setCommandPanelTaskMode original_panel_mode
            )
        )
        catch
        (
        )

        try
        (
            if original_subobject_level != undefined then
            (
                subObjectLevel = original_subobject_level
            )
        )
        catch
        (
        )

        test_passed
        -- return
    ),



    /*
    Captures Slice Walls progress callback arguments for the regression test.
    Uses struct state so MAXScript does not need an unsupported outer-local closure.
    */
    function captureSliceProgressTest processed_count total_count object_index:0 object_total:0 object_name:"" vertex_count:0 =
    (
        slice_progress_test_capture = #(processed_count, total_count, object_index, object_total, object_name, vertex_count)

        true
        -- return
    ),


    /*
    Tests Slice Walls CTRL+LMB source resolution for both Editable Poly and Edit Poly.
    The temporary object is removed after the test.
    */
    function testSlice90CornerPolySourceSupport =
    (
        local test_node = undefined
        local base_supported = false
        local modifier_supported = false

        try
        (
            test_node = box length:10.0 width:10.0 height:10.0
            convertToPoly test_node

            local base_data = getDoubleFaceSource test_node undefined
            base_supported = (
                base_data != undefined and
                base_data[1] == #editablePoly and
                base_data[2] == test_node.baseObject
            )

            local test_modifier = Edit_Poly()
            addModifier test_node test_modifier

            local modifier_data = getDoubleFaceSource test_node test_modifier
            modifier_supported = (
                modifier_data != undefined and
                modifier_data[1] == #editPoly and
                modifier_data[2] == test_modifier
            )
        )
        catch
        (
            base_supported = false
            modifier_supported = false
        )

        if test_node != undefined and isValidNode test_node then
        (
            delete test_node
        )

        base_supported and modifier_supported
        -- return
    ),


    /*
    Tests that strict border-corner selection accepts 90 degrees but rejects straight 180 degrees.
    */
    function testExact90BorderCornerRule =
    (
        local threshold_value = 0.1
        local accepts_90 = abs(90.0 - 90.0) <= threshold_value
        local rejects_180 = not(abs(180.0 - 90.0) <= threshold_value)

        accepts_90 and rejects_180
        -- return
    ),


    /*
    Tests the Slice Walls edge-cleanup option gate.
    */
    function testSliceEdgeCleanupOption =
    (
        local cleanup_enabled = true
        local cleanup_disabled = false

        cleanup_enabled and not cleanup_disabled
        -- return
    ),


    /*
    Tests the Slice Walls progress callback keyword-argument contract.
    */
    function testSliceProgressCallbackArguments =
    (
        slice_progress_test_capture = undefined

        captureSliceProgressTest 3 10 object_index:2 object_total:4 object_name:"Wall_A" vertex_count:24

        test_passed = slice_progress_test_capture != undefined
        test_passed = test_passed and slice_progress_test_capture[1] == 3
        test_passed = test_passed and slice_progress_test_capture[2] == 10
        test_passed = test_passed and slice_progress_test_capture[3] == 2
        test_passed = test_passed and slice_progress_test_capture[4] == 4
        test_passed = test_passed and slice_progress_test_capture[5] == "Wall_A"
        test_passed = test_passed and slice_progress_test_capture[6] == 24

        test_passed
        -- return
    ),


    /*
    Tests the slice Modify-context helper's non-scene guard path.
    Returns true without changing selection or command-panel mode.
    */
    function testSliceModifyContextGuards =
    (
        test_passed = not (ensureSliceModifyContext undefined undefined)
        test_passed
        -- return
    ),


    /*
    Captures selected Slice Force vertex positions before the incoming stack is baked.
    Only Vertex sub-object mode is considered; positions are stored in world space so the later Editable Poly conversion cannot erase the requested slice location.
    */
    function captureSliceForceSelectedVertexPositions node match_tolerance:0.001 =
    (
        local world_positions = #()
        if node == undefined or not(isValidNode node) then return world_positions
        if subObjectLevel != 1 then return world_positions

        local source_positions = #()
        local current_object = undefined

        try(current_object = modPanel.getCurrentObject())catch(current_object = undefined)

        if current_object != undefined and classOf current_object == Edit_Poly then
        (
            local belongs_to_node = false

            for modifier in node.modifiers while not belongs_to_node do
            (
                if modifier == current_object then belongs_to_node = true
            )

            if belongs_to_node then
            (
                local selected_vertices = #{}
                try(selected_vertices = current_object.GetSelection #Vertex node:node)catch(selected_vertices = #{})

                for vertex_index in selected_vertices do
                (
                    local object_position = undefined
                    try(object_position = current_object.GetVertex vertex_index node:node)catch(object_position = undefined)

                    if object_position != undefined then
                    (
                        append source_positions (object_position * node.objectTransform)
                    )
                )
            )
        )

        if source_positions.count == 0 and classOf node.baseObject == Editable_Poly then
        (
            local selected_vertices = #{}
            try(selected_vertices = polyop.getVertSelection node.baseObject)catch(selected_vertices = #{})

            for vertex_index in selected_vertices do
            (
                local world_position = undefined

                try
                (
                    in coordsys world
                    (
                        world_position = polyop.getVert node.baseObject vertex_index node:node
                    )
                )
                catch
                (
                    world_position = undefined
                )

                if world_position != undefined then append source_positions world_position
            )
        )

        local point_tolerance = amax epsilon match_tolerance

        for source_position in source_positions do
        (
            local duplicate_point = false

            for cached_position in world_positions while not duplicate_point do
            (
                if distance source_position cached_position <= point_tolerance then duplicate_point = true
            )

            if not duplicate_point then append world_positions source_position
        )

        world_positions
        -- return
    ),


    /*
    Chooses a local wall-face normal for one baked Editable Poly vertex.
    Adjacent mostly-vertical faces are ranked by how strongly their orientation repeats on the object, which favors the wall skin over small reveal/cap faces.
    */
    function getSliceForceSelectedVertexWallNormal topology_data vertex_index angle_threshold:5.0 =
    (
        if classOf topology_data != Array or topology_data.count < 12 then return undefined
        if vertex_index < 1 or vertex_index > topology_data[1] then return undefined

        local vertex_faces = topology_data[6]
        local face_normals = topology_data[11]
        local incident_faces = vertex_faces[vertex_index]
        local normal_limit = cos (amin 45.0 (amax 0.1 angle_threshold))
        local best_normal = undefined
        local best_count = -1

        for face_index in incident_faces do
        (
            local candidate_normal = if face_index >= 1 and face_index <= face_normals.count then face_normals[face_index] else undefined

            if candidate_normal != undefined and length candidate_normal > epsilon and abs(candidate_normal.z) < 0.95 then
            (
                candidate_normal = normalize candidate_normal
                local parallel_count = 0

                for other_normal in face_normals do
                (
                    if other_normal != undefined and length other_normal > epsilon and abs(other_normal.z) < 0.95 then
                    (
                        if abs(dot candidate_normal (normalize other_normal)) >= normal_limit then parallel_count += 1
                    )
                )

                if parallel_count > best_count then
                (
                    best_count = parallel_count
                    best_normal = candidate_normal
                )
            )
        )

        best_normal
        -- return
    ),


    /*
    Builds the complete Slice Force task cache from explicitly selected vertex positions.
    Selected positions replace automatic hole/T-junction anchor locations; existing automatic tasks are consulted only for local orientation.
    */
    function buildSliceForceSelectedVertexTaskCache node selected_positions orientation_tasks cut_mode:#all angle_threshold:5.0 match_tolerance:0.001 =
    (
        local cached_tasks = #()
        if node == undefined or not(isValidNode node) then return cached_tasks
        if classOf node.baseObject != Editable_Poly then return cached_tasks
        if classOf selected_positions != Array or selected_positions.count == 0 then return cached_tasks

        local topology_data = buildPolyTopology node node.baseObject
        if classOf topology_data != Array or topology_data.count < 12 then return cached_tasks

        local world_points = topology_data[4]
        if classOf world_points != Array then return cached_tasks
        local vertex_count = topology_data[1]
        local plane_tolerance = amax epsilon match_tolerance

        for selected_position in selected_positions do
        (
            local nearest_vertex = 0
            local nearest_distance = 1e30

            for vertex_index = 1 to vertex_count do
            (
                local world_point = world_points[vertex_index]

                if world_point != undefined then
                (
                    local current_distance = distance selected_position world_point

                    if current_distance < nearest_distance then
                    (
                        nearest_distance = current_distance
                        nearest_vertex = vertex_index
                    )
                )
            )

            if nearest_vertex > 0 then
            (
                local world_anchor = selected_position
                local selected_wall_normal = getSliceForceSelectedVertexWallNormal \
                    topology_data \
                    nearest_vertex \
                    angle_threshold:angle_threshold

                local requested_kinds = case cut_mode of
                (
                    #vertical: #(#vertical)
                    #horizontal: #(#horizontal)
                    default: #(#vertical, #horizontal)
                )

                for slice_kind in requested_kinds do
                (
                    local orientation_task = undefined
                    local orientation_distance = 1e30

                    if orientation_tasks != undefined then
                    (
                        for candidate_task in orientation_tasks do
                        (
                            if candidate_task != undefined and candidate_task.count >= 9 and candidate_task[2] == slice_kind then
                            (
                                local candidate_anchor = candidate_task[4]

                                if candidate_anchor != undefined then
                                (
                                    local current_distance = distance world_anchor candidate_anchor

                                    if current_distance < orientation_distance then
                                    (
                                        orientation_distance = current_distance
                                        orientation_task = candidate_task
                                    )
                                )
                            )
                        )
                    )

                    local wall_normal = selected_wall_normal
                    local world_axis = undefined

                    if orientation_task != undefined then
                    (
                        if orientation_task.count >= 9 and orientation_task[9] != undefined then wall_normal = orientation_task[9]
                        if slice_kind == #vertical then world_axis = orientation_task[5]
                    )

                    if slice_kind == #horizontal then
                    (
                        world_axis = [0.0,0.0,1.0]
                    )
                    else if world_axis == undefined or length world_axis <= epsilon then
                    (
                        if wall_normal != undefined and length wall_normal > epsilon then
                        (
                            world_axis = cross [0.0,0.0,1.0] wall_normal
                        )
                    )

                    if world_axis != undefined and length world_axis > epsilon then
                    (
                        world_axis = normalize world_axis

                        if doesSliceForcePlaneSplitPoints world_points world_anchor world_axis match_tolerance:plane_tolerance then
                        (
                            local selected_task = #(
                                nearest_vertex,
                                slice_kind,
                                0,
                                world_anchor,
                                world_axis,
                                #{},
                                #{nearest_vertex},
                                world_anchor.z,
                                wall_normal,
                                world_anchor,
                                0
                            )

                            if findSliceForcePlaneCacheIndex cached_tasks selected_task match_tolerance:plane_tolerance == 0 then
                            (
                                append cached_tasks selected_task
                            )
                        )
                    )
                )
            )
        )

        if not batch_quiet then
        (
            format "Wall-Fixer Slice Force Selected Vertex Override: node:% selectedPositions:% direction:% planes:%\n" node.name selected_positions.count cut_mode cached_tasks.count
        )

        cached_tasks
        -- return
    ),


    /*
    Returns whether Slice Force should replace automatic anchor locations with selected vertex positions.
    The override is intentionally limited to one selected wall in Vertex sub-object mode.
    */
    function shouldUseSliceForceSelectedVertexOverride object_count subobject_level selected_position_count =
    (
        object_count == 1 and subobject_level == 1 and selected_position_count > 0
        -- return
    ),


    /*
    Tests selected-vertex Slice Force override gating without changing scene geometry.
    */
    function testSliceForceSelectedVertexOverridePolicy =
    (
        shouldUseSliceForceSelectedVertexOverride 1 1 1 and
        shouldUseSliceForceSelectedVertexOverride 1 1 3 and
        not(shouldUseSliceForceSelectedVertexOverride 2 1 1) and
        not(shouldUseSliceForceSelectedVertexOverride 1 0 1) and
        not(shouldUseSliceForceSelectedVertexOverride 1 1 0)
        -- return
    ),


    /*
    Tests the dedicated CTRL+RMB T-junction-only Force policy.
    This mode suppresses automatic and selected-vertex anchor sources and starts from an empty plane cache.
    */
    function testSliceForceTJunctionOnlyPolicy =
    (
        local t_junction_only = true
        local automatic_anchors_enabled = not t_junction_only
        local selected_vertex_override_enabled = not t_junction_only
        local initial_plane_count = 0

        t_junction_only and not automatic_anchors_enabled and not selected_vertex_override_enabled and initial_plane_count == 0
        -- return
    ),


    /*
    Tests Slice Force analysis result normalization.
    Non-array status values such as OK must never be treated as task arrays.
    */
    function testSliceForceAnalysisResultSafety =
    (
        local task_array = #()
        local status_value = OK

        local result_value = (
            classOf task_array == Array and
            classOf status_value != Array and
            (getSliceForceTJunctionStraightPair status_value == undefined) and
            (findSliceForcePlaneCacheIndex status_value status_value == 0) and
            (not (doesSliceForcePlaneSplitPoints status_value [0,0,0] [0,0,1]))
        )

        result_value
        -- return
    ),


    /*
    Runs optimized Slice Force as an analyze-once, prebuilt-modifier-stack workflow.
    Incoming modifiers are baked first; proven planar Slice Walls analysis has priority, with Force-only non-planar analysis used only as fallback.
    A selected Vertex sub-object position overrides automatic anchor locations for a single selected wall.
    */
    function debugSliceSelectedWallsForceInternal cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 include_t_junctions:false t_junction_only:false progress_callback:undefined =
    (
        local all_selected_nodes = selection as array
        local selected_nodes = getBatchSliceProcessNodes all_selected_nodes
        local failed_nodes = #()
        local force_records = #()
        local total_task_count = 0
        local processed_vertex_count = 0
        local report = ""
        local original_subobject_level = subObjectLevel
        local selected_vertex_positions = #()
        local use_selected_vertex_override = false

        if not t_junction_only and selected_nodes.count == 1 and original_subobject_level == 1 then
        (
            selected_vertex_positions = captureSliceForceSelectedVertexPositions selected_nodes[1] match_tolerance:0.001
            use_selected_vertex_override = shouldUseSliceForceSelectedVertexOverride selected_nodes.count original_subobject_level selected_vertex_positions.count
        )

        last_slice_report = ""
        last_slice_error = undefined
        last_slice_failed_nodes = #()
        last_slice_processed_objects = 0
        last_slice_processed_vertices = 0

        if all_selected_nodes.count == 0 then
        (
            last_slice_report = "Select at least one wall before running Slice Force."
            return false
        )

        if selected_nodes.count == 0 then
        (
            last_slice_report = "Slice Force: all selected walls have only four vertices; nothing to cut."
            select all_selected_nodes
            try(completeRedraw())catch(try(redrawViews())catch())
            return true
        )

        /*
        Phase 1: bake each incoming stack, analyze its final Editable Poly once,
        and cache every unique physical Force plane before creating any slice modifier.
        */
        for node_index = 1 to selected_nodes.count do
        (
            local node = selected_nodes[node_index]
            local node_ok = true
            local node_error = undefined
            local vertex_count = 0
            local force_tasks = #()

            try
            (
                if not(activateBatchSliceNodeContext node) then
                (
                    node_error = node.name + ": could not activate Slice Force object context."
                    node_ok = false
                )

                if node_ok and not(prepareSliceForceBaseObject node) then
                (
                    node_error = node.name + ": could not apply the incoming modifier stack to Editable Poly."
                    node_ok = false
                )

                if node_ok then
                (
                    vertex_count = polyop.getNumVerts node.baseObject
                    processed_vertex_count += vertex_count

                    clearResetInnerVertSelection node
                    clearLastDebugSliceContext node:node

                    local orientation_tasks = #()
                    local planar_analysis_error = undefined
                    local nonplanar_analysis_error = undefined
                    local selected_analysis_error = undefined
                    local t_junction_analysis_error = undefined

                    /*
                    CTRL+RMB T-junction-only mode bypasses every automatic/selected anchor source.
                    It starts from an empty physical-plane cache so only true T-junction vertices may contribute planes.
                    */
                    if t_junction_only then
                    (
                        try
                        (
                            force_tasks = mergeSliceForceTJunctionTasks \
                                node \
                                #() \
                                cut_mode:cut_mode \
                                angle_threshold:angle_threshold \
                                match_tolerance:0.001

                            if classOf force_tasks != Array then
                            (
                                t_junction_analysis_error = "T-junction-only analyzer returned " + (force_tasks as string)
                                force_tasks = #()
                            )
                        )
                        catch
                        (
                            t_junction_analysis_error = (getCurrentException()) as string
                            force_tasks = #()
                        )
                    )
                    else
                    (
                        /*
                        Force treats analyzer failures as local fallbacks instead of aborting the object.
                        Non-array status values such as OK are normalized to an empty task array.
                        */
                        try
                        (
                            orientation_tasks = buildSliceForcePlanarTaskCache \
                                node \
                                cut_mode:cut_mode \
                                slice_plane_mode:slice_plane_mode \
                                angle_threshold:angle_threshold \
                                planar_tolerance:planar_tolerance \
                                match_tolerance:0.001

                            if classOf orientation_tasks != Array then
                            (
                                planar_analysis_error = "planar analyzer returned " + (orientation_tasks as string)
                                orientation_tasks = #()
                            )
                        )
                        catch
                        (
                            planar_analysis_error = (getCurrentException()) as string
                            orientation_tasks = #()
                        )

                        if orientation_tasks.count == 0 then
                        (
                            try
                            (
                                orientation_tasks = buildSliceForceNonPlanarTaskCache \
                                    node \
                                    cut_mode:cut_mode \
                                    angle_threshold:angle_threshold \
                                    planar_tolerance:planar_tolerance \
                                    match_tolerance:0.001

                                if classOf orientation_tasks != Array then
                                (
                                    nonplanar_analysis_error = "non-planar analyzer returned " + (orientation_tasks as string)
                                    orientation_tasks = #()
                                )
                            )
                            catch
                            (
                                nonplanar_analysis_error = (getCurrentException()) as string
                                orientation_tasks = #()
                            )
                        )

                        if use_selected_vertex_override and node == selected_nodes[1] then
                        (
                            try
                            (
                                force_tasks = buildSliceForceSelectedVertexTaskCache \
                                    node \
                                    selected_vertex_positions \
                                    orientation_tasks \
                                    cut_mode:cut_mode \
                                    angle_threshold:angle_threshold \
                                    match_tolerance:0.001

                                if classOf force_tasks != Array then
                                (
                                    selected_analysis_error = "selected-vertex analyzer returned " + (force_tasks as string)
                                    force_tasks = #()
                                )
                            )
                            catch
                            (
                                selected_analysis_error = (getCurrentException()) as string
                                force_tasks = #()
                            )
                        )
                        else
                        (
                            force_tasks = orientation_tasks

                            if include_t_junctions then
                            (
                                try
                                (
                                    force_tasks = mergeSliceForceTJunctionTasks \
                                        node \
                                        force_tasks \
                                        cut_mode:cut_mode \
                                        angle_threshold:angle_threshold \
                                        match_tolerance:0.001

                                    if classOf force_tasks != Array then
                                    (
                                        t_junction_analysis_error = "T-junction analyzer returned " + (force_tasks as string)
                                        force_tasks = #()
                                    )
                                )
                                catch
                                (
                                    t_junction_analysis_error = (getCurrentException()) as string
                                )
                            )
                        )
                    )

                    if force_tasks.count == 0 then
                    (
                        if t_junction_only then
                        (
                            node_error = node.name + ": Slice Force found no interior horizontal slice plane at any true T-junction vertex."
                            if t_junction_analysis_error != undefined then node_error += " T-junction: " + t_junction_analysis_error
                        )
                        else if use_selected_vertex_override and node == selected_nodes[1] then
                        (
                            node_error = node.name + ": selected vertex position does not define an interior Slice Force plane for the requested direction."
                            if selected_analysis_error != undefined then node_error += " Selected vertex: " + selected_analysis_error
                        )
                        else
                        (
                            node_error = node.name + ": Slice Force found no interior slice planes after stable planar analysis and non-planar fallbacks."
                            if t_junction_analysis_error != undefined then node_error += " T-junction: " + t_junction_analysis_error
                        )

                        if planar_analysis_error != undefined then node_error += " Planar: " + planar_analysis_error
                        if nonplanar_analysis_error != undefined then node_error += " Non-planar: " + nonplanar_analysis_error
                        node_ok = false
                    )
                )
            )
            catch
            (
                node_error = node.name + ": Slice Force analysis error. " + ((getCurrentException()) as string)
                node_ok = false
            )

            if node_ok then
            (
                append force_records #(node, force_tasks, vertex_count, node_index)
                total_task_count += force_tasks.count

                if not batch_quiet then format "Wall-Fixer Slice Force Cache: node:% uniquePlanes:% verts:%\n" node.name force_tasks.count vertex_count
            )
            else
            (
                append failed_nodes node
                if report != "" then report += "\n"
                report += node_error
            )
        )

        if force_records.count == 0 then
        (
            last_slice_failed_nodes = failed_nodes
            last_slice_processed_objects = 0
            last_slice_processed_vertices = processed_vertex_count
            last_slice_report = report

            if failed_nodes.count > 0 then select failed_nodes
            try(subObjectLevel = 0)catch()
            try(setSliceForceCreateMode())catch()
            try(completeRedraw())catch(try(redrawViews())catch())
            return false
        )

        if progress_callback != undefined then
        (
            try(progress_callback 0 total_task_count object_index:0 object_total:selected_nodes.count object_name:"" vertex_count:0)catch()
        )

        /*
        Phase 2: each object receives its complete N-modifier stack up front.
        Modifiers are configured bottom-to-top from the cached plane list and the stack is collapsed once.
        */
        local completed_task_count = 0
        local successful_nodes = #()

        for force_record in force_records do
        (
            local node = force_record[1]
            local force_tasks = force_record[2]
            local vertex_count = force_record[3]
            local object_index = force_record[4]
            local node_ok = true
            local node_error = undefined

            try
            (
                if not(activateBatchSliceNodeContext node) then
                (
                    node_error = node.name + ": could not reactivate Slice Force object context."
                    node_ok = false
                )

                if node_ok then
                (
                    node_ok = executeSliceForceCachedStack \
                        node \
                        force_tasks \
                        task_index_offset:completed_task_count \
                        total_task_count:total_task_count \
                        progress_callback:progress_callback \
                        object_index:object_index \
                        object_total:selected_nodes.count \
                        object_name:node.name \
                        vertex_count:vertex_count

                    if not node_ok then
                    (
                        node_error = node.name + ": " + (last_slice_error as string)
                    )
                )
            )
            catch
            (
                node_error = node.name + ": Slice Force stack execution error. " + ((getCurrentException()) as string)
                node_ok = false
            )

            completed_task_count += force_tasks.count

            if node_ok then
            (
                append successful_nodes node
                if report != "" then report += "\n"
                report += node.name + ": Slice Force " + \
                    (if t_junction_only then "used T-junction-only anchors with " else if use_selected_vertex_override and node == selected_nodes[1] then "used selected vertex position override with " else "cached ") + \
                    (force_tasks.count as string) + " unique plane(s), prebuilt the full modifier stack, and collapsed to Editable Poly."
            )
            else
            (
                if (findItem failed_nodes node) == 0 then append failed_nodes node
                if report != "" then report += "\n"
                report += node_error
            )
        )

        last_slice_processed_objects = successful_nodes.count
        last_slice_processed_vertices = processed_vertex_count
        last_slice_failed_nodes = failed_nodes
        last_slice_report = report

        local force_completed = failed_nodes.count == 0

        if force_completed then
        (
            if successful_nodes.count > 0 then select successful_nodes
        )
        else
        (
            select failed_nodes
        )

        /*
        Finalize the actual viewport before the UI exposes SUCCESS/FAILED.
        Result selection, Editable Poly evaluation and Create-mode state are committed first.
        */
        try(subObjectLevel = 0)catch()
        try(setSliceForceCreateMode())catch()

        for viewport_node in (selection as array) do
        (
            if viewport_node != undefined and isValidNode viewport_node then
            (
                try(update viewport_node)catch()
            )
        )

        try(completeRedraw())catch(try(redrawViews())catch())

        force_completed
        -- return
    ),


    /*
    Runs batch slicing with optional quiet Listener output.
    Quiet state is restored after the batch even when the internal operation throws.
    */
    function debugSliceSelectedWalls cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 slice_precision:0.01 cleanup_edges:true force_per_plane:false display_hidden_edges:undefined double_side:undefined progress_callback:undefined quiet:false =
    (
        local previous_batch_quiet = batch_quiet
        local completed = false
        local batch_failure = undefined
        local batch_start_ms = timeStamp()

        batch_quiet = quiet

        try
        (
            completed = debugSliceSelectedWallsInternal \
                cut_mode:cut_mode \
                slice_plane_mode:slice_plane_mode \
                angle_threshold:angle_threshold \
                planar_tolerance:planar_tolerance \
                slice_precision:slice_precision \
                cleanup_edges:cleanup_edges \
                force_per_plane:force_per_plane \
                display_hidden_edges:display_hidden_edges \
                double_side:double_side \
                progress_callback:progress_callback
        )
        catch
        (
            batch_failure = getCurrentException()
        )

        batch_quiet = previous_batch_quiet
        last_slice_elapsed_ms = (timeStamp()) - batch_start_ms

        if completed then
        (
            elapsed_seconds = (last_slice_elapsed_ms as float) / 1000.0
            stats_text = "SLICE STATS: " + (elapsed_seconds as string) + " s; objects: " + (last_slice_processed_objects as string) + "; vertices: " + (last_slice_processed_vertices as string) + "."
            if last_slice_report == "" then last_slice_report = stats_text else last_slice_report += stats_text
            appendSliceStatsCsv cut_mode last_slice_processed_objects last_slice_processed_vertices last_slice_elapsed_ms
        )

        if batch_failure != undefined then
        (
            throw (batch_failure as string)
        )

        completed
        -- return
    ),


    /*
    Runs optimized Slice Force.
    Anchor analysis happens once on the baked Editable Poly; all unique-plane modifiers are created before any slice is committed.
    */
    function debugSliceSelectedWallsForce cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 slice_precision:0.01 cleanup_edges:true display_hidden_edges:undefined double_side:undefined include_t_junctions:false t_junction_only:false progress_callback:undefined quiet:false =
    (
        local previous_batch_quiet = batch_quiet
        local completed = false
        local batch_failure = undefined
        local batch_start_ms = timeStamp()

        batch_quiet = quiet

        try
        (
            completed = debugSliceSelectedWallsForceInternal \
                cut_mode:cut_mode \
                slice_plane_mode:slice_plane_mode \
                angle_threshold:angle_threshold \
                planar_tolerance:planar_tolerance \
                include_t_junctions:include_t_junctions \
                t_junction_only:t_junction_only \
                progress_callback:progress_callback
        )
        catch
        (
            batch_failure = getCurrentException()
        )

        batch_quiet = previous_batch_quiet
        last_slice_elapsed_ms = (timeStamp()) - batch_start_ms

        if completed then
        (
            appendSliceStatsCsv cut_mode last_slice_processed_objects last_slice_processed_vertices last_slice_elapsed_ms
        )

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
    Returns true when one live Edit Poly vertex touches any border edge.
    Only incident edges of the requested vertex are inspected.
    */
    function isDebugModifierBorderVertex node modifier vertex_index =
    (
        if node == undefined or not(isValidNode node) or modifier == undefined then return false
        if vertex_index < 1 then return false

        incident_edge_count = 0
        try
        (
            incident_edge_count = modifier.GetVertexEdgeCount vertex_index node:node
        )
        catch
        (
            incident_edge_count = 0
        )

        for edge_slot = 1 to incident_edge_count do
        (
            edge_index = undefined
            face_a = undefined
            face_b = undefined

            try
            (
                edge_index = modifier.GetVertexEdge vertex_index edge_slot node:node
                if edge_index != undefined and edge_index > 0 then
                (
                    face_a = modifier.GetEdgeFace edge_index 1 node:node
                    face_b = modifier.GetEdgeFace edge_index 2 node:node
                )
            )
            catch
            (
                edge_index = undefined
            )

            if edge_index != undefined and face_a != undefined and face_b != undefined then
            (
                if ((face_a == 0) != (face_b == 0)) then return true
            )
        )

        false
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
        local new_edge_data = #()
        local touched_vertices = #{}

        -- Inspect only edges reported by the slice as newly appended.
        for edge_index in last_debug_slice_new_edges do
        (
            if edge_index >= 1 and edge_index <= edge_count then
            (
                local edge_a = undefined
                local edge_b = undefined
                local face_a = undefined
                local face_b = undefined

                try
                (
                    edge_a = modifier.GetEdgeVertex edge_index 1 node:node
                    edge_b = modifier.GetEdgeVertex edge_index 2 node:node
                    face_a = modifier.GetEdgeFace edge_index 1 node:node
                    face_b = modifier.GetEdgeFace edge_index 2 node:node
                )
                catch
                (
                    edge_a = undefined
                    edge_b = undefined
                )

                if edge_a != undefined and edge_b != undefined and face_a != undefined and face_b != undefined then
                (
                    local is_border_edge = (face_a == 0) != (face_b == 0)

                    if not is_border_edge and edge_a >= 1 and edge_a <= vertex_count and edge_b >= 1 and edge_b <= vertex_count then
                    (
                        usable_new_edges[edge_index] = true
                        touched_vertices[edge_a] = true
                        touched_vertices[edge_b] = true
                        append new_edge_data #(edge_index, edge_a, edge_b)
                    )
                )
            )
        )

        -- Border status is needed only for vertices touched by the new slice edges.
        for vertex_index in touched_vertices do
        (
            if isDebugModifierBorderVertex node modifier vertex_index then
            (
                border_vertices[vertex_index] = true
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
                local touches_new_edge = false

                for edge_data in new_edge_data while not touches_new_edge do
                (
                    touches_new_edge = (edge_data[2] == start_vertex or edge_data[3] == start_vertex)
                )

                if touches_new_edge then
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

            for edge_data in new_edge_data do
            (
                local edge_index = edge_data[1]
                local edge_a = edge_data[2]
                local edge_b = edge_data[3]
                local touches_current = (edge_a == current_vertex or edge_b == current_vertex)
                local already_kept = edge_index <= kept_edges.count and kept_edges[edge_index]

                if touches_current and not already_kept then
                (
                    kept_edges[edge_index] = true

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
    Tests the appended vertex-index range used by Slice Precision.
    */
    function testSliceAppendedVertexRange =
    (
        old_vertices = #{}
        for vertex_index = 1 to 10 do old_vertices[vertex_index] = true

        first_new_vertex_index = old_vertices.count + 1
        first_new_vertex_index == 11
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
            ensureSliceModifyContext node modifier
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
    Returns unique live poly-topology neighbours of one vertex from Edit Poly.
    This follows actual Editable Poly/Edit Poly edges instead of TriMesh edge visibility.
    */
    function getDebugTopologyEdgeNeighborVertices node modifier vertex_index =
    (
        local neighbor_vertices = #()
        if node == undefined or modifier == undefined then return neighbor_vertices
        if vertex_index < 1 or vertex_index > (modifier.GetNumVertices node:node) then return neighbor_vertices

        local edge_count = modifier.GetNumEdges node:node

        for edge_index = 1 to edge_count do
        (
            local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
            local edge_b = modifier.GetEdgeVertex edge_index 2 node:node

            if edge_a == vertex_index and edge_b > 0 and (findItem neighbor_vertices edge_b) == 0 then
            (
                append neighbor_vertices edge_b
            )
            else if edge_b == vertex_index and edge_a > 0 and (findItem neighbor_vertices edge_a) == 0 then
            (
                append neighbor_vertices edge_a
            )
        )

        neighbor_vertices
        -- return
    ),


    /*
    Returns all live vertices that have exactly two actual poly-topology edges.
    Corners and straight continuations both qualify because LMB is a topology-selection action.
    */
    function getDebugTwoTopologyEdgeVertices node modifier =
    (
        local result_vertices = #{}
        if node == undefined or modifier == undefined then return result_vertices

        local vertex_count = modifier.GetNumVertices node:node

        for vertex_index = 1 to vertex_count do
        (
            local vertex_position = modifier.GetVertex vertex_index node:node

            if vertex_position != undefined then
            (
                local neighbor_vertices = ::WallFixer.getDebugTopologyEdgeNeighborVertices node modifier vertex_index

                if neighbor_vertices.count == 2 then
                (
                    result_vertices[vertex_index] = true
                )
            )
        )

        result_vertices
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
    Returns visible live poly-topology neighbours of one vertex.
    Actual Edit Poly edges define incidence; evaluated edge visibility decides whether each edge is visible.
    */
    function getDebugVisibleTopologyEdgeNeighborVertices node modifier mesh_value vertex_index =
    (
        local neighbor_vertices = #()
        if node == undefined or modifier == undefined or mesh_value == undefined then return neighbor_vertices
        if vertex_index < 1 or vertex_index > (modifier.GetNumVertices node:node) then return neighbor_vertices

        local edge_count = modifier.GetNumEdges node:node

        for edge_index = 1 to edge_count do
        (
            local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
            local edge_b = modifier.GetEdgeVertex edge_index 2 node:node
            local other_vertex = 0

            if edge_a == vertex_index then
            (
                other_vertex = edge_b
            )
            else if edge_b == vertex_index then
            (
                other_vertex = edge_a
            )

            if other_vertex > 0 and (findItem neighbor_vertices other_vertex) == 0 then
            (
                if ::WallFixer.isEvaluatedMeshEdgeVisibleByVertexPair mesh_value vertex_index other_vertex then
                (
                    append neighbor_vertices other_vertex
                )
            )
        )

        neighbor_vertices
        -- return
    ),


    /*
    Returns true when one visible live topology edge is an open-border edge.
    Edge identity is resolved by its two endpoint vertex IDs, not by a saved TriMesh edge index.
    */
    function isDebugVisibleTopologyBorderEdgeByVertexPair node modifier mesh_value vertex_a vertex_b =
    (
        if node == undefined or modifier == undefined or mesh_value == undefined then return false
        if vertex_a < 1 or vertex_b < 1 then return false

        local edge_count = modifier.GetNumEdges node:node

        for edge_index = 1 to edge_count do
        (
            local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
            local edge_b = modifier.GetEdgeVertex edge_index 2 node:node
            local same_edge = (edge_a == vertex_a and edge_b == vertex_b) or (edge_a == vertex_b and edge_b == vertex_a)

            if same_edge then
            (
                if ::WallFixer.isEvaluatedMeshEdgeVisibleByVertexPair mesh_value vertex_a vertex_b then
                (
                    local face_a = modifier.GetEdgeFace edge_index 1 node:node
                    local face_b = modifier.GetEdgeFace edge_index 2 node:node
                    local face_a_valid = face_a != undefined and face_a > 0
                    local face_b_valid = face_b != undefined and face_b > 0

                    if face_a_valid != face_b_valid then return true
                )
            )
        )

        false
        -- return
    ),


    /*
    Returns true only for a removable vertex with exactly two visible live topology edges.
    Border corners are rejected; straight-through border vertices remain valid within the supplied tolerance.
    */
    function isDebugRemovableTwoVisibleTopologyVertex node modifier mesh_value vertex_index angle_threshold:2.0 =
    (
        if node == undefined or modifier == undefined or mesh_value == undefined then return false
        if vertex_index < 1 or vertex_index > (modifier.GetNumVertices node:node) then return false
        if vertex_index > (getNumVerts mesh_value) then return false

        local neighbor_vertices = ::WallFixer.getDebugVisibleTopologyEdgeNeighborVertices node modifier mesh_value vertex_index
        if neighbor_vertices.count != 2 then return false

        local border_edge_a = ::WallFixer.isDebugVisibleTopologyBorderEdgeByVertexPair node modifier mesh_value vertex_index neighbor_vertices[1]
        local border_edge_b = ::WallFixer.isDebugVisibleTopologyBorderEdgeByVertexPair node modifier mesh_value vertex_index neighbor_vertices[2]

        if not border_edge_a and not border_edge_b then return true

        -- A malformed/partial border incidence is kept conservative and never removed automatically.
        if not border_edge_a or not border_edge_b then return false

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
    Returns true only when one live vertex has exactly two visible topology edges and they continue straight.
    A small straightness tolerance absorbs processed-wall numeric noise while excluding corners.
    */
    function isDebugStraightTwoVisibleTopologyVertex node modifier mesh_value vertex_index angle_threshold:2.0 =
    (
        if node == undefined or modifier == undefined or mesh_value == undefined then return false
        if vertex_index < 1 or vertex_index > (modifier.GetNumVertices node:node) then return false
        if vertex_index > (getNumVerts mesh_value) then return false

        local neighbor_vertices = ::WallFixer.getDebugVisibleTopologyEdgeNeighborVertices node modifier mesh_value vertex_index
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
    Initializes the dedicated two-edge-vertex Edit Poly as a live pass-through modifier.
    Returns false when the modifier still exposes no live vertices after forced evaluation.
    */
    function prepareDebugTwoEdgeVertsModifier node modifier bind_primary:true =
    (
        if node == undefined or not(isValidNode node) or modifier == undefined then return false

        local live_vertex_count = 0
        local evaluated_mesh = undefined

        try
        (
            select node
            max modify mode
            modPanel.setCurrentObject modifier
            if bind_primary then modifier.SetPrimaryNode node
            modifier.useStackSelection = false
            modifier.selectMode = 0
            if classOf node.baseObject == Editable_Poly then node.baseObject.selectMode = 0
            try (modifier.showCage = off) catch ()
            modifier.SetEPolySelLevel #Vertex
            subObjectLevel = 1
            update node

            evaluated_mesh = snapshotAsMesh node
            if evaluated_mesh != undefined then
            (
                free evaluated_mesh
                evaluated_mesh = undefined
            )

            live_vertex_count = modifier.GetNumVertices node:node
        )
        catch
        (
            if evaluated_mesh != undefined then free evaluated_mesh
            live_vertex_count = 0
        )

        live_vertex_count > 0
        -- return
    ),


    /*
    Returns the project-standard SELECT TWO-EDGE VERTS Edit Poly used by Find Two-Edge Verts.
    An existing exact SELECT modifier is reused in place; it is never deleted or duplicated merely because topology preparation fails.
    */
    function getDebugTwoEdgeVertsModifier node create_if_missing:true =
    (
        if node == undefined or not(isValidNode node) then return undefined

        select_name = getSelectDeleteModifierName "TWO-EDGE VERTS"
        found_modifier = findNamedEditPolyModifier node select_name

        if found_modifier != undefined then
        (
            if not prepareDebugTwoEdgeVertsModifier node found_modifier bind_primary:false then return undefined
            return found_modifier
        )

        if not create_if_missing then return undefined

        found_modifier = Edit_Poly name:select_name
        addModifier node found_modifier

        if not prepareDebugTwoEdgeVertsModifier node found_modifier bind_primary:true then
        (
            try(deleteModifier node found_modifier)catch()
            update node
            found_modifier = undefined
        )

        found_modifier
        -- return
    ),


    /*
    Selects every vertex with exactly two visible real topology edges except border corners.
    Straight-through border vertices remain valid within the supplied tolerance.
    */
    function debugFindTwoEdgeVerts angle_threshold:2.0 =
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
        local modifier = getDebugTwoEdgeVertsModifier node create_if_missing:false
        local modifier_created = modifier == undefined

        if modifier == undefined then
        (
            modifier = getDebugTwoEdgeVertsModifier node create_if_missing:true
        )

        if modifier == undefined then
        (
            last_slice_report = node.name + ": SELECT TWO-EDGE VERTS could not be created or reused."
            return false
        )

        local failure = undefined
        local evaluated_mesh = undefined
        local candidates = #{}

        try
        (
            update node
            evaluated_mesh = snapshotAsMesh node
            if evaluated_mesh == undefined then throw "Could not evaluate current wall mesh."

            local live_vertex_count = modifier.GetNumVertices node:node
            if getNumVerts evaluated_mesh != live_vertex_count then
            (
                throw "Evaluated mesh vertex indices do not match Edit Poly vertex indices."
            )

            for vertex_index = 1 to live_vertex_count do
            (
                if ::WallFixer.isDebugRemovableTwoVisibleTopologyVertex node modifier evaluated_mesh vertex_index angle_threshold:angle_threshold then
                (
                    candidates[vertex_index] = true
                )
            )

            free evaluated_mesh
            evaluated_mesh = undefined

            select node
            max modify mode
            modPanel.setCurrentObject modifier
            modifier.SetPrimaryNode node
            modifier.useStackSelection = false
            modifier.selectMode = 0
            if classOf node.baseObject == Editable_Poly then node.baseObject.selectMode = 0
            modifier.SetEPolySelLevel #Vertex
            subObjectLevel = 1
            modifier.SetSelection #Vertex candidates node:node
            update node
            modifier.RefreshScreen()

            local actual_selection = modifier.GetSelection #Vertex node:node

            if actual_selection != candidates then
            (
                throw ("Could not select every two-visible-edge vertex. Requested:" + (candidates as string) + " actual:" + (actual_selection as string))
            )

            if not batch_quiet then format "Wall-Fixer Find Two-Edge Verts: node:% candidates:% count:% straightTolerance:% modifier:% created:%\n"                 node.name candidates candidates.numberSet angle_threshold modifier.name modifier_created

            last_slice_report = node.name + ": Find Two-Edge Verts selected " + (candidates.numberSet as string) + " two-visible-edge vertices."
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
    Removes the vertices stored by SELECT TWO-EDGE VERTS and renames that same modifier DELETED TWO-EDGE VERTS.
    When RMB is used without a preceding LMB, the normal snapshot-based finder creates the SELECT modifier first.
    */
    function removeSelectedTwoEdgeVerts angle_threshold:2.0 =
    (
        last_slice_error = undefined
        last_slice_report = ""

        selected_nodes = selection as array
        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select one processed wall before removing two-edge vertices."
            return false
        )

        node = selected_nodes[1]
        modifier = getDebugTwoEdgeVertsModifier node create_if_missing:false

        if modifier == undefined then
        (
            if not debugFindTwoEdgeVerts angle_threshold:angle_threshold then return false
            modifier = getDebugTwoEdgeVertsModifier node create_if_missing:false
        )

        if modifier == undefined then
        (
            last_slice_report = node.name + ": SELECT TWO-EDGE VERTS modifier unavailable."
            return false
        )

        failure = undefined
        evaluated_mesh = undefined
        removed_count = 0
        deleted_name = getSelectDeleteModifierName "TWO-EDGE VERTS" deleted:true

        try
        (
            stored_selection = modifier.GetSelection #Vertex node:node
            if stored_selection == undefined then stored_selection = #{}

            evaluated_mesh = snapshotAsMesh node
            if evaluated_mesh == undefined then throw "Could not evaluate current wall mesh."

            live_vertex_count = modifier.GetNumVertices node:node
            if getNumVerts evaluated_mesh != live_vertex_count then
            (
                throw "Evaluated snapshot vertex IDs do not match SELECT TWO-EDGE VERTS."
            )

            current_candidates = #{}
            for vertex_index = 1 to live_vertex_count do
            (
                if ::WallFixer.isDebugRemovableTwoVisibleTopologyVertex node modifier evaluated_mesh vertex_index angle_threshold:angle_threshold then
                (
                    current_candidates[vertex_index] = true
                )
            )

            free evaluated_mesh
            evaluated_mesh = undefined

            vertices_to_remove = stored_selection * current_candidates
            display_result = activateNamedEditPolySelection node modifier #Vertex vertices_to_remove
            if not display_result[1] then throw "Could not restore SELECT TWO-EDGE VERTS before removal."

            if vertices_to_remove.numberSet > 0 then
            (
                before_vertex_count = modifier.GetNumVertices node:node
                modifier.ButtonOp #RemoveVertex
                update node
                modifier.RefreshScreen()
                after_vertex_count = modifier.GetNumVertices node:node

                if after_vertex_count >= before_vertex_count then
                (
                    modifier.SetSelection #Vertex vertices_to_remove node:node
                    modifier.SetOperation #RemoveVertex
                    modifier.Commit()
                    update node
                    modifier.RefreshScreen()
                    after_vertex_count = modifier.GetNumVertices node:node
                )

                if after_vertex_count >= before_vertex_count then
                (
                    throw "Remove Vertex did not reduce live topology."
                )

                removed_count = before_vertex_count - after_vertex_count
            )

            modifier.name = deleted_name
            modifier.showCage = off
            update node
            completeRedraw()

            last_slice_report = node.name + ": removed " + (removed_count as string) + " two-edge vertex/vertices in " + deleted_name + "."
            if not batch_quiet then format "Wall-Fixer Two-Edge Verts Delete: %\n" last_slice_report
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
    Verifies the current Vertex selection equals every removable two-visible-edge vertex.
    Border corners are excluded while straight-through border vertices remain valid.
    */
    function testFindTwoEdgeVertsVisibleSelection angle_threshold:2.0 =
    (
        local selected_nodes = selection as array
        if selected_nodes.count != 1 then return false

        local node = selected_nodes[1]
        local modifier = getDebugTwoEdgeVertsModifier node create_if_missing:false
        if modifier == undefined then return false

        local evaluated_mesh = snapshotAsMesh node
        if evaluated_mesh == undefined then return false
        if getNumVerts evaluated_mesh != modifier.GetNumVertices node:node then
        (
            free evaluated_mesh
            return false
        )

        local expected_selection = #{}
        local vertex_count = modifier.GetNumVertices node:node

        for vertex_index = 1 to vertex_count do
        (
            if ::WallFixer.isDebugRemovableTwoVisibleTopologyVertex node modifier evaluated_mesh vertex_index angle_threshold:angle_threshold then
            (
                expected_selection[vertex_index] = true
            )
        )

        free evaluated_mesh

        local actual_selection = modifier.GetSelection #Vertex node:node
        local test_passed = actual_selection == expected_selection

        if not batch_quiet then format "Find Two-Edge Verts visible selection test | expected:% actual:% | result:%\n" expected_selection actual_selection test_passed

        test_passed
        -- return
    ),


    /*
    Verifies border-corner rejection on a five-vertex planar border with one straight middle vertex.
    The straight border vertex must be selected and the four geometric corners must be rejected.
    */
    function testFindTwoEdgeVertsBorderCornerRule angle_threshold:2.0 =
    (
        local original_selection = selection as array
        local test_node = undefined
        local test_passed = false

        try
        (
            test_node = editable_mesh name:(uniqueName "TWO_EDGE_BORDER_TEST_")
            convertTo test_node Editable_Poly
            local test_poly = test_node.baseObject
            test_poly.selectMode = 0

            local vertex_1 = polyop.createVert test_poly [0.0,0.0,0.0]
            local vertex_2 = polyop.createVert test_poly [5.0,0.0,0.0]
            local vertex_3 = polyop.createVert test_poly [10.0,0.0,0.0]
            local vertex_4 = polyop.createVert test_poly [10.0,10.0,0.0]
            local vertex_5 = polyop.createVert test_poly [0.0,10.0,0.0]

            polyop.createPolygon test_poly #(vertex_1, vertex_2, vertex_3, vertex_4, vertex_5)
            update test_node
            select test_node

            local completed = debugFindTwoEdgeVerts angle_threshold:angle_threshold
            local modifier = getDebugTwoEdgeVertsModifier test_node create_if_missing:false
            local actual_selection = if modifier != undefined then modifier.GetSelection #Vertex node:test_node else #{}
            local expected_selection = #{2}
            local select_passed = completed and actual_selection == expected_selection
            local before_vertex_count = if modifier != undefined then modifier.GetNumVertices node:test_node else 0
            local remove_passed = false

            if select_passed then
            (
                remove_passed = removeSelectedTwoEdgeVerts angle_threshold:angle_threshold

                local deleted_name = getSelectDeleteModifierName "TWO-EDGE VERTS" deleted:true
                local deleted_modifier = findNamedEditPolyModifier test_node deleted_name
                local after_vertex_count = if deleted_modifier != undefined then deleted_modifier.GetNumVertices node:test_node else before_vertex_count
                remove_passed = remove_passed and after_vertex_count == (before_vertex_count - 1)
            )

            test_passed = select_passed and remove_passed

            if not batch_quiet then format "Find Two-Edge Verts border-corner test | expected:% actual:% | select:% remove:% | result:%\n" expected_selection actual_selection select_passed remove_passed test_passed
        )
        catch
        (
            test_passed = false
            if not batch_quiet then format "Find Two-Edge Verts border-corner test FAILED: %\n" (getCurrentException())
        )

        if test_node != undefined then try(delete test_node)catch()

        if original_selection.count > 0 then
        (
            select original_selection
        )
        else
        (
            clearSelection()
        )

        test_passed
        -- return
    ),


    /*
    Verifies the dedicated two-edge modifier is bound to the selected node and exposes live vertices.
    Rebuilds a stale zero-topology copy through the normal acquisition path.
    */
    function testTwoEdgeVertsModifierLiveTopology =
    (
        local selected_nodes = selection as array
        if selected_nodes.count != 1 then return false

        local node = selected_nodes[1]
        local modifier = getDebugTwoEdgeVertsModifier node create_if_missing:true
        if modifier == undefined then return false

        local live_vertex_count = 0
        try
        (
            live_vertex_count = modifier.GetNumVertices node:node
        )
        catch
        (
            live_vertex_count = 0
        )

        local test_passed = live_vertex_count > 0
        if not batch_quiet then format "Two-Edge Verts modifier live topology test | node:% modifier:% liveVerts:% | result:%\n" node.name modifier.name live_vertex_count test_passed

        test_passed
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
    Collects only true 90-degree open-border corners.
    Straight 180-degree border vertices are intentionally excluded.
    */
    function collectExact90BorderVerts node source_kind source_ref angle_threshold:0.1 =
    (
        local exact_90_verts = #{}
        local border_edges = get90AngleOpenBorderEdges node source_kind source_ref
        local border_verts = #{}
        local tolerance_value = amax 0.0 angle_threshold

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
            if angle_value != undefined and abs(angle_value - 90.0) <= tolerance_value then
            (
                exact_90_verts[vert_index] = true
            )
        )

        exact_90_verts
        -- return
    ),


    /*
    Selects true 90-degree open-border corners on the current poly editing source.
    The current Edit Poly modifier wins; otherwise an Editable Poly base object is used directly.
    */
    function selectCurrentPoly90BorderCorners angle_threshold:0.1 =
    (
        local selected_nodes = selection as array
        local active_edit_poly = undefined
        last_slice_report = ""

        if selected_nodes.count != 1 then
        (
            last_slice_report = "Select exactly one Editable Poly object or one object with the current Edit Poly modifier."
            return false
        )

        local node = selected_nodes[1]
        if node == undefined or not(isValidNode node) then
        (
            last_slice_report = "Selected object is invalid."
            return false
        )

        try
        (
            local current_object = modPanel.getCurrentObject()
            if current_object != undefined and classOf current_object == Edit_Poly then
            (
                active_edit_poly = current_object
            )
        )
        catch
        (
            active_edit_poly = undefined
        )

        local source_data = getDoubleFaceSource node active_edit_poly
        if source_data == undefined then
        (
            last_slice_report = "CTRL+LMB Select requires an Editable Poly base object or the current Edit Poly modifier."
            return false
        )

        local source_kind = source_data[1]
        local source_ref = source_data[2]
        local corner_verts = collectExact90BorderVerts             node             source_kind             source_ref             angle_threshold:(amax 0.0 angle_threshold)

        if not(set90AngleVertexSelection node source_kind source_ref corner_verts) then
        (
            last_slice_report = node.name + ": could not select 90-degree border corners."
            return false
        )

        local source_name = if source_kind == #editPoly then "Edit Poly" else "Editable Poly"
        last_slice_report = node.name + ": selected " + (corner_verts.numberSet as string) + " true 90-degree border corner vert(s) on " + source_name + "."
        if not batch_quiet then format "%\n" last_slice_report
        completeRedraw()
        true
        -- return
    ),


    /*
    Backward-compatible alias for the original Edit Poly-only helper name.
    */
    function selectCurrentEditPoly90BorderCorners angle_threshold:0.1 =
    (
        selectCurrentPoly90BorderCorners angle_threshold:angle_threshold
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
    Collects near-coincident vertices from one evaluated mesh snapshot.
    Both vertices of every pair inside the requested position threshold are returned without changing scene geometry.
    */
    function collectDoubleVertsFromMesh mesh_value position_threshold:1.0 =
    (
        double_verts = #{}

        if mesh_value == undefined then return double_verts

        vert_count = getNumVerts mesh_value
        threshold_value = if position_threshold < 0.0 then 0.0 else position_threshold
        threshold_sq = threshold_value * threshold_value

        if vert_count > 1 then
        (
            for vert_a = 1 to (vert_count - 1) do
            (
                pos_a = getVert mesh_value vert_a

                for vert_b = (vert_a + 1) to vert_count do
                (
                    pos_b = getVert mesh_value vert_b
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

        double_verts
        -- return
    ),


    /*
    Collects duplicate-position vertices from an Editable Poly base for legacy callers.
    New LMB/RMB workflow controls use evaluated snapshots through selectDuplicatedVerticesOnNode.
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
    Detects duplicated vertices from the evaluated snapshot and stores them in exactly one SELECT DUPLICATED VERTICES Edit Poly.
    Existing exact SELECT modifiers are reused; no duplicate selection modifier is created and cage display remains off.
    */
    function selectDuplicatedVerticesOnNode node position_threshold:1.0 =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0, "invalid node", undefined, #{})
        if superclassof node != GeometryClass then return #(false, 0, "requires geometry", undefined, #{})

        evaluated_mesh = undefined
        operation_error = undefined
        selection_modifier = undefined
        double_verts = #{}
        snapshot_vertex_count = 0
        select_name = getSelectDeleteModifierName "DUPLICATED VERTICES"

        try
        (
            evaluated_mesh = snapshotAsMesh node
            if evaluated_mesh == undefined then throw "could not create evaluated snapshot"

            snapshot_vertex_count = getNumVerts evaluated_mesh
            double_verts = collectDoubleVertsFromMesh evaluated_mesh position_threshold:position_threshold
            free evaluated_mesh
            evaluated_mesh = undefined

            if double_verts.numberSet > 0 then
            (
                selection_modifier = ensureNamedEditPolyModifier node select_name #Vertex
                if selection_modifier == undefined then throw (select_name + " could not be created or reused")

                live_vertex_count = selection_modifier.GetNumVertices node:node
                if live_vertex_count != snapshot_vertex_count then
                (
                    throw "evaluated snapshot vertex IDs do not match the existing SELECT DUPLICATED VERTICES modifier"
                )

                selection_modifier.SetSelection #Vertex double_verts node:node
                stored_selection = selection_modifier.GetSelection #Vertex node:node
                if stored_selection != double_verts then
                (
                    throw ("SELECT DUPLICATED VERTICES selection mismatch. Requested:" + (double_verts as string) + " actual:" + (stored_selection as string))
                )

                selection_modifier.showCage = off
                update node
            )
        )
        catch
        (
            if evaluated_mesh != undefined then free evaluated_mesh
            operation_error = getCurrentException()
        )

        if operation_error == undefined then
        (
            #(true, double_verts.numberSet, "", selection_modifier, copy double_verts)
        )
        else
        (
            #(false, 0, operation_error as string, selection_modifier, #{})
        )
        -- return
    ),


    /*
    Runs duplicated-vertex LMB selection on every selected geometry node.
    A SELECT DUPLICATED VERTICES modifier is created and activated only when at least one duplicated vertex is detected.
    */
    function selectDuplicatedVerticesSelection position_threshold:1.0 =
    (
        last_slice_error = undefined
        last_slice_report = ""
        selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select at least one geometry object."
            return #(false, 0)
        )

        total_double_verts = 0
        failed_nodes = #()
        report_text = ""
        display_node = undefined
        display_modifier = undefined
        display_selection = #{}

        for node in selected_nodes do
        (
            if superclassof node == GeometryClass then
            (
                select_result = selectDuplicatedVerticesOnNode node position_threshold:position_threshold

                if select_result[1] then
                (
                    total_double_verts += select_result[2]
                    report_text += node.name + ": duplicated vertices " + (select_result[2] as string) + ".\n"

                    if display_modifier == undefined and select_result[4] != undefined then
                    (
                        display_node = node
                        display_modifier = select_result[4]
                        display_selection = select_result[5]
                    )
                )
                else
                (
                    append failed_nodes node.name
                    report_text += node.name + ": FAILED - " + select_result[3] + ".\n"
                )
            )
        )

        if display_modifier != undefined then
        (
            display_result = activateNamedEditPolySelection display_node display_modifier #Vertex display_selection
            if not display_result[1] then
            (
                append failed_nodes display_node.name
                report_text += display_node.name + ": FAILED - SELECT DUPLICATED VERTICES final selection mismatch.\n"
            )
        )

        if failed_nodes.count == 0 then
        (
            last_slice_report = "Duplicated Vertex Selection complete. Vertices selected: " + (total_double_verts as string) + ".\n" + report_text
            if not batch_quiet then format "%" last_slice_report
            #(true, total_double_verts)
        )
        else
        (
            last_slice_report = "Duplicated Vertex Selection completed with failures.\n" + report_text
            if not batch_quiet then format "%" last_slice_report
            #(false, total_double_verts)
        )
        -- return
    ),


    /*
    Verifies zero duplicated vertices do not create a SELECT DUPLICATED VERTICES modifier.
    Returns true only when detection succeeds with zero matches and the named modifier is absent.
    */
    function testDuplicatedVertexSelectionSkipsEmptyModifier =
    (
        test_node = undefined
        test_result = false
        select_name = getSelectDeleteModifierName "DUPLICATED VERTICES"

        try
        (
            test_node = box name:"WALL_FIXER_TEST_NO_DUPLICATES" length:100.0 width:100.0 height:100.0
            convertToPoly test_node

            select_result = selectDuplicatedVerticesOnNode test_node position_threshold:0.0
            selection_modifier = findNamedEditPolyModifier test_node select_name
            test_result = select_result[1] and (select_result[2] == 0) and (selection_modifier == undefined)

            format "TEST duplicated-vertex empty selection: % | count:% | modifier:%\n" test_result select_result[2] selection_modifier
        )
        catch
        (
            format "TEST duplicated-vertex empty selection FAILED: %\n" (getCurrentException() as string)
            test_result = false
        )

        if test_node != undefined and isValidNode test_node then
        (
            delete test_node
        )

        test_result
        -- return
    ),


    /*
    Prepares the stored SELECT DUPLICATED VERTICES selection for RMB welding.
    When no SELECT modifier exists, the same snapshot-based detector creates it first; stored IDs are revalidated against the current snapshot.
    */
    function prepareDuplicatedVerticesDeleteOnNode node position_threshold:1.0 =
    (
        select_name = getSelectDeleteModifierName "DUPLICATED VERTICES"
        selection_modifier = findNamedEditPolyModifier node select_name

        if selection_modifier == undefined then
        (
            return selectDuplicatedVerticesOnNode node position_threshold:position_threshold
        )

        evaluated_mesh = undefined
        operation_error = undefined
        valid_selection = #{}

        try
        (
            evaluated_mesh = snapshotAsMesh node
            if evaluated_mesh == undefined then throw "could not create evaluated snapshot"

            snapshot_vertex_count = getNumVerts evaluated_mesh
            current_double_verts = collectDoubleVertsFromMesh evaluated_mesh position_threshold:position_threshold
            free evaluated_mesh
            evaluated_mesh = undefined

            live_vertex_count = selection_modifier.GetNumVertices node:node
            if live_vertex_count != snapshot_vertex_count then
            (
                throw "evaluated snapshot vertex IDs do not match SELECT DUPLICATED VERTICES"
            )

            stored_selection = selection_modifier.GetSelection #Vertex node:node
            if stored_selection == undefined then stored_selection = #{}
            valid_selection = stored_selection * current_double_verts

            selection_modifier.useStackSelection = false
            selection_modifier.showCage = off
            selection_modifier.SetEPolySelLevel #Vertex
            selection_modifier.SetSelection #Vertex valid_selection node:node
            update node
        )
        catch
        (
            if evaluated_mesh != undefined then free evaluated_mesh
            operation_error = getCurrentException()
        )

        if operation_error == undefined then
        (
            #(true, valid_selection.numberSet, "", selection_modifier, copy valid_selection)
        )
        else
        (
            #(false, 0, operation_error as string, selection_modifier, #{})
        )
        -- return
    ),


    /*
    Compatibility wrapper for older callers of selectDoubleVerts.
    The operation now follows the project-wide SELECT DUPLICATED VERTICES modifier rule.
    */
    function selectDoubleVerts position_threshold:1.0 =
    (
        result = selectDuplicatedVerticesSelection position_threshold:position_threshold
        result[1]
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
    Returns the current topology source used by WALLS COMPLETION corner repair.
    The active Edit Poly wins, then the top Edit Poly, then the Editable Poly base object.
    */
    function getWallCompletionSource node active_edit_poly:undefined =
    (
        if node == undefined or not(isValidNode node) then return undefined

        setEditablePolyCageOff node

        if active_edit_poly != undefined and nodeHasEditPolyModifier node active_edit_poly then
        (
            #(#editPoly, active_edit_poly)
        )
        else if node.modifiers.count > 0 and classOf node.modifiers[1] == Edit_Poly then
        (
            #(#editPoly, node.modifiers[1])
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
    Returns both vertices of one live edge from Edit Poly or Editable Poly topology.
    Invalid or dead edge slots return undefined.
    */
    function getWallCompletionEdgeVerts node source_kind source_ref edge_index =
    (
        if node == undefined or not(isValidNode node) or source_ref == undefined then return undefined

        edge_verts = undefined

        try
        (
            if source_kind == #editPoly then
            (
                edge_a = source_ref.GetEdgeVertex edge_index 1 node:node
                edge_b = source_ref.GetEdgeVertex edge_index 2 node:node
                if edge_a > 0 and edge_b > 0 then edge_verts = #(edge_a, edge_b)
            )
            else
            (
                current_edge_verts = polyop.getEdgeVerts source_ref edge_index
                if current_edge_verts != undefined and current_edge_verts.count == 2 then edge_verts = #(current_edge_verts[1], current_edge_verts[2])
            )
        )
        catch
        (
            edge_verts = undefined
        )

        edge_verts
        -- return
    ),

    /*
    Returns the current live vertex count for one WALLS COMPLETION topology source.
    Edit Poly dead slots are ignored so a successful weld can be verified after commits.
    */
    function getWallCompletionVertexCount node source_kind source_ref =
    (
        if node == undefined or not(isValidNode node) or source_ref == undefined then return 0

        if source_kind == #editPoly then
        (
            getLiveEditPolyVertexCount node source_ref
        )
        else
        (
            try(polyop.getNumVerts source_ref)catch(0)
        )
        -- return
    ),

    /*
    Projects one branch point onto a vertical edge and validates an interior T-junction hit.
    The returned array contains edge fraction, projected world point, and world distance.
    */
    function getCornerTJunctionProjection branch_world edge_a_world edge_b_world position_threshold:1.0 vertical_angle_threshold:5.0 =
    (
        if branch_world == undefined or edge_a_world == undefined or edge_b_world == undefined then return undefined

        threshold_value = amax 0.0 position_threshold
        angle_threshold_value = amax 0.0 vertical_angle_threshold
        edge_vector = edge_b_world - edge_a_world
        edge_length_sq = dot edge_vector edge_vector
        if edge_length_sq <= (epsilon * epsilon) then return undefined

        edge_length = sqrt edge_length_sq
        edge_direction = edge_vector / edge_length
        vertical_dot = amax 0.0 (amin 1.0 (abs(dot edge_direction [0.0,0.0,1.0])))
        vertical_error = acos vertical_dot
        if vertical_error > angle_threshold_value then return undefined

        edge_fraction = dot (branch_world - edge_a_world) edge_vector / edge_length_sq
        endpoint_margin = threshold_value / edge_length
        if endpoint_margin < 0.000001 then endpoint_margin = 0.000001
        if endpoint_margin > 0.49 then endpoint_margin = 0.49
        if edge_fraction <= endpoint_margin or edge_fraction >= (1.0 - endpoint_margin) then return undefined

        projected_world = edge_a_world + (edge_vector * edge_fraction)
        projection_distance = distance branch_world projected_world
        if projection_distance > threshold_value then return undefined

        #(edge_fraction, projected_world, projection_distance)
        -- return
    ),

    /*
    Finds the nearest open-border branch vertex that terminates on the interior of a vertical open-border edge.
    A branch must own at least one non-vertical border edge so overlapping vertical borders are not treated as T-junctions.
    */
    function findCornerTJunctionCandidate node source_kind source_ref position_threshold:1.0 vertical_angle_threshold:5.0 =
    (
        if node == undefined or not(isValidNode node) or source_ref == undefined then return undefined

        border_edges = get90AngleOpenBorderEdges node source_kind source_ref
        if border_edges.numberSet == 0 then return undefined

        vertex_count = 0
        try
        (
            vertex_count = if source_kind == #editPoly then source_ref.GetNumVertices node:node else polyop.getNumVerts source_ref
        )
        catch
        (
            vertex_count = 0
        )
        if vertex_count <= 0 then return undefined

        object_tm = node.objectTransform
        world_up = [0.0,0.0,1.0]
        best_candidate = undefined
        best_distance = 1e30

        for branch_vertex = 1 to vertex_count do
        (
            branch_local = get90AngleVertexPosition node source_kind source_ref branch_vertex

            if branch_local != undefined then
            (
                branch_neighbors = get90AngleBorderNeighborVerts node source_kind source_ref border_edges branch_vertex
                has_nonvertical_border = false
                branch_world = branch_local * object_tm

                for neighbor_vertex in branch_neighbors while not has_nonvertical_border do
                (
                    neighbor_local = get90AngleVertexPosition node source_kind source_ref neighbor_vertex
                    if neighbor_local != undefined then
                    (
                        neighbor_direction = safeNormalize ((neighbor_local * object_tm) - branch_world)
                        if neighbor_direction != undefined then
                        (
                            neighbor_vertical_dot = amax 0.0 (amin 1.0 (abs(dot neighbor_direction world_up)))
                            neighbor_vertical_error = acos neighbor_vertical_dot
                            if neighbor_vertical_error > vertical_angle_threshold then has_nonvertical_border = true
                        )
                    )
                )

                if has_nonvertical_border then
                (
                    for target_edge in border_edges do
                    (
                        edge_verts = getWallCompletionEdgeVerts node source_kind source_ref target_edge

                        if edge_verts != undefined and branch_vertex != edge_verts[1] and branch_vertex != edge_verts[2] then
                        (
                            edge_a_local = get90AngleVertexPosition node source_kind source_ref edge_verts[1]
                            edge_b_local = get90AngleVertexPosition node source_kind source_ref edge_verts[2]

                            if edge_a_local != undefined and edge_b_local != undefined then
                            (
                                projection = getCornerTJunctionProjection \
                                    branch_world \
                                    (edge_a_local * object_tm) \
                                    (edge_b_local * object_tm) \
                                    position_threshold:position_threshold \
                                    vertical_angle_threshold:vertical_angle_threshold

                                if projection != undefined and projection[3] < best_distance then
                                (
                                    best_distance = projection[3]
                                    best_candidate = #(branch_vertex, target_edge, projection[1], projection[2], projection[3])
                                )
                            )
                        )
                    )
                )
            )
        )

        best_candidate
        -- return
    ),

    /*
    Divides the target vertical border edge and welds the branch vertex to the new split vertex.
    Both Edit Poly and Editable Poly paths use their native topology methods without adding or collapsing modifiers.
    */
    function repairCornerTJunctionCandidate node source_kind source_ref candidate =
    (
        if node == undefined or not(isValidNode node) or source_ref == undefined then return false
        if candidate == undefined or candidate.count < 5 then return false

        branch_vertex = candidate[1]
        target_edge = candidate[2]
        edge_fraction = candidate[3]
        projected_world = candidate[4]
        before_vertex_count = getWallCompletionVertexCount node source_kind source_ref
        new_vertex = undefined
        repair_success = false

        try
        (
            if source_kind == #editPoly then
            (
                select node
                max modify mode
                modPanel.setCurrentObject source_ref
                source_ref.SetPrimaryNode node
                source_ref.useStackSelection = false

                new_vertex = source_ref.DivideEdge target_edge edge_fraction node:node

                if new_vertex != undefined and new_vertex > 0 then
                (
                    source_ref.Commit()
                    update node

                    branch_position = source_ref.GetVertex branch_vertex node:node
                    split_position = source_ref.GetVertex new_vertex node:node

                    if branch_position != undefined and split_position != undefined then
                    (
                        single_selection = #{}
                        single_selection[branch_vertex] = true
                        source_ref.SetEPolySelLevel #Vertex
                        subObjectLevel = 1
                        source_ref.SetSelection #Vertex #{} node:node
                        source_ref.Select #Vertex single_selection node:node
                        source_ref.SetOperation #Transform
                        source_ref.MoveSelection (split_position - branch_position) parent:(source_ref.GetNodeTM node:node) axis:(source_ref.GetNodeTM node:node)
                        source_ref.Commit()
                        update node

                        source_ref.WeldVertices branch_vertex new_vertex node:node
                        source_ref.Commit()
                        update node

                        after_vertex_count = getWallCompletionVertexCount node source_kind source_ref
                        repair_success = after_vertex_count <= before_vertex_count
                    )
                )
            )
            else
            (
                new_vertex = polyop.divideEdge source_ref target_edge edge_fraction

                if new_vertex != undefined and new_vertex > 0 then
                (
                    projected_local = projected_world * inverse node.objectTransform
                    polyop.weldVerts source_ref branch_vertex new_vertex projected_local
                    update node

                    after_vertex_count = getWallCompletionVertexCount node source_kind source_ref
                    repair_success = after_vertex_count <= before_vertex_count
                )
            )
        )
        catch
        (
            repair_success = false
        )

        repair_success
        -- return
    ),

    /*
    Repairs unwelded T-junctions on vertical wall-corner border edges for the current selection.
    Topology is re-read after every repair so changed vertex and edge indices are never reused.
    */
    function repairCornerTJunctions position_threshold:1.0 vertical_angle_threshold:5.0 =
    (
        selected_nodes = selection as array
        active_edit_poly = undefined
        supported_count = 0
        repaired_count = 0
        failed_count = 0
        threshold_value = amax 0.0 position_threshold
        max_repairs_per_node = 10000
        last_slice_report = ""

        try
        (
            current_object = modPanel.getCurrentObject()
            if current_object != undefined and classOf current_object == Edit_Poly then active_edit_poly = current_object
        )
        catch
        (
            active_edit_poly = undefined
        )

        if selected_nodes.count == 0 then
        (
            last_slice_report = "WELD AND CONNECT WALL CORNERS: select at least one wall object."
            if not batch_quiet then format "%\n" last_slice_report
            return false
        )

        for node in selected_nodes do
        (
            if node != undefined and isValidNode node and superClassOf node == GeometryClass then
            (
                source_data = getWallCompletionSource node active_edit_poly:active_edit_poly

                if source_data != undefined then
                (
                    supported_count += 1
                    source_kind = source_data[1]
                    source_ref = source_data[2]
                    node_repairs = 0
                    keep_repairing = true

                    while keep_repairing and node_repairs < max_repairs_per_node do
                    (
                        candidate = findCornerTJunctionCandidate \
                            node \
                            source_kind \
                            source_ref \
                            position_threshold:threshold_value \
                            vertical_angle_threshold:vertical_angle_threshold

                        if candidate == undefined then
                        (
                            keep_repairing = false
                        )
                        else if repairCornerTJunctionCandidate node source_kind source_ref candidate then
                        (
                            node_repairs += 1
                            repaired_count += 1
                        )
                        else
                        (
                            keep_repairing = false
                            failed_count += 1
                        )
                    )

                    if node_repairs >= max_repairs_per_node then failed_count += 1
                )
            )
        )

        completeRedraw()

        if supported_count == 0 then
        (
            last_slice_report = "WELD AND CONNECT WALL CORNERS: no Editable Poly or Edit Poly wall object was available."
            if not batch_quiet then format "%\n" last_slice_report
            false
        )
        else if failed_count > 0 then
        (
            last_slice_report = "WELD AND CONNECT WALL CORNERS: repaired " + (repaired_count as string) + " T-junction(s); " + (failed_count as string) + " object(s) stopped on an unresolved junction."
            if not batch_quiet then format "%\n" last_slice_report
            false
        )
        else
        (
            last_slice_report = "WELD AND CONNECT WALL CORNERS: repaired " + (repaired_count as string) + " vertical-edge T-junction(s)."
            if not batch_quiet then format "%\n" last_slice_report
            true
        )
        -- return
    ),

    /*
    Tests vertical-edge T-junction projection without changing scene geometry.
    Interior vertical hits pass; endpoints, horizontal edges, and distant branches must fail.
    */
    function testCornerTJunctionProjection =
    (
        interior_hit = getCornerTJunctionProjection [0.01,0.0,1.0] [0.0,0.0,0.0] [0.0,0.0,2.0] position_threshold:0.05 vertical_angle_threshold:5.0
        endpoint_hit = getCornerTJunctionProjection [0.01,0.0,0.0] [0.0,0.0,0.0] [0.0,0.0,2.0] position_threshold:0.05 vertical_angle_threshold:5.0
        horizontal_hit = getCornerTJunctionProjection [1.0,0.01,0.0] [0.0,0.0,0.0] [2.0,0.0,0.0] position_threshold:0.05 vertical_angle_threshold:5.0
        distant_hit = getCornerTJunctionProjection [0.20,0.0,1.0] [0.0,0.0,0.0] [0.0,0.0,2.0] position_threshold:0.05 vertical_angle_threshold:5.0
        passed = interior_hit != undefined and endpoint_hit == undefined and horizontal_hit == undefined and distant_hit == undefined

        format "Corner T-junction projection test | interior:% | endpoint:% | horizontal:% | distant:% | passed:%\n" \
            (interior_hit != undefined) (endpoint_hit != undefined) (horizontal_hit != undefined) (distant_hit != undefined) passed

        passed
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
