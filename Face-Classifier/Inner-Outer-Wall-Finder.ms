/*
Inner-Outer Wall Finder 0.22
Classifies selected wall faces and marks horizontal faces by normal direction.
Material ID 1 = OUTER, ID 2 = INNER, ID 3 = UP, ID 4 = DOWN.
*/

global WallFixerVersion
global WallFixerRollout
global wall_fixer_version_system
global wall_fixer_version_epoch
global wall_fixer_inner_outer_file_version = "0.22"
global wall_fixer_inner_outer_tool_version = 0.23
global wallFaceClassifierRollout
global wall_face_classifier_cache = #()
global wall_face_classifier_last_nodes = #()

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

wall_fixer_inner_outer_current_tool_version_number = undefined

if WallFixerVersion != undefined then
(
    try
    (
        wall_fixer_inner_outer_current_tool_version_number = WallFixerVersion as float
    )
    catch
    (
        wall_fixer_inner_outer_current_tool_version_number = undefined
    )
)

if wall_fixer_inner_outer_current_tool_version_number == undefined then
(
    WallFixerVersion = wall_fixer_inner_outer_tool_version
)
else if wall_fixer_inner_outer_tool_version > wall_fixer_inner_outer_current_tool_version_number then
(
    WallFixerVersion = wall_fixer_inner_outer_tool_version
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

/* Returns the top Edit Poly modifier when it is the evaluated top modifier.
*/
function getTopEditPoly object_node =
(
    local edit_poly_mod = undefined

    if object_node.modifiers.count > 0 then
    (
        if classof object_node.modifiers[1] == Edit_Poly then
        (
            edit_poly_mod = object_node.modifiers[1]
        )
    )

    edit_poly_mod -- return
)

/* Returns a supported geometry source for Editable Poly or top Edit Poly.
*/
function getFaceGeometrySource object_node =
(
    local source_data = undefined
    local edit_poly_mod = getTopEditPoly object_node

    if edit_poly_mod != undefined then
    (
        source_data = #(#editPoly, edit_poly_mod)
    )
    else if object_node.modifiers.count == 0 and classof object_node.baseObject == Editable_Poly then
    (
        source_data = #(#editablePoly, object_node.baseObject)
    )

    source_data -- return
)

/* Returns the vertex count from the current supported polygon source.
*/
function getSourceNumVertices object_node source_data =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local vertex_count = 0

    if source_type == #editPoly then
    (
        vertex_count = source_value.GetNumVertices node:object_node
    )
    else if source_type == #editablePoly then
    (
        vertex_count = source_value.GetNumVertices()
    )

    vertex_count -- return
)

/* Returns the face count from the current supported polygon source.
*/
function getSourceNumFaces object_node source_data =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local face_count = 0

    if source_type == #editPoly then
    (
        face_count = source_value.GetNumFaces node:object_node
    )
    else if source_type == #editablePoly then
    (
        face_count = source_value.GetNumFaces()
    )

    face_count -- return
)

/* Returns one evaluated vertex position in world space.
*/
function getSourceVertexWorld object_node source_data vertex_index =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local vertex_local = [0.0, 0.0, 0.0]

    if source_type == #editPoly then
    (
        vertex_local = source_value.GetVertex vertex_index node:object_node
    )
    else if source_type == #editablePoly then
    (
        vertex_local = source_value.GetVertex vertex_index
    )

    (vertex_local * object_node.objectTransform) -- return
)

/* Returns the number of polygon corners for one evaluated face.
*/
function getSourceFaceDegree object_node source_data face_index =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local face_degree = 0

    if source_type == #editPoly then
    (
        face_degree = source_value.GetFaceDegree face_index node:object_node
    )
    else if source_type == #editablePoly then
    (
        face_degree = source_value.GetFaceDegree face_index
    )

    face_degree -- return
)

/* Returns the vertex index at one polygon corner.
*/
function getSourceFaceVertex object_node source_data face_index corner_index =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local vertex_index = 0

    if source_type == #editPoly then
    (
        vertex_index = source_value.GetFaceVertex face_index corner_index node:object_node
    )
    else if source_type == #editablePoly then
    (
        vertex_index = source_value.GetFaceVertex face_index corner_index
    )

    vertex_index -- return
)

/* Returns the edge index at one polygon side.
*/
function getSourceFaceEdge object_node source_data face_index side_index =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local edge_index = 0

    if source_type == #editPoly then
    (
        edge_index = source_value.GetFaceEdge face_index side_index node:object_node
    )
    else if source_type == #editablePoly then
    (
        edge_index = source_value.GetFaceEdge face_index side_index
    )

    edge_index -- return
)

/* Returns the face index attached to one side of an edge.
*/
function getSourceEdgeFace object_node source_data edge_index side_index =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local face_index = 0

    if source_type == #editPoly then
    (
        face_index = source_value.GetEdgeFace edge_index side_index node:object_node
    )
    else if source_type == #editablePoly then
    (
        face_index = source_value.GetEdgeFace edge_index side_index
    )

    face_index -- return
)

/* Calculates the center of an arbitrary polygon from cached world-space vertices.
*/
function calculatePolygonCenter face_vertices =
(
    local center_value = [0.0, 0.0, 0.0]

    if face_vertices.count > 0 then
    (
        for vertex_value in face_vertices do
        (
            center_value += vertex_value
        )

        center_value /= face_vertices.count
    )

    center_value -- return
)

/* Calculates a stable polygon normal with Newell's method in world space.
*/
function calculatePolygonNormal face_vertices epsilon:0.0000001 =
(
    local normal_value = [0.0, 0.0, 0.0]
    local current_vertex = [0.0, 0.0, 0.0]
    local next_vertex = [0.0, 0.0, 0.0]
    local next_index = 1

    if face_vertices.count >= 3 then
    (
        for vertex_index = 1 to face_vertices.count do
        (
            next_index = vertex_index + 1
            if next_index > face_vertices.count then
            (
                next_index = 1
            )

            current_vertex = face_vertices[vertex_index]
            next_vertex = face_vertices[next_index]

            normal_value.x += (current_vertex.y - next_vertex.y) * (current_vertex.z + next_vertex.z)
            normal_value.y += (current_vertex.z - next_vertex.z) * (current_vertex.x + next_vertex.x)
            normal_value.z += (current_vertex.x - next_vertex.x) * (current_vertex.y + next_vertex.y)
        )
    )

    if (length normal_value) > epsilon then
    (
        normal_value = normalize normal_value
    )
    else
    (
        normal_value = [0.0, 0.0, 0.0]
    )

    normal_value -- return
)

/* Returns the positive ray distance to an axis-aligned bounding-box exit.
*/
function getBBoxExitDistance point_value direction_value bbox_min bbox_max epsilon:0.0000001 =
(
    local distance_value = 1.0e30
    local candidate_distance = 0.0

    if direction_value.x > epsilon then
    (
        candidate_distance = (bbox_max.x - point_value.x) / direction_value.x
        if candidate_distance >= 0.0 and candidate_distance < distance_value then
        (
            distance_value = candidate_distance
        )
    )
    else if direction_value.x < -epsilon then
    (
        candidate_distance = (bbox_min.x - point_value.x) / direction_value.x
        if candidate_distance >= 0.0 and candidate_distance < distance_value then
        (
            distance_value = candidate_distance
        )
    )

    if direction_value.y > epsilon then
    (
        candidate_distance = (bbox_max.y - point_value.y) / direction_value.y
        if candidate_distance >= 0.0 and candidate_distance < distance_value then
        (
            distance_value = candidate_distance
        )
    )
    else if direction_value.y < -epsilon then
    (
        candidate_distance = (bbox_min.y - point_value.y) / direction_value.y
        if candidate_distance >= 0.0 and candidate_distance < distance_value then
        (
            distance_value = candidate_distance
        )
    )

    if direction_value.z > epsilon then
    (
        candidate_distance = (bbox_max.z - point_value.z) / direction_value.z
        if candidate_distance >= 0.0 and candidate_distance < distance_value then
        (
            distance_value = candidate_distance
        )
    )
    else if direction_value.z < -epsilon then
    (
        candidate_distance = (bbox_min.z - point_value.z) / direction_value.z
        if candidate_distance >= 0.0 and candidate_distance < distance_value then
        (
            distance_value = candidate_distance
        )
    )

    if distance_value == 1.0e30 then
    (
        distance_value = 0.0
    )

    distance_value -- return
)

/* Calculates a double-sided ray/triangle hit distance with Moller-Trumbore intersection.
*/
function getRayTriangleDistance ray_origin ray_direction point_a point_b point_c epsilon:0.0000001 =
(
    local edge_a = point_b - point_a
    local edge_b = point_c - point_a
    local p_vector = cross ray_direction edge_b
    local determinant = dot edge_a p_vector
    local hit_distance = undefined
    local inverse_determinant = 0.0
    local t_vector = [0.0, 0.0, 0.0]
    local u_value = 0.0
    local q_vector = [0.0, 0.0, 0.0]
    local v_value = 0.0
    local t_value = 0.0

    if (abs determinant) > epsilon then
    (
        inverse_determinant = 1.0 / determinant
        t_vector = ray_origin - point_a
        u_value = (dot t_vector p_vector) * inverse_determinant

        if u_value >= -epsilon and u_value <= (1.0 + epsilon) then
        (
            q_vector = cross t_vector edge_a
            v_value = (dot ray_direction q_vector) * inverse_determinant

            if v_value >= -epsilon and (u_value + v_value) <= (1.0 + epsilon) then
            (
                t_value = (dot edge_b q_vector) * inverse_determinant
                if t_value > epsilon then
                (
                    hit_distance = t_value
                )
            )
        )
    )

    hit_distance -- return
)

/* Finds the nearest selected-face hit for a double-sided ray, excluding its source face.
*/
function getNearestRayHitDistance ray_origin ray_direction object_data_array ignore_node ignore_face epsilon:0.0000001 =
(
    local nearest_distance = undefined
    local face_vertices = undefined
    local hit_distance = undefined

    for object_data in object_data_array do
    (
        local object_node = object_data[1]
        local cached_faces = object_data[3]

        for face_index = 1 to cached_faces.count do
        (
            if not (object_node == ignore_node and face_index == ignore_face) then
            (
                face_vertices = cached_faces[face_index]

                if face_vertices.count >= 3 then
                (
                    for triangle_index = 2 to (face_vertices.count - 1) do
                    (
                        hit_distance = getRayTriangleDistance ray_origin ray_direction face_vertices[1] face_vertices[triangle_index] face_vertices[triangle_index + 1] epsilon:epsilon

                        if hit_distance != undefined then
                        (
                            if nearest_distance == undefined or hit_distance < nearest_distance then
                            (
                                nearest_distance = hit_distance
                            )
                        )
                    )
                )
            )
        )
    )

    nearest_distance -- return
)

