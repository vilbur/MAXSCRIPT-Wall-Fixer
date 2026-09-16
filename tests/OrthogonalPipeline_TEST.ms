/* Run in a fresh 3dsmaxbatch process, or a disposable Max scene.
   Geometry assertions inspect evaluated Edit Poly topology, never just Slice's return value. */
(
    global WMCWallSlicePipeline
    local rootPath = getFilenamePath(getSourceFileName())
    local report = createFile (rootPath + "test/pipeline-native-results.txt")
    fn check condition message = (if not condition do throw message)
    fn saveObj points faces path =
    (
        local stream = createFile path
        format "# Native Wall Mesh Cleaner regression topology\n" to:stream
        for p in points do format "v % % %\n" p.x p.y p.z to:stream
        for face in faces do
        (
            format "f" to:stream
            for v in face do format " %" v to:stream
            format "\n" to:stream
        )
        close stream
    )
    fn makeWall angleValue existingModifier:false baked:false door:false meshBase:false scaleValue:[1,1,1] =
    (
        local wall = mesh vertices:#() faces:#()
        convertToPoly wall
        local points = #([0,0,0],[12,0,0],[12,0,10],[0,0,10],[4,0,3],[8,0,3],[8,0,7],[4,0,7],[6,0,0],[6,0,10])
        if door do join points #([1,0,0],[1,0,2],[3,0,2],[3,0,0],[0,0,3])
        local rotationTM = rotateZMatrix angleValue
        for p in points do polyop.createVert wall (if baked then p*rotationTM else p)
        local bottom = if door then #(1,11,12,13,14,9,2,6,5,15) else #(1,9,2,6,5)
        for face in #(bottom,#(2,3,7,6),#(3,10,4,8,7),(if door then #(4,15,5,8) else #(4,1,5,8))) do polyop.createPolygon wall face
        polyop.setFaceMatID wall #all 3
        polyop.setFaceSmoothGroup wall #all 1
        polyop.setEdgeVis wall ((polyop.getEdgesUsingFace wall #all)-(polyop.getOpenEdges wall)) false
        if not baked do wall.rotation = quat angleValue [0,0,1]
        wall.scale = scaleValue
        if meshBase do convertToMesh wall
        if existingModifier do addModifier wall (Edit_Poly())
        wall
    )
    try
    (
        global WallMeshCleaner
        local text = (dotNetClass "System.IO.File").ReadAllText (rootPath + "WallMeshCleaner.ms")
        execute (substring text 1 ((findString text "saved_weld_enabled =")-1))
        format "COMPILED\n" to:report
        flush report
        for config in #(#(0,false,false,false,false,[1,1,1]),#(37,false,false,false,false,[1,1,1]),#(91,true,false,false,false,[1,1,1]),#(37,true,true,false,false,[1,1,1]),#(37,false,false,true,false,[2,1,0.5]),#(37,true,false,false,true,[1,1,1])) do
        (
            local wall = makeWall config[1] existingModifier:config[2] baked:config[3] door:config[4] meshBase:config[5] scaleValue:config[6]
            local expectedV = if config[4] then 30 else 16
            local expectedE = if config[4] then 48 else 24
            local expectedF = if config[4] then 18 else 8

            if config[1] == 0 do
            (
                local exportPoints = #()
                local exportFaces = #()
                for v=1 to (polyop.getNumVerts wall.baseObject) do append exportPoints (polyop.getVert wall.baseObject v)
                for f=1 to (polyop.getNumFaces wall.baseObject) do append exportFaces (polyop.getFaceVerts wall.baseObject f)
                saveObj exportPoints exportFaces (rootPath + "test/pipeline-window-before.obj")
            )
            local sourceMesh = snapshotAsMesh wall
            local sourcePoints = for v=1 to sourceMesh.numverts collect getVert sourceMesh v
            local sourceFaces = sourceMesh.numfaces
            select wall
            check (WallMeshCleaner.sliceSelection()) ("Pipeline returned failure: " + (WallMeshCleaner.last_slice_error as string))
            check (wall.modifiers.count == 1) "Expected one Edit Poly modifier."
            local ep = wall.modifiers[1]
            select wall
            max modify mode
            modPanel.setCurrentObject ep
            ep.SetPrimaryNode wall
            local inspector = WMCWallSlicePipeline node:wall ep:ep
            local t = inspector.refreshTopology()
            inspector.tolerance = units.decodeValue "0.001mm"
            inspector.setFrame t
            inspector.validateStructure t
            check (t.faces.count == expectedF) "Window wall must contain eight rectangular regions."
            check (t.points.count == expectedV) "Wrong vertex count: redundant vertices or missing intersections."
            check (t.edges.count == expectedE) "Wrong edge count."
            check (t.border.numberSet == (if config[4] then 24 else 16)) "Outer/opening boundary edge count changed."
            for f in t.faces do check (f.count == 4) "Non-quad region remains."
            for e=1 to t.edges.count do check (inspector.edgeKind t e != #diagonal) "Internal diagonal remains."
            if config[1] == 0 do saveObj t.points t.faces (rootPath + "test/pipeline-window-after.obj")
            if config[4] do saveObj t.points t.faces (rootPath + "test/pipeline-door-after.obj")
            local baseProbe = copy wall
            while baseProbe.modifiers.count > 0 do deleteModifier baseProbe 1
            local baseMesh = snapshotAsMesh baseProbe
            delete baseProbe
            check (baseMesh.numverts == sourcePoints.count and baseMesh.numfaces == sourceFaces) "Base topology changed."
            for v=1 to sourcePoints.count do check ((getVert baseMesh v) == sourcePoints[v]) "Base geometry changed."
            free baseMesh
            free sourceMesh
            -- Idempotence: the second run must retain both orthogonal passes.
            check (WallMeshCleaner.propagateSelectionJunctionCuts()) "Fix N-gons returned failure."
            ep = wall.modifiers[1]
            modPanel.setCurrentObject ep
            inspector.ep = ep
            t = inspector.refreshTopology()
            check (t.faces.count == expectedF and t.points.count == expectedV and t.edges.count == expectedE) "Second run changed clean topology."
            format "PASS rotation:% existing Edit Poly:% baked:% door:% mesh base:% | V:% E:% F:% | base unchanged\n" config[1] config[2] config[3] config[4] config[5] expectedV expectedE expectedF to:report
            flush report
        )
        -- A genuine sloping outer boundary is geometry, not disposable triangulation.
        local sloped = makeWall 23
        polyop.setVert sloped.baseObject 3 [13,0,10]
        select sloped
        check (WallMeshCleaner.sliceSelection()) ("Sloping boundary failed: " + (WallMeshCleaner.last_slice_error as string))
        format "PASS genuine sloping boundary preserved\n" to:report
        flush report

        -- Material seams must prevent dissolution even when the diagonal is geometrically flat.
        local seam = mesh vertices:#() faces:#()
        convertToPoly seam
        for p in #([0,0,0],[10,0,0],[10,0,10],[0,0,10]) do polyop.createVert seam p
        polyop.createPolygon seam #(1,2,3)
        polyop.createPolygon seam #(1,3,4)
        polyop.setFaceMatID seam #{1} 1
        polyop.setFaceMatID seam #{2} 2
        select seam
        check (WallMeshCleaner.sliceSelection()) "Material seam processing failed."
        max modify mode
        modPanel.setCurrentObject seam.modifiers[1]
        seam.modifiers[1].SetPrimaryNode seam
        local seamInspector = WMCWallSlicePipeline node:seam ep:seam.modifiers[1]
        local seamTopology = seamInspector.refreshTopology()
        check (seamTopology.faces.count == 2 and seamTopology.edges.count == 5) "Required material seam was dissolved."
        format "PASS required material diagonal retained\n" to:report
        flush report

        -- Failures restore both a newly added modifier and an existing modifier stack.
        for existing in #(false,true) do
        (
            local invalid = makeWall 0 existingModifier:existing
            polyop.setVert invalid.baseObject 3 [12,1,10]
            local originalCount = invalid.modifiers.count
            select invalid
            check (not(WallMeshCleaner.sliceSelection())) "Nonplanar geometry should be rejected."
            check (invalid.modifiers.count == originalCount) "Failure did not restore modifier stack."
            check ((polyop.getVert invalid.baseObject 3) == [12,1,10]) "Failure changed the base object."
        )
        format "PASS nonplanar rejection and modifier rollback\n" to:report
        flush report
        for mode in #(#vertical,#horizontal) do
        (
            local modeWall = makeWall 37
            select modeWall
            check (WallMeshCleaner.sliceSelection cut_mode:mode) "Single-direction pass failed."
            max modify mode
            modPanel.setCurrentObject modeWall.modifiers[1]
            modeWall.modifiers[1].SetPrimaryNode modeWall
            local inspector = WMCWallSlicePipeline node:modeWall ep:modeWall.modifiers[1]
            local t = inspector.refreshTopology()
            inspector.tolerance = units.decodeValue "0.001mm"
            inspector.setFrame t
            check (t.points.count == 12 and t.edges.count == 16 and t.faces.count == 4) "Single-pass topology counts differ."
            for e=1 to t.edges.count where not t.border[e] do
                check (inspector.edgeKind t e == mode) "Single pass created an edge in the other direction."
            format "PASS % only: four regions, no opposite-direction cuts\n" mode to:report
            flush report
        )
        for withModifier in #(false,true) do
        (
            local sharedWall = makeWall 37 existingModifier:withModifier
            local otherInstance = instance sharedWall
            local modifierCount = otherInstance.modifiers.count
            local originalModifier = if withModifier then otherInstance.modifiers[1] else undefined
            local originalMesh = snapshotAsMesh otherInstance
            select sharedWall
            check (WallMeshCleaner.sliceSelection()) "Shared stack processing failed."
            check (otherInstance.modifiers.count == modifierCount) "Changed an unselected instance's modifiers."
            if withModifier do check (otherInstance.modifiers[1] == originalModifier) "Changed an unselected modifier reference."
            local otherMesh = snapshotAsMesh otherInstance
            check (otherMesh.numverts == originalMesh.numverts and otherMesh.numfaces == originalMesh.numfaces) "Changed an unselected instance's topology."
            for v=1 to otherMesh.numverts do check ((getVert otherMesh v) == (getVert originalMesh v)) "Moved an unselected instance vertex."
            free originalMesh
            free otherMesh
            format "PASS unselected instance preserved (existing modifier:%)\n" withModifier to:report
            flush report
        )
        format "ALL TESTS PASSED\n" to:report
    )
    catch (format "FAIL: %\n" (getCurrentException()) to:report; try (format "%\n" (getCurrentExceptionStackTrace()) to:report) catch ())
    close report
)
