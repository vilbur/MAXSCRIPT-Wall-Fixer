/*
Run in a fresh 3dsmaxbatch process or a disposable Max scene.

Regression protected here:
- a straight coplanar internal divider spanning straight border segments must be dissolved;
- an otherwise flat divider that terminates at a border corner must remain untouched.
*/
(
    global WallMeshCleaner

    local test_directory = dotNetObject "System.IO.DirectoryInfo" (getFilenamePath (getSourceFileName()))
    local root_path = test_directory.Parent.FullName + "\\"
    local report_path = root_path + "tests\\RedundantLoopCleanup_RESULTS.txt"
    local report = createFile report_path

    fn check condition message =
    (
        if not condition do throw message
    )

    fn makeStraightDividerWall =
    (
        local wall = mesh name:"WMC_RedundantLoop_Positive" vertices:#() faces:#()
        convertToPoly wall

        for point_value in #(
            [0,0,0], [10,0,0], [10,0,10], [0,0,10],
            [5,0,0], [5,0,10]
        ) do polyop.createVert wall point_value

        polyop.createPolygon wall #(1,5,6,4)
        polyop.createPolygon wall #(5,2,3,6)
        polyop.setFaceMatID wall #all 1
        update wall
        wall
    )

    fn makeCornerDividerWall =
    (
        local wall = mesh name:"WMC_RedundantLoop_Corner" vertices:#() faces:#()
        convertToPoly wall

        for point_value in #(
            [0,0,0], [10,0,0], [10,0,10], [0,0,10]
        ) do polyop.createVert wall point_value

        polyop.createPolygon wall #(1,2,3)
        polyop.createPolygon wall #(1,3,4)
        polyop.setFaceMatID wall #all 1
        update wall
        wall
    )

    try
    (
        resetMaxFile #noPrompt

        local source_text = (dotNetClass "System.IO.File").ReadAllText (root_path + "WallMeshCleaner.ms")
        execute (substring source_text 1 ((findString source_text "saved_weld_enabled =") - 1))

        for with_existing_modifier in #(false, true) do
        (
            local removable_wall = makeStraightDividerWall()
            if with_existing_modifier do addModifier removable_wall (Edit_Poly name:"Existing Edit Poly")
            local original_modifier_count = removable_wall.modifiers.count
            select removable_wall

            check (WallMeshCleaner.cleanupRedundantLoops()) "Straight planar border-to-border divider was not processed."
            check (removable_wall.modifiers.count == original_modifier_count + 2) "Expected exactly FIND and DELETE Edit Poly modifiers above the existing stack."
            check (removable_wall.modifiers[2].name == "FIND REDUNDANT LOOPS") "Lower inspection modifier is missing or misnamed."
            check (removable_wall.modifiers[1].name == "DELETE REDUNDANT LOOPS") "Upper removal modifier is missing or misnamed."

            local find_modifier = removable_wall.modifiers[2]
            local delete_modifier = removable_wall.modifiers[1]
            delete_modifier.enabled = false
            update removable_wall
            select removable_wall
            max modify mode
            modPanel.setCurrentObject find_modifier
            find_modifier.SetPrimaryNode removable_wall
            check ((find_modifier.GetSelection #Edge node:removable_wall).numberSet == 1) "FIND REDUNDANT LOOPS did not retain the detected edge selection."

            delete_modifier.enabled = true
            update removable_wall
            modPanel.setCurrentObject delete_modifier
            delete_modifier.SetPrimaryNode removable_wall
            local live_face_count = 0
            local live_border_edge_count = 0

            for face_index = 1 to delete_modifier.GetNumFaces node:removable_wall do
            (
                local face_degree = delete_modifier.GetFaceDegree face_index node:removable_wall
                if (face_degree != undefined) and (face_degree >= 3) do live_face_count += 1
            )

            for edge_index = 1 to delete_modifier.GetNumEdges node:removable_wall do
            (
                local edge_a = delete_modifier.GetEdgeVertex edge_index 1 node:removable_wall
                local edge_b = delete_modifier.GetEdgeVertex edge_index 2 node:removable_wall
                local face_a = delete_modifier.GetEdgeFace edge_index 1 node:removable_wall
                local face_b = delete_modifier.GetEdgeFace edge_index 2 node:removable_wall

                if (edge_a != undefined) and (edge_b != undefined) and (face_a != undefined) and (face_b != undefined) do
                (
                    if (face_a == 0) != (face_b == 0) do live_border_edge_count += 1
                )
            )

            check (live_face_count == 1) ("RemoveEdge must merge the two coplanar polygons instead of deleting either surface; live faces: " + (live_face_count as string))
            check (live_border_edge_count == 6) ("RemoveEdge changed the wall border or created a hole; live border edges: " + (live_border_edge_count as string))

            format "PASS: straight planar border-to-border redundant loop found and dissolved (existing Edit Poly:%).\n" with_existing_modifier to:report
            flush report
        )

        local automatic_wall = makeStraightDividerWall()
        select automatic_wall

        check (WallMeshCleaner.sliceSelection()) "Slice Selected Walls failed on the automatic-cleanup fixture."
        check (automatic_wall.modifiers.count == 3) "Slice Selected Walls did not add its cleanup modifier plus FIND and DELETE redundant-loop modifiers."
        check (automatic_wall.modifiers[2].name == "FIND REDUNDANT LOOPS") "Slice Selected Walls did not preserve the automatic redundant-loop inspection selection."
        check (automatic_wall.modifiers[1].name == "DELETE REDUNDANT LOOPS") "Slice Selected Walls did not execute automatic redundant-loop removal."

        format "PASS: Slice Selected Walls automatically ran redundant-loop cleanup after slicing.\n" to:report
        flush report

        local corner_wall = makeCornerDividerWall()
        select corner_wall

        check (not WallMeshCleaner.cleanupRedundantLoops()) "Corner-ending divider must be rejected."
        check (corner_wall.modifiers.count == 0) "Rejected corner-ending divider must add no modifiers."

        format "PASS: divider ending at a corner vertex preserved with no modifiers.\n" to:report
        format "ALL TESTS PASSED\n" to:report
    )
    catch
    (
        format "FAIL: %\n" (getCurrentException()) to:report
        try (format "%\n" (getCurrentExceptionStackTrace()) to:report) catch ()
    )

    close report
)
