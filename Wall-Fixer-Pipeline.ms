/*
Wall-Fixer Pipeline 0.23
Native Edit Poly topology snapshot and wall slicing pipeline.
Load through Wall-Fixer.ms during normal development.
*/

global WallFixerVersion
global WallFixerRollout
global wall_fixer_version_system
global wall_fixer_version_epoch
global wall_fixer_pipeline_file_version = "0.23"
global wall_fixer_pipeline_tool_version = 0.83

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

wall_fixer_pipeline_current_tool_version_number = undefined

if WallFixerVersion != undefined then
(
    try
    (
        wall_fixer_pipeline_current_tool_version_number = WallFixerVersion as float
    )
    catch
    (
        wall_fixer_pipeline_current_tool_version_number = undefined
    )
)

if wall_fixer_pipeline_current_tool_version_number == undefined then
(
    WallFixerVersion = wall_fixer_pipeline_tool_version
)
else if wall_fixer_pipeline_tool_version > wall_fixer_pipeline_current_tool_version_number then
(
    WallFixerVersion = wall_fixer_pipeline_tool_version
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


global WMCWallTopology
global WMCWallSlicePipeline

/* Native Edit Poly pipeline. All persistent topology references are positions.
   A topology snapshot is valid only until the next Commit. */
struct WMCWallTopology (points, validVertices, faces, validFaces, edges, validEdges, faceEdges, vertexEdges, border, materials, smoothing)
struct WMCWallSlicePipeline
(
    node, ep, origin, normal, horizontal, vertical, referenceWorld = undefined,
    tolerance = 0.0001, planarTolerance = 1.0, angularTolerance = 0.1, axisTolerance = 0.1,
    corners = #(), anchors = #(), originalBorder = #(), originalDiagonals = #(),
    protectedSegments = #(), baseline, cuts = 0, removedEdges = 0, removedVerts = 0, uiSelection = true,

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
            format "Wall-Fixer Topology Snapshot: raw verts/edges/faces:%/%/% live:%/%/% dead:%/%/%\n" \
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
                format "Wall-Fixer Boundary Debug: original segment:%  A:%  B:%  topologyTolerance:%  boundaryTolerance:%  planarTolerance:%\n" i s[1] s[2] tolerance boundary_tolerance planarTolerance
                throw ("Original wall/opening boundary changed at original segment " + (i as string) + ".")
            )
        )
        for i = 1 to borderSegments.count do
        (
            local s = borderSegments[i]
            if not(coveredAtTolerance s originalBorder boundary_tolerance) then
            (
                format "Wall-Fixer Boundary Debug: unexpected segment:%  A:%  B:%  topologyTolerance:%  boundaryTolerance:%  planarTolerance:%\n" i s[1] s[2] tolerance boundary_tolerance planarTolerance
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
    Returns live topology indices appended after a known pre-operation maximum index.
    Slice-created topology is appended by Edit Poly, so this avoids rediscovering new items geometrically.
    */
    function getAppendedValidIndices original_max_index valid_items =
    (
        result = #{}
        if valid_items == undefined then return result

        first_new_index = amax 1 (original_max_index + 1)
        last_index = valid_items.count

        if first_new_index <= last_index then
        (
            for item_index = first_new_index to last_index do
            (
                if valid_items[item_index] then result[item_index] = true
            )
        )

        result
        -- return
    ),

    /*
    Returns newly appended non-border edges after one Edit Poly slice.
    Only the appended index range is inspected.
    */
    function findAppendedNewEdges original_edge_max_index =
    (
        t = refreshTopology()
        result = getAppendedValidIndices original_edge_max_index t.validEdges
        result = result - t.border
        result
        -- return
    ),

    /*
    Tests appended-index topology detection without requiring scene geometry.
    */
    function testAppendedTopologyIndexSelection =
    (
        valid_items = #{}
        expected = #{}

        for item_index = 1 to 8 do valid_items[item_index] = true
        valid_items[6] = false
        expected[5] = true
        expected[7] = true
        expected[8] = true

        (getAppendedValidIndices 4 valid_items) == expected
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
    Finds the current connected faces belonging to one stored planar base-wall region.
    Face IDs may change after earlier cuts, so the region is remapped from its base normal, plane and preserved source vertex.
    */
    function getCurrentPlanarWallRegionFaces t source_vertex world_normal world_origin plane_tolerance:1.0 =
    (
        local result = #{}
        if t == undefined or world_normal == undefined or world_origin == undefined then return result
        if source_vertex < 1 or source_vertex > t.points.count or not t.validVertices[source_vertex] then return result
        if length world_normal <= tolerance then return result

        local region_normal = normalize world_normal
        local region_origin = world_origin - referenceWorld
        local normal_limit = cos 0.1
        local seed_face = 0

        for face_index in t.validFaces while seed_face == 0 do
        (
            if findItem t.faces[face_index] source_vertex > 0 then
            (
                local face_vector = faceVector t face_index
                if length face_vector > tolerance*tolerance then
                (
                    local face_normal = normalize face_vector
                    local face_matches = abs(dot face_normal region_normal) >= normal_limit

                    for vertex_index in t.faces[face_index] while face_matches do
                    (
                        if abs(dot (t.points[vertex_index] - region_origin) region_normal) > plane_tolerance then
                        (
                            face_matches = false
                        )
                    )

                    if face_matches then
                    (
                        seed_face = face_index
                    )
                )
            )
        )

        if seed_face == 0 then return result

        local face_queue = #(seed_face)
        local queue_index = 1
        result[seed_face] = true

        while queue_index <= face_queue.count do
        (
            local current_face = face_queue[queue_index]
            queue_index += 1

            for edge_index in t.faceEdges[current_face] do
            (
                if t.validEdges[edge_index] then
                (
                    local edge_record = t.edges[edge_index]

                    for adjacent_face in #(edge_record[3],edge_record[4]) do
                    (
                        if adjacent_face > 0 and t.validFaces[adjacent_face] and not result[adjacent_face] then
                        (
                            local face_vector = faceVector t adjacent_face
                            local face_matches = length face_vector > tolerance*tolerance

                            if face_matches then
                            (
                                local face_normal = normalize face_vector
                                face_matches = abs(dot face_normal region_normal) >= normal_limit
                            )

                            if face_matches then
                            (
                                for vertex_index in t.faces[adjacent_face] while face_matches do
                                (
                                    if abs(dot (t.points[vertex_index] - region_origin) region_normal) > plane_tolerance then
                                    (
                                        face_matches = false
                                    )
                                )
                            )

                            if face_matches then
                            (
                                result[adjacent_face] = true
                                append face_queue adjacent_face
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
    Performs one debug slice using a plane defined entirely by the unchanged base object.
    The current Edit Poly only executes the plane and no longer rediscovers a border edge.
    */
    function makeOneSliceFromBasePlane sourceVertex worldAnchor worldAxis sliceKind wall_normal:undefined wall_origin:undefined plane_tolerance:1.0 =
    (
        if worldAnchor == undefined or worldAxis == undefined then return undefined
        if length worldAxis <= tolerance then return undefined

        local t = refreshTopology()

        local axis = normalize worldAxis
        local anchor = worldAnchor - referenceWorld
        local slice_faces = copy t.validFaces

        if wall_normal != undefined and wall_origin != undefined then
        (
            slice_faces = getCurrentPlanarWallRegionFaces                 t                 sourceVertex                 wall_normal                 wall_origin                 plane_tolerance:plane_tolerance

            if slice_faces.numberSet == 0 then
            (
                format "Wall-Fixer Base Plane Slice Skip: source:% direction:% reason:stored planar wall region cannot be remapped.\n" sourceVertex sliceKind
                return undefined
            )
        )

        local original_vertex_count = t.validVertices.numberSet
        local original_edge_count = t.validEdges.numberSet
        local original_edge_max_index = t.validEdges.count
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
        local region_vertices = #{}

        for face_index in slice_faces do
        (
            for vertex_index in t.faces[face_index] do
            (
                region_vertices[vertex_index] = true
            )
        )

        for vertex_index in region_vertices do
        (
            if abs(dot(t.points[vertex_index] - anchor) axis) <= alignment_tolerance then
            (
                aligned_vertices[vertex_index] = true
            )
        )

        if uiSelection then
        (
            ep.useStackSelection = false
            ep.SetEPolySelLevel #Vertex
            ep.SetSelection #Vertex #{} node:node
            if aligned_vertices.numberSet > 0 then
            (
                ep.Select #Vertex aligned_vertices node:node
            )
            completeRedraw()
        )

        local tm = node.objectTransform
        local local_normal = normalize [dot tm.row1 axis,dot tm.row2 axis,dot tm.row3 axis]
        local local_point = worldAnchor * inverse tm
        ep.SetSlicePlane local_normal local_point

        local slice_operation = if slice_faces.numberSet == t.validFaces.numberSet then #Slice else #SliceSelectedFaces
        format "Wall-Fixer Base Plane Slice: source:% direction:% alignedCurrentVerts:% axis:% regionFaces:%/% operation:% split:%\n"             sourceVertex sliceKind aligned_vertices axis slice_faces.numberSet t.validFaces.numberSet slice_operation ep.split
        t = applyOperation #Face slice_faces slice_operation

        local topology_changed = (t.validVertices.numberSet != original_vertex_count or t.validEdges.numberSet != original_edge_count or t.validFaces.numberSet != original_face_count)

        local new_edges = findAppendedNewEdges original_edge_max_index
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
            format "Wall-Fixer Base Plane Slice Skip: source:% direction:% reason:Edit Poly topology did not change.\n" sourceVertex sliceKind
            return undefined
        )

        cuts += 1
        if uiSelection then
        (
            ep.useStackSelection = false
            ep.SetEPolySelLevel #Edge
            ep.SetSelection #Edge #{} node:node
            ep.Select #Edge new_edges node:node
            completeRedraw()
        )

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
                format "Wall-Fixer Slice Debug: selected source vertex % is not live anymore.\n" preferredSourceVertex
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

            format "Wall-Fixer Make 1 Slice Candidates: inner:% preferred:% skippedLast:% candidates:%\n" inner_vertices preferredSourceVertex excludedSourceVertex source_vertices
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

                                if uiSelection then
                                (
                                    ep.useStackSelection = false
                                    ep.SetEPolySelLevel #Vertex
                                    ep.SetSelection #Vertex #{} node:node
                                    ep.Select #Vertex #{source_vertex_before} node:node
                                    completeRedraw()
                                )

                                local tm = node.objectTransform
                                local localNormal = normalize [dot tm.row1 axis,dot tm.row2 axis,dot tm.row3 axis]
                                local localPoint = (anchor + referenceWorld) * inverse tm
                                ep.SetSlicePlane localNormal localPoint
                                local slice_operation = if region.numberSet == t.validFaces.numberSet then #Slice else #SliceSelectedFaces
                                format "Wall-Fixer Slice Debug: innerCorner:% direction:% planeMode:% definingEdge:% definingVerts:% operation:% region:%/% split:%\n" source_vertex_before slice_kind planeMode defining_edge aligned_vertices slice_operation region.numberSet t.validFaces.numberSet ep.split
                                t = applyOperation #Face region slice_operation

                                local source_vertex_after = source_vertex_before
                                if source_vertex_after > t.points.count or not t.validVertices[source_vertex_after] then source_vertex_after = 0

                                local new_edges = findNewEdges original_segments

                                if new_edges.numberSet > 0 then
                                (
                                    cuts += 1
                                    if uiSelection then
                                    (
                                        ep.useStackSelection = false
                                        ep.SetEPolySelLevel #Edge
                                        ep.SetSelection #Edge #{} node:node
                                        ep.Select #Edge new_edges node:node
                                        completeRedraw()
                                    )
                                    return #(anchor,source_vertex_before,source_vertex_after,slice_kind,axis,original_points,original_segments,referenceWorld,new_edges,aligned_vertices,second_vertex)
                                )
                                else
                                (
                                    format "Wall-Fixer Make 1 Slice Skip: source:% direction:% reason:no new non-border edge.\n" source_vertex_before slice_kind
                                )
                            )
                            else
                            (
                                format "Wall-Fixer Make 1 Slice Skip: source:% direction:% reason:connected region does not cross plane.\n" source_vertex_before slice_kind
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
                            format "Wall-Fixer Slice Debug: direction:% planeMode:% definingVerts:% operation:% region:%/% split:%\n" slice_kind planeMode plane_definition[2] slice_operation region.numberSet t.validFaces.numberSet ep.split
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
        format "Wall-Fixer: % | cuts:% diagonal edges removed:% straight vertices removed:% | topology validated\n" node.name cuts removedEdges removedVerts
        true
    )
)
