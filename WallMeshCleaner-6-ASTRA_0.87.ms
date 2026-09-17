/*
WallMeshCleaner 6-ASTRA 0.85
Native Edit Poly slicing: conservative collinear cleanup, preserved boundary
corner anchors, wall-plane vertical pass, horizontal pass, safe original-diagonal
removal, final collinear cleanup and geometric/topological validation.

Slice and Fix N-gons use the same pipeline. No welding, material-ID tracking,
per-cut dissolving or base-object writes occur in these actions.
Regression: OrthogonalPipeline_TEST.ms. See README.md for supported scope.
*/

try
(
    destroyDialog WallMeshCleanerRollout
)
catch
(
)

global WMCWallTopology
global WMCWallSlicePipeline
global WallMeshCleaner_v
global WallMeshCleaner
global WallMeshCleanerRollout
global WallMeshCleanerOptionsRollout
global WallMeshCleanerFaceSlicerRollout
global WallMeshCleanerFaceCleanerRollout
global WallMeshCleanerVertexCleanerRollout
global WallMeshCleanerScriptPath

WallMeshCleanerScriptPath = getSourceFileName()

/* Native Edit Poly pipeline. All persistent topology references are positions.
   A topology snapshot is valid only until the next Commit. */
struct WMCWallTopology (points, validVertices, faces, validFaces, edges, validEdges, faceEdges, vertexEdges, border, materials, smoothing)
struct WMCWallSlicePipeline
(
    node, ep, origin, normal, horizontal, vertical, referenceWorld = undefined,
    tolerance = 0.0001, planarTolerance = 1.0, angularTolerance = 0.1, axisTolerance = 0.1,
    corners = #(), anchors = #(), originalBorder = #(), originalDiagonals = #(),
    protectedSegments = #(), baseline, cuts = 0, removedEdges = 0, removedVerts = 0,

    fn refreshTopology =
    (
        update node
        -- Force evaluation; Edit Poly otherwise returns zero counts after Commit.
        local evaluated = snapshotAsMesh node
        free evaluated
        local t = WMCWallTopology points:#() validVertices:#{} faces:#() validFaces:#{} edges:#() validEdges:#{} faceEdges:#() vertexEdges:#() border:#{} materials:#() smoothing:#()

        /*
        Edit Poly can keep dead sub-object slots after topology operations.
        Indexed interface calls return undefined for those slots, so keep only live
        Point3 values and explicitly track live vertices, edges and faces.
        */
        local vertex_count = ep.GetNumVertices node:node
        if referenceWorld == undefined and vertex_count > 0 then
        (
            for v = 1 to vertex_count do
            (
                if referenceWorld == undefined then
                (
                    local reference_point = ep.GetVertex v node:node
                    if reference_point != undefined then referenceWorld = reference_point
                )
            )
        )
        if referenceWorld == undefined and vertex_count > 0 then throw "Edit Poly has no valid vertex positions."

        for v = 1 to vertex_count do
        (
            local vertex_point = ep.GetVertex v node:node
            if vertex_point != undefined then
            (
                append t.points (vertex_point - referenceWorld)
                t.validVertices[v] = true
            )
            else
            (
                /* Placeholder preserves Edit Poly IDs; dead slots are never used. */
                append t.points [0,0,0]
            )
            append t.vertexEdges #{}
        )

        local edge_count = ep.GetNumEdges node:node
        for e = 1 to edge_count do
        (
            local a = ep.GetEdgeVertex e 1 node:node
            local b = ep.GetEdgeVertex e 2 node:node
            local f = ep.GetEdgeFace e 1 node:node
            local g = ep.GetEdgeFace e 2 node:node
            local edge_valid = true

            if a == undefined or b == undefined or f == undefined or g == undefined then edge_valid = false
            if edge_valid then
            (
                if a < 1 or b < 1 or a > vertex_count or b > vertex_count then edge_valid = false
            )
            if edge_valid then
            (
                if not t.validVertices[a] or not t.validVertices[b] then edge_valid = false
            )

            if edge_valid then
            (
                append t.edges #(a,b,f,g)
                t.validEdges[e] = true
                t.vertexEdges[a][e] = true
                t.vertexEdges[b][e] = true
            )
            else
            (
                append t.edges #(0,0,0,0)
            )
        )

        local face_count = ep.GetNumFaces node:node
        for f = 1 to face_count do
        (
            local vs = #()
            local es = #{}
            local degree = ep.GetFaceDegree f node:node
            local face_valid = true

            if degree == undefined then
            (
                face_valid = false
            )
            else if degree < 3 then
            (
                face_valid = false
            )

            if face_valid then
            (
                for k = 1 to degree while face_valid do
                (
                    local face_vertex = ep.GetFaceVertex f k node:node
                    local face_edge = ep.GetFaceEdge f k node:node
                    if face_vertex == undefined or face_edge == undefined then
                    (
                        face_valid = false
                    )
                    else if face_vertex < 1 or face_vertex > vertex_count or face_edge < 1 or face_edge > edge_count then
                    (
                        face_valid = false
                    )
                    else if not t.validVertices[face_vertex] or not t.validEdges[face_edge] then
                    (
                        face_valid = false
                    )
                    else
                    (
                        append vs face_vertex
                        es[face_edge] = true
                    )
                )
            )

            if face_valid then
            (
                append t.faces vs
                append t.faceEdges es
                t.validFaces[f] = true
                local face_material = ep.GetFaceMaterial f node:node
                local face_smoothing = ep.GetFaceSmoothingGroups f node:node
                append t.materials (if face_material == undefined then 0 else face_material)
                append t.smoothing (if face_smoothing == undefined then 0 else face_smoothing)
            )
            else
            (
                append t.faces #()
                append t.faceEdges #{}
                append t.materials 0
                append t.smoothing 0
            )
        )

        /* Normalize edge face references against live faces and discard dead edges. */
        t.border = #{}
        for e in t.validEdges do
        (
            local rec = t.edges[e]
            local f = rec[3]
            local g = rec[4]
            local live_f = 0
            local live_g = 0
            if f != undefined then
            (
                if f > 0 and f <= face_count then if t.validFaces[f] then live_f = f
            )
            if g != undefined then
            (
                if g > 0 and g <= face_count then if t.validFaces[g] then live_g = g
            )

            if live_f == 0 and live_g == 0 then
            (
                t.validEdges[e] = false
                t.vertexEdges[rec[1]][e] = false
                t.vertexEdges[rec[2]][e] = false
                t.edges[e] = #(0,0,0,0)
            )
            else
            (
                t.edges[e] = #(rec[1],rec[2],live_f,live_g)
                if (live_f == 0) != (live_g == 0) then t.border[e] = true
            )
        )

        if vertex_count != t.validVertices.numberSet or edge_count != t.validEdges.numberSet or face_count != t.validFaces.numberSet then
        (
            format "WallMeshCleaner Topology Snapshot: raw verts/edges/faces:%/%/% live:%/%/% dead:%/%/%\n" \
                vertex_count edge_count face_count \
                t.validVertices.numberSet t.validEdges.numberSet t.validFaces.numberSet \
                (vertex_count - t.validVertices.numberSet) (edge_count - t.validEdges.numberSet) (face_count - t.validFaces.numberSet)
        )
        if t.validVertices.numberSet == 0 then throw "Edit Poly has no live vertices."
        if t.validEdges.numberSet == 0 then throw "Edit Poly has no live edges."
        if t.validFaces.numberSet == 0 then throw "Edit Poly has no live faces."
        t
    ),
    fn faceVector t f =
    (
        if f < 1 or f > t.faces.count or not t.validFaces[f] then return [0,0,0]
        local vs = t.faces[f]
        if vs.count < 3 then return [0,0,0]
        local result = [0,0,0]
        local p = t.points[vs[1]]
        for k = 1 to vs.count do
        (
            local j = if k == vs.count then 1 else k+1
            result += cross (t.points[vs[k]]-p) (t.points[vs[j]]-p)
        )
        result * 0.5
    ),
    fn segment t e = #(t.points[t.edges[e][1]], t.points[t.edges[e][2]]),
    fn edgeKind t e =
    (
        local s = segment t e
        local d = s[2]-s[1]
        if length d <= tolerance then #degenerate
        else
        (
            d = normalize d
            if abs(dot d horizontal) >= cos axisTolerance then #horizontal
            else if abs(dot d vertical) >= cos axisTolerance then #vertical
            else #diagonal
        )
    ),
    fn onSegment p a b =
    (
        local d = b-a
        local len = length d
        if len <= tolerance then distance p a <= tolerance
        else
        (
            local along = dot (p-a) (d/len)
            along >= -tolerance and along <= len+tolerance and
                length ((p-a)-(d/len)*along) <= tolerance
        )
    ),
    fn covered s segments =
    (
        local d = s[2]-s[1]
        local len = length d
        if len <= tolerance then return false
        d /= len
        local intervals = #()
        for other in segments do
        (
            local a = dot (other[1]-s[1]) d
            local b = dot (other[2]-s[1]) d
            if length ((other[1]-s[1])-d*a) <= tolerance and length ((other[2]-s[1])-d*b) <= tolerance do
                append intervals #(amin a b, amax a b)
        )
        fn compareIntervals a b = (if a[1] < b[1] then -1 else if a[1] > b[1] then 1 else 0)
        qsort intervals compareIntervals
        local reach = 0.0
        for interval in intervals do
            if interval[1] <= reach+tolerance and interval[2] >= -tolerance do reach = amax reach interval[2]
        reach >= len-tolerance
    ),
    /*
    Returns a precision-aware tolerance used only when validating preserved geometry.
    Large world coordinates lose sub-unit precision in Edit Poly world-space vertex queries.
    */
    function getBoundaryValidationTolerance =
    (
        local world_scale = 0.0
        if referenceWorld != undefined then
        (
            world_scale = amax (abs referenceWorld.x) (abs referenceWorld.y)
            world_scale = amax world_scale (abs referenceWorld.z)
        )
        amax tolerance (world_scale * 0.000001)
        -- return
    ),
    /*
    Tests whether a segment is fully represented by collinear result segments.
    Uses an explicit validation tolerance without changing slice/intersection tolerance.
    */
    function coveredAtTolerance s segments match_tolerance =
    (
        local d = s[2]-s[1]
        local len = length d
        if len <= match_tolerance then return false
        d /= len
        local intervals = #()
        for other in segments do
        (
            local a = dot (other[1]-s[1]) d
            local b = dot (other[2]-s[1]) d
            if length ((other[1]-s[1])-d*a) <= match_tolerance and length ((other[2]-s[1])-d*b) <= match_tolerance then
            (
                append intervals #(amin a b, amax a b)
            )
        )
        function compareValidationIntervals a b =
        (
            if a[1] < b[1] then -1 else if a[1] > b[1] then 1 else 0
            -- return
        )
        qsort intervals compareValidationIntervals
        local reach = 0.0
        for interval in intervals do
        (
            if interval[1] <= reach+match_tolerance and interval[2] >= -match_tolerance then
            (
                reach = amax reach interval[2]
            )
        )
        reach >= len-match_tolerance
        -- return
    ),
    fn hasPoint t p =
    (
        for vertex_index in t.validVertices do
        (
            if distance p t.points[vertex_index] <= tolerance then return true
        )
        false
        -- return
    ),
    fn isStraight a p b =
    (
        local u = a-p
        local v = b-p
        if length u <= tolerance or length v <= tolerance then false
        else (dot (normalize u) (normalize v) <= -(cos angularTolerance)) and (onSegment p a b)
    ),
    fn otherVertex t e v = (if t.edges[e][1] == v then t.edges[e][2] else t.edges[e][1]),
    fn collectCornerVertices t =
    (
        local result = #()
        for v in t.validVertices do
        (
            local borderEdges = (t.vertexEdges[v] * t.border) as array
            if borderEdges.count > 0 do
            (
                if borderEdges.count != 2 do throw "Non-manifold wall boundary."
                local a = otherVertex t borderEdges[1] v
                local b = otherVertex t borderEdges[2] v
                if not (isStraight t.points[a] t.points[v] t.points[b]) do append result t.points[v]
            )
        )
        result
    ),
    fn setFrame t =
    (
        if t.validFaces.numberSet == 0 then throw "The evaluated Edit Poly has no live faces."
        local first_face = (t.validFaces as array)[1]
        origin = t.points[t.faces[first_face][1]]
        local n = faceVector t first_face
        if length n <= tolerance*tolerance do throw "Degenerate input face."
        normal = normalize n
        vertical = [0,0,1] - normal * (dot normal [0,0,1])
        if length vertical < 0.00001 then
        (
            -- A horizontal planar input has no gravity-based up direction.
            -- Use its longest boundary edge for a stable in-plane orientation.
            local longest = [0,0,0]
            for e in t.border do
            (
                local s = segment t e
                if length(s[2]-s[1]) > length longest do longest = s[2]-s[1]
            )
            if length longest <= tolerance do throw "No usable boundary direction."
            horizontal = normalize longest
            vertical = normalize(cross normal horizontal)
        )
        else
        (
            vertical = normalize vertical
            horizontal = normalize(cross vertical normal)
        )
        true
    ),
    fn areaByMaterial t =
    (
        local result = #()
        for f in t.validFaces do
        (
            local key = #(t.materials[f],t.smoothing[f])
            local entry = 0
            for j = 1 to result.count do if result[j][1][1] == key[1] and result[j][1][2] == key[2] do entry = j
            if entry == 0 then append result #(key,length(faceVector t f))
            else result[entry][2] += length(faceVector t f)
        )
        result
    ),
    fn orient2 a b c = ((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)),
    fn projected p = [dot(p-origin) horizontal,dot(p-origin) vertical,0],
    fn simpleFace t vs =
    (
        if (vs as bitarray).numberSet != vs.count do return false
        -- Reject crossings, including overlapping nonadjacent polygon edges.
        for i = 1 to vs.count do for j = i+1 to vs.count do
        (
            local ni = if i == vs.count then 1 else i+1
            local nj = if j == vs.count then 1 else j+1
            if ni != j and nj != i do
            (
                local a = projected t.points[vs[i]]
                local b = projected t.points[vs[ni]]
                local c = projected t.points[vs[j]]
                local d = projected t.points[vs[nj]]
                local abC = orient2 a b c
                local abD = orient2 a b d
                local cdA = orient2 c d a
                local cdB = orient2 c d b
                if abC*abD < 0 and cdA*cdB < 0 do return false
                if onSegment c a b or onSegment d a b or onSegment a c d or onSegment b c d do return false
            )
        )
        true
    ),
    /* MNMesh can encode a polygon with a hole by traversing an internal
       bridge twice, in opposite directions. This is not a self-intersection.
       Accept only these native bridges; actual crossings and pinches fail. */
    fn validFaceBoundary t f =
    (
        local vs = t.faces[f]
        if simpleFace t vs do return true
        local bridges = #{}
        for e in t.faceEdges[f] do
        (
            local rec = t.edges[e]
            if rec[3] == f and rec[4] == f do
            (
                local forwardCount = 0
                local reverseCount = 0
                for k=1 to vs.count do
                (
                    local next = if k == vs.count then 1 else k+1
                    if vs[k] == rec[1] and vs[next] == rec[2] do forwardCount += 1
                    if vs[k] == rec[2] and vs[next] == rec[1] do reverseCount += 1
                )
                if forwardCount != 1 or reverseCount != 1 do return false
                bridges[e] = true
            )
        )
        if bridges.numberSet == 0 do return false
        for v in (vs as bitarray) do
        (
            local occurrences = 0
            for candidate in vs do if candidate == v do occurrences += 1
            if occurrences != 1+(t.vertexEdges[v]*bridges).numberSet do return false
        )
        for i=1 to vs.count do for j=i+1 to vs.count do
        (
            local ni = if i == vs.count then 1 else i+1
            local nj = if j == vs.count then 1 else j+1
            if ni != j and nj != i and not(vs[i] == vs[nj] and vs[ni] == vs[j]) do
            (
                local a = projected t.points[vs[i]]
                local b = projected t.points[vs[ni]]
                local c = projected t.points[vs[j]]
                local d = projected t.points[vs[nj]]
                if (orient2 a b c)*(orient2 a b d) < 0 and (orient2 c d a)*(orient2 c d b) < 0 do return false
                if vs[j] != vs[i] and vs[j] != vs[ni] and onSegment c a b do return false
                if vs[nj] != vs[i] and vs[nj] != vs[ni] and onSegment d a b do return false
                if vs[i] != vs[j] and vs[i] != vs[nj] and onSegment a c d do return false
                if vs[ni] != vs[j] and vs[ni] != vs[nj] and onSegment b c d do return false
            )
        )
        true
    ),
    fn validateStructure t =
    (
        if t.validFaces.numberSet == 0 then throw "The wall lost all faces."
        for vertex_index in t.validVertices do
        (
            if abs(dot(t.points[vertex_index]-origin) normal) > planarTolerance then throw "Input/result is not one planar wall."
        )
        local used = #{}
        for f in t.validFaces do
        (
            local vs = t.faces[f]
            if vs.count < 3 do throw "Invalid polygon degree."
            if not(validFaceBoundary t f) do throw "Self-intersecting or invalid polygon boundary."
            -- Face winding is not a planarity failure. Reject only truly degenerate zero-area faces.
            if length(faceVector t f) <= tolerance*tolerance do throw "Zero-area polygon."
            for v in vs do used[v] = true
        )
        if used.numberSet != t.validVertices.numberSet do throw "Isolated vertices in topology."
        for e in t.validEdges do
        (
            local rec = t.edges[e]
            if rec[1] < 1 or rec[2] < 1 or (rec[3] == 0 and rec[4] == 0) do throw "Isolated/invalid edge."
            if distance t.points[rec[1]] t.points[rec[2]] <= tolerance do throw "Zero-length edge."
            -- Same-face bridge incidence was checked by validFaceBoundary.
            for f in #(rec[3],rec[4]) where f > 0 do
            (
                if not t.validFaces[f] then throw "Edge references a dead face."
                if not t.faceEdges[f][e] then throw "Invalid face-edge adjacency."
            )
        )
        collectCornerVertices t -- Also validates the outer and opening border degree.
        true
    ),
    fn canRemoveVertex t v =
    (
        local incident = t.vertexEdges[v] as array
        if incident.count != 2 do return false
        for p in corners do if distance p t.points[v] <= tolerance do return false
        local a = otherVertex t incident[1] v
        local b = otherVertex t incident[2] v
        if not(isStraight t.points[a] t.points[v] t.points[b]) do return false
        for f in t.validFaces where findItem t.faces[f] v > 0 do
            if t.faces[f].count <= 3 do return false
        true
    ),
    fn uvContinuous t e =
    (
        local rec = t.edges[e]
        for channel = -2 to (ep.GetNumMapChannels node:node)-1 do
            if ep.GetMapChannelActive channel node:node do
                for v in #(rec[1],rec[2]) do
                (
                    local values = #()
                    for f in #(rec[3],rec[4]) do
                    (
                        local k = findItem t.faces[f] v
                        local mv = ep.GetMapFaceVert channel f k node:node
                        append values (ep.GetMapVertex channel mv node:node)
                    )
                    if distance values[1] values[2] > 0.000001 do return false
                )
        true
    ),
    fn canRemoveDiagonal t e =
    (
        local rec = t.edges[e]
        local a = rec[3]
        local b = rec[4]
        if a == 0 or b == 0 or a == b then return false
        if not t.validFaces[a] or not t.validFaces[b] then return false
        if edgeKind t e != #diagonal then return false
        local s = segment t e
        local old = false
        for stored in originalDiagonals do
            if onSegment s[1] stored[1] stored[2] and onSegment s[2] stored[1] stored[2] do old = true
        if not old do return false
        if t.materials[a] != t.materials[b] or t.smoothing[a] != t.smoothing[b] do return false
        if (t.faceEdges[a]*t.faceEdges[b]).numberSet != 1 do return false
        -- Exactly two common vertices and one shared edge: their union is a disk,
        -- not a ring around an opening or a pair touching at another corner.
        if ((t.faces[a] as bitarray)*(t.faces[b] as bitarray)).numberSet != 2 do return false
        if not(uvContinuous t e) do return false
        -- Walk the conceptual union once; refuse multiple loops or crossings.
        local boundaryEdges = (t.faceEdges[a]+t.faceEdges[b])-#{e}
        local remaining = copy boundaryEdges
        local loop = #(rec[1])
        local current = rec[1]
        while remaining.numberSet > 0 do
        (
            local candidates = (t.vertexEdges[current]*remaining) as array
            if candidates.count == 0 do return false
            local nextEdge = candidates[1]
            remaining[nextEdge] = false
            current = otherVertex t nextEdge current
            if current != loop[1] then append loop current
            else if remaining.numberSet > 0 do return false
        )
        current == loop[1] and simpleFace t loop
    ),
    fn validateCleanTopology t final:false =
    (
        validateStructure t
        local boundary_tolerance = getBoundaryValidationTolerance()
        local borderSegments = for e in t.border collect segment t e
        for i = 1 to originalBorder.count do
        (
            local s = originalBorder[i]
            if not(coveredAtTolerance s borderSegments boundary_tolerance) then
            (
                format "WallMeshCleaner Boundary Debug: original segment:%  A:%  B:%  topologyTolerance:%  boundaryTolerance:%  planarTolerance:%\n" i s[1] s[2] tolerance boundary_tolerance planarTolerance
                throw ("Original wall/opening boundary changed at original segment " + (i as string) + ".")
            )
        )
        for i = 1 to borderSegments.count do
        (
            local s = borderSegments[i]
            if not(coveredAtTolerance s originalBorder boundary_tolerance) then
            (
                format "WallMeshCleaner Boundary Debug: unexpected segment:%  A:%  B:%  topologyTolerance:%  boundaryTolerance:%  planarTolerance:%\n" i s[1] s[2] tolerance boundary_tolerance planarTolerance
                throw ("Unexpected wall/opening boundary at result segment " + (i as string) + ".")
            )
        )
        for p in corners do if not(hasPoint t p) do throw "An original corner was lost."
        if (t.validVertices.numberSet-t.validEdges.numberSet+t.validFaces.numberSet) != baseline[1] do throw "Wall/opening topology changed (Euler characteristic)."
        local areas = areaByMaterial t
        if areas.count != baseline[2].count do throw "Material/smoothing regions changed."
        for old in baseline[2] do
        (
            local found = false
            for current in areas do if old[1][1] == current[1][1] and old[1][2] == current[1][2] do
                found = abs(old[2]-current[2]) <= amax (old[2]*0.00001) (tolerance*tolerance*10)
            if not found do throw "Wall surface area or material/smoothing boundary changed."
        )
        local allSegments = for e in t.validEdges collect segment t e
        for s in protectedSegments do if not(coveredAtTolerance s allSegments boundary_tolerance) do throw "An intentional orthogonal edge was lost."
        if final do
        (
            for v in t.validVertices do if canRemoveVertex t v do throw "A safely removable collinear vertex remains."
            for e in t.validEdges do if canRemoveDiagonal t e then throw "A safely removable internal diagonal remains."
        )
        true
    ),
    fn applyOperation level ids operation =
    (
        if level == #Vertex then subObjectLevel = 1
        else if level == #Edge then subObjectLevel = 2
        else if level == #Face then subObjectLevel = 4
        ep.SetEPolySelLevel level
        refreshTopology()
        ep.SetSelection level #{} node:node
        local selectedOK = ep.Select level ids node:node
        if not selectedOK or (ep.GetSelection level node:node) != ids do throw ("Edit Poly selection failed for " + (level as string) + " result=" + (selectedOK as string) + " requested=" + (ids as string) + " actual=" + ((ep.GetSelection level node:node) as string))
        ep.SetOperation operation
        ep.Commit()
        refreshTopology()
    ),
    fn cleanCollinearVertices =
    (
        local t = refreshTopology()
        local changed = true
        while changed do
        (
            changed = false
            for v in t.validVertices while not changed do if canRemoveVertex t v do
            (
                local countBefore = t.validVertices.numberSet
                t = applyOperation #Vertex #{v} #RemoveVertex
                if t.validVertices.numberSet != countBefore-1 do throw "Edit Poly did not remove exactly one straight vertex."
                validateCleanTopology t
                removedVerts += 1
                changed = true
            )
        )
        t
    ),
    fn componentAt t p =
    (
        local result = #{}
        local queue = #()
        for v in t.validVertices do if distance t.points[v] p <= tolerance do
            for e in t.vertexEdges[v] do if t.validEdges[e] then for f in #(t.edges[e][3],t.edges[e][4]) where f > 0 do
                if t.validFaces[f] and not result[f] then (result[f] = true; append queue f)
        local i = 1
        while i <= queue.count do
        (
            local f = queue[i]
            i += 1
            for e in t.faceEdges[f] do if t.validEdges[e] then for g in #(t.edges[e][3],t.edges[e][4]) where g > 0 do
                if t.validFaces[g] and not result[g] then (result[g] = true; append queue g)
        )
        result
    ),
    /*
    Collects boundary corner anchors used by the wall slicer.
    An anchor must connect one horizontal and one vertical border edge.
    */
    function collectCutAnchors t =
    (
        anchors = #()
        for v in t.validVertices do
        (
            local es = (t.vertexEdges[v]*t.border) as array
            if es.count == 2 then
            (
                local k1 = edgeKind t es[1]
                local k2 = edgeKind t es[2]
                if (k1 == #horizontal and k2 == #vertical) or (k1 == #vertical and k2 == #horizontal) then
                (
                    append anchors t.points[v]
                )
            )
        )
        anchors
        -- return
    ),
    /*
    Initializes non-destructive mesh data required by debug and slice operations.
    No topology change is performed by this function.
    */
    function prepareSliceAnalysis =
    (
        local t = refreshTopology()
        setFrame t
        validateStructure t
        corners = collectCornerVertices t
        originalBorder = for e in t.border collect segment t e
        originalDiagonals = for e in t.validEdges where not t.border[e] and edgeKind t e == #diagonal collect segment t e
        protectedSegments = for e in t.validEdges where edgeKind t e != #diagonal collect segment t e
        baseline = #(t.validVertices.numberSet-t.validEdges.numberSet+t.validFaces.numberSet,areaByMaterial t)
        collectCutAnchors t
        t
        -- return
    ),
    /*
    Validates the current evaluated wall without modifying topology.
    Returns compact mesh statistics for the Debug report.
    */
    function checkMesh =
    (
        local t = prepareSliceAnalysis()
        #(t.validVertices.numberSet,t.validEdges.numberSet,t.validFaces.numberSet,t.border.numberSet,corners.count,anchors.count)
        -- return
    ),
    /*
    Builds a vertex BitArray for all currently detected slice anchors.
    Anchor positions are remapped to the current topology snapshot.
    */
    function getSliceAnchorVertexSelection =
    (
        local t = refreshTopology()
        local anchor_vertices = #{}
        for anchor in anchors do
        (
            local best_vertex = 0
            local best_distance = 1e30
            for v in t.validVertices do
            (
                local current_distance = distance t.points[v] anchor
                if current_distance < best_distance then
                (
                    best_distance = current_distance
                    best_vertex = v
                )
            )
            if best_vertex > 0 and best_distance <= tolerance then
            (
                anchor_vertices[best_vertex] = true
            )
        )
        anchor_vertices
        -- return
    ),
    /*
    Collects closed border loops as ordered vertex-index arrays.
    The validated wall boundary guarantees two border edges at each border vertex.
    */
    function collectBorderLoops t =
    (
        local remaining_edges = copy t.border
        local loops = #()
        while remaining_edges.numberSet > 0 do
        (
            local start_edge = (remaining_edges as array)[1]
            local start_vertex = t.edges[start_edge][1]
            local current_vertex = start_vertex
            local current_edge = start_edge
            local loop_vertices = #()
            local closed = false
            local safety = 0
            while not closed and safety <= t.validEdges.numberSet do
            (
                safety += 1
                append loop_vertices current_vertex
                remaining_edges[current_edge] = false
                local next_vertex = otherVertex t current_edge current_vertex
                if next_vertex == start_vertex then
                (
                    closed = true
                )
                else
                (
                    local next_edges = (t.vertexEdges[next_vertex] * t.border) as array
                    if next_edges.count != 2 then throw "Non-manifold wall boundary."
                    local next_edge = if next_edges[1] == current_edge then next_edges[2] else next_edges[1]
                    current_vertex = next_vertex
                    current_edge = next_edge
                )
            )
            if not closed then throw "Cannot trace closed wall boundary."
            append loops loop_vertices
        )
        loops
        -- return
    ),
    /*
    Returns signed projected area of one border loop in the current wall frame.
    Only absolute area is used to distinguish the outer boundary from openings.
    */
    function borderLoopArea t loop_vertices =
    (
        local area = 0.0
        for i = 1 to loop_vertices.count do
        (
            local j = if i == loop_vertices.count then 1 else i + 1
            local p1 = t.points[loop_vertices[i]] - origin
            local p2 = t.points[loop_vertices[j]] - origin
            local x1 = dot p1 horizontal
            local y1 = dot p1 vertical
            local x2 = dot p2 horizontal
            local y2 = dot p2 vertical
            area += x1 * y2 - x2 * y1
        )
        area * 0.5
        -- return
    ),
    /*
    Selects wall-inner corner vertices on all boundary loops.
    Opening-loop corners are included, plus concave/re-entrant corners on the outer border.
    */
    function getInnerCornerVertexSelection =
    (
        local t = refreshTopology()
        local loops = collectBorderLoops t
        local result = #{}
        if loops.count == 0 then return result

        local outer_index = 1
        local outer_signed_area = borderLoopArea t loops[1]
        local outer_area = abs(outer_signed_area)
        for i = 2 to loops.count do
        (
            local current_signed_area = borderLoopArea t loops[i]
            local current_area = abs(current_signed_area)
            if current_area > outer_area then
            (
                outer_area = current_area
                outer_signed_area = current_signed_area
                outer_index = i
            )
        )

        for i = 1 to loops.count do
        (
            local loop_vertices = loops[i]
            local loop_signed_area = borderLoopArea t loop_vertices
            local loop_orientation = if loop_signed_area >= 0.0 then 1.0 else -1.0

            for j = 1 to loop_vertices.count do
            (
                local v = loop_vertices[j]
                local border_edges = (t.vertexEdges[v] * t.border) as array
                if border_edges.count == 2 then
                (
                    local a = otherVertex t border_edges[1] v
                    local b = otherVertex t border_edges[2] v
                    if not(isStraight t.points[a] t.points[v] t.points[b]) then
                    (
                        if i != outer_index then
                        (
                            result[v] = true
                        )
                        else
                        (
                            local previous_index = if j == 1 then loop_vertices.count else j - 1
                            local next_index = if j == loop_vertices.count then 1 else j + 1
                            local previous_vertex = loop_vertices[previous_index]
                            local next_vertex = loop_vertices[next_index]
                            local p0 = t.points[previous_vertex] - origin
                            local p1 = t.points[v] - origin
                            local p2 = t.points[next_vertex] - origin
                            local x0 = dot p0 horizontal
                            local y0 = dot p0 vertical
                            local x1 = dot p1 horizontal
                            local y1 = dot p1 vertical
                            local x2 = dot p2 horizontal
                            local y2 = dot p2 vertical
                            local turn_cross = ((x1 - x0) * (y2 - y1)) - ((y1 - y0) * (x2 - x1))
                            if (turn_cross * loop_orientation) < -tolerance then result[v] = true
                        )
                    )
                )
            )
        )
        result
        -- return
    ),
    /*
    Finds redundant vertices created where the last debug slice crossed invisible triangulation edges.
    New vertices lying on the slice line are kept only when they also lie on an original explicit polygon edge.
    */
    function findRedundantSliceVertices original_points original_segments slice_anchor slice_axis =
    (
        local t = refreshTopology()
        local result = #{}
        local match_tolerance = getBoundaryValidationTolerance()

        function pointMatchesOriginal point_value points_array comparison_tolerance =
        (
            for original_point in points_array do
            (
                if distance point_value original_point <= comparison_tolerance then return true
            )
            false
            -- return
        )

        function pointOnOriginalSegment point_value segments_array comparison_tolerance =
        (
            for original_segment in segments_array do
            (
                local a = original_segment[1]
                local b = original_segment[2]
                local d = b - a
                local segment_length = length d
                if segment_length > comparison_tolerance then
                (
                    local direction = d / segment_length
                    local along = dot (point_value - a) direction
                    local offset = length ((point_value - a) - (direction * along))
                    if along >= -comparison_tolerance and along <= segment_length + comparison_tolerance and offset <= comparison_tolerance then return true
                )
            )
            false
            -- return
        )

        for v in t.validVertices do
        (
            local point_value = t.points[v]
            if abs(dot (point_value - slice_anchor) slice_axis) <= match_tolerance then
            (
                if not(pointMatchesOriginal point_value original_points match_tolerance) and not(pointOnOriginalSegment point_value original_segments match_tolerance) then
                (
                    local slice_neighbor_count = 0
                    for edge_index in t.vertexEdges[v] do
                    (
                        local other_vertex = otherVertex t edge_index v
                        local other_point = t.points[other_vertex]
                        if abs(dot (other_point - slice_anchor) slice_axis) <= match_tolerance then
                        (
                            slice_neighbor_count += 1
                        )
                    )
                    if slice_neighbor_count >= 2 then result[v] = true
                )
            )
        )
        result
        -- return
    ),

    /*
    Finds new non-border edges created by the debug slice.
    Border edges are always excluded because a border cannot be a sliced interior edge.
    */
    function findNewEdges original_segments =
    (
        local t = refreshTopology()
        local result = #{}
        local match_tolerance = getBoundaryValidationTolerance()

        for edge_index in t.validEdges do
        (
            if not t.border[edge_index] then
            (
                local current_segment = segment t edge_index
                local existed_before = false
                for original_segment in original_segments while not existed_before do
                (
                    local same_forward = distance current_segment[1] original_segment[1] <= match_tolerance and distance current_segment[2] original_segment[2] <= match_tolerance
                    local same_reverse = distance current_segment[1] original_segment[2] <= match_tolerance and distance current_segment[2] original_segment[1] <= match_tolerance
                    if same_forward or same_reverse then existed_before = true
                )
                if not existed_before then result[edge_index] = true
            )
        )
        result
        -- return
    ),
    /*
    Finds the current vertex index matching a preserved corner position.
    The nearest evaluated vertex is returned so topology refreshes do not invalidate stored indices.
    */
    function findVertexAtPoint t point_value =
    (
        local best_vertex = 0
        local best_distance = 1e30

        for vertex_index in t.validVertices do
        (
            local current_distance = distance t.points[vertex_index] point_value
            if current_distance < best_distance then
            (
                best_distance = current_distance
                best_vertex = vertex_index
            )
        )

        best_vertex
        -- return
    ),

    /*
    Builds one slice-plane definition from either the global wall frame or a corner plus its next border vertex.
    Returns plane normal axis, defining vertex selection and the optional second defining vertex.
    */
    function getSlicePlaneDefinition t source_vertex slice_kind planeMode:#nextVert =
    (
        if source_vertex < 1 or source_vertex > t.points.count or not t.validVertices[source_vertex] then return undefined

        local anchor = t.points[source_vertex]
        local desired_line = if slice_kind == #vertical then vertical else horizontal

        if planeMode == #globalAxis then
        (
            local plane_axis = if slice_kind == #vertical then horizontal else vertical
            local aligned_vertices = #{}

            for vertex_index in t.validVertices do
            (
                if abs(dot(t.points[vertex_index]-anchor) plane_axis) <= tolerance then
                (
                    aligned_vertices[vertex_index] = true
                )
            )

            #(plane_axis,aligned_vertices,0,0)
        )
        else
        (
            local border_edges = (t.vertexEdges[source_vertex] * t.border) as array
            local matching_edges = #()

            /*
            Edge Direction must be defined by one real border edge.
            Accept only the adjacent border edge whose classified direction matches the requested slice direction.
            */
            for edge_index in border_edges do
            (
                if edgeKind t edge_index == slice_kind then
                (
                    append matching_edges edge_index
                )
            )

            /* A clean orthogonal corner has exactly one horizontal and one vertical border edge. */
            if matching_edges.count != 1 then return undefined

            local defining_edge = matching_edges[1]
            local best_vertex = otherVertex t defining_edge source_vertex
            if best_vertex == 0 then return undefined

            local edge_vector = t.points[best_vertex] - anchor
            if length edge_vector <= tolerance then return undefined

            local line_direction = normalize edge_vector
            local plane_axis = cross line_direction normal
            if length plane_axis <= tolerance then return undefined
            plane_axis = normalize plane_axis

            local aligned_vertices = #{source_vertex,best_vertex}
            #(plane_axis,aligned_vertices,best_vertex,defining_edge)
        )
        -- return
    ),

    /*
    Finds vertices defining the next debug slice plane without modifying topology.
    Global-axis mode selects every vertex on the plane; next-vert mode selects the exact defining pair.
    */
    function getOneSliceAlignmentVertices cutMode:#all planeMode:#nextVert =
    (
        local t = prepareSliceAnalysis()
        local inner_vertices = getInnerCornerVertexSelection()
        if inner_vertices.numberSet == 0 then return undefined

        local slice_kinds = #()
        if cutMode == #all or cutMode == #vertical then append slice_kinds #vertical
        if cutMode == #all or cutMode == #horizontal then append slice_kinds #horizontal

        for source_vertex in inner_vertices do
        (
            t = refreshTopology()
            local anchor = t.points[source_vertex]
            local region = componentAt t anchor
            if region.numberSet > 0 then
            (
                for slice_kind in slice_kinds do
                (
                    local plane_definition = getSlicePlaneDefinition t source_vertex slice_kind planeMode:planeMode
                    if plane_definition != undefined then
                    (
                        local axis = plane_definition[1]
                        local spans = false
                    for face_index in region while not spans do
                    (
                        local low = 1e30
                        local high = -1e30
                        for vertex_index in t.faces[face_index] do
                        (
                            local value = dot(t.points[vertex_index]-anchor) axis
                            low = amin low value
                            high = amax high value
                        )
                        if low < -tolerance and high > tolerance then spans = true
                    )

                        if spans then
                        (
                            return #(plane_definition[2],source_vertex,slice_kind,axis,anchor,plane_definition[3],plane_definition[4])
                        )
                    )
                )
            )
        )
        undefined
        -- return
    ),

    /*
    Performs one debug slice using a plane defined entirely by the unchanged base object.
    The current Edit Poly only executes the plane and no longer rediscovers a border edge.
    */
    function makeOneSliceFromBasePlane sourceVertex worldAnchor worldAxis sliceKind =
    (
        if worldAnchor == undefined or worldAxis == undefined then return undefined
        if length worldAxis <= tolerance then return undefined

        local t = refreshTopology()
        setFrame t

        local axis = normalize worldAxis
        local anchor = worldAnchor - referenceWorld
        local original_vertex_count = t.validVertices.numberSet
        local original_edge_count = t.validEdges.numberSet
        local original_face_count = t.validFaces.numberSet
        local original_vertices = copy t.validVertices
        local original_points = for vertex_index in t.validVertices collect t.points[vertex_index]
        local original_segments = #()
        for edge_index in t.validEdges do
        (
            append original_segments (segment t edge_index)
        )

        /* Select current Edit Poly vertices lying on the base-defined slice plane.
           Current vertex IDs are irrelevant; the unchanged base object owns the plane definition. */
        local aligned_vertices = #{}
        local alignment_tolerance = getBoundaryValidationTolerance()
        for vertex_index in t.validVertices do
        (
            if abs(dot(t.points[vertex_index] - anchor) axis) <= alignment_tolerance then
            (
                aligned_vertices[vertex_index] = true
            )
        )

        ep.useStackSelection = false
        ep.SetEPolySelLevel #Vertex
        subObjectLevel = 1
        ep.SetSelection #Vertex #{} node:node
        if aligned_vertices.numberSet > 0 then
        (
            ep.Select #Vertex aligned_vertices node:node
        )
        completeRedraw()

        local tm = node.objectTransform
        local local_normal = normalize [dot tm.row1 axis,dot tm.row2 axis,dot tm.row3 axis]
        local local_point = worldAnchor * inverse tm
        ep.SetSlicePlane local_normal local_point

        format "WallMeshCleaner Base Plane Slice: source:% direction:% alignedCurrentVerts:% axis:% faces:% split:%\n" sourceVertex sliceKind aligned_vertices axis t.validFaces.numberSet ep.split
        t = applyOperation #Face t.validFaces #Slice

        local topology_changed = (t.validVertices.numberSet != original_vertex_count or t.validEdges.numberSet != original_edge_count or t.validFaces.numberSet != original_face_count)

        local new_edges = findNewEdges original_segments
        if topology_changed and new_edges.numberSet == 0 then
        (
            /* Geometric before/after matching can be over-tolerant at large world coordinates.
               If Edit Poly changed topology, fall back to current non-border edges lying on this plane. */
            local plane_edge_tolerance = amax tolerance 0.01
            for edge_index in t.validEdges do
            (
                if not t.border[edge_index] then
                (
                    local edge_segment = segment t edge_index
                    if abs(dot(edge_segment[1] - anchor) axis) <= plane_edge_tolerance and abs(dot(edge_segment[2] - anchor) axis) <= plane_edge_tolerance then
                    (
                        new_edges[edge_index] = true
                    )
                )
            )
        )

        if not topology_changed then
        (
            format "WallMeshCleaner Base Plane Slice Skip: source:% direction:% reason:Edit Poly topology did not change.\n" sourceVertex sliceKind
            return undefined
        )

        cuts += 1
        ep.useStackSelection = false
        ep.SetEPolySelLevel #Edge
        subObjectLevel = 2
        ep.SetSelection #Edge #{} node:node
        ep.Select #Edge new_edges node:node
        completeRedraw()

        #(anchor,sourceVertex,sourceVertex,sliceKind,axis,original_points,original_segments,referenceWorld,new_edges,aligned_vertices,0,original_vertices)
        -- return
    ),

    /*
    Performs one debug slice through one current live vertex.
    Debug slicing uses only the current live topology and current vertex selection.
    */
    function makeOneSlice cutMode:#all planeMode:#nextVert preferredSourceVertex:0 strictPreferredSource:false excludedSourceVertex:0 =
    (
        local t = undefined
        local source_vertices = #{}

        if strictPreferredSource then
        (
            if preferredSourceVertex < 1 then return undefined
            t = refreshTopology()
            setFrame t
            if preferredSourceVertex > t.points.count or not t.validVertices[preferredSourceVertex] then
            (
                format "WallMeshCleaner Slice Debug: selected source vertex % is not live anymore.\n" preferredSourceVertex
                return undefined
            )
            source_vertices = #{preferredSourceVertex}
        )
        else
        (
            t = prepareSliceAnalysis()
            local inner_vertices = getInnerCornerVertexSelection()
            if inner_vertices.numberSet == 0 then return undefined
            if preferredSourceVertex > 0 and preferredSourceVertex <= t.points.count and t.validVertices[preferredSourceVertex] and inner_vertices[preferredSourceVertex] and preferredSourceVertex != excludedSourceVertex then
            (
                source_vertices = #{preferredSourceVertex}
            )
            else
            (
                source_vertices = copy inner_vertices
                if excludedSourceVertex > 0 and excludedSourceVertex <= source_vertices.count then
                (
                    source_vertices[excludedSourceVertex] = false
                )
            )

            format "WallMeshCleaner Make 1 Slice Candidates: inner:% preferred:% skippedLast:% candidates:%\n" inner_vertices preferredSourceVertex excludedSourceVertex source_vertices
        )

        local slice_kinds = #()
        if cutMode == #all or cutMode == #vertical then append slice_kinds #vertical
        if cutMode == #all or cutMode == #horizontal then append slice_kinds #horizontal

        for source_vertex_before in source_vertices do
        (
            t = refreshTopology()
            if source_vertex_before >= 1 and source_vertex_before <= t.points.count and t.validVertices[source_vertex_before] then
            (
                local anchor = t.points[source_vertex_before]
                local region = componentAt t anchor
                if region.numberSet > 0 then
                (
                    for slice_kind in slice_kinds do
                    (
                        local plane_definition = getSlicePlaneDefinition t source_vertex_before slice_kind planeMode:planeMode
                        if plane_definition != undefined then
                        (
                            local axis = plane_definition[1]
                            local aligned_vertices = plane_definition[2]
                            local second_vertex = plane_definition[3]
                            local defining_edge = plane_definition[4]
                            /*
                            Test the whole connected wall region, not one individual face.
                            Previous slices may partition a valid next cut across several faces.
                            */
                            local region_low = 1e30
                            local region_high = -1e30
                            local region_vertices = #{}

                            for face_index in region do
                            (
                                if t.validFaces[face_index] then
                                (
                                    for vertex_index in t.faces[face_index] do
                                    (
                                        if vertex_index >= 1 and vertex_index <= t.points.count and t.validVertices[vertex_index] then
                                        (
                                            region_vertices[vertex_index] = true
                                        )
                                    )
                                )
                            )

                            for vertex_index in region_vertices do
                            (
                                local region_value = dot(t.points[vertex_index]-anchor) axis
                                region_low = amin region_low region_value
                                region_high = amax region_high region_value
                            )

                            local spans = region_low < -tolerance and region_high > tolerance

                            if spans then
                            (
                                local original_points = for vertex_index in t.validVertices collect t.points[vertex_index]
                                local original_segments = #()
                                for edge_index in t.validEdges do
                                (
                                    append original_segments (segment t edge_index)
                                )

                                ep.useStackSelection = false
                                ep.SetEPolySelLevel #Vertex
                                subObjectLevel = 1
                                ep.SetSelection #Vertex #{} node:node
                                ep.Select #Vertex #{source_vertex_before} node:node
                                completeRedraw()

                                local tm = node.objectTransform
                                local localNormal = normalize [dot tm.row1 axis,dot tm.row2 axis,dot tm.row3 axis]
                                local localPoint = (anchor + referenceWorld) * inverse tm
                                ep.SetSlicePlane localNormal localPoint
                                local slice_operation = if region.numberSet == t.validFaces.numberSet then #Slice else #SliceSelectedFaces
                                format "WallMeshCleaner Slice Debug: innerCorner:% direction:% planeMode:% definingEdge:% definingVerts:% operation:% region:%/% split:%\n" source_vertex_before slice_kind planeMode defining_edge aligned_vertices slice_operation region.numberSet t.validFaces.numberSet ep.split
                                t = applyOperation #Face region slice_operation

                                local source_vertex_after = source_vertex_before
                                if source_vertex_after > t.points.count or not t.validVertices[source_vertex_after] then source_vertex_after = 0

                                local new_edges = findNewEdges original_segments

                                if new_edges.numberSet > 0 then
                                (
                                    cuts += 1
                                    ep.useStackSelection = false
                                    ep.SetEPolySelLevel #Edge
                                    subObjectLevel = 2
                                    ep.SetSelection #Edge #{} node:node
                                    ep.Select #Edge new_edges node:node
                                    completeRedraw()
                                    return #(anchor,source_vertex_before,source_vertex_after,slice_kind,axis,original_points,original_segments,referenceWorld,new_edges,aligned_vertices,second_vertex)
                                )
                                else
                                (
                                    format "WallMeshCleaner Make 1 Slice Skip: source:% direction:% reason:no new non-border edge.\n" source_vertex_before slice_kind
                                )
                            )
                            else
                            (
                                format "WallMeshCleaner Make 1 Slice Skip: source:% direction:% reason:connected region does not cross plane.\n" source_vertex_before slice_kind
                            )
                        )
                    )
                )
            )
        )
        undefined
        -- return
    ),
    /*
    Performs all cuts of one requested orientation using the selected slice-plane definition mode.
    Global-axis mode uses the wall frame; next-vert mode derives each plane from the corner and matching border neighbour.
    */
    function performCuts slice_kind planeMode:#nextVert =
    (
        local done = #()

        for anchor in anchors do
        (
            local t = refreshTopology()
            local region = componentAt t anchor
            if region.numberSet == 0 then throw "Cannot remap a preserved corner anchor."

            local source_vertex = findVertexAtPoint t anchor
            if source_vertex > 0 then
            (
                local plane_definition = getSlicePlaneDefinition t source_vertex slice_kind planeMode:planeMode
                if plane_definition != undefined then
                (
                    local axis = plane_definition[1]
                    local duplicate = false

                    for item in done while not duplicate do
                    (
                        local parallel = abs(dot item[1] axis) >= cos(axisTolerance)
                        local same_plane = abs(dot(anchor-item[2]) axis) <= tolerance
                        if parallel and same_plane then duplicate = true
                    )

                    if not duplicate then
                    (
                        append done #(axis,anchor)
                        local spans = false

                        for face_index in region while not spans do
                        (
                            local low = 1e30
                            local high = -1e30

                            for vertex_index in t.faces[face_index] do
                            (
                                local value = dot(t.points[vertex_index]-anchor) axis
                                low = amin low value
                                high = amax high value
                            )

                            if low < -tolerance and high > tolerance then spans = true
                        )

                        if spans then
                        (
                            local tm = node.objectTransform
                            local localNormal = normalize [dot tm.row1 axis,dot tm.row2 axis,dot tm.row3 axis]
                            local localPoint = (anchor + referenceWorld) * inverse tm
                            ep.SetSlicePlane localNormal localPoint
                            local slice_operation = if region.numberSet == t.validFaces.numberSet then #Slice else #SliceSelectedFaces
                            format "WallMeshCleaner Slice Debug: direction:% planeMode:% definingVerts:% operation:% region:%/% split:%\n" slice_kind planeMode plane_definition[2] slice_operation region.numberSet t.validFaces.numberSet ep.split
                            t = applyOperation #Face region slice_operation
                            local current_region = componentAt t anchor

                            for face_index in current_region do
                            (
                                local low = 1e30
                                local high = -1e30

                                for vertex_index in t.faces[face_index] do
                                (
                                    local value = dot(t.points[vertex_index]-anchor) axis
                                    low = amin low value
                                    high = amax high value
                                )

                                if low < -tolerance and high > tolerance then throw "Slice left a polygon crossing its requested plane."
                            )

                            for edge_index in t.validEdges do
                            (
                                local edge_segment = segment t edge_index
                                if abs(dot(edge_segment[1]-anchor) axis) <= tolerance and abs(dot(edge_segment[2]-anchor) axis) <= tolerance then
                                (
                                    append protectedSegments edge_segment
                                )
                            )

                            validateCleanTopology t
                            cuts += 1
                        )
                    )
                )
            )
        )

        true
        -- return
    ),

    /*
    Performs vertical cuts using the requested slice-plane definition mode.
    */
    function performVerticalCuts planeMode:#nextVert =
    (
        performCuts #vertical planeMode:planeMode
        -- return
    ),

    /*
    Performs horizontal cuts using the requested slice-plane definition mode.
    */
    function performHorizontalCuts planeMode:#nextVert =
    (
        performCuts #horizontal planeMode:planeMode
        -- return
    ),
    fn removeRedundantDiagonalEdges =
    (
        local t = refreshTopology()
        local changed = true
        while changed do
        (
            changed = false
            for e in t.validEdges while not changed do if canRemoveDiagonal t e then
            (
                local oldCount = t.validFaces.numberSet
                t = applyOperation #Edge #{e} #RemoveEdge
                if t.validFaces.numberSet != oldCount-1 then throw "Edit Poly did not dissolve exactly two adjacent faces."
                validateCleanTopology t
                removedEdges += 1
                changed = true
            )
        )
        t
    ),
    function run cutMode:#all planeMode:#nextVert =
    (
        local t = prepareSliceAnalysis()
        cleanCollinearVertices()
        t = refreshTopology()
        -- Rebuild anchors after collinear cleanup because vertex indices/topology changed.
        collectCutAnchors t
        if cutMode == #all or cutMode == #vertical then performVerticalCuts planeMode:planeMode
        if cutMode == #all or cutMode == #horizontal then performHorizontalCuts planeMode:planeMode
        -- Removing diagonals can expose collinear vertices; removing those can
        -- make another pair of faces eligible. Refresh until both reach a fixed point.
        local changed = true
        while changed do
        (
            local before = removedEdges+removedVerts
            removeRedundantDiagonalEdges()
            cleanCollinearVertices()
            changed = removedEdges+removedVerts > before
        )
        t = refreshTopology()
        validateCleanTopology t final:true
        format "WallMeshCleaner: % | cuts:% diagonal edges removed:% straight vertices removed:% | topology validated\n" node.name cuts removedEdges removedVerts
        true
    )
)


struct WallMeshCleaner_v
(
    version = "0.87",
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
    last_debug_slice_node = undefined,
    last_debug_slice_new_edges = #{},
    last_debug_slice_start_vertices = #{},
    last_debug_slice_original_vertices = #{},
    epsilon = 0.001,
    axis_angle_threshold = 5.0,
    ini_path = ((getDir #userScripts) + "\\WallMeshCleaner.ini"),

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
    Removes all modifiers from one wall before Reset Slicing analyzes the base object.
    The base Editable Poly is preserved.
    */
    function removeAllNodeModifiers node =
    (
        if node == undefined or not(isValidNode node) then return false

        while node.modifiers.count > 0 do
        (
            deleteModifier node node.modifiers[1]
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
        removeAllNodeModifiers node

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
    Analyzes the unchanged Editable Poly base object and returns inner corners with usable directions.
    Each result is #(base_vertex_id, can_slice_vertical, can_slice_horizontal, vertical_base_edge_id, horizontal_base_edge_id).
    */
    function getBaseInnerSliceCandidates node angle_threshold:5.0 source_vertices:undefined =
    (
        result = #()
        if node == undefined or not(isValidNode node) then return result

        base_obj = node.baseObject
        if classOf base_obj != Editable_Poly then return result

        vert_count = polyop.getNumVerts base_obj
        edge_count = polyop.getNumEdges base_obj
        face_count = polyop.getNumFaces base_obj
        if vert_count < 3 or edge_count < 3 or face_count < 1 then return result

        world_points = #()
        for vertex_index = 1 to vert_count do
        (
            append world_points ((polyop.getVert base_obj vertex_index) * node.objectTransform)
        )

        wall_normal = undefined
        for face_index = 1 to face_count while wall_normal == undefined do
        (
            face_verts = polyop.getFaceVerts base_obj face_index
            if face_verts != undefined and face_verts.count >= 3 then
            (
                p1 = world_points[face_verts[1]]
                for corner_index = 2 to (face_verts.count - 1) while wall_normal == undefined do
                (
                    p2 = world_points[face_verts[corner_index]]
                    p3 = world_points[face_verts[corner_index + 1]]
                    normal_test = cross (p2 - p1) (p3 - p1)
                    if length normal_test > epsilon then wall_normal = normalize normal_test
                )
            )
        )
        if wall_normal == undefined then return result

        wall_vertical = [0,0,1] - wall_normal * (dot wall_normal [0,0,1])
        wall_horizontal = undefined
        if length wall_vertical > epsilon then
        (
            wall_vertical = normalize wall_vertical
            wall_horizontal = normalize (cross wall_vertical wall_normal)
        )

        border_edges = #{}
        vertex_border_edges = for vertex_index = 1 to vert_count collect #{}
        for edge_index = 1 to edge_count do
        (
            edge_faces = polyop.getFacesUsingEdge base_obj #{edge_index}
            if edge_faces.numberSet == 1 then
            (
                edge_verts = polyop.getEdgeVerts base_obj edge_index
                face_index = (edge_faces as array)[1]
                face_verts = polyop.getFaceVerts base_obj face_index
                face_edge_uses = 0

                /* MNMesh hole bridges belong to one face but occur twice in its boundary.
                   Count ordered boundary uses so those internal bridges are not mistaken for border edges. */
                if edge_verts != undefined and edge_verts.count == 2 and face_verts != undefined and face_verts.count >= 3 then
                (
                    for face_corner = 1 to face_verts.count do
                    (
                        next_corner = if face_corner == face_verts.count then 1 else face_corner + 1
                        face_vertex_a = face_verts[face_corner]
                        face_vertex_b = face_verts[next_corner]
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
        if border_edges.numberSet == 0 then return result

        if wall_horizontal == undefined then
        (
            longest_vector = [0,0,0]
            for edge_index in border_edges do
            (
                edge_verts = polyop.getEdgeVerts base_obj edge_index
                edge_vector = world_points[edge_verts[2]] - world_points[edge_verts[1]]
                if length edge_vector > length longest_vector then longest_vector = edge_vector
            )
            if length longest_vector <= epsilon then return result
            wall_horizontal = normalize longest_vector
            wall_vertical = normalize (cross wall_normal wall_horizontal)
        )

        direction_cos = cos (amin 45.0 (amax 0.0 angle_threshold))
        edge_kinds = for edge_index = 1 to edge_count collect #diagonal
        for edge_index in border_edges do
        (
            edge_verts = polyop.getEdgeVerts base_obj edge_index
            if edge_verts != undefined and edge_verts.count == 2 then
            (
                edge_vector = world_points[edge_verts[2]] - world_points[edge_verts[1]]
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

        remaining_edges = copy border_edges
        loops = #()
        while remaining_edges.numberSet > 0 do
        (
            start_edge = (remaining_edges as array)[1]
            start_edge_verts = polyop.getEdgeVerts base_obj start_edge
            if start_edge_verts == undefined or start_edge_verts.count != 2 then
            (
                remaining_edges[start_edge] = false
            )
            else
            (
                start_vertex = start_edge_verts[1]
                current_vertex = start_vertex
                current_edge = start_edge
                loop_vertices = #()
                closed = false
                safety = 0

                while not closed and safety <= edge_count do
                (
                    safety += 1
                    append loop_vertices current_vertex
                    remaining_edges[current_edge] = false
                    current_edge_verts = polyop.getEdgeVerts base_obj current_edge
                    next_vertex = if current_edge_verts[1] == current_vertex then current_edge_verts[2] else current_edge_verts[1]
                    if next_vertex == start_vertex then
                    (
                        closed = true
                    )
                    else
                    (
                        next_edges = (vertex_border_edges[next_vertex] * border_edges) as array
                        if next_edges.count != 2 then
                        (
                            safety = edge_count + 1
                        )
                        else
                        (
                            next_edge = if next_edges[1] == current_edge then next_edges[2] else next_edges[1]
                            current_vertex = next_vertex
                            current_edge = next_edge
                        )
                    )
                )
                if closed and loop_vertices.count >= 3 then append loops loop_vertices
            )
        )
        if loops.count == 0 then return result

        loop_areas = #()
        for loop_vertices in loops do
        (
            loop_area = 0.0
            loop_origin = world_points[loop_vertices[1]]
            for loop_position = 1 to loop_vertices.count do
            (
                next_position = if loop_position == loop_vertices.count then 1 else loop_position + 1
                point_a = world_points[loop_vertices[loop_position]] - loop_origin
                point_b = world_points[loop_vertices[next_position]] - loop_origin
                ax = dot point_a wall_horizontal
                ay = dot point_a wall_vertical
                point_b_x = dot point_b wall_horizontal
                point_b_y = dot point_b wall_vertical
                loop_area += ax * point_b_y - point_b_x * ay
            )
            append loop_areas (loop_area * 0.5)
        )

        outer_index = 1
        outer_area = abs(loop_areas[1])
        for loop_index = 2 to loops.count do
        (
            current_area = abs(loop_areas[loop_index])
            if current_area > outer_area then
            (
                outer_area = current_area
                outer_index = loop_index
            )
        )

        for loop_index = 1 to loops.count do
        (
            loop_vertices = loops[loop_index]
            signed_area = loop_areas[loop_index]
            orientation = if signed_area >= 0.0 then 1.0 else -1.0

            for corner_index = 1 to loop_vertices.count do
            (
                vertex_index = loop_vertices[corner_index]
                border_at_vertex = (vertex_border_edges[vertex_index] * border_edges) as array
                if border_at_vertex.count == 2 then
                (
                    previous_index = if corner_index == 1 then loop_vertices.count else corner_index - 1
                    next_index = if corner_index == loop_vertices.count then 1 else corner_index + 1
                    previous_vertex = loop_vertices[previous_index]
                    next_vertex = loop_vertices[next_index]
                    dir_a = world_points[previous_vertex] - world_points[vertex_index]
                    dir_b = world_points[next_vertex] - world_points[vertex_index]

                    if length dir_a > epsilon and length dir_b > epsilon then
                    (
                        dir_a = normalize dir_a
                        dir_b = normalize dir_b
                        is_straight = abs(dot dir_a dir_b) >= direction_cos

                        /*
                        When Reset Slicing supplied exact INNER VERTS, those base IDs are authoritative.
                        Do not run a second concavity test here because it can disagree with the slicer pipeline.
                        */
                        is_inner = false
                        if source_vertices != undefined then
                        (
                            if vertex_index <= source_vertices.count then
                            (
                                is_inner = source_vertices[vertex_index]
                            )
                        )
                        else if not is_straight then
                        (
                            is_inner = loop_index != outer_index
                            if not is_inner then
                            (
                                p0 = world_points[previous_vertex]
                                p1 = world_points[vertex_index]
                                p2 = world_points[next_vertex]
                                x0 = dot p0 wall_horizontal
                                y0 = dot p0 wall_vertical
                                x1 = dot p1 wall_horizontal
                                y1 = dot p1 wall_vertical
                                x2 = dot p2 wall_horizontal
                                y2 = dot p2 wall_vertical
                                turn_cross = ((x1 - x0) * (y2 - y1)) - ((y1 - y0) * (x2 - x1))
                                is_inner = (turn_cross * orientation) < -epsilon
                            )
                        )

                        if is_inner then
                        (
                                can_vertical = false
                                can_horizontal = false
                                vertical_base_edge = 0
                                horizontal_base_edge = 0
                                for edge_index in border_at_vertex do
                                (
                                    edge_kind = edge_kinds[edge_index]
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
                                            if length vertical_edge_axis > epsilon then vertical_edge_axis = normalize vertical_edge_axis else vertical_edge_axis = undefined
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
                                            if length horizontal_edge_axis > epsilon then horizontal_edge_axis = normalize horizontal_edge_axis else horizontal_edge_axis = undefined
                                        )
                                    )
                                )

                                /*
                                Store the base-object slice plane itself with the candidate.
                                The modified Edit Poly must not rediscover the defining border edge after prior cuts.
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
                                    wall_vertical
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
    Returns base-object inner-corner vertices still available for the next Make 1 Slice pass.
    For All mode, vertical candidates have priority until exhausted, then horizontal candidates are returned.
    */
    function getAvailableBaseSliceCornerSelection node cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 =
    (
        local result = #{}
        local base_candidates = getBaseInnerSliceCandidates node angle_threshold:angle_threshold
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
    function getRemainingResetInnerVertSelection node cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 =
    (
        local reset_inner_vertices = getResetInnerVertSelection node
        if reset_inner_vertices == undefined then return undefined

        local remaining_vertices = copy reset_inner_vertices
        local base_candidates = getBaseInnerSliceCandidates node angle_threshold:angle_threshold source_vertices:reset_inner_vertices
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
                                if debug_output then format "WallMeshCleaner Redundant Loop Detected: node:% loop:% edges:% startVert:% endVert:%\n" node.name loop_records.count chain_edges start_vertex current_vertex
                            )
                        )
                        else if debug_output then
                        (
                            format "WallMeshCleaner Redundant Loop Rejected: node:% startEdge:% startVert:% traversedEdges:% reason:%\n" node.name start_edge start_vertex chain_edges rejected_reason
                        )
                    )
                )
            )
        )

        if debug_output then
        (
            format "WallMeshCleaner Redundant Loop Detection Summary: node:% candidateEdges:% loops:% redundantEdges:%\n" node.name candidate_edges loop_records.count all_redundant_edges
        )

        #(loop_records, all_redundant_edges)
        -- return
    ),

    /*
    Adds FIND/DELETE Edit Poly modifiers for one node only when redundant loops are detected.
    DELETE uses Edit Poly Remove Edge, so surrounding faces are dissolved rather than deleted.
    */
    function cleanupRedundantLoopsOnNode node angle_threshold:0.1 debug_output:true commit_delete:false =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0, 0, "invalid node")
        if not(isSliceSupportedNode node) then return #(false, 0, 0, "requires Editable Poly geometry or an Edit Poly workflow")

        find_modifier = undefined
        delete_modifier = undefined
        operation_error = undefined
        loop_count = 0
        redundant_edge_count = 0

        try
        (
            find_modifier = Edit_Poly name:"WMC REDUNDANT LOOP ANALYSIS"
            addModifier node find_modifier
            update node
            find_modifier.SetPrimaryNode node
            find_modifier.useStackSelection = false

            detection_data = detectRedundantLoops node find_modifier angle_threshold:angle_threshold debug_output:debug_output
            loop_records = detection_data[1]
            redundant_edges = detection_data[2]
            loop_count = loop_records.count
            redundant_edge_count = redundant_edges.numberSet

            if redundant_edge_count == 0 then
            (
                deleteModifier node find_modifier
                find_modifier = undefined
                update node
                if debug_output then format "WallMeshCleaner Redundant Loop Cleanup: node:% no redundant loops found; no modifiers added.\n" node.name
                return #(true, 0, 0, "")
            )

            edge_descriptors = #()
            for edge_index in redundant_edges do
            (
                edge_a = find_modifier.GetEdgeVertex edge_index 1 node:node
                edge_b = find_modifier.GetEdgeVertex edge_index 2 node:node
                if edge_a == undefined or edge_b == undefined then throw ("Detected edge became invalid before cleanup: " + (edge_index as string))
                point_a = find_modifier.GetVertex edge_a node:node
                point_b = find_modifier.GetVertex edge_b node:node
                if point_a == undefined or point_b == undefined then throw ("Detected edge endpoints became invalid before cleanup: " + (edge_index as string))
                append edge_descriptors #(edge_index, point_a, point_b)
            )

            find_modifier.name = "FIND REDUNDANT LOOPS"
            find_modifier.SetEPolySelLevel #Edge
            find_modifier.SetSelection #Edge redundant_edges node:node
            stored_find_selection = find_modifier.GetSelection #Edge node:node
            if stored_find_selection != redundant_edges then throw "FIND REDUNDANT LOOPS could not store the detected edge selection."

            delete_modifier = Edit_Poly name:"DELETE REDUNDANT LOOPS"
            addModifier node delete_modifier
            update node

            select node
            max modify mode
            modPanel.setCurrentObject delete_modifier
            delete_modifier.SetPrimaryNode node
            delete_modifier.useStackSelection = false
            old_remove_ctrl = delete_modifier.remveEdgeCtrlKey
            delete_modifier.remveEdgeCtrlKey = false
            delete_modifier.SetEPolySelLevel #Edge
            subObjectLevel = 2
            delete_modifier.SetSelection #Edge redundant_edges node:node
            stored_delete_selection = delete_modifier.GetSelection #Edge node:node
            if stored_delete_selection != redundant_edges then throw "DELETE REDUNDANT LOOPS could not select the detected edges."

            if commit_delete then
            (
                /* Mass Slice must use the deterministic Edit Poly operation path. */
                delete_modifier.SetOperation #RemoveEdge
                delete_modifier.Commit()
                update node
                if debug_output then format "WallMeshCleaner Slice Selected Walls DELETE REDUNDANT LOOPS: Remove Edge executed and committed after Make 1 Slice.\n"
            )
            else
            (
                /* Keep the proven interactive/manual Edge Cleaner behavior unchanged. */
                delete_modifier.ButtonOp #RemoveEdge
            )
            update node
            delete_modifier.RefreshScreen()
            delete_modifier.remveEdgeCtrlKey = old_remove_ctrl

            unresolved_edges = #{}
            for edge_data in edge_descriptors do
            (
                if doesDebugVisibleEdgeExistByEndpointPositions node edge_data[2] edge_data[3] tolerance:0.01 then unresolved_edges[edge_data[1]] = true
            )
            if unresolved_edges.numberSet > 0 then throw ("Remove Edge left detected redundant edges visible: " + (unresolved_edges as string))

            if debug_output then
            (
                format "WallMeshCleaner Redundant Loop Cleanup Complete: node:% loops:% removedEdges:% findModifier:% deleteModifier:%\n" node.name loop_count redundant_edge_count find_modifier.name delete_modifier.name
            )
        )
        catch
        (
            operation_error = getCurrentException()
            if delete_modifier != undefined then
            (
                try(deleteModifier node delete_modifier)catch()
                delete_modifier = undefined
            )
            if find_modifier != undefined then
            (
                try(deleteModifier node find_modifier)catch()
                find_modifier = undefined
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
            format "%" last_slice_report
            true
        )
        else
        (
            last_slice_report = "Redundant Loop Cleanup completed with failures.\n" + report_text
            format "%" last_slice_report
            false
        )
        -- return
    ),

    /*
    Returns the preferred script path for Restart.
    The matching versioned file is preferred; WallMeshCleaner.ms is the fallback.
    */
    function getRestartScriptPath source_script_path =
    (
        script_dir = getFilenamePath source_script_path
        versioned_script_path = script_dir + "WallMeshCleaner_" + version + ".ms"
        unversioned_script_path = script_dir + "WallMeshCleaner.ms"

        if doesFileExist source_script_path then
        (
            source_script_path
        )
        else if doesFileExist versioned_script_path then
        (
            versioned_script_path
        )
        else if doesFileExist unversioned_script_path then
        (
            unversioned_script_path
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
    function saveSettings weld_enabled weld_threshold display_hidden_edges double_side auto_smooth cut_mode_index angle_threshold planar_tolerance:1.0 slice_plane_mode_index:2 border_angle_threshold:5.0 double_vert_threshold:1.0 slice_precision:0.01 dialog_position:undefined =
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
        setIniSetting ini_path "Settings" "DoubleVertThreshold" (double_vert_threshold as string)
        setIniSetting ini_path "Settings" "SlicePrecision" (slice_precision as string)

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
                format "WallMeshCleaner Weld: weldVertsByThreshold failed on %\n" node.name
            )

            node.weldThreshold = previous_weld_threshold
            completeRedraw()

            format "WallMeshCleaner Weld: % | threshold: % | result: %\n" \
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

            format "WallMeshCleaner Auto Smooth: % | faces: % | threshold: %\n" \
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

    /* Slice and Fix N-gons now share one native Edit Poly pipeline.
       Legacy weld keywords are accepted, but cleanup never welds borders. */
    function processNode node cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 reset_clean_edges:true clear_clean_edges:true auto_smooth:false operation_mode:#full =
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
                modifier = Edit_Poly name:"Wall topology cleanup"
                addModifier node modifier
                added = true
            )
            else
            (
                if modifier.animationMode != 0 or modifier.currentOperation != 0 do throw "Commit the active Edit Poly operation before slicing."
                backup = copy modifier
            )
            settings = #(modifier.split,modifier.useStackSelection,modifier.useSoftSel,modifier.remveEdgeCtrlKey)

            select node
            max modify mode
            modPanel.setCurrentObject modifier
            modifier.SetPrimaryNode node
            modifier.split = false
            modifier.useStackSelection = false
            modifier.useSoftSel = false
            modifier.remveEdgeCtrlKey = false
            local pipeline = WMCWallSlicePipeline node:node ep:modifier planarTolerance:(amax 0.0 planar_tolerance) axisTolerance:(amin 45.0 (amax 0.0 angle_threshold))
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
                    format "WallMeshCleaner Slice Alignment Debug: source:% direction:% mode:% edge:% vertices:% count:%\n" alignment_debug[2] alignment_debug[3] slice_plane_mode alignment_debug[7] debug_vertex_selection debug_vertex_selection.numberSet
                )
                #checkCorners:
                (
                    debug_vertex_selection = getResetInnerVertSelection node
                    if debug_vertex_selection == undefined then throw "Run Reset Slicing before Check Corners."

                    last_slice_report = node.name + ":\n" + \
                        "  INNER VERTS FROM RESET SLICING: " + (debug_vertex_selection as string) + "\n" + \
                        "  COUNT: " + (debug_vertex_selection.numberSet as string)
                    format "WallMeshCleaner Check Corners:\n%\n" last_slice_report
                )
                #oneSlice:
                (
                    clearLastDebugSliceContext node:node

                    /* Analyze only the unchanged base object to choose the next source corner.
                       Edge Direction consumes successful base edges; Global Axis consumes successful planes. */
                    local reset_inner_vertices = getResetInnerVertSelection node
                    if reset_inner_vertices == undefined then throw "Run Reset Slicing before Make 1 Slice."

                    local base_candidates = getBaseInnerSliceCandidates node angle_threshold:angle_threshold source_vertices:reset_inner_vertices
                    if base_candidates.count == 0 then throw "Reset Slicing INNER VERTS cannot define any base slice candidates."

                    local candidate_vertices = #{}
                    for candidate in base_candidates do
                    (
                        candidate_vertices[candidate[1]] = true
                    )
                    local missing_candidate_vertices = reset_inner_vertices - candidate_vertices
                    format "WallMeshCleaner Base Candidates: resetInner:% candidates:% missing:%\n" reset_inner_vertices candidate_vertices missing_candidate_vertices

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

                                format "WallMeshCleaner Base Slice: node:% baseVert:% baseEdge:% direction:% mode:% processed:%\n" node.name base_vertex base_edge slice_kind slice_plane_mode item_processed
                                slice_debug = pipeline.makeOneSliceFromBasePlane base_vertex base_anchor base_axis slice_kind

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
                                    format "WallMeshCleaner Base Slice Pending: baseVert:% baseEdge:% direction:% reason:no topology change; keep for retry.\n" base_vertex base_edge slice_kind
                                )
                            )
                            else if direction_available and base_axis != undefined and item_processed then
                            (
                                if slice_plane_mode == #nextVert then
                                (
                                    format "WallMeshCleaner Base Slice Skip: baseVert:% baseEdge:% direction:% reason:base edge already sliced.\n" base_vertex base_edge slice_kind
                                )
                                else
                                (
                                    format "WallMeshCleaner Base Slice Skip: baseVert:% direction:% reason:same geometric slice plane already processed.\n" base_vertex slice_kind
                                )
                            )
                            else if direction_available and base_axis != undefined and attempted_this_click then
                            (
                                format "WallMeshCleaner Base Slice Skip: baseVert:% baseEdge:% direction:% reason:same pending item already attempted this click.\n" base_vertex base_edge slice_kind
                            )
                            else if direction_available and base_axis == undefined then
                            (
                                format "WallMeshCleaner Base Slice Skip: baseVert:% direction:% reason:base slice plane is undefined.\n" base_vertex slice_kind
                            )
                            else if not direction_available then
                            (
                                format "WallMeshCleaner Base Slice Skip: baseVert:% direction:% reason:no matching base border edge.\n" base_vertex slice_kind
                            )
                        )
                    )

                    if slice_debug == undefined then
                    (
                        debug_edge_selection = #{}
                        last_slice_report = node.name + ": no pending base edge/plane can change the current topology yet."
                        format "WallMeshCleaner Base Slice: %\n" last_slice_report
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

            select node
            max modify mode
            base_obj = node.baseObject
            if classOf base_obj == Editable_Poly then
            (
                modPanel.setCurrentObject base_obj
                subObjectLevel = 1
                polyop.setVertSelection base_obj debug_vertex_selection
                format "WallMeshCleaner Debug Base Selection: selected:%\n" (polyop.getVertSelection base_obj)
            )
            completeRedraw()
        )
        else if (operation_mode == #oneSlice or operation_mode == #innerCorners or operation_mode == #sliceAlignment) and success and modifier != undefined then
        (
            select node
            max modify mode
            modPanel.setCurrentObject modifier
            modifier.SetPrimaryNode node
            modifier.useStackSelection = false

            if operation_mode == #oneSlice then
            (
                modifier.SetEPolySelLevel #Edge
                subObjectLevel = 2
                modifier.SetSelection #Edge #{} node:node
                local debug_selected_ok = modifier.Select #Edge debug_edge_selection node:node
                local debug_actual_selection = modifier.GetSelection #Edge node:node
                format "WallMeshCleaner Debug New Edges: requested:% selected:% result:%\n" debug_edge_selection debug_actual_selection debug_selected_ok
                if debug_actual_selection != debug_edge_selection then
                (
                    last_slice_report += " | WARNING: edge selection mismatch requested:" + (debug_edge_selection as string) + " actual:" + (debug_actual_selection as string)
                )

                last_debug_slice_node = node
                last_debug_slice_new_edges = copy debug_edge_selection
                last_debug_slice_start_vertices = copy debug_start_vertices
                last_debug_slice_original_vertices = copy debug_original_vertices
                format "WallMeshCleaner Slice Edge Cleanup Context: newEdges:% startVerts:% originalVerts:%\n" last_debug_slice_new_edges last_debug_slice_start_vertices last_debug_slice_original_vertices.numberSet
            )
            else
            (
                modifier.SetEPolySelLevel #Vertex
                subObjectLevel = 1
                modifier.SetSelection #Vertex #{} node:node
                local debug_selected_ok = modifier.Select #Vertex debug_vertex_selection node:node
                local debug_actual_selection = modifier.GetSelection #Vertex node:node
                format "WallMeshCleaner Debug Selection: requested:% selected:% result:%\n" debug_vertex_selection debug_actual_selection debug_selected_ok
                if debug_actual_selection != debug_vertex_selection then
                (
                    last_slice_report += " | WARNING: viewport selection mismatch requested:" + (debug_vertex_selection as string) + " actual:" + (debug_actual_selection as string)
                )
            )
            completeRedraw()
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
        if failure != undefined do format "WallMeshCleaner: % | restored after failure: %\n" node.name failure
        success
    ),
    /*
    Checks selected walls using the same planar/topology validation as Slice Walls.
    No topology changes are made; available slice-anchor vertices remain selected.
    */
    function debugCheckSelection angle_threshold:5.0 planar_tolerance:1.0 =
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
                if processNode node angle_threshold:angle_threshold planar_tolerance:planar_tolerance operation_mode:#check then
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
        format "WallMeshCleaner Reset Slicing:\n%\n" last_slice_report
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
        format "WallMeshCleaner Inner Corners: %\n" last_slice_report
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

        format "WallMeshCleaner Check Corners:\n%\n" last_slice_report
        completeRedraw()
        true
        -- return
    ),

    /*
    Performs exactly one debug slice through one detected inner corner on the first selected wall.
    The raw slice result is kept for inspection and every edge not present before the slice remains selected.
    */
    function debugMakeOneSlice cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 =
    (
        format "\n"

        local selected_nodes = selection as array
        last_slice_report = ""
        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select one wall before running Make 1 Slice."
            return false
        )
        local node = selected_nodes[1]
        undo "WallMeshCleaner - Debug Make 1 Slice" on
        (
            if not(processNode node cut_mode:cut_mode slice_plane_mode:slice_plane_mode angle_threshold:angle_threshold planar_tolerance:planar_tolerance operation_mode:#oneSlice) then
            (
                last_slice_report = node.name + ": " + (last_slice_error as string)
            )
        )

        local remaining_inner_vertices = getRemainingResetInnerVertSelection node \
            cut_mode:cut_mode \
            slice_plane_mode:slice_plane_mode \
            angle_threshold:angle_threshold
        if remaining_inner_vertices != undefined then
        (
            format "REMAINING INNER VERTS: %\n" remaining_inner_vertices
        )

        completeRedraw()
        last_slice_error == undefined
        -- return
    ),
    /*
    Adds a fresh Mass Slice working Edit Poly above redundant-loop inspection modifiers when needed.
    FIND/DELETE REDUNDANT LOOPS therefore stay untouched and remain inspectable between slice iterations.
    */
    function ensureMassSliceWorkingModifier node =
    (
        if node == undefined or not(isValidNode node) then return false

        if node.modifiers.count > 0 then
        (
            local top_modifier = node.modifiers[1]
            if classOf top_modifier == Edit_Poly and (top_modifier.name == "FIND REDUNDANT LOOPS" or top_modifier.name == "DELETE REDUNDANT LOOPS") then
            (
                local working_modifier = Edit_Poly name:"Wall topology cleanup"
                addModifier node working_modifier
                update node
                format "WallMeshCleaner Slice Selected Walls: added fresh working Edit Poly above %.\n" top_modifier.name
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
        subObjectLevel = 1
        modifier.SetSelection #Vertex #{} node:node
        modifier.SetSelection #Vertex single_selection node:node
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
        modifier.SetSelection #Vertex pair_selection node:node
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
                modifier.SetSelection #Vertex pair_selection node:node
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
                modifier.SetSelection #Vertex pair_selection node:node
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

        format "WallMeshCleaner Slice Precision Repair: newVert:% anchor:% distance:% threshold:% liveBefore:% liveAfter:% method:% success:%\n" new_vertex_index anchor_vertex_index world_distance precision_threshold before_live_count after_live_count repair_method repair_success
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
            format "WallMeshCleaner Slice Precision Anchor: node:% anchor:% threshold:% candidates:%\n"                 node.name anchor_vertices[anchor_array_index][1] precision_threshold anchor_candidate_sets[anchor_array_index]
        )
        format "WallMeshCleaner Slice Precision Candidates: node:% threshold:% candidates:%\n" node.name precision_threshold candidate_vertices
        format "WallMeshCleaner Slice Precision Inspection: node:% threshold:% inspection:%\n" node.name precision_threshold inspection_vertices
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
    function removeMassSlicePrecisionVertex node modifier preferred_vertex saved_position preferred_anchor anchor_world precision_threshold:0.01 =
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
                subObjectLevel = 1
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

            format "WallMeshCleaner Slice Precision Remove Attempt: preferredVert:% currentVert:% anchor:% distance:% method:% selectedVerts:% liveBefore:% liveAfter:% success:% reason:%\n" \
                preferred_vertex current_vertex anchor_vertex world_distance method actual_selection before_live_count after_live_count removed failure_reason

            if removed then return #(true, current_vertex, method, "")
        )

        current_vertex = findMassSlicePrecisionCandidate node modifier preferred_vertex saved_position tolerance:lookup_tolerance
        if current_vertex <= 0 then return #(true, 0, #alreadyGone, "")

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
            subObjectLevel = 1
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

        format "WallMeshCleaner Slice Precision Collapse Fallback: preferredVert:% currentVert:% anchor:% liveBefore:% liveAfter:% success:% reason:%\n" \
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
            subObjectLevel = 1
            modifier.SetSelection #Vertex #{} node:node
            modifier.Select #Vertex cluster_selection node:node
            actual_selection = modifier.GetSelection #Vertex node:node
            if actual_selection != cluster_selection then throw "Edit Poly collapse selection did not match the requested Slice Precision cluster."

            modifier.ButtonOp #CollapseVertex
            update node
            refreshDebugModifierTopology node
            modifier.RefreshScreen()
        )
        catch
        (
            collapse_error = getCurrentException()
        )

        local live_after_collapse = getLiveEditPolyVertexCount node modifier
        if collapse_error != undefined then return #(false, cluster_selection, 0, collapse_error as string)
        if live_after_collapse >= live_before then return #(false, cluster_selection, 0, "collapse did not reduce live vertex count")

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
            refreshDebugModifierTopology node
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

        format "WallMeshCleaner Slice Precision Cluster: anchorWorld:% selected:% liveBefore:% liveAfter:% survivor:% exactPosition:% success:% reason:%\n" \
            anchor_world cluster_selection live_before live_after_collapse survivor_vertex position_ok cluster_success failure_reason

        #(cluster_success, cluster_selection, survivor_vertex, failure_reason)
        -- return
    ),

    /*
    Repairs every precision candidate from the latest Make 1 Slice while preserving all original pre-slice anchors.
    Candidates are re-resolved after every topology change so duplicates at either end of the slice are handled independently.
    */
    function cleanupMassSlicePrecisionVerts node precision_threshold:0.01 =
    (
        if precision_threshold <= 0.0 then return #(true, 0, #{})
        if node == undefined or not(isValidNode node) then return #(false, 0, #{})
        if last_debug_slice_node != node then return #(false, 0, #{})
        if last_debug_slice_original_vertices.numberSet == 0 then return #(false, 0, #{})
        if node.modifiers.count == 0 then return #(false, 0, #{})

        local modifier = node.modifiers[1]
        if classOf modifier != Edit_Poly then return #(false, 0, #{})

        select node
        max modify mode
        modPanel.setCurrentObject modifier
        modifier.SetPrimaryNode node
        modifier.useStackSelection = false

        local precision_data = getMassSlicePrecisionCandidates node precision_threshold:precision_threshold
        local candidate_vertices = precision_data[1]
        local repair_pairs = precision_data[2]
        local object_tm = node.objectTransform
        local anchor_groups = #()
        local repaired_vertices = #{}
        local unresolved_vertices = #{}

        /* Save both anchor groups and all candidate positions before any collapse changes topology IDs. */
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

        for anchor_group in anchor_groups do
        (
            local anchor_vertex = anchor_group[1]
            local anchor_world = anchor_group[2]
            local candidate_positions = anchor_group[3]
            local original_candidate_vertices = anchor_group[4]
            local collapse_result = collapseMassSlicePrecisionAnchorCluster node modifier anchor_world candidate_positions precision_threshold:precision_threshold

            if collapse_result[1] then
            (
                repaired_vertices += original_candidate_vertices
            )
            else
            (
                unresolved_vertices += original_candidate_vertices
                format "WallMeshCleaner Slice Precision Cluster FAILED: node:% anchorVert:% candidates:% reason:%\n" node.name anchor_vertex original_candidate_vertices collapse_result[4]
            )
        )

        modifier.SetSelection #Vertex #{} node:node
        format "WallMeshCleaner Slice Precision: node:% threshold:% candidates:% repaired:% unresolved:% groups:%\n" node.name precision_threshold candidate_vertices repaired_vertices unresolved_vertices anchor_groups.count
        #(unresolved_vertices.numberSet == 0, repaired_vertices.numberSet, candidate_vertices)
        -- return
    ),

    /*
    Runs the proven Reset Slicing + Make 1 Slice debug workflow on all selected walls.
    All mode drains vertical slicing completely before starting horizontal slicing.
    */
    function debugSliceSelectedWalls cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0 slice_precision:0.01 display_hidden_edges:undefined double_side:undefined =
    (
        local selected_nodes = selection as array
        last_slice_report = ""
        last_slice_error = undefined

        if selected_nodes.count == 0 then
        (
            last_slice_report = "Select at least one wall before running Slice Selected Walls."
            return false
        )

        /* Reset all selected walls first so every node starts from the same clean debug state. */
        select selected_nodes
        if not(debugCheckSelection angle_threshold:angle_threshold planar_tolerance:planar_tolerance) then
        (
            last_slice_error = "Reset Slicing failed for one or more selected walls."
            select selected_nodes
            completeRedraw()
            return false
        )

        local requested_directions = if cut_mode == #all then #(#vertical, #horizontal) else #(cut_mode)
        local all_ok = true
        local automation_report = ""

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
                select node

                for slice_kind in requested_directions while node_ok do
                (
                    local remaining_inner_vertices = getRemainingResetInnerVertSelection node                         cut_mode:slice_kind                         slice_plane_mode:slice_plane_mode                         angle_threshold:angle_threshold

                    if remaining_inner_vertices == undefined then
                    (
                        node_error = node.name + ": Reset Slicing INNER VERTS cache is missing."
                        node_ok = false
                    )
                    else
                    (
                        format "
WallMeshCleaner Slice Selected Walls: node:% direction:%
" node.name slice_kind
                        format "REMAINING INNER VERTS: %
" remaining_inner_vertices

                        while remaining_inner_vertices.numberSet > 0 and node_ok do
                        (
                            local remaining_count_before = remaining_inner_vertices.numberSet
                            if not(ensureMassSliceWorkingModifier node) then
                            (
                                node_error = node.name + ": could not prepare the next Mass Slice working modifier."
                                node_ok = false
                            )

                            local slice_ok = false
                            if node_ok then
                            (
                                slice_ok = debugMakeOneSlice                                 cut_mode:slice_kind                                 slice_plane_mode:slice_plane_mode                                 angle_threshold:angle_threshold                                 planar_tolerance:planar_tolerance

                                if not slice_ok then
                                (
                                    node_error = node.name + ": Make 1 Slice failed in " + (slice_kind as string) + " mode. " + last_slice_report
                                    node_ok = false
                                )
                            )

                            if slice_ok then
                            (
                                local precision_cleanup = cleanupMassSlicePrecisionVerts node precision_threshold:slice_precision
                                if not precision_cleanup[1] then
                                (
                                    node_error = node.name + ": Slice Precision cleanup failed after slice."
                                    format "WallMeshCleaner Slice Selected Walls STOP: %\n" node_error
                                    node_ok = false
                                )
                                else
                                (
                                    format "WallMeshCleaner Slice Selected Walls Slice Precision: node:% threshold:% fixed:%\n" node.name slice_precision precision_cleanup[2]

                                    local redundant_cleanup = cleanupRedundantLoopsOnNode node angle_threshold:0.1 debug_output:true commit_delete:true
                                    if not redundant_cleanup[1] then
                                    (
                                        node_error = node.name + ": Redundant Loop Cleanup failed after slice. " + redundant_cleanup[4]
                                        format "WallMeshCleaner Slice Selected Walls STOP: %\n" node_error
                                        node_ok = false
                                    )
                                    else
                                    (
                                        format "WallMeshCleaner Slice Selected Walls Redundant Loop Cleanup: node:% loops:% edges:%\n" node.name redundant_cleanup[2] redundant_cleanup[3]

                                        remaining_inner_vertices = getRemainingResetInnerVertSelection node                                     cut_mode:slice_kind                                     slice_plane_mode:slice_plane_mode                                     angle_threshold:angle_threshold

                                        if remaining_inner_vertices == undefined then
                                        (
                                            node_error = node.name + ": remaining INNER VERTS could not be evaluated after slicing."
                                            node_ok = false
                                        )
                                        else if remaining_inner_vertices.numberSet >= remaining_count_before and remaining_inner_vertices.numberSet > 0 then
                                        (
                                            node_error = node.name + ": no progress in " + (slice_kind as string) + " mode; REMAINING INNER VERTS: " + (remaining_inner_vertices as string)
                                            format "WallMeshCleaner Slice Selected Walls STOP: %\n" node_error
                                            node_ok = false
                                        )
                                    )
                                )
                            )
                        )

                        if node_ok then
                        (
                            format "WallMeshCleaner Slice Selected Walls Complete: node:% direction:% REMAINING INNER VERTS:#{}
" node.name slice_kind
                        )
                    )
                )
            )

            if node_ok then
            (
                automation_report += node.name + ": slicing complete"
                if cut_mode == #all then automation_report += " (vertical, then horizontal)"
                automation_report += ".
"
            )
            else
            (
                all_ok = false
                if node_error == undefined then node_error = "Slice Selected Walls stopped before completion."
                if last_slice_error == undefined then last_slice_error = node_error
                automation_report += node_error + "
"
            )
        )

        if display_hidden_edges != undefined or double_side != undefined then
        (
            setNodesDisplayOptions selected_nodes hidden_edges:display_hidden_edges double_side:double_side
        )

        select selected_nodes
        completeRedraw()
        last_slice_report = automation_report

        all_ok
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
    Predicts slice-created vertex candidates that become removable with the redundant edges.
    Base-object vertices and vertices that remain corners or junctions are protected.
    */
    function getDebugPredictedSlicedEdgeRemovalVertices node modifier removable_edges base_vertex_count angle_threshold:0.1 =
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
            if vertex_index <= base_vertex_count then
            (
                protected_base_vertices[vertex_index] = true
            )
            else if vertex_index >= 1 and vertex_index <= vertex_count then
            (
                local vertex_position = modifier.GetVertex vertex_index node:node
                local neighbor_vertices = #()

                for edge_index = 1 to edge_count do
                (
                    local edge_is_removed = edge_index <= removable_edges.count and removable_edges[edge_index]

                    if not edge_is_removed then
                    (
                        local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
                        local edge_b = modifier.GetEdgeVertex edge_index 2 node:node

                        if edge_a != undefined and edge_b != undefined then
                        (
                            if edge_a == vertex_index then
                            (
                                append neighbor_vertices edge_b
                            )
                            else if edge_b == vertex_index then
                            (
                                append neighbor_vertices edge_a
                            )
                        )
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

                if is_removable then
                (
                    removable_new_vertices[vertex_index] = true
                )
                else
                (
                    protected_corner_vertices[vertex_index] = true
                )
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
            format "%\n" last_slice_report
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

        local base_vertex_count = polyop.getNumVerts base_obj
        local vertex_cleanup_data = getDebugPredictedSlicedEdgeRemovalVertices node modifier removable_edges base_vertex_count
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
        format "WallMeshCleaner Clean Up Sliced Edges Select: cachedLastSlice:% keep:% removeEdges:% selectedEdges:% removeVerts:% selectedVerts:% protectedBaseVerts:% protectedCornerVerts:%\n" usable_new_edges kept_edges removable_edges actual_edge_selection removable_new_vertices actual_vertex_selection protected_base_vertices protected_corner_vertices
        completeRedraw()

        (actual_edge_selection == removable_edges) and (actual_vertex_selection == removable_new_vertices)
        -- return
    ),

    /*
    Returns true when a slice-created vertex can be safely removed after redundant edge removal.
    The vertex must have exactly two remaining topology edges and those edges must be straight, so real corners are protected.
    */
    function isDebugRemovableSliceVertex node modifier vertex_index angle_threshold:0.1 =
    (
        if node == undefined or not(isValidNode node) then return false
        if modifier == undefined then return false

        local vertex_count = modifier.GetNumVertices node:node
        if vertex_index < 1 or vertex_index > vertex_count then return false

        local vertex_position = modifier.GetVertex vertex_index node:node
        if vertex_position == undefined then return false

        local incident_edges = #()
        local neighbor_vertices = #()
        local edge_count = modifier.GetNumEdges node:node

        for edge_index = 1 to edge_count do
        (
            local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
            local edge_b = modifier.GetEdgeVertex edge_index 2 node:node

            if edge_a != undefined and edge_b != undefined then
            (
                if edge_a == vertex_index then
                (
                    append incident_edges edge_index
                    append neighbor_vertices edge_b
                )
                else if edge_b == vertex_index then
                (
                    append incident_edges edge_index
                    append neighbor_vertices edge_a
                )
            )
        )

        if incident_edges.count != 2 or neighbor_vertices.count != 2 then return false

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
    Dead or isolated vertex IDs left behind by topology edits are treated as removed.
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
                local edge_count = modifier.GetNumEdges node:node
                for edge_index = 1 to edge_count do
                (
                    local edge_a = modifier.GetEdgeVertex edge_index 1 node:node
                    local edge_b = modifier.GetEdgeVertex edge_index 2 node:node
                    if edge_a == vertex_index or edge_b == vertex_index then incident_edge_count += 1
                )
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
    Finds a live slice-created Edit Poly vertex by its saved object-space position.
    This avoids relying on stale vertex IDs after topology-changing collapse operations.
    */
    function findDebugSliceVertexByPosition node modifier target_position base_vertex_count tolerance:0.01 =
    (
        if node == undefined or not(isValidNode node) then return 0
        if modifier == undefined or target_position == undefined then return 0

        local vertex_count = modifier.GetNumVertices node:node
        local found_vertex_index = 0
        local closest_distance = undefined

        for vertex_index = (base_vertex_count + 1) to vertex_count do
        (
            if doesDebugModifierVertexExist node modifier vertex_index then
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

    /* Returns whether one current Edit Poly edge slot still has two live endpoints. */
    function doesDebugModifierEdgeExist node modifier edge_index =
    (
        if node == undefined or not(isValidNode node) or modifier == undefined then return false
        local edge_count = modifier.GetNumEdges node:node
        if edge_index < 1 or edge_index > edge_count then return false
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
        edge_a != undefined and edge_b != undefined and edge_a > 0 and edge_b > 0 and \
            doesDebugModifierVertexExist node modifier edge_a and doesDebugModifierVertexExist node modifier edge_b
    ),

    /* Resolves a current edge by its saved endpoint positions. */
    function findDebugEdgeByEndpointPositions node modifier point_a point_b tolerance:0.01 =
    (
        if node == undefined or not(isValidNode node) or modifier == undefined then return 0
        local edge_count = modifier.GetNumEdges node:node
        for edge_index = 1 to edge_count do
        (
            if doesDebugModifierEdgeExist node modifier edge_index then
            (
                local vertex_a = modifier.GetEdgeVertex edge_index 1 node:node
                local vertex_b = modifier.GetEdgeVertex edge_index 2 node:node
                local current_a = modifier.GetVertex vertex_a node:node
                local current_b = modifier.GetVertex vertex_b node:node
                local same_forward = distance current_a point_a <= tolerance and distance current_b point_b <= tolerance
                local same_reverse = distance current_a point_b <= tolerance and distance current_b point_a <= tolerance
                if same_forward or same_reverse then return edge_index
            )
        )
        0
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

    /* Returns compact live topology state for per-attempt logging. */
    function getDebugCleanupTopologyState node modifier =
    (
        local live_vertices = #{}
        local live_edges = #{}
        if node != undefined and isValidNode node and modifier != undefined then
        (
            for vertex_index = 1 to (modifier.GetNumVertices node:node) where doesDebugModifierVertexExist node modifier vertex_index do live_vertices[vertex_index] = true
            for edge_index = 1 to (modifier.GetNumEdges node:node) where doesDebugModifierEdgeExist node modifier edge_index do live_edges[edge_index] = true
        )
        #(live_vertices, live_edges)
    ),

    /* Removes one redundant edge with the exact Edit Poly UI button sequence. */
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
            subObjectLevel = 2
            modifier.SetSelection #Edge #{} node:node
            modifier.Select #Edge requested_selection node:node
            actual_selection = modifier.GetSelection #Edge node:node
            if actual_selection != requested_selection then throw "Edit Poly edge selection did not match the requested redundant edge."
            modifier.ButtonOp #RemoveEdge
            update node
            refreshDebugModifierTopology node
            modifier.RefreshScreen()
        )
        catch
        (
            operation_error = getCurrentException()
        )
        modifier.remveEdgeCtrlKey = old_remove_ctrl
        local visible_edge_remains = doesDebugVisibleEdgeExistByEndpointPositions node point_a point_b tolerance:0.01
        local resolved_after = if visible_edge_remains then findDebugEdgeByEndpointPositions node modifier point_a point_b tolerance:0.01 else 0
        local topology_after = getDebugCleanupTopologyState node modifier
        local removed = operation_error == undefined and resolved_after == 0
        local failure_reason = if operation_error != undefined then operation_error as string else if resolved_after > 0 then "edge endpoints are still connected after ButtonOp #RemoveEdge" else ""
        format "WallMeshCleaner Cleanup Edge Attempt: originalEdge:% currentEdge:% method:% selectedEdges:% endpoints:%/% liveVertsAfter:% liveEdgesAfter:% success:% reason:%\n" \
            edge_index resolved_after #buttonRemoveEdge actual_selection point_a point_b topology_after[1] topology_after[2] removed failure_reason
        removed
    ),

    /* Removes one confirmed slice-created vertex, verifying fresh topology after every method. */
    function forceRemoveDebugCleanupVertex node modifier original_vertex_index saved_position base_vertex_count =
    (
        local current_vertex_index = findDebugSliceVertexByPosition node modifier saved_position base_vertex_count tolerance:0.01
        if current_vertex_index <= 0 then return #(true, 0, #alreadyGone, "")
        if current_vertex_index <= base_vertex_count or not(isDebugRemovableSliceVertex node modifier current_vertex_index) then
        (
            local protect_reason = if current_vertex_index <= base_vertex_count then "resolved vertex is an original base-object vertex" else "current vertex is not a straight two-edge cleanup vertex"
            local protected_position = modifier.GetVertex current_vertex_index node:node
            local protected_state = getDebugCleanupTopologyState node modifier
            format "WallMeshCleaner Cleanup Vert Attempt: originalVert:% currentVert:% method:% selectedVerts:% neighbor:% positionBefore:% positionAfter:% liveVertsAfter:% liveEdgesAfter:% success:false reason:%\n" \
                original_vertex_index current_vertex_index #protected #{} 0 protected_position protected_position protected_state[1] protected_state[2] protect_reason
            return #(false, current_vertex_index, #protected, protect_reason)
        )

        local methods = #(#buttonRemoveVertex, #operationRemoveVertex)
        for method in methods do
        (
            current_vertex_index = findDebugSliceVertexByPosition node modifier saved_position base_vertex_count tolerance:0.01
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
                subObjectLevel = 1
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
                refreshDebugModifierTopology node
                modifier.RefreshScreen()
            )
            catch
            (
                operation_error = getCurrentException()
            )
            local after_live_count = getDebugLiveVertexCount node modifier
            local resolved_after = findDebugSliceVertexByPosition node modifier saved_position base_vertex_count tolerance:0.01
            local after_position = if resolved_after > 0 then modifier.GetVertex resolved_after node:node else undefined
            local topology_after = getDebugCleanupTopologyState node modifier
            local removed = operation_error == undefined and resolved_after == 0 and after_live_count < before_live_count
            local failure_reason = ""
            if operation_error != undefined then failure_reason = operation_error as string
            else if resolved_after > 0 then failure_reason = "cleanup vertex still resolves at its saved position"
            else if after_live_count >= before_live_count then failure_reason = "live vertex count did not decrease"
            format "WallMeshCleaner Cleanup Vert Attempt: originalVert:% currentVert:% method:% selectedVerts:% neighbor:% positionBefore:% positionAfter:% liveVertsAfter:% liveEdgesAfter:% success:% reason:%\n" \
                original_vertex_index current_vertex_index method actual_selection 0 before_position after_position topology_after[1] topology_after[2] removed failure_reason
            if removed then return #(true, current_vertex_index, method, "")
            format "WallMeshCleaner Cleanup Vert Transition: originalVert:% failedMethod:% nextMethod:% reason:%\n" \
                original_vertex_index method (if method == #buttonRemoveVertex then #operationRemoveVertex else #guardedCollapse) failure_reason
        )

        current_vertex_index = findDebugSliceVertexByPosition node modifier saved_position base_vertex_count tolerance:0.01
        if current_vertex_index <= 0 then return #(true, 0, #alreadyGone, "")
        local neighbor_index = getDebugClosestNeighborVertex node modifier current_vertex_index
        if neighbor_index <= base_vertex_count then
        (
            local guarded_position = modifier.GetVertex current_vertex_index node:node
            local guarded_state = getDebugCleanupTopologyState node modifier
            local guarded_reason = "collapse target is not slice-created; base vertices are protected"
            format "WallMeshCleaner Cleanup Vert Attempt: originalVert:% currentVert:% method:% selectedVerts:% neighbor:% positionBefore:% positionAfter:% liveVertsAfter:% liveEdgesAfter:% success:false reason:%\n" \
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
            subObjectLevel = 1
            modifier.SetSelection #Vertex #{} node:node
            modifier.Select #Vertex collapse_selection node:node
            collapse_actual_selection = modifier.GetSelection #Vertex node:node
            if collapse_actual_selection != collapse_selection then throw "Edit Poly collapse selection did not match the requested slice-created pair."
            modifier.ButtonOp #CollapseVertex
            update node
            refreshDebugModifierTopology node
            modifier.RefreshScreen()
        )
        catch
        (
            collapse_error = getCurrentException()
        )
        local collapse_after_count = getDebugLiveVertexCount node modifier
        local collapse_resolved_after = findDebugSliceVertexByPosition node modifier saved_position base_vertex_count tolerance:0.01
        local collapse_after_position = if collapse_resolved_after > 0 then modifier.GetVertex collapse_resolved_after node:node else undefined
        local collapse_state = getDebugCleanupTopologyState node modifier
        local collapse_removed = collapse_error == undefined and collapse_resolved_after == 0 and collapse_after_count < collapse_before_count
        local collapse_reason = if collapse_error != undefined then collapse_error as string else if collapse_resolved_after > 0 then "cleanup vertex still resolves after collapse" else if collapse_after_count >= collapse_before_count then "live vertex count did not decrease" else ""
        format "WallMeshCleaner Cleanup Vert Attempt: originalVert:% currentVert:% method:% selectedVerts:% neighbor:% positionBefore:% positionAfter:% liveVertsAfter:% liveEdgesAfter:% success:% reason:%\n" \
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
            subObjectLevel = 1
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

        format "WallMeshCleaner Collapse Cleanup Vert: source:% neighbor:% moved:% moveDistance:% beforeSlots:% afterSlots:% beforeLive:% afterLive:% method:% success:%\n" vertex_index closest_neighbor_index moved_position move_distance before_vertex_count after_vertex_count before_live_vertex_count after_live_vertex_count collapse_method (collapse_ok and move_ok and collapse_success)

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
    function debugCleanUpSlicedEdges =
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
            format "%\n" last_slice_report
            return false
        )

        local removable_edges = cleanup_data[1]
        local kept_edges = cleanup_data[2]
        local usable_new_edges = cleanup_data[3]
        local start_vertices = cleanup_data[5]
        local base_vertex_count = polyop.getNumVerts base_obj
        local vertex_cleanup_data = getDebugPredictedSlicedEdgeRemovalVertices node modifier removable_edges base_vertex_count
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
                    format "WallMeshCleaner Cleanup Edge Attempt: originalEdge:% currentEdge:0 method:alreadyGone selectedEdges:#{} endpoints:%/% success:true reason:\n" original_edge_index edge_data[2] edge_data[3]
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
                local current_vertex_index = findDebugSliceVertexByPosition node modifier candidate_position base_vertex_count tolerance:0.01

                if current_vertex_index > 0 then
                (
                    local removal_result = forceRemoveDebugCleanupVertex node modifier original_vertex_index candidate_position base_vertex_count
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
            modifier.SetEPolySelLevel #Edge
            subObjectLevel = 2
            modifier.SetSelection #Edge #{} node:node

            last_slice_report = node.name + ": redundant sliced edges removed:" + (removed_edge_count as string) + "; cleanup candidates:" + (removable_new_vertices.numberSet as string) + "; removed verts:" + (removed_new_vertices.numberSet as string) + "; unresolved verts:" + (unresolved_new_vertices as string) + "."
            format "WallMeshCleaner Clean Up Sliced Edges Summary: new:% startVerts:% keep:% requestedEdges:% removedEdges:% cleanupCandidates:% removedVerts:% methods:% unresolvedVerts:% protectedBaseVerts:% protectedCornerVerts:% baseVertCount:%\n" usable_new_edges start_vertices kept_edges removable_edges removed_edge_count removable_new_vertices removed_new_vertices removal_methods unresolved_new_vertices protected_base_vertices protected_corner_vertices base_vertex_count

            if removed_edge_count > 0 then clearLastDebugSliceContext node:node
            completeRedraw()
        )
        catch
        (
            modifier.remveEdgeCtrlKey = old_remove_ctrl
            failure = getCurrentException()
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
        format "WallMeshCleaner Sliced Edge Verts: edges:% requested:% selected:% result:%\n" sliced_edges sliced_vertices actual_selection selected_ok

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

            format "WallMeshCleaner Clean Up Slice Select: selected:% protectedInner:% border:% nonTwoVisible:% selectable:%\n" sliced_vertices protected_selected_vertices border_selected_vertices non_two_visible_vertices selectable_vertices
            for sliced_vertex in sliced_vertices do
            (
                local visible_edge_count = countVisibleEdgesAtVertex evaluated_mesh sliced_vertex
                local is_border_vertex = sliced_vertex <= border_vertices.count and border_vertices[sliced_vertex]
                local select_vertex = sliced_vertex <= selectable_vertices.count and selectable_vertices[sliced_vertex]
                format "WallMeshCleaner Clean Up Slice Select Vert:% visibleEdges:% border:% inner:% select:%\n" sliced_vertex visible_edge_count is_border_vertex (sliced_vertex <= protected_inner_vertices.count and protected_inner_vertices[sliced_vertex]) select_vertex
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

            format "WallMeshCleaner Clean Up Slice: selected:% protectedInner:% border:% nonTwoVisible:% removable:%\n" sliced_vertices protected_selected_vertices border_selected_vertices non_two_visible_vertices removable_vertices
            for sliced_vertex in sliced_vertices do
            (
                local visible_edge_count = countVisibleEdgesAtVertex evaluated_mesh sliced_vertex
                local is_border_vertex = sliced_vertex <= border_vertices.count and border_vertices[sliced_vertex]
                local remove_vertex = sliced_vertex <= removable_vertices.count and removable_vertices[sliced_vertex]
                format "WallMeshCleaner Clean Up Slice Vert:% visibleEdges:% border:% remove:%\n" sliced_vertex visible_edge_count is_border_vertex remove_vertex
            )

            free evaluated_mesh
            evaluated_mesh = undefined

            modifier.SetEPolySelLevel #Vertex
            subObjectLevel = 1
            modifier.SetSelection #Vertex #{} node:node

            if removable_vertices.numberSet > 0 then
            (
                local selected_ok = modifier.Select #Vertex removable_vertices node:node
                if not selected_ok or (modifier.GetSelection #Vertex node:node) != removable_vertices then
                (
                    throw "Could not select removable sliced vertices for Remove Vertex."
                )

                modifier.SetOperation #RemoveVertex
                modifier.Commit()
                update node
            )

            modifier.SetEPolySelLevel #Vertex
            subObjectLevel = 1
            modifier.SetSelection #Vertex #{} node:node

            last_slice_report = node.name + ": sliced verts removed:" + (removable_vertices.numberSet as string) + "; protected inner verts:" + (protected_selected_vertices.numberSet as string) + "; skipped border verts:" + (border_selected_vertices.numberSet as string) + "; skipped non-2-visible verts:" + (non_two_visible_vertices.numberSet as string) + "."
            format "WallMeshCleaner Clean Up Slice: removed:% protected:% skippedBorder:% skippedNonTwoVisible:%\n" removable_vertices protected_selected_vertices border_selected_vertices non_two_visible_vertices
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
        undo "WallMeshCleaner - Slice" on
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
        undo "WallMeshCleaner - Fix N-gons" on
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
            messageBox "WallMeshCleaner: Select at least one supported Editable Poly wall object."
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

            format "TEST ANGLES: % selected\n" total_bad_verts
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
            messageBox "WallMeshCleaner: Select at least one supported Editable Poly wall object."
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

            format "FIND DOUBLE VERTS: % selected\n" total_double_verts
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

        undo "WallMeshCleaner - Fix Border Angles" on
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
            messageBox "WallMeshCleaner: Select at least one supported Editable Poly wall object."
            false
        )
        else
        (
            if horizontal_mode then
            (
                if use_high_z then
                (
                    format "FIX ANGLES: Horizontal - Align RIGHT\n"
                )
                else
                (
                    format "FIX ANGLES: Horizontal - Align LEFT\n"
                )
            )
            else
            (
                if use_high_z then
                (
                    format "FIX ANGLES: Align TOP\n"
                )
                else
                (
                    format "FIX ANGLES: Align BOTTOM\n"
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

        undo "WallMeshCleaner - Fix Double Verts" on
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
            messageBox "WallMeshCleaner: Select at least one supported Editable Poly wall object."
            false
        )
        else
        (
            if total_failed_pairs > 0 then
            (
                format "FIX VERTS: % fixed | % unresolved\n" total_collapsed_pairs total_failed_pairs
            )
            else
            (
                format "FIX VERTS: % fixed\n" total_collapsed_pairs
            )
            completeRedraw()
            true
        )
        -- return
    ),

    /*
    Initializes the WallMeshCleaner struct instance.
    Persistent settings are loaded by the rollout after creation.
    */
    on create do
    (
    )
)

WallMeshCleaner = WallMeshCleaner_v()

saved_weld_enabled = WallMeshCleaner.readIniBool "WeldVertices" true
saved_weld_threshold = WallMeshCleaner.readIniFloat "WeldThreshold" 1.0
saved_display_hidden_edges = WallMeshCleaner.readIniBool "DisplayHiddenEdges" false
saved_double_side = WallMeshCleaner.readIniBool "DoubleSide" true
saved_auto_smooth = WallMeshCleaner.readIniBool "AutoSmooth" false
saved_cut_mode_index = WallMeshCleaner.readIniInt "CutMode" 1
saved_angle_threshold = WallMeshCleaner.readIniFloat "AngleThreshold" 5.0
saved_planar_tolerance = WallMeshCleaner.readIniFloat "PlanarTolerance" 1.0
saved_slice_plane_mode_index = WallMeshCleaner.readIniInt "SlicePlaneMode" 2
saved_border_angle_threshold = WallMeshCleaner.readIniFloat "BorderAngleThreshold" 5.0
saved_double_vert_threshold = WallMeshCleaner.readIniFloat "DoubleVertThreshold" 1.0
saved_slice_precision = WallMeshCleaner.readIniFloat "SlicePrecision" 0.01
saved_dialog_position = WallMeshCleaner.loadDialogPosition()

rollout WallMeshCleanerOptionsRollout "Options" width:310 height:142
(
    checkbox weld_checkbox "Weld Vertices" pos:[8,13] width:110 height:20 checked:saved_weld_enabled tooltip:"Legacy weld setting.\nSlice and Fix N-gons preserve boundaries without welding."
    label weld_threshold_label "Threshold:" pos:[140,15] width:62 height:18
    spinner weld_threshold_spinner "" pos:[200,12] width:102 height:20 \
        range:[0.0,1000000.0,saved_weld_threshold] type:#worldUnits scale:0.1 \
        tooltip:"Maximum weld distance.\n\nUnits: system units."

    checkbox auto_smooth_checkbox "Auto Smooth" \
        pos:[8,42] width:126 height:20 checked:saved_auto_smooth \
        tooltip:"Enable automatic smoothing.\n\nApplied around supported cleanup operations."

    button smooth_button "Smooth" \
        pos:[166,38] width:136 height:26 \
        tooltip:"Apply Auto Smooth.\n\nUses the current smoothing threshold."

    checkbutton hidden_edges_checkbutton "Display Hidden Edges" \
        pos:[8,75] width:142 height:26 checked:saved_display_hidden_edges \
        tooltip:"Toggle hidden edge display.\n\nAffects selected wall objects."

    checkbutton double_side_checkbutton "Double Side" \
        pos:[160,75] width:142 height:26 checked:saved_double_side \
        tooltip:"Toggle double-sided display.\n\nDisables backface culling when enabled."

    label slice_precision_label "Advanced - Slice Precision:" pos:[8,114] width:152 height:18
    spinner slice_precision_spinner "" pos:[164,110] width:138 height:20 \
        range:[0.0,1000000.0,saved_slice_precision] type:#worldUnits scale:0.001 \
        tooltip:"Advanced post-slice precision threshold.\n\nSlice Selected Walls checks only vertices created by the latest Make 1 Slice. New vertices within this world-space distance of the defining anchor vertices are welded back to the anchor before redundant-loop cleanup.\n\nDefault: 0.01 world units."

    on weld_checkbox changed state do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on weld_threshold_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on auto_smooth_checkbox changed state do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on hidden_edges_checkbutton changed state do
    (
        WallMeshCleaner.setSelectionDisplayHiddenEdges state
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on double_side_checkbutton changed state do
    (
        WallMeshCleaner.setSelectionDoubleSide state
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on slice_precision_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on smooth_button pressed do
    (
        ::WallMeshCleanerRollout.runSmooth()
    )
)

rollout WallMeshCleanerFaceSlicerRollout "Face Slicer" width:310 height:354
(
    dotNetControl reset_slicing_button "System.Windows.Forms.Button" pos:[8,8] width:294 height:32

    radiobuttons cut_mode_radio "" pos:[8,48] width:243 height:20 \
        labels:#("All", "Horizontal", "Vertical") default:saved_cut_mode_index columns:3 align:#left \
        offsets:#([0,0],[-15,0],[0,0]) \
        tooltip:"Choose slicing direction.\n\nAll: Vertical first, then Horizontal."

    spinner angle_spinner "Angle:" pos:[257,48] width:45 height:20 \
        range:[0.0,45.0,saved_angle_threshold] type:#float scale:1.0 \
        tooltip:"Orientation tolerance.\n\nUnits: degrees."

    label planar_tolerance_label "Planar tolerance:" pos:[8,80] width:96 height:18
    spinner planar_tolerance_spinner "" pos:[104,77] width:96 height:20 \
        range:[0.0,1000000.0,saved_planar_tolerance] type:#float scale:0.1 \
        tooltip:"Maximum distance from the detected wall plane before the wall is rejected.\n\nUnits: system units."

    label slice_plane_mode_label "Slice Direction" pos:[8,106] width:120 height:18
    radiobuttons slice_plane_mode_radio "" pos:[126,103] width:176 height:22 \
        labels:#("Global Axis", "Edge Direction") default:saved_slice_plane_mode_index columns:2 align:#left \
        tooltip:"Choose how each slice plane is oriented.\n\nCorner + Global Axis: source corner plus the wall-local horizontal/vertical frame.\nEdge Direction: source corner plus its matching adjacent border vertex. This is the default."

    button slice_button "Slice Selected Walls" pos:[8,132] width:294 height:34 tooltip:"Run Reset Slicing, then repeat Make 1 Slice until REMAINING INNER VERTS is empty.\n\nAll mode runs Vertical completely first, then Horizontal."

    groupBox manual_group "MANUAL" pos:[8,172] width:294 height:112
    button make_one_slice_button "1. Make 1 Slice" pos:[16,192] width:278 height:28 \
        tooltip:"LMB: Analyze the unchanged base object and make one pending slice. Edge Direction remembers successful base border edges, not infinite planes. Failed cuts stay pending for retry after later topology changes. Vertical and horizontal are tracked separately.\nNewly created non-border edges are selected.\n\nRMB: Convert the currently selected sliced edges to non-border sliced vertices."
    button clean_up_sliced_edges_button "2. Clean Up Sliced Edges" pos:[16,224] width:278 height:28 \
        tooltip:"LMB: Remove the redundant edges and eligible new vertices.\n\nRMB: Select redundant edge candidates and the slice-created vertex candidates that would be removed with them. Edge and Vertex selections are both stored; Vertex mode is left active."

    button slice_precision_cleanup_button "3. Fix Slice Precision" pos:[16,256] width:278 height:28 \
        tooltip:"LMB: Repair all new slice vertices within Slice Precision of any original pre-slice vertex.\n\nRMB: Select all vertices that LMB would repair, without changing topology."

    groupBox debug_group "Debug" pos:[8,290] width:294 height:56
    button check_corners_button "Check Corners" pos:[16,308] width:135 height:28 \
        tooltip:"Select exactly the INNER VERTS captured by the last Reset Slicing.\n\nNo corner availability is recalculated. Run Reset Slicing first."
    button clean_up_slice_button "Clean Up Slice" pos:[159,308] width:135 height:28 \
        tooltip:"LMB: Select only sliced verts with exactly 2 visible edges that are not on a border and are not Reset Slicing INNER VERTS. No topology change.\n\nRMB: Remove only eligible sliced verts using the same filter."

    on cut_mode_radio changed state do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on angle_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on planar_tolerance_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on slice_plane_mode_radio changed state do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on slice_button pressed do
    (
        ::WallMeshCleanerRollout.runDebugSliceSelectedWalls()
    )

    on WallMeshCleanerFaceSlicerRollout open do
    (
        reset_slicing_button.Text = "Reset Slicing"
        reset_slicing_button.UseVisualStyleBackColor = false
        reset_slicing_button.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 55 55 55
        reset_slicing_button.ForeColor = (dotNetClass "System.Drawing.Color").Green
    )

    on reset_slicing_button MouseUp event_args do
    (
        mouse_button = event_args.Button.ToString()
        if mouse_button == "Left" then
        (
            ::WallMeshCleanerRollout.runResetSlicing()
        )
        else if mouse_button == "Right" then
        (
            ::WallMeshCleanerRollout.runDebugSelectInnerCorners()
        )
    )

    on make_one_slice_button pressed do
    (
        ::WallMeshCleanerRollout.runDebugMakeOneSlice()
    )

    on make_one_slice_button rightclick do
    (
        ::WallMeshCleanerRollout.runDebugSelectSlicedEdgeVertices()
    )

    on clean_up_sliced_edges_button pressed do
    (
        ::WallMeshCleanerRollout.runDebugCleanUpSlicedEdges()
    )

    on clean_up_sliced_edges_button rightclick do
    (
        ::WallMeshCleanerRollout.runDebugInspectCleanUpSlicedEdges()
    )

    on slice_precision_cleanup_button pressed do
    (
        ::WallMeshCleanerRollout.runDebugSlicePrecisionCleanup()
    )

    on slice_precision_cleanup_button rightclick do
    (
        ::WallMeshCleanerRollout.runDebugSelectSlicePrecisionCandidates()
    )

    on check_corners_button pressed do
    (
        ::WallMeshCleanerRollout.runDebugCheckCorners()
    )

    on clean_up_slice_button pressed do
    (
        ::WallMeshCleanerRollout.runDebugInspectCleanUpSlice()
    )

    on clean_up_slice_button rightclick do
    (
        ::WallMeshCleanerRollout.runDebugCleanUpSlice()
    )
)

rollout WallMeshCleanerFaceCleanerRollout "Face Cleaner" width:310 height:60
(
    button junction_button "Fix N-gons" pos:[8,8] width:294 height:34 tooltip:"Reduce wall N-gons.\n\nPrefer orthogonal clean cuts.\n\nRemove redundant dirty topology."

    on junction_button pressed do
    (
        ::WallMeshCleanerRollout.runFaceCleaner()
    )
)

rollout WallMeshCleanerEdgeCleanerRollout "Edge Cleaner" width:310 height:60
(
    button redundant_loop_cleanup_button "Redundant Loop Cleanup" pos:[8,8] width:294 height:34 \
        tooltip:"Find geometrically redundant straight planar loops running border-to-border.\n\nCreates FIND REDUNDANT LOOPS and DELETE REDUNDANT LOOPS only when a valid redundant loop is found.\n\nDELETE uses Remove Edge, not Delete."

    on redundant_loop_cleanup_button pressed do
    (
        ::WallMeshCleanerRollout.runRedundantLoopCleanup()
    )
)

rollout WallMeshCleanerVertexCleanerRollout "Vertex Cleaner" width:310 height:144
(
    button test_border_angles_button "Test Border Angles" \
        pos:[8,8] width:138 height:34 \
        tooltip:"Select bad border-angle vertices.\n\nAccepts orthogonal or straight borders.\n\nSelection only."

    spinner border_angle_threshold_spinner "" pos:[152,14] width:76 height:20 \
        range:[0.0,45.0,saved_border_angle_threshold] type:#float scale:0.1 \
        tooltip:"Border angle tolerance.\n\nValid angles: 90 / 180 / 270 degrees."

    button fix_border_angles_button "Fix Angles" \
        pos:[234,8] width:68 height:34 \
        tooltip:"LMB: Align BOTTOM.\n\nRMB: Align TOP.\n\nCTRL + LMB: Align LEFT.\n\nCTRL + RMB: Align RIGHT.\n\nUses all currently selected vertices.\n\nHorizontal movement stays in the wall plane."

    button find_double_verts_button "Find Double Verts" \
        pos:[8,50] width:138 height:34 \
        tooltip:"Select near-coincident vertices.\n\nUses Double Vert Threshold.\n\nSelection only."

    spinner double_vert_threshold_spinner "" pos:[152,56] width:76 height:20 \
        range:[0.0,1000000.0,saved_double_vert_threshold] type:#worldUnits scale:0.1 \
        tooltip:"Near-coincident distance threshold.\n\nUnits: system units.\n\nDefault: 1 system unit."

    button fix_double_verts_button "Fix Verts" \
        pos:[234,50] width:68 height:34 \
        tooltip:"Fix near-coincident vertex pairs.\n\nCreate edge if needed.\n\nCollapse connected pair.\n\nUnresolved pairs stay selected."

    button test_vertical_position_button "Test Vertical Position" \
        pos:[8,92] width:294 height:34 \
        tooltip:"Use currently selected vertices.\n\nReport maximum Z position difference.\n\nSelection only."

    on border_angle_threshold_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on double_vert_threshold_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on test_border_angles_button pressed do
    (
        ::WallMeshCleanerRollout.runBorderAngleTest()
    )

    on fix_border_angles_button pressed do
    (
        ::WallMeshCleanerRollout.runBorderAngleFix use_high_z:false horizontal_mode:keyboard.controlPressed
    )

    on fix_border_angles_button rightclick do
    (
        ::WallMeshCleanerRollout.runBorderAngleFix use_high_z:true horizontal_mode:keyboard.controlPressed
    )

    on find_double_verts_button pressed do
    (
        ::WallMeshCleanerRollout.runDoubleVertTest()
    )

    on fix_double_verts_button pressed do
    (
        ::WallMeshCleanerRollout.runDoubleVertFix()
    )

    on test_vertical_position_button pressed do
    (
        ::WallMeshCleanerRollout.runVerticalPositionTest()
    )
)

rollout WallMeshCleanerRollout "Wall Mesh Cleaner 6-ASTRA 0.87" width:344 height:900
(
    button restart_button "Restart" pos:[262,6] width:74 height:22 tooltip:"Reload the matching versioned script first.\nFallback: WallMeshCleaner.ms."
    subRollout tool_subrollout "Wall Mesh Cleaner 6-ASTRA 0.87" pos:[8,32] width:328 height:860

    /*
    Returns the requested face-slice orientation from the Face Slicer sub-rollout.
    All performs vertical first and horizontal second in the slicer implementation.
    */
    function getCutMode =
    (
        case WallMeshCleanerFaceSlicerRollout.cut_mode_radio.state of
        (
            2: #horizontal
            3: #vertical
            default: #all
        )
        -- return
    )

    /*
    Returns the selected slice-plane definition mode from the Face Slicer rollout.
    The next-vertex mode is the default because two mesh vertices define the actual cut line.
    */
    function getSlicePlaneMode =
    (
        case WallMeshCleanerFaceSlicerRollout.slice_plane_mode_radio.state of
        (
            1: #globalAxis
            default: #nextVert
        )
        -- return
    )

    /*
    Saves all controls from the five child rollouts to the shared INI file.
    Child rollouts call this parent method so persistence remains centralized.
    */
    function saveUiSettings =
    (
        WallMeshCleaner.saveSettings \
            WallMeshCleanerOptionsRollout.weld_checkbox.checked \
            WallMeshCleanerOptionsRollout.weld_threshold_spinner.value \
            WallMeshCleanerOptionsRollout.hidden_edges_checkbutton.checked \
            WallMeshCleanerOptionsRollout.double_side_checkbutton.checked \
            WallMeshCleanerOptionsRollout.auto_smooth_checkbox.checked \
            WallMeshCleanerFaceSlicerRollout.cut_mode_radio.state \
            WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value \
            slice_plane_mode_index:WallMeshCleanerFaceSlicerRollout.slice_plane_mode_radio.state \
            border_angle_threshold:WallMeshCleanerVertexCleanerRollout.border_angle_threshold_spinner.value \
            double_vert_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value \
            slice_precision:WallMeshCleanerOptionsRollout.slice_precision_spinner.value
        -- return
    )

    /*
    Runs Auto Smooth from the Options sub-rollout.
    The operation remains undoable and redraws the viewport after completion.
    */
    function runSmooth =
    (
        undo "WallMeshCleaner - Auto Smooth" on
        (
            WallMeshCleaner.autoSmoothSelection()
        )

        completeRedraw()
        -- return
    )

    /*
    Runs the main face slicer using shared Options and Face Slicer controls.
    Display options are applied before slicing and current settings are persisted.
    */
    function runFaceSlicer =
    (
        WallMeshCleaner.setSelectionDisplayHiddenEdges WallMeshCleanerOptionsRollout.hidden_edges_checkbutton.checked
        WallMeshCleaner.setSelectionDoubleSide WallMeshCleanerOptionsRollout.double_side_checkbutton.checked
        saveUiSettings()

        local completed = WallMeshCleaner.sliceSelection \
            weld_vertices:WallMeshCleanerOptionsRollout.weld_checkbox.checked \
            weld_threshold:WallMeshCleanerOptionsRollout.weld_threshold_spinner.value \
            cut_mode:(getCutMode()) \
            slice_plane_mode:(getSlicePlaneMode()) \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value
        messageBox WallMeshCleaner.last_slice_report title:(if completed then "Wall Mesh Cleaner - Completed" else "Wall Mesh Cleaner - Could not finish")
        completed
    )

    /*
    Runs only the slicer's mesh validation stage for debugging.
    The report counts usable anchors and leaves those anchor vertices selected.
    */
    function runResetSlicing =
    (
        saveUiSettings()
        local completed = WallMeshCleaner.debugCheckSelection \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value
        completed
        -- return
    )

    /*
    Automates the stable debug slicing workflow for every selected wall.
    Reset Slicing runs first; All mode completes vertical before horizontal.
    */
    function runDebugSliceSelectedWalls =
    (
        saveUiSettings()
        local completed = WallMeshCleaner.debugSliceSelectedWalls \
            cut_mode:(getCutMode()) \
            slice_plane_mode:(getSlicePlaneMode()) \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value \
            slice_precision:WallMeshCleanerOptionsRollout.slice_precision_spinner.value \
            display_hidden_edges:WallMeshCleanerOptionsRollout.hidden_edges_checkbutton.checked \
            double_side:WallMeshCleanerOptionsRollout.double_side_checkbutton.checked

        messageBox WallMeshCleaner.last_slice_report title:(if completed then "Wall Mesh Cleaner - Slice Selected Walls Complete" else "Wall Mesh Cleaner - Slice Selected Walls Stopped")
        completed
        -- return
    )

    /*
    Selects wall-inner corner vertices for slicer debugging, including outer-border re-entrant corners.
    Triggered by right-click on Reset Slicing.
    */
    function runDebugSelectInnerCorners =
    (
        saveUiSettings()
        local completed = WallMeshCleaner.debugSelectInnerCorners \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Inner Corner Check Failed"
        )
        completed
        -- return
    )

    /*
    Selects the exact INNER VERTS captured by the last successful Reset Slicing.
    The UI button therefore reproduces Reset Slicing corner IDs without recalculation.
    */
    function runDebugCheckCorners =
    (
        saveUiSettings()
        local completed = WallMeshCleaner.debugCheckCorners \
            cut_mode:(getCutMode()) \
            slice_plane_mode:(getSlicePlaneMode()) \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Check Corners Failed"
        )
        completed
        -- return
    )

    /*
    Selects non-border vertices belonging to the sliced edges created by the last Make 1 Slice.
    Triggered by right-click on Make 1 Slice and does not modify topology.
    */
    function runDebugSelectSlicedEdgeVertices =
    (
        local completed = WallMeshCleaner.debugSelectSlicedEdgeVertices()
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Sliced Edge Vertex Check Failed"
        )
        completed
        -- return
    )

    /*
    Runs exactly one slicer cut and leaves newly created non-border edges selected.
    Current cut mode, angle tolerance and planar tolerance are respected.
    */
    function runDebugMakeOneSlice =
    (
        saveUiSettings()
        local completed = WallMeshCleaner.debugMakeOneSlice \
            cut_mode:(getCutMode()) \
            slice_plane_mode:(getSlicePlaneMode()) \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Debug Slice Failed"
        )
        completed
        -- return
    )

    /*
    Runs the exact Slice Precision post-slice repair used by Slice Selected Walls on the last manual Make 1 Slice.
    Only vertices created by that slice are candidates, and only near-anchor candidates may be welded.
    */
    function runDebugSlicePrecisionCleanup =
    (
        saveUiSettings()
        local selected_nodes = selection as array
        if selected_nodes.count != 1 then
        (
            format "WallMeshCleaner Slice Precision Manual: select exactly one wall that was processed by Make 1 Slice.\n"
            false
        )
        else
        (
            local node = selected_nodes[1]
            local precision_cleanup = WallMeshCleaner.cleanupMassSlicePrecisionVerts node precision_threshold:WallMeshCleanerOptionsRollout.slice_precision_spinner.value
            format "WallMeshCleaner Slice Precision Manual: node:% threshold:% success:% fixed:% candidates:%\n" node.name WallMeshCleanerOptionsRollout.slice_precision_spinner.value precision_cleanup[1] precision_cleanup[2] precision_cleanup[3]
            completeRedraw()
            precision_cleanup[1]
        )
        -- return
    )

    /*
    Selects every new vertex that the current Slice Precision value would repair.
    No topology change is made; Vertex sub-object level remains active for inspection.
    */
    function runDebugSelectSlicePrecisionCandidates =
    (
        saveUiSettings()
        local selected_nodes = selection as array
        if selected_nodes.count != 1 then
        (
            format "WallMeshCleaner Slice Precision Inspect: select exactly one wall that was processed by Make 1 Slice.\n"
            false
        )
        else
        (
            local node = selected_nodes[1]
            local precision_data = WallMeshCleaner.getMassSlicePrecisionCandidates node precision_threshold:WallMeshCleanerOptionsRollout.slice_precision_spinner.value
            local candidate_vertices = precision_data[1]
            local inspection_vertices = precision_data[3]

            if node.modifiers.count > 0 and classOf node.modifiers[1] == Edit_Poly then
            (
                local modifier = node.modifiers[1]
                select node
                max modify mode
                modPanel.setCurrentObject modifier
                modifier.SetPrimaryNode node
                modifier.useStackSelection = false
                modifier.SetEPolySelLevel #Vertex
                subObjectLevel = 1
                modifier.SetSelection #Vertex #{} node:node
                modifier.SetSelection #Vertex inspection_vertices node:node
                modifier.RefreshScreen()
                completeRedraw()
            )

            format "WallMeshCleaner Slice Precision Candidates: %\n" candidate_vertices
            format "WallMeshCleaner Slice Precision Inspection: %\n" inspection_vertices
            inspection_vertices.numberSet > 0
        )
        -- return
    )

    /*
    Selects redundant edge candidates plus their predicted removable slice-created vertices.
    No topology change is made; Vertex sub-object level remains active for inspection.
    */
    function runDebugInspectCleanUpSlicedEdges =
    (
        local completed = WallMeshCleaner.debugInspectCleanUpSlicedEdges()
        local listener_only_notice = WallMeshCleaner.isLastSliceContextNotice (WallMeshCleaner.last_slice_report)
        if (not completed) and (not listener_only_notice) then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Clean Up Sliced Edges Test Failed"
        )
        completed
        -- return
    )

    /*
    Removes the redundant new edges identified from the last Make 1 Slice.
    */
    function runDebugCleanUpSlicedEdges =
    (
        local completed = WallMeshCleaner.debugCleanUpSlicedEdges()
        local listener_only_notice = WallMeshCleaner.isLastSliceContextNotice (WallMeshCleaner.last_slice_report)
        if (not completed) and (not listener_only_notice) then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Clean Up Sliced Edges Failed"
        )
        completed
        -- return
    )

    /*
    Selects only Clean Up Slice eligible vertices.
    LMB requires exactly 2 visible edges, not border, and not cached INNER VERTS; no topology change.
    */
    function runDebugInspectCleanUpSlice =
    (
        local completed = WallMeshCleaner.debugInspectCleanUpSlice()
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Clean Up Slice Test Failed"
        )
        completed
        -- return
    )

    /*
    Removes redundant sliced vertices from the last debug slice.
    INNER VERTS cached by Reset Slicing are always protected from removal.
    */
    function runDebugCleanUpSlice =
    (
        local completed = WallMeshCleaner.debugCleanUpSlice()
        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Clean Up Slice Failed"
        )
        completed
        -- return
    )

    /*
    Runs geometric redundant-loop cleanup with a strict near-zero angular tolerance.
    The two inspection modifiers are created only for walls where valid loops are detected.
    */
    function runRedundantLoopCleanup =
    (
        completed = false
        undo "WallMeshCleaner - Redundant Loop Cleanup" on
        (
            completed = WallMeshCleaner.cleanupRedundantLoopsSelection angle_threshold:0.1 debug_output:true
        )

        if not completed then
        (
            messageBox WallMeshCleaner.last_slice_report title:"Wall Mesh Cleaner - Redundant Loop Cleanup Failed"
        )
        completed
        -- return
    )

    /*
    Runs the face-cleaner N-gon post-process using the current shared options.
    The handler lives on the parent rollout so the sub-rollout stays UI-only.
    */
    function runFaceCleaner =
    (
        saveUiSettings()

        local completed = WallMeshCleaner.propagateSelectionJunctionCuts \
            weld_vertices:WallMeshCleanerOptionsRollout.weld_checkbox.checked \
            weld_threshold:WallMeshCleanerOptionsRollout.weld_threshold_spinner.value \
            auto_smooth:WallMeshCleanerOptionsRollout.auto_smooth_checkbox.checked \
            cut_mode:(getCutMode()) \
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value
        messageBox WallMeshCleaner.last_slice_report title:(if completed then "Wall Mesh Cleaner - Completed" else "Wall Mesh Cleaner - Could not finish")
        completed
    )

    /*
    Runs border-angle validation from the Vertex Cleaner sub-rollout.
    Problem vertices are selected without modifying geometry.
    */
    function runBorderAngleTest =
    (
        saveUiSettings()
        WallMeshCleaner.selectNonOrthoBorderVerts \
            angle_threshold:WallMeshCleanerVertexCleanerRollout.border_angle_threshold_spinner.value
        -- return
    )

    /*
    Aligns all currently selected vertices as one set.
    LMB/RMB use bottom/top Z; CTRL + LMB/RMB use left/right wall-local horizontal position.
    */
    function runBorderAngleFix use_high_z:false horizontal_mode:false =
    (
        saveUiSettings()
        WallMeshCleaner.fixNonOrthoBorderVerts use_high_z:use_high_z horizontal_mode:horizontal_mode
        -- return
    )

    /*
    Runs duplicate-position vertex detection from the Vertex Cleaner sub-rollout.
    All vertices participating in a near-coincident pair are selected.
    */
    function runDoubleVertTest =
    (
        saveUiSettings()
        WallMeshCleaner.selectDoubleVerts \
            position_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value
        -- return
    )

    /*
    Fixes near-coincident vertices using the current Vertex Cleaner distance threshold.
    Only vertices detected by the duplicate-position test are passed to the weld operation.
    */
    function runDoubleVertFix =
    (
        saveUiSettings()
        WallMeshCleaner.fixDoubleVerts \
            position_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value
        -- return
    )

    /*
    Reports the world-Z range across all currently selected vertices.
    Values are formatted with the current 3ds Max display-unit settings.
    */
    function runVerticalPositionTest =
    (
        selected_nodes = selection as array
        found_vert = false
        min_z = 0.0
        max_z = 0.0

        for node in selected_nodes do
        (
            if WallMeshCleaner.isSupportedNode node then
            (
                base_obj = node.baseObject
                selected_verts = polyop.getVertSelection base_obj

                for vert_index in selected_verts do
                (
                    world_pos = (polyop.getVert base_obj vert_index) * node.objectTransform

                    if not found_vert then
                    (
                        min_z = world_pos.z
                        max_z = world_pos.z
                        found_vert = true
                    )
                    else
                    (
                        if world_pos.z < min_z then min_z = world_pos.z
                        if world_pos.z > max_z then max_z = world_pos.z
                    )
                )
            )
        )

        if found_vert then
        (
            z_difference = max_z - min_z
            formatted_difference = units.formatValue z_difference
            formatted_difference = substituteString formatted_difference " " ""
            format "Z POSITION DIFFERENCE: %\n" formatted_difference
        )
        else
        (
            format "Z POSITION DIFFERENCE: No verts selected\n"
        )
        -- return
    )

    on restart_button pressed do
    (
        script_path = WallMeshCleaner.getRestartScriptPath WallMeshCleanerScriptPath

        if script_path != undefined then
        (
            saveUiSettings()
            destroyDialog WallMeshCleanerRollout
            fileIn script_path
        )
        else
        (
            messageBox (
                "WallMeshCleaner restart failed.\n\n" +
                "Neither the versioned script nor WallMeshCleaner.ms exists beside the running script."
            )
        )
    )

    on WallMeshCleanerRollout open do
    (
        addSubRollout tool_subrollout WallMeshCleanerOptionsRollout
        addSubRollout tool_subrollout WallMeshCleanerFaceSlicerRollout
        addSubRollout tool_subrollout WallMeshCleanerFaceCleanerRollout
        addSubRollout tool_subrollout WallMeshCleanerEdgeCleanerRollout
        addSubRollout tool_subrollout WallMeshCleanerVertexCleanerRollout
    )

    on WallMeshCleanerRollout close do
    (
        dialog_pos = undefined

        try
        (
            dialog_pos = getDialogPos WallMeshCleanerRollout
        )
        catch
        (
            dialog_pos = undefined
        )

        WallMeshCleaner.saveSettings \
            WallMeshCleanerOptionsRollout.weld_checkbox.checked \
            WallMeshCleanerOptionsRollout.weld_threshold_spinner.value \
            WallMeshCleanerOptionsRollout.hidden_edges_checkbutton.checked \
            WallMeshCleanerOptionsRollout.double_side_checkbutton.checked \
            WallMeshCleanerOptionsRollout.auto_smooth_checkbox.checked \
            WallMeshCleanerFaceSlicerRollout.cut_mode_radio.state \
            WallMeshCleanerFaceSlicerRollout.angle_spinner.value \
            planar_tolerance:WallMeshCleanerFaceSlicerRollout.planar_tolerance_spinner.value \
            slice_plane_mode_index:WallMeshCleanerFaceSlicerRollout.slice_plane_mode_radio.state \
            border_angle_threshold:WallMeshCleanerVertexCleanerRollout.border_angle_threshold_spinner.value \
            double_vert_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value \
            slice_precision:WallMeshCleanerOptionsRollout.slice_precision_spinner.value \
            dialog_position:dialog_pos

        removeSubRollout tool_subrollout WallMeshCleanerVertexCleanerRollout
        removeSubRollout tool_subrollout WallMeshCleanerEdgeCleanerRollout
        removeSubRollout tool_subrollout WallMeshCleanerFaceCleanerRollout
        removeSubRollout tool_subrollout WallMeshCleanerFaceSlicerRollout
        removeSubRollout tool_subrollout WallMeshCleanerOptionsRollout
    )
)

if saved_dialog_position == undefined then
(
    createDialog WallMeshCleanerRollout
)
else
(
    createDialog WallMeshCleanerRollout pos:saved_dialog_position
)
