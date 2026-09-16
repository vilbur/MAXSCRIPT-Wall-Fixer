(
    global WallMeshCleaner
    local root_path = @"D:\GoogleDrive\ProgramsData\CG\3DsMax\AppData\scripts\MAXSCRIPT-Wall-Mesh-Cleaner\"
    local report_path = root_path + "tests\CleanUpSlicedEdges_068_RESULTS.txt"
    local report = createFile report_path

    fn check condition message =
    (
        if not condition do throw message
    )

    try
    (
        resetMaxFile #noPrompt
        fileIn (root_path + "WallMeshCleaner-6-ASTRA_0.68.ms") quiet:true
        importFile @"D:\Downloads\_AI\GPT\verts-to-remove.obj" #noPrompt
        check (objects.count == 1) "OBJ import did not create exactly one wall object."

        local wall = objects[1]
        convertToPoly wall
        select wall
        local base_vertex_count = polyop.getNumVerts wall.baseObject
        local protected_positions = for vertex_index = 1 to base_vertex_count collect polyop.getVert wall.baseObject vertex_index

        check (WallMeshCleaner.debugCheckSelection angle_threshold:5.0 planar_tolerance:1000.0) ("Reset Slicing failed: " + (WallMeshCleaner.last_slice_error as string))

        local cleanup_data = undefined
        local removable_edges = #{}
        local removable_vertices = #{}
        local edge_descriptors = #()
        local candidate_positions = #()
        local modifier = undefined

        for attempt = 1 to 12 while removable_vertices.numberSet == 0 do
        (
            check (WallMeshCleaner.debugMakeOneSlice cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1000.0) ("Make 1 Slice failed: " + (WallMeshCleaner.last_slice_error as string))
            modifier = WallMeshCleaner.getDebugTopologyModifier wall
            cleanup_data = WallMeshCleaner.getDebugSlicedEdgeCleanupCandidates wall modifier
            if cleanup_data != undefined then
            (
                removable_edges = cleanup_data[1]
                local vertex_data = WallMeshCleaner.getDebugPredictedSlicedEdgeRemovalVertices wall modifier removable_edges base_vertex_count
                removable_vertices = vertex_data[1]
            )
        )

        check (modifier != undefined) "Make 1 Slice did not create an Edit Poly modifier."
        check (removable_edges.numberSet > 0) "No redundant sliced-edge candidate was produced."
        check (removable_vertices.numberSet > 0) "No cleanup-vertex candidate was produced."

        for edge_index in removable_edges do
        (
            local edge_a = modifier.GetEdgeVertex edge_index 1 node:wall
            local edge_b = modifier.GetEdgeVertex edge_index 2 node:wall
            append edge_descriptors #(edge_index, modifier.GetVertex edge_a node:wall, modifier.GetVertex edge_b node:wall)
        )
        for vertex_index in removable_vertices do append candidate_positions #(vertex_index, modifier.GetVertex vertex_index node:wall)

        check (WallMeshCleaner.debugCleanUpSlicedEdges()) ("Clean Up Sliced Edges failed: " + WallMeshCleaner.last_slice_report)

        for edge_data in edge_descriptors do
        (
            check (not (WallMeshCleaner.doesDebugVisibleEdgeExistByEndpointPositions wall edge_data[2] edge_data[3] tolerance:0.01)) ("Redundant visible edge survived: " + (edge_data[1] as string))
        )
        for candidate_data in candidate_positions do
        (
            check ((WallMeshCleaner.findDebugSliceVertexByPosition wall modifier candidate_data[2] base_vertex_count tolerance:0.01) == 0) ("Cleanup vertex survived: " + (candidate_data[1] as string))
        )
        for protected_position in protected_positions do
        (
            check ((WallMeshCleaner.findDebugLiveVertexByPosition wall modifier protected_position tolerance:0.01) > 0) ("Original base vertex position was removed: " + (protected_position as string))
        )

        format "PASS: redundant visible edges removed before all confirmed cleanup vertices; base vertices preserved.\n" to:report
    )
    catch
    (
        format "FAIL: %\n" (getCurrentException()) to:report
        try (format "%\n" (getCurrentExceptionStackTrace()) to:report) catch ()
    )
    close report
)