/*
WallMeshCleaner 0.57
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
struct WMCWallTopology (points, faces, edges, faceEdges, vertexEdges, border, materials, smoothing)
struct WMCWallSlicePipeline
(
    node, ep, origin, normal, horizontal, vertical, referenceLocal = undefined,
    tolerance = 0.0001, angularTolerance = 0.1, axisTolerance = 0.1,
    corners = #(), anchors = #(), originalBorder = #(), originalDiagonals = #(),
    protectedSegments = #(), baseline, cuts = 0, removedEdges = 0, removedVerts = 0,

    fn refreshTopology =
    (
        update node
        -- Force evaluation; Edit Poly otherwise returns zero counts after Commit.
        local evaluated = snapshotAsMesh node
        free evaluated
        local t = WMCWallTopology points:#() faces:#() edges:#() faceEdges:#() vertexEdges:#() border:#{} materials:#() smoothing:#()
        -- EditPolyMod.GetVertex returns world coordinates even inside coordsys local.
        -- Convert explicitly; otherwise a rotated node is transformed twice.
        local basis = copy node.objectTransform
        basis.row4 = [0,0,0]
        if referenceLocal == undefined and (ep.GetNumVertices node:node) > 0 do referenceLocal = (ep.GetVertex 1 node:node) * inverse node.objectTransform
        for v = 1 to (ep.GetNumVertices node:node) do
        (
            append t.points ((((ep.GetVertex v node:node) * inverse node.objectTransform)-referenceLocal) * basis)
            append t.vertexEdges #{}
        )
        for e = 1 to (ep.GetNumEdges node:node) do
        (
            local a = ep.GetEdgeVertex e 1 node:node
            local b = ep.GetEdgeVertex e 2 node:node
            local f = ep.GetEdgeFace e 1 node:node
            local g = ep.GetEdgeFace e 2 node:node
            append t.edges #(a,b,f,g)
            if a > 0 and b > 0 do
            (
                t.vertexEdges[a][e] = true
                t.vertexEdges[b][e] = true
            )
            if (f == 0) != (g == 0) do t.border[e] = true
        )
        for f = 1 to (ep.GetNumFaces node:node) do
        (
            local vs = #()
            local es = #{}
            for k = 1 to (ep.GetFaceDegree f node:node) do
            (
                append vs (ep.GetFaceVertex f k node:node)
                es[ep.GetFaceEdge f k node:node] = true
            )
            append t.faces vs
            append t.faceEdges es
            append t.materials (ep.GetFaceMaterial f node:node)
            append t.smoothing (ep.GetFaceSmoothingGroups f node:node)
        )
        t
    ),
    fn faceVector t f =
    (
        local vs = t.faces[f]
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
    fn hasPoint t p =
    (
        for q in t.points do if distance p q <= tolerance do return true
        false
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
        for v = 1 to t.points.count do
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
        if t.faces.count == 0 do throw "The evaluated Edit Poly has no faces."
        origin = t.points[t.faces[1][1]]
        local n = faceVector t 1
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
        for f = 1 to t.faces.count do
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
        if t.faces.count == 0 do throw "The wall lost all faces."
        for p in t.points do
            if abs(dot(p-origin) normal) > tolerance do throw "Input/result is not one planar wall."
        local used = #{}
        for f = 1 to t.faces.count do
        (
            local vs = t.faces[f]
            if vs.count < 3 do throw "Invalid polygon degree."
            if not(validFaceBoundary t f) do throw "Self-intersecting or invalid polygon boundary."
            if dot (faceVector t f) normal <= tolerance*tolerance do throw "Zero-area or reversed polygon."
            for v in vs do used[v] = true
        )
        if used.numberSet != t.points.count do throw "Isolated vertices in topology."
        for e = 1 to t.edges.count do
        (
            local rec = t.edges[e]
            if rec[1] < 1 or rec[2] < 1 or (rec[3] == 0 and rec[4] == 0) do throw "Isolated/invalid edge."
            if distance t.points[rec[1]] t.points[rec[2]] <= tolerance do throw "Zero-length edge."
            -- Same-face bridge incidence was checked by validFaceBoundary.
            for f in #(rec[3],rec[4]) where f > 0 do
                if not t.faceEdges[f][e] do throw "Invalid face-edge adjacency."
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
        for f = 1 to t.faces.count where findItem t.faces[f] v > 0 do
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
        if a == 0 or b == 0 or a == b do return false
        if edgeKind t e != #diagonal do return false
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
        local borderSegments = for e in t.border collect segment t e
        for s in originalBorder do if not(covered s borderSegments) do throw "Original wall/opening boundary changed."
        for s in borderSegments do if not(covered s originalBorder) do throw "Unexpected wall/opening boundary."
        for p in corners do if not(hasPoint t p) do throw "An original corner was lost."
        if (t.points.count-t.edges.count+t.faces.count) != baseline[1] do throw "Wall/opening topology changed (Euler characteristic)."
        local areas = areaByMaterial t
        if areas.count != baseline[2].count do throw "Material/smoothing regions changed."
        for old in baseline[2] do
        (
            local found = false
            for current in areas do if old[1][1] == current[1][1] and old[1][2] == current[1][2] do
                found = abs(old[2]-current[2]) <= amax (old[2]*0.00001) (tolerance*tolerance*10)
            if not found do throw "Wall surface area or material/smoothing boundary changed."
        )
        local allSegments = for e = 1 to t.edges.count collect segment t e
        for s in protectedSegments do if not(covered s allSegments) do throw "An intentional orthogonal edge was lost."
        if final do
        (
            for v = 1 to t.points.count do if canRemoveVertex t v do throw "A safely removable collinear vertex remains."
            for e = 1 to t.edges.count do if canRemoveDiagonal t e do throw "A safely removable internal diagonal remains."
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
            for v = 1 to t.points.count while not changed do if canRemoveVertex t v do
            (
                local countBefore = t.points.count
                t = applyOperation #Vertex #{v} #RemoveVertex
                if t.points.count != countBefore-1 do throw "Edit Poly did not remove exactly one straight vertex."
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
        for v = 1 to t.points.count do if distance t.points[v] p <= tolerance do
            for e in t.vertexEdges[v] do for f in #(t.edges[e][3],t.edges[e][4]) where f > 0 do
                if not result[f] do (result[f] = true; append queue f)
        local i = 1
        while i <= queue.count do
        (
            local f = queue[i]
            i += 1
            for e in t.faceEdges[f] do for g in #(t.edges[e][3],t.edges[e][4]) where g > 0 do
                if not result[g] do (result[g] = true; append queue g)
        )
        result
    ),
    fn performCuts axis =
    (
        -- Deduplication is per connected component, identified geometrically.
        local done = #()
        for anchor in anchors do
        (
            local t = refreshTopology()
            local region = componentAt t anchor
            if region.numberSet == 0 do throw "Cannot remap a preserved corner anchor."
            local station = dot(anchor-origin) axis
            local duplicate = false
            for item in done do
                if abs(item[1]-station) <= tolerance and (componentAt t item[2]) == region do duplicate = true
            if not duplicate do
            (
                append done #(station,anchor)
                local spans = false
                for f in region do
                (
                    local low = 1e30
                    local high = -1e30
                    for v in t.faces[f] do
                    (
                        local value = dot(t.points[v]-anchor) axis
                        low = amin low value
                        high = amax high value
                    )
                    if low < -tolerance and high > tolerance do spans = true
                )
                if spans do
                (
                    local tm = node.objectTransform
                    -- Plane normals transform as covectors (also handles nonuniform scale).
                    local localNormal = normalize [dot tm.row1 axis,dot tm.row2 axis,dot tm.row3 axis]
                    tm.row4 = [0,0,0]
                    ep.SetSlicePlane localNormal ((anchor * inverse tm) + referenceLocal)
                    t = applyOperation #Face region #SliceSelectedFaces
                    local currentRegion = componentAt t anchor
                    for f in currentRegion do
                    (
                        local low = 1e30
                        local high = -1e30
                        for v in t.faces[f] do
                        (
                            local value = dot(t.points[v]-anchor) axis
                            low = amin low value
                            high = amax high value
                        )
                        if low < -tolerance and high > tolerance do throw "Slice left a polygon crossing its requested plane."
                    )
                    for e = 1 to t.edges.count do
                    (
                        local s = segment t e
                        if abs(dot(s[1]-anchor) axis) <= tolerance and abs(dot(s[2]-anchor) axis) <= tolerance do
                            append protectedSegments s
                    )
                    validateCleanTopology t
                    cuts += 1
                )
            )
        )
        true
    ),
    fn performVerticalCuts = performCuts horizontal,
    fn performHorizontalCuts = performCuts vertical,
    fn removeRedundantDiagonalEdges =
    (
        local t = refreshTopology()
        local changed = true
        while changed do
        (
            changed = false
            for e = 1 to t.edges.count while not changed do if canRemoveDiagonal t e do
            (
                local oldCount = t.faces.count
                t = applyOperation #Edge #{e} #RemoveEdge
                if t.faces.count != oldCount-1 do throw "Edit Poly did not dissolve exactly two adjacent faces."
                validateCleanTopology t
                removedEdges += 1
                changed = true
            )
        )
        t
    ),
    fn run cutMode:#all =
    (
        local t = refreshTopology()
        tolerance = units.decodeValue "0.001mm"
        setFrame t
        validateStructure t
        corners = collectCornerVertices t
        originalBorder = for e in t.border collect segment t e
        originalDiagonals = for e = 1 to t.edges.count where not t.border[e] and edgeKind t e == #diagonal collect segment t e
        protectedSegments = for e = 1 to t.edges.count where edgeKind t e != #diagonal collect segment t e
        baseline = #(t.points.count-t.edges.count+t.faces.count,areaByMaterial t)
        cleanCollinearVertices()
        t = refreshTopology()
        -- Only boundary corners with one edge in each wall-plane direction anchor cuts.
        anchors = #()
        for v = 1 to t.points.count do
        (
            local es = (t.vertexEdges[v]*t.border) as array
            if es.count == 2 do
            (
                local k1 = edgeKind t es[1]
                local k2 = edgeKind t es[2]
                if (k1 == #horizontal and k2 == #vertical) or (k1 == #vertical and k2 == #horizontal) do append anchors t.points[v]
            )
        )
        if cutMode == #all or cutMode == #vertical do performVerticalCuts()
        if cutMode == #all or cutMode == #horizontal do performHorizontalCuts()
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
    version = "0.57",
    last_slice_error = undefined,
    last_slice_count = 0,
    last_slice_report = "",
    epsilon = 0.001,
    axis_angle_threshold = 5.0,
    ini_path = ((getDir #userScripts) + "\\WallMeshCleaner.ini"),

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
    Returns the preferred script path for Restart.
    The matching versioned file is preferred; WallMeshCleaner.ms is the fallback.
    */
    function getRestartScriptPath source_script_path =
    (
        script_dir = getFilenamePath source_script_path
        versioned_script_path = script_dir + "WallMeshCleaner_" + version + ".ms"
        unversioned_script_path = script_dir + "WallMeshCleaner.ms"

        if doesFileExist versioned_script_path then
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
    function saveSettings weld_enabled weld_threshold display_hidden_edges double_side auto_smooth cut_mode_index angle_threshold border_angle_threshold:5.0 double_vert_threshold:1.0 dialog_position:undefined =
    (
        setIniSetting ini_path "Settings" "WeldVertices" (if weld_enabled then "1" else "0")
        setIniSetting ini_path "Settings" "WeldThreshold" (weld_threshold as string)
        setIniSetting ini_path "Settings" "DisplayHiddenEdges" (if display_hidden_edges then "1" else "0")
        setIniSetting ini_path "Settings" "DoubleSide" (if double_side then "1" else "0")
        setIniSetting ini_path "Settings" "AutoSmooth" (if auto_smooth then "1" else "0")
        setIniSetting ini_path "Settings" "CutMode" (cut_mode_index as string)
        setIniSetting ini_path "Settings" "AngleThreshold" (angle_threshold as string)
        setIniSetting ini_path "Settings" "BorderAngleThreshold" (border_angle_threshold as string)
        setIniSetting ini_path "Settings" "DoubleVertThreshold" (double_vert_threshold as string)

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
    Applies viewport edge-display state to all selected nodes.
    Checked Display Hidden Edges corresponds to the node allEdges property.
    */
    function setSelectionDisplayHiddenEdges enabled =
    (
        selected_nodes = selection as array

        for node in selected_nodes do
        (
            if isValidNode node then
            (
                node.allEdges = enabled
            )
        )

        redrawViews()
        true
        -- return
    ),

    /*
    Applies double-sided viewport display to all selected nodes.
    Checked Double Side means backface culling is disabled on the object.
    */
    function setSelectionDoubleSide enabled =
    (
        selected_nodes = selection as array

        for node in selected_nodes do
        (
            if isValidNode node then
            (
                node.backFaceCull = not enabled
            )
        )

        redrawViews()
        true
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
    function processNode node cut_mode:#all angle_threshold:5.0 reset_clean_edges:true clear_clean_edges:true auto_smooth:false =
    (
        last_slice_error = undefined
        last_slice_count = 0
        if not isValidNode node then
        (
            last_slice_error = "The selected node is no longer valid."
            return false
        )
        local supported = (classOf node.baseObject == Editable_Poly)
        for m in node.modifiers do if classOf m == Edit_Poly do supported = true
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
            local pipeline = WMCWallSlicePipeline node:node ep:modifier axisTolerance:(amin 45.0 (amax 0.0 angle_threshold))
            pipeline.run cutMode:cut_mode
            if auto_smooth do
            (
                local t = pipeline.refreshTopology()
                local ids = #{1..t.faces.count}
                t = pipeline.applyOperation #Face ids #Autosmooth
                pipeline.validateStructure t
            )
            modifier.SetSelection #Vertex #{} node:node
            modifier.SetSelection #Edge #{} node:node
            modifier.SetSelection #Face #{} node:node
            modifier.split = settings[1]
            modifier.useStackSelection = settings[2]
            modifier.useSoftSel = settings[3]
            modifier.remveEdgeCtrlKey = settings[4]
            last_slice_count = pipeline.cuts
            success = true
        )
        catch
        (
            failure = getCurrentException()
            if modifier != undefined do
            (
                if added then deleteModifier node modifier
                else if backup != undefined do
                (
                    deleteModifier node modifier
                    addModifier node backup
                    if oldCurrent == modifier do oldCurrent = backup
                )
            )
        )
        select oldSelection
        if oldPanel == #modify and oldCurrent != undefined do
            try (modPanel.setCurrentObject oldCurrent; subObjectLevel = oldLevel) catch ()
        setCommandPanelTaskMode oldPanel
        last_slice_error = failure
        if failure != undefined do format "WallMeshCleaner: % | restored after failure: %\n" node.name failure
        success
    ),
    function sliceSelection weld_vertices:false weld_threshold:1.0 cut_mode:#all angle_threshold:5.0 =
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
                if processNode node cut_mode:cut_mode angle_threshold:angle_threshold then
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
    function propagateAutomaticJunctionCuts node cut_mode:#all angle_threshold:5.0 =
    (
        if processNode node cut_mode:cut_mode angle_threshold:angle_threshold then last_slice_count else 0
    ),
    function propagateSelectionJunctionCuts weld_vertices:false weld_threshold:1.0 auto_smooth:false cut_mode:#all angle_threshold:5.0 =
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
                if processNode node cut_mode:cut_mode angle_threshold:angle_threshold auto_smooth:auto_smooth then
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
saved_border_angle_threshold = WallMeshCleaner.readIniFloat "BorderAngleThreshold" 5.0
saved_double_vert_threshold = WallMeshCleaner.readIniFloat "DoubleVertThreshold" 1.0
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

    on smooth_button pressed do
    (
        ::WallMeshCleanerRollout.runSmooth()
    )
)

rollout WallMeshCleanerFaceSlicerRollout "Face Slicer" width:310 height:86
(
    radiobuttons cut_mode_radio "" pos:[8,8] width:243 height:20 \
        labels:#("All", "Horizontal", "Vertical") default:saved_cut_mode_index columns:3 align:#left \
        offsets:#([0,0],[-15,0],[0,0]) \
        tooltip:"Choose slicing direction.\n\nAll: Vertical first, then Horizontal."

    spinner angle_spinner "Angle:" pos:[257,8] width:45 height:20 \
        range:[0.0,45.0,saved_angle_threshold] type:#float scale:1.0 \
        tooltip:"Orientation tolerance.\n\nUnits: degrees."

    button slice_button "Slice Selected Walls" pos:[8,40] width:294 height:34 tooltip:"Clean redundant straight vertices and safe internal diagonals.\nPreserve boundary corners.\n\nAll: Vertical first, then Horizontal in the wall plane."

    on cut_mode_radio changed state do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on angle_spinner changed value do
    (
        ::WallMeshCleanerRollout.saveUiSettings()
    )

    on slice_button pressed do
    (
        ::WallMeshCleanerRollout.runFaceSlicer()
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

rollout WallMeshCleanerRollout "Wall Mesh Cleaner 0.57" width:344 height:594
(
    button restart_button "Restart" pos:[262,6] width:74 height:22 tooltip:"Reload the matching versioned script first.\nFallback: WallMeshCleaner.ms."
    subRollout tool_subrollout "Wall Mesh Cleaner 0.57" pos:[8,32] width:328 height:554

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
    Saves all controls from the four child rollouts to the shared INI file.
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
            border_angle_threshold:WallMeshCleanerVertexCleanerRollout.border_angle_threshold_spinner.value \
            double_vert_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value
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
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value
        messageBox WallMeshCleaner.last_slice_report title:(if completed then "Wall Mesh Cleaner - Completed" else "Wall Mesh Cleaner - Could not finish")
        completed
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
            angle_threshold:WallMeshCleanerFaceSlicerRollout.angle_spinner.value
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
            border_angle_threshold:WallMeshCleanerVertexCleanerRollout.border_angle_threshold_spinner.value \
            double_vert_threshold:WallMeshCleanerVertexCleanerRollout.double_vert_threshold_spinner.value \
            dialog_position:dialog_pos

        removeSubRollout tool_subrollout WallMeshCleanerVertexCleanerRollout
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