/* Finds the nearest nearly-parallel face hit within the wall-thickness search distance.
   Only faces on the currently selected objects are searched.
*/
function getNearestOppositeWallHit ray_origin ray_direction source_normal object_data_array ignore_node ignore_face max_distance parallel_threshold:0.90 epsilon:0.0000001 =
(
    local nearest_data = undefined
    local candidate_normal = [0.0, 0.0, 0.0]
    local face_vertices = undefined
    local hit_distance = undefined
    local parallel_value = 0.0

    for object_data in object_data_array do
    (
        local object_node = object_data[1]
        local cached_faces = object_data[3]
        local face_normals = object_data[5]

        for face_index = 1 to cached_faces.count do
        (
            if not (object_node == ignore_node and face_index == ignore_face) then
            (
                candidate_normal = face_normals[face_index]

                if (length candidate_normal) > epsilon then
                (
                    parallel_value = abs (dot source_normal candidate_normal)

                    if parallel_value >= parallel_threshold then
                    (
                        face_vertices = cached_faces[face_index]

                        if face_vertices.count >= 3 then
                        (
                            for triangle_index = 2 to (face_vertices.count - 1) do
                            (
                                hit_distance = getRayTriangleDistance ray_origin ray_direction face_vertices[1] face_vertices[triangle_index] face_vertices[triangle_index + 1] epsilon:epsilon

                                if hit_distance != undefined then
                                (
                                    if hit_distance <= max_distance then
                                    (
                                        if nearest_data == undefined or hit_distance < nearest_data[1] then
                                        (
                                            nearest_data = #(hit_distance, object_node, face_index, parallel_value)
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )

    nearest_data -- return
)

/* Returns the current classification of one cached face.
   ID 1 = OUTER, ID 2 = INNER, ID 3 = UP, ID 4 = DOWN, 0 = unresolved wall.
*/
function getCachedFaceClass object_data_array object_node face_index =
(
    local class_id = 0

    for object_data in object_data_array do
    (
        if object_data[1] == object_node then
        (
            if face_index >= 1 and face_index <= object_data[6].count then
            (
                class_id = object_data[6][face_index]
            )
        )
    )

    class_id -- return
)

/* Returns the cached first-pass spatial score for one face.
   Positive scores lean OUTER, negative scores lean INNER.
*/
function getCachedFaceScore object_data_array object_node face_index =
(
    local score_value = 0.0

    for object_data in object_data_array do
    (
        if object_data[1] == object_node then
        (
            if object_data.count >= 7 and face_index >= 1 and face_index <= object_data[7].count then
            (
                score_value = object_data[7][face_index]
            )
        )
    )

    score_value -- return
)

/* Returns the cached center and normal for one face.
   Result is #(center, normal), or undefined when the face cannot be found.
*/
function getCachedFaceCenterNormal object_data_array object_node face_index =
(
    local result_data = undefined

    for object_data in object_data_array do
    (
        if object_data[1] == object_node then
        (
            if face_index >= 1 and face_index <= object_data[4].count then
            (
                result_data = #(object_data[4][face_index], object_data[5][face_index])
            )
        )
    )

    result_data -- return
)

/* Resolves unresolved or weak wall faces by finding the opposite wall behind the face.
   Horizontal UP/DOWN faces are ignored; only wall classes 0, 1, and 2 are considered.
*/
function resolveUnresolvedWallsByThickness object_data_array wall_thickness confidence_threshold:0.12 parallel_threshold:0.90 ray_offset:0.001 epsilon:0.0000001 =
(
    local resolved_count = 0
    local weak_limit = confidence_threshold * 2.0

    if weak_limit < confidence_threshold then
    (
        weak_limit = confidence_threshold
    )

    if wall_thickness > epsilon then
    (
        for object_data in object_data_array do
        (
            local object_node = object_data[1]
            local face_centers = object_data[4]
            local face_normals = object_data[5]
            local face_classes = object_data[6]
            local face_scores = object_data[7]

            for face_index = 1 to face_classes.count do
            (
                local current_class = face_classes[face_index]
                local face_score = face_scores[face_index]

                if current_class == 0 or ((current_class == 1 or current_class == 2) and (abs face_score) < weak_limit) then
                (
                    local face_center = face_centers[face_index]
                    local face_normal = face_normals[face_index]

                    if (length face_normal) > epsilon then
                    (
                        local opposite_origin = face_center - (face_normal * ray_offset)
                        local opposite_hit = getNearestOppositeWallHit opposite_origin (-face_normal) face_normal object_data_array object_node face_index wall_thickness parallel_threshold:parallel_threshold epsilon:epsilon

                        if opposite_hit != undefined then
                        (
                            local opposite_data = getCachedFaceCenterNormal object_data_array opposite_hit[2] opposite_hit[3]

                            if opposite_data != undefined then
                            (
                                local opposite_center = opposite_data[1]
                                local opposite_normal = opposite_data[2]

                                if (length opposite_normal) > epsilon and (abs opposite_normal.z) < 0.85 then
                                (
                                    local source_outward_origin = face_center + (face_normal * ray_offset)
                                    local opposite_outward_origin = opposite_center + (opposite_normal * ray_offset)
                                    local source_outward_hit = getNearestRayHitDistance source_outward_origin face_normal object_data_array object_node face_index epsilon:epsilon
                                    local opposite_outward_hit = getNearestRayHitDistance opposite_outward_origin opposite_normal object_data_array opposite_hit[2] opposite_hit[3] epsilon:epsilon
                                    local new_class = 0

                                    if source_outward_hit == undefined and opposite_outward_hit != undefined then
                                    (
                                        new_class = 1
                                    )
                                    else if source_outward_hit != undefined and opposite_outward_hit == undefined then
                                    (
                                        new_class = 2
                                    )
                                    else
                                    (
                                        local opposite_class = getCachedFaceClass object_data_array opposite_hit[2] opposite_hit[3]
                                        local opposite_score = getCachedFaceScore object_data_array opposite_hit[2] opposite_hit[3]

                                        if (abs opposite_score) >= weak_limit then
                                        (
                                            if opposite_class == 1 then
                                            (
                                                new_class = 2
                                            )
                                            else if opposite_class == 2 then
                                            (
                                                new_class = 1
                                            )
                                        )
                                    )

                                    if (new_class == 1 or new_class == 2) and new_class != current_class then
                                    (
                                        face_classes[face_index] = new_class
                                        resolved_count += 1
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )

    resolved_count -- return
)

/* Builds a bitarray containing every face assigned to one classification ID.
*/
function buildFaceClassBits face_classes class_id =
(
    local face_bits = #{}

    for face_index = 1 to face_classes.count do
    (
        if face_classes[face_index] == class_id then
        (
            face_bits[face_index] = true
        )
    )

    face_bits -- return
)

/* Resolves remaining unresolved wall faces from already classified edge neighbors.
   UP and DOWN faces do not vote in wall classification.
*/
function resolveUnresolvedWallFaces object_data_array neighbor_passes:3 =
(
    local total_change_count = 0

    for pass_index = 1 to neighbor_passes do
    (
        local change_count = 0

        for object_data in object_data_array do
        (
            local object_node = object_data[1]
            local source_data = object_data[2]
            local face_normals = object_data[5]
            local face_classes = object_data[6]

            for face_index = 1 to face_classes.count do
            (
                if face_classes[face_index] == 0 then
                (
                    local face_degree = getSourceFaceDegree object_node source_data face_index
                    local vote_value = 0.0
                    local evidence_value = 0.0
                    local edge_index = 0
                    local edge_face_a = 0
                    local edge_face_b = 0
                    local neighbor_face = 0
                    local neighbor_class = 0
                    local similarity = 0.0
                    local vote_weight = 0.0

                    for side_index = 1 to face_degree do
                    (
                        edge_index = getSourceFaceEdge object_node source_data face_index side_index

                        if edge_index > 0 then
                        (
                            edge_face_a = getSourceEdgeFace object_node source_data edge_index 1
                            edge_face_b = getSourceEdgeFace object_node source_data edge_index 2
                            neighbor_face = 0

                            if edge_face_a > 0 and edge_face_a != face_index then
                            (
                                neighbor_face = edge_face_a
                            )
                            else if edge_face_b > 0 and edge_face_b != face_index then
                            (
                                neighbor_face = edge_face_b
                            )

                            if neighbor_face > 0 and neighbor_face <= face_classes.count then
                            (
                                neighbor_class = face_classes[neighbor_face]

                                if neighbor_class == 1 or neighbor_class == 2 then
                                (
                                    similarity = abs (dot face_normals[face_index] face_normals[neighbor_face])
                                    vote_weight = 0.25 + (0.75 * similarity)
                                    evidence_value += vote_weight

                                    if neighbor_class == 1 then
                                    (
                                        vote_value += vote_weight
                                    )
                                    else
                                    (
                                        vote_value -= vote_weight
                                    )
                                )
                            )
                        )
                    )

                    if evidence_value >= 0.5 then
                    (
                        local normalized_vote = vote_value / evidence_value

                        if normalized_vote >= 0.34 then
                        (
                            face_classes[face_index] = 1
                            change_count += 1
                        )
                        else if normalized_vote <= -0.34 then
                        (
                            face_classes[face_index] = 2
                            change_count += 1
                        )
                    )
                )
            )
        )

        total_change_count += change_count
    )

    total_change_count -- return
)

/* Forces every remaining unresolved wall face to OUTER or INNER from its spatial score.
   This is the final fallback so every non-horizontal face receives a wall class.
*/
function finalizeUnresolvedWallFaces object_data_array =
(
    local finalized_count = 0

    for object_data in object_data_array do
    (
        local face_classes = object_data[6]
        local face_scores = object_data[7]

        for face_index = 1 to face_classes.count do
        (
            if face_classes[face_index] == 0 then
            (
                if face_scores[face_index] >= 0.0 then
                (
                    face_classes[face_index] = 1
                )
                else
                (
                    face_classes[face_index] = 2
                )

                finalized_count += 1
            )
        )
    )

    finalized_count -- return
)

/* Creates the classifier Multi/Sub-Object material with legacy Standard sub-materials.
   ID 1 = OUTER green, ID 2 = INNER orange, ID 3 = UP pastel blue, ID 4 = DOWN pastel brown.
*/
function createWallClassifierMaterial =
(
    local classifier_material = multimaterial numsubs:4 name:"WALL FACE CLASSIFIER"
    local outer_material = standardMaterial name:"OUTER" diffuse:(color 60 200 80)
    local inner_material = standardMaterial name:"INNER" diffuse:(color 255 140 0)
    local up_material = standardMaterial name:"UP" diffuse:(color 155 205 235)
    local down_material = standardMaterial name:"DOWN" diffuse:(color 190 155 120)

    classifier_material.materialList[1] = outer_material
    classifier_material.materialList[2] = inner_material
    classifier_material.materialList[3] = up_material
    classifier_material.materialList[4] = down_material
    classifier_material.materialIDList = #(1, 2, 3, 4)
    classifier_material.names = #("OUTER", "INNER", "UP", "DOWN")

    classifier_material -- return
)

/* Assigns one shared classifier Multi/Sub-Object material to supported nodes.
   Existing node materials are replaced only on the objects being classified.
*/
function assignWallClassifierMaterial object_nodes =
(
    local classifier_material = createWallClassifierMaterial()

    for object_node in object_nodes do
    (
        object_node.material = classifier_material
    )

    classifier_material -- return
)

/* Assigns one Material ID to a face set on Editable Poly or top Edit Poly.
*/
function setSourceFaceMaterialId object_node source_data face_bits material_id =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local working_bits = copy face_bits

    if working_bits.numberSet > 0 then
    (
        if source_type == #editPoly then
        (
            select object_node
            max modify mode
            modPanel.setCurrentObject source_value
            source_value.SetEPolySelLevel #Face
            source_value.SetSelection #Face working_bits node:object_node
            source_value.materialIDToSet = material_id
            source_value.ButtonOp #SetMaterial
        )
        else if source_type == #editablePoly then
        (
            polyOp.setFaceMatID source_value working_bits material_id
        )
    )

    true -- return
)

/* Sets the face selection without changing the current object selection.
   This lets one LMB action update face selections across multiple supported objects.
*/
function setSourceFaceSelection object_node source_data face_bits =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local working_bits = copy face_bits

    if source_type == #editPoly then
    (
        source_value.SetEPolySelLevel #Face
        source_value.SetSelection #Face working_bits node:object_node
    )
    else if source_type == #editablePoly then
    (
        source_value.SetSelection #Face working_bits
    )

    true -- return
)

/* Returns the Material ID assigned to one face on Editable Poly or top Edit Poly.
*/
function getSourceFaceMaterialId object_node source_data face_index =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local material_id = 0

    if source_type == #editPoly then
    (
        material_id = source_value.GetFaceMaterial face_index node:object_node
    )
    else if source_type == #editablePoly then
    (
        material_id = polyOp.getFaceMatID source_value face_index
    )

    material_id -- return
)

/* Finds cached classifier data for one node and removes invalid cache entries.
   Returns zero when the node does not currently have cached class bitarrays.
*/
function findWallFaceCacheIndex object_node =
(
    local found_index = 0

    if wall_face_classifier_cache.count > 0 then
    (
        for cache_index = wall_face_classifier_cache.count to 1 by -1 do
        (
            local cache_entry = wall_face_classifier_cache[cache_index]

            if cache_entry.count < 6 then
            (
                deleteItem wall_face_classifier_cache cache_index
            )
            else if not isValidNode cache_entry[1] then
            (
                deleteItem wall_face_classifier_cache cache_index
            )
            else if found_index == 0 and cache_entry[1] == object_node then
            (
                found_index = cache_index
            )
        )
    )

    found_index -- return
)

/* Stores OUTER, INNER, UP, and DOWN face bitarrays for fast button selection.
   Cache entries are rebuilt after classification or manual RMB marking.
*/
function cacheWallFaceClasses object_node face_count outer_bits inner_bits up_bits down_bits =
(
    local cache_entry = #(object_node, face_count, copy outer_bits, copy inner_bits, copy up_bits, copy down_bits)
    local cache_index = findWallFaceCacheIndex object_node

    if cache_index > 0 then
    (
        wall_face_classifier_cache[cache_index] = cache_entry
    )
    else
    (
        append wall_face_classifier_cache cache_entry
    )

    cache_entry -- return
)

/* Reads classifier Material IDs once and stores all four face classes in cache.
   Faces using other Material IDs are intentionally not included in the classifier cache.
*/
function cacheWallFaceClassesFromMaterialIds object_node source_data =
(
    local face_count = getSourceNumFaces object_node source_data
    local outer_bits = #{}
    local inner_bits = #{}
    local up_bits = #{}
    local down_bits = #{}

    for face_index = 1 to face_count do
    (
        local material_id = getSourceFaceMaterialId object_node source_data face_index

        if material_id == 1 then
        (
            outer_bits[face_index] = true
        )
        else if material_id == 2 then
        (
            inner_bits[face_index] = true
        )
        else if material_id == 3 then
        (
            up_bits[face_index] = true
        )
        else if material_id == 4 then
        (
            down_bits[face_index] = true
        )
    )

    cacheWallFaceClasses object_node face_count outer_bits inner_bits up_bits down_bits -- return
)

/* Returns cached face bits when they still match the current object topology.
   Undefined means the cache should be rebuilt from Material IDs.
*/
function getCachedWallFaceBits object_node source_data material_id =
(
    local result_bits = undefined
    local cache_index = findWallFaceCacheIndex object_node

    if cache_index > 0 then
    (
        local cache_entry = wall_face_classifier_cache[cache_index]
        local face_count = getSourceNumFaces object_node source_data
        local material_valid = false

        if object_node.material != undefined then
        (
            if object_node.material.name == "WALL FACE CLASSIFIER" then
            (
                material_valid = true
            )
        )

        if cache_entry[2] == face_count and material_valid then
        (
            if material_id == 1 then
            (
                result_bits = copy cache_entry[3]
            )
            else if material_id == 2 then
            (
                result_bits = copy cache_entry[4]
            )
            else if material_id == 3 then
            (
                result_bits = copy cache_entry[5]
            )
            else if material_id == 4 then
            (
                result_bits = copy cache_entry[6]
            )
        )
        else
        (
            deleteItem wall_face_classifier_cache cache_index
        )
    )

    result_bits -- return
)

/* Returns the current face selection for Editable Poly or top Edit Poly.
   The returned bitarray is copied so callers can safely modify it.
*/
function getSourceFaceSelection object_node source_data =
(
    local source_type = source_data[1]
    local source_value = source_data[2]
    local face_bits = #{}

    if source_type == #editPoly then
    (
        face_bits = source_value.GetSelection #Face node:object_node
    )
    else if source_type == #editablePoly then
    (
        face_bits = source_value.GetSelection #Face
    )

    copy face_bits -- return
)

/* Builds a bitarray containing every face of one supported polygon source.
   Used when RMB marking is performed at object level.
*/
function getAllSourceFaceBits object_node source_data =
(
    local face_count = getSourceNumFaces object_node source_data
    local face_bits = #{}

    for face_index = 1 to face_count do
    (
        face_bits[face_index] = true
    )

    face_bits -- return
)


/* Converts a face bitarray to a compact persistent user-property string.
   The stored indices are used only as manual FORCED OUTER/INNER classification hints.
*/
function wallFaceBitsToUserPropString face_bits =
(
    local value_string = ""
    local first_value = true

    for face_index in face_bits do
    (
        if not first_value then
        (
            value_string += ","
        )

        value_string += face_index as string
        first_value = false
    )

    value_string -- return
)

/* Restores a persistent FORCED face list and clamps it to the current face count.
   Empty or missing user properties produce an empty bitarray.
*/
function wallFaceBitsFromUserPropString value_string face_count =
(
    local face_bits = #{}

    if value_string != undefined and value_string != "" then
    (
        local safe_value_string = value_string as string
        local token_array = filterString safe_value_string ","

        for token_value in token_array do
        (
            local face_index = token_value as integer

            if face_index >= 1 and face_index <= face_count then
            (
                face_bits[face_index] = true
            )
        )
    )

    face_bits -- return
)

/* Returns the user-property name for one manual FORCED wall class.
   Only OUTER and INNER can be forced by RMB.
*/
function getForcedWallFacePropertyName material_id =
(
    local property_name = ""

    if material_id == 1 then
    (
        property_name = "WallFaceClassifierForcedOuter"
    )
    else if material_id == 2 then
    (
        property_name = "WallFaceClassifierForcedInner"
    )

    property_name -- return
)

/* Reads persistent FORCED OUTER or INNER face indices from one object.
   Face indices outside the current topology are ignored.
*/
function getForcedWallFaceBits object_node source_data material_id =
(
    local face_bits = #{}
    local property_name = getForcedWallFacePropertyName material_id

    if property_name != "" then
    (
        local face_count = getSourceNumFaces object_node source_data
        local value_string = getUserProp object_node property_name
        face_bits = wallFaceBitsFromUserPropString value_string face_count
    )

    face_bits -- return
)

/* Writes persistent FORCED OUTER or INNER face indices to one object.
   Classification reads these hints before running any automatic wall tests.
*/
function setForcedWallFaceBits object_node material_id face_bits =
(
    local property_name = getForcedWallFacePropertyName material_id

    if property_name != "" then
    (
        setUserProp object_node property_name (wallFaceBitsToUserPropString face_bits)
    )

    true -- return
)

/* Adds a manual FORCED class and removes the same faces from the opposite forced class.
   This allows RMB OUTER/INNER to replace a previous manual hint cleanly.
*/
function forceWallFaceClass object_node source_data material_id mark_bits =
(
    local forced_outer_bits = getForcedWallFaceBits object_node source_data 1
    local forced_inner_bits = getForcedWallFaceBits object_node source_data 2

    if material_id == 1 then
    (
        forced_outer_bits = forced_outer_bits + mark_bits
        forced_inner_bits = forced_inner_bits - mark_bits
    )
    else if material_id == 2 then
    (
        forced_inner_bits = forced_inner_bits + mark_bits
        forced_outer_bits = forced_outer_bits - mark_bits
    )

    setForcedWallFaceBits object_node 1 forced_outer_bits
    setForcedWallFaceBits object_node 2 forced_inner_bits

    #(forced_outer_bits, forced_inner_bits) -- return
)

/* Returns supported geometry nodes from the current selection or restores the last classification set.
   When remember_selection is true, the resolved nodes become the set restored by later empty-selection actions.
*/
function getWallFaceWorkingNodes remember_selection:false =
(
    local working_nodes = for object_node in selection where superclassof object_node == GeometryClass collect object_node
    local restored_nodes = #()

    if working_nodes.count == 0 then
    (
        for object_node in wall_face_classifier_last_nodes do
        (
            if isValidNode object_node then
            (
                if superclassof object_node == GeometryClass then
                (
                    append restored_nodes object_node
                )
            )
        )

        working_nodes = restored_nodes

        if working_nodes.count > 0 then
        (
            select working_nodes
        )
    )

    if remember_selection and working_nodes.count > 0 then
    (
        wall_face_classifier_last_nodes = for object_node in working_nodes collect object_node
    )

    working_nodes -- return
)

/* Returns the default connection distance derived from wall thickness.
   Neighbor connection starts at ten percent of the current wall-thickness value.
*/
function getDefaultWallConnectionThreshold wall_thickness =
(
    wall_thickness * 0.1 -- return
)

/* Resets classifier face Material IDs and clears all persistent FORCED hints on selected objects.
   Existing face selections are restored and cached classifier data is discarded.
*/
function resetSelectedWallFaceClassification =
(
    local selected_nodes = getWallFaceWorkingNodes()
    local reset_data_array = #()
    local valid_nodes = #()
    local reset_face_count = 0
    local selection_level_before = subObjectLevel

    for object_node in selected_nodes do
    (
        local source_data = getFaceGeometrySource object_node

        if source_data != undefined then
        (
            local all_face_bits = getAllSourceFaceBits object_node source_data
            local original_bits = getSourceFaceSelection object_node source_data

            append reset_data_array #(object_node, source_data, all_face_bits, original_bits)
            append valid_nodes object_node
            reset_face_count += all_face_bits.numberSet
        )
    )

    if valid_nodes.count > 0 then
    (
        for reset_data in reset_data_array do
        (
            local object_node = reset_data[1]
            local source_data = reset_data[2]
            local all_face_bits = reset_data[3]
            local original_bits = reset_data[4]
            local cache_index = findWallFaceCacheIndex object_node

            setSourceFaceMaterialId object_node source_data all_face_bits 1
            setForcedWallFaceBits object_node 1 #{}
            setForcedWallFaceBits object_node 2 #{}
            setSourceFaceSelection object_node source_data original_bits

            if cache_index > 0 then
            (
                deleteItem wall_face_classifier_cache cache_index
            )
        )

        select valid_nodes
        max modify mode

        if selection_level_before != undefined then
        (
            subObjectLevel = selection_level_before
        )

        redrawViews()
    )

    #(valid_nodes.count, reset_face_count) -- return
)

/* Reuses an existing classifier material when possible and assigns it to nodes.
   A new legacy Standard Multi/Sub material is created only when none is available.
*/
function ensureWallClassifierMaterial object_nodes =
(
    local classifier_material = undefined

    for object_node in object_nodes do
    (
        if classifier_material == undefined then
        (
            if object_node.material != undefined then
            (
                if object_node.material.name == "WALL FACE CLASSIFIER" then
                (
                    classifier_material = object_node.material
                )
            )
        )
    )

    if classifier_material == undefined then
    (
        classifier_material = createWallClassifierMaterial()
    )

    for object_node in object_nodes do
    (
        object_node.material = classifier_material
    )

    classifier_material -- return
)


/* Returns true when a node already uses the classifier Multi/Sub material.
   Used to preserve existing manual/classified face IDs during RMB marking.
*/
function hasWallClassifierMaterial object_node =
(
    local has_classifier_material = false

    if object_node.material != undefined then
    (
        if object_node.material.name == "WALL FACE CLASSIFIER" then
        (
            has_classifier_material = true
        )
    )

    has_classifier_material -- return
)

/* Selects one classifier class from the current or restored working set.
   Object level selects matching objects; Face level selects matching faces across matching objects.
*/
function selectWallFacesByMaterialId material_id =
(
    local had_node_selection = (selection.count > 0)
    local selection_level_before = subObjectLevel
    local selected_nodes = getWallFaceWorkingNodes()
    local use_face_selection = (had_node_selection and selection_level_before == 4)
    local selection_data_array = #()
    local matching_nodes = #()
    local selected_face_count = 0
    local selection_mode = #objects

    if use_face_selection then
    (
        selection_mode = #faces
    )

    for object_node in selected_nodes do
    (
        local source_data = getFaceGeometrySource object_node

        if source_data != undefined then
        (
            local face_bits = getCachedWallFaceBits object_node source_data material_id

            if face_bits == undefined then
            (
                local cache_entry = cacheWallFaceClassesFromMaterialIds object_node source_data

                if material_id == 1 then
                (
                    face_bits = copy cache_entry[3]
                )
                else if material_id == 2 then
                (
                    face_bits = copy cache_entry[4]
                )
                else if material_id == 3 then
                (
                    face_bits = copy cache_entry[5]
                )
                else if material_id == 4 then
                (
                    face_bits = copy cache_entry[6]
                )
                else
                (
                    face_bits = #{}
                )
            )

            if face_bits.numberSet > 0 then
            (
                append matching_nodes object_node
                append selection_data_array #(object_node, source_data, face_bits)
                selected_face_count += face_bits.numberSet
            )
        )
    )

    if matching_nodes.count > 0 then
    (
        select matching_nodes
        max modify mode

        if use_face_selection then
        (
            subObjectLevel = 4

            for selection_data in selection_data_array do
            (
                setSourceFaceSelection selection_data[1] selection_data[2] selection_data[3]
            )
        )

        redrawViews()
    )
    else
    (
        clearSelection()
        redrawViews()
    )

    #(matching_nodes.count, selected_face_count, selection_mode) -- return
)

/* FORCES selected faces or whole selected objects as OUTER or INNER.
   Forced classes persist as classification hints and are processed before automatic tests.
*/
function markSelectedWallFaces material_id =
(
    local had_node_selection = (selection.count > 0)
    local selection_level_before = subObjectLevel
    local selected_nodes = getWallFaceWorkingNodes()
    local mark_data_array = #()
    local valid_nodes = #()
    local marked_face_count = 0
    local use_face_selection = (had_node_selection and selection_level_before == 4)
    local source_label = "selected objects"

    if use_face_selection then
    (
        source_label = "face selection"
    )

    for object_node in selected_nodes do
    (
        local source_data = getFaceGeometrySource object_node

        if source_data != undefined then
        (
            local original_bits = getSourceFaceSelection object_node source_data
            local mark_bits = #{}
            local had_classifier_material = hasWallClassifierMaterial object_node

            if use_face_selection then
            (
                mark_bits = copy original_bits
            )
            else
            (
                mark_bits = getAllSourceFaceBits object_node source_data
            )

            if mark_bits.numberSet > 0 then
            (
                append mark_data_array #(object_node, source_data, mark_bits, original_bits, had_classifier_material)
                append valid_nodes object_node
                marked_face_count += mark_bits.numberSet
            )
        )
    )

    if valid_nodes.count > 0 then
    (
        ensureWallClassifierMaterial valid_nodes

        for mark_data in mark_data_array do
        (
            local object_node = mark_data[1]
            local source_data = mark_data[2]
            local mark_bits = mark_data[3]
            local original_bits = mark_data[4]
            local had_classifier_material = mark_data[5]

            forceWallFaceClass object_node source_data material_id mark_bits
            setSourceFaceMaterialId object_node source_data mark_bits material_id
            setSourceFaceSelection object_node source_data original_bits
            cacheWallFaceClassesFromMaterialIds object_node source_data
        )

        select valid_nodes
        max modify mode

        if selection_level_before != undefined then
        (
            subObjectLevel = selection_level_before
        )

        redrawViews()
    )

    #(valid_nodes.count, marked_face_count, source_label) -- return
)

/* Returns true when two faces share at least the requested number of vertex indices.
   Forced hierarchy propagation uses two shared vertices so a single corner touch cannot inherit a class.
*/
function facesShareMinimumVertices face_indices_a face_indices_b minimum_shared_vertices:2 =
(
    local shared_count = 0

    for vertex_index in face_indices_a while shared_count < minimum_shared_vertices do
    (
        if (findItem face_indices_b vertex_index) > 0 then
        (
            shared_count += 1
        )
    )

    (shared_count >= minimum_shared_vertices) -- return
)

/* Builds edge-connected face elements for one selected object.
   Faces must share at least two vertices; a one-vertex corner touch starts a separate element.
*/
function buildWallHierarchyElements object_data object_data_index definite_threshold horizontal_normal_threshold:0.85 prefer_outer_seed:false =
(
    local vertex_world_cache = object_data[8]
    local face_vertex_indices = object_data[9]
    local face_normals = object_data[5]
    local face_scores = object_data[7]
    local vertex_faces = #()
    local visited_faces = #{}
    local element_data_array = #()

    for vertex_index = 1 to vertex_world_cache.count do
    (
        append vertex_faces #{}
    )

    for face_index = 1 to face_vertex_indices.count do
    (
        for vertex_index in face_vertex_indices[face_index] do
        (
            vertex_faces[vertex_index][face_index] = true
        )
    )

    for start_face = 1 to face_vertex_indices.count do
    (
        if not visited_faces[start_face] then
        (
            local pending_faces = #(start_face)
            local element_faces = #{}
            local element_vertices = #{}
            local has_horizontal_face = false
            local has_outer_seed = false
            local has_inner_seed = false
            local seed_class = 0
            local bbox_min = undefined
            local bbox_max = undefined

            visited_faces[start_face] = true

            while pending_faces.count > 0 do
            (
                local current_face = pending_faces[pending_faces.count]
                deleteItem pending_faces pending_faces.count
                element_faces[current_face] = true

                for vertex_index in face_vertex_indices[current_face] do
                (
                    element_vertices[vertex_index] = true

                    for neighbor_face in vertex_faces[vertex_index] do
                    (
                        if not visited_faces[neighbor_face] then
                        (
                            if facesShareMinimumVertices face_vertex_indices[current_face] face_vertex_indices[neighbor_face] minimum_shared_vertices:2 then
                            (
                                visited_faces[neighbor_face] = true
                                append pending_faces neighbor_face
                            )
                        )
                    )
                )
            )

            for face_index in element_faces do
            (
                local face_normal = face_normals[face_index]
                local face_score = face_scores[face_index]

                if (abs face_normal.z) >= horizontal_normal_threshold then
                (
                    has_horizontal_face = true
                )

                if face_score >= definite_threshold then
                (
                    has_outer_seed = true
                )
                else if face_score <= -definite_threshold then
                (
                    has_inner_seed = true
                )
            )

            if not has_horizontal_face then
            (
                if prefer_outer_seed and has_outer_seed then
                (
                    /* FORCED OUTER is the point of interest and wins a seed conflict. */
                    seed_class = 1
                )
                else if has_outer_seed and not has_inner_seed then
                (
                    seed_class = 1
                )
                else if has_inner_seed and not has_outer_seed then
                (
                    seed_class = 2
                )
            )

            for vertex_index in element_vertices do
            (
                local vertex_world = vertex_world_cache[vertex_index]

                if bbox_min == undefined then
                (
                    bbox_min = copy vertex_world
                    bbox_max = copy vertex_world
                )
                else
                (
                    if vertex_world.x < bbox_min.x then
                    (
                        bbox_min.x = vertex_world.x
                    )
                    if vertex_world.y < bbox_min.y then
                    (
                        bbox_min.y = vertex_world.y
                    )
                    if vertex_world.z < bbox_min.z then
                    (
                        bbox_min.z = vertex_world.z
                    )

                    if vertex_world.x > bbox_max.x then
                    (
                        bbox_max.x = vertex_world.x
                    )
                    if vertex_world.y > bbox_max.y then
                    (
                        bbox_max.y = vertex_world.y
                    )
                    if vertex_world.z > bbox_max.z then
                    (
                        bbox_max.z = vertex_world.z
                    )
                )
            )

            append element_data_array #(object_data_index, element_faces, element_vertices, has_horizontal_face, seed_class, bbox_min, bbox_max)
        )
    )

    element_data_array -- return
)

/* Returns true when two element bounds can touch within the connection threshold.
   This avoids expensive vertex comparisons for distant elements.
*/
function wallHierarchyBoundsOverlap element_a element_b connection_threshold =
(
    local min_a = element_a[6]
    local max_a = element_a[7]
    local min_b = element_b[6]
    local max_b = element_b[7]
    local overlap_result = true

    if min_a == undefined or min_b == undefined then
    (
        overlap_result = false
    )
    else
    (
        if (max_a.x + connection_threshold) < min_b.x or (max_b.x + connection_threshold) < min_a.x then
        (
            overlap_result = false
        )
        else if (max_a.y + connection_threshold) < min_b.y or (max_b.y + connection_threshold) < min_a.y then
        (
            overlap_result = false
        )
        else if (max_a.z + connection_threshold) < min_b.z or (max_b.z + connection_threshold) < min_a.z then
        (
            overlap_result = false
        )
    )

    overlap_result -- return
)

/* Counts unique matching world-space vertices between two separate wall elements.
   Two matches are treated as an edge-like wall connection instead of a corner touch.
*/
function countWallHierarchyVertexMatches element_a element_b object_data_array connection_threshold maximum_matches:2 =
(
    local match_count = 0
    local threshold_squared = connection_threshold * connection_threshold
    local object_data_a = object_data_array[element_a[1]]
    local object_data_b = object_data_array[element_b[1]]
    local vertex_world_a = object_data_a[8]
    local vertex_world_b = object_data_b[8]
    local vertices_a = element_a[3]
    local vertices_b = element_b[3]
    local matched_b = #{}

    if wallHierarchyBoundsOverlap element_a element_b connection_threshold then
    (
        for vertex_index_a in vertices_a do
        (
            if match_count < maximum_matches then
            (
                local point_a = vertex_world_a[vertex_index_a]
                local found_match = false

                for vertex_index_b in vertices_b do
                (
                    if not found_match and not matched_b[vertex_index_b] then
                    (
                        local delta = point_a - vertex_world_b[vertex_index_b]

                        if (dot delta delta) <= threshold_squared then
                        (
                            matched_b[vertex_index_b] = true
                            match_count += 1
                            found_match = true
                        )
                    )
                )
            )
        )
    )

    match_count -- return
)

/* Propagates reliable OUTER/INNER seeds through edge-connected wall elements and neighboring meshes.
   A face/element must connect through at least two shared vertices; floors and ceilings stop the chain.
*/
function resolveWallHierarchyByElements object_data_array connection_threshold confidence_threshold:0.12 horizontal_normal_threshold:0.85 minimum_matching_vertices:2 prefer_outer_seed:false =
(
    local definite_threshold = confidence_threshold * 2.0
    local all_elements = #()
    local resolved_count = 0
    local connection_count = 0

    if definite_threshold < 0.35 then
    (
        definite_threshold = 0.35
    )

    for object_data_index = 1 to object_data_array.count do
    (
        local object_elements = buildWallHierarchyElements object_data_array[object_data_index] object_data_index definite_threshold horizontal_normal_threshold:horizontal_normal_threshold prefer_outer_seed:prefer_outer_seed

        for element_data in object_elements do
        (
            append all_elements element_data
        )
    )

    /* First apply a reliable seed to the complete topological element.
       This fixes unresolved wall faces inside one wall element before cross-object propagation.
    */
    for element_data in all_elements do
    (
        local seed_class = element_data[5]

        if seed_class == 1 or seed_class == 2 then
        (
            local face_classes = object_data_array[element_data[1]][6]

            for face_index in element_data[2] do
            (
                if face_classes[face_index] != seed_class then
                (
                    face_classes[face_index] = seed_class
                    resolved_count += 1
                )
            )
        )
    )

    if connection_threshold > 0.0 and all_elements.count > 1 then
    (
        local element_neighbors = #()
        local visited_elements = #{}

        for element_index = 1 to all_elements.count do
        (
            append element_neighbors #{}
        )

        for element_index_a = 1 to (all_elements.count - 1) do
        (
            local element_a = all_elements[element_index_a]

            if not element_a[4] then
            (
                for element_index_b = (element_index_a + 1) to all_elements.count do
                (
                    local element_b = all_elements[element_index_b]

                    if not element_b[4] then
                    (
                        local match_count = countWallHierarchyVertexMatches element_a element_b object_data_array connection_threshold maximum_matches:minimum_matching_vertices

                        if match_count >= minimum_matching_vertices then
                        (
                            element_neighbors[element_index_a][element_index_b] = true
                            element_neighbors[element_index_b][element_index_a] = true
                            connection_count += 1
                        )
                    )
                )
            )
        )

        for start_element = 1 to all_elements.count do
        (
            if not visited_elements[start_element] and not all_elements[start_element][4] then
            (
                local pending_elements = #(start_element)
                local network_elements = #{}
                local has_outer_seed = false
                local has_inner_seed = false
                local network_class = 0

                visited_elements[start_element] = true

                while pending_elements.count > 0 do
                (
                    local current_element = pending_elements[pending_elements.count]
                    local current_seed = all_elements[current_element][5]
                    deleteItem pending_elements pending_elements.count
                    network_elements[current_element] = true

                    if current_seed == 1 then
                    (
                        has_outer_seed = true
                    )
                    else if current_seed == 2 then
                    (
                        has_inner_seed = true
                    )

                    for neighbor_element in element_neighbors[current_element] do
                    (
                        if not visited_elements[neighbor_element] then
                        (
                            visited_elements[neighbor_element] = true
                            append pending_elements neighbor_element
                        )
                    )
                )

                if prefer_outer_seed and has_outer_seed then
                (
                    /* FORCED OUTER wins when OUTER and INNER hints meet in one wall network. */
                    network_class = 1
                )
                else if has_outer_seed and not has_inner_seed then
                (
                    network_class = 1
                )
                else if has_inner_seed and not has_outer_seed then
                (
                    network_class = 2
                )

                if network_class == 1 or network_class == 2 then
                (
                    for element_index in network_elements do
                    (
                        local element_data = all_elements[element_index]

                        if element_data[5] == 0 or (prefer_outer_seed and network_class == 1 and element_data[5] == 2) then
                        (
                            local face_classes = object_data_array[element_data[1]][6]

                            for face_index in element_data[2] do
                            (
                                if face_classes[face_index] != network_class then
                                (
                                    face_classes[face_index] = network_class
                                    resolved_count += 1
                                )
                            )
                        )
                    )
                )
            )
        )
    )

    format "Wall hierarchy: % elements | % neighbor links | % faces resolved | vertex threshold: %\\n" all_elements.count connection_count resolved_count connection_threshold

    #(resolved_count, all_elements.count, connection_count) -- return
)

/* Classifies selected faces into OUTER, INNER, UP, and DOWN.
   Persistent FORCED OUTER/INNER hints propagate first, then automatic wall tests resolve the rest.
*/
function classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) horizontal_normal_threshold:0.85 =
(
    local selected_nodes = getWallFaceWorkingNodes()
    local valid_nodes = #()
    local object_data_array = #()
    local bbox_min = undefined
    local bbox_max = undefined
    local total_faces = 0
    local outer_count = 0
    local inner_count = 0
    local up_count = 0
    local down_count = 0
    local selection_type = #none
    local thickness_resolved = 0
    local hierarchy_resolved = 0
    local forced_hierarchy_resolved = 0
    local forced_face_count = 0
    local neighbor_resolved = 0
    local fallback_resolved = 0

    if selected_nodes.count == 0 then
    (
        messageBox "Select wall objects first, or run CLASSIFY once so the last object set can be restored." title:"Inner-Outer Wall Finder"
        #() -- return
    )
    else
    (
        for object_node in selected_nodes do
        (
            local source_data = getFaceGeometrySource object_node

            if source_data != undefined then
            (
                append valid_nodes object_node
                local vertex_count = getSourceNumVertices object_node source_data

                for vertex_index = 1 to vertex_count do
                (
                    local vertex_world = getSourceVertexWorld object_node source_data vertex_index

                    if bbox_min == undefined then
                    (
                        bbox_min = copy vertex_world
                        bbox_max = copy vertex_world
                    )
                    else
                    (
                        if vertex_world.x < bbox_min.x then
                        (
                            bbox_min.x = vertex_world.x
                        )
                        if vertex_world.y < bbox_min.y then
                        (
                            bbox_min.y = vertex_world.y
                        )
                        if vertex_world.z < bbox_min.z then
                        (
                            bbox_min.z = vertex_world.z
                        )

                        if vertex_world.x > bbox_max.x then
                        (
                            bbox_max.x = vertex_world.x
                        )
                        if vertex_world.y > bbox_max.y then
                        (
                            bbox_max.y = vertex_world.y
                        )
                        if vertex_world.z > bbox_max.z then
                        (
                            bbox_max.z = vertex_world.z
                        )
                    )
                )
            )
        )

        if valid_nodes.count == 0 or bbox_min == undefined then
        (
            messageBox "No supported objects found. Use Editable Poly or an object with Edit Poly as the top modifier." title:"Inner-Outer Wall Finder"
            #() -- return
        )
        else
        (
            wall_face_classifier_last_nodes = for object_node in valid_nodes collect object_node

            local bbox_center = (bbox_min + bbox_max) * 0.5
            local bbox_diagonal = length (bbox_max - bbox_min)
            local geometry_epsilon = bbox_diagonal * 0.00000001
            local ray_offset = bbox_diagonal * 0.00001

            if geometry_epsilon < 0.0000001 then
            (
                geometry_epsilon = 0.0000001
            )

            if ray_offset < 0.0001 then
            (
                ray_offset = 0.0001
            )

            for object_node in valid_nodes do
            (
                local source_data = getFaceGeometrySource object_node
                local vertex_count = getSourceNumVertices object_node source_data
                local face_count = getSourceNumFaces object_node source_data
                local vertex_world_cache = #()
                local cached_faces = #()
                local face_centers = #()
                local face_normals = #()
                local face_classes = #()
                local face_scores = #()
                local face_vertex_indices = #()
                local forced_outer_bits = getForcedWallFaceBits object_node source_data 1
                local forced_inner_bits = getForcedWallFaceBits object_node source_data 2

                total_faces += face_count
                forced_face_count += forced_outer_bits.numberSet
                forced_face_count += forced_inner_bits.numberSet

                for vertex_index = 1 to vertex_count do
                (
                    append vertex_world_cache (getSourceVertexWorld object_node source_data vertex_index)
                )

                for face_index = 1 to face_count do
                (
                    local face_degree = getSourceFaceDegree object_node source_data face_index
                    local face_vertices = #()
                    local face_indices = #()

                    for corner_index = 1 to face_degree do
                    (
                        local vertex_index = getSourceFaceVertex object_node source_data face_index corner_index
                        append face_indices vertex_index
                        append face_vertices vertex_world_cache[vertex_index]
                    )

                    local initial_class = 0
                    local initial_score = 0.0

                    if forced_outer_bits[face_index] then
                    (
                        initial_class = 1
                        initial_score = 1.0
                    )
                    else if forced_inner_bits[face_index] then
                    (
                        initial_class = 2
                        initial_score = -1.0
                    )

                    append cached_faces face_vertices
                    append face_centers (calculatePolygonCenter face_vertices)
                    append face_normals (calculatePolygonNormal face_vertices epsilon:geometry_epsilon)
                    append face_classes initial_class
                    append face_scores initial_score
                    append face_vertex_indices face_indices
                )

                append object_data_array #(object_node, source_data, cached_faces, face_centers, face_normals, face_classes, face_scores, vertex_world_cache, face_vertex_indices)
            )

            if forced_face_count > 0 then
            (
                local forced_hierarchy_result = resolveWallHierarchyByElements object_data_array connection_threshold confidence_threshold:confidence_threshold horizontal_normal_threshold:horizontal_normal_threshold minimum_matching_vertices:2 prefer_outer_seed:true
                forced_hierarchy_resolved = forced_hierarchy_result[1]
                hierarchy_resolved += forced_hierarchy_resolved
            )

            for object_data in object_data_array do
            (
                local face_centers = object_data[4]
                local face_normals = object_data[5]
                local face_classes = object_data[6]
                local face_scores = object_data[7]

                for face_index = 1 to face_classes.count do
                (
                    local face_center = face_centers[face_index]
                    local face_normal = face_normals[face_index]

                    if face_classes[face_index] == 1 or face_classes[face_index] == 2 then
                    (
                        /* FORCED or force-propagated wall class: preserve it. */
                    )
                    else if (length face_normal) <= geometry_epsilon then
                    (
                        face_classes[face_index] = 0
                    )
                    else if face_normal.z >= horizontal_normal_threshold then
                    (
                        face_classes[face_index] = 3
                    )
                    else if face_normal.z <= -horizontal_normal_threshold then
                    (
                        face_classes[face_index] = 4
                    )
                    else
                    (
                        local plus_exit = getBBoxExitDistance face_center face_normal bbox_min bbox_max epsilon:geometry_epsilon
                        local minus_exit = getBBoxExitDistance face_center (-face_normal) bbox_min bbox_max epsilon:geometry_epsilon
                        local bbox_score = 0.0
                        local radial_vector = face_center - bbox_center
                        local radial_score = 0.0
                        local spatial_score = 0.0

                        if (plus_exit + minus_exit) > geometry_epsilon then
                        (
                            bbox_score = (minus_exit - plus_exit) / (plus_exit + minus_exit)
                        )

                        if (length radial_vector) > geometry_epsilon then
                        (
                            radial_score = dot face_normal (normalize radial_vector)
                        )

                        spatial_score = (bbox_score * 0.70) + (radial_score * 0.30)
                        face_scores[face_index] = spatial_score

                        if spatial_score >= confidence_threshold then
                        (
                            face_classes[face_index] = 1
                        )
                        else if spatial_score <= -confidence_threshold then
                        (
                            face_classes[face_index] = 2
                        )
                        else
                        (
                            face_classes[face_index] = 0
                        )
                    )
                )
            )

            thickness_resolved = resolveUnresolvedWallsByThickness object_data_array wall_thickness confidence_threshold:confidence_threshold parallel_threshold:0.90 ray_offset:ray_offset epsilon:geometry_epsilon

            local hierarchy_result = resolveWallHierarchyByElements object_data_array connection_threshold confidence_threshold:confidence_threshold horizontal_normal_threshold:horizontal_normal_threshold minimum_matching_vertices:2
            hierarchy_resolved += hierarchy_result[1]

            neighbor_resolved = resolveUnresolvedWallFaces object_data_array neighbor_passes:neighbor_passes
            fallback_resolved = finalizeUnresolvedWallFaces object_data_array

            assignWallClassifierMaterial valid_nodes

            for object_data in object_data_array do
            (
                local object_node = object_data[1]
                local source_data = object_data[2]
                local face_classes = object_data[6]
                local outer_bits = buildFaceClassBits face_classes 1
                local inner_bits = buildFaceClassBits face_classes 2
                local up_bits = buildFaceClassBits face_classes 3
                local down_bits = buildFaceClassBits face_classes 4

                outer_count += outer_bits.numberSet
                inner_count += inner_bits.numberSet
                up_count += up_bits.numberSet
                down_count += down_bits.numberSet

                setSourceFaceMaterialId object_node source_data outer_bits 1
                setSourceFaceMaterialId object_node source_data inner_bits 2
                setSourceFaceMaterialId object_node source_data up_bits 3
                setSourceFaceMaterialId object_node source_data down_bits 4
                cacheWallFaceClasses object_node face_classes.count outer_bits inner_bits up_bits down_bits
            )

            if outer_count > 0 then
            (
                selection_type = #outer
            )
            else if inner_count > 0 then
            (
                selection_type = #inner
            )
            else if up_count > 0 then
            (
                selection_type = #up
            )
            else if down_count > 0 then
            (
                selection_type = #down
            )

            for object_data in object_data_array do
            (
                local object_node = object_data[1]
                local source_data = object_data[2]
                local face_classes = object_data[6]
                local selection_bits = #{}

                if selection_type == #inner then
                (
                    selection_bits = buildFaceClassBits face_classes 2
                )
                else if selection_type == #outer then
                (
                    selection_bits = buildFaceClassBits face_classes 1
                )
                else if selection_type == #up then
                (
                    selection_bits = buildFaceClassBits face_classes 3
                )
                else if selection_type == #down then
                (
                    selection_bits = buildFaceClassBits face_classes 4
                )

                setSourceFaceSelection object_node source_data selection_bits
            )

            select valid_nodes
            max modify mode
            subObjectLevel = 4
            redrawViews()

            format "Inner-Outer Wall Finder 0.22: % faces | FORCED hints: % | forced propagation: % | OUTER: % | INNER: % | UP: % | DOWN: % | thickness: % | hierarchy total: % | neighbor: % | fallback: % | selected: %\n" total_faces forced_face_count forced_hierarchy_resolved outer_count inner_count up_count down_count thickness_resolved hierarchy_resolved neighbor_resolved fallback_resolved selection_type

            #(valid_nodes.count, total_faces, outer_count, inner_count, up_count, down_count, selection_type, thickness_resolved, hierarchy_resolved, neighbor_resolved, fallback_resolved) -- return
        )
    )
)

/* Creates a non-destructive test setup with OUTER/INNER walls and horizontal caps.
   The box faces provide clear UP and DOWN normal-direction test cases.
*/
function createWallFaceClassifierTestScene =
(
    local outer_box = box width:200 length:200 height:120 pos:[0, 0, 60] name:(uniqueName "WFC_TEST_OUTER")
    local inner_box = box width:80 length:80 height:60 pos:[0, 0, 60] name:(uniqueName "WFC_TEST_INNER")

    convertToPoly outer_box
    convertToPoly inner_box
    polyOp.flipNormals inner_box #all

    select #(outer_box, inner_box)
    redrawViews()

    #(outer_box, inner_box) -- return
)

/* Runs a one-click test using the generated scene and default settings.
   The generated objects remain selected so only those objects are analyzed.
*/
function testWallFaceClassifier wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    createWallFaceClassifierTestScene()
    classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:wall_thickness connection_threshold:connection_threshold
)

/* Tests all four Material IDs and the assigned Multi/Sub-Object material.
   Creates the test scene, classifies it, and prints each assigned sub-material.
*/
function testWallFaceClassifierMaterials wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    local test_nodes = createWallFaceClassifierTestScene()
    local result_data = classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:wall_thickness connection_threshold:connection_threshold

    if test_nodes.count > 0 then
    (
        local classifier_material = test_nodes[1].material

        format "Classifier material: %\n" classifier_material
        format "ID 1 OUTER: % | diffuse: %\n" classifier_material.materialList[1].name classifier_material.materialList[1].diffuse
        format "ID 2 INNER: % | diffuse: %\n" classifier_material.materialList[2].name classifier_material.materialList[2].diffuse
        format "ID 3 UP: % | diffuse: %\n" classifier_material.materialList[3].name classifier_material.materialList[3].diffuse
        format "ID 4 DOWN: % | diffuse: %\n" classifier_material.materialList[4].name classifier_material.materialList[4].diffuse
    )

    result_data -- return
)

/* Tests Material ID face selection after running the classifier.
   Pass material_id 1, 2, 3, or 4 to test OUTER, INNER, UP, or DOWN.
*/
function testWallFaceClassSelection material_id:1 wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    createWallFaceClassifierTestScene()
    classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:wall_thickness connection_threshold:connection_threshold
    selectWallFacesByMaterialId material_id
)

/* Tests cached class selection after a normal classification pass.
   Prints cache size and selects OUTER faces through the cached path.
*/
function testWallFaceClassifierCache wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    local result_data = #()

    createWallFaceClassifierTestScene()
    classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:wall_thickness connection_threshold:connection_threshold
    result_data = selectWallFacesByMaterialId 1
    format "Classifier cache entries: % | OUTER selected: %\n" wall_face_classifier_cache.count result_data[2]
    result_data -- return
)

/* Tests RMB-style manual marking without using the rollout event handler.
   Object-level test marks every face of a new Editable Poly box as INNER.
*/
function testMarkSelectedWallFaces =
(
    local test_box = box width:100 length:100 height:100 pos:[0, 0, 50] name:(uniqueName "WFC_TEST_MARK")
    local result_data = #()

    convertToPoly test_box
    select test_box
    max modify mode
    subObjectLevel = 0
    result_data = markSelectedWallFaces 2
    format "Manual mark test | objects: % | INNER faces marked: %\n" result_data[1] result_data[2]
    result_data -- return
)

/* Returns a short suffix for one physical unit type.
   Used for metric, US, and 1:1 custom display units.
*/
function getWallFacePhysicalUnitLabel unit_type =
(
    local unit_label = "units"

    case unit_type of
    (
        #Millimeters: unit_label = "mm"
        #Centimeters: unit_label = "cm"
        #Meters: unit_label = "m"
        #Kilometers: unit_label = "km"
        #Inches: unit_label = "in"
        #Feet: unit_label = "ft"
        #Miles: unit_label = "mi"
        default: unit_label = "units"
    )

    unit_label -- return
)

/* Returns a short label for the current 3ds Max display units.
   A 1:1 Custom unit uses its physical unit suffix, for example 1 mm -> mm.
*/
function getWallFaceDisplayUnitLabel =
(
    local unit_label = "units"
    local custom_value_epsilon = 0.000001

    case units.DisplayType of
    (
        #Generic:
        (
            unit_label = "units"
        )
        #Metric:
        (
            unit_label = getWallFacePhysicalUnitLabel units.MetricType
        )
        #US:
        (
            case units.USType of
            (
                #Frac_In: unit_label = "in"
                #Dec_In: unit_label = "in"
                #Frac_Ft: unit_label = "ft"
                #Dec_Ft: unit_label = "ft"
                #Ft_Frac_In: unit_label = "ft/in"
                #Ft_Dec_In: unit_label = "ft/in"
                default: unit_label = "US"
            )
        )
        #custom:
        (
            if (abs (units.CustomValue - 1.0)) <= custom_value_epsilon then
            (
                unit_label = getWallFacePhysicalUnitLabel units.CustomUnit
            )
            else if units.CustomName != "" then
            (
                unit_label = units.CustomName
            )
            else
            (
                unit_label = "custom"
            )
        )
        default:
        (
            unit_label = "units"
        )
    )

    unit_label -- return
)

/* Tests the object > element > face hierarchy pass on the current selected objects.
   Prints how many faces were resolved by element/network propagation.
*/
function testWallHierarchyPropagation connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    local result_data = classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:(units.decodeValue "1m") connection_threshold:connection_threshold

    if result_data.count == 11 then
    (
        format "Hierarchy test: % faces resolved with connection threshold %\n" result_data[9] connection_threshold
    )

    result_data -- return
)

/* Tests the display-unit label helper used by the thickness controls.
   For Custom units it also prints the scale and physical reference unit.
*/
function testWallFaceDisplayUnitLabel =
(
    local unit_label = getWallFaceDisplayUnitLabel()

    if units.DisplayType == #custom then
    (
        format "Display type: % | Custom value: % | Custom unit: % | UI label: %\n" units.DisplayType units.CustomValue units.CustomUnit unit_label
    )
    else
    (
        format "Display type: % | UI label: %\n" units.DisplayType unit_label
    )

    unit_label -- return
)

/* Tests the unit-independent 1 meter default used by Wall thickness.
   Prints its value in system units and the current display-unit string.
*/
function testWallFaceDefaultThickness =
(
    local one_meter = units.decodeValue "1m"
    format "Wall thickness default = 1m | System-unit value: %\n" one_meter
    one_meter -- return
)

/* Reports and validates persistent FORCED OUTER/INNER hints on the current selection.
   With run_classification:true it verifies that classification preserves every forced face.
*/
function testWallFaceForcedHints run_classification:false =
(
    local selected_nodes = for object_node in selection where superclassof object_node == GeometryClass collect object_node
    local forced_outer_count = 0
    local forced_inner_count = 0
    local failed_face_count = 0

    for object_node in selected_nodes do
    (
        local source_data = getFaceGeometrySource object_node

        if source_data != undefined then
        (
            local forced_outer_bits = getForcedWallFaceBits object_node source_data 1
            local forced_inner_bits = getForcedWallFaceBits object_node source_data 2
            forced_outer_count += forced_outer_bits.numberSet
            forced_inner_count += forced_inner_bits.numberSet
        )
    )

    format "FORCED hints | OUTER: % | INNER: %\n" forced_outer_count forced_inner_count

    if run_classification then
    (
        classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1)

        for object_node in selected_nodes do
        (
            local source_data = getFaceGeometrySource object_node

            if source_data != undefined then
            (
                local forced_outer_bits = getForcedWallFaceBits object_node source_data 1
                local forced_inner_bits = getForcedWallFaceBits object_node source_data 2

                for face_index in forced_outer_bits do
                (
                    if getSourceFaceMaterialId object_node source_data face_index != 1 then
                    (
                        failed_face_count += 1
                    )
                )

                for face_index in forced_inner_bits do
                (
                    if getSourceFaceMaterialId object_node source_data face_index != 2 then
                    (
                        failed_face_count += 1
                    )
                )
            )
        )

        format "FORCED preservation failures: %\n" failed_face_count
    )

    #(forced_outer_count, forced_inner_count, failed_face_count) -- return
)

/* Returns the visible wall-face class name for one classifier color.
   Used to name objects created by EXPLODE.
*/
function getWallFaceClassName material_id =
(
    local class_name = "CLASS"

    case material_id of
    (
        1: class_name = "OUTER"
        2: class_name = "INNER"
        3: class_name = "UP"
        4: class_name = "DOWN"
        default: class_name = "CLASS"
    )

    class_name -- return
)

/* Explodes selected classified objects into separate color-class objects.
   Mixed objects are split into OUTER, INNER, UP, and DOWN objects by face Material ID.
*/
function explodeSelectedWallFacesByClass =
(
    local selected_nodes = for object_node in selection where superclassof object_node == GeometryClass collect object_node
    local result_nodes = #()
    local exploded_source_count = 0
    local created_object_count = 0
    local skipped_object_count = 0

    for object_node in selected_nodes do
    (
        if isValidNode object_node then
        (
            local source_data = getFaceGeometrySource object_node

            if source_data != undefined and hasWallClassifierMaterial object_node then
            (
                local face_count = getSourceNumFaces object_node source_data
                local used_class_ids = #()

                for face_index = 1 to face_count do
                (
                    local material_id = getSourceFaceMaterialId object_node source_data face_index

                    if material_id >= 1 and material_id <= 4 then
                    (
                        if (findItem used_class_ids material_id) == 0 then
                        (
                            append used_class_ids material_id
                        )
                    )
                )

                if used_class_ids.count > 1 then
                (
                    local source_name = object_node.name
                    local source_result_nodes = #()

                    for material_id in used_class_ids do
                    (
                        local split_node = copy object_node
                        local class_name = getWallFaceClassName material_id

                        split_node.name = uniqueName (source_name + "_" + class_name)
                        collapseStack split_node

                        if classof split_node.baseObject != Editable_Poly then
                        (
                            convertToPoly split_node
                        )

                        local split_face_count = polyop.getNumFaces split_node
                        local delete_bits = #{}

                        for split_face_index = 1 to split_face_count do
                        (
                            if (polyop.getFaceMatID split_node split_face_index) != material_id then
                            (
                                delete_bits[split_face_index] = true
                            )
                        )

                        if delete_bits.numberSet > 0 then
                        (
                            polyop.deleteFaces split_node delete_bits delIsoVerts:true
                        )

                        if (polyop.getNumFaces split_node) > 0 then
                        (
                            setForcedWallFaceBits split_node 1 #{}
                            setForcedWallFaceBits split_node 2 #{}
                            append source_result_nodes split_node
                            append result_nodes split_node
                            created_object_count += 1
                        )
                        else
                        (
                            delete split_node
                        )
                    )

                    if source_result_nodes.count > 0 then
                    (
                        delete object_node
                        exploded_source_count += 1
                    )
                )
                else if used_class_ids.count == 1 then
                (
                    append result_nodes object_node
                )
                else
                (
                    skipped_object_count += 1
                )
            )
            else
            (
                skipped_object_count += 1
            )
        )
    )

    wall_face_classifier_cache = #()
    wall_face_classifier_last_nodes = for object_node in result_nodes where isValidNode object_node collect object_node

    if result_nodes.count > 0 then
    (
        select result_nodes
        max modify mode
        subObjectLevel = 0
    )

    redrawViews()
    #(exploded_source_count, created_object_count, skipped_object_count, result_nodes.count) -- return
)

/* Tests EXPLODE after classifying the built-in test scene.
   Prints how many source objects were split and how many result objects were created.
*/
function testWallFaceClassifierExplode wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1) =
(
    createWallFaceClassifierTestScene()
    classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:wall_thickness connection_threshold:connection_threshold

    local result_data = explodeSelectedWallFacesByClass()
    format "EXPLODE test | split sources: % | created objects: % | skipped: % | selected results: %\n" result_data[1] result_data[2] result_data[3] result_data[4]

    result_data -- return
)

/* Tests RMB reset behavior on the current selected supported objects.
   Verifies FORCED hints are empty and every reset face uses Material ID 1.
*/
function testWallFaceClassifierReset =
(
    local result_data = resetSelectedWallFaceClassification()
    local forced_face_count = 0
    local non_default_id_count = 0

    for object_node in selection where superclassof object_node == GeometryClass do
    (
        local source_data = getFaceGeometrySource object_node

        if source_data != undefined then
        (
            local forced_outer_bits = getForcedWallFaceBits object_node source_data 1
            local forced_inner_bits = getForcedWallFaceBits object_node source_data 2
            local face_count = getSourceNumFaces object_node source_data

            forced_face_count += forced_outer_bits.numberSet + forced_inner_bits.numberSet

            for face_index = 1 to face_count do
            (
                if getSourceFaceMaterialId object_node source_data face_index != 1 then
                (
                    non_default_id_count += 1
                )
            )
        )
    )

    format "RESET objects: % | faces: % | forced faces left: % | non-default Material IDs: %\n" result_data[1] result_data[2] forced_face_count non_default_id_count
    #(result_data[1], result_data[2], forced_face_count, non_default_id_count) -- return
)

/* Tests the two-shared-vertex rule used by FORCED hierarchy propagation.
   One shared corner must fail while a shared edge of two vertices must pass.
*/
function testForcedMinimumSharedVertices =
(
    local forced_face = #(1, 2, 3, 4)
    local corner_touch_face = #(4, 5, 6, 7)
    local edge_touch_face = #(3, 4, 8, 9)
    local corner_result = facesShareMinimumVertices forced_face corner_touch_face minimum_shared_vertices:2
    local edge_result = facesShareMinimumVertices forced_face edge_touch_face minimum_shared_vertices:2

    format "FORCED 2-vertex rule | corner touch: % | edge touch: %\n" corner_result edge_result
    #(corner_result, edge_result) -- return
)

/* Tests FORCED OUTER priority across connected wall elements without changing the scene.
   An OUTER forced element must override a connected INNER forced element.
*/
function testForcedOuterPriority =
(
    local shared_vertices = #([0, 0, 0], [0, 0, 10], [10, 0, 10], [10, 0, 0])
    local face_indices = #(#(1, 2, 3, 4))
    local outer_data = #(undefined, undefined, #(), #(), #([1, 0, 0]), #(1), #(1.0), shared_vertices, face_indices)
    local inner_data = #(undefined, undefined, #(), #(), #([1, 0, 0]), #(2), #(-1.0), shared_vertices, face_indices)
    local object_data_array = #(outer_data, inner_data)
    local result_data = resolveWallHierarchyByElements object_data_array 1.0 confidence_threshold:0.12 horizontal_normal_threshold:0.85 minimum_matching_vertices:2 prefer_outer_seed:true
    local outer_result = object_data_array[1][6][1]
    local inner_result = object_data_array[2][6][1]
    local priority_ok = (outer_result == 1 and inner_result == 1)

    format "FORCED priority | OUTER element: % | connected INNER element becomes: % | passed: %\n" outer_result inner_result priority_ok

    priority_ok -- return
)

/* Tests the color-name legend used by the CLASSIFY tooltip.
   Prints the four visible class labels without material ID numbers.
*/
function testWallFaceClassifierColorLegend =
(
    format "Green = OUTER | Orange = INNER | Pastel Blue = UP | Pastel Brown = DOWN\n"
    true -- return
)

/* Tests the default connection-threshold relationship without changing the scene.
   The expected threshold is exactly ten percent of the supplied wall thickness.
*/
function testWallFaceDefaultConnectionThreshold wall_thickness:(units.decodeValue "1m") =
(
    local connection_threshold = getDefaultWallConnectionThreshold wall_thickness

    format "Wall thickness: % | default Connect threshold: % | ratio: %\n" wall_thickness connection_threshold (connection_threshold / wall_thickness)

    connection_threshold -- return
)

/* Tests last-run object restoration and both LMB selection modes.
   It classifies a test scene, clears node selection, restores matching objects, then selects matching faces.
*/
function testWallFaceSelectionRestore =
(
    local test_nodes = createWallFaceClassifierTestScene()
    local classify_result = classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:(units.decodeValue "1m") connection_threshold:((units.decodeValue "1m") * 0.1)
    local object_result = #()
    local face_result = #()

    clearSelection()
    object_result = selectWallFacesByMaterialId 1

    if selection.count > 0 then
    (
        max modify mode
        subObjectLevel = 4
        face_result = selectWallFacesByMaterialId 1
    )

    format "Restore test | classified objects: % | OUTER objects restored: % | OUTER faces selected: %\n" classify_result[1] object_result[1] face_result[2]

    #(object_result, face_result) -- return
)

rollout wallFaceClassifierRollout "4. Get Outter Walls" width:276 height:208
(
    spinner spn_wall_thickness "Wall thickness:" pos:[8,8] width:204 height:20 range:[0.001,1000000.0,(units.decodeValue "1m")] type:#worldunits fieldwidth:70 \
        tooltip:"Maximum distance to search for the opposite wall. Default: 1 m."
    label lbl_wall_units "units" pos:[218,12] width:50 height:18 align:#left tooltip:"Current display unit."

    spinner spn_connection_threshold "Connect threshold:" pos:[8,34] width:204 height:20 range:[0.001,1000000.0,((units.decodeValue "1m") * 0.1)] type:#worldunits fieldwidth:70 \
        tooltip:"Matches neighbor vertices; at least 2 must match. Default is 10% of Wall thickness, and changing Wall thickness resets this value."
    label lbl_connect_units "units" pos:[218,38] width:50 height:18 align:#left tooltip:"Current display unit."

    button btn_classify "INNER \\ OUTTER" pos:[8,60] width:82 height:32 tooltip:"LMB: Classify selected objects. If nothing is selected, restore the last classified object set. FORCED hints run first; OUTER has priority.\n\nGreen = OUTER | Orange = INNER | Pastel Blue = UP | Pastel Brown = DOWN."
    button btn_explode "EXPLODE" pos:[97,60] width:82 height:32 tooltip:"LMB: Split each selected classified object into separate OUTER, INNER, UP, and DOWN objects."
    button btn_reset "RESET" pos:[186,60] width:82 height:32 tooltip:"LMB: Reset face classification, clear FORCED OUTER/INNER hints, and clear cached class data."

    button btn_select_outer "SELECT OUTER" pos:[8,98] width:127 height:24 tooltip:"LMB: Object mode selects objects containing OUTER faces. Face mode selects OUTER faces.\n\nRMB: FORCE selected faces or objects OUTER. Highest-priority classification seed."
    button btn_select_inner "SELECT INNER" pos:[141,98] width:127 height:24 tooltip:"LMB: Object mode selects objects containing INNER faces. Face mode selects INNER faces.\n\nRMB: FORCE selected faces or objects INNER. Used as a classification seed."
    button btn_select_up "SELECT UP" pos:[8,128] width:127 height:24 tooltip:"LMB: Object mode selects objects containing UP faces. Face mode selects UP faces."
    button btn_select_down "SELECT DOWN" pos:[141,128] width:127 height:24 tooltip:"LMB: Object mode selects objects containing DOWN faces. Face mode selects DOWN faces."

    label lbl_status "Ready" pos:[8,158] width:260 height:18 align:#left tooltip:"Classification counts and current selection."
    button btn_test "Create test scene" pos:[8,180] width:130 height:24 tooltip:"Create simple wall geometry for testing."

    on wallFaceClassifierRollout open do
    (
        local unit_label = getWallFaceDisplayUnitLabel()
        lbl_wall_units.text = unit_label
        lbl_connect_units.text = unit_label
    )

    on spn_wall_thickness changed thickness_value do
    (
        local unit_label = getWallFaceDisplayUnitLabel()
        lbl_wall_units.text = unit_label
        lbl_connect_units.text = unit_label
        spn_connection_threshold.value = getDefaultWallConnectionThreshold thickness_value
    )

    on spn_connection_threshold changed threshold_value do
    (
        local unit_label = getWallFaceDisplayUnitLabel()
        lbl_wall_units.text = unit_label
        lbl_connect_units.text = unit_label
    )

    on btn_classify pressed do
    (
        local result_data = #()
        local unit_label = getWallFaceDisplayUnitLabel()
        lbl_wall_units.text = unit_label
        lbl_connect_units.text = unit_label

        undo "Classify Wall Faces" on
        (
            result_data = classifySelectedWallFaces confidence_threshold:0.12 neighbor_passes:3 wall_thickness:spn_wall_thickness.value connection_threshold:spn_connection_threshold.value
        )

        if result_data.count == 11 then
        (
            lbl_status.text = ("OUTER: " + result_data[3] as string + "  INNER: " + result_data[4] as string + "  UP: " + result_data[5] as string + "  DOWN: " + result_data[6] as string)
        )
    )

    on btn_explode pressed do
    (
        local result_data = #()

        undo "Explode Wall Faces By Class" on
        (
            result_data = explodeSelectedWallFacesByClass()
        )

        if result_data.count == 4 then
        (
            lbl_status.text = ("EXPLODE: " + result_data[2] as string + " objects created from " + result_data[1] as string + " sources")
        )
    )

    on btn_reset pressed do
    (
        local result_data = #()

        undo "Reset Wall Face Classification" on
        (
            result_data = resetSelectedWallFaceClassification()
        )

        if result_data.count == 2 then
        (
            lbl_status.text = ("RESET: " + result_data[1] as string + " objects | " + result_data[2] as string + " face IDs | FORCED data cleared")
        )
    )

    on btn_select_outer pressed do
    (
        local result_data = selectWallFacesByMaterialId 1

        if result_data.count == 3 then
        (
            if result_data[3] == #faces then
            (
                lbl_status.text = ("OUTER faces: " + result_data[2] as string)
            )
            else
            (
                lbl_status.text = ("OUTER objects: " + result_data[1] as string)
            )
        )
    )

    on btn_select_outer rightclick do
    (
        local result_data = #()

        undo "Force Wall Faces OUTER" on
        (
            result_data = markSelectedWallFaces 1
        )

        if result_data.count == 3 then
        (
            lbl_status.text = ("FORCED OUTER: " + result_data[2] as string + " faces | " + result_data[3] as string)
        )
    )

    on btn_select_inner pressed do
    (
        local result_data = selectWallFacesByMaterialId 2

        if result_data.count == 3 then
        (
            if result_data[3] == #faces then
            (
                lbl_status.text = ("INNER faces: " + result_data[2] as string)
            )
            else
            (
                lbl_status.text = ("INNER objects: " + result_data[1] as string)
            )
        )
    )

    on btn_select_inner rightclick do
    (
        local result_data = #()

        undo "Force Wall Faces INNER" on
        (
            result_data = markSelectedWallFaces 2
        )

        if result_data.count == 3 then
        (
            lbl_status.text = ("FORCED INNER: " + result_data[2] as string + " faces | " + result_data[3] as string)
        )
    )

    on btn_select_up pressed do
    (
        local result_data = selectWallFacesByMaterialId 3

        if result_data.count == 3 then
        (
            if result_data[3] == #faces then
            (
                lbl_status.text = ("UP faces: " + result_data[2] as string)
            )
            else
            (
                lbl_status.text = ("UP objects: " + result_data[1] as string)
            )
        )
    )

    on btn_select_down pressed do
    (
        local result_data = selectWallFacesByMaterialId 4

        if result_data.count == 3 then
        (
            if result_data[3] == #faces then
            (
                lbl_status.text = ("DOWN faces: " + result_data[2] as string)
            )
            else
            (
                lbl_status.text = ("DOWN objects: " + result_data[1] as string)
            )
        )
    )

    on btn_test pressed do
    (
        createWallFaceClassifierTestScene()
        lbl_status.text = "Test scene created."
    )
)

