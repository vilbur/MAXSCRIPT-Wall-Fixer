/* Run in a fresh 3dsmaxbatch process on generated geometry. */
(
    global WallMeshCleaner
    local source_path = (getFilenamePath (getSourceFileName())) + "WallMeshCleaner.ms"
    local source_text = (dotNetClass "System.IO.File").ReadAllText source_path
    execute (substring source_text 1 ((findString source_text "saved_weld_enabled =") - 1))
    fn check condition message = (if not condition do throw message)
    fn hasVertexAt node position_value =
    (
        local found = false
        for v in (polyop.getVertsByFlag node.baseObject 0) do
            if distance (polyop.getVert node.baseObject v) position_value < 0.001 do found = true
        found
    )
    -- Two visible straight edges must win over hidden protected edges and material/SG seams.
    local fan = mesh vertices:#() faces:#()
    convertToPoly fan
    for p in #([0,0,0],[5,0,0],[10,0,0],[10,10,0],[0,10,0]) do polyop.createVert fan p
    polyop.createPolygon fan #(1,2,5)
    polyop.createPolygon fan #(2,4,5)
    polyop.createPolygon fan #(2,3,4)
    local hidden_edges = (polyop.getEdgesUsingVert fan 2) - (polyop.getOpenEdges fan)
    polyop.setEdgeVis fan #all true
    polyop.setEdgeVis fan hidden_edges false
    polyop.setEdgeFlags fan hidden_edges (bit.set 0 25 true) mask:(bit.set 0 25 true)
    for f = 1 to 3 do
    (
        polyop.setFaceMatID fan #{f} f
        polyop.setFaceSmoothGroup fan #{f} f
    )
    check (WallMeshCleaner.isTwoVisibleEdgeStraightVertex fan.baseObject 2) "Hidden topology incorrectly blocked straight visible-edge candidate"
    check (WallMeshCleaner.removeTwoVisibleEdgeStraightVerts fan > 0) "Two-visible-edge vertex was not removed"
    check (not (hasVertexAt fan [5,0,0])) "Two-visible-edge midpoint survived"
    check ((polyop.getNumFaces fan) > 0) "Vertex removal deleted all faces"
    -- Removing an interior midpoint must leave the full visible slice divider.
    local interior = mesh vertices:#() faces:#()
    convertToPoly interior
    for p in #([-10,0,0],[0,-10,0],[10,0,0],[0,10,0],[0,0,0]) do polyop.createVert interior p
    for f in #(#(1,2,5),#(2,3,5),#(3,4,5),#(4,1,5)) do polyop.createPolygon interior f
    local cut_edges = #{}
    cut_edges[WallMeshCleaner.findEdgeBetweenVerts interior.baseObject 1 5] = true
    cut_edges[WallMeshCleaner.findEdgeBetweenVerts interior.baseObject 3 5] = true
    polyop.setEdgeVis interior #all true
    polyop.setEdgeVis interior ((polyop.getEdgesUsingVert interior 5) - cut_edges) false
    polyop.setEdgeFlags interior cut_edges (bit.set 0 25 true) mask:(bit.set 0 25 true)
    check (WallMeshCleaner.removeTwoVisibleEdgeStraightVerts interior == 1) "Interior redundant vertex survived"
    check (not (hasVertexAt interior [0,0,0])) "Interior midpoint survived"
    local divider = polyop.getEdgesByFlag interior (bit.set 0 25 true)
    check (divider.numberSet == 1) "Full slice divider was not restored"
    check (polyop.getEdgeVis interior (divider as array)[1]) "Restored slice divider is hidden"
    check ((polyop.getNumFaces interior) == 2) "Visible slice no longer separates two faces"
    check ((polyop.getFacesUsingEdge interior divider).numberSet == 2) "Restored divider is not an internal edge"
    WallMeshCleaner.cleanupNewSliceEdges interior (bit.set 0 27 true) collect_new:false
    check ((polyop.getNumFaces interior) == 2) "Later cleanup removed the restored slice divider"
    local wall = mesh vertices:#() faces:#()
    convertToPoly wall
    for p in #([0,0,0], [5,0,0], [10,0,0], [10,10,0], [0,10,0]) do polyop.createVert wall p
    polyop.createPolygon wall #(1,2,3,4,5)
    local clean_flag = bit.set 0 25 true
    local edge_index = WallMeshCleaner.findEdgeBetweenVerts wall.baseObject 1 2
    polyop.setEdgeFlags wall.baseObject #{edge_index} clean_flag mask:clean_flag
    check (WallMeshCleaner.removeTwoVisibleEdgeStraightVerts wall == 1) "Mixed clean/dirty straight vertex survived"
    check (not (hasVertexAt wall [5,0,0])) "Straight midpoint survived"
    check ((polyop.getEdgesByFlag wall.baseObject clean_flag).numberSet == 1) "Merged edge lost protection"
    check ((polyop.getNumFaces wall) == 1) "Boundary cleanup damaged face"
    local sliced_wall = mesh vertices:#() faces:#()
    convertToPoly sliced_wall
    for p in #([0,0,0], [10,0,0], [10,10,0], [0,10,0]) do polyop.createVert sliced_wall p
    polyop.createPolygon sliced_wall #(1,2,3)
    polyop.createPolygon sliced_wall #(1,3,4)
    polyop.setFaceMatID sliced_wall #all 1
    polyop.setFaceSmoothGroup sliced_wall #all 1
    local diagonal = WallMeshCleaner.findEdgeBetweenVerts sliced_wall.baseObject 1 3
    polyop.setEdgeVis sliced_wall #{diagonal} false
    check (WallMeshCleaner.sliceWithCleanup sliced_wall (polyop.getFacesByFlag sliced_wall 0) (ray [4,0,0] [1,0,0])) "First slice failed"
    check (not (hasVertexAt sliced_wall [4,4,0])) "Hidden-edge crossing survived first slice"
    check (WallMeshCleaner.sliceWithCleanup sliced_wall (polyop.getFacesByFlag sliced_wall 0) (ray [0,6,0] [0,1,0])) "Second slice failed"
    check (not (hasVertexAt sliced_wall [6,6,0])) "Hidden-edge crossing survived second slice"
    check (hasVertexAt sliced_wall [4,6,0]) "Real perpendicular cut intersection removed"
    check ((polyop.getNumFaces sliced_wall) == 4) "Slice faces damaged"
    format "PASS: per-slice cleanup, clean flag transfer, and real cut intersection preservation\n"
)
