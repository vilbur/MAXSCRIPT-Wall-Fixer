(
    global WallMeshCleaner
    local test_path = getFilenamePath (getSourceFileName())
    local root_path = pathConfig.convertPathToAbsolute (test_path + "..\\")
    local report_path = test_path + "SliceSelectedWalls_RedundantCleanup_DIAGNOSTIC.txt"
    local report = createFile report_path

    fn makeWall =
    (
        local wall = mesh vertices:#() faces:#()
        convertToPoly wall
        for point in #([0,0,0],[12,0,0],[12,0,10],[0,0,10],[4,0,3],[8,0,3],[8,0,7],[4,0,7],[6,0,0],[6,0,10]) do polyop.createVert wall point
        for face in #(#(1,9,2,6,5),#(2,3,7,6),#(3,10,4,8,7),#(4,1,5,8)) do polyop.createPolygon wall face
        polyop.setFaceSmoothGroup wall #all 1
        polyop.setEdgeVis wall ((polyop.getEdgesUsingFace wall #all) - (polyop.getOpenEdges wall)) false
        wall
    )

    try
    (
        resetMaxFile #noPrompt
        local source_text = (dotNetClass "System.IO.File").ReadAllText (root_path + "WallMeshCleaner-6-ASTRA_0.70.ms")
        execute (substring source_text 1 ((findString source_text "saved_weld_enabled =") - 1))

        importFile @"D:\Downloads\_AI\GPT\verts-to-remove.obj" #noPrompt
        if objects.count != 1 then throw "verts-to-remove.obj did not create exactly one wall."
        local wall = objects[1]
        convertToPoly wall
        wall.name = "automatic-cleanup-wall"
        select wall

        local sliced = WallMeshCleaner.debugSliceSelectedWalls cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1000.0
        format "AUTO result:% report:% modifiers:%\n" sliced WallMeshCleaner.last_slice_report wall.modifiers.count to:report
        for modifier_index = 1 to wall.modifiers.count do format "AUTO modifier[%]: %\n" modifier_index wall.modifiers[modifier_index].name to:report

        local topology_modifier = WallMeshCleaner.getDebugTopologyModifier wall
        local pending_cleanup = WallMeshCleaner.getDebugSlicedEdgeCleanupCandidates wall topology_modifier
        if pending_cleanup == undefined then
            format "AUTO pending sliced-edge cleanup: undefined\n" to:report
        else
            format "AUTO pending sliced-edge cleanup: remove:% keep:% new:%\n" pending_cleanup[1] pending_cleanup[2] pending_cleanup[3] to:report

        local sliced_cleanup_result = WallMeshCleaner.debugCleanUpSlicedEdges()
        format "SLICED EDGE MANUAL result:% report:%\n" sliced_cleanup_result WallMeshCleaner.last_slice_report to:report

        local manual_result = WallMeshCleaner.cleanupRedundantLoopsOnNode wall angle_threshold:0.1 debug_output:true
        format "MANUAL result:% modifiers:%\n" manual_result wall.modifiers.count to:report
        for modifier_index = 1 to wall.modifiers.count do format "FINAL modifier[%]: %\n" modifier_index wall.modifiers[modifier_index].name to:report
    )
    catch
    (
        format "FAIL: %\n" (getCurrentException()) to:report
        try(format "%\n" (getCurrentExceptionStackTrace()) to:report)catch()
    )
    close report
)
