/* Run in a fresh 3dsmaxbatch process. */
(
    global WallMeshCleaner
    local root_path = getFilenamePath (getSourceFileName())
    fileIn (root_path + "SliceCleanup_TEST.ms")
    fn check condition message = (if not condition do throw message)
    fn makePoly points faces =
    (
        local obj = mesh vertices:#() faces:#()
        convertToPoly obj
        for p in points do polyop.createVert obj p
        for f in faces do polyop.createPolygon obj f
        obj
    )
    local mm = units.decodeValue "1mm"
    -- A tiny bent edge must collapse onto the original corner, not its midpoint.
    local obj = makePoly (for p in #([0,0,0],[10,0,0],[10.003,0.004,0],[10,10,0],[0,10,0]) collect p*mm) #(#(1,2,3,4,5))
    local result = WallMeshCleaner.preprocessSliceNode obj
    check (result[2] == 1) "Near-duplicate pair was not target welded"
    check ((polyop.getVertsByFlag obj 0).numberSet == 4) "Wrong vertex count after preprocessing"
    check ((polyop.getNumFaces obj) == 1) "Target weld damaged the polygon"
    local preserved = false
    for v in (polyop.getVertsByFlag obj 0) do
        if distance (polyop.getVert obj v) ([10,0,0]*mm) < mm*0.00001 do preserved = true
    check preserved "Corner position moved"
    -- A straight boundary T-vertex survives step one, but must yield to a nearby corner.
    local corner_test = makePoly (for p in #([0,0,0],[5,0,0],[10,0,0],[10,10,0],[5,10,0],[0,10,0],[5,-0.005,0],[6,-2,0],[4,-2,0]) collect p*mm) #(#(1,2,5,6),#(2,3,4,5),#(7,9,8))
    check ((WallMeshCleaner.preSliceCornerRank corner_test 7 (mm*0.01)) > (WallMeshCleaner.preSliceCornerRank corner_test 2 (mm*0.01))) "Corner was not preferred over edge vertex"
    result = WallMeshCleaner.preprocessSliceNode corner_test
    check (result[2] == 1) "Disconnected border pair did not weld"
    preserved = false
    for v in (polyop.getVertsByFlag corner_test 0) do
        if distance (polyop.getVert corner_test v) ([5,-0.005,0]*mm) < mm*0.00001 do preserved = true
    check preserved "Higher-index corner position was not retained"
    -- The same local separation exceeds tolerance after object scaling.
    local scaled = makePoly (for p in #([0,0,0],[10,0,0],[10.003,0.004,0],[10,10,0],[0,10,0]) collect p*mm) #(#(1,2,3,4,5))
    scaled.scale = [10,10,10]
    result = WallMeshCleaner.preprocessSliceNode scaled
    check (result[2] == 0) "Weld tolerance ignored object scale"
    -- Native OBJ importer retains the supplied source polygons and hole topology.
    for test_case in #(#("vertical",#vertical), #("all",#all)) do
    (
        local before = objects as array
        importFile (root_path + "test/objects/test_wall-complex/test_wall-complex-slice-" + test_case[1] + ".obj") #noPrompt
        local sources = for obj in objects where ((findItem before obj) == 0 and matchPattern obj.name pattern:"*source*") collect obj
        check (sources.count > 0) "OBJ source object was not imported"
        for source in sources do
        (
            convertToPoly source
            select source
            check (WallMeshCleaner.sliceSelection cut_mode:test_case[2]) "Example slicing failed"
            check ((polyop.getNumFaces source) > 0) "Example lost all faces"
            check ((polyop.getOpenEdges source).numberSet > 0) "Example lost its open boundary"
        )
    )
    format "PASS: preprocessing, target preservation, scaled tolerance, and both complex OBJ sources\n"
)
