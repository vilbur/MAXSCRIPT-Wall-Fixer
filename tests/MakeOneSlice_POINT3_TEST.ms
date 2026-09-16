(
    global WallMeshCleaner
    local root_path = @"C:\Users\vilbur\AppData\Local\Autodesk\3dsMax\2026 - 64bit\ENU\scripts\MAXSCRIPT-Wall-Mesh-Cleaner\"
    local report = createFile (root_path + "test\\make-one-slice-point3-results.txt")
    try
    (
        loadMaxFile (root_path + "test\\objects\\test_wall-complex\\test_wall-complex-001.max") useFileUnits:true quiet:true
        fileIn (root_path + "WallMeshCleaner-6-ASTRA_0.30.ms") quiet:true
        local wall = getNodeByName "all-slice-source-CLEANED" exact:true
        if wall == undefined then throw "Fixture node all-slice-source-CLEANED was not found."
        select wall
        if not (WallMeshCleaner.debugMakeOneSlice cut_mode:#all slice_plane_mode:#nextVert angle_threshold:5.0 planar_tolerance:1.0) then throw (WallMeshCleaner.last_slice_error as string)
        format "PASS: Make 1 Slice completed without an undefined Point3.\n" to:report
    )
    catch
    (
        format "FAIL: %\n" (getCurrentException()) to:report
        try (format "%\n" (getCurrentExceptionStackTrace()) to:report) catch ()
    )
    close report
)