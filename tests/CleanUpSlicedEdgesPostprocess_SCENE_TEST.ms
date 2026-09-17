/*
Run with test_wall-complex-002.max as -sceneFile in a disposable 3dsmaxbatch process.

Regression protected here:
- only vertices generated above the Editable Poly base may be removed;
- every original base-object vertex remains live;
- each removed redundant midpoint replaces two visible edges with one visible edge;
- cleanup is recorded in the dedicated named Edit Poly modifier.
*/
(
    global WallMeshCleaner

    local root_path = (getFilenamePath (getSourceFileName())) + "..\\"
    local report_path = root_path + "tests\\CleanUpSlicedEdgesPostprocess_SCENE_RESULTS.txt"
    local report = createFile report_path

    fn check condition message =
    (
        if not condition do throw message
    )

    fn countUniqueVisibleEdges mesh_value =
    (
        local edge_keys = #()
        for face_index = 1 to (getNumFaces mesh_value) do
        (
            local face_vertices = getFace mesh_value face_index
            local vertex_ids = #(face_vertices.x as integer, face_vertices.y as integer, face_vertices.z as integer)
            for face_edge_index = 1 to 3 where getEdgeVis mesh_value face_index face_edge_index do
            (
                local edge_a = vertex_ids[face_edge_index]
                local edge_b = vertex_ids[if face_edge_index == 3 then 1 else face_edge_index + 1]
                local edge_key = ((amin edge_a edge_b) as string) + ":" + ((amax edge_a edge_b) as string)
                if (findItem edge_keys edge_key) == 0 then append edge_keys edge_key
            )
        )
        edge_keys.count
    )

    try
    (
        check (objects.count == 1) "Saved step-4 scene must contain exactly one wall."
        local wall = objects[1]
        check (classOf wall.baseObject == Editable_Poly) "Saved step-4 wall base must be Editable Poly."

        fileIn (root_path + "WallMeshCleaner-6-ASTRA_0.911.ms") quiet:true
        select wall

        local base_vertex_count = polyop.getNumVerts wall.baseObject
        local before_mesh = snapshotAsMesh wall
        local before_vertex_count = getNumVerts before_mesh
        local before_visible_edge_count = countUniqueVisibleEdges before_mesh
        free before_mesh

        check (before_vertex_count > base_vertex_count) "Saved step-4 scene has no generated slice vertices."

        local cleanup_result = WallMeshCleaner.postProcessCleanUpSliceVerts wall
        check cleanup_result[1] ("Postprocess failed: " + WallMeshCleaner.last_slice_report)
        check (cleanup_result[2] > 0) "Postprocess found no generated straight visible-edge candidate."
        check (cleanup_result[3] > 0) "Postprocess removed no redundant generated midpoint."
        check (cleanup_result[2] == cleanup_result[3] + cleanup_result[4].numberSet) "Postprocess candidate accounting is inconsistent."

        local post_modifier = wall.modifiers[1]
        check (post_modifier.name == "CLEAN UP SLICED EDGES POSTPROCESS") "Dedicated postprocess modifier is missing or misnamed."

        for vertex_index = 1 to base_vertex_count do
        (
            check (WallMeshCleaner.doesDebugModifierVertexExist wall post_modifier vertex_index) \
                ("Original base-object vertex was removed: " + (vertex_index as string))
        )

        local after_mesh = snapshotAsMesh wall
        local after_vertex_count = getNumVerts after_mesh
        local after_visible_edge_count = countUniqueVisibleEdges after_mesh
        free after_mesh

        check (after_vertex_count == before_vertex_count - cleanup_result[3]) "Vertex count did not decrease by exactly the removed candidate count."
        check (after_visible_edge_count == before_visible_edge_count - cleanup_result[3]) "Visible topology did not replace each A-R-B pair with one continuous A-B edge."

        format "PASS: removed:% baseVerts:% evaluatedBefore:% evaluatedAfter:% visibleBefore:% visibleAfter:%\n" \
            cleanup_result[3] base_vertex_count before_vertex_count after_vertex_count before_visible_edge_count after_visible_edge_count to:report
        format "ALL TESTS PASSED\n" to:report
    )
    catch
    (
        format "FAIL: %\n" (getCurrentException()) to:report
        try (format "%\n" (getCurrentExceptionStackTrace()) to:report) catch ()
    )

    close report
)
